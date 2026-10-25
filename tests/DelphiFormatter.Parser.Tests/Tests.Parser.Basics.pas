unit Tests.Parser.Basics;

interface

uses
  DUnitX.TestFramework, DelphiFormatter.Syntax.Kinds,
  DelphiFormatter.Syntax.Nodes, DelphiFormatter.Syntax.Tree;

type
  [TestFixture]
  TParserTests = class
  private
    function Parse(const Source: string; Mode: Integer = 0): TSyntaxTree;
    procedure Coverage(Tree: TSyntaxTree);
    function Child(Node: TSyntaxNode; Index: Integer): TSyntaxNode;
    function Count(Element: TSyntaxElement; Kind: TSyntaxKind): Integer;
    function Shape(Element: TSyntaxElement): string;
  public
    [Test] procedure MultiplicationBelowAddition;
    [Test] procedure LeftAssociativity;
    [Test] procedure DelphiWordOperators;
    [Test] procedure UnaryAndParentheses;
    [Test] procedure NestedCalls;
    [Test] procedure LiteralComponents;
    [Test] procedure AssignmentAndBlock;
    [Test] procedure EmptyStatements;
    [Test] procedure DanglingElse;
    [Test] procedure SemicolonBeforeElse;
    [Test] procedure MinimalUnit;
    [Test] procedure UsesClauses;
    [Test] procedure MissingTokens;
    [Test] procedure UnexpectedTokens;
    [Test] procedure IncompleteStatements;
    [Test] procedure TriviaAndSpans;
    [Test] procedure DirectivesAreOpaque;
    [Test] procedure UnsupportedSections;
    [Test] procedure ReaderBounds;
    [Test] procedure RetainedSourceAndDiagnostics;
    [Test] procedure DeterministicMalformedInputs;
    [Test] procedure NestingAndLongChains;
    [Test] procedure AllOperatorGroups;
    [Test] procedure ElseAfterBlock;
    [Test] procedure MalformedUsesAndMissingThen;
    [Test] procedure ArbitraryUTF16;
    [Test] procedure IndependentTrees;
    [Test] procedure UnsupportedExpressions;
    [Test] procedure LongGenericLookahead;
    [Test] procedure LongComparisonLookahead;
    [Test] procedure BooleanIdentifiers;
    [Test] procedure DirectiveEntryModes;
  end;

implementation

uses
  System.SysUtils, System.Generics.Collections,
  DelphiFormatter.Lexer.Scanner, DelphiFormatter.Lexer.Tokens,
  DelphiFormatter.Parser.Reader, DelphiFormatter.Parser.Delphi;

function TParserTests.Parse(const Source: string; Mode: Integer): TSyntaxTree;
var
  Lex: TDelphiLexResult;
begin
  Lex := TDelphiLexer.Tokenize(Source);
  try
    case Mode of
      1: Result := TDelphiParser.ParseExpression(Lex);
      2: Result := TDelphiParser.ParseStatement(Lex);
    else Result := TDelphiParser.Parse(Lex);
    end;
  finally
    Lex.Free;
  end;
  // Every test exercises the tree AFTER destruction of its original lexer.
  try Coverage(Result);
  except Result.Free; raise; end;
end;

procedure TParserTests.Coverage(Tree: TSyntaxTree);
var
  Lex: TDelphiLexResult;
  Next: Integer;
  Seen: TDictionary<TSyntaxElement, Boolean>;
  procedure Visit(Element: TSyntaxElement);
  var
    N: TSyntaxNode;
    T: TSyntaxToken;
    Original: TDelphiToken;
    I, Previous: Integer;
  begin
    Assert.IsFalse(Seen.ContainsKey(Element), 'Duplicate element');
    Seen.Add(Element, True);
    if Element is TSyntaxNode then
    begin
      N := TSyntaxNode(Element);
      Previous := N.Span.StartOffset;
      for I := 0 to N.ChildCount - 1 do
      begin
        Assert.IsTrue(N.GetChild(I).Span.StartOffset >= Previous, 'Ordered spans');
        Visit(N.GetChild(I));
        Previous := N.GetChild(I).Span.EndOffset;
      end;
      Assert.AreEqual(N.Span.EndOffset, Previous, 'Parent span union');
    end
    else
    begin
      T := TSyntaxToken(Element);
      if T.IsMissing then
      begin
        Assert.AreEqual(0, T.Span.Length);
        Assert.AreEqual(-1, T.OriginalIndex);
        Assert.IsTrue(T.ExpectedText <> '');
        Exit;
      end;
      Assert.IsTrue(Next < Lex.TokenCount);
      Original := Lex.GetToken(Next);
      Assert.AreEqual(Next, T.OriginalIndex, 'Original index');
      Assert.AreEqual(Integer(Original.Kind), Integer(T.OriginalToken.Kind));
      Assert.AreEqual(Original.Span.StartOffset, T.Span.StartOffset);
      Assert.AreEqual(Original.Span.Length, T.Span.Length);
      Inc(Next);
    end;
  end;
begin
  Lex := TDelphiLexer.Tokenize(Tree.Source);
  Seen := TDictionary<TSyntaxElement, Boolean>.Create;
  try
    Next := 0;
    Visit(Tree.Root);
    Assert.AreEqual(Lex.TokenCount, Next, 'Every original token including EOF');
    Assert.AreEqual(0, Tree.Root.Span.StartOffset);
    Assert.AreEqual(Length(Tree.Source), Tree.Root.Span.Length);
    Assert.AreEqual(Tree.Source, Tree.Serialize, 'Leaf reconstruction');
  finally
    Seen.Free;
    Lex.Free;
  end;
end;

function TParserTests.Child(Node: TSyntaxNode; Index: Integer): TSyntaxNode;
var
  I: Integer;
begin
  for I := 0 to Node.ChildCount - 1 do
    if Node.GetChild(I) is TSyntaxNode then
    begin
      if Index = 0 then Exit(TSyntaxNode(Node.GetChild(I)));
      Dec(Index);
    end;
  raise Exception.Create('Missing syntax child');
end;

function TParserTests.Count(Element: TSyntaxElement; Kind: TSyntaxKind): Integer;
var
  I: Integer;
begin
  Result := Ord(Element.Kind = Kind);
  if Element is TSyntaxNode then
    for I := 0 to TSyntaxNode(Element).ChildCount - 1 do
      Inc(Result, Count(TSyntaxNode(Element).GetChild(I), Kind));
end;

function TParserTests.Shape(Element: TSyntaxElement): string;
var
  I: Integer;
begin
  Result := Format('%d:%d:%d[', [Ord(Element.Kind), Element.Span.StartOffset,
    Element.Span.Length]);
  if Element is TSyntaxNode then
    for I := 0 to TSyntaxNode(Element).ChildCount - 1 do
      Result := Result + Shape(TSyntaxNode(Element).GetChild(I));
  Result := Result + ']';
end;

procedure TParserTests.MultiplicationBelowAddition;
var T: TSyntaxTree; N: TSyntaxNode;
begin
  T := Parse('A + B * C', 1);
  try
    N := Child(T.Root, 0);
    Assert.AreEqual(Integer(skBinaryExpression), Integer(N.Kind));
    Assert.AreEqual(Integer(skIdentifierExpression), Integer(Child(N, 0).Kind));
    Assert.AreEqual(Integer(skBinaryExpression), Integer(Child(N, 1).Kind));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.LeftAssociativity;
var T: TSyntaxTree; N: TSyntaxNode;
begin
  T := Parse('A - B - C', 1);
  try
    N := Child(T.Root, 0);
    Assert.AreEqual(Integer(skBinaryExpression), Integer(Child(N, 0).Kind));
    Assert.AreEqual(Integer(skIdentifierExpression), Integer(Child(N, 1).Kind));
    Assert.AreEqual(0, Child(N, 0).Span.StartOffset);
    Assert.AreEqual(5, Child(N, 0).Span.Length);
  finally T.Free; end;
end;

procedure TParserTests.DelphiWordOperators;
const Sources: array[0..5] of string = ('A + B shl C', 'A or B and C',
  'A + B as C', 'A = B or C', 'A is B + C', 'A xor B div C');
var S: string; T: TSyntaxTree;
begin
  for S in Sources do
  begin
    T := Parse(S, 1);
    try
      Assert.AreEqual(Integer(skBinaryExpression), Integer(Child(Child(T.Root, 0), 1).Kind));
      Assert.AreEqual(0, T.DiagnosticCount);
    finally T.Free; end;
  end;
end;

procedure TParserTests.UnaryAndParentheses;
var T: TSyntaxTree; N: TSyntaxNode;
begin
  T := Parse('-(A + B) * not C', 1);
  try
    N := Child(T.Root, 0);
    Assert.AreEqual(Integer(skUnaryExpression), Integer(Child(N, 0).Kind));
    Assert.AreEqual(Integer(skParenthesizedExpression), Integer(Child(Child(N, 0), 0).Kind));
    Assert.AreEqual(Integer(skUnaryExpression), Integer(Child(N, 1).Kind));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.NestedCalls;
var T: TSyntaxTree; N: TSyntaxNode;
begin
  T := Parse('F(A + B, G(2), H())', 1);
  try
    N := Child(T.Root, 0);
    Assert.AreEqual(Integer(skCallExpression), Integer(N.Kind));
    Assert.AreEqual(Integer(skBinaryExpression), Integer(Child(N, 1).Kind));
    Assert.AreEqual(Integer(skCallExpression), Integer(Child(N, 2).Kind));
    Assert.AreEqual(3, Count(N, skCallExpression));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.LiteralComponents;
var T: TSyntaxTree;
begin
  T := Parse('''Hi''#13#10', 1);
  try
    Assert.AreEqual(Integer(skLiteralExpression), Integer(Child(T.Root, 0).Kind));
    Assert.AreEqual(3, Child(T.Root, 0).ChildCount);
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.AssignmentAndBlock;
var T: TSyntaxTree; N: TSyntaxNode;
begin
  T := Parse('begin Result := A + B * C; if Result > 10 then DoSomething(Result); end', 2);
  try
    N := Child(T.Root, 0);
    Assert.AreEqual(Integer(skBlockStatement), Integer(N.Kind));
    Assert.AreEqual(Integer(skAssignmentStatement), Integer(Child(N, 0).Kind));
    Assert.AreEqual(Integer(skIfStatement), Integer(Child(N, 1).Kind));
    Assert.AreEqual(1, Count(N, skCallStatement));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.EmptyStatements;
var T: TSyntaxTree;
begin
  T := Parse('begin ; ; begin end; end', 2);
  try
    Assert.AreEqual(2, Count(T.Root, skEmptyStatement));
    Assert.AreEqual(2, Count(T.Root, skBlockStatement));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.DanglingElse;
var T: TSyntaxTree; OuterIf, InnerIf: TSyntaxNode;
begin
  T := Parse('if A then if B then F else G', 2);
  try
    OuterIf := Child(T.Root, 0);
    InnerIf := Child(OuterIf, 1);
    Assert.AreEqual(Integer(skIfStatement), Integer(InnerIf.Kind));
    Assert.AreEqual(9, InnerIf.Span.StartOffset,
      'Inner if starts with the trivia before if');
    Assert.AreEqual(2, Count(T.Root, skIfStatement));
    Assert.AreEqual(Integer(skCallStatement), Integer(Child(InnerIf, 2).Kind));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.SemicolonBeforeElse;
var T: TSyntaxTree;
begin
  T := Parse('begin if A then F; else G; H; end', 2);
  try
    Assert.IsTrue(T.DiagnosticCount > 0);
    Assert.AreEqual(1, Count(T.Root, skIfStatement));
    Assert.AreEqual(3, Count(T.Root, skCallStatement));
  finally T.Free; end;
end;

procedure TParserTests.MinimalUnit;
var T: TSyntaxTree;
begin
  T := Parse('unit Example; interface implementation end.');
  try
    Assert.AreEqual(Integer(skUnitDeclaration), Integer(Child(T.Root, 0).Kind));
    Assert.AreEqual(0, T.DiagnosticCount);
    Assert.AreEqual(0, Count(T.Root, skOpaqueRegion));
  finally T.Free; end;
end;

procedure TParserTests.UsesClauses;
var T: TSyntaxTree;
begin
  T := Parse('unit A.B; interface uses System.SysUtils, X in ''x.pas''; implementation uses Y; end.');
  try
    Assert.AreEqual(2, Count(T.Root, skUsesClause));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.MissingTokens;
var T: TSyntaxTree;
begin
  T := Parse('F(A + )', 1);
  try
    Assert.AreEqual(1, Count(T.Root, skMissingToken));
    Assert.AreEqual(1, T.DiagnosticCount);
    Assert.AreEqual('PAR001', T.GetDiagnostic(0).Code);
    Assert.AreEqual(6, T.GetDiagnostic(0).Span.StartOffset);
    Assert.AreEqual(1, Count(T.Root, skCallExpression));
  finally T.Free; end;
  T := Parse('unit X interface implementation end');
  try
    Assert.AreEqual(2, Count(T.Root, skMissingToken));
    Assert.AreEqual(2, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.UnexpectedTokens;
var T: TSyntaxTree;
begin
  T := Parse('A + ? + B', 1);
  try
    Assert.IsTrue(Count(T.Root, skError) > 0);
    Assert.IsTrue(T.DiagnosticCount > 0);
    Assert.AreEqual(2, Count(T.Root, skBinaryExpression));
  finally T.Free; end;
end;

procedure TParserTests.IncompleteStatements;
const Sources: array[0..7] of string = ('begin A := ; B := 2; end',
  'begin if then F else G', 'begin A := (1 + ; B := 2; end',
  'if A F', 'begin F G; end', 'begin , ; end', 'begin', '');
var S: string; T: TSyntaxTree;
begin
  for S in Sources do
  begin
    T := Parse(S, 2);
    try Assert.IsTrue(T.Root.ChildCount > 0);
    finally T.Free; end;
  end;
  T := Parse(Sources[0], 2);
  try
    Assert.AreEqual(2, Count(T.Root, skAssignmentStatement));
    Assert.AreEqual(1, Count(T.Root, skMissingToken));
  finally T.Free; end;
end;

procedure TParserTests.TriviaAndSpans;
var T: TSyntaxTree; N: TSyntaxNode;
begin
  T := Parse(' {c}'#13#10'A + B  //tail', 1);
  try
    N := Child(T.Root, 0);
    Assert.AreEqual(0, N.Span.StartOffset);
    Assert.AreEqual(11, N.Span.Length);
    Assert.AreEqual(0, T.DiagnosticCount);
    Assert.IsTrue(Count(T.Root, skToken) > 8);
  finally T.Free; end;
end;

procedure TParserTests.DirectivesAreOpaque;
const Sources: array[0..2] of string = ('A {$IFDEF X} + B {$ELSE} * C {$ENDIF}',
  '{$I file.inc} unit X; interface implementation end.', 'F((*$IFDEF X*)A(*$ENDIF*))');
var S: string; T: TSyntaxTree;
begin
  for S in Sources do
  begin
    T := Parse(S, 1);
    try
      Assert.AreEqual(Integer(skOpaqueRegion), Integer(Child(T.Root, 0).Kind));
      Assert.AreEqual(0, Count(T.Root, skBinaryExpression));
      Assert.AreEqual('PAR003', T.GetDiagnostic(0).Code);
    finally T.Free; end;
  end;
end;

procedure TParserTests.UnsupportedSections;
var T: TSyntaxTree;
begin
  T := Parse('unit X; interface type T = class end; implementation procedure F; begin end; end. trailing');
  try
    Assert.AreEqual(3, Count(T.Root, skOpaqueRegion));
    Assert.AreEqual(1, Count(T.Root, skUnitDeclaration));
    Assert.AreEqual(0, Count(T.Root, skBlockStatement));
  finally T.Free; end;
  T := Parse('begin while A do begin F; G end; H; end', 2);
  try
    Assert.AreEqual(1, Count(T.Root, skOpaqueRegion));
    Assert.AreEqual(1, Count(T.Root, skCallStatement));
  finally T.Free; end;
end;

procedure TParserTests.ReaderBounds;
var L: TDelphiLexResult; R: TTokenReader;
  A: TObjectList<TSyntaxElement>; C: TList<TSyntaxElement>;
begin
  L := TDelphiLexer.Tokenize(' {c} A {$I x}');
  R := TTokenReader.Create(L);
  A := TObjectList<TSyntaxElement>.Create(True);
  C := TList<TSyntaxElement>.Create;
  try
    Assert.IsTrue(R.Matches('a'));
    Assert.AreEqual(R.SignificantIndex, R.SignificantIndex(-100));
    Assert.AreEqual(Integer(tkEOF), Integer(R.PeekSignificant(High(Integer)).Kind));
    R.ConsumeWithTriviaInto(C, A);
    Assert.AreEqual(Integer(tkCompilerDirective), Integer(R.PeekSignificant.Kind));
    Assert.IsFalse(R.AtEOF);
    R.ConsumeWithTriviaInto(C, A);
    Assert.IsTrue(R.AtEOF);
    R.ConsumeWithTriviaInto(C, A);
    R.ConsumeWithTriviaInto(C, A);
    Assert.AreEqual(L.TokenCount, Integer(C.Count));
  finally C.Free; A.Free; R.Free; L.Free; end;
end;

procedure TParserTests.RetainedSourceAndDiagnostics;
var T: TSyntaxTree; I: Integer;
begin
  for I := 1 to 100 do
  begin
    T := Parse('A + '#0 + Char($D800), 1);
    try
      Assert.IsTrue(T.DiagnosticCount >= 2);
      Assert.AreEqual<string>('A + '#0 + Char($D800), T.Serialize);
      Assert.IsTrue(Count(T.Root, skBinaryExpression) > 0);
    finally T.Free; end;
  end;
end;

procedure TParserTests.DeterministicMalformedInputs;
const Parts: array[0..19] of string = ('A', ' ', 'begin', 'end', 'if', 'then',
  'else', ';', '(', ')', ':=', '+', '*', ',', 'uses', '.', '{c}', #13#10, '?', '1');
var Seed: UInt64; I, J, K, Mode: Integer; S: string; A, B: TSyntaxTree;
begin
  Seed := $4D322E31;
  for I := 0 to 299 do
  begin
    S := '';
    for J := 0 to I mod 35 do
    begin
      Seed := (Seed * UInt64(1664525) + UInt64(1013904223)) and UInt64($FFFFFFFF);
      K := Integer(Seed mod UInt64(Length(Parts)));
      S := S + Parts[K] + ' ';
    end;
    Mode := I mod 3;
    A := Parse(S, Mode);
    try
      B := Parse(S, Mode);
      try
        Assert.AreEqual(Shape(A.Root), Shape(B.Root));
        Assert.AreEqual(A.DiagnosticCount, B.DiagnosticCount);
        for J := 0 to A.DiagnosticCount - 1 do
        begin
          Assert.AreEqual(A.GetDiagnostic(J).Code, B.GetDiagnostic(J).Code);
          Assert.AreEqual(A.GetDiagnostic(J).Message, B.GetDiagnostic(J).Message);
          Assert.AreEqual(A.GetDiagnostic(J).Span.StartOffset, B.GetDiagnostic(J).Span.StartOffset);
          Assert.AreEqual(A.GetDiagnostic(J).Span.Length, B.GetDiagnostic(J).Span.Length);
        end;
      finally B.Free; end;
    finally A.Free; end;
  end;
end;

procedure TParserTests.NestingAndLongChains;
var S: string; I: Integer; T: TSyntaxTree;
begin
  S := StringOfChar('(', 400) + 'A' + StringOfChar(')', 400);
  T := Parse(S, 1);
  try Assert.IsTrue(T.DiagnosticCount > 0);
  finally T.Free; end;
  S := 'A';
  for I := 1 to 300 do S := S + ' + A';
  T := Parse(S, 1);
  try
    Assert.AreEqual(300, Count(T.Root, skBinaryExpression));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.AllOperatorGroups;
const Operators: array[0..19] of string = ('*', '/', 'div', 'mod', 'and',
  'shl', 'shr', 'as', '+', '-', 'or', 'xor', '=', '<>', '<', '>', '<=', '>=', 'in', 'is');
var Op: string; T: TSyntaxTree; N: TSyntaxNode;
begin
  for Op in Operators do
  begin
    T := Parse('A ' + Op + ' B ' + Op + ' C', 1);
    try
      N := Child(T.Root, 0);
      Assert.AreEqual(Integer(skBinaryExpression), Integer(N.Kind));
      Assert.AreEqual(Integer(skBinaryExpression), Integer(Child(N, 0).Kind));
      Assert.AreEqual(Integer(skIdentifierExpression), Integer(Child(N, 1).Kind));
      Assert.AreEqual(0, T.DiagnosticCount);
    finally T.Free; end;
  end;
end;

procedure TParserTests.ElseAfterBlock;
var T: TSyntaxTree; N: TSyntaxNode;
begin
  T := Parse('begin if A then begin if B then F; end else G; H end', 2);
  try
    N := Child(Child(T.Root, 0), 0);
    Assert.AreEqual(Integer(skIfStatement), Integer(N.Kind));
    Assert.AreEqual(Integer(skBlockStatement), Integer(Child(N, 1).Kind));
    Assert.AreEqual(Integer(skCallStatement), Integer(Child(N, 2).Kind));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.MalformedUsesAndMissingThen;
var T: TSyntaxTree;
begin
  T := Parse('unit X; interface uses A, ; implementation uses ; end.');
  try
    Assert.AreEqual(2, Count(T.Root, skUsesClause));
    Assert.AreEqual(2, Count(T.Root, skMissingToken));
    Assert.AreEqual(2, T.DiagnosticCount);
  finally T.Free; end;
  T := Parse('if A F', 2);
  try
    Assert.AreEqual(1, Count(T.Root, skIfStatement));
    Assert.AreEqual(1, Count(T.Root, skCallStatement));
    Assert.AreEqual(1, T.DiagnosticCount);
    Assert.AreEqual('Expected then', T.GetDiagnostic(0).Message);
  finally T.Free; end;
end;

procedure TParserTests.ArbitraryUTF16;
var Seed: UInt64; S: string; I, J: Integer; T: TSyntaxTree;
begin
  Seed := $554E4943;
  for I := 0 to 199 do
  begin
    S := '';
    for J := 0 to I mod 40 do
    begin
      Seed := (Seed * UInt64(1664525) + UInt64(1013904223)) and UInt64($FFFFFFFF);
      S := S + Char(Seed and $FFFF);
    end;
    T := Parse(S, I mod 3);
    try Assert.AreEqual(Length(S), T.Root.Span.Length);
    finally T.Free; end;
  end;
end;

procedure TParserTests.IndependentTrees;
var L: TDelphiLexResult; A, B: TSyntaxTree;
begin
  L := TDelphiLexer.Tokenize('A + B * C');
  try
    A := TDelphiParser.ParseExpression(L);
    try B := TDelphiParser.ParseExpression(L);
    except A.Free; raise; end;
  finally L.Free; end;
  try
    Assert.AreEqual(Shape(A.Root), Shape(B.Root));
    Assert.IsFalse(A.Root = B.Root);
    A.Free;
    A := nil;
    Coverage(B);
    Assert.AreEqual('A + B * C', B.Serialize);
  finally A.Free; B.Free; end;
end;

procedure TParserTests.UnsupportedExpressions;
const Sources: array[0..3] of string = ('Foo<T>(A)', 'A.B', 'A[0]', 'F(G<T,U>(A), B)');
var S: string; T: TSyntaxTree;
begin
  for S in Sources do
  begin
    T := Parse(S, 1);
    try
      Assert.IsTrue(Count(T.Root, skOpaqueRegion) > 0);
      Assert.IsTrue(T.DiagnosticCount > 0);
      Assert.AreEqual(0, Count(T.Root, skBinaryExpression));
    finally T.Free; end;
  end;
end;

procedure TParserTests.LongGenericLookahead;
var Builder: TStringBuilder; S: string; I: Integer; T, Again: TSyntaxTree;
begin
  Builder := TStringBuilder.Create;
  try
    Builder.Append('F<');
    for I := 1 to 1024 do Builder.Append(' {gap} '#13#10' G<');
    Builder.Append('T');
    S := Builder.ToString; // many unclosed angles at EOF
    T := Parse(S, 1);
    try
      Assert.AreEqual(0, Count(T.Root, skOpaqueRegion));
      Assert.AreEqual(1025, Count(T.Root, skBinaryExpression));
      Assert.AreEqual(0, T.DiagnosticCount); // also a syntactic comparison chain
    finally T.Free; end;
    for I := 1 to 1025 do Builder.Append('> {after} '#9);
    Builder.Append('(A)');
    S := Builder.ToString;
    T := Parse(S, 1);
    try
      Assert.AreEqual(1, Count(T.Root, skOpaqueRegion));
      Assert.AreEqual(0, Count(T.Root, skBinaryExpression));
      Assert.AreEqual(1, T.DiagnosticCount);
      Again := Parse(S, 1);
      try Assert.AreEqual(Shape(T.Root), Shape(Again.Root));
      finally Again.Free; end;
    finally T.Free; end;
  finally Builder.Free; end;
end;

procedure TParserTests.LongComparisonLookahead;
var Builder: TStringBuilder; I: Integer; T: TSyntaxTree;
begin
  Builder := TStringBuilder.Create;
  try
    Builder.Append('A');
    for I := 1 to 768 do
      Builder.Append(' {one} '#13#10' (*two*) '#9'< {three} B');
    T := Parse(Builder.ToString, 1);
    try
      Assert.AreEqual(768, Count(T.Root, skBinaryExpression));
      Assert.AreEqual(769, Count(T.Root, skIdentifierExpression));
      Assert.AreEqual(0, Count(T.Root, skOpaqueRegion));
      Assert.AreEqual(0, T.DiagnosticCount);
    finally T.Free; end;
    Builder.Append(' < {missing operand} ');
    T := Parse(Builder.ToString, 1);
    try
      Assert.AreEqual(769, Count(T.Root, skBinaryExpression));
      Assert.AreEqual(1, Count(T.Root, skMissingToken));
      Assert.AreEqual(1, T.DiagnosticCount);
      Assert.AreEqual('PAR001', T.GetDiagnostic(0).Code);
    finally T.Free; end;
  finally Builder.Free; end;
end;

procedure TParserTests.BooleanIdentifiers;
const Names: array[0..7] of string = ('True', 'False', 'true', 'false',
  'TRUE', 'FALSE', 'tRuE', 'fAlSe');
var Name: string; T: TSyntaxTree; N: TSyntaxNode;
begin
  for Name in Names do
  begin
    T := Parse(Name, 1);
    try
      N := Child(T.Root, 0);
      Assert.AreEqual(Integer(skIdentifierExpression), Integer(N.Kind));
      Assert.AreEqual(Integer(tkIdentifier),
        Integer(TSyntaxToken(N.GetChild(0)).OriginalToken.Kind));
      Assert.AreEqual(0, Count(T.Root, skLiteralExpression));
      Assert.AreEqual(0, T.DiagnosticCount);
    finally T.Free; end;
  end;
  T := Parse('not tRuE or FaLsE and True', 1);
  try
    N := Child(T.Root, 0);
    Assert.AreEqual(Integer(skBinaryExpression), Integer(N.Kind));
    Assert.AreEqual(Integer(skUnaryExpression), Integer(Child(N, 0).Kind));
    Assert.AreEqual(Integer(skBinaryExpression), Integer(Child(N, 1).Kind));
    Assert.AreEqual(3, Count(T.Root, skIdentifierExpression));
    Assert.AreEqual(0, Count(T.Root, skLiteralExpression));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.DirectiveEntryModes;
const Sources: array[0..2] of string = (' {$R *.res} '#13#10'A + True',
  '{$IFDEF X}begin F;{$ELSE}False + {$ENDIF}',
  '(*$I file.inc*) '#9 + Char($D800));
var S: string; Mode: Integer; T: TSyntaxTree;
begin
  for S in Sources do
    for Mode := 0 to 2 do
    begin
      T := Parse(S, Mode);
      try
        Assert.AreEqual(Integer(skOpaqueRegion), Integer(Child(T.Root, 0).Kind));
        Assert.AreEqual(1, Count(T.Root, skOpaqueRegion));
        Assert.AreEqual(0, Count(T.Root, skBinaryExpression));
        Assert.AreEqual(0, Count(T.Root, skMissingToken));
      finally T.Free; end;
    end;
end;

initialization
  TDUnitX.RegisterTestFixture(TParserTests);

end.
