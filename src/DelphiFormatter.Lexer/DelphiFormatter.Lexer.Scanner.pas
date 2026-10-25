unit DelphiFormatter.Lexer.Scanner;

interface

uses
  DelphiFormatter.Lexer.Tokens;

type
  TDelphiLexer = class
  public
    // Caller owns the returned result. No scanner state survives this call.
    class function Tokenize(const Source: string): TDelphiLexResult; static;
  end;

implementation

uses
  System.Character,
  System.Generics.Collections,
  DelphiFormatter.Core.Spans,
  DelphiFormatter.Core.Diagnostics,
  DelphiFormatter.Lexer.Keywords;

function IsIdentifierStart(C: Char): Boolean;
begin
  Result := (C = '_') or C.IsLetter;
end;

function IsIdentifierPart(C: Char): Boolean;
begin
  Result := IsIdentifierStart(C) or C.IsNumber;
end;

function IsHorizontalBlank(C: Char): Boolean;
begin
  // Delphi blanks U+0000..U+0020, with CR/LF handled separately.
  Result := (Ord(C) <= 32) and (C <> #13) and (C <> #10);
end;

class function TDelphiLexer.Tokenize(const Source: string): TDelphiLexResult;
var
  Tokens: TList<TDelphiToken>;
  Diagnostics: TList<TDiagnostic>;
  Position, Start, SourceLength: Integer;
  C, Next: Char;
  Kind: TTokenKind;
  Span: TSourceSpan;
  Escaped, Deferred: Boolean;
  UnknownCode, UnknownMessage: string;

  function Peek(Delta: Integer): Char;
  begin
    // NUL is also valid source: the outer loop, not this sentinel, detects EOF.
    if Delta < SourceLength - Position then
      Result := Source[Position + Delta + 1]
    else
      Result := #0;
  end;

begin
  Tokens := TList<TDelphiToken>.Create;
  try
    Diagnostics := TList<TDiagnostic>.Create;
    try
      Position := 0;
      SourceLength := Length(Source);
      while Position < SourceLength do
      begin
        Start := Position;
        C := Peek(0);
        Next := Peek(1);
        Kind := tkUnknown;
        Deferred := False;
        UnknownCode := 'LEX005';
        UnknownMessage := 'Unrecognized source character';
        if (C = #13) or (C = #10) then
        begin
          Kind := tkNewLine;
          Inc(Position);
          if (C = #13) and (Next = #10) then
            Inc(Position);
        end
        else if IsHorizontalBlank(C) then
        begin
          Kind := tkWhitespace;
          repeat
            Inc(Position);
          until (Position = SourceLength) or not IsHorizontalBlank(Peek(0));
        end
        else if (Ord(C) >= $D800) and (Ord(C) <= $DFFF) then
        begin
          Inc(Position);
          if (Ord(C) <= $DBFF) and (Position < SourceLength) and
            (Ord(Next) >= $DC00) and (Ord(Next) <= $DFFF) then
          begin
            // One valid scalar value, two UTF-16 code units. Identifier
            // classification beyond the BMP remains outside M1.1.
            Inc(Position);
            Deferred := True;
            UnknownMessage := 'Supplementary Unicode character is not supported in M1.1';
          end
          else
          begin
            UnknownCode := 'LEX007';
            UnknownMessage := 'Invalid UTF-16: isolated surrogate code unit';
          end;
        end
        else if IsIdentifierStart(C) or ((C = '&') and IsIdentifierStart(Next)) then
        begin
          Escaped := C = '&';
          if Escaped then
            Inc(Position);
          Inc(Position);
          while (Position < SourceLength) and IsIdentifierPart(Peek(0)) do
            Inc(Position);
          Kind := tkIdentifier;
          if not Escaped then
            if IsReservedWord(Source, Start, Position - Start) then
              Kind := tkReservedWord;
        end
        else
        begin
          // These openers belong to M1.2; do not mislabel them as operators.
          Deferred := (C = '''') or (C = '{') or (C = '}') or
            (C = '$') or (C = '%') or (C = '#') or
            ((C >= '0') and (C <= '9')) or
            ((C = '/') and (Next = '/')) or
            ((C = '(') and (Next = '*'));
          Inc(Position); // Ordinary fallback consumes one UTF-16 code unit.
          if Deferred then
            UnknownMessage := 'Lexical category not implemented in M1.1';
          if not Deferred then
          begin
            case C of
              ':': begin
                Kind := tkSymbol;
                if Next = '=' then Inc(Position);
              end;
              '<': begin
                Kind := tkSymbol;
                if (Next = '=') or (Next = '>') then Inc(Position);
              end;
              '>': begin
                Kind := tkSymbol;
                if Next = '=' then Inc(Position);
              end;
              '.': begin
                Kind := tkSymbol;
                if (Next = '.') or (Next = ')') then Inc(Position);
              end;
              '(': begin
                Kind := tkSymbol;
                if Next = '.' then Inc(Position);
              end;
              '+', '-', '*', '/', '=', ',', ';', ')', '[', ']', '^', '@':
                Kind := tkSymbol;
            end;
          end;
        end;
        Span := TSourceSpan.Create(Start, Position - Start);
        Tokens.Add(TDelphiToken.Create(Kind, Span));
        if Kind = tkUnknown then
          if Deferred then
            Diagnostics.Add(TDiagnostic.Create('LEX006',
              UnknownMessage, dsWarning, Span))
          else
            Diagnostics.Add(TDiagnostic.Create(UnknownCode,
              UnknownMessage, dsError, Span));
      end;
      Tokens.Add(TDelphiToken.Create(tkEOF, TSourceSpan.Create(SourceLength, 0)));
      Result := TDelphiLexResult.Create(Source, Tokens.ToArray, Diagnostics.ToArray);
    finally
      Diagnostics.Free;
    end;
  finally
    Tokens.Free;
  end;
end;

end.
