unit DelphiFormatter.Syntax.Nodes;

interface

uses
  DelphiFormatter.Core.Spans, DelphiFormatter.Lexer.Tokens,
  DelphiFormatter.Syntax.Kinds;

type
  // Elements are individually owned by the tree arena. Child references are
  // borrowed, immutable views; never Free an element obtained from a tree.
  TSyntaxElement = class abstract
  private
    FKind: TSyntaxKind;
    FSpan: TSourceSpan;
  protected
    constructor Create(AKind: TSyntaxKind; const ASpan: TSourceSpan);
  public
    property Kind: TSyntaxKind read FKind;
    property Span: TSourceSpan read FSpan;
  end;

  TSyntaxToken = class(TSyntaxElement)
  private
    FOriginalToken: TDelphiToken;
    FOriginalIndex: Integer;
    FExpectedText: string;
    function GetIsMissing: Boolean;
  public
    constructor CreateOriginal(const AToken: TDelphiToken; AIndex: Integer);
    constructor CreateMissing(const AExpectedText: string; AOffset: Integer);
    property OriginalToken: TDelphiToken read FOriginalToken;
    property OriginalIndex: Integer read FOriginalIndex;
    property ExpectedText: string read FExpectedText;
    property IsMissing: Boolean read GetIsMissing;
  end;

  TSyntaxNode = class(TSyntaxElement)
  private
    FChildren: TArray<TSyntaxElement>;
    function GetChildCount: Integer;
  public
    constructor Create(AKind: TSyntaxKind;
      const AChildren: TArray<TSyntaxElement>; AEmptyOffset: Integer);
    function GetChild(Index: Integer): TSyntaxElement;
    property ChildCount: Integer read GetChildCount;
  end;

implementation

constructor TSyntaxElement.Create(AKind: TSyntaxKind; const ASpan: TSourceSpan);
begin
  inherited Create;
  FKind := AKind;
  FSpan := ASpan;
end;

constructor TSyntaxToken.CreateOriginal(const AToken: TDelphiToken; AIndex: Integer);
begin
  inherited Create(skToken, AToken.Span);
  FOriginalToken := AToken;
  FOriginalIndex := AIndex;
end;

constructor TSyntaxToken.CreateMissing(const AExpectedText: string; AOffset: Integer);
begin
  inherited Create(skMissingToken, TSourceSpan.Create(AOffset, 0));
  FOriginalIndex := -1;
  FExpectedText := AExpectedText;
end;

function TSyntaxToken.GetIsMissing: Boolean;
begin
  Result := Kind = skMissingToken;
end;

constructor TSyntaxNode.Create(AKind: TSyntaxKind;
  const AChildren: TArray<TSyntaxElement>; AEmptyOffset: Integer);
var
  First, Last: Integer;
begin
  First := AEmptyOffset;
  Last := First;
  if Length(AChildren) > 0 then
  begin
    First := AChildren[0].Span.StartOffset;
    Last := AChildren[High(AChildren)].Span.EndOffset;
  end;
  inherited Create(AKind, TSourceSpan.Create(First, Last - First));
  FChildren := Copy(AChildren);
end;

function TSyntaxNode.GetChildCount: Integer;
begin
  Result := Length(FChildren);
end;

function TSyntaxNode.GetChild(Index: Integer): TSyntaxElement;
begin
  Result := FChildren[Index];
end;

end.
