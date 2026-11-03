unit DelphiFormatter.Syntax.Query;

interface

uses
  DelphiFormatter.Syntax.Nodes, DelphiFormatter.Syntax.Tree;

type
  // Borrowed role views over existing direct child shapes (design 04). They
  // never reparse source and are valid only while the tree is alive.

  // N-STMT Assignment = (Target, Operator, Value).
  TAssignmentRoles = record
    Target: TSyntaxNode;
    OperatorToken: TSyntaxToken;
    Value: TSyntaxNode;
  end;

  // N-ROUTINE with body = (Header, LocalDeclaration*, Body, FinalSemicolon).
  TRoutineRoles = record
    Header: TSyntaxNode;
    Body: TSyntaxNode;
    FinalSemicolon: TSyntaxToken;
  end;

// Original whitespace, newline and comment leaves.
function IsTriviaLeaf(Element: TSyntaxElement): Boolean;

// True only for the exact shape Target node, ':=' leaf, Value node (trivia
// leaves aside) without missing children.
function TryGetAssignmentRoles(Tree: TSyntaxTree; Node: TSyntaxNode;
  out Roles: TAssignmentRoles): Boolean;

// True only for a routine with header, optional var/const sections, block
// body and final semicolon. Interface headings, forward/external and
// recovered routines yield False.
function TryGetRoutineRoles(Tree: TSyntaxTree; Node: TSyntaxNode;
  out Roles: TRoutineRoles): Boolean;

// Original index of the first/last leaf of Element that is neither
// whitespace nor newline (comments count), or -1 when there is none.
function FirstAnchorIndex(Element: TSyntaxElement): Integer;
function LastAnchorIndex(Element: TSyntaxElement): Integer;

implementation

uses
  System.SysUtils, System.Generics.Collections, DelphiFormatter.Lexer.Tokens,
  DelphiFormatter.Syntax.Kinds;

function IsTriviaLeaf(Element: TSyntaxElement): Boolean;
begin
  Result := (Element is TSyntaxToken) and not TSyntaxToken(Element).IsMissing and
    (TSyntaxToken(Element).OriginalToken.Kind in [tkWhitespace, tkNewLine, tkComment]);
end;

function LeafText(Tree: TSyntaxTree; Token: TSyntaxToken): string;
begin
  Result := Copy(Tree.Source, Token.Span.StartOffset + 1, Token.Span.Length);
end;

function SignificantChildren(Node: TSyntaxNode): TArray<TSyntaxElement>;
var
  I, Count: Integer;
begin
  SetLength(Result, Node.ChildCount);
  Count := 0;
  for I := 0 to Node.ChildCount - 1 do
    if not IsTriviaLeaf(Node.GetChild(I)) then
    begin
      Result[Count] := Node.GetChild(I);
      Inc(Count);
    end;
  SetLength(Result, Count);
end;

function IsOriginalSymbol(Tree: TSyntaxTree; Element: TSyntaxElement;
  const Text: string): Boolean;
begin
  Result := (Element is TSyntaxToken) and not TSyntaxToken(Element).IsMissing and
    (TSyntaxToken(Element).OriginalToken.Kind = tkSymbol) and
    (LeafText(Tree, TSyntaxToken(Element)) = Text);
end;

function TryGetAssignmentRoles(Tree: TSyntaxTree; Node: TSyntaxNode;
  out Roles: TAssignmentRoles): Boolean;
var
  Parts: TArray<TSyntaxElement>;
begin
  if (Tree = nil) or (Node = nil) then
    raise EArgumentNilException.Create('Tree and node are required');
  Roles := Default(TAssignmentRoles);
  Result := False;
  if Node.Kind <> skAssignmentStatement then
    Exit;
  Parts := SignificantChildren(Node);
  if (Length(Parts) <> 3) or not (Parts[0] is TSyntaxNode) or
    not IsOriginalSymbol(Tree, Parts[1], ':=') or not (Parts[2] is TSyntaxNode) then
    Exit;
  Roles.Target := TSyntaxNode(Parts[0]);
  Roles.OperatorToken := TSyntaxToken(Parts[1]);
  Roles.Value := TSyntaxNode(Parts[2]);
  Result := True;
end;

function TryGetRoutineRoles(Tree: TSyntaxTree; Node: TSyntaxNode;
  out Roles: TRoutineRoles): Boolean;
var
  Parts: TArray<TSyntaxElement>;
  I: Integer;
begin
  if (Tree = nil) or (Node = nil) then
    raise EArgumentNilException.Create('Tree and node are required');
  Roles := Default(TRoutineRoles);
  Result := False;
  if Node.Kind <> skRoutineDeclaration then
    Exit;
  Parts := SignificantChildren(Node);
  if (Length(Parts) < 3) or (Parts[0].Kind <> skRoutineHeader) or
    (Parts[High(Parts) - 1].Kind <> skBlockStatement) or
    not IsOriginalSymbol(Tree, Parts[High(Parts)], ';') then
    Exit;
  for I := 1 to High(Parts) - 2 do
    if not (Parts[I].Kind in [skVarSection, skConstSection]) then
      Exit;
  Roles.Header := TSyntaxNode(Parts[0]);
  Roles.Body := TSyntaxNode(Parts[High(Parts) - 1]);
  Roles.FinalSemicolon := TSyntaxToken(Parts[High(Parts)]);
  Result := True;
end;

function IsAnchorLeaf(Element: TSyntaxElement): Boolean;
begin
  Result := (Element is TSyntaxToken) and not TSyntaxToken(Element).IsMissing and
    not (TSyntaxToken(Element).OriginalToken.Kind in [tkWhitespace, tkNewLine]);
end;

function EdgeAnchorIndex(Element: TSyntaxElement; FromEnd: Boolean): Integer;
var
  Stack: TStack<TSyntaxElement>;
  Current: TSyntaxElement;
  Node: TSyntaxNode;
  I: Integer;
begin
  if Element = nil then
    raise EArgumentNilException.Create('Element');
  Result := -1;
  // Iterative so deep expression chains cannot exhaust the call stack.
  Stack := TStack<TSyntaxElement>.Create;
  try
    Stack.Push(Element);
    while Stack.Count > 0 do
    begin
      Current := Stack.Pop;
      if Current is TSyntaxNode then
      begin
        Node := TSyntaxNode(Current);
        if FromEnd then
          for I := 0 to Node.ChildCount - 1 do
            Stack.Push(Node.GetChild(I))
        else
          for I := Node.ChildCount - 1 downto 0 do
            Stack.Push(Node.GetChild(I));
      end
      else if IsAnchorLeaf(Current) then
        Exit(TSyntaxToken(Current).OriginalIndex);
    end;
  finally
    Stack.Free;
  end;
end;

function FirstAnchorIndex(Element: TSyntaxElement): Integer;
begin
  Result := EdgeAnchorIndex(Element, False);
end;

function LastAnchorIndex(Element: TSyntaxElement): Integer;
begin
  Result := EdgeAnchorIndex(Element, True);
end;

end.
