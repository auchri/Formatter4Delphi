unit DelphiFormatter.Lexer.Scanner;

interface

uses DelphiFormatter.Lexer.Tokens;

type
  TDelphiLexer = class
  public
    // Caller owns the result; scanner state is local to this call.
    class function Tokenize(const Source: string): TDelphiLexResult; static;
  end;

implementation

uses
  System.Character, System.Generics.Collections,
  DelphiFormatter.Core.Spans, DelphiFormatter.Core.Diagnostics,
  DelphiFormatter.Lexer.Keywords;

function IsIdentifierStart(C: Char): Boolean;
begin
  Result := (C = '_') or C.IsLetter;
end;

function IsIdentifierPart(C: Char): Boolean;
begin
  Result := IsIdentifierStart(C) or C.IsNumber;
end;

function IsDigit(C: Char): Boolean;
begin
  Result := (C >= '0') and (C <= '9');
end;

function DigitValue(C: Char): Integer;
begin
  case C of
    '0'..'9': Result := Ord(C) - Ord('0');
    'a'..'f': Result := Ord(C) - Ord('a') + 10;
    'A'..'F': Result := Ord(C) - Ord('A') + 10;
  else Result := -1;
  end;
end;

function IsHorizontalBlank(C: Char): Boolean;
begin
  Result := (Ord(C) <= 32) and (C <> #13) and (C <> #10);
end;

class function TDelphiLexer.Tokenize(const Source: string): TDelphiLexResult;
var
  Tokens: TList<TDelphiToken>;
  Diagnostics: TList<TDiagnostic>;
  Position, Start, SourceLength, I: Integer;
  C, Next: Char;
  Kind: TTokenKind;
  Escaped: Boolean;

  function Peek(Delta: Integer = 0): Char;
  begin
    if (Delta >= 0) and (Delta < SourceLength - Position) then
      Result := Source[Position + Delta + 1]
    else Result := #0;
  end;

  procedure Error(const Code, MessageText: string; Offset, Count: Integer);
  begin
    Diagnostics.Add(TDiagnostic.Create(Code, MessageText, dsError,
      TSourceSpan.Create(Offset, Count)));
  end;

  procedure ConstructError(const Code, MessageText: string);
  begin
    Error(Code, MessageText, Start, Position - Start);
  end;

  function QuoteCount: Integer;
  begin
    Result := 0;
    while (Result < SourceLength - Position) and (Peek(Result) = #39) do
      Inc(Result);
  end;

  procedure ScanString;
  var Delimiter, Run: Integer; LinePrefix: Boolean;
  begin
    Kind := tkStringLiteral;
    Delimiter := QuoteCount;
    if (Delimiter >= 3) and Odd(Delimiter) and
      ((Peek(Delimiter) = #13) or (Peek(Delimiter) = #10)) then
    begin
      Inc(Position, Delimiter);
      LinePrefix := False;
      while Position < SourceLength do
      begin
        if LinePrefix and (Peek = #39) then
        begin
          Run := QuoteCount;
          if Run = Delimiter then
          begin
            Inc(Position, Run);
            Exit;
          end;
          Inc(Position, Run);
          LinePrefix := False;
        end
        else
        begin
          if (Peek = #13) or (Peek = #10) then LinePrefix := True
          else if (Peek <> ' ') and (Peek <> #9) then LinePrefix := False;
          Inc(Position);
        end;
      end;
    end
    else
    begin
      Inc(Position);
      while Position < SourceLength do
      begin
        if (Peek = #13) or (Peek = #10) then Break;
        if Peek = #39 then
        begin
          Inc(Position);
          if Peek <> #39 then Exit;
        end;
        Inc(Position);
      end;
    end;
    ConstructError('LEX003', 'Unterminated string literal');
  end;

  procedure ScanLineComment;
  begin
    Kind := tkComment;
    Inc(Position, 2);
    while (Position < SourceLength) and (Peek <> #13) and (Peek <> #10) do
      Inc(Position);
  end;

  procedure ScanBlockComment;
  var Brace, Directive: Boolean;
  begin
    Brace := Peek = '{';
    if Brace then Inc(Position) else Inc(Position, 2);
    Directive := Peek = '$';
    if Directive then Kind := tkCompilerDirective else Kind := tkComment;
    // Other comment styles are inert within this comment. This permits
    // cross-style nesting without making same-style delimiters recursive.
    while Position < SourceLength do
    begin
      if Brace and (Peek = '}') then
      begin Inc(Position); Exit; end;
      if not Brace and (Peek = '*') and (Peek(1) = ')') then
      begin Inc(Position, 2); Exit; end;
      Inc(Position);
    end;
    if Directive then ConstructError('LEX002', 'Unterminated compiler directive')
    else ConstructError('LEX001', 'Unterminated block comment');
  end;

  procedure ScanNumber(CharCode: Boolean);
  var Base, Digits, Value, D: Integer; Bad, PreviousDigit: Boolean;

    procedure ScanDigits;
    begin
      Digits := 0;
      PreviousDigit := False;
      while Position < SourceLength do
      begin
        D := DigitValue(Peek);
        if ((D >= 0) and (D < Base)) or
          ((Base = 2) and IsDigit(Peek)) then
        begin
          if D >= Base then Bad := True;
          Inc(Digits);
          // Saturate: char codes need only a UTF-16 range check; numbers
          // are not evaluated here, so arbitrarily long input cannot overflow.
          if Value <= 65535 then Value := Value * Base + D;
          PreviousDigit := True;
          Inc(Position);
        end
        else if Peek = '_' then
        begin
          if not PreviousDigit then Bad := True;
          PreviousDigit := False;
          Inc(Position);
        end
        else Break;
      end;
      if (Digits = 0) or not PreviousDigit then Bad := True;
    end;

  begin
    if CharCode then begin Kind := tkCharCode; Inc(Position); end
    else Kind := tkNumber;
    Base := 10;
    Bad := False;
    Value := 0;
    if Peek = '$' then begin Base := 16; Inc(Position); end
    else if Peek = '%' then
    begin
      Base := 2;
      if CharCode then Bad := True;
      Inc(Position);
    end;
    ScanDigits;
    if not CharCode and (Base = 10) then
    begin
      if (Peek = '.') and (Peek(1) <> '.') and (Peek(1) <> ')') and
        not IsIdentifierStart(Peek(1)) then
      begin
        Inc(Position);
        if IsDigit(Peek) or (Peek = '_') then ScanDigits;
      end;
      if (Peek = 'e') or (Peek = 'E') then
      begin
        Inc(Position);
        if (Peek = '+') or (Peek = '-') then Inc(Position);
        ScanDigits;
      end;
    end;
    if CharCode and (Value > 65535) then Bad := True;
    if Bad then ConstructError('LEX004', 'Malformed numeric literal');
  end;

  procedure ScanSymbol;
  begin
    Kind := tkSymbol;
    Inc(Position);
    case C of
      ':': if Next = '=' then Inc(Position);
      '<': if (Next = '=') or (Next = '>') then Inc(Position);
      '>': if Next = '=' then Inc(Position);
      '.': if (Next = '.') or (Next = ')') then Inc(Position);
      '(': if Next = '.' then Inc(Position);
      '+', '-', '*', '/', '=', ',', ';', ')', '[', ']', '^', '@': ;
    else
      Kind := tkUnknown;
      ConstructError('LEX005', 'Unrecognized source character');
    end;
  end;

begin
  Tokens := TList<TDelphiToken>.Create;
  try
    Diagnostics := TList<TDiagnostic>.Create;
    try
      Position := 0;
      SourceLength := Length(Source);
      // Validate encoding independently, including inside comments/strings.
      I := 0;
      while I < SourceLength do
      begin
        C := Source[I + 1];
        if (Ord(C) >= $D800) and (Ord(C) <= $DBFF) and
          (I + 1 < SourceLength) and (Ord(Source[I + 2]) >= $DC00) and
          (Ord(Source[I + 2]) <= $DFFF) then Inc(I, 2)
        else
        begin
          if (Ord(C) >= $D800) and (Ord(C) <= $DFFF) then
            Error('LEX007', 'Invalid UTF-16: isolated surrogate code unit', I, 1);
          Inc(I);
        end;
      end;
      while Position < SourceLength do
      begin
        Start := Position;
        C := Peek;
        Next := Peek(1);
        Kind := tkUnknown;
        if (C = #13) or (C = #10) then
        begin
          Kind := tkNewLine;
          Inc(Position);
          if (C = #13) and (Next = #10) then Inc(Position);
        end
        else if IsHorizontalBlank(C) then
        begin
          Kind := tkWhitespace;
          repeat Inc(Position);
          until (Position = SourceLength) or not IsHorizontalBlank(Peek);
        end
        else if (C = '/') and (Next = '/') then ScanLineComment
        else if (C = '{') or ((C = '(') and (Next = '*')) then ScanBlockComment
        else if C = #39 then ScanString
        else if IsIdentifierStart(C) or ((C = '&') and IsIdentifierStart(Next)) then
        begin
          Escaped := C = '&';
          if Escaped then Inc(Position);
          Inc(Position);
          while (Position < SourceLength) and IsIdentifierPart(Peek) do Inc(Position);
          Kind := tkIdentifier;
          if not Escaped and IsReservedWord(Source, Start, Position - Start) then
            Kind := tkReservedWord;
        end
        else if IsDigit(C) or (C = '$') or (C = '%') then ScanNumber(False)
        else if C = '#' then ScanNumber(True)
        else if (Ord(C) >= $D800) and (Ord(C) <= $DFFF) then
        begin
          Inc(Position);
          if (Ord(C) <= $DBFF) and (Ord(Next) >= $DC00) and
            (Ord(Next) <= $DFFF) then
          begin
            Inc(Position);
            ConstructError('LEX005', 'Supplementary Unicode character outside literal/comment');
          end;
        end
        else ScanSymbol;
        Tokens.Add(TDelphiToken.Create(Kind, TSourceSpan.Create(Start, Position - Start)));
      end;
      Tokens.Add(TDelphiToken.Create(tkEOF, TSourceSpan.Create(SourceLength, 0)));
      Result := TDelphiLexResult.Create(Source, Tokens.ToArray, Diagnostics.ToArray);
    finally Diagnostics.Free; end;
  finally Tokens.Free; end;
end;

end.
