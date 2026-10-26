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
    procedure CheckOpaqueBody(const Body: string);
    procedure SameDiagnostics(A, B: TSyntaxTree);
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
    [Test] procedure Declarations;
    [Test] procedure RoutineHierarchy;
    [Test] procedure ParameterGroups;
    [Test] procedure EmptyAndQualifiedRoutines;
    [Test] procedure LocalDeclarations;
    [Test] procedure TypeRecovery;
    [Test] procedure DeclarationErrors;
    [Test] procedure RoutineErrors;
    [Test] procedure ResourceDirectives;
    [Test] procedure UnsafeResources;
    [Test] procedure CompiledDeclarationCorpus;
    [Test] procedure DeclarationDeterminism;
    [Test] procedure UnsupportedParameterTypes;
    [Test] procedure DeclarationRecoveryBoundaries;
    [Test] procedure OpaqueProceduralParameters;
    [Test] procedure DeclarationLifetimes;
    [Test] procedure MemberHierarchy;
    [Test] procedure QualifiedAndEscapedMembers;
    [Test] procedure PostfixTrivia;
    [Test] procedure IndexHierarchy;
    [Test] procedure MultipleAndComplexIndices;
    [Test] procedure AlternativeIndexBrackets;
    [Test] procedure DereferenceHierarchy;
    [Test] procedure MixedPostfixChains;
    [Test] procedure PostfixPrecedence;
    [Test] procedure DesignatorAssignments;
    [Test] procedure InvalidAssignmentTargets;
    [Test] procedure MemberCallStatements;
    [Test] procedure PostfixRecovery;
    [Test] procedure QualifiedGenericFallback;
    [Test] procedure PostfixDirectives;
    [Test] procedure LongPostfixChains;
    [Test] procedure PostfixDeterminism;
    [Test] procedure PostfixLifetimes;
    [Test] procedure CompiledPostfixCorpus;
    [Test] procedure SyntaxKindOrdinals;
    [Test] procedure TypeSectionHierarchy;
    [Test] procedure MixedTypeDeclarations;
    [Test] procedure MultipleTypeSections;
    [Test] procedure ClassAncestors;
    [Test] procedure ClassVisibility;
    [Test] procedure AggregateFields;
    [Test] procedure AggregateMethods;
    [Test] procedure MethodDirectives;
    [Test] procedure OpaqueProperties;
    [Test] procedure PropertySpecifiers;
    [Test] procedure PropertyArrays;
    [Test] procedure PropertyHierarchy;
    [Test] procedure PropertyRedeclarations;
    [Test] procedure PropertyRecovery;
    [Test] procedure PropertyFieldBoundaryRecovery;
    [Test] procedure PropertyFollowingPropertyRecovery;
    [Test] procedure PropertyBoundaryValidDeclarations;
    [Test] procedure PropertyStress;
    [Test] procedure CompiledPropertyCorpus;
    [Test] procedure UnsupportedAggregates;
    [Test] procedure AggregateRecovery;
    [Test] procedure AggregateDeterminism;
    [Test] procedure AggregateLifetimes;
    [Test] procedure CompiledClassRecordCorpus;
    [Test] procedure OpaqueMemberTypeKeywords;
    [Test] procedure NestedOpaqueTypeBoundaries;
    [Test] procedure LongFieldLookahead;
    [Test] procedure LongAncestorLookahead;
    [Test] procedure TypeLookaheadRecovery;
    [Test] procedure ControlLoops;
    [Test] procedure ControlHierarchy;
    [Test] procedure ControlCases;
    [Test] procedure ControlExceptions;
    [Test] procedure ControlElseBinding;
    [Test] procedure ControlRecovery;
    [Test] procedure ControlRoutineRecovery;
    [Test] procedure ControlDirectives;
    [Test] procedure ControlStress;
    [Test] procedure ControlDepth;
    [Test] procedure ControlMalformedLifetimes;
    [Test] procedure CompiledControlFlowCorpus;
    [Test] procedure ControlHandlerRecovery;
    [Test] procedure ControlSeparatorsAndTrivia;
    [Test] procedure ControlOpaqueFallback;
    [Test] procedure OpaqueWithBodies;
    [Test] procedure OpaqueInlineForBodies;
    [Test] procedure OpaqueElseOwnership;
    [Test] procedure OpaqueMalformedStatements;
    [Test] procedure OpaqueKeywordTrivia;
    [Test] procedure OpaqueUnsupportedStress;
    [Test] procedure OpaqueUnsupportedDirectives;
    [Test] procedure OpaqueUnsupportedDepthAndLifetimes;


  end;

implementation

uses
  System.SysUtils, System.IOUtils, System.Generics.Collections,
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
    Assert.AreEqual(1, Count(T.Root, skOpaqueRegion));
    Assert.AreEqual(1, Count(T.Root, skClassDeclaration));
    Assert.AreEqual(1, Count(T.Root, skUnitDeclaration));
    Assert.AreEqual(1, Count(T.Root, skBlockStatement));
  finally T.Free; end;
  T := Parse('begin while A do begin F; G end; H; end', 2);
  try
    Assert.AreEqual(0, Count(T.Root, skOpaqueRegion));
    Assert.AreEqual(1, Count(T.Root, skWhileStatement));
    Assert.AreEqual(3, Count(T.Root, skCallStatement));
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
const Sources: array[0..1] of string = ('Foo<T>(A)', 'F(G<T,U>(A), B)');
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

procedure TParserTests.OpaqueProceduralParameters;
var T: TSyntaxTree;
begin
  T := Parse('unit X; interface procedure P(A: procedure(X: Integer) of object; '+
    'B: reference to function: Integer); procedure Q; implementation end.');
  try
    Assert.AreEqual(2, Count(T.Root, skRoutineDeclaration));
    Assert.AreEqual(2, Count(T.Root, skParameterDeclaration));
    Assert.IsTrue(Count(T.Root, skOpaqueRegion) >= 2);
  finally T.Free; end;
end;

procedure TParserTests.DeclarationLifetimes;
var I: Integer; T: TSyntaxTree;
begin
  for I := 0 to 99 do
  begin
    T := Parse('unit X; interface const A=2; procedure P; implementation '+
      'procedure P; var V: Integer; begin V := A; end; end.' + Char($D800));
    try
      Assert.AreEqual(2, Count(T.Root, skRoutineDeclaration));
      Assert.IsTrue(T.DiagnosticCount > 0);
    finally T.Free; end;
  end;
end;

procedure TParserTests.DeclarationRecoveryBoundaries;
const Bad: array[0..4] of string = ('const A = ', 'const A = 1 ',
  'var A: ', 'var A: array[0..2] of Integer; B: Integer; ',
  'type T = class procedure Hidden; ');
var S: string; T: TSyntaxTree;
begin
  for S in Bad do
  begin
    T := Parse('unit X; interface '+S+' implementation procedure Good; begin end; end.');
    try
      Assert.AreEqual(1, Count(T.Root, skRoutineDeclaration));
      Assert.AreEqual(1, Count(T.Root, skBlockStatement));
      Assert.IsTrue(T.DiagnosticCount > 0);
    finally T.Free; end;
  end;
end;

procedure TParserTests.Declarations;
var T: TSyntaxTree; U: TSyntaxNode;
begin
  T := Parse('unit X; interface const Max = 100; Name = ''App''; '+
    'Timeout: System.Integer = 30; var A, B: Double; Enabled: Boolean = True; '+
    'implementation var Counter: Integer; const Version = 1; end.');
  try
    U := Child(T.Root, 0);
    Assert.AreEqual(2, Count(U, skConstSection));
    Assert.AreEqual(4, Count(U, skConstDeclaration));
    Assert.AreEqual(2, Count(U, skVarSection));
    Assert.AreEqual(3, Count(U, skVarDeclaration));
    Assert.AreEqual(4, Count(U, skTypeReference));
    Assert.AreEqual(Integer(skConstSection), Integer(Child(U, 0).Kind));
    Assert.AreEqual(Integer(skConstDeclaration), Integer(Child(Child(U, 0), 0).Kind));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.RoutineHierarchy;
var T: TSyntaxTree; U, R, H: TSyntaxNode;
begin
  T := Parse('unit X; interface function Add(A, B: Integer): Integer; '+
    'procedure Reset; implementation function Add(A, B: Integer): Integer; '+
    'begin Result := A + B; end; procedure Reset; begin end; end.');
  try
    U := Child(T.Root, 0);
    Assert.AreEqual(4, Count(U, skRoutineDeclaration));
    Assert.AreEqual(2, Count(U, skBlockStatement));
    Assert.AreEqual(2, Count(U, skReturnType));
    Assert.AreEqual(0, Count(Child(U, 0), skBlockStatement));
    R := Child(U, 2); H := Child(R, 0);
    Assert.AreEqual(Integer(skRoutineHeader), Integer(H.Kind));
    Assert.AreEqual(Integer(skParameterList), Integer(Child(H, 0).Kind));
    Assert.AreEqual(Integer(skReturnType), Integer(Child(H, 1).Kind));
    Assert.AreEqual(Integer(skBlockStatement), Integer(Child(R, 1).Kind));
    Assert.AreEqual(1, Count(R, skBinaryExpression));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.ParameterGroups;
var T: TSyntaxTree;
begin
  T := Parse('unit X; interface procedure P(A,B: Integer; const Name: string; '+
    'var Counter: System.Integer; out Success: Boolean; N: Integer = 2); '+
    'procedure Empty(); implementation end.');
  try
    Assert.AreEqual(2, Count(T.Root, skParameterList));
    Assert.AreEqual(5, Count(T.Root, skParameterDeclaration));
    Assert.AreEqual(5, Count(T.Root, skTypeReference));
    Assert.AreEqual(0, Count(T.Root, skReturnType));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.EmptyAndQualifiedRoutines;
var T: TSyntaxTree;
begin
  T := Parse('unit X; interface implementation procedure TCalc.Reset; begin end; '+
    'function TCalc.Add(A: Integer): System.Integer; begin Result := A; end; end.');
  try
    Assert.AreEqual(2, Count(T.Root, skRoutineDeclaration));
    Assert.AreEqual(2, Count(T.Root, skBlockStatement));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.LocalDeclarations;
var T: TSyntaxTree; R: TSyntaxNode;
begin
  T := Parse('unit X; interface implementation function Calculate(A,B: Integer): Integer; '+
    'const Multiplier = 2; var Temp: Integer; begin Temp := A+B; '+
    'if Temp > 0 then begin Result := Temp*Multiplier; end else Result := 0; end; end.');
  try
    R := Child(Child(T.Root, 0), 0);
    Assert.AreEqual(Integer(skConstSection), Integer(Child(R, 1).Kind));
    Assert.AreEqual(Integer(skVarSection), Integer(Child(R, 2).Kind));
    Assert.AreEqual(Integer(skBlockStatement), Integer(Child(R, 3).Kind));
    Assert.AreEqual(3, Count(R, skAssignmentStatement));
    Assert.AreEqual(1, Count(R, skIfStatement));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.TypeRecovery;
const Types: array[0..6] of string = (
  'type T = class procedure Member; type TInner = record X: Integer; end; end; ',
  'type T = class; TRef = class of TObject; ',
  'type T = record A: array[0..1] of Integer; end; ',
  'type T = interface procedure Member; end; ',
  'type T = class class procedure Member; class var X: Integer; end; ',
  'type T = record case Boolean of True: (X: Integer); False: (Y: Double); end; ',
  'type TCallback = procedure(A: Integer); TFunc = function: Integer; ');
var S: string; T: TSyntaxTree;
begin
  for S in Types do
  begin
    T := Parse('unit X; interface '+S+'procedure P; implementation '+
      'procedure P; begin end; threadvar X: Integer; procedure Q; begin end; end.');
    try
      Assert.AreEqual(3, Count(T.Root, skRoutineDeclaration));
      Assert.AreEqual(2, Count(T.Root, skBlockStatement));
      Assert.IsTrue(Count(T.Root, skOpaqueRegion) >= 2);
    finally T.Free; end;
  end;
end;

procedure TParserTests.DeclarationErrors;
const Bad: array[0..5] of string = (': Integer;', 'A Integer;', 'A: ;',
  'A: Integer B: Integer;', 'A: Integer = ;', 'A: array[0..2] of Integer;');
var S: string; T: TSyntaxTree;
begin
  for S in Bad do
  begin
    T := Parse('unit X; interface var '+S+' procedure P; implementation end.');
    try
      Assert.IsTrue(T.DiagnosticCount > 0);
      Assert.AreEqual(1, Count(T.Root, skRoutineDeclaration));
      Assert.IsTrue(Count(T.Root, skVarDeclaration) > 0);
    finally T.Free; end;
  end;
end;

procedure TParserTests.RoutineErrors;
const Bad: array[0..6] of string = ('procedure Bad(A: Integer; ',
  'function Bad: ; ', 'procedure Bad; ', 'procedure Bad; begin A := 1; ',
  'procedure Bad; var A: Integer; ', 'procedure Bad ',
  'procedure Bad; A := 1; ');
var S: string; T: TSyntaxTree;
begin
  for S in Bad do
  begin
    T := Parse('unit X; interface implementation '+S+
      'procedure Good; begin end; end.');
    try
      Assert.AreEqual(2, Count(T.Root, skRoutineDeclaration));
      Assert.IsTrue(T.DiagnosticCount > 0);
    finally T.Free; end;
  end;
  T := Parse('unit X; interface implementation procedure P; begin A := 1; end.');
  try
    Assert.AreEqual(1, Count(T.Root, skRoutineDeclaration));
    Assert.IsTrue(Count(T.Root, skMissingToken) >= 2);
  finally T.Free; end;
  T := Parse('unit X; interface implementation function P(A: Integer');
  try Assert.IsTrue(T.DiagnosticCount > 0);
  finally T.Free; end;
end;

procedure TParserTests.ResourceDirectives;
var T: TSyntaxTree;
begin
  T := Parse('unit X; interface procedure P; implementation'#13#10+
    '{$R *.dfm}'#13#10+'procedure P; begin end;'#13#10+
    '(*$RESOURCE sample.res*)'#13#10+'procedure Q; begin end; end.');
  try
    Assert.AreEqual(3, Count(T.Root, skRoutineDeclaration));
    Assert.AreEqual(2, Count(T.Root, skDirective));
    Assert.AreEqual(0, Count(T.Root, skOpaqueRegion));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.UnsafeResources;
const Bodies: array[0..3] of string = (
  'procedure P; begin'#13#10'{$R x.res}'#13#10'end;',
  'procedure P(A:'#13#10'{$R x.res}'#13#10'Integer); begin end;',
  '{$R x.res} procedure P; begin end;',
  '{$IFDEF X} procedure P; {$ENDIF}');
var S: string; T: TSyntaxTree;
begin
  for S in Bodies do
  begin
    T := Parse('unit X; interface implementation'#13#10+S+#13#10+'end.');
    try
      Assert.AreEqual(Integer(skOpaqueRegion), Integer(Child(T.Root, 0).Kind));
      Assert.AreEqual(0, Count(T.Root, skRoutineDeclaration));
    finally T.Free; end;
  end;
end;

procedure TParserTests.CompiledDeclarationCorpus;
var T: TSyntaxTree; S: string;
begin
  S := TFile.ReadAllText('tests/Fixtures/DeclarationCorpus.pas', TEncoding.UTF8);
  T := Parse(S);
  try
    Assert.AreEqual(6, Count(T.Root, skRoutineDeclaration));
    Assert.AreEqual(3, Count(T.Root, skBlockStatement));
    Assert.AreEqual(1, Count(T.Root, skDirective));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.DeclarationDeterminism;
const Parts: array[0..16] of string = ('var', 'const', 'type', 'procedure',
  'function', 'A', ':', '=', ';', '(', ')', 'begin', 'end', 'class', 'Integer', ',', '1');
var Seed: UInt64; I,J: Integer; S: string; A,B: TSyntaxTree;
begin
  Seed := $4D322E32;
  for I := 0 to 299 do
  begin
    S := 'unit X; interface ';
    for J := 0 to I mod 35 do
    begin
      Seed := (Seed * UInt64(1664525) + UInt64(1013904223)) and UInt64($FFFFFFFF);
      S := S + Parts[Integer(Seed mod UInt64(Length(Parts)))] + ' ';
    end;
    S := S + ' implementation procedure Good; begin end; end.';
    A := Parse(S);
    try
      B := Parse(S);
      try
        Assert.AreEqual(Shape(A.Root), Shape(B.Root));
        Assert.AreEqual(A.DiagnosticCount, B.DiagnosticCount);
        for J := 0 to A.DiagnosticCount - 1 do
        begin
          Assert.AreEqual(A.GetDiagnostic(J).Code, B.GetDiagnostic(J).Code);
          Assert.AreEqual(A.GetDiagnostic(J).Span.StartOffset, B.GetDiagnostic(J).Span.StartOffset);
        end;
      finally B.Free; end;
    finally A.Free; end;
  end;
end;

procedure TParserTests.UnsupportedParameterTypes;
var T: TSyntaxTree;
begin
  T := Parse('unit X; interface procedure P(A: array of Integer; '+
    'B: TList<Integer>); procedure Q; implementation end.');
  try
    Assert.AreEqual(2, Count(T.Root, skRoutineDeclaration));
    Assert.AreEqual(2, Count(T.Root, skParameterDeclaration));
    Assert.IsTrue(Count(T.Root, skOpaqueRegion) > 0);
    Assert.IsTrue(T.DiagnosticCount > 0);
  finally T.Free; end;
end;

procedure TParserTests.MemberHierarchy;
var T: TSyntaxTree; N: TSyntaxNode;
begin
  T := Parse('Customer.Address.City', 1);
  try
    N := Child(T.Root, 0);
    Assert.AreEqual(Integer(skMemberAccessExpression), Integer(N.Kind));
    Assert.AreEqual(17, N.GetChild(2).Span.StartOffset);
    N := Child(N, 0);
    Assert.AreEqual(Integer(skMemberAccessExpression), Integer(N.Kind));
    Assert.AreEqual(0, N.Span.StartOffset);
    Assert.AreEqual(16, N.Span.Length);
    Assert.AreEqual(Integer(skIdentifierExpression), Integer(Child(N, 0).Kind));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.QualifiedAndEscapedMembers;
const Sources: array[0..4] of string = ('Customer.Name', 'Form1.Caption',
  'System.SysUtils.Format', '&Type.&Name', 'GetObject().Property');
var S: string; T: TSyntaxTree;
begin
  for S in Sources do
  begin
    T := Parse(S, 1);
    try
      Assert.AreEqual(Integer(skMemberAccessExpression), Integer(Child(T.Root, 0).Kind));
      Assert.AreEqual(0, T.DiagnosticCount);
    finally T.Free; end;
  end;
end;

procedure TParserTests.PostfixTrivia;
var T: TSyntaxTree;
begin
  T := Parse(' Data {receiver} . (*member*) Items '#13#10+
    '[ {index} A + 1, B ] {pointer} ^ . Name ', 1);
  try
    Assert.AreEqual(2, Count(T.Root, skMemberAccessExpression));
    Assert.AreEqual(1, Count(T.Root, skIndexExpression));
    Assert.AreEqual(1, Count(T.Root, skDereferenceExpression));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.IndexHierarchy;
var T: TSyntaxTree; N: TSyntaxNode;
begin
  T := Parse('Data.Items[Index].Name', 1);
  try
    N := Child(T.Root, 0);
    Assert.AreEqual(Integer(skMemberAccessExpression), Integer(N.Kind));
    N := Child(N, 0);
    Assert.AreEqual(Integer(skIndexExpression), Integer(N.Kind));
    Assert.AreEqual(Integer(skMemberAccessExpression), Integer(Child(N, 0).Kind));
    Assert.AreEqual(Integer(skIdentifierExpression), Integer(Child(N, 1).Kind));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
  T := Parse('Matrix[Row][Column]', 1);
  try
    N := Child(T.Root, 0);
    Assert.AreEqual(Integer(skIndexExpression), Integer(N.Kind));
    Assert.AreEqual(Integer(skIndexExpression), Integer(Child(N, 0).Kind));
    Assert.AreEqual(2, Count(N, skIndexExpression));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.MultipleAndComplexIndices;
var T: TSyntaxTree; N: TSyntaxNode;
begin
  T := Parse('Matrix[Row + 1, Items[F(Column * 2)]]', 1);
  try
    N := Child(T.Root, 0);
    Assert.AreEqual(Integer(skIndexExpression), Integer(N.Kind));
    Assert.AreEqual(Integer(skBinaryExpression), Integer(Child(N, 1).Kind));
    Assert.AreEqual(Integer(skIndexExpression), Integer(Child(N, 2).Kind));
    Assert.AreEqual(2, Count(N, skBinaryExpression));
    Assert.AreEqual(1, Count(N, skCallExpression));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.AlternativeIndexBrackets;
const Sources: array[0..5] of string = ('Items(.0.)',
  'Matrix(.Row, Column.)', 'Items(.Indices[0].).Name', 'Matrix[Row](.Column.)',
  'Items[0.)', 'Items(.0]');
var S: string; T: TSyntaxTree;
begin
  for S in Sources do
  begin
    T := Parse(S, 1);
    try
      Assert.IsTrue(Count(T.Root, skIndexExpression) > 0);
      Assert.AreEqual(0, Count(T.Root, skCallExpression));
      Assert.AreEqual(0, T.DiagnosticCount);
    finally T.Free; end;
  end;
end;

procedure TParserTests.DereferenceHierarchy;
var T: TSyntaxTree; N: TSyntaxNode;
begin
  T := Parse('P^.Next^.Value', 1);
  try
    N := Child(T.Root, 0);
    Assert.AreEqual(Integer(skMemberAccessExpression), Integer(N.Kind));
    N := Child(N, 0);
    Assert.AreEqual(Integer(skDereferenceExpression), Integer(N.Kind));
    N := Child(N, 0);
    Assert.AreEqual(Integer(skMemberAccessExpression), Integer(N.Kind));
    Assert.AreEqual(Integer(skDereferenceExpression), Integer(Child(N, 0).Kind));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
  T := Parse('P^^', 1);
  try
    Assert.AreEqual(2, Count(T.Root, skDereferenceExpression));
    Assert.AreEqual(Integer(skDereferenceExpression), Integer(Child(Child(T.Root, 0), 0).Kind));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.MixedPostfixChains;
var T: TSyntaxTree; N: TSyntaxNode;
begin
  T := Parse('Factory.Create().Items[0]^.GetAddress().City', 1);
  try
    N := Child(T.Root, 0);
    Assert.AreEqual(Integer(skMemberAccessExpression), Integer(N.Kind));
    N := Child(N, 0);
    Assert.AreEqual(Integer(skCallExpression), Integer(N.Kind));
    N := Child(N, 0);
    Assert.AreEqual(Integer(skMemberAccessExpression), Integer(N.Kind));
    N := Child(N, 0);
    Assert.AreEqual(Integer(skDereferenceExpression), Integer(N.Kind));
    N := Child(N, 0);
    Assert.AreEqual(Integer(skIndexExpression), Integer(N.Kind));
    Assert.AreEqual(2, Count(T.Root, skCallExpression));
    Assert.AreEqual(4, Count(T.Root, skMemberAccessExpression));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.PostfixPrecedence;
var T: TSyntaxTree; N: TSyntaxNode;
begin
  T := Parse('-A.Items[0] + B.Value * C[Index]', 1);
  try
    N := Child(T.Root, 0);
    Assert.AreEqual(Integer(skBinaryExpression), Integer(N.Kind));
    Assert.AreEqual(Integer(skUnaryExpression), Integer(Child(N, 0).Kind));
    Assert.AreEqual(Integer(skIndexExpression), Integer(Child(Child(N, 0), 0).Kind));
    Assert.AreEqual(Integer(skBinaryExpression), Integer(Child(N, 1).Kind));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
  T := Parse('not Obj.Enabled and @P^.Field <> nil', 1);
  try
    N := Child(T.Root, 0);
    Assert.AreEqual(Integer(skBinaryExpression), Integer(Child(N, 0).Kind));
    N := Child(N, 0);
    Assert.AreEqual(Integer(skUnaryExpression), Integer(Child(N, 0).Kind));
    Assert.AreEqual(Integer(skMemberAccessExpression), Integer(Child(Child(N, 0), 0).Kind));
    Assert.AreEqual(Integer(skUnaryExpression), Integer(Child(N, 1).Kind));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.DesignatorAssignments;
const Targets: array[0..10] of string = ('A', 'Customer.Name',
  'Customer.Address.City', 'Items[Index]', 'Items[Index].Name',
  'Matrix[Row, Column]', 'P^', 'P^.Field', 'Items[Index]^',
  'GetObject().Property', 'Matrix(.Row, Column.)');
var S: string; T: TSyntaxTree;
begin
  for S in Targets do
  begin
    T := Parse(S+' := Value;', 2);
    try
      Assert.AreEqual(Integer(skAssignmentStatement), Integer(Child(T.Root, 0).Kind), S);
      Assert.AreEqual(0, T.DiagnosticCount, S);
    finally T.Free; end;
  end;
end;

procedure TParserTests.InvalidAssignmentTargets;
const Targets: array[0..3] of string = ('A + B', 'F()', 'A * B.Field', 'A = B');
var S: string; T: TSyntaxTree;
begin
  for S in Targets do
  begin
    T := Parse('begin '+S+' := 10; Good.Name := Value; end', 2);
    try
      Assert.AreEqual(Integer(skError), Integer(Child(Child(T.Root, 0), 0).Kind));
      Assert.AreEqual(1, Count(T.Root, skAssignmentStatement));
      Assert.IsTrue(T.DiagnosticCount > 0);
    finally T.Free; end;
  end;
end;

procedure TParserTests.MemberCallStatements;
const Sources: array[0..7] of string = ('DoSomething', 'DoSomething(Value)',
  'Logger.WriteMessage(''Hello'')', 'Customer.Save', 'Items[Index].Update',
  'Form1.Close', 'Customer.GetAddress().Save', 'Items[Index].SetValue(NewValue)');
var S: string; T: TSyntaxTree;
begin
  for S in Sources do
  begin
    T := Parse('if A then '+S+' else Form1.Close;', 2);
    try
      Assert.AreEqual(2, Count(T.Root, skCallStatement), S);
      Assert.AreEqual(0, Count(T.Root, skOpaqueRegion), S);
      Assert.AreEqual(0, T.DiagnosticCount, S);
    finally T.Free; end;
  end;
end;

procedure TParserTests.PostfixRecovery;
const Sources: array[0..11] of string = ('Customer.', 'Items[', 'Matrix[A,',
  'P^.', 'Customer.Name :=', 'Items[Index := Value', 'Items[]',
  'Items[0,]', 'Items(.', 'Items(.A,.)', 'F(Items[)', 'Items[A + ]');
var S: string; T: TSyntaxTree; I: Integer;
begin
  for S in Sources do
  begin
    T := Parse(S, 2);
    try
      Assert.IsTrue(T.DiagnosticCount > 0, S);
      Assert.IsTrue(Count(T.Root, skMissingToken) > 0, S);
      Assert.AreEqual('PAR001', T.GetDiagnostic(0).Code, S);
      for I := 0 to T.DiagnosticCount - 1 do
        Assert.IsTrue(T.GetDiagnostic(I).Span.EndOffset <= Length(S));
    finally T.Free; end;
    T := Parse('begin '+S+'; Next.Name := Value; end', 2);
    try
      Assert.IsTrue(T.DiagnosticCount > 0, S);
      Assert.AreEqual(Integer(skAssignmentStatement),
        Integer(Child(Child(T.Root, 0), 1).Kind), S);
    finally T.Free; end;
  end;
end;

procedure TParserTests.QualifiedGenericFallback;
const Sources: array[0..5] of string = ('GenericMethod<T>(Value)',
  'Obj.GenericMethod<T>(Value)', 'Factory.Create<T>().Property',
  'F(Obj.Method<T,U>(Value), B)', 'Items[I].Method<T>(Value)',
  'Obj.Method<TList<T>>(Value).Name');
var S: string; T: TSyntaxTree;
begin
  for S in Sources do
  begin
    T := Parse(S, 1);
    try
      Assert.IsTrue(Count(T.Root, skOpaqueRegion) > 0, S);
      Assert.AreEqual(0, Count(T.Root, skBinaryExpression), S);
      Assert.IsTrue(T.DiagnosticCount > 0, S);
    finally T.Free; end;
  end;
  T := Parse('A.Value < B.Value', 1);
  try
    Assert.AreEqual(1, Count(T.Root, skBinaryExpression));
    Assert.AreEqual(0, Count(T.Root, skOpaqueRegion));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.PostfixDirectives;
const Sources: array[0..2] of string = ('A.{$IFDEF X}B{$ENDIF}',
  'A[{$I index.inc}I]', 'P^.'#13#10'{$R x.res}'#13#10'Field');
var S: string; T: TSyntaxTree;
begin
  for S in Sources do
  begin
    T := Parse('unit X; interface implementation procedure P; begin '+S+'; end; end.');
    try
      Assert.AreEqual(Integer(skOpaqueRegion), Integer(Child(T.Root, 0).Kind));
      Assert.AreEqual(0, Count(T.Root, skRoutineDeclaration));
    finally T.Free; end;
  end;
end;

procedure TParserTests.LongPostfixChains;
var B: TStringBuilder; T: TSyntaxTree; N: TSyntaxNode; I: Integer;
begin
  B := TStringBuilder.Create;
  try
    B.Append('A');
    for I := 1 to 512 do B.Append('.B[0]()^');
    T := Parse(B.ToString+' := Value;', 2);
    try
      Assert.AreEqual(0, T.DiagnosticCount);
      N := Child(Child(T.Root, 0), 0);
      for I := 1 to 512 do
      begin
        Assert.AreEqual(Integer(skDereferenceExpression), Integer(N.Kind)); N := Child(N, 0);
        Assert.AreEqual(Integer(skCallExpression), Integer(N.Kind)); N := Child(N, 0);
        Assert.AreEqual(Integer(skIndexExpression), Integer(N.Kind)); N := Child(N, 0);
        Assert.AreEqual(Integer(skMemberAccessExpression), Integer(N.Kind)); N := Child(N, 0);
      end;
      Assert.AreEqual(Integer(skIdentifierExpression), Integer(N.Kind));
    finally T.Free; end;
    B.Append('.');
    T := Parse(B.ToString, 1);
    try Assert.IsTrue(T.DiagnosticCount > 0);
    finally T.Free; end;
  finally B.Free; end;
end;

procedure TParserTests.PostfixDeterminism;
const Parts: array[0..17] of string = ('A', '.', '^', '[', ']', '(.', '.)',
  '(', ')', ',', ':=', ';', 'B', '+', '<', '>', '0', '{gap}');
var Seed: UInt64; I,J,Mode: Integer; S: string; A,B: TSyntaxTree;
begin
  Seed := $4D322E33;
  for I := 0 to 299 do
  begin
    S := 'A';
    for J := 0 to I mod 45 do
    begin
      Seed := (Seed * UInt64(1664525) + UInt64(1013904223)) and UInt64($FFFFFFFF);
      S := S + ' ' + Parts[Integer(Seed mod UInt64(Length(Parts)))];
    end;
    for Mode := 1 to 2 do
    begin
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
end;

procedure TParserTests.PostfixLifetimes;
var I: Integer; T: TSyntaxTree;
begin
  for I := 1 to 200 do
  begin
    T := Parse('begin P^.Items[F(0)].Name := Value; P^.Save; end', 2);
    try Assert.AreEqual(0, T.DiagnosticCount);
    finally T.Free; end;
    T := Parse('A.' + Char($D800) + '[I,].B^', 1);
    try Assert.IsTrue(T.DiagnosticCount > 0);
    finally T.Free; end;
  end;
end;

procedure TParserTests.CompiledPostfixCorpus;
var T: TSyntaxTree;
begin
  T := Parse(TFile.ReadAllText('tests/Fixtures/PostfixCorpus.pas', TEncoding.UTF8));
  try
    Assert.AreEqual(5, Count(T.Root, skBlockStatement));
    Assert.IsTrue(Count(T.Root, skMemberAccessExpression) >= 20);
    Assert.IsTrue(Count(T.Root, skIndexExpression) >= 8);
    Assert.IsTrue(Count(T.Root, skDereferenceExpression) >= 5);
    Assert.IsTrue(Count(T.Root, skAssignmentStatement) >= 15);
    Assert.AreEqual(1, Count(T.Root, skIfStatement));
    // Pointer/array aliases and the complex array field type remain opaque.
    Assert.AreEqual(1, Count(T.Root, skClassDeclaration));
    Assert.AreEqual(1, Count(T.Root, skRecordDeclaration));
    Assert.AreEqual(4, Count(T.Root, skOpaqueRegion));
    Assert.AreEqual(4, T.DiagnosticCount);
    Assert.AreEqual('PAR003', T.GetDiagnostic(0).Code);
  finally T.Free; end;
end;

procedure TParserTests.SyntaxKindOrdinals;
begin
  Assert.AreEqual(15, Ord(skCallExpression));
  Assert.AreEqual(30, Ord(skDirective));
  Assert.AreEqual(31, Ord(skMemberAccessExpression));
  Assert.AreEqual(32, Ord(skIndexExpression));
  Assert.AreEqual(33, Ord(skDereferenceExpression));
end;

procedure TParserTests.TypeSectionHierarchy;
var T: TSyntaxTree; S, D: TSyntaxNode;
begin
  T := Parse('unit X; interface type A=class end; B=record end; '+
    'C=class end; implementation end.');
  try
    S := Child(Child(T.Root, 0), 0);
    Assert.AreEqual(Integer(skTypeSection), Integer(S.Kind));
    Assert.AreEqual(3, Count(S, skTypeDeclaration));
    D := Child(S, 0);
    Assert.AreEqual(Integer(skTypeDeclaration), Integer(D.Kind));
    Assert.AreEqual(Integer(skClassDeclaration), Integer(Child(D, 0).Kind));
    Assert.AreEqual(2, Count(S, skClassDeclaration));
    Assert.AreEqual(1, Count(S, skRecordDeclaration));
    Assert.AreEqual(0, T.DiagnosticCount);
    Assert.AreEqual(34, Ord(skTypeSection));
    Assert.AreEqual(41, Ord(skAncestorList));
  finally T.Free; end;
end;

procedure TParserTests.MixedTypeDeclarations;
const Aliases: array[0..8] of string = ('A=Integer;', 'A=^B;',
  'A=array of Integer;', 'A=(New, Active, Closed);', 'A=set of Byte;',
  'A=TList<string>;', 'A=procedure(X: Integer; Y: string);',
  'A=function(X: Integer): Integer of object;', 'A=reference to procedure;');
var S: string; T: TSyntaxTree;
begin
  for S in Aliases do
  begin
    T := Parse('unit X; interface type '+S+' B=class end; C=record X: Integer; end; '+
      'implementation end.');
    try
      Assert.AreEqual(3, Count(T.Root, skTypeDeclaration), S);
      Assert.AreEqual(1, Count(T.Root, skClassDeclaration), S);
      Assert.AreEqual(1, Count(T.Root, skRecordDeclaration), S);
      Assert.AreEqual(1, Count(T.Root, skOpaqueRegion), S);
      Assert.AreEqual(0, Count(T.Root, skRoutineDeclaration), S);
      Assert.AreEqual('PAR003', T.GetDiagnostic(0).Code);
    finally T.Free; end;
  end;
end;

procedure TParserTests.MultipleTypeSections;
var T: TSyntaxTree;
begin
  T := Parse('unit X; interface const C=1; type A=class end; '+
    'var V: Integer; type B=record end; procedure P; '+
    'implementation type D=class end; procedure P; begin end; type E=record end; end.');
  try
    Assert.AreEqual(4, Count(T.Root, skTypeSection));
    Assert.AreEqual(2, Count(T.Root, skRoutineDeclaration));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.ClassAncestors;
var T: TSyntaxTree; A: TSyntaxNode;
begin
  T := Parse('unit X; interface type A=class(System.TObject, ICustomer, '+
    'Example.IPrintable) end; implementation end.');
  try
    A := Child(Child(Child(Child(Child(T.Root, 0), 0), 0), 0), 0);
    Assert.AreEqual(Integer(skAncestorList), Integer(A.Kind));
    Assert.AreEqual(3, Count(A, skTypeReference));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.ClassVisibility;
var T: TSyntaxTree; A, V: TSyntaxNode; I: Integer;
begin
  T := Parse('unit X; interface type A=class Before: Integer; '+
    'private A: Integer; protected B: Integer; public C: Integer; '+
    'published D: Integer; automated E: Integer; strict private F: Integer; '+
    'strict protected G: Integer; end; implementation end.');
  try
    A := Child(Child(Child(Child(T.Root, 0), 0), 0), 0);
    Assert.AreEqual(Integer(skFieldDeclaration), Integer(Child(A, 0).Kind));
    Assert.AreEqual(7, Count(A, skVisibilitySection));
    for I := 1 to 7 do
    begin
      V := Child(A, I);
      Assert.AreEqual(Integer(skVisibilitySection), Integer(V.Kind));
      Assert.AreEqual(1, Count(V, skFieldDeclaration));
    end;
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.AggregateFields;
var T: TSyntaxTree;
begin
  T := Parse('unit X; interface type A=class FX,FY: Double; '+
    'P: System.Types.TPoint; end; B=record X,Y: Integer; '+
    '{between members} Z: string; end; implementation end.');
  try
    Assert.AreEqual(4, Count(T.Root, skFieldDeclaration));
    Assert.AreEqual(4, Count(T.Root, skTypeReference));
    Assert.AreEqual(0, Count(T.Root, skVarDeclaration));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.AggregateMethods;
var T: TSyntaxTree; A, M: TSyntaxNode;
begin
  T := Parse('unit X; interface type A=class procedure Save; '+
    'procedure SetName(const Value: string); function Calculate(A,B: Integer): Integer; '+
    'constructor Create; destructor Destroy; override; end; '+
    'B=record function Sum: Integer; end; implementation '+
    'constructor A.Create; begin end; destructor A.Destroy; begin end; end.');
  try
    Assert.AreEqual(6, Count(T.Root, skMethodDeclaration));
    Assert.AreEqual(2, Count(T.Root, skParameterDeclaration));
    Assert.AreEqual(2, Count(T.Root, skRoutineDeclaration));
    Assert.AreEqual(2, Count(T.Root, skBlockStatement));
    A := Child(Child(Child(Child(T.Root, 0), 0), 0), 0);
    M := Child(A, 0);
    Assert.AreEqual(Integer(skMethodDeclaration), Integer(M.Kind));
    Assert.AreEqual(Integer(skRoutineHeader), Integer(Child(M, 0).Kind));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.MethodDirectives;
var T: TSyntaxTree; A, M, D: TSyntaxNode;
begin
  T := Parse('unit X; interface type A=class '+
    'procedure P; reintroduce; overload; virtual; abstract; '+
    'procedure Q; override; F: Integer; virtual: Integer; end; implementation end.');
  try
    A := Child(Child(Child(Child(T.Root, 0), 0), 0), 0);
    M := Child(A, 0); D := Child(M, 1);
    Assert.AreEqual(Integer(skOpaqueRegion), Integer(D.Kind));
    Assert.AreEqual(' reintroduce; overload; virtual; abstract;',
      Copy(T.Source, D.Span.StartOffset+1, D.Span.Length));
    Assert.AreEqual(2, Count(T.Root, skMethodDeclaration));
    Assert.AreEqual(2, Count(T.Root, skFieldDeclaration));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.OpaqueProperties;
const Props: array[0..4] of string = (
  'property Name: string read FName write FName;',
  'property Items[Index: Integer]: TObject read GetItem;',
  'property Caption: string read FCaption write SetCaption default '''';',
  'property Items[Index: array of TList<Integer>]: TList<string> read GetItem;',
  'property Items[Index: Integer]: TObject read GetItem; default;');
var P: string; T: TSyntaxTree; A, O: TSyntaxNode;
begin
  for P in Props do
  begin
    T := Parse('unit X; interface type A=class '+P+
      ' procedure Save; F: Integer; end; implementation end.');
    try
      A := Child(Child(Child(Child(T.Root, 0), 0), 0), 0);
      O := Child(A, 0);
      Assert.AreEqual(Integer(skPropertyDeclaration), Integer(O.Kind));
      Assert.AreEqual(' '+P, Copy(T.Source, O.Span.StartOffset+1, O.Span.Length));
      Assert.AreEqual(1, Count(A, skMethodDeclaration));
      Assert.AreEqual(1, Count(A, skFieldDeclaration));
      if Pos('TList', P) = 0 then Assert.AreEqual(0, T.DiagnosticCount)
      else Assert.IsTrue(Count(O, skOpaqueRegion) > 0);
    finally T.Free; end;
  end;
end;

procedure TParserTests.UnsupportedAggregates;
const Types: array[0..7] of string = ('A<T>=class end;', 'A=class;',
  'A=class of TObject;', 'A=class helper for TObject end;',
  'A=record helper for Integer end;', 'A=interface procedure P; end;',
  'A=class(TList<Integer>) end;', 'A=class abstract end;');
var S: string; T: TSyntaxTree;
begin
  for S in Types do
  begin
    T := Parse('unit X; interface type '+S+' B=class end; C=record end; '+
      'implementation end.');
    try
      Assert.AreEqual(3, Count(T.Root, skTypeDeclaration), S);
      Assert.AreEqual(1, Count(T.Root, skClassDeclaration), S);
      Assert.AreEqual(1, Count(T.Root, skRecordDeclaration), S);
      Assert.AreEqual(0, Count(T.Root, skMethodDeclaration), S);
      Assert.AreEqual(1, Count(T.Root, skOpaqueRegion), S);
    finally T.Free; end;
  end;
  T := Parse('unit X; interface type A=class class procedure Hidden; '+
    'class var HiddenField: Integer; procedure Good; type B=record X: Integer; end; '+
    'end; C=record case Boolean of True:(X: Integer); False:(Y: Integer); end; '+
    'D=class end; implementation end.');
  try
    Assert.AreEqual(2, Count(T.Root, skClassDeclaration));
    Assert.AreEqual(1, Count(T.Root, skRecordDeclaration));
    Assert.AreEqual(1, Count(T.Root, skMethodDeclaration));
    Assert.AreEqual(0, Count(T.Root, skFieldDeclaration));
    Assert.IsTrue(Count(T.Root, skOpaqueRegion) >= 4);
  finally T.Free; end;
end;

procedure TParserTests.AggregateRecovery;
const Bad: array[0..8] of string = ('A=class F: string procedure Save; end;',
  'A=record X: Integer; Y: end;', 'A=class(TObject public procedure Save; end;',
  'A=class procedure P(X: Integer; end;', 'A=class F Integer; end;',
  'A=record X: Integer;', 'A=class end', 'A=class F: array[0..1] of Integer; end;',
  'A=record X: record Y: Integer; end; end;');
var S: string; T: TSyntaxTree;
begin
  for S in Bad do
  begin
    T := Parse('unit X; interface type '+S+' B=class procedure Good; end; '+
      'implementation procedure After; begin end; end.');
    try
      Assert.IsTrue(T.DiagnosticCount > 0, S);
      Assert.AreEqual(2, Count(T.Root, skTypeDeclaration), S);
      Assert.IsTrue(Count(T.Root, skMethodDeclaration) >= 1, S);
      Assert.AreEqual(1, Count(T.Root, skRoutineDeclaration), S);
      Assert.AreEqual(1, Count(T.Root, skBlockStatement), S);
    finally T.Free; end;
  end;
end;

procedure TParserTests.AggregateDeterminism;
const Parts: array[0..15] of string = ('X ', '= ', 'class ', 'record ',
  'end; ', 'property ', 'procedure ', '( ', ') ', '[ ', '] ', '; ',
  'strict private ', 'case ', ': ', 'Integer ');
var I,J,K: Integer; Seed: Cardinal; S: string; A,B: TSyntaxTree;
begin
  Seed := 97;
  for I := 1 to 400 do
  begin
    S := 'unit X; interface type A=class ';
    for J := 1 to 24 do
    begin
      Seed := Cardinal((UInt64(Seed) * 1664525 + 1013904223) and UInt64($FFFFFFFF));
      S := S + Parts[Integer((Seed shr 24) and 15)];
    end;
    S := S+' end; B=record X: Integer; end; implementation end.';
    A := Parse(S);
    try
      B := Parse(S);
      try
        Assert.AreEqual(Shape(A.Root), Shape(B.Root));
        Assert.AreEqual(A.DiagnosticCount, B.DiagnosticCount);
        for K := 0 to A.DiagnosticCount-1 do
        begin
          Assert.AreEqual(A.GetDiagnostic(K).Code, B.GetDiagnostic(K).Code);
          Assert.AreEqual(A.GetDiagnostic(K).Message, B.GetDiagnostic(K).Message);
          Assert.AreEqual(A.GetDiagnostic(K).Span.StartOffset, B.GetDiagnostic(K).Span.StartOffset);
          Assert.AreEqual(A.GetDiagnostic(K).Span.Length, B.GetDiagnostic(K).Span.Length);
        end;
      finally B.Free; end;
    finally A.Free; end;
  end;
end;

procedure TParserTests.AggregateLifetimes;
var I: Integer; T: TSyntaxTree;
begin
  for I := 1 to 300 do
  begin
    T := Parse('unit X; interface type A=class F: Integer; '+
      'property P: string read F; procedure Save; end; B=record X: '+
      Char($D800)+' end; implementation end.');
    try
      Assert.AreEqual(1, Count(T.Root, skClassDeclaration));
      Assert.IsTrue(T.DiagnosticCount > 0);
    finally T.Free; end;
  end;
end;

procedure TParserTests.OpaqueMemberTypeKeywords;
var T: TSyntaxTree; A, M: TSyntaxNode;
begin
  T := Parse('unit X; interface type A=class '+
    'property P: class of TObject read F; '+
    'procedure RegisterCallback(A: procedure(X: Integer) of object); '+
    'procedure Good; F: Integer; end; implementation end.');
  try
    Assert.AreEqual(2, Count(T.Root, skMethodDeclaration));
    Assert.AreEqual(1, Count(T.Root, skFieldDeclaration));
    A := Child(Child(Child(Child(T.Root, 0), 0), 0), 0);
    Assert.AreEqual(Integer(skOpaqueRegion), Integer(Child(A, 0).Kind));
    M := Child(A, 1);
    Assert.AreEqual(1, Count(M, skOpaqueRegion));
    Assert.AreEqual(1, Count(M, skParameterDeclaration));
  finally T.Free; end;
end;

procedure TParserTests.NestedOpaqueTypeBoundaries;
var T: TSyntaxTree;
begin
  T := Parse('unit X; interface type A<T: class; U: record> = class end; '+
    'B=record case Integer of 0:(R: record X: Integer; end); end; '+
    'C=class procedure Good; end; implementation end.');
  try
    Assert.AreEqual(3, Count(T.Root, skTypeDeclaration));
    Assert.AreEqual(1, Count(T.Root, skClassDeclaration));
    Assert.AreEqual(1, Count(T.Root, skRecordDeclaration));
    Assert.AreEqual(1, Count(T.Root, skMethodDeclaration));
    Assert.AreEqual(0, Count(T.Root, skFieldDeclaration));
    Assert.AreEqual(2, Count(T.Root, skOpaqueRegion));
  finally T.Free; end;
end;

procedure TParserTests.CompiledClassRecordCorpus;
var T: TSyntaxTree;
begin
  T := Parse(TFile.ReadAllText('tests/Fixtures/ClassRecordCorpus.pas', TEncoding.UTF8));
  try
    Assert.AreEqual(1, Count(T.Root, skTypeSection));
    Assert.AreEqual(5, Count(T.Root, skTypeDeclaration));
    Assert.AreEqual(1, Count(T.Root, skClassDeclaration));
    Assert.AreEqual(2, Count(T.Root, skRecordDeclaration));
    Assert.AreEqual(7, Count(T.Root, skMethodDeclaration));
    Assert.AreEqual(7, Count(T.Root, skRoutineDeclaration));
    Assert.AreEqual(7, Count(T.Root, skBlockStatement));
    Assert.AreEqual(5, Count(T.Root, skFieldDeclaration));
    Assert.AreEqual(2, T.DiagnosticCount); // alias, class reference
  finally T.Free; end;
end;

procedure TParserTests.LongFieldLookahead;
const NameCount = 2048;
var Builder: TStringBuilder; Mode, I, Names, Commas, Colons: Integer;
  T: TSyntaxTree; F: TSyntaxNode; Leaf: TSyntaxToken; Fields, Gap: string;
begin
  for Mode := 0 to 1 do
  begin
    if Mode = 0 then Gap := ''
    else Gap := ' { , : < end ) are comment text } '#9#13#10' (* gap *) ';
    Builder := TStringBuilder.Create;
    try
      for I := 1 to NameCount do
      begin
        if I > 1 then Builder.Append(Gap + ',' + Gap);
        if I mod 7 = 0 then Builder.Append('&');
        Builder.Append('F').Append(I);
      end;
      Builder.Append(Gap + ': Integer;');
      Fields := Builder.ToString;
    finally Builder.Free; end;
    T := Parse('unit X; interface type A=class ' + Fields +
      ' procedure Following; end; implementation end.');
    try
      Assert.AreEqual(0, T.DiagnosticCount);
      Assert.AreEqual(1, Count(T.Root, skFieldDeclaration));
      Assert.AreEqual(1, Count(T.Root, skMethodDeclaration));
      F := Child(Child(Child(Child(Child(T.Root, 0), 0), 0), 0), 0);
      Assert.AreEqual(Integer(skFieldDeclaration), Integer(F.Kind));
      Assert.AreEqual(' ' + Fields, Copy(T.Source, F.Span.StartOffset + 1, F.Span.Length));
      Names := 0; Commas := 0; Colons := 0;
      for I := 0 to F.ChildCount - 1 do
        if F.GetChild(I) is TSyntaxToken then
        begin
          Leaf := TSyntaxToken(F.GetChild(I));
          if Leaf.OriginalToken.Kind = tkIdentifier then Inc(Names);
          if Leaf.OriginalToken.Kind = tkSymbol then
          begin
            if T.Source[Leaf.Span.StartOffset + 1] = ',' then Inc(Commas);
            if T.Source[Leaf.Span.StartOffset + 1] = ':' then Inc(Colons);
          end;
        end;
      Assert.AreEqual(NameCount, Names);
      Assert.AreEqual(NameCount - 1, Commas);
      Assert.AreEqual(1, Colons);
    finally T.Free; end;
  end;
end;

procedure TParserTests.LongAncestorLookahead;
const AncestorCount = 2048;
var Builder: TStringBuilder; Mode, I: Integer; T, Again: TSyntaxTree;
  S: string; A: TSyntaxNode;
begin
  for Mode := 0 to 1 do
  begin
    Builder := TStringBuilder.Create;
    try
      Builder.Append('unit X; interface type A=class(');
      for I := 1 to AncestorCount do
      begin
        if I > 1 then Builder.Append(' { < ; end ) } , '#13#10#9);
        Builder.Append('System.Example.I').Append(I);
      end;
      Builder.Append(', &end');
      if Mode = 1 then Builder.Append(', TBase { comment } <TList<Integer>>');
      Builder.Append(') end; B=record X: Integer; end; implementation end.');
      S := Builder.ToString;
    finally Builder.Free; end;
    T := Parse(S);
    try
      Assert.AreEqual(2, Count(T.Root, skTypeDeclaration));
      Assert.AreEqual(1, Count(T.Root, skRecordDeclaration));
      if Mode = 0 then
      begin
        Assert.AreEqual(1, Count(T.Root, skClassDeclaration));
        Assert.AreEqual(1, Count(T.Root, skAncestorList));
        A := Child(Child(Child(Child(Child(T.Root, 0), 0), 0), 0), 0);
        Assert.AreEqual(Integer(skAncestorList), Integer(A.Kind));
        Assert.AreEqual(AncestorCount + 1, Count(A, skTypeReference));
        Assert.AreEqual(0, T.DiagnosticCount);
      end
      else
      begin
        Assert.AreEqual(0, Count(T.Root, skClassDeclaration));
        Assert.AreEqual(0, Count(T.Root, skAncestorList));
        Assert.AreEqual(1, Count(T.Root, skOpaqueRegion));
        Assert.AreEqual(1, T.DiagnosticCount);
        Assert.AreEqual('PAR003', T.GetDiagnostic(0).Code);
      end;
      Again := Parse(S);
      try
        Assert.AreEqual(Shape(T.Root), Shape(Again.Root));
        Assert.AreEqual(T.DiagnosticCount, Again.DiagnosticCount);
      finally Again.Free; end;
    finally T.Free; end;
  end;
end;

procedure TParserTests.TypeLookaheadRecovery;
const Fragments: array[0..8] of string = (
  'A=class F1 {gap}, &F2 Integer; end;',
  'A=class F1, {gap} : Integer; end;',
  'A=class(TObject {gap} public procedure Save; end;',
  'A=class(TObject, {gap} ); end;',
  'A=class(TBase {gap} <TList<Integer>>) end;',
  'A=class(TObject; F: TList<Integer>; end;',
  'A=class(TObject end; C=TList<Integer>;',
  'A=class(''end'', ''<'', TObject) end;',
  'A=class F1, F2 {gap} ; procedure Save; end;');
  Directives: array[0..3] of string = (
  'A=class F1, {$IFDEF X} F2 {$ENDIF}: Integer; end;',
  'A=class(TObject, {$IFDEF X} ITest {$ENDIF}) end;',
  'A=class F1, '#13#10'{$R missing.res}'#13#10' F2: Integer; end;',
  'A=class(TObject, '#13#10'{$R missing.res}'#13#10' ITest) end;');
var S: string; T, Again: TSyntaxTree; I: Integer;
  procedure CheckDeterminism;
  var J: Integer;
  begin
    Again := Parse(S);
    try
      Assert.AreEqual(Shape(T.Root), Shape(Again.Root));
      Assert.AreEqual(T.DiagnosticCount, Again.DiagnosticCount);
      for J := 0 to T.DiagnosticCount - 1 do
      begin
        Assert.AreEqual(T.GetDiagnostic(J).Code, Again.GetDiagnostic(J).Code);
        Assert.AreEqual(T.GetDiagnostic(J).Message, Again.GetDiagnostic(J).Message);
        Assert.AreEqual(Integer(T.GetDiagnostic(J).Severity), Integer(Again.GetDiagnostic(J).Severity));
        Assert.AreEqual(T.GetDiagnostic(J).Span.StartOffset, Again.GetDiagnostic(J).Span.StartOffset);
        Assert.AreEqual(T.GetDiagnostic(J).Span.Length, Again.GetDiagnostic(J).Span.Length);
      end;
    finally Again.Free; end;
  end;
begin
  for I := Low(Fragments) to High(Fragments) do
  begin
    S := 'unit X; interface type ' + Fragments[I] +
      ' B=record X: Integer; end; implementation end.';
    T := Parse(S);
    try
      Assert.AreEqual(1, Count(T.Root, skRecordDeclaration), Fragments[I]);
      Assert.AreEqual(1, Count(T.Root, skClassDeclaration) + Ord(I = 4));
      Assert.IsTrue(T.DiagnosticCount > 0, Fragments[I]);
      CheckDeterminism;
    finally T.Free; end;
  end;
  for I := 0 to 1 do
  begin
    S := 'unit X; interface type A=class(TObject, { EOF }';
    if I = 1 then S := S + ' ITest { EOF }';
    T := Parse(S);
    try
      Assert.AreEqual(1, Count(T.Root, skAncestorList));
      Assert.IsTrue(Count(T.Root, skMissingToken) > 0);
      Assert.IsTrue(T.DiagnosticCount > 0);
      CheckDeterminism;
    finally T.Free; end;
  end;
  for I := Low(Directives) to High(Directives) do
  begin
    S := 'unit X; interface type ' + Directives[I] +
      ' B=record X: Integer; end; implementation end.';
    T := Parse(S);
    try
      Assert.AreEqual(1, Count(T.Root, skOpaqueRegion));
      Assert.AreEqual(0, Count(T.Root, skClassDeclaration));
      Assert.AreEqual(0, Count(T.Root, skFieldDeclaration));
      Assert.AreEqual(0, Count(T.Root, skRecordDeclaration));
      Assert.IsTrue(T.DiagnosticCount > 0);
      CheckDeterminism;
    finally T.Free; end;
  end;
end;

procedure TParserTests.PropertySpecifiers;
const Cases: array[0..11] of string = (
  'property Name: string read FName;',
  'property Name: string write SetName;',
  'property Name: string read FName write SetName stored True;',
  'property Position: System.Types.TPoint read FPosition;',
  'property &type: string read &read write &write;',
  'property Index: Integer index 2 read GetValue write SetValue;',
  'property Default: Boolean read FEnabled stored False default True;',
  'property Count: Integer read FCount default -1;',
  'property State: TState read FState nodefault;',
  'property Controller: TController read FController implements A.IController;',
  'property Value: Integer stored ShouldStore read FValue;',
  'property {name} Name: {type} string read {accessor} FName;');
var S: string; T: TSyntaxTree; A, P: TSyntaxNode;
begin
  Assert.AreEqual(42, Ord(skPropertyDeclaration));
  Assert.AreEqual(43, Ord(skPropertyIndexParameters));
  Assert.AreEqual(44, Ord(skPropertySpecifier));
  for S in Cases do
  begin
    T := Parse('unit X; interface type A=class public '+S+
      ' procedure Save; F: Integer; end; implementation end.');
    try
      A := Child(Child(Child(Child(T.Root, 0), 0), 0), 0);
      P := Child(Child(A, 0), 0);
      Assert.AreEqual(Integer(skPropertyDeclaration), Integer(P.Kind), S);
      Assert.AreEqual(' '+S, Copy(T.Source, P.Span.StartOffset+1, P.Span.Length));
      if Pos('implements', S) > 0 then Assert.AreEqual(2, Count(P, skTypeReference))
      else Assert.AreEqual(1, Count(P, skTypeReference));
      Assert.IsTrue(Count(P, skPropertySpecifier) > 0);
      Assert.AreEqual(0, Count(P, skCallExpression));
      Assert.AreEqual(0, T.DiagnosticCount, S);
      Assert.AreEqual(1, Count(A, skMethodDeclaration));
      Assert.AreEqual(1, Count(A, skFieldDeclaration));
    finally T.Free; end;
  end;
end;

procedure TParserTests.PropertyHierarchy;
var T: TSyntaxTree; A, P, S, V: TSyntaxNode;
begin
  T := Parse('unit X; interface type A=class '+
    'property Count: Integer read FCount default -1; '+
    'property Items[Index: Integer]: TObject read GetItem; default; '+
    'F: Integer; end; implementation end.');
  try
    A := Child(Child(Child(Child(T.Root, 0), 0), 0), 0);
    P := Child(A, 0);
    S := Child(P, 2);
    Assert.AreEqual(Integer(skPropertySpecifier), Integer(S.Kind));
    Assert.AreEqual(' default -1', Copy(T.Source, S.Span.StartOffset+1, S.Span.Length));
    V := Child(S, 0);
    Assert.AreEqual(Integer(skUnaryExpression), Integer(V.Kind));
    Assert.AreEqual(Integer(skLiteralExpression), Integer(Child(V, 0).Kind));
    P := Child(A, 1);
    Assert.AreEqual(Integer(skPropertyIndexParameters), Integer(Child(P, 0).Kind));
    S := Child(P, 3);
    Assert.AreEqual(Integer(skPropertySpecifier), Integer(S.Kind));
    Assert.AreEqual(' default;', Copy(T.Source, S.Span.StartOffset+1, S.Span.Length));
    Assert.AreEqual(';', Copy(T.Source, P.Span.EndOffset, 1));
    Assert.AreEqual(1, Count(A, skFieldDeclaration));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.PropertyArrays;
const Cases: array[0..4] of string = (
  'property Items[Index: Integer]: TObject read GetItem write SetItem;',
  'property Pixels[X, Y: Integer]: TColor read GetPixel write SetPixel;',
  'property Values[const Name: string]: string read GetValue write SetValue;',
  'property Items[X: Integer; const Name: string]: TObject read GetItem; default;',
  'property Items[Index: array of TList<Integer>]: TObject read GetItem;');
var S: string; T: TSyntaxTree;
begin
  for S in Cases do
  begin
    T := Parse('unit X; interface type A=class '+S+
      ' property Next: Integer read FNext; procedure Save; end; implementation end.');
    try
      Assert.AreEqual(2, Count(T.Root, skPropertyDeclaration));
      Assert.AreEqual(1, Count(T.Root, skPropertyIndexParameters));
      Assert.IsTrue(Count(T.Root, skParameterDeclaration) > 0);
      Assert.AreEqual(0, Count(T.Root, skIndexExpression));
      Assert.AreEqual(1, Count(T.Root, skMethodDeclaration));
      if Pos('array of', S) = 0 then Assert.AreEqual(0, T.DiagnosticCount)
      else Assert.IsTrue(Count(T.Root, skOpaqueRegion) > 0);
    finally T.Free; end;
  end;
end;

procedure TParserTests.PropertyRedeclarations;
var T: TSyntaxTree;
begin
  T := Parse('unit X; interface type A=class public property Name; '+
    'property Name read GetName; property Name write SetName; '+
    'property Caption stored False; property Color default clBlue; '+
    'property State nodefault; end; implementation end.');
  try
    Assert.AreEqual(6, Count(T.Root, skPropertyDeclaration));
    Assert.AreEqual(5, Count(T.Root, skPropertySpecifier));
    Assert.AreEqual(0, Count(T.Root, skTypeReference));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.PropertyRecovery;
const Cases: array[0..12] of string = (
  'property : string read FName;',
  'property Name string read FName;',
  'property Name: read FName;',
  'property Name: string read;',
  'property Name: string write;',
  'property Items[Index: Integer: TObject read GetItem;',
  'property Items[Index: Integer]: TObject read GetItem',
  'property Items[Index: Integer]: TObject read GetItem; default',
  'property Items: TList<string> read GetItem;',
  'property Name: Integer read FName default [One, Two];',
  'property Name: string read GetName();',
  'property Name: string read',
  'property Items[Index: procedure(X: Integer) of object]: TObject read GetItem;');
var S, Input: string; T, U: TSyntaxTree; I: Integer;
begin
  for S in Cases do
  begin
    Input := 'unit X; interface type A=class '+S+
      ' procedure Save; F: Integer; property Next: Integer read F; end; implementation end.';
    T := Parse(Input); U := Parse(Input);
    try
      Assert.IsTrue(T.DiagnosticCount > 0);
      Assert.AreEqual(1, Count(T.Root, skMethodDeclaration));
      Assert.AreEqual(1, Count(T.Root, skFieldDeclaration));
      Assert.AreEqual(2, Count(T.Root, skPropertyDeclaration));
      Assert.AreEqual(Shape(T.Root), Shape(U.Root));
      Assert.AreEqual(T.DiagnosticCount, U.DiagnosticCount);
      for I := 0 to T.DiagnosticCount-1 do
      begin
        Assert.AreEqual(T.GetDiagnostic(I).Code, U.GetDiagnostic(I).Code);
        Assert.AreEqual(T.GetDiagnostic(I).Message, U.GetDiagnostic(I).Message);
        Assert.AreEqual(T.GetDiagnostic(I).Span.StartOffset, U.GetDiagnostic(I).Span.StartOffset);
      end;
    finally U.Free; T.Free; end;
  end;
  T := Parse('unit X; interface type A=class property P: Integer read '+
    'F: Integer; procedure Save; end; implementation end.');
  try
    Assert.AreEqual(1, Count(T.Root, skPropertyDeclaration));
    Assert.AreEqual(1, Count(T.Root, skFieldDeclaration));
    Assert.AreEqual(1, Count(T.Root, skMethodDeclaration));
    Assert.IsTrue(T.DiagnosticCount > 0);
  finally T.Free; end;
  T := Parse('unit X; interface type A=class class property P: Integer read F; '+
    'procedure Save; end; implementation end.');
  try
    Assert.AreEqual(0, Count(T.Root, skPropertyDeclaration));
    Assert.AreEqual(1, Count(T.Root, skMethodDeclaration));
  finally T.Free; end;
  T := Parse('unit X; interface type A=class property P: Integer {$IFDEF X} read F; '+
    '{$ENDIF} end; implementation end.');
  try Assert.AreEqual(0, Count(T.Root, skPropertyDeclaration));
  finally T.Free; end;
end;

procedure TParserTests.PropertyFieldBoundaryRecovery;
const Prefixes: array[0..9] of string = (
  'property Name',
  'property Name: string read FName',
  'property Name:',
  'property Name: string read',
  'property Name: Integer default -',
  'property Name: Integer default (1 + 2)',
  'property Name: string read GetName()',
  'property Name: TObject implements',
  'property Name: Integer nodefault',
  'property Name: Integer default 1 + 2');
  Gaps: array[0..3] of string = (' ', #10, #13, #13#10);
  Fields: array[0..2] of string = ('FCount', 'FCount, FOther', 'stored');
var Prefix, Gap, Names, Source, Input: string; T, U: TSyntaxTree;
  A, P, F, M: TSyntaxNode; I: Integer; Leaf: TSyntaxToken;
begin
  for Prefix in Prefixes do
    for Gap in Gaps do
      for Names in Fields do
      begin
        Input := 'unit X; interface type TExample=class ';
        Source := Input + Prefix + Gap + '{ boundary }' + Gap + Names +
          ': Integer;' + Gap + 'procedure Save; end; implementation end.';
        T := Parse(Source); U := Parse(Source);
        try
          Assert.AreEqual(1, Count(T.Root, skPropertyDeclaration), Source);
          Assert.AreEqual(1, Count(T.Root, skFieldDeclaration), Source);
          Assert.AreEqual(1, Count(T.Root, skMethodDeclaration), Source);
          A := Child(Child(Child(Child(T.Root, 0), 0), 0), 0);
          P := Child(A, 0); F := Child(A, 1); M := Child(A, 2);
          Assert.AreEqual(Integer(skPropertyDeclaration), Integer(P.Kind));
          Assert.AreEqual(Integer(skFieldDeclaration), Integer(F.Kind));
          Assert.AreEqual(Integer(skMethodDeclaration), Integer(M.Kind));
          Assert.AreEqual(' ' + Prefix,
            Copy(T.Source, P.Span.StartOffset+1, P.Span.Length));
          Assert.AreEqual(Gap + '{ boundary }' + Gap + Names + ': Integer;',
            Copy(T.Source, F.Span.StartOffset+1, F.Span.Length));
          Assert.AreEqual(P.Span.EndOffset, F.Span.StartOffset);
          Leaf := TSyntaxToken(P.GetChild(P.ChildCount-1));
          Assert.IsTrue(Leaf.IsMissing);
          Assert.AreEqual(';', Leaf.ExpectedText);
          Assert.AreEqual(0, Leaf.Span.Length);
          Assert.AreEqual(Length(Input + Prefix), Leaf.Span.StartOffset);
          Assert.IsTrue(T.DiagnosticCount > 0);
          Assert.AreEqual('PAR001', T.GetDiagnostic(T.DiagnosticCount-1).Code);
          Assert.AreEqual('Expected ;', T.GetDiagnostic(T.DiagnosticCount-1).Message);
          Assert.AreEqual(Shape(T.Root), Shape(U.Root));
          Assert.AreEqual(T.DiagnosticCount, U.DiagnosticCount);
          for I := 0 to T.DiagnosticCount-1 do
          begin
            Assert.AreEqual(T.GetDiagnostic(I).Code, U.GetDiagnostic(I).Code);
            Assert.AreEqual(T.GetDiagnostic(I).Message, U.GetDiagnostic(I).Message);
            Assert.AreEqual(Integer(T.GetDiagnostic(I).Severity), Integer(U.GetDiagnostic(I).Severity));
            Assert.AreEqual(T.GetDiagnostic(I).Span.StartOffset, U.GetDiagnostic(I).Span.StartOffset);
            Assert.AreEqual(T.GetDiagnostic(I).Span.Length, U.GetDiagnostic(I).Span.Length);
          end;
        finally U.Free; T.Free; end;
      end;
end;

procedure TParserTests.PropertyFollowingPropertyRecovery;
var T, U: TSyntaxTree; A, P, Q: TSyntaxNode; S: string; I: Integer;
begin
  S := 'unit X; interface type TExample=class property Name: string read' +
    #13#10 + 'property Count: Integer read FCount; procedure Save; end; implementation end.';
  T := Parse(S); U := Parse(S);
  try
    Assert.AreEqual(2, Count(T.Root, skPropertyDeclaration));
    Assert.AreEqual(1, Count(T.Root, skMethodDeclaration));
    A := Child(Child(Child(Child(T.Root, 0), 0), 0), 0);
    P := Child(A, 0); Q := Child(A, 1);
    Assert.AreEqual(' property Name: string read', Copy(S, P.Span.StartOffset+1, P.Span.Length));
    Assert.AreEqual(#13#10 + 'property Count: Integer read FCount;',
      Copy(S, Q.Span.StartOffset+1, Q.Span.Length));
    Assert.AreEqual(2, Count(P, skMissingToken));
    Assert.AreEqual(0, Count(Q, skMissingToken));
    Assert.AreEqual(2, T.DiagnosticCount);
    Assert.AreEqual('Expected property specifier value', T.GetDiagnostic(0).Message);
    Assert.AreEqual('Expected ;', T.GetDiagnostic(1).Message);
    Assert.AreEqual(Shape(T.Root), Shape(U.Root));
    Assert.AreEqual(T.DiagnosticCount, U.DiagnosticCount);
    for I := 0 to T.DiagnosticCount-1 do
    begin
      Assert.AreEqual(T.GetDiagnostic(I).Code, U.GetDiagnostic(I).Code);
      Assert.AreEqual(T.GetDiagnostic(I).Message, U.GetDiagnostic(I).Message);
      Assert.AreEqual(Integer(T.GetDiagnostic(I).Severity), Integer(U.GetDiagnostic(I).Severity));
      Assert.AreEqual(T.GetDiagnostic(I).Span.StartOffset, U.GetDiagnostic(I).Span.StartOffset);
      Assert.AreEqual(T.GetDiagnostic(I).Span.Length, U.GetDiagnostic(I).Span.Length);
    end;
  finally U.Free; T.Free; end;
end;

procedure TParserTests.PropertyBoundaryValidDeclarations;
var T, U: TSyntaxTree; S: string; A, P: TSyntaxNode;
begin
  S := 'unit X; interface type TExample=class property Name; ' +
    'property Name read GetName; property Caption stored False; ' +
    'property Name: string read FName write SetName; ' +
    'property Count: Integer read FCount; ' +
    'property Items[Index: Integer]: TObject read GetItem; ' +
    'procedure Save; end; implementation end.';
  T := Parse(S); U := Parse(S);
  try
    Assert.AreEqual(0, T.DiagnosticCount);
    Assert.AreEqual(0, U.DiagnosticCount);
    Assert.AreEqual(6, Count(T.Root, skPropertyDeclaration));
    Assert.AreEqual(6, Count(T.Root, skPropertySpecifier));
    Assert.AreEqual(4, Count(T.Root, skTypeReference));
    Assert.AreEqual(1, Count(T.Root, skPropertyIndexParameters));
    Assert.AreEqual(1, Count(T.Root, skParameterDeclaration));
    Assert.AreEqual(0, Count(T.Root, skMissingToken));
    Assert.AreEqual(0, Count(T.Root, skOpaqueRegion));
    Assert.AreEqual(1, Count(T.Root, skMethodDeclaration));
    A := Child(Child(Child(Child(T.Root, 0), 0), 0), 0);
    Assert.AreEqual(0, Count(Child(A, 0), skTypeReference));
    Assert.AreEqual(0, Count(Child(A, 1), skTypeReference));
    Assert.AreEqual(0, Count(Child(A, 2), skTypeReference));
    P := Child(A, 3);
    Assert.AreEqual(Integer(skTypeReference), Integer(Child(P, 0).Kind));
    Assert.AreEqual(Integer(skPropertySpecifier), Integer(Child(P, 1).Kind));
    Assert.AreEqual(Integer(skPropertySpecifier), Integer(Child(P, 2).Kind));
    P := Child(A, 5);
    Assert.AreEqual(Integer(skPropertyIndexParameters), Integer(Child(P, 0).Kind));
    Assert.AreEqual(Integer(skTypeReference), Integer(Child(P, 1).Kind));
    Assert.AreEqual(Integer(skPropertySpecifier), Integer(Child(P, 2).Kind));
    Assert.AreEqual(Shape(T.Root), Shape(U.Root));
  finally U.Free; T.Free; end;
end;

procedure TParserTests.PropertyStress;
var B: TStringBuilder; I: Integer; T, U: TSyntaxTree; S: string;
begin
  B := TStringBuilder.Create;
  try
    B.Append('unit X; interface type A=class ');
    for I := 1 to 2048 do
      B.Append('property P').Append(I).Append(': Integer { trivia } read F; ');
    B.Append('property Items[');
    for I := 1 to 1024 do
    begin
      if I > 1 then B.Append('; ');
      B.Append('N').Append(I).Append(': Integer');
    end;
    B.Append(']: Integer read GetItem; default; end; implementation end.');
    T := Parse(B.ToString);
    try
      Assert.AreEqual(2049, Count(T.Root, skPropertyDeclaration));
      Assert.AreEqual(1024, Count(T.Root, skParameterDeclaration));
      Assert.AreEqual(0, T.DiagnosticCount);
    finally T.Free; end;
  finally B.Free; end;
  for I := 0 to 299 do
  begin
    S := 'unit X; interface type A=class property P'+IntToStr(I)+
      '[N: Integer]: string read F '+Copy('default -1; write; stored False;', 1, I mod 31)+
      ' {'+Char($D800)+' '+Char($DC00 + I)+'} end; implementation end.';
    T := Parse(S); U := Parse(S);
    try Assert.AreEqual(Shape(T.Root), Shape(U.Root));
    finally U.Free; T.Free; end;
  end;
end;

procedure TParserTests.CompiledPropertyCorpus;
var T: TSyntaxTree;
begin
  T := Parse(TFile.ReadAllText('tests/Fixtures/PropertyCorpus.pas', TEncoding.UTF8));
  try
    Assert.AreEqual(13, Count(T.Root, skPropertyDeclaration));
    Assert.AreEqual(1, Count(T.Root, skPropertyIndexParameters));
    Assert.AreEqual(26, Count(T.Root, skPropertySpecifier));
    Assert.AreEqual(0, T.DiagnosticCount);
  finally T.Free; end;
end;

procedure TParserTests.ControlLoops;
const
  Sources: array[0..8] of string = (
    'for I := 0 to 10 do Process(I)',
    'for I := 10 downto 0 do begin Process(I); end',
    'for Item in Items[Index + 1].Children do Process(Item)',
    'for I := First(1 + 2) to Last * 2 do while Active do Process',
    'while Index < Count do begin Items[Index].Update; Index := Index + 1; end',
    'while Active do if Ready then for Item in Items do Save(Item)',
    'repeat Inc(Index); Process(Index); until Index >= Count',
    'repeat until Done',
    'repeat repeat Process; until A; until B');
  Kinds: array[0..8] of TSyntaxKind = (skForStatement, skForStatement,
    skForInStatement, skForStatement, skWhileStatement, skWhileStatement,
    skRepeatStatement, skRepeatStatement, skRepeatStatement);
var T: TSyntaxTree; I: Integer;
begin
  for I := Low(Sources) to High(Sources) do
  begin
    T := Parse(Sources[I], 2);
    try
      Assert.AreEqual(Ord(Kinds[I]), Ord(Child(T.Root, 0).Kind), Sources[I]);
      Assert.AreEqual(0, T.DiagnosticCount, Sources[I]);
      Assert.AreEqual(0, Count(T.Root, skOpaqueRegion), Sources[I]);
    finally T.Free; end;
  end;
end;

procedure TParserTests.ControlHierarchy;
var T: TSyntaxTree; N: TSyntaxNode;
begin
  T := Parse('for I := 1 + 2 to Limit * 3 do repeat X := X + 1; until X > 10;', 2);
  try
    N := Child(T.Root, 0);
    Assert.AreEqual(Ord(skIdentifierExpression), Ord(Child(N, 0).Kind));
    Assert.AreEqual(Ord(skBinaryExpression), Ord(Child(N, 1).Kind));
    Assert.AreEqual(Ord(skBinaryExpression), Ord(Child(N, 2).Kind));
    N := Child(N, 3);
    Assert.AreEqual(Ord(skRepeatStatement), Ord(N.Kind));
    Assert.AreEqual(Ord(skStatementList), Ord(Child(N, 0).Kind));
    Assert.AreEqual(Ord(skAssignmentStatement), Ord(Child(Child(N, 0), 0).Kind));
    Assert.AreEqual(Ord(skBinaryExpression), Ord(Child(N, 1).Kind));
    Assert.AreEqual(Length(T.Source) - 1, Child(T.Root, 0).Span.EndOffset);
    Assert.AreEqual(0, T.DiagnosticCount);
    Assert.AreEqual(44, Ord(skPropertySpecifier));
    Assert.AreEqual(45, Ord(skForStatement));
  finally T.Free; end;
end;

procedure TParserTests.ControlCases;
var T: TSyntaxTree; N: TSyntaxNode;
begin
  T := Parse('case Value of 0, 1, 2: Small; 3..10: Medium; -1: Invalid; ' +
    'State.Ready: case Other of 0: Save; end; else Other; Last; end;', 2);
  try
    Assert.AreEqual(0, T.DiagnosticCount);
    Assert.AreEqual(2, Count(T.Root, skCaseStatement));
    Assert.AreEqual(5, Count(T.Root, skCaseBranch));
    N := Child(T.Root, 0);
    Assert.AreEqual(Ord(skIdentifierExpression), Ord(Child(N, 0).Kind));
    Assert.AreEqual(Ord(skCaseBranch), Ord(Child(N, 1).Kind));
    Assert.AreEqual(3, Count(Child(N, 1), skLiteralExpression));
    Assert.AreEqual(Ord(skUnaryExpression), Ord(Child(Child(N, 3), 0).Kind));
    Assert.AreEqual(Ord(skStatementList), Ord(Child(N, 5).Kind));
  finally T.Free; end;
end;

procedure TParserTests.ControlExceptions;
const Sources: array[0..4] of string = (
  'try Work; finally Cleanup; More; end',
  'try Work; except Handle; raise; end',
  'try Work; except on E: Exception do Handle(E); on EArgumentException do raise; end',
  'try Work; except on E: System.SysUtils.Exception do begin Handle(E); end; else Other; More; end',
  'try try while Active do Process; finally Cleanup; end; except on Exception do raise Exception.Create(''Error''); end');
var T: TSyntaxTree; I: Integer;
begin
  for I := Low(Sources) to High(Sources) do
  begin
    T := Parse(Sources[I], 2);
    try
      Assert.AreEqual(0, T.DiagnosticCount, Sources[I]);
      Assert.AreEqual(0, Count(T.Root, skOpaqueRegion));
      Assert.AreEqual(Ord(skStatementList), Ord(Child(Child(T.Root, 0), 0).Kind));
      if I >= 2 then Assert.IsTrue(Count(T.Root, skExceptionHandler) > 0);
    finally T.Free; end;
  end;
end;

procedure TParserTests.ControlElseBinding;
var T: TSyntaxTree; N: TSyntaxNode;
begin
  T := Parse('case A of 1: if A then if B then X else Y; else Z; end', 2);
  try
    Assert.AreEqual(0, T.DiagnosticCount);
    N := Child(Child(Child(T.Root, 0), 1), 1);
    Assert.AreEqual(Ord(skIfStatement), Ord(N.Kind));
    Assert.AreEqual(2, Count(N, skIfStatement));
    Assert.AreEqual(Ord(skIfStatement), Ord(Child(N, 1).Kind));
    Assert.AreEqual(Ord(skCallStatement), Ord(Child(Child(N, 1), 2).Kind));
    Assert.AreEqual(2, Count(N, skCallStatement));
  finally T.Free; end;
end;

procedure TParserTests.ControlRecovery;
const Sources: array[0..18] of string = (
  'for I := 0 to do Process;', 'for I := 0 10 do Process;',
  'for I 0 to 10 do Process;', 'for I := 0 to 10 Process;',
  'while Active Process;', 'while Active do',
  'repeat Process; end;', 'repeat Process; until ;',
  'case Value of 1 Process; 2: ProcessOther; end;',
  'case Value 1: Process; end;', 'case A of : Process; end;',
  'case A of 1 + 2: Process; end;',
  'try Process; finally Cleanup;', 'try Process; end;',
  'try Process; except on E: do Handle; on Exception do Other; end;',
  'try Process; except on E Exception do Handle; end;',
  'try Process; except on : Exception do Handle; end;',
  'while do ;', 'case A of 1: try Work; finally Cleanup; end');
var A, B: TSyntaxTree; I, J: Integer;
begin
  for I := Low(Sources) to High(Sources) do
  begin
    A := Parse(Sources[I], 2);
    try
      Assert.IsTrue(A.DiagnosticCount > 0, Sources[I]);
      B := Parse(Sources[I], 2);
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

procedure TParserTests.ControlRoutineRecovery;
const Fragments: array[0..4] of string = (
  'try Work; finally Cleanup;', 'case X of 1: Work;',
  'repeat Work;', 'while X do', 'try case X of 1: Work;');
var T: TSyntaxTree; S: string;
begin
  for S in Fragments do
  begin
    T := Parse('unit U; interface implementation procedure A; begin ' + S +
      ' procedure B; begin Save; end; end.');
    try
      Assert.AreEqual(2, Count(T.Root, skRoutineDeclaration), S);
      Assert.IsTrue(T.DiagnosticCount > 0);
      Assert.IsTrue(Count(T.Root, skCallStatement) >= 1);
    finally T.Free; end;
  end;
end;

procedure TParserTests.ControlDirectives;
const Sources: array[0..2] of string = (
  'while X do {$IFDEF X} Work {$ENDIF}',
  'try Work; {$I x.inc} finally Cleanup; end',
  'case X of 1: {$R x.res} Work; end');
var T: TSyntaxTree; S: string;
begin
  for S in Sources do
  begin
    T := Parse(S, 2);
    try
      Assert.AreEqual(0, Count(T.Root, skWhileStatement));
      Assert.AreEqual(0, Count(T.Root, skTryFinallyStatement));
      Assert.AreEqual(0, Count(T.Root, skCaseStatement));
      Assert.IsTrue(Count(T.Root, skOpaqueRegion) > 0);
    finally T.Free; end;
  end;
end;

procedure TParserTests.ControlStress;
var T: TSyntaxTree; B: TStringBuilder; I: Integer;
begin
  B := TStringBuilder.Create;
  try
    B.Append('begin case X of ');
    for I := 0 to 1023 do B.Append(IntToStr(I) + ': Process; ');
    B.Append('end; repeat ');
    for I := 0 to 2047 do B.Append('while Active do Process; ');
    B.Append('until Done; end');
    T := Parse(B.ToString, 2);
    try
      Assert.AreEqual(1024, Count(T.Root, skCaseBranch));
      Assert.AreEqual(2048, Count(T.Root, skWhileStatement));
      Assert.AreEqual(0, T.DiagnosticCount);
    finally T.Free; end;
  finally B.Free; end;
end;

procedure TParserTests.ControlDepth;
const Openers: array[0..3] of string = ('while X do ', 'for I := 0 to 1 do ',
  'try ', 'case X of 1: ');
var T: TSyntaxTree; S, Opener: string; I: Integer;
begin
  for Opener in Openers do
  begin
    S := 'Process';
    for I := 1 to 150 do
    begin
      if Opener = 'try ' then S := Opener + S + '; finally Cleanup; end'
      else if Opener = 'case X of 1: ' then S := Opener + S + '; end'
      else S := Opener + S;
    end;
    T := Parse(S, 2);
    try
      Assert.IsTrue(Count(T.Root, skOpaqueRegion) > 0, Opener);
      Assert.IsTrue(T.DiagnosticCount > 0, Opener);
      Assert.AreEqual('PAR004', T.GetDiagnostic(0).Code);
    finally T.Free; end;
  end;
end;

procedure TParserTests.ControlMalformedLifetimes;
const Parts: array[0..10] of string = ('for I := ', 'while ', 'repeat ',
  'until ', 'case X of ', '1: ', 'try ', 'except on E: ', 'finally ', 'do ', '; end; ');
var A, B: TSyntaxTree; S: string; I, J: Integer;
begin
  for I := 0 to 299 do
  begin
    S := 'begin ';
    for J := 0 to 8 + I mod 30 do
      S := S + Parts[(I * 7 + J * 3 + J * J) mod Length(Parts)];
    S := S + Char($D800) + ' end';
    A := Parse(S, 2);
    try
      B := Parse(S, 2);
      try
        Assert.AreEqual(Shape(A.Root), Shape(B.Root));
        Assert.AreEqual(A.DiagnosticCount, B.DiagnosticCount);
      finally B.Free; end;
    finally A.Free; end;
  end;
end;

procedure TParserTests.CompiledControlFlowCorpus;
var T: TSyntaxTree;
begin
  T := Parse(TFile.ReadAllText('tests/Fixtures/ControlFlowCorpus.pas', TEncoding.UTF8));
  try
    Assert.AreEqual(0, T.DiagnosticCount);
    Assert.AreEqual(3, Count(T.Root, skForStatement));
    Assert.AreEqual(1, Count(T.Root, skForInStatement));
    Assert.AreEqual(2, Count(T.Root, skRepeatStatement));
    Assert.AreEqual(2, Count(T.Root, skCaseStatement));
    Assert.AreEqual(2, Count(T.Root, skTryExceptStatement));
    Assert.AreEqual(1, Count(T.Root, skTryFinallyStatement));
    Assert.AreEqual(2, Count(T.Root, skExceptionHandler));
    Assert.AreEqual(2, Count(T.Root, skRaiseStatement));
    Assert.AreEqual(0, Count(T.Root, skOpaqueRegion));
  finally T.Free; end;
end;

procedure TParserTests.ControlHandlerRecovery;
const Headers: array[0..3] of string = ('E: Exception<T>', ': Exception',
  'E Exception', 'E:');
var T: TSyntaxTree; Header: string; N: TSyntaxNode;
begin
  for Header in Headers do
  begin
    T := Parse('try Work; except on ' + Header + ' do Handle; ' +
      'on System.SysUtils.Exception do Recover; else Other; end', 2);
    try
      Assert.IsTrue(T.DiagnosticCount > 0, Header);
      Assert.AreEqual(2, Count(T.Root, skExceptionHandler), Header);
      N := Child(Child(T.Root, 0), 2);
      Assert.AreEqual(Ord(skExceptionHandler), Ord(N.Kind));
      Assert.AreEqual(1, Count(N, skTypeReference));
      Assert.AreEqual(1, Count(N, skCallStatement));
    finally T.Free; end;
  end;
end;

procedure TParserTests.ControlSeparatorsAndTrivia;
var T: TSyntaxTree; N, L: TSyntaxNode; I, Separators: Integer;
begin
  T := Parse('repeat {body}'#13#10'; Work; ; until {test} Done;', 2);
  try
    Assert.AreEqual(0, T.DiagnosticCount);
    N := Child(T.Root, 0);
    L := Child(N, 0);
    Assert.AreEqual(2, Count(L, skEmptyStatement));
    Separators := 0;
    for I := 0 to L.ChildCount - 1 do
      if L.GetChild(I) is TSyntaxToken then
        if not TSyntaxToken(L.GetChild(I)).IsMissing and
          (Copy(T.Source, L.GetChild(I).Span.StartOffset + 1,
            L.GetChild(I).Span.Length) = ';') then Inc(Separators);
    Assert.AreEqual(3, Separators);
    Assert.AreEqual(Length(T.Source) - 1, N.Span.EndOffset);
    Assert.AreEqual(Ord(skIdentifierExpression), Ord(Child(N, 1).Kind));
  finally T.Free; end;
  T := Parse('try Work; finally begin Cleanup; end', 2);
  try
    Assert.IsTrue(Count(T.Root, skMissingToken) > 0);
    Assert.AreEqual(1, Count(T.Root, skBlockStatement));
  finally T.Free; end;
end;

procedure TParserTests.ControlOpaqueFallback;
var T: TSyntaxTree;
begin
  T := Parse('begin with Obj do begin Work; More; end; AfterWork; end', 2);
  try
    Assert.AreEqual(1, Count(T.Root, skOpaqueRegion));
    Assert.AreEqual(1, Count(T.Root, skCallStatement));
  finally T.Free; end;
  T := Parse('begin for var I := 0 to 10 do begin Work; end; AfterWork; end', 2);
  try
    Assert.AreEqual(0, Count(T.Root, skForStatement));
    Assert.AreEqual(1, Count(T.Root, skCallStatement));
    Assert.IsTrue(Count(T.Root, skOpaqueRegion) > 0);
  finally T.Free; end;
  T := Parse('begin raise E at Address; AfterWork; end', 2);
  try
    Assert.AreEqual(0, Count(T.Root, skRaiseStatement));
    Assert.AreEqual(1, Count(T.Root, skCallStatement));
    Assert.IsTrue(Count(T.Root, skOpaqueRegion) > 0);
  finally T.Free; end;
  T := Parse('case X of (1 + 2): Work; 3: Other; end', 2);
  try
    Assert.AreEqual(2, Count(T.Root, skCaseBranch));
    Assert.AreEqual(2, Count(T.Root, skCallStatement));
    Assert.IsTrue(Count(T.Root, skOpaqueRegion) > 0);
  finally T.Free; end;
end;

procedure TParserTests.SameDiagnostics(A, B: TSyntaxTree);
var I: Integer;
begin
  Assert.AreEqual(A.DiagnosticCount, B.DiagnosticCount);
  for I := 0 to A.DiagnosticCount - 1 do
  begin
    Assert.AreEqual(A.GetDiagnostic(I).Code, B.GetDiagnostic(I).Code);
    Assert.AreEqual(A.GetDiagnostic(I).Message, B.GetDiagnostic(I).Message);
    Assert.AreEqual(Ord(A.GetDiagnostic(I).Severity), Ord(B.GetDiagnostic(I).Severity));
    Assert.AreEqual(A.GetDiagnostic(I).Span.StartOffset, B.GetDiagnostic(I).Span.StartOffset);
    Assert.AreEqual(A.GetDiagnostic(I).Span.Length, B.GetDiagnostic(I).Span.Length);
  end;
end;

procedure TParserTests.CheckOpaqueBody(const Body: string);
var A, B: TSyntaxTree; BlockNode, OpaqueNode: TSyntaxNode; I, Separators: Integer;
begin
  A := Parse('begin ' + Body + '; ContinueWork; end', 2);
  try
    BlockNode := Child(A.Root, 0);
    Assert.AreEqual(Ord(skBlockStatement), Ord(BlockNode.Kind), Body);
    OpaqueNode := Child(BlockNode, 0);
    Assert.AreEqual(Ord(skOpaqueRegion), Ord(OpaqueNode.Kind), Body);
    Assert.AreEqual(Body, Trim(Copy(A.Source, OpaqueNode.Span.StartOffset + 1,
      OpaqueNode.Span.Length)), 'Complete opaque extent: ' + Body);
    Assert.AreEqual(Ord(skCallStatement), Ord(Child(BlockNode, 1).Kind));
    Assert.AreEqual('ContinueWork', Trim(Copy(A.Source,
      Child(BlockNode, 1).Span.StartOffset + 1, Child(BlockNode, 1).Span.Length)));
    Assert.AreEqual(1, Count(A.Root, skOpaqueRegion));
    Assert.AreEqual(1, Count(A.Root, skBlockStatement));
    Assert.AreEqual(1, Count(A.Root, skCallStatement));
    Assert.AreEqual(0, Count(A.Root, skIfStatement));
    Assert.AreEqual(0, Count(A.Root, skForStatement));
    Assert.AreEqual(0, Count(A.Root, skMissingToken));
    Separators := 0;
    for I := 0 to BlockNode.ChildCount - 1 do
      if BlockNode.GetChild(I) is TSyntaxToken then
        if Copy(A.Source, BlockNode.GetChild(I).Span.StartOffset + 1,
          BlockNode.GetChild(I).Span.Length) = ';' then Inc(Separators);
    Assert.AreEqual(2, Separators, 'Both separators belong to the outer block');
    Assert.AreEqual(1, A.DiagnosticCount, Body);
    Assert.AreEqual('PAR003', A.GetDiagnostic(0).Code);
    B := Parse(A.Source, 2);
    try
      Assert.AreEqual(Shape(A.Root), Shape(B.Root));
      SameDiagnostics(A, B);
    finally B.Free; end;
  finally A.Free; end;
end;

procedure TParserTests.OpaqueWithBodies;
const Bodies: array[0..10] of string = (
  'if Active then Save else Reset',
  'begin Save; Reset; end',
  'case State of 0: Save; 1: if Active then Save else Reset; else Reset; end',
  'try Save; finally Reset; end',
  'try Save; except on E: Exception do if Active then Save else Reset; else Reset; end',
  'repeat Save; if Active then Reset; until Done',
  'begin begin Save; end; Reset; end',
  'while Active do if Ready then Save else Reset',
  'with Other do if Active then Save else Reset',
  'Value := Other.Value + 1',
  'for I := 0 to 10 do if Ready then Save else Reset');
var Body: string;
begin
  for Body in Bodies do CheckOpaqueBody('with Customer do ' + Body);
end;

procedure TParserTests.OpaqueInlineForBodies;
const Bodies: array[0..3] of string = ('Process(I)',
  'if I > 5 then Process(I) else Skip(I)',
  'begin Process(I); Skip(I); end',
  'repeat Process(I); until Done');
var Body: string;
begin
  for Body in Bodies do CheckOpaqueBody('for var I := 0 to 10 do ' + Body);
end;

procedure TParserTests.OpaqueElseOwnership;
const Bodies: array[0..4] of string = (
  'with Customer do Save',
  'with Customer do if B then Save else Reset',
  'with Customer do if B then if C then Save else Reset else Other',
  'for var I := 0 to 10 do if B then Save else Reset',
  'with Customer do begin if B then Save else Reset; end');
var Body: string; A, B: TSyntaxTree; N, O: TSyntaxNode;
begin
  for Body in Bodies do
  begin
    A := Parse('if Active then ' + Body + ' else HandleInactive', 2);
    try
      N := Child(A.Root, 0);
      Assert.AreEqual(Ord(skIfStatement), Ord(N.Kind));
      Assert.AreEqual(Ord(skIdentifierExpression), Ord(Child(N, 0).Kind));
      O := Child(N, 1);
      Assert.AreEqual(Ord(skOpaqueRegion), Ord(O.Kind));
      Assert.AreEqual(Body, Trim(Copy(A.Source, O.Span.StartOffset + 1, O.Span.Length)));
      Assert.AreEqual(Ord(skCallStatement), Ord(Child(N, 2).Kind));
      Assert.AreEqual('HandleInactive', Trim(Copy(A.Source,
        Child(N, 2).Span.StartOffset + 1, Child(N, 2).Span.Length)));
      Assert.AreEqual(1, Count(A.Root, skIfStatement));
      Assert.AreEqual(1, Count(A.Root, skCallStatement));
      Assert.AreEqual(1, A.DiagnosticCount);
      Assert.AreEqual('PAR003', A.GetDiagnostic(0).Code);
      B := Parse(A.Source, 2);
      try
        Assert.AreEqual(Shape(A.Root), Shape(B.Root));
        SameDiagnostics(A, B);
      finally B.Free; end;
    finally A.Free; end;
  end;
  A := Parse('if Active then with Customer do if B then Save else Reset', 2);
  try
    N := Child(A.Root, 0);
    O := Child(N, 1);
    Assert.AreEqual(Ord(skOpaqueRegion), Ord(O.Kind));
    Assert.AreEqual('with Customer do if B then Save else Reset',
      Trim(Copy(A.Source, O.Span.StartOffset + 1, O.Span.Length)));
    Assert.AreEqual(1, Count(A.Root, skIfStatement));
    Assert.AreEqual(0, Count(A.Root, skCallStatement));
    Assert.AreEqual(1, A.DiagnosticCount);
    B := Parse(A.Source, 2);
    try SameDiagnostics(A, B); finally B.Free; end;
  finally A.Free; end;
  A := Parse('if A then if B then with Customer do Save else Reset', 2);
  try
    N := Child(Child(A.Root, 0), 1);
    Assert.AreEqual(Ord(skIfStatement), Ord(N.Kind));
    Assert.AreEqual(Ord(skOpaqueRegion), Ord(Child(N, 1).Kind));
    Assert.AreEqual(Ord(skCallStatement), Ord(Child(N, 2).Kind));
    Assert.AreEqual(2, Count(A.Root, skIfStatement));
    Assert.AreEqual(1, Count(A.Root, skCallStatement));
    Assert.AreEqual(1, A.DiagnosticCount);
    B := Parse(A.Source, 2);
    try SameDiagnostics(A, B); finally B.Free; end;
  finally A.Free; end;
end;

procedure TParserTests.OpaqueMalformedStatements;
const Fragments: array[0..5] of string = ('with Customer do',
  'with Customer do if Active then Save else', 'with Customer begin Save;',
  'with Customer do begin Save;', 'for var I := 0 to 10 do begin Save;',
  'with Customer do try Save; finally Reset;');
var S: string; A, B: TSyntaxTree;
begin
  CheckOpaqueBody('with Customer Save'); // missing do: conservative complete fragment
  CheckOpaqueBody('with Customer do Obj.'); // a broken member never hides a separator
  for S in Fragments do
  begin
    A := Parse(S, 2);
    try
      Assert.AreEqual(1, Count(A.Root, skOpaqueRegion), S);
      Assert.AreEqual(0, Count(A.Root, skIfStatement));
      Assert.AreEqual(0, Count(A.Root, skCallStatement));
      B := Parse(S, 2);
      try SameDiagnostics(A, B); finally B.Free; end;
    finally A.Free; end;
    A := Parse('unit U; interface implementation procedure A; begin ' + S +
      ' procedure B; begin ContinueWork; end; end.');
    try
      Assert.AreEqual(2, Count(A.Root, skRoutineDeclaration), S);
      Assert.AreEqual(1, Count(A.Root, skCallStatement), S);
      B := Parse(A.Source);
      try SameDiagnostics(A, B); finally B.Free; end;
    finally A.Free; end;
  end;
end;

procedure TParserTests.OpaqueKeywordTrivia;
var A, B: TSyntaxTree;
begin
  CheckOpaqueBody('with Customer do if {then else begin} Active then ' +
    'Save(''if then else case try repeat end'', ''else'') else Reset');
  CheckOpaqueBody('with Customer do Save(''then'', ''else'', ''end'')');
  CheckOpaqueBody('with Customer do Obj.&if(''else'')');
  CheckOpaqueBody('with Customer do Obj.If(''else'')');
  CheckOpaqueBody('with Customer do begin Obj.End; Obj.Try; Obj.Repeat; end');
  CheckOpaqueBody('for var I := 0 to 10 do if Active then'#13#10 +
    '// else then end'#13#10' Save else Reset');
  A := Parse('unit U; interface implementation procedure Exercise; begin ' +
    'with Customer do Obj.Procedure; ContinueWork; end; end.');
  try
    Assert.AreEqual(1, Count(A.Root, skRoutineDeclaration));
    Assert.AreEqual(1, Count(A.Root, skCallStatement));
    Assert.AreEqual(1, Count(A.Root, skOpaqueRegion));
    Assert.AreEqual(1, A.DiagnosticCount);
    B := Parse(A.Source);
    try SameDiagnostics(A, B); finally B.Free; end;
  finally A.Free; end;
end;

procedure TParserTests.OpaqueUnsupportedStress;
var Builder: TStringBuilder; A, B: TSyntaxTree; I, J: Integer; S: string;
begin
  Builder := TStringBuilder.Create;
  try
    Builder.Append('begin ');
    for I := 1 to 256 do
    begin
      Builder.Append('with Customer do ');
      for J := 1 to 32 do Builder.Append('if A then ');
      Builder.Append('begin Save; Reset; end');
      for J := 1 to 32 do Builder.Append(' else Other');
      Builder.Append('; ');
    end;
    Builder.Append('ContinueWork; MoreWork; LastWork; end');
    S := Builder.ToString;
  finally Builder.Free; end;
  A := Parse(S, 2);
  try
    Assert.AreEqual(256, Count(A.Root, skOpaqueRegion));
    Assert.AreEqual(3, Count(A.Root, skCallStatement));
    Assert.AreEqual(0, Count(A.Root, skIfStatement));
    B := Parse(S, 2);
    try SameDiagnostics(A, B); finally B.Free; end;
  finally A.Free; end;
end;

procedure TParserTests.OpaqueUnsupportedDirectives;
const Directives: array[0..2] of string = ('{$IFDEF X}', '{$I x.inc}', '{$R x.res}');
var D: string; A, B: TSyntaxTree;
begin
  for D in Directives do
  begin
    A := Parse('begin with Customer do if Active then ' + D +
      ' Save else Reset; ContinueWork; end', 2);
    try
      Assert.AreEqual(0, Count(A.Root, skBlockStatement));
      Assert.AreEqual(0, Count(A.Root, skCallStatement));
      Assert.AreEqual(1, Count(A.Root, skOpaqueRegion));
      B := Parse(A.Source, 2);
      try SameDiagnostics(A, B); finally B.Free; end;
    finally A.Free; end;
  end;
end;

procedure TParserTests.OpaqueUnsupportedDepthAndLifetimes;
var A, B: TSyntaxTree; Builder: TStringBuilder; S: string; I: Integer;
begin
  Builder := TStringBuilder.Create;
  try
    Builder.Append('begin with Customer do ');
    for I := 1 to 150 do Builder.Append('if Active then ');
    Builder.Append('Save');
    for I := 1 to 150 do Builder.Append(' else Reset');
    Builder.Append('; ContinueWork; end');
    S := Builder.ToString;
  finally Builder.Free; end;
  A := Parse(S, 2);
  try
    Assert.AreEqual(1, Count(A.Root, skOpaqueRegion));
    Assert.AreEqual(0, Count(A.Root, skIfStatement));
    Assert.AreEqual(1, Count(A.Root, skCallStatement));
    Assert.AreEqual(2, A.DiagnosticCount);
    Assert.AreEqual('PAR004', A.GetDiagnostic(1).Code);
    B := Parse(S, 2);
    try SameDiagnostics(A, B); finally B.Free; end;
  finally A.Free; end;
  for I := 0 to 199 do
  begin
    S := 'begin with Customer do if Active then Save(''' +
      Char($D800 + I mod 1024) + ''') else Reset; ContinueWork; end';
    A := Parse(S, 2);
    try
      Assert.AreEqual(1, Count(A.Root, skOpaqueRegion));
      Assert.AreEqual(1, Count(A.Root, skCallStatement));
      Assert.AreEqual(2, A.DiagnosticCount);
      B := Parse(S, 2);
      try
        Assert.AreEqual(Shape(A.Root), Shape(B.Root));
        SameDiagnostics(A, B);
      finally B.Free; end;
    finally A.Free; end;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TParserTests);

end.
