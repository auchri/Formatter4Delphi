unit DelphiFormatter.Lexer.Tokens;

interface

uses
  DelphiFormatter.Core.Spans,
  DelphiFormatter.Core.Diagnostics;

type
  TTokenKind = (tkIdentifier, tkReservedWord, tkNumber, tkStringLiteral,
    tkCharCode, tkSymbol, tkCompilerDirective, tkComment, tkWhitespace,
    tkNewLine, tkUnknown, tkEOF);

  TDelphiToken = record
    Kind: TTokenKind;
    Span: TSourceSpan;
    constructor Create(AKind: TTokenKind; const ASpan: TSourceSpan);
  end;

  TDelphiLexResult = class
  private
    FSource: string;
    FTokens: TArray<TDelphiToken>;
    FDiagnostics: TArray<TDiagnostic>;
    function GetTokenCount: Integer;
    function GetDiagnosticCount: Integer;
  public
    constructor Create(const ASource: string;
      const ATokens: TArray<TDelphiToken>;
      const ADiagnostics: TArray<TDiagnostic>);
    function GetToken(Index: Integer): TDelphiToken;
    function TokenText(Index: Integer): string;
    function GetDiagnostic(Index: Integer): TDiagnostic;
    property Source: string read FSource;
    property TokenCount: Integer read GetTokenCount;
    property DiagnosticCount: Integer read GetDiagnosticCount;
  end;

implementation

uses
  System.SysUtils;

constructor TDelphiToken.Create(AKind: TTokenKind; const ASpan: TSourceSpan);
begin
  Kind := AKind;
  Span := ASpan;
end;

constructor TDelphiLexResult.Create(const ASource: string;
  const ATokens: TArray<TDelphiToken>;
  const ADiagnostics: TArray<TDiagnostic>);
var
  I, Offset: Integer;
  Token: TDelphiToken;
begin
  inherited Create;
  // Reject invalid caller-supplied streams before retaining them. Lexical
  // errors belong in diagnostics; broken result construction is API misuse.
  if Length(ATokens) = 0 then
    raise EArgumentException.Create('Token stream must contain EOF');
  Offset := 0;
  for I := 0 to High(ATokens) do
  begin
    Token := ATokens[I];
    if (Token.Span.StartOffset <> Offset) or
      (Token.Span.EndOffset > Length(ASource)) then
      raise EArgumentException.Create('Token spans must cover the source contiguously');
    if Token.Kind = tkEOF then
    begin
      if (I <> High(ATokens)) or (Token.Span.Length <> 0) or
        (Offset <> Length(ASource)) then
        raise EArgumentException.Create('EOF must end the stream at source length');
    end
    else if (Token.Span.Length = 0) or (I = High(ATokens)) then
      raise EArgumentException.Create('Nonempty tokens must be followed by EOF');
    Offset := Token.Span.EndOffset;
  end;
  for I := 0 to High(ADiagnostics) do
    if ADiagnostics[I].Span.EndOffset > Length(ASource) then
      raise EArgumentException.Create('Diagnostic span exceeds source length');
  FSource := ASource;
  FTokens := Copy(ATokens);
  FDiagnostics := Copy(ADiagnostics);
end;

function TDelphiLexResult.GetTokenCount: Integer;
begin
  Result := Length(FTokens);
end;

function TDelphiLexResult.GetDiagnosticCount: Integer;
begin
  Result := Length(FDiagnostics);
end;

function TDelphiLexResult.GetToken(Index: Integer): TDelphiToken;
begin
  if (Index < 0) or (Index >= TokenCount) then
    raise EArgumentOutOfRangeException.Create('Token index out of range');
  Result := FTokens[Index];
end;

function TDelphiLexResult.TokenText(Index: Integer): string;
var
  Token: TDelphiToken;
begin
  Token := GetToken(Index);
  if Token.Span.Length = 0 then
    Exit('');
  Result := Copy(FSource, Token.Span.StartOffset + 1, Token.Span.Length);
end;

function TDelphiLexResult.GetDiagnostic(Index: Integer): TDiagnostic;
begin
  if (Index < 0) or (Index >= DiagnosticCount) then
    raise EArgumentOutOfRangeException.Create('Diagnostic index out of range');
  Result := FDiagnostics[Index];
end;

end.
