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
begin
  inherited Create;
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
  Result := Copy(FSource, Token.Span.StartOffset + 1, Token.Span.Length);
end;

function TDelphiLexResult.GetDiagnostic(Index: Integer): TDiagnostic;
begin
  if (Index < 0) or (Index >= DiagnosticCount) then
    raise EArgumentOutOfRangeException.Create('Diagnostic index out of range');
  Result := FDiagnostics[Index];
end;

end.
