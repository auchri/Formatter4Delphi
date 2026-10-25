unit DelphiFormatter.Parser.Reader;

interface

uses
  System.Generics.Collections, DelphiFormatter.Lexer.Tokens,
  DelphiFormatter.Syntax.Nodes;

type
  // Borrows the validated lexer result only for the duration of parsing.
  TTokenReader = class
  private
    FLex: TDelphiLexResult;
    FPosition: Integer;
  public
    constructor Create(ALex: TDelphiLexResult);
    class function IsTrivia(AKind: TTokenKind): Boolean; static;
    function SignificantIndex(Lookahead: Integer = 0): Integer;
    function PeekSignificant(Lookahead: Integer = 0): TDelphiToken;
    function Matches(const Text: string; Lookahead: Integer = 0): Boolean;
    function AtEOF: Boolean;
    procedure ConsumeWithTriviaInto(Children: TList<TSyntaxElement>;
      Arena: TObjectList<TSyntaxElement>);
    property Position: Integer read FPosition;
  end;

implementation

uses
  System.SysUtils;

constructor TTokenReader.Create(ALex: TDelphiLexResult);
begin
  inherited Create;
  if ALex = nil then
    raise EArgumentNilException.Create('ALex');
  FLex := ALex;
end;

class function TTokenReader.IsTrivia(AKind: TTokenKind): Boolean;
begin
  Result := AKind in [tkWhitespace, tkNewLine, tkComment];
end;

function TTokenReader.SignificantIndex(Lookahead: Integer): Integer;
begin
  Result := FPosition;
  if Result >= FLex.TokenCount then
    Exit(FLex.TokenCount - 1);
  if Lookahead < 0 then
    Lookahead := 0;
  while Result < FLex.TokenCount - 1 do
  begin
    if not IsTrivia(FLex.GetToken(Result).Kind) then
    begin
      if Lookahead = 0 then
        Exit;
      Dec(Lookahead);
    end;
    Inc(Result);
  end;
end;

function TTokenReader.PeekSignificant(Lookahead: Integer): TDelphiToken;
begin
  Result := FLex.GetToken(SignificantIndex(Lookahead));
end;

function TTokenReader.Matches(const Text: string; Lookahead: Integer): Boolean;
var
  Index: Integer;
  Token: TDelphiToken;
begin
  Index := SignificantIndex(Lookahead);
  Token := FLex.GetToken(Index);
  Result := (Token.Kind in [tkIdentifier, tkReservedWord, tkSymbol]) and
    SameText(FLex.TokenText(Index), Text);
end;

function TTokenReader.AtEOF: Boolean;
begin
  Result := PeekSignificant.Kind = tkEOF;
end;

procedure TTokenReader.ConsumeWithTriviaInto(Children: TList<TSyntaxElement>;
  Arena: TObjectList<TSyntaxElement>);
var
  Last: Integer;
  Leaf: TSyntaxToken;
begin
  if FPosition >= FLex.TokenCount then
    Exit;
  Last := SignificantIndex;
  while FPosition <= Last do
  begin
    Leaf := TSyntaxToken.CreateOriginal(FLex.GetToken(FPosition), FPosition);
    Arena.Add(Leaf);
    Children.Add(Leaf);
    Inc(FPosition);
  end;
end;

end.
