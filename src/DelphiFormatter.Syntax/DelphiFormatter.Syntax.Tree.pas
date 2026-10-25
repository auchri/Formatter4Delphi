unit DelphiFormatter.Syntax.Tree;

interface

uses
  DelphiFormatter.Core.Diagnostics, DelphiFormatter.Syntax.Nodes;

type
  TSyntaxTree = class
  private
    FSource: string;
    FRoot: TSyntaxNode;
    FElements: TArray<TSyntaxElement>;
    FDiagnostics: TArray<TDiagnostic>;
    function GetDiagnosticCount: Integer;
  public
    // On successful construction takes ownership of all AElements, exactly
    // once, including ARoot. Parser arena retains ownership if creation fails.
    constructor Create(const ASource: string; ARoot: TSyntaxNode;
      const AElements: TArray<TSyntaxElement>;
      const ADiagnostics: TArray<TDiagnostic>);
    destructor Destroy; override;
    function Serialize: string;
    function GetDiagnostic(Index: Integer): TDiagnostic;
    property Source: string read FSource;
    property Root: TSyntaxNode read FRoot;
    property DiagnosticCount: Integer read GetDiagnosticCount;
  end;

implementation

uses
  System.SysUtils, System.Generics.Collections, DelphiFormatter.Lexer.Tokens;

constructor TSyntaxTree.Create(const ASource: string; ARoot: TSyntaxNode;
  const AElements: TArray<TSyntaxElement>;
  const ADiagnostics: TArray<TDiagnostic>);
begin
  inherited Create;
  FSource := ASource;
  FRoot := ARoot;
  FDiagnostics := Copy(ADiagnostics);
  // Last potentially allocating assignment: successful ownership transfer.
  FElements := Copy(AElements);
end;

destructor TSyntaxTree.Destroy;
var
  Element: TSyntaxElement;
begin
  for Element in FElements do
    Element.Free;
  inherited;
end;

function TSyntaxTree.Serialize: string;
var
  Stack: TStack<TSyntaxElement>;
  Text: TStringBuilder;
  Element: TSyntaxElement;
  Node: TSyntaxNode;
  Token: TSyntaxToken;
  I: Integer;
begin
  Stack := TStack<TSyntaxElement>.Create;
  Text := TStringBuilder.Create;
  try
    Stack.Push(FRoot);
    while Stack.Count > 0 do
    begin
      Element := Stack.Pop;
      if Element is TSyntaxNode then
      begin
        Node := TSyntaxNode(Element);
        for I := Node.ChildCount - 1 downto 0 do
          Stack.Push(Node.GetChild(I));
      end
      else
      begin
        Token := TSyntaxToken(Element);
        if not Token.IsMissing and (Token.OriginalToken.Kind <> tkEOF) then
          Text.Append(FSource, Token.Span.StartOffset, Token.Span.Length);
      end;
    end;
    Result := Text.ToString;
  finally
    Text.Free;
    Stack.Free;
  end;
end;

function TSyntaxTree.GetDiagnosticCount: Integer;
begin
  Result := Length(FDiagnostics);
end;

function TSyntaxTree.GetDiagnostic(Index: Integer): TDiagnostic;
begin
  Result := FDiagnostics[Index];
end;

end.
