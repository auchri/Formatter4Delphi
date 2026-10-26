unit DelphiFormatter.Parser.Delphi;

interface

uses
  System.Generics.Collections, DelphiFormatter.Core.Diagnostics,
  DelphiFormatter.Lexer.Tokens, DelphiFormatter.Syntax.Kinds,
  DelphiFormatter.Syntax.Nodes, DelphiFormatter.Syntax.Tree,
  DelphiFormatter.Parser.Reader;

type
  TDirectiveClass = (dcNone, dcUnknown, dcSwitch, dcOpen, dcBranch,
    dcElse, dcClose, dcInclude, dcResource);

  TDelphiParser = class
  private
    FLex: TDelphiLexResult;
    FReader: TTokenReader;
    FArena: TObjectList<TSyntaxElement>;
    FDiagnostics: TList<TDiagnostic>;
    FDepth: Integer;
    FRoutineBody: Boolean;
    FAllowDirective, FUnsafeDirective: Boolean;
    FUnsafeDirectiveIndex: Integer;
    FInMember: Boolean;
    FGenericCallOpeners: TArray<Boolean>;
    FDirectives: TArray<TDirectiveClass>;
    FConditionalEnd: TArray<Integer>;
    FConditionalNext: TArray<Integer>;
    FConditionalSafe: TArray<Boolean>;
    FConditionalSafeImplementation: TArray<Boolean>;
    FDirectiveErrors: TArray<TDiagnostic>;
    procedure IndexDirectives;
    function ClassifyDirective(Index: Integer): TDirectiveClass;
    function SafeConditional(Index: Integer; IsInterface: Boolean): Boolean;
    function SectionDirective(IsInterface: Boolean): TSyntaxNode;
    function Node(Kind: TSyntaxKind; Children: TList<TSyntaxElement>): TSyntaxNode;
    procedure Take(Children: TList<TSyntaxElement>);
    procedure Report(const Code, Message: string);
    procedure Missing(Children: TList<TSyntaxElement>; const Expected: string);
    procedure Expect(Children: TList<TSyntaxElement>; const Text: string);
    procedure Identifier(Children: TList<TSyntaxElement>);
    function Boundary: Boolean;
    function Precedence: Integer;
    function AmbiguousGenericCall(MemberName: Boolean = False): Boolean;
    procedure IndexGenericCallOpeners;
    function Expression(MinPrecedence: Integer = 1): TSyntaxNode;
    function Primary: TSyntaxNode;
    function IsAssignableTarget(Target: TSyntaxNode): Boolean;
    function Statement: TSyntaxNode;
    function Block: TSyntaxNode;
    function IfStatement: TSyntaxNode;
    function ControlStatement: TSyntaxNode;
    function StatementList(const Stops: array of string): TSyntaxNode;
    function ListEnd(const Stops: array of string): Boolean;
    function HardStatementEnd: Boolean;
    function CaseStatement: TSyntaxNode;
    function CaseLabel: TSyntaxNode;
    function TryStatement: TSyntaxNode;
    function ExceptionHandler: TSyntaxNode;
    procedure StatementBody(Children: TList<TSyntaxElement>);
    function UsesClause: TSyntaxNode;
    function SectionEnd: Boolean;
    function DeclarationStart: Boolean;
    function TypeReference: TSyntaxNode;
    function DeclarationSection(IsConst: Boolean): TSyntaxNode;
    function Parameters: TSyntaxNode;
    function Routine(IsInterface: Boolean): TSyntaxNode;
    function RoutineHeader: TSyntaxNode;
    function TypeSection: TSyntaxNode;
    function TypeDeclaration: TSyntaxNode;
    function AggregateDeclaration(IsClass: Boolean): TSyntaxNode;
    function AncestorList: TSyntaxNode;
    function VisibilityStart: Boolean;
    function MethodStart: Boolean;
    function MemberBoundary: Boolean;
    function FieldStart: Boolean;
    function SkipRawTrivia(Index: Integer): Integer;
    function MethodDirective: Boolean;
    function FieldDeclaration: TSyntaxNode;
    function MethodDeclaration: TSyntaxNode;
    function PropertyDeclaration: TSyntaxNode;
    function PropertyIndexParameters: TSyntaxNode;
    function PropertySpecifier: TSyntaxNode;
    function PropertySpecifierStart: Boolean;
    function PropertyFragment(InParameters: Boolean = False): TSyntaxNode;
    function PropertyType: TSyntaxNode;
    procedure PropertyName(Children: TList<TSyntaxElement>);
    function OpaqueTypeFragment(IsMember: Boolean;
      ToBodyEnd: Boolean = False; IncludeSemicolon: Boolean = True): TSyntaxNode;
    function OpaqueDeclaration(StopAtSemicolon: Boolean = False): TSyntaxNode;
    function ResourceDirective(Index: Integer): Boolean;
    function UnitDeclaration: TSyntaxNode;
    function OpaqueStatement(TrackAngles: Boolean = False): TSyntaxNode;
    function OpaqueUnsupportedStatement: TSyntaxNode;
    procedure UnitSection(Children: TList<TSyntaxElement>; IsInterface: Boolean);
    function Execute(RootKind: TSyntaxKind): TSyntaxTree;
  public
    constructor Create(ALex: TDelphiLexResult);
    destructor Destroy; override;
    class function Parse(ALex: TDelphiLexResult): TSyntaxTree; static;
    class function ParseExpression(ALex: TDelphiLexResult): TSyntaxTree; static;
    class function ParseStatement(ALex: TDelphiLexResult): TSyntaxTree; static;
  end;

implementation

uses
  System.SysUtils, DelphiFormatter.Core.Spans;

constructor TDelphiParser.Create(ALex: TDelphiLexResult);
var
  I: Integer;
begin
  inherited Create;
  FReader := TTokenReader.Create(ALex);
  FLex := ALex;
  FUnsafeDirectiveIndex := -1;
  FArena := TObjectList<TSyntaxElement>.Create(True);
  FDiagnostics := TList<TDiagnostic>.Create;
  for I := 0 to ALex.DiagnosticCount - 1 do
    FDiagnostics.Add(ALex.GetDiagnostic(I));
end;

destructor TDelphiParser.Destroy;
begin
  FDiagnostics.Free;
  FArena.Free;
  FReader.Free;
  inherited;
end;

function TDelphiParser.Node(Kind: TSyntaxKind;
  Children: TList<TSyntaxElement>): TSyntaxNode;
var
  Offset: Integer;
begin
  Offset := Length(FLex.Source);
  if FReader.Position < FLex.TokenCount then
    Offset := FLex.GetToken(FReader.Position).Span.StartOffset;
  Result := TSyntaxNode.Create(Kind, Children.ToArray, Offset);
  FArena.Add(Result);
end;

procedure TDelphiParser.Take(Children: TList<TSyntaxElement>);
begin
  if (FReader.PeekSignificant.Kind = tkCompilerDirective) and
    not FAllowDirective then
  begin
    FUnsafeDirective := True;
    if FUnsafeDirectiveIndex < 0 then FUnsafeDirectiveIndex := FReader.SignificantIndex;
  end;
  FReader.ConsumeWithTriviaInto(Children, FArena);
end;

procedure TDelphiParser.Report(const Code, Message: string);
var
  Severity: TDiagnosticSeverity;
begin
  Severity := dsError;
  if Code = 'PAR003' then Severity := dsWarning;
  FDiagnostics.Add(TDiagnostic.Create(Code, Message, Severity,
    FReader.PeekSignificant.Span));
end;

procedure TDelphiParser.Missing(Children: TList<TSyntaxElement>;
  const Expected: string);
var
  Leaf: TSyntaxToken;
begin
  if FReader.PeekSignificant.Kind = tkCompilerDirective then
  begin
    FUnsafeDirective := True;
    if FUnsafeDirectiveIndex < 0 then FUnsafeDirectiveIndex := FReader.SignificantIndex;
  end;
  Report('PAR001', 'Expected ' + Expected);
  // Anchor BEFORE pending trivia so sibling spans remain ordered.
  Leaf := TSyntaxToken.CreateMissing(Expected,
    FLex.GetToken(FReader.Position).Span.StartOffset);
  FArena.Add(Leaf);
  Children.Add(Leaf);
end;

procedure TDelphiParser.Expect(Children: TList<TSyntaxElement>; const Text: string);
begin
  if FReader.Matches(Text) then Take(Children)
  else Missing(Children, Text);
end;

procedure TDelphiParser.Identifier(Children: TList<TSyntaxElement>);
begin
  if FReader.PeekSignificant.Kind = tkIdentifier then Take(Children)
  else Missing(Children, 'identifier');
end;

function TDelphiParser.Boundary: Boolean;
begin
  Result := FReader.AtEOF or FReader.Matches(';') or FReader.Matches('end') or
    FReader.Matches('else') or FReader.Matches('then') or
    FReader.Matches(')') or FReader.Matches(']') or FReader.Matches('.)') or
    FReader.Matches(':=') or FReader.Matches(',') or
    FReader.Matches('do') or FReader.Matches('to') or
    FReader.Matches('downto') or FReader.Matches('of') or
    FReader.Matches('until') or FReader.Matches('except') or
    FReader.Matches('finally') or FReader.Matches('on') or
    FReader.Matches('interface') or FReader.Matches('implementation');
  if FRoutineBody then
    Result := Result or MethodStart;
end;

function TDelphiParser.Precedence: Integer;
begin
  // Delphi groups equal-precedence binary operators to the left, including
  // comparisons. 'as' belongs to the multiplicative group, 'is' to comparisons.
  if FReader.Matches('*') or FReader.Matches('/') or FReader.Matches('div') or
    FReader.Matches('mod') or FReader.Matches('and') or FReader.Matches('shl') or
    FReader.Matches('shr') or FReader.Matches('as') then Exit(3);
  if FReader.Matches('+') or FReader.Matches('-') or FReader.Matches('or') or
    FReader.Matches('xor') then Exit(2);
  if FReader.Matches('=') or FReader.Matches('<>') or FReader.Matches('<') or
    FReader.Matches('>') or FReader.Matches('<=') or FReader.Matches('>=') or
    FReader.Matches('in') or FReader.Matches('is') then Exit(1);
  Result := 0;
end;

function TDelphiParser.Expression(MinPrecedence: Integer): TSyntaxNode;
var
  Children: TList<TSyntaxElement>;
  P: Integer;
begin
  Inc(FDepth);
  try
    if FDepth > 128 then
    begin
      Report('PAR004', 'Parser nesting limit reached');
      Exit(OpaqueStatement);
    end;
    Result := Primary;
    while True do
    begin
      P := Precedence;
      if P < MinPrecedence then Break;
      Children := TList<TSyntaxElement>.Create;
      try
        Children.Add(Result);
        Take(Children); // mandatory progress before recursive RHS
        Children.Add(Expression(P + 1));
        Result := Node(skBinaryExpression, Children);
      finally
        Children.Free;
      end;
    end;
  finally
    Dec(FDepth);
  end;
end;

procedure TDelphiParser.IndexGenericCallOpeners;
var
  I, Next, Opener: Integer;
  Openers: TList<Integer>;
  Token: TDelphiToken;
  Text: string;
begin
  // Build once for the immutable stream. Each raw token is visited once;
  // trivia immediately after a closer is visited at most once more. Each
  // opener is pushed and removed once. This also avoids rescanning suffixes
  // for successive identifiers in a long A < B < C ... comparison chain.
  SetLength(FGenericCallOpeners, FLex.TokenCount);
  Openers := TList<Integer>.Create;
  try
    for I := 0 to FLex.TokenCount - 1 do
    begin
      Token := FLex.GetToken(I);
      if not (Token.Kind in [tkIdentifier, tkReservedWord, tkSymbol]) then
        Continue;
      Text := FLex.TokenText(I);
      // Same barriers as the original conservative lookahead, not a generic
      // grammar. Unclosed openers at a barrier or EOF remain false.
      if (Text = ';') or (Text = '(') or SameText(Text, 'then') or
        SameText(Text, 'end') then
        Openers.Clear
      else if Text = '<' then
        Openers.Add(I)
      else if (Text = '>') and (Openers.Count > 0) then
      begin
        Opener := Openers.Last;
        Openers.Delete(Openers.Count - 1);
        Next := I + 1;
        while (Next < FLex.TokenCount - 1) and
          TTokenReader.IsTrivia(FLex.GetToken(Next).Kind) do Inc(Next);
        FGenericCallOpeners[Opener] :=
          (FLex.GetToken(Next).Kind = tkSymbol) and
          (FLex.TokenText(Next) = '(');
      end;
    end;
  finally
    Openers.Free;
  end;
end;

function TDelphiParser.AmbiguousGenericCall(MemberName: Boolean): Boolean;
begin
  Result := False;
  if not ((FReader.PeekSignificant.Kind = tkIdentifier) or
    (MemberName and (FReader.PeekSignificant.Kind = tkReservedWord))) or
    not FReader.Matches('<', 1) then Exit;
  if Length(FGenericCallOpeners) = 0 then IndexGenericCallOpeners;
  Result := FGenericCallOpeners[FReader.SignificantIndex(1)];
end;

function TDelphiParser.Primary: TSyntaxNode;
var
  Children: TList<TSyntaxElement>;
  Kind: TSyntaxKind;
  Before: Integer;
  Closer: string;
  IsIndex: Boolean;
begin
  // A name followed by <...>(...) may be a generic specialization rather
  // than relational operators. Do not claim to understand that grammar yet.
  if AmbiguousGenericCall then
  begin
    Report('PAR003', 'Ambiguous generic call preserved as opaque');
    Exit(OpaqueStatement(True));
  end;
  Children := TList<TSyntaxElement>.Create;
  try
    if FReader.Matches('+') or FReader.Matches('-') or
      FReader.Matches('not') or FReader.Matches('@') then
    begin
      Kind := skUnaryExpression;
      Take(Children);
      Children.Add(Expression(4));
    end
    else if FReader.Matches('(') then
    begin
      Kind := skParenthesizedExpression;
      Take(Children);
      Children.Add(Expression);
      Expect(Children, ')');
    end
    else if FReader.PeekSignificant.Kind = tkIdentifier then
    begin
      Kind := skIdentifierExpression;
      Take(Children);
    end
    else if (FReader.PeekSignificant.Kind in [tkNumber, tkStringLiteral, tkCharCode]) or
      FReader.Matches('nil') then
    begin
      Kind := skLiteralExpression;
      if FReader.PeekSignificant.Kind in [tkStringLiteral, tkCharCode] then
      begin
        Take(Children);
        // Adjacent string/character-code components form one Delphi literal.
        while FReader.PeekSignificant.Kind in [tkStringLiteral, tkCharCode] do
          Take(Children);
      end
      else Take(Children);
    end
    else
    begin
      Kind := skError;
      if Boundary or DeclarationStart then Missing(Children, 'expression')
      else
      begin
        Report('PAR002', 'Unexpected expression token');
        Take(Children);
      end;
    end;
    Result := Node(Kind, Children);
    // Left-fold postfix operators; chain length does not consume parser depth.
    while True do
    begin
      Children.Clear;
      Children.Add(Result);
      if FReader.Matches('.') then
      begin
        Take(Children);
        // Qualified candidates reuse the existing linear angle-opener index.
        if AmbiguousGenericCall(True) then
        begin
          Report('PAR003', 'Ambiguous generic call preserved as opaque');
          Children.Add(OpaqueStatement(True));
          Exit(Node(skOpaqueRegion, Children));
        end;
        // Delphi also permits keyword spellings after qualification.
        if FReader.PeekSignificant.Kind in [tkIdentifier, tkReservedWord] then
          Take(Children)
        else Missing(Children, 'identifier');
        Result := Node(skMemberAccessExpression, Children);
      end
      else if FReader.Matches('^') then
      begin
        Take(Children);
        Result := Node(skDereferenceExpression, Children);
      end
      else if FReader.Matches('(') or FReader.Matches('[') or
        FReader.Matches('(.') then
      begin
        IsIndex := not FReader.Matches('(');
        if FReader.Matches('[') then Closer := ']'
        else if FReader.Matches('(.') then Closer := '.)'
        else Closer := ')';
        Take(Children);
        // Calls may be empty; an index list needs at least one expression.
        if IsIndex or (not FReader.Matches(Closer) and not FReader.AtEOF) then
          while True do
          begin
            Before := FReader.Position;
            Children.Add(Expression);
            if not FReader.Matches(',') then Break;
            Take(Children);
            if FReader.Position <= Before then Break;
          end;
        // Both spellings denote the same bracket token in Delphi.
        if IsIndex and (FReader.Matches(']') or FReader.Matches('.)')) then
          Take(Children)
        else Expect(Children, Closer);
        if IsIndex then Result := Node(skIndexExpression, Children)
        else Result := Node(skCallExpression, Children);
      end
      else Break;
    end;
  finally
    Children.Free;
  end;
end;

function TDelphiParser.OpaqueStatement(TrackAngles: Boolean): TSyntaxNode;
var
  Children: TList<TSyntaxElement>;
  Nesting: Integer;
begin
  Children := TList<TSyntaxElement>.Create;
  try
    Nesting := 0;
    while not FReader.AtEOF do
    begin
      if HardStatementEnd then Break;
      if (Nesting = 0) and Boundary and not (FReader.Matches('do') or
        FReader.Matches('to') or FReader.Matches('downto') or
        FReader.Matches('of')) then Break;
      if FReader.Matches('begin') or FReader.Matches('(') or
        FReader.Matches('case') or FReader.Matches('try') or
        FReader.Matches('repeat') or
        FReader.Matches('[') or FReader.Matches('(.') or
        (TrackAngles and FReader.Matches('<')) then Inc(Nesting)
      else if FReader.Matches('end') or FReader.Matches('until') or FReader.Matches(')') or
        FReader.Matches(']') or FReader.Matches('.)') or
        (TrackAngles and FReader.Matches('>')) then Dec(Nesting);
      Take(Children); // each continuing iteration consumes original tokens
    end;
    Result := Node(skOpaqueRegion, Children);
  finally
    Children.Free;
  end;
end;

function TDelphiParser.OpaqueUnsupportedStatement: TSyntaxNode;
const
  END_BLOCK = 1;
  TRY_BLOCK = 2;
  REPEAT_BLOCK = 3;
var
  Children: TList<TSyntaxElement>;
  Qualified: Boolean;

  procedure Consume;
  begin
    // Only significant keyword tokens drive the envelope. A keyword after a
    // dot is a member name; comments, strings and escaped names are inert.
    Qualified := FReader.Matches('.') and
      (FReader.PeekSignificant(1).Kind in [tkIdentifier, tkReservedWord]);
    Take(Children);
  end;

  function AtHardEnd: Boolean;
  begin
    Result := FReader.AtEOF or (not Qualified and HardStatementEnd);
  end;

  function AtStatementEnd: Boolean;
  begin
    Result := AtHardEnd or (not Qualified and (FReader.Matches(';') or
      FReader.Matches('end') or FReader.Matches('until') or
      FReader.Matches('finally') or FReader.Matches('except') or
      FReader.Matches('else') or FReader.Matches('on')));
  end;

  procedure SkipBalanced(Compound, PreserveElse: Boolean);
  var
    Openers: TList<Integer>;
    Parens, TryCount, Opener: Integer;
  begin
    Openers := TList<Integer>.Create;
    try
      Parens := 0;
      TryCount := 0;
      while not AtHardEnd do
      begin
        if (Parens = 0) and not Qualified then
        begin
          if (Openers.Count = 0) and
            (FReader.Matches(';') or FReader.Matches('end') or
             FReader.Matches('until') or FReader.Matches('finally') or
             FReader.Matches('except') or FReader.Matches('on') or
             (PreserveElse and FReader.Matches('else'))) then Break;
          // Keep outer exception/repeat terminators when this opaque body is
          // incomplete. An absent end's intended owner otherwise stays ambiguous.
          if (TryCount = 0) and (FReader.Matches('finally') or
            FReader.Matches('except')) then Break;
          Opener := 0;
          if FReader.Matches('begin') or FReader.Matches('case') then Opener := END_BLOCK
          else if FReader.Matches('try') then Opener := TRY_BLOCK
          else if FReader.Matches('repeat') then Opener := REPEAT_BLOCK;
          if Opener <> 0 then
          begin
            Openers.Add(Opener);
            if Opener = TRY_BLOCK then Inc(TryCount);
          end
          else if FReader.Matches('end') or FReader.Matches('until') then
          begin
            if Openers.Count = 0 then Break;
            if (Openers.Last = REPEAT_BLOCK) <> FReader.Matches('until') then Break;
            if Openers.Last = TRY_BLOCK then Dec(TryCount);
            Openers.Delete(Openers.Count - 1);
            Consume;
            if Compound and (Openers.Count = 0) then Break;
            Continue;
          end;
        end;
        if FReader.Matches('(') or FReader.Matches('[') or
          FReader.Matches('(.') then Inc(Parens)
        else if FReader.Matches(')') or FReader.Matches(']') or
          FReader.Matches('.)') then
        begin
          if Parens = 0 then Break;
          Dec(Parens);
        end;
        Consume; // every continuing iteration consumes an original token
      end;
    finally Openers.Free; end;
  end;

  procedure SkipHeader(const Delimiter: string);
  var
    Parens: Integer;
  begin
    Parens := 0;
    while not AtHardEnd do
    begin
      if (Parens = 0) and not Qualified then
      begin
        if FReader.Matches(Delimiter) or AtStatementEnd then Break;
        // A clear body opener after a missing do/then remains opaque with its
        // prefix, rather than leaking its internal statements into the CST.
        if FReader.Matches('begin') or FReader.Matches('if') or
          FReader.Matches('case') or FReader.Matches('try') or
          FReader.Matches('repeat') or FReader.Matches('with') or
          FReader.Matches('while') or FReader.Matches('for') then Break;
      end;
      if FReader.Matches('(') or FReader.Matches('[') or
        FReader.Matches('(.') then Inc(Parens)
      else if FReader.Matches(')') or FReader.Matches(']') or
        FReader.Matches('.)') then
      begin
        if Parens = 0 then Break;
        Dec(Parens);
      end;
      Consume;
    end;
  end;

  procedure SkipOne(Depth: Integer);
  var
    IsRepeat: Boolean;
  begin
    if AtStatementEnd then Exit;
    if Depth > 128 then
    begin
      Report('PAR004', 'Parser nesting limit reached');
      // At the guard, retain a larger fragment through the next safe separator;
      // do not recurse or invent nested structure for the remaining source.
      SkipBalanced(False, False);
      Exit;
    end;
    if FReader.Matches('if') then
    begin
      Consume;
      SkipHeader('then');
      if FReader.Matches('then') then Consume;
      SkipOne(Depth + 1);
      // Exactly this skipped if may own one else. Returning through with/for
      // envelopes leaves any further else for the supported outer IfStatement.
      if FReader.Matches('else') then
      begin
        Consume;
        SkipOne(Depth + 1);
      end;
    end
    else if FReader.Matches('with') or FReader.Matches('for') or
      FReader.Matches('while') then
    begin
      Consume;
      SkipHeader('do');
      if FReader.Matches('do') then Consume;
      SkipOne(Depth + 1);
    end
    else if FReader.Matches('begin') or FReader.Matches('case') or
      FReader.Matches('try') or FReader.Matches('repeat') then
    begin
      IsRepeat := FReader.Matches('repeat');
      SkipBalanced(True, True);
      if IsRepeat then SkipBalanced(False, True); // until condition
    end
    else SkipBalanced(False, True);
  end;

begin
  Children := TList<TSyntaxElement>.Create;
  try
    Qualified := False;
    SkipOne(FDepth);
    Result := Node(skOpaqueRegion, Children);
  finally Children.Free; end;
end;

function TDelphiParser.IsAssignableTarget(Target: TSyntaxNode): Boolean;
var
  I: Integer;
  Receiver: TSyntaxNode;
begin
  // A bare call is not a target. Inside a designator, calls may return an
  // object/pointer. Writability and name resolution belong to semantics.
  Result := False;
  if Target.Kind = skCallExpression then Exit;
  while Target.Kind in [skMemberAccessExpression, skIndexExpression,
    skDereferenceExpression, skCallExpression, skParenthesizedExpression] do
  begin
    Receiver := nil;
    for I := 0 to Target.ChildCount - 1 do
    begin
      if Target.GetChild(I).Kind = skMissingToken then Exit;
      if (Receiver = nil) and (Target.GetChild(I) is TSyntaxNode) then
        Receiver := TSyntaxNode(Target.GetChild(I));
    end;
    if Receiver = nil then Exit;
    Target := Receiver;
  end;
  Result := Target.Kind = skIdentifierExpression;
end;

function TDelphiParser.Statement: TSyntaxNode;
var
  Children: TList<TSyntaxElement>;
  Left: TSyntaxNode;
  Kind: TSyntaxKind;
begin
  Inc(FDepth);
  try
    if FDepth > 128 then
    begin
      Report('PAR004', 'Parser nesting limit reached');
      Exit(OpaqueStatement);
    end;
    if FReader.Matches('begin') then Exit(Block);
    if FReader.Matches('if') then Exit(IfStatement);
    if FReader.Matches('for') or FReader.Matches('while') or
      FReader.Matches('repeat') or FReader.Matches('raise') then
      Exit(ControlStatement);
    if FReader.Matches('case') then Exit(CaseStatement);
    if FReader.Matches('try') then Exit(TryStatement);
    Children := TList<TSyntaxElement>.Create;
    try
      if Boundary then
        Exit(Node(skEmptyStatement, Children));
      if FReader.PeekSignificant.Kind <> tkIdentifier then
      begin
        Report('PAR003', 'Unsupported statement preserved as opaque');
        if FReader.Matches('with') then Exit(OpaqueUnsupportedStatement);
        Exit(OpaqueStatement);
      end;
      Left := Expression;
      Children.Add(Left);
      if FReader.Matches(':=') then
      begin
        Kind := skAssignmentStatement;
        if not IsAssignableTarget(Left) then
        begin
          Kind := skError;
          Report('PAR002', 'Unsupported assignment target');
        end;
        Take(Children);
        Children.Add(Expression);
      end
      else if (Left.Kind = skCallExpression) or IsAssignableTarget(Left) then
        Kind := skCallStatement
      else
      begin
        Kind := skError;
        Report('PAR002', 'Expected assignment or call');
      end;
      if not Boundary then
      begin
        Report('PAR003', 'Unsupported statement suffix preserved as opaque');
        Children.Add(OpaqueStatement);
        Kind := skOpaqueRegion;
      end;
      Result := Node(Kind, Children);
    finally
      Children.Free;
    end;
  finally
    Dec(FDepth);
  end;
end;

function TDelphiParser.Block: TSyntaxNode;
var
  Children, Unexpected: TList<TSyntaxElement>;
  Before: Integer;
begin
  Children := TList<TSyntaxElement>.Create;
  try
    Expect(Children, 'begin');
    while not FReader.AtEOF and not FReader.Matches('end') and
      not FReader.Matches('implementation') and not FReader.Matches('until') and
      not FReader.Matches('finally') and not FReader.Matches('except') do
    begin
      if FRoutineBody and (MethodStart or
        (FReader.Matches('end') and FReader.Matches('.', 1))) then Break;
      if FReader.Matches('else') then
      begin
        Report('PAR002', 'Else cannot follow a statement separator');
        Unexpected := TList<TSyntaxElement>.Create;
        try
          Take(Unexpected);
          Children.Add(Node(skError, Unexpected));
        finally Unexpected.Free; end;
        Continue;
      end;
      Before := FReader.Position;
      Children.Add(Statement);
      if FReader.Matches(';') then Take(Children)
      else if FReader.Matches('else') then Break // recover a missing block end
      else if not FReader.Matches('end') and not FReader.AtEOF then
        Missing(Children, ';');
      if FReader.Position = Before then
      begin
        // A boundary not belonging to this block: preserve one token and retry.
        Report('PAR002', 'Unexpected token in block');
        Unexpected := TList<TSyntaxElement>.Create;
        try
          Take(Unexpected);
          Children.Add(Node(skError, Unexpected));
        finally Unexpected.Free; end;
      end;
    end;
    if FRoutineBody and FReader.Matches('end') and FReader.Matches('.', 1) then
      Missing(Children, 'end')
    else Expect(Children, 'end');
    Result := Node(skBlockStatement, Children);
  finally
    Children.Free;
  end;
end;

function TDelphiParser.IfStatement: TSyntaxNode;
var
  Children: TList<TSyntaxElement>;
begin
  Children := TList<TSyntaxElement>.Create;
  try
    Take(Children);
    Children.Add(Expression);
    Expect(Children, 'then');
    Children.Add(Statement);
    // Statement never consumes the separator. Thus '; else' cannot bind here,
    // and recursion binds an unseparated else to the nearest unmatched if.
    if FReader.Matches('else') then
    begin
      Take(Children);
      Children.Add(Statement);
    end;
    Result := Node(skIfStatement, Children);
  finally
    Children.Free;
  end;
end;

function TDelphiParser.HardStatementEnd: Boolean;
begin
  Result := FReader.AtEOF or FReader.Matches('implementation') or
    FReader.Matches('interface') or
    (FRoutineBody and (MethodStart or
      (FReader.Matches('end') and FReader.Matches('.', 1))));
end;

function TDelphiParser.ListEnd(const Stops: array of string): Boolean;
var
  Text: string;
begin
  Result := True;
  if HardStatementEnd then Exit;
  for Text in Stops do
    if FReader.Matches(Text) then Exit;
  // Preserve delimiters belonging to an enclosing, incomplete construct.
  Result := FReader.Matches('end') or FReader.Matches('until') or
    FReader.Matches('finally') or FReader.Matches('except') or
    FReader.Matches('else');
end;

function TDelphiParser.StatementList(const Stops: array of string): TSyntaxNode;
var
  Children, Unexpected: TList<TSyntaxElement>;
  Before: Integer;
begin
  Children := TList<TSyntaxElement>.Create;
  try
    while not ListEnd(Stops) do
    begin
      Before := FReader.Position;
      Children.Add(Statement);
      if FReader.Matches(';') then Take(Children)
      else if not ListEnd(Stops) then Missing(Children, ';');
      if Before = FReader.Position then
      begin
        Report('PAR002', 'Unexpected token in statement list');
        Unexpected := TList<TSyntaxElement>.Create;
        try
          Take(Unexpected);
          Children.Add(Node(skError, Unexpected));
        finally Unexpected.Free; end;
      end;
    end;
    Result := Node(skStatementList, Children);
  finally Children.Free; end;
end;

procedure TDelphiParser.StatementBody(Children: TList<TSyntaxElement>);
begin
  if HardStatementEnd or (Boundary and not FReader.Matches(';')) then
    Missing(Children, 'statement')
  else Children.Add(Statement);
end;

function TDelphiParser.ControlStatement: TSyntaxNode;
var
  Children, VariableName: TList<TSyntaxElement>;
  Kind: TSyntaxKind;
begin
  Children := TList<TSyntaxElement>.Create;
  try
    if FReader.Matches('for') then
    begin
      if FReader.Matches('var', 1) then
      begin
        Report('PAR003', 'Inline loop variable preserved as opaque');
        Exit(OpaqueUnsupportedStatement);
      end;
      Take(Children);
      VariableName := TList<TSyntaxElement>.Create;
      try
        Identifier(VariableName);
        Children.Add(Node(skIdentifierExpression, VariableName));
      finally VariableName.Free; end;
      if FReader.Matches('in') then
      begin
        Kind := skForInStatement;
        Take(Children);
        Children.Add(Expression);
      end
      else
      begin
        Kind := skForStatement;
        Expect(Children, ':=');
        Children.Add(Expression);
        if FReader.Matches('downto') then Take(Children)
        else Expect(Children, 'to');
        Children.Add(Expression);
      end;
      Expect(Children, 'do');
      StatementBody(Children);
    end
    else if FReader.Matches('while') then
    begin
      Kind := skWhileStatement;
      Take(Children);
      Children.Add(Expression);
      Expect(Children, 'do');
      StatementBody(Children);
    end
    else if FReader.Matches('repeat') then
    begin
      Kind := skRepeatStatement;
      Take(Children);
      Children.Add(StatementList(['until']));
      Expect(Children, 'until');
      Children.Add(Expression);
    end
    else
    begin
      Kind := skRaiseStatement;
      Take(Children);
      if not Boundary then Children.Add(Expression);
      if not Boundary then
      begin
        Report('PAR003', 'Extended raise preserved as opaque');
        Children.Add(OpaqueStatement);
        Kind := skOpaqueRegion;
      end;
    end;
    Result := Node(Kind, Children);
  finally Children.Free; end;
end;

function TDelphiParser.CaseLabel: TSyntaxNode;
var
  Children: TList<TSyntaxElement>;
  Kind: TSyntaxKind;
begin
  Children := TList<TSyntaxElement>.Create;
  try
    Kind := skLiteralExpression;
    if FReader.Matches('+') or FReader.Matches('-') then
    begin
      Take(Children);
      if FReader.Matches('+') or FReader.Matches('-') then
        Missing(Children, 'case label')
      else Children.Add(CaseLabel);
      Kind := skUnaryExpression;
    end
    else if FReader.PeekSignificant.Kind = tkIdentifier then
    begin
      Kind := skIdentifierExpression;
      Take(Children);
      while FReader.Matches('.') do
      begin
        Take(Children);
        Identifier(Children);
      end;
    end
    else if FReader.PeekSignificant.Kind in [tkNumber, tkStringLiteral, tkCharCode] then
      Take(Children)
    else Missing(Children, 'case label');
    Result := Node(Kind, Children);
  finally Children.Free; end;
end;

function TDelphiParser.CaseStatement: TSyntaxNode;
var
  Children, Branch, Fragment: TList<TSyntaxElement>;
  Before, Delimiters: Integer;
begin
  Children := TList<TSyntaxElement>.Create;
  try
    Take(Children);
    Children.Add(Expression);
    Expect(Children, 'of');
    while not ListEnd(['else', 'end']) do
    begin
      Before := FReader.Position;
      Branch := TList<TSyntaxElement>.Create;
      try
        repeat
          Branch.Add(CaseLabel);
          if FReader.Matches('..') then
          begin
            Take(Branch);
            Branch.Add(CaseLabel);
          end;
          if not FReader.Matches(',') then Break;
          Take(Branch);
        until HardStatementEnd;
        if not FReader.Matches(':') and not Boundary and
          (FReader.PeekSignificant.Kind <> tkIdentifier) then
        begin
          Report('PAR003', 'Complex case label preserved as opaque');
          Fragment := TList<TSyntaxElement>.Create;
          try
            Delimiters := 0;
            while not HardStatementEnd and not FReader.Matches(';') and
              not ListEnd(['else', 'end']) do
            begin
              if (Delimiters = 0) and (FReader.Matches(':') or
                FReader.Matches(',')) then Break;
              if FReader.Matches('(') or FReader.Matches('[') then
                Inc(Delimiters)
              else if FReader.Matches(')') or FReader.Matches(']') then
              begin
                if Delimiters = 0 then Break;
                Dec(Delimiters);
              end;
              Take(Fragment);
            end;
            Branch.Add(Node(skOpaqueRegion, Fragment));
          finally Fragment.Free; end;
        end;
        Expect(Branch, ':');
        StatementBody(Branch);
        Children.Add(Node(skCaseBranch, Branch));
      finally Branch.Free; end;
      if FReader.Matches(';') then Take(Children)
      else if not ListEnd(['else', 'end']) then Missing(Children, ';');
      if Before = FReader.Position then Break;
    end;
    if FReader.Matches('else') then
    begin
      Take(Children);
      Children.Add(StatementList(['end']));
    end;
    if HardStatementEnd then Missing(Children, 'end')
    else Expect(Children, 'end');
    Result := Node(skCaseStatement, Children);
  finally Children.Free; end;
end;

function TDelphiParser.ExceptionHandler: TSyntaxNode;
var
  Children, Fragment: TList<TSyntaxElement>;
begin
  Children := TList<TSyntaxElement>.Create;
  try
    Take(Children); // on
    if FReader.Matches(':', 1) then
    begin
      Identifier(Children);
      Take(Children);
    end
    else if (FReader.PeekSignificant.Kind = tkIdentifier) and
      (FReader.PeekSignificant(1).Kind = tkIdentifier) and
      not FReader.Matches('do', 1) then
    begin
      Identifier(Children);
      Missing(Children, ':');
    end;
    Children.Add(TypeReference);
    if not FReader.Matches('do') and not Boundary and
      (FReader.PeekSignificant.Kind <> tkIdentifier) and
      not FReader.Matches('begin') then
    begin
      Report('PAR003', 'Unsupported exception handler header preserved as opaque');
      Fragment := TList<TSyntaxElement>.Create;
      try
        while not Boundary and not HardStatementEnd do Take(Fragment);
        Children.Add(Node(skOpaqueRegion, Fragment));
      finally Fragment.Free; end;
    end;
    Expect(Children, 'do');
    StatementBody(Children);
    Result := Node(skExceptionHandler, Children);
  finally Children.Free; end;
end;

function TDelphiParser.TryStatement: TSyntaxNode;
var
  Children: TList<TSyntaxElement>;
  Kind: TSyntaxKind;
begin
  Children := TList<TSyntaxElement>.Create;
  try
    Take(Children);
    Children.Add(StatementList(['finally', 'except']));
    Kind := skTryFinallyStatement;
    if FReader.Matches('finally') then
    begin
      Take(Children);
      Children.Add(StatementList(['end']));
    end
    else if FReader.Matches('except') then
    begin
      Kind := skTryExceptStatement;
      Take(Children);
      if FReader.Matches('on') then
      begin
        while FReader.Matches('on') do
        begin
          Children.Add(ExceptionHandler);
          if FReader.Matches(';') then Take(Children)
          else if FReader.Matches('on') then Missing(Children, ';');
        end;
        if FReader.Matches('else') then
        begin
          Take(Children);
          Children.Add(StatementList(['end']));
        end;
      end
      else Children.Add(StatementList(['end']));
    end
    else Missing(Children, 'finally or except');
    if HardStatementEnd then Missing(Children, 'end')
    else Expect(Children, 'end');
    Result := Node(Kind, Children);
  finally Children.Free; end;
end;

function TDelphiParser.UsesClause: TSyntaxNode;
var
  Children: TList<TSyntaxElement>;
begin
  Children := TList<TSyntaxElement>.Create;
  try
    Take(Children);
    while True do
    begin
      Identifier(Children);
      while FReader.Matches('.') do
      begin
        Take(Children);
        Identifier(Children);
      end;
      if FReader.Matches('in') then
      begin
        Take(Children);
        if FReader.PeekSignificant.Kind = tkStringLiteral then Take(Children)
        else Missing(Children, 'unit filename string');
      end;
      if not FReader.Matches(',') then Break;
      Take(Children); // loop always consumes comma before continuing
    end;
    Expect(Children, ';');
    Result := Node(skUsesClause, Children);
  finally
    Children.Free;
  end;
end;

function TDelphiParser.SectionEnd: Boolean;
begin
  Result := FReader.AtEOF or FReader.Matches('implementation') or
    FReader.Matches('initialization') or FReader.Matches('finalization') or
    (FReader.Matches('end') and (FReader.Matches('.', 1) or
      (FReader.PeekSignificant(1).Kind = tkEOF)));
end;

function TDelphiParser.DeclarationStart: Boolean;
begin
  Result := SectionEnd or FReader.Matches('const') or FReader.Matches('var') or
    FReader.Matches('type') or FReader.Matches('procedure') or
    FReader.Matches('function') or FReader.Matches('constructor') or
    FReader.Matches('destructor') or FReader.Matches('begin') or
    (FReader.PeekSignificant.Kind = tkCompilerDirective);
end;

function TDelphiParser.TypeReference: TSyntaxNode;
var C: TList<TSyntaxElement>;
begin
  C := TList<TSyntaxElement>.Create;
  try
    if FInMember and VisibilityStart then Missing(C, 'type identifier')
    else if FReader.Matches('string') then Take(C) else Identifier(C);
    while FReader.Matches('.') do
    begin
      Take(C);
      Identifier(C);
    end;
    Result := Node(skTypeReference, C);
  finally C.Free; end;
end;

function TDelphiParser.OpaqueDeclaration(StopAtSemicolon: Boolean): TSyntaxNode;
var C: TList<TSyntaxElement>; Depth, Parens: Integer;
  First, InType, CanSync: Boolean;
begin
  C := TList<TSyntaxElement>.Create;
  try
    Report('PAR003', 'Unsupported declaration preserved as opaque');
    Depth := 0;
    Parens := 0;
    First := True;
    InType := FReader.Matches('type');
    CanSync := False;
    while not FReader.AtEOF do
    begin
      if SectionEnd then Break;
      if StopAtSemicolon and (Depth = 0) and (Parens = 0) and
        FReader.Matches(';') then Break;
      if not First and (Depth = 0) and (Parens = 0) and
        DeclarationStart and (not InType or CanSync) then Break;
      if FReader.Matches('(') or FReader.Matches('[') then Inc(Parens)
      else if FReader.Matches(')') or FReader.Matches(']') then
      begin
        if Parens > 0 then Dec(Parens);
      end
      else if (Parens = 0) and (FReader.Matches('record') or
        FReader.Matches('object') or FReader.Matches('interface') or
        FReader.Matches('begin') or FReader.Matches('try') or
        (FReader.Matches('case') and not InType) or
        (FReader.Matches('class') and not FReader.Matches('of', 1) and
          not FReader.Matches(';', 1) and not FReader.Matches('procedure', 1) and
          not FReader.Matches('function', 1) and not FReader.Matches('var', 1) and
          not FReader.Matches('constructor', 1) and
          not FReader.Matches('destructor', 1) and
          not FReader.Matches('property', 1) and
          not FReader.Matches('operator', 1))) then Inc(Depth)
      else if (Parens = 0) and FReader.Matches('end') and (Depth > 0) then Dec(Depth);
      CanSync := FReader.Matches(';');
      Take(C);
      First := False;
    end;
    Result := Node(skOpaqueRegion, C);
  finally C.Free; end;
end;

function TDelphiParser.DeclarationSection(IsConst: Boolean): TSyntaxNode;
var C, D: TList<TSyntaxElement>; Before: Integer;
begin
  C := TList<TSyntaxElement>.Create;
  D := TList<TSyntaxElement>.Create;
  try
    Take(C);
    while not DeclarationStart do
    begin
      Before := FReader.Position;
      D.Clear;
      Identifier(D);
      if not IsConst then
        while FReader.Matches(',') do
        begin
          Take(D);
          Identifier(D);
        end;
      if not IsConst or FReader.Matches(':') then
      begin
        Expect(D, ':');
        D.Add(TypeReference);
      end;
      if IsConst then Expect(D, '=');
      if not IsConst and FReader.Matches('=') then
      begin
        Take(D);
        D.Add(Expression);
      end
      else if IsConst then D.Add(Expression);
      if not FReader.Matches(';') and not DeclarationStart and
        (FReader.PeekSignificant.Kind <> tkIdentifier) then
        D.Add(OpaqueDeclaration(True));
      Expect(D, ';');
      if IsConst then C.Add(Node(skConstDeclaration, D))
      else C.Add(Node(skVarDeclaration, D));
      if FReader.Position = Before then Break;
    end;
    if IsConst then Result := Node(skConstSection, C)
    else Result := Node(skVarSection, C);
  finally D.Free; C.Free; end;
end;

function TDelphiParser.Parameters: TSyntaxNode;
var C, D, O: TList<TSyntaxElement>; Before, Nest: Integer;
begin
  C := TList<TSyntaxElement>.Create;
  D := TList<TSyntaxElement>.Create;
  O := TList<TSyntaxElement>.Create;
  try
    Take(C);
    while not FReader.AtEOF and not FReader.Matches(')') and
      not SectionEnd and not FReader.Matches('begin') and
      not (FInMember and (FReader.Matches('end') or VisibilityStart)) do
    begin
      Before := FReader.Position;
      D.Clear;
      if FReader.Matches('const') or FReader.Matches('var') or
        FReader.Matches('out') then Take(D);
      Identifier(D);
      while FReader.Matches(',') do
      begin
        Take(D);
        Identifier(D);
      end;
      Expect(D, ':');
      D.Add(TypeReference);
      if FReader.Matches('=') then
      begin
        Take(D);
        D.Add(Expression);
      end;
      if not FReader.Matches(';') and not FReader.Matches(')') and
        not SectionEnd and not FReader.Matches('begin') and
        not (FInMember and (FReader.Matches('end') or VisibilityStart)) then
      begin
        Report('PAR003', 'Unsupported parameter suffix preserved as opaque');
        O.Clear;
        Nest := 0;
        while not FReader.AtEOF and not SectionEnd do
        begin
          if FInMember and (FReader.Matches('end') or VisibilityStart) then Break;
          if (Nest = 0) and (FReader.Matches(';') or FReader.Matches(')') or
            FReader.Matches('begin')) then Break;
          if FReader.Matches('(') or FReader.Matches('[') then Inc(Nest)
          else if FReader.Matches(')') or FReader.Matches(']') then
          begin
            if Nest > 0 then Dec(Nest);
          end;
          Take(O);
        end;
        D.Add(Node(skOpaqueRegion, O));
      end;
      C.Add(Node(skParameterDeclaration, D));
      if not FReader.Matches(';') then Break;
      // Leave a header semicolon after a missing closer to Routine.
      if (FReader.PeekSignificant(1).Kind <> tkIdentifier) and
        not FReader.Matches('const', 1) and not FReader.Matches('var', 1) and
        not FReader.Matches('out', 1) then Break;
      Take(C);
      if FReader.Position = Before then Break;
    end;
    Expect(C, ')');
    Result := Node(skParameterList, C);
  finally O.Free; D.Free; C.Free; end;
end;

function TDelphiParser.RoutineHeader: TSyntaxNode;
var H, R: TList<TSyntaxElement>; IsFunction: Boolean;
begin
  H := TList<TSyntaxElement>.Create;
  R := TList<TSyntaxElement>.Create;
  try
    IsFunction := FReader.Matches('function');
    Take(H);
    Identifier(H);
    while FReader.Matches('.') do
    begin
      Take(H);
      Identifier(H);
    end;
    if FReader.Matches('(') then H.Add(Parameters);
    if IsFunction then
    begin
      Expect(R, ':');
      R.Add(TypeReference);
      H.Add(Node(skReturnType, R));
    end;
    if not FReader.Matches(';') and not DeclarationStart and
      not (FInMember and MemberBoundary) then
      if FInMember then H.Add(OpaqueTypeFragment(True, False, False))
      else H.Add(OpaqueDeclaration(True));
    Expect(H, ';');
    Result := Node(skRoutineHeader, H);
  finally R.Free; H.Free; end;
end;

function TDelphiParser.Routine(IsInterface: Boolean): TSyntaxNode;
var C: TList<TSyntaxElement>; SavedBody: Boolean;
begin
  C := TList<TSyntaxElement>.Create;
  try
    C.Add(RoutineHeader);
    if not IsInterface then
    begin
      if FReader.Matches('forward') or FReader.Matches('external') then
        C.Add(OpaqueDeclaration)
      else
      begin
        while FReader.Matches('const') or FReader.Matches('var') or
          FReader.Matches('type') do
          if FReader.Matches('type') then C.Add(OpaqueDeclaration)
          else C.Add(DeclarationSection(FReader.Matches('const')));
        if FReader.Matches('begin') then
        begin
          SavedBody := FRoutineBody;
          FRoutineBody := True;
          try C.Add(Block);
          finally FRoutineBody := SavedBody; end;
          Expect(C, ';');
        end
        else
        begin
          Missing(C, 'begin');
          if not DeclarationStart then C.Add(OpaqueDeclaration);
          Missing(C, 'end');
          if FReader.Matches(';') then Take(C);
        end;
      end;
    end;
    Result := Node(skRoutineDeclaration, C);
  finally C.Free; end;
end;

function TDelphiParser.VisibilityStart: Boolean;
begin
  Result := FReader.Matches('private') or FReader.Matches('protected') or
    FReader.Matches('public') or FReader.Matches('published') or
    FReader.Matches('automated') or (FReader.Matches('strict') and
      (FReader.Matches('private', 1) or FReader.Matches('protected', 1)));
end;

function TDelphiParser.MethodStart: Boolean;
begin
  Result := FReader.Matches('procedure') or FReader.Matches('function') or
    FReader.Matches('constructor') or FReader.Matches('destructor');
end;

function TDelphiParser.MemberBoundary: Boolean;
begin
  Result := SectionEnd or FReader.Matches('end') or VisibilityStart or
    MethodStart or FReader.Matches('property') or FReader.Matches('class') or
    FReader.Matches('type') or FReader.Matches('case') or
    ((FReader.PeekSignificant.Kind = tkIdentifier) and FReader.Matches('=', 1));
end;

function TDelphiParser.FieldStart: Boolean;
var I: Integer; Token: TDelphiToken;
begin
  Result := False;
  I := SkipRawTrivia(FReader.Position);
  if FLex.GetToken(I).Kind <> tkIdentifier then Exit;
  while True do
  begin
    I := SkipRawTrivia(I + 1);
    Token := FLex.GetToken(I);
    if (Token.Kind <> tkSymbol) or (Token.Span.Length <> 1) then Exit;
    case FLex.Source[Token.Span.StartOffset + 1] of
      ':': Exit(True);
      ',':
        begin
          I := SkipRawTrivia(I + 1);
          if FLex.GetToken(I).Kind <> tkIdentifier then Exit;
        end;
    else Exit;
    end;
  end;
end;

function TDelphiParser.SkipRawTrivia(Index: Integer): Integer;
begin
  // Local raw cursor only; EOF is the sentinel and directives stay significant.
  Result := Index;
  if Result >= FLex.TokenCount then Exit(FLex.TokenCount - 1);
  while (Result < FLex.TokenCount - 1) and
    TTokenReader.IsTrivia(FLex.GetToken(Result).Kind) do Inc(Result);
end;

function TDelphiParser.MethodDirective: Boolean;
begin
  // Deliberately finite: arbitrary contextual identifiers can be field names.
  Result := FReader.Matches('virtual') or FReader.Matches('dynamic') or
    FReader.Matches('override') or FReader.Matches('overload') or
    FReader.Matches('reintroduce') or FReader.Matches('abstract') or
    FReader.Matches('final') or FReader.Matches('static') or
    FReader.Matches('inline') or FReader.Matches('stdcall') or
    FReader.Matches('cdecl') or FReader.Matches('safecall') or
    FReader.Matches('register') or FReader.Matches('pascal') or
    FReader.Matches('message') or FReader.Matches('dispid') or
    FReader.Matches('deprecated') or FReader.Matches('platform') or
    FReader.Matches('experimental');
  Result := Result and not FieldStart;
end;

function TDelphiParser.OpaqueTypeFragment(IsMember, ToBodyEnd,
  IncludeSemicolon: Boolean): TSyntaxNode;
var C: TList<TSyntaxElement>; Blocks, Parens, Angles: Integer;
  First, IsProperty, IsClassMember, WasOf: Boolean;
begin
  C := TList<TSyntaxElement>.Create;
  try
    Report('PAR003', 'Unsupported type/member preserved as opaque');
    Blocks := 0;
    Parens := 0;
    Angles := 0;
    First := True;
    WasOf := False;
    IsProperty := IsMember and (FReader.Matches('property') or
      (FReader.Matches('class') and FReader.Matches('property', 1)));
    IsClassMember := IsMember and FReader.Matches('class');
    while not FReader.AtEOF do
    begin
      if SectionEnd then Break;
      if (Blocks = 0) and FReader.Matches('end') then Break;
      if not First and (Blocks = 0) and (Parens = 0) and (Angles = 0) then
      begin
        if not ToBodyEnd and FReader.Matches(';') then
        begin
          if IncludeSemicolon then Take(C);
          // The default-property marker follows the property's first ';'.
          if IsProperty and IncludeSemicolon and
            (FReader.Matches('default') or FReader.Matches('nodefault')) and
            FReader.Matches(';', 1) then
          begin Take(C); Take(C); end;
          Break;
        end;
        if not ToBodyEnd and IsMember and not IsClassMember and
          not IsProperty and (MemberBoundary or FieldStart) then Break;
        if not IsMember and
          ((FReader.PeekSignificant.Kind = tkIdentifier) and
            FReader.Matches('=', 1)) then Break;
        if not IsMember and (FReader.Matches('type') or
          FReader.Matches('const') or FReader.Matches('var')) then Break;
      end;
      if FReader.Matches('(') or FReader.Matches('[') or
        FReader.Matches('(.') then Inc(Parens)
      else if FReader.Matches(')') or FReader.Matches(']') or
        FReader.Matches('.)') then
      begin
        if Parens > 0 then Dec(Parens);
      end
      else if FReader.Matches('<') then Inc(Angles)
      else if FReader.Matches('>') or FReader.Matches('>=') then
      begin
        if Angles > 0 then Dec(Angles);
      end
      else if (Angles = 0) and (FReader.Matches('record') or
        (FReader.Matches('object') and not WasOf) or FReader.Matches('interface') or
        FReader.Matches('begin') or FReader.Matches('try') or
        (FReader.Matches('class') and not FReader.Matches('of', 1) and
          not FReader.Matches(';', 1) and not FReader.Matches('procedure', 1) and
          not FReader.Matches('function', 1) and not FReader.Matches('var', 1) and
          not FReader.Matches('constructor', 1) and
          not FReader.Matches('destructor', 1) and
          not FReader.Matches('property', 1) and
          not FReader.Matches('operator', 1))) then Inc(Blocks)
      else if FReader.Matches('end') and (Blocks > 0) then
        Dec(Blocks);
      WasOf := FReader.Matches('of');
      Take(C);
      First := False;
    end;
    Result := Node(skOpaqueRegion, C);
  finally C.Free; end;
end;

function TDelphiParser.TypeSection: TSyntaxNode;
var C: TList<TSyntaxElement>; Before: Integer;
begin
  C := TList<TSyntaxElement>.Create;
  try
    Take(C);
    while not DeclarationStart and not FReader.Matches('end') do
    begin
      Before := FReader.Position;
      C.Add(TypeDeclaration);
      if Before = FReader.Position then Break;
    end;
    Result := Node(skTypeSection, C);
  finally C.Free; end;
end;

function TDelphiParser.TypeDeclaration: TSyntaxNode;
var C: TList<TSyntaxElement>; I: Integer; Supported: Boolean;
  Token: TDelphiToken;
begin
  C := TList<TSyntaxElement>.Create;
  try
    if (FReader.PeekSignificant.Kind <> tkIdentifier) or
      not FReader.Matches('=', 1) then
      C.Add(OpaqueTypeFragment(False))
    else
    begin
      Identifier(C);
      Take(C); // equals
      Supported := (FReader.Matches('class') and not FReader.Matches(';', 1) and
        not FReader.Matches('of', 1) and not FReader.Matches('helper', 1) and
        not FReader.Matches('abstract', 1) and not FReader.Matches('sealed', 1)) or
        (FReader.Matches('record') and not FReader.Matches('helper', 1));
      if Supported and FReader.Matches('(', 1) then
      begin
        I := FReader.SignificantIndex(2);
        while I < FLex.TokenCount do
        begin
          Token := FLex.GetToken(I);
          if Token.Kind = tkEOF then Break;
          if (Token.Kind = tkSymbol) and (Token.Span.Length = 1) then
            case FLex.Source[Token.Span.StartOffset + 1] of
              ')', ';': Break;
              '<': begin Supported := False; Break; end;
            end;
          if (Token.Kind in [tkIdentifier, tkReservedWord]) and
            (Token.Span.Length = 3) and SameText(FLex.TokenText(I), 'end') then
            Break;
          I := SkipRawTrivia(I + 1);
        end;
      end;
      if Supported then
      begin
        C.Add(AggregateDeclaration(FReader.Matches('class')));
        Expect(C, ';');
      end
      else C.Add(OpaqueTypeFragment(False));
    end;
    Result := Node(skTypeDeclaration, C);
  finally C.Free; end;
end;

function TDelphiParser.AncestorList: TSyntaxNode;
var C: TList<TSyntaxElement>;
begin
  C := TList<TSyntaxElement>.Create;
  try
    Take(C);
    while True do
    begin
      C.Add(TypeReference);
      if not FReader.Matches(',') then Break;
      Take(C);
    end;
    Expect(C, ')');
    Result := Node(skAncestorList, C);
  finally C.Free; end;
end;

function TDelphiParser.AggregateDeclaration(IsClass: Boolean): TSyntaxNode;
var C, V: TList<TSyntaxElement>; Before: Integer; Saved: Boolean;
  procedure AddMember(E: TSyntaxElement);
  begin
    if V.Count > 0 then V.Add(E) else C.Add(E);
  end;
begin
  C := TList<TSyntaxElement>.Create;
  V := TList<TSyntaxElement>.Create;
  Saved := FInMember;
  FInMember := True;
  try
    Take(C);
    if IsClass and FReader.Matches('(') then C.Add(AncestorList);
    while not SectionEnd and not FReader.Matches('end') do
    begin
      // A new unit section/type declaration is a safe missing-end boundary.
      if FReader.Matches('type') or FReader.Matches('const') or
        FReader.Matches('var') or ((FReader.PeekSignificant.Kind = tkIdentifier)
        and FReader.Matches('=', 1)) then
      begin
        if FReader.Matches('type') then AddMember(OpaqueTypeFragment(True, True));
        Break;
      end;
      Before := FReader.Position;
      if VisibilityStart then
      begin
        if V.Count > 0 then C.Add(Node(skVisibilitySection, V));
        V.Clear;
        if FReader.Matches('strict') then Take(V);
        Take(V);
      end
      else if FReader.Matches('property') then
      begin
        if FReader.Matches(':', 2) and
          (FReader.Matches('class', 3) or FReader.Matches('record', 3) or
           FReader.Matches('procedure', 3) or FReader.Matches('function', 3)) then
          AddMember(OpaqueTypeFragment(True))
        else AddMember(PropertyDeclaration);
      end
      else if MethodStart then AddMember(MethodDeclaration)
      else if FieldStart then AddMember(FieldDeclaration)
      else if FReader.Matches('case') then
      begin AddMember(OpaqueTypeFragment(True, True)); Break; end
      else AddMember(OpaqueTypeFragment(True));
      if FReader.Position = Before then Break;
    end;
    if V.Count > 0 then C.Add(Node(skVisibilitySection, V));
    if SectionEnd then Missing(C, 'end') else Expect(C, 'end');
    if IsClass then Result := Node(skClassDeclaration, C)
    else Result := Node(skRecordDeclaration, C);
  finally FInMember := Saved; V.Free; C.Free; end;
end;

function TDelphiParser.FieldDeclaration: TSyntaxNode;
var C: TList<TSyntaxElement>;
begin
  C := TList<TSyntaxElement>.Create;
  try
    Identifier(C);
    while FReader.Matches(',') do
    begin Take(C); Identifier(C); end;
    Expect(C, ':');
    if (FReader.PeekSignificant.Kind = tkIdentifier) or
      FReader.Matches('string') then C.Add(TypeReference)
    else if MemberBoundary or FReader.Matches(';') then C.Add(TypeReference)
    else C.Add(OpaqueTypeFragment(True, False, False));
    if not FReader.Matches(';') and not MemberBoundary and not FieldStart then
      C.Add(OpaqueTypeFragment(True, False, False));
    Expect(C, ';');
    Result := Node(skFieldDeclaration, C);
  finally C.Free; end;
end;

function TDelphiParser.MethodDeclaration: TSyntaxNode;
var C, D: TList<TSyntaxElement>;
begin
  C := TList<TSyntaxElement>.Create;
  D := TList<TSyntaxElement>.Create;
  try
    C.Add(RoutineHeader);
    while MethodDirective do
    begin
      Take(D);
      while not FReader.AtEOF and not MemberBoundary and not FieldStart and
        not FReader.Matches(';') do Take(D);
      Expect(D, ';');
    end;
    if D.Count > 0 then C.Add(Node(skOpaqueRegion, D));
    Result := Node(skMethodDeclaration, C);
  finally D.Free; C.Free; end;
end;

function TDelphiParser.PropertySpecifierStart: Boolean;
begin
  Result := FReader.Matches('read') or FReader.Matches('write') or
    FReader.Matches('stored') or FReader.Matches('default') or
    FReader.Matches('nodefault') or FReader.Matches('index') or
    FReader.Matches('implements');
end;

procedure TDelphiParser.PropertyName(Children: TList<TSyntaxElement>);
begin
  Identifier(Children);
  while FReader.Matches('.') do
  begin Take(Children); Identifier(Children); end;
end;

function TDelphiParser.PropertyFragment(InParameters: Boolean): TSyntaxNode;
var C: TList<TSyntaxElement>; Parens, Brackets, Angles: Integer;
  ProceduralType, AfterComma: Boolean;
begin
  C := TList<TSyntaxElement>.Create;
  try
    Report('PAR003', 'Unsupported property fragment preserved as opaque');
    Parens := 0; Brackets := 0; Angles := 0;
    ProceduralType := InParameters and MethodStart and FReader.Matches('(', 1);
    AfterComma := False;
    while not FReader.AtEOF do
    begin
      // A procedural parameter type can start here, but a later method is recovery.
      if MemberBoundary and not (ProceduralType and (C.Count = 0)) then Break;
      if (Parens = 0) and (Brackets = 0) and (Angles = 0) then
      begin
        if FReader.Matches(';') or PropertySpecifierStart then Break;
        // Do not rescan each suffix of a comma-separated opaque name list.
        if not AfterComma and FieldStart then Break;
        if InParameters and (FReader.Matches(']') or FReader.Matches(':')) then Break;
      end;
      if FReader.Matches('(') then Inc(Parens)
      else if FReader.Matches('[') or FReader.Matches('(.') then Inc(Brackets)
      else if FReader.Matches(')') and (Parens > 0) then Dec(Parens)
      else if (FReader.Matches(']') or FReader.Matches('.)')) and
        (Brackets > 0) then Dec(Brackets)
      else if FReader.Matches('<') then Inc(Angles)
      else if (FReader.Matches('>') or FReader.Matches('>=')) and
        (Angles > 0) then Dec(Angles);
      AfterComma := FReader.Matches(',');
      Take(C);
    end;
    Result := Node(skOpaqueRegion, C);
  finally C.Free; end;
end;

function TDelphiParser.PropertyType: TSyntaxNode;
var C: TList<TSyntaxElement>; I: Integer; Token: TDelphiToken;
begin
  if MethodStart and FReader.Matches('(', 1) then Exit(PropertyFragment(True));
  if PropertySpecifierStart or MemberBoundary or FReader.Matches(';') or
    FReader.Matches(']') then
  begin
    C := TList<TSyntaxElement>.Create;
    try Missing(C, 'type identifier'); Result := Node(skTypeReference, C);
    finally C.Free; end;
  end
  else if (FReader.PeekSignificant.Kind = tkIdentifier) or
    FReader.Matches('string') then
  begin
    // Monotone raw cursor; each qualified-name token and trivia gap is visited once.
    I := SkipRawTrivia(FReader.SignificantIndex + 1);
    Token := FLex.GetToken(I);
    while (Token.Kind = tkSymbol) and (Token.Span.Length = 1) and
      (FLex.Source[Token.Span.StartOffset + 1] = '.') do
    begin
      I := SkipRawTrivia(I + 1);
      if FLex.GetToken(I).Kind <> tkIdentifier then Break;
      I := SkipRawTrivia(I + 1);
      Token := FLex.GetToken(I);
    end;
    Token := FLex.GetToken(I);
    if (Token.Kind = tkSymbol) and (Token.Span.Length = 1) and
      (FLex.Source[Token.Span.StartOffset + 1] = '<') then
      Result := PropertyFragment(True)
    else Result := TypeReference;
  end
  else Result := PropertyFragment(True);
end;

function TDelphiParser.PropertyIndexParameters: TSyntaxNode;
var C, D: TList<TSyntaxElement>; Before: Integer;
begin
  C := TList<TSyntaxElement>.Create;
  D := TList<TSyntaxElement>.Create;
  try
    Take(C);
    while not FReader.AtEOF and not FReader.Matches(']') and
      not MemberBoundary and not FReader.Matches(':') do
    begin
      Before := FReader.Position;
      D.Clear;
      if FReader.Matches('const') then Take(D);
      Identifier(D);
      while FReader.Matches(',') do
      begin Take(D); Identifier(D); end;
      Expect(D, ':');
      D.Add(PropertyType);
      if not FReader.Matches(';') and not FReader.Matches(']') and
        not FReader.Matches(':') and not MemberBoundary and
        not PropertySpecifierStart then D.Add(PropertyFragment(True));
      C.Add(Node(skParameterDeclaration, D));
      if not FReader.Matches(';') then Break;
      if (FReader.PeekSignificant(1).Kind <> tkIdentifier) and
        not FReader.Matches('const', 1) then Break;
      Take(C);
      if Before = FReader.Position then Break;
    end;
    Expect(C, ']');
    Result := Node(skPropertyIndexParameters, C);
  finally D.Free; C.Free; end;
end;

function TDelphiParser.PropertySpecifier: TSyntaxNode;
var C, V, L: TList<TSyntaxElement>; NoValue, ConstantValue,
  InterfaceName, Signed: Boolean;
begin
  C := TList<TSyntaxElement>.Create;
  V := TList<TSyntaxElement>.Create;
  L := TList<TSyntaxElement>.Create;
  try
    NoValue := FReader.Matches('nodefault');
    ConstantValue := FReader.Matches('default') or FReader.Matches('index');
    InterfaceName := FReader.Matches('implements');
    Take(C);
    if not NoValue then
    begin
      if PropertySpecifierStart or MemberBoundary or FieldStart or
        FReader.Matches(';') then
        Missing(C, 'property specifier value')
      else if ConstantValue then
      begin
        Signed := FReader.Matches('+') or FReader.Matches('-');
        if Signed then Take(V);
        if FReader.PeekSignificant.Kind in [tkNumber, tkStringLiteral, tkCharCode] then
        begin Take(L); V.Add(Node(skLiteralExpression, L)); end
        else if not FieldStart and (FReader.PeekSignificant.Kind = tkIdentifier) then
        begin PropertyName(L); V.Add(Node(skIdentifierExpression, L)); end
        else if Signed then Missing(V, 'constant')
        else V.Add(PropertyFragment);
        if Signed then
        begin
          L.Clear; L.Add(Node(skUnaryExpression, V));
          V.Clear; V.Add(L.Last);
        end;
        if not PropertySpecifierStart and not MemberBoundary and not FieldStart and
          not FReader.Matches(';') and not FReader.AtEOF then
        begin
          V.Add(PropertyFragment);
          C.Add(Node(skOpaqueRegion, V));
        end
        else C.Add(V.Last);
      end
      else if InterfaceName then
      begin
        C.Add(PropertyType);
        while FReader.Matches(',') do
        begin Take(C); C.Add(PropertyType); end;
      end
      else if FReader.PeekSignificant.Kind = tkIdentifier then
      begin PropertyName(V); C.Add(Node(skIdentifierExpression, V)); end
      else C.Add(PropertyFragment);
    end;
    if not PropertySpecifierStart and not MemberBoundary and not FieldStart and
      not FReader.Matches(';') and not FReader.AtEOF then C.Add(PropertyFragment);
    Result := Node(skPropertySpecifier, C);
  finally L.Free; V.Free; C.Free; end;
end;

function TDelphiParser.PropertyDeclaration: TSyntaxNode;
var C, D: TList<TSyntaxElement>; HasParameters: Boolean; Before: Integer;
begin
  C := TList<TSyntaxElement>.Create;
  D := TList<TSyntaxElement>.Create;
  try
    Take(C);
    Identifier(C);
    HasParameters := FReader.Matches('[');
    if HasParameters then C.Add(PropertyIndexParameters);
    if FReader.Matches(':') then
    begin
      Take(C);
      if FieldStart then Missing(C, 'type identifier') else C.Add(PropertyType);
    end
    else if not PropertySpecifierStart and not MemberBoundary and
      not FieldStart and not FReader.Matches(';') and not FReader.AtEOF then
    begin Missing(C, ':'); C.Add(PropertyType); end;
    while not FReader.AtEOF and not MemberBoundary and not FReader.Matches(';') do
    begin
      Before := FReader.Position;
      if FieldStart then Break
      else if PropertySpecifierStart then C.Add(PropertySpecifier)
      else C.Add(PropertyFragment);
      if Before = FReader.Position then Break;
    end;
    Expect(C, ';');
    if HasParameters and FReader.Matches('default') and not FieldStart then
    begin
      Take(D); Expect(D, ';'); C.Add(Node(skPropertySpecifier, D));
    end;
    Result := Node(skPropertyDeclaration, C);
  finally D.Free; C.Free; end;
end;

function TDelphiParser.ClassifyDirective(Index: Integer): TDirectiveClass;
var S, Name: string; P, First, Last, Q: Integer;
begin
  Result := dcNone;
  if FLex.GetToken(Index).Kind <> tkCompilerDirective then Exit;
  Result := dcUnknown;
  S := FLex.TokenText(Index);
  Last := Length(S);
  if Copy(S, 1, 2) = '{$' then
  begin
    if (Last < 4) or (S[Last] <> '}') then Exit;
    P := 3; Dec(Last);
  end
  else if Copy(S, 1, 3) = '(*$' then
  begin
    if Copy(S, Last - 1, 2) <> '*)' then Exit;
    P := 4; Dec(Last, 2);
  end
  else Exit;
  while (P <= Last) and CharInSet(S[P], [' ', #9, #10, #13]) do Inc(P);
  First := P;
  while (P <= Last) and CharInSet(S[P], ['a'..'z', 'A'..'Z', '0'..'9', '_']) do Inc(P);
  Name := UpperCase(Copy(S, First, P - First));
  if Name = '' then Exit;
  if (P <= Last) and not CharInSet(S[P], [' ', #9, #10, #13, '+', '-']) then Exit;
  if (Length(Name) = 1) and (P <= Last) and CharInSet(S[P], ['+', '-']) then
  begin
    // A finite switch alphabet, including I/O and range checking, not files.
    Q := First;
    repeat
      if (Q + 1 > Last) or
        not CharInSet(UpCase(S[Q]), ['A'..'D', 'F'..'P', 'Q'..'Z']) or
        not CharInSet(S[Q + 1], ['+', '-']) then Exit;
      Inc(Q, 2);
      if Q > Last then Break;
      if S[Q] <> ',' then
      begin
        if CharInSet(S[Q], [' ', #9, #10, #13]) then Break;
        Exit;
      end;
      Inc(Q);
    until False;
    Result := dcSwitch;
    Exit;
  end;
  if (P <= Last) and CharInSet(S[P], ['+', '-']) then Exit;
  if (Name = 'IFDEF') or (Name = 'IFNDEF') or (Name = 'IF') or
    (Name = 'IFOPT') then Result := dcOpen
  else if Name = 'ELSEIF' then Result := dcBranch
  else if Name = 'ELSE' then Result := dcElse
  else if (Name = 'ENDIF') or (Name = 'IFEND') then Result := dcClose
  else if (Name = 'I') or (Name = 'INCLUDE') then Result := dcInclude
  else if (Name = 'R') or (Name = 'RESOURCE') then Result := dcResource
  else if (Name = 'DEFINE') or (Name = 'UNDEF') or (Name = 'WARN') or
    (Name = 'HINTS') or (Name = 'WARNINGS') or (Name = 'RANGECHECKS') or
    (Name = 'OVERFLOWCHECKS') or (Name = 'ASSERTIONS') or
    (Name = 'OPTIMIZATION') or (Name = 'INLINE') or (Name = 'ALIGN') or
    (Name = 'IOCHECKS') or (Name = 'LONGSTRINGS') or
    (Name = 'BOOLEVAL') or (Name = 'STACKFRAMES') or
    (Name = 'SCOPEDENUMS') then Result := dcSwitch;
end;

procedure TDelphiParser.IndexDirectives;
type
  TFrame = record
    Opener, LastBoundary, InterfaceState, ImplementationState: Integer;
    InterfaceOK, ImplementationOK, SeenElse: Boolean;
  end;
var
  Stack: TArray<TFrame>; Depth, I, J: Integer; K: TDirectiveClass;
  Errors: TList<TDiagnostic>; S: string;
  procedure Error(Index: Integer; const Message: string);
  begin
    Errors.Add(TDiagnostic.Create('PAR005', Message, dsError,
      FLex.GetToken(Index).Span));
  end;
  procedure Step(var State: Integer; InImplementation: Boolean);
  begin
    case State of
      0: if (FLex.GetToken(I).Kind = tkReservedWord) and (S = 'procedure') then
           State := 1 else State := -1;
      1: if FLex.GetToken(I).Kind = tkIdentifier then State := 2 else State := -1;
      2: if S = ';' then
           begin if InImplementation then State := 3 else State := 0; end
         else State := -1;
      3: if S = 'begin' then State := 4 else State := -1;
      4: if S = 'end' then State := 5 else State := -1;
      5: if S = ';' then State := 0 else State := -1;
    end;
  end;
begin
  SetLength(FDirectives, FLex.TokenCount);
  SetLength(FConditionalEnd, FLex.TokenCount);
  SetLength(FConditionalNext, FLex.TokenCount);
  SetLength(FConditionalSafe, FLex.TokenCount);
  SetLength(FConditionalSafeImplementation, FLex.TokenCount);
  SetLength(Stack, 32);
  Errors := TList<TDiagnostic>.Create;
  try
    Depth := 0;
    for I := 0 to FLex.TokenCount - 1 do
    begin
      FConditionalEnd[I] := -1;
      FConditionalNext[I] := -1;
      K := ClassifyDirective(I);
      FDirectives[I] := K;
      case K of
        dcOpen:
          begin
            if Depth = Length(Stack) then SetLength(Stack, Depth * 2);
            Stack[Depth].Opener := I;
            Stack[Depth].LastBoundary := I;
            Stack[Depth].InterfaceState := 0;
            Stack[Depth].ImplementationState := 0;
            Stack[Depth].InterfaceOK := True;
            Stack[Depth].ImplementationOK := True;
            Stack[Depth].SeenElse := False;
            Inc(Depth);
            if Depth = 33 then Error(I, 'Conditional nesting exceeds 32 levels');
          end;
        dcBranch, dcElse:
          if Depth = 0 then Error(I, 'Conditional branch without opener')
          else
          begin
            J := Depth - 1;
            FConditionalNext[Stack[J].LastBoundary] := I;
            Stack[J].LastBoundary := I;
            if Stack[J].SeenElse then Error(I, 'Conditional branch after ELSE');
            Stack[J].SeenElse := Stack[J].SeenElse or (K = dcElse);
            Stack[J].InterfaceOK := Stack[J].InterfaceOK and
              (Stack[J].InterfaceState = 0);
            Stack[J].ImplementationOK := Stack[J].ImplementationOK and
              (Stack[J].ImplementationState = 0);
            Stack[J].InterfaceState := 0;
            Stack[J].ImplementationState := 0;
          end;
        dcClose:
          if Depth = 0 then Error(I, 'Conditional closer without opener')
          else
          begin
            Dec(Depth); J := Stack[Depth].Opener;
            FConditionalNext[Stack[Depth].LastBoundary] := I;
            FConditionalEnd[J] := I;
            FConditionalSafe[J] := Stack[Depth].InterfaceOK and
              (Stack[Depth].InterfaceState = 0);
            FConditionalSafeImplementation[J] := Stack[Depth].ImplementationOK and
              (Stack[Depth].ImplementationState = 0);
            if Depth > 0 then
            begin
              Stack[Depth - 1].InterfaceOK := Stack[Depth - 1].InterfaceOK and
                FConditionalSafe[J] and (Stack[Depth - 1].InterfaceState = 0);
              Stack[Depth - 1].ImplementationOK := Stack[Depth - 1].ImplementationOK and
                FConditionalSafeImplementation[J] and
                (Stack[Depth - 1].ImplementationState = 0);
            end;
          end;
      else
        if Depth > 0 then
        begin
          J := Depth - 1;
          if K in [dcSwitch, dcResource] then
          begin
            Stack[J].InterfaceOK := Stack[J].InterfaceOK and (Stack[J].InterfaceState = 0);
            Stack[J].ImplementationOK := Stack[J].ImplementationOK and
              (Stack[J].ImplementationState = 0);
          end
          else if not TTokenReader.IsTrivia(FLex.GetToken(I).Kind) then
          begin
            S := LowerCase(FLex.TokenText(I));
            Step(Stack[J].InterfaceState, False);
            Step(Stack[J].ImplementationState, True);
          end;
        end;
      end;
    end;
    for I := 0 to Depth - 1 do Error(Stack[I].Opener, 'Missing conditional closer');
    FDirectiveErrors := Errors.ToArray;
  finally Errors.Free; end;
end;

function TDelphiParser.SafeConditional(Index: Integer; IsInterface: Boolean): Boolean;
begin
  if IsInterface then Result := FConditionalSafe[Index]
  else Result := FConditionalSafeImplementation[Index];
end;

function TDelphiParser.SectionDirective(IsInterface: Boolean): TSyntaxNode;
var C: TList<TSyntaxElement>; Index, Last: Integer; Protected: TSyntaxNode;
begin
  Result := nil;
  Index := FReader.SignificantIndex;
  if (FDirectives[Index] = dcResource) and not ResourceDirective(Index) then Exit;
  if FDirectives[Index] = dcOpen then
  begin
    if not SafeConditional(Index, IsInterface) then Exit;
    Last := FConditionalEnd[Index];
    if Last < Index then Exit;
  end
  else if FDirectives[Index] in [dcSwitch, dcResource] then Last := Index
  else Exit;
  C := TList<TSyntaxElement>.Create;
  try
    FAllowDirective := True;
    try
      repeat Take(C); until FReader.Position > Last;
    finally FAllowDirective := False; end;
    // Keep every branch opaque, including nested groups. No branch selection.
    if FDirectives[Index] = dcOpen then
    begin
      Protected := Node(skOpaqueRegion, C);
      C.Clear;
      C.Add(Protected);
      Result := Node(skConditionalDirectiveRegion, C);
    end
    else Result := Node(skDirective, C);
  finally C.Free; end;
end;

function TDelphiParser.ResourceDirective(Index: Integer): Boolean;
var S: string; I, P: Integer; Span: TSourceSpan;
begin
  Result := False;
  Span := FLex.GetToken(Index).Span;
  P := Span.StartOffset;
  while (P > 0) and not CharInSet(FLex.Source[P], [#10, #13]) do
  begin
    if not CharInSet(FLex.Source[P], [' ', #9]) then Exit;
    Dec(P);
  end;
  P := Span.EndOffset + 1;
  while (P <= Length(FLex.Source)) and
    not CharInSet(FLex.Source[P], [#10, #13]) do
  begin
    if not CharInSet(FLex.Source[P], [' ', #9]) then Exit;
    Inc(P);
  end;
  S := Trim(FLex.TokenText(Index));
  if Copy(S, 1, 2) = '{$' then
  begin
    if (Length(S) < 4) or (S[Length(S)] <> '}') then Exit;
    S := Copy(S, 3, Length(S) - 3);
  end
  else if Copy(S, 1, 3) = '(*$' then
  begin
    if Copy(S, Length(S) - 1, 2) <> '*)' then Exit;
    S := Copy(S, 4, Length(S) - 5);
  end
  else Exit;
  S := Trim(S);
  I := 1;
  while (I <= Length(S)) and CharInSet(S[I], ['A'..'Z', 'a'..'z']) do Inc(I);
  Result := (SameText(Copy(S, 1, I - 1), 'R') or
    SameText(Copy(S, 1, I - 1), 'RESOURCE')) and
    (I <= Length(S)) and CharInSet(S[I], [' ', #9]);
end;

procedure TDelphiParser.UnitSection(Children: TList<TSyntaxElement>;
  IsInterface: Boolean);
var C: TList<TSyntaxElement>; Before: Integer; Directive: TSyntaxNode;
  SafeBoundary: Boolean;
begin
  C := TList<TSyntaxElement>.Create;
  try
    SafeBoundary := True;
    while not SectionEnd do
    begin
      Before := FReader.Position;
      if FReader.Matches('uses') then Children.Add(UsesClause)
      else if FReader.Matches('const') or FReader.Matches('var') then
        Children.Add(DeclarationSection(FReader.Matches('const')))
      else if FReader.Matches('type') then Children.Add(TypeSection)
      else if MethodStart then Children.Add(Routine(IsInterface))
      else if FReader.PeekSignificant.Kind = tkCompilerDirective then
      begin
        if not SafeBoundary then FUnsafeDirective := True;
        Directive := SectionDirective(IsInterface);
        if Directive <> nil then Children.Add(Directive)
        else begin FUnsafeDirective := True; Children.Add(OpaqueDeclaration); end;
      end
      else
      begin
        SafeBoundary := False;
        Children.Add(OpaqueDeclaration);
      end;
      if FReader.Position = Before then
      begin
        C.Clear;
        Take(C);
        Children.Add(Node(skOpaqueRegion, C));
      end;
    end;
  finally C.Free; end;
end;

function TDelphiParser.UnitDeclaration: TSyntaxNode;
var
  Children: TList<TSyntaxElement>;
begin
  Children := TList<TSyntaxElement>.Create;
  try
    Expect(Children, 'unit');
    Identifier(Children);
    while FReader.Matches('.') do
    begin
      Take(Children);
      Identifier(Children);
    end;
    Expect(Children, ';');
    while FDirectives[FReader.SignificantIndex] = dcSwitch do
      Children.Add(SectionDirective(True));
    Expect(Children, 'interface');
    UnitSection(Children, True);
    Expect(Children, 'implementation');
    UnitSection(Children, False);
    Expect(Children, 'end');
    Expect(Children, '.');
    Result := Node(skUnitDeclaration, Children);
  finally
    Children.Free;
  end;
end;

function TDelphiParser.Execute(RootKind: TSyntaxKind): TSyntaxTree;
var
  Children, Tail: TList<TSyntaxElement>;
  Root: TSyntaxNode;
  I: Integer;
  HasDirective, ContainsDirective: Boolean;
  FailureIndex: Integer;
  FailureMessage: string;
begin
  Children := TList<TSyntaxElement>.Create;
  Tail := TList<TSyntaxElement>.Create;
  try
    IndexDirectives;
    HasDirective := Length(FDirectiveErrors) > 0;
    ContainsDirective := False;
    FailureIndex := -1;
    FailureMessage := 'Directive-bearing input preserved as opaque';
    for I := 0 to FLex.TokenCount - 1 do
      if FLex.GetToken(I).Kind = tkCompilerDirective then
      begin
        ContainsDirective := True;
        if (RootKind <> skCompilationUnit) or
          (FDirectives[I] in [dcUnknown, dcInclude]) then HasDirective := True;
        if (FDirectives[I] = dcInclude) and
          ((FailureIndex < 0) or (FDirectives[FailureIndex] <> dcInclude)) then
        begin
          FailureIndex := I;
          FailureMessage := 'Include directive requires unresolved source expansion';
        end
        else if (FDirectives[I] = dcUnknown) and (FailureIndex < 0) then
        begin
          FailureIndex := I;
          FailureMessage := 'Unknown compiler directive preserved as opaque';
        end;
      end;
    for I := 0 to High(FDirectiveErrors) do FDiagnostics.Add(FDirectiveErrors[I]);
    if HasDirective then
    begin
      if Length(FDirectiveErrors) > 0 then
        FailureMessage := 'Malformed conditional structure preserved as opaque';
      if FailureIndex >= 0 then
        FDiagnostics.Add(TDiagnostic.Create('PAR003', FailureMessage, dsWarning,
          FLex.GetToken(FailureIndex).Span))
      else Report('PAR003', FailureMessage);
    end
    else if RootKind = skExpressionRoot then Children.Add(Expression)
    else if RootKind = skStatementRoot then
    begin
      Children.Add(Statement);
      if FReader.Matches(';') then Take(Children);
    end
    else
    begin
      while FDirectives[FReader.SignificantIndex] = dcSwitch do
        Children.Add(SectionDirective(True));
      if FReader.Matches('unit') then Children.Add(UnitDeclaration)
      else
      begin
        FUnsafeDirective := Children.Count > 0;
        HasDirective := ContainsDirective;
        Report('PAR003', 'Unsupported compilation unit preserved as opaque');
      end;
    end;
    if FUnsafeDirective then
    begin
      // Any directive away from a proven section boundary is unsafe.
      // Discard construction state and preserve the complete input explicitly.
      Children.Clear;
      FArena.Clear;
      FReader.Free;
      FReader := TTokenReader.Create(FLex);
      FDiagnostics.Clear;
      for I := 0 to FLex.DiagnosticCount - 1 do
        FDiagnostics.Add(FLex.GetDiagnostic(I));
      for I := 0 to High(FDirectiveErrors) do FDiagnostics.Add(FDirectiveErrors[I]);
      if FUnsafeDirectiveIndex >= 0 then
        FDiagnostics.Add(TDiagnostic.Create('PAR003',
          'Directive outside a safe section boundary', dsWarning,
          FLex.GetToken(FUnsafeDirectiveIndex).Span))
      else Report('PAR003', 'Directive outside a safe section boundary');
      HasDirective := True;
    end;
    if not FReader.AtEOF then
    begin
      if not HasDirective then Report('PAR002', 'Unexpected trailing source');
      while not FReader.AtEOF do Take(Tail);
      Children.Add(Node(skOpaqueRegion, Tail));
    end;
    Take(Children); // remaining trivia plus exactly one original EOF
    Root := Node(RootKind, Children);
    Result := TSyntaxTree.Create(FLex.Source, Root, FArena.ToArray,
      FDiagnostics.ToArray);
    FArena.OwnsObjects := False;
    FArena.Clear;
  finally
    Tail.Free;
    Children.Free;
  end;
end;

class function TDelphiParser.Parse(ALex: TDelphiLexResult): TSyntaxTree;
var
  Parser: TDelphiParser;
begin
  Parser := TDelphiParser.Create(ALex);
  try Result := Parser.Execute(skCompilationUnit);
  finally Parser.Free; end;
end;

class function TDelphiParser.ParseExpression(ALex: TDelphiLexResult): TSyntaxTree;
var
  Parser: TDelphiParser;
begin
  Parser := TDelphiParser.Create(ALex);
  try Result := Parser.Execute(skExpressionRoot);
  finally Parser.Free; end;
end;

class function TDelphiParser.ParseStatement(ALex: TDelphiLexResult): TSyntaxTree;
var
  Parser: TDelphiParser;
begin
  Parser := TDelphiParser.Create(ALex);
  try Result := Parser.Execute(skStatementRoot);
  finally Parser.Free; end;
end;

end.
