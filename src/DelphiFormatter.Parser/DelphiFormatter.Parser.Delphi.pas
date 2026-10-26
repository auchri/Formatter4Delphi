unit DelphiFormatter.Parser.Delphi;

interface

uses
  System.Generics.Collections, DelphiFormatter.Core.Diagnostics,
  DelphiFormatter.Lexer.Tokens, DelphiFormatter.Syntax.Kinds,
  DelphiFormatter.Syntax.Nodes, DelphiFormatter.Syntax.Tree,
  DelphiFormatter.Parser.Reader;

type
  TDelphiParser = class
  private
    FLex: TDelphiLexResult;
    FReader: TTokenReader;
    FArena: TObjectList<TSyntaxElement>;
    FDiagnostics: TList<TDiagnostic>;
    FDepth: Integer;
    FRoutineBody: Boolean;
    FAllowDirective, FUnsafeDirective: Boolean;
    FGenericCallOpeners: TArray<Boolean>;
    function Node(Kind: TSyntaxKind; Children: TList<TSyntaxElement>): TSyntaxNode;
    procedure Take(Children: TList<TSyntaxElement>);
    procedure Report(const Code, Message: string);
    procedure Missing(Children: TList<TSyntaxElement>; const Expected: string);
    procedure Expect(Children: TList<TSyntaxElement>; const Text: string);
    procedure Identifier(Children: TList<TSyntaxElement>);
    function Boundary: Boolean;
    function Precedence: Integer;
    function AmbiguousGenericCall: Boolean;
    procedure IndexGenericCallOpeners;
    function Expression(MinPrecedence: Integer = 1): TSyntaxNode;
    function Primary: TSyntaxNode;
    function Statement: TSyntaxNode;
    function Block: TSyntaxNode;
    function IfStatement: TSyntaxNode;
    function UsesClause: TSyntaxNode;
    function SectionEnd: Boolean;
    function DeclarationStart: Boolean;
    function TypeReference: TSyntaxNode;
    function DeclarationSection(IsConst: Boolean): TSyntaxNode;
    function Parameters: TSyntaxNode;
    function Routine(IsInterface: Boolean): TSyntaxNode;
    function OpaqueDeclaration(StopAtSemicolon: Boolean = False): TSyntaxNode;
    function ResourceDirective(Index: Integer): Boolean;
    function UnitDeclaration: TSyntaxNode;
    function OpaqueStatement(TrackAngles: Boolean = False): TSyntaxNode;
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
    not FAllowDirective then FUnsafeDirective := True;
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
    FUnsafeDirective := True;
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
    FReader.Matches(')') or FReader.Matches(',') or
    FReader.Matches('interface') or FReader.Matches('implementation');
  if FRoutineBody then
    Result := Result or FReader.Matches('procedure') or FReader.Matches('function');
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

function TDelphiParser.AmbiguousGenericCall: Boolean;
begin
  Result := False;
  if (FReader.PeekSignificant.Kind <> tkIdentifier) or
    not FReader.Matches('<', 1) then Exit;
  if Length(FGenericCallOpeners) = 0 then IndexGenericCallOpeners;
  Result := FGenericCallOpeners[FReader.SignificantIndex(1)];
end;

function TDelphiParser.Primary: TSyntaxNode;
var
  Children: TList<TSyntaxElement>;
  Kind: TSyntaxKind;
  Before: Integer;
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
    while FReader.Matches('(') do
    begin
      Children.Clear;
      Children.Add(Result);
      Take(Children);
      if not FReader.Matches(')') and not FReader.AtEOF then
        while True do
        begin
          Before := FReader.Position;
          Children.Add(Expression);
          if not FReader.Matches(',') then Break;
          Take(Children);
          if FReader.Position <= Before then Break;
        end;
      Expect(Children, ')');
      Result := Node(skCallExpression, Children);
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
      if (Nesting = 0) and Boundary then Break;
      if FReader.Matches('begin') or FReader.Matches('(') or
        FReader.Matches('[') or (TrackAngles and FReader.Matches('<')) then Inc(Nesting)
      else if FReader.Matches('end') or FReader.Matches(')') or
        FReader.Matches(']') or (TrackAngles and FReader.Matches('>')) then Dec(Nesting);
      Take(Children); // each continuing iteration consumes original tokens
    end;
    Result := Node(skOpaqueRegion, Children);
  finally
    Children.Free;
  end;
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
    Children := TList<TSyntaxElement>.Create;
    try
      if Boundary then
        Exit(Node(skEmptyStatement, Children));
      if FReader.PeekSignificant.Kind <> tkIdentifier then
      begin
        Report('PAR003', 'Unsupported statement preserved as opaque');
        Exit(OpaqueStatement);
      end;
      Left := Expression;
      Children.Add(Left);
      if FReader.Matches(':=') then
      begin
        Kind := skAssignmentStatement;
        if Left.Kind <> skIdentifierExpression then
        begin
          Kind := skError;
          Report('PAR002', 'Unsupported assignment target');
        end;
        Take(Children);
        Children.Add(Expression);
      end
      else if Left.Kind in [skIdentifierExpression, skCallExpression] then
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
      not FReader.Matches('implementation') do
    begin
      if FRoutineBody and (FReader.Matches('procedure') or
        FReader.Matches('function') or
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
    FReader.Matches('function') or FReader.Matches('begin') or
    (FReader.PeekSignificant.Kind = tkCompilerDirective);
end;

function TDelphiParser.TypeReference: TSyntaxNode;
var C: TList<TSyntaxElement>;
begin
  C := TList<TSyntaxElement>.Create;
  try
    if FReader.Matches('string') then Take(C) else Identifier(C);
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
      not SectionEnd and not FReader.Matches('begin') do
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
        not SectionEnd and not FReader.Matches('begin') then
      begin
        Report('PAR003', 'Unsupported parameter suffix preserved as opaque');
        O.Clear;
        Nest := 0;
        while not FReader.AtEOF and not SectionEnd do
        begin
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

function TDelphiParser.Routine(IsInterface: Boolean): TSyntaxNode;
var C, H, R: TList<TSyntaxElement>; IsFunction, SavedBody: Boolean;
begin
  C := TList<TSyntaxElement>.Create;
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
    if not FReader.Matches(';') and not DeclarationStart then
      H.Add(OpaqueDeclaration(True));
    Expect(H, ';');
    C.Add(Node(skRoutineHeader, H));
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
  finally R.Free; H.Free; C.Free; end;
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
var C: TList<TSyntaxElement>; Before: Integer;
begin
  C := TList<TSyntaxElement>.Create;
  try
    while not SectionEnd do
    begin
      Before := FReader.Position;
      if FReader.Matches('uses') then Children.Add(UsesClause)
      else if FReader.Matches('const') or FReader.Matches('var') then
        Children.Add(DeclarationSection(FReader.Matches('const')))
      else if FReader.Matches('procedure') or FReader.Matches('function') then
        Children.Add(Routine(IsInterface))
      else if (FReader.PeekSignificant.Kind = tkCompilerDirective) and
        ResourceDirective(FReader.SignificantIndex) then
      begin
        C.Clear;
        FAllowDirective := True;
        try Take(C);
        finally FAllowDirective := False; end;
        Children.Add(Node(skDirective, C));
      end
      else Children.Add(OpaqueDeclaration);
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
  HasDirective: Boolean;
begin
  Children := TList<TSyntaxElement>.Create;
  Tail := TList<TSyntaxElement>.Create;
  try
    HasDirective := False;
    for I := 0 to FLex.TokenCount - 1 do
      if (FLex.GetToken(I).Kind = tkCompilerDirective) and
        ((RootKind <> skCompilationUnit) or not ResourceDirective(I)) then
        HasDirective := True;
    if HasDirective then
      Report('PAR003', 'Directive-bearing input preserved as opaque')
    else if RootKind = skExpressionRoot then Children.Add(Expression)
    else if RootKind = skStatementRoot then
    begin
      Children.Add(Statement);
      if FReader.Matches(';') then Take(Children);
    end
    else if FReader.Matches('unit') then Children.Add(UnitDeclaration)
    else Report('PAR003', 'Unsupported compilation unit preserved as opaque');
    if FUnsafeDirective then
    begin
      // A resource directive away from a supported section boundary is unsafe.
      // Discard construction state and preserve the complete input explicitly.
      Children.Clear;
      FArena.Clear;
      FReader.Free;
      FReader := TTokenReader.Create(FLex);
      FDiagnostics.Clear;
      for I := 0 to FLex.DiagnosticCount - 1 do
        FDiagnostics.Add(FLex.GetDiagnostic(I));
      Report('PAR003', 'Directive outside a safe section boundary');
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
