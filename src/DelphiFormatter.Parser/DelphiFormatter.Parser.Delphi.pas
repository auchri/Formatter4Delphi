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
    function Node(Kind: TSyntaxKind; Children: TList<TSyntaxElement>): TSyntaxNode;
    procedure Take(Children: TList<TSyntaxElement>);
    procedure Report(const Code, Message: string);
    procedure Missing(Children: TList<TSyntaxElement>; const Expected: string);
    procedure Expect(Children: TList<TSyntaxElement>; const Text: string);
    procedure Identifier(Children: TList<TSyntaxElement>);
    function Boundary: Boolean;
    function Precedence: Integer;
    function AmbiguousGenericCall: Boolean;
    function Expression(MinPrecedence: Integer = 1): TSyntaxNode;
    function Primary: TSyntaxNode;
    function Statement: TSyntaxNode;
    function Block: TSyntaxNode;
    function IfStatement: TSyntaxNode;
    function UsesClause: TSyntaxNode;
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
  DelphiFormatter.Core.Spans;

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

function TDelphiParser.AmbiguousGenericCall: Boolean;
var
  I, Angles: Integer;
begin
  Result := False;
  if (FReader.PeekSignificant.Kind <> tkIdentifier) or
    not FReader.Matches('<', 1) then Exit;
  I := 1;
  Angles := 0;
  while FReader.PeekSignificant(I).Kind <> tkEOF do
  begin
    if FReader.Matches(';', I) or FReader.Matches('(', I) or
      FReader.Matches('then', I) or FReader.Matches('end', I) then Exit;
    if FReader.Matches('<', I) then Inc(Angles)
    else if FReader.Matches('>', I) then
    begin
      Dec(Angles);
      if Angles = 0 then Exit(FReader.Matches('(', I + 1));
    end;
    Inc(I); // bounded by the remaining original stream, ending at EOF
  end;
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
      FReader.Matches('nil') or FReader.Matches('true') or FReader.Matches('false') then
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
      if Boundary then Missing(Children, 'expression')
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
    Expect(Children, 'end');
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

procedure TDelphiParser.UnitSection(Children: TList<TSyntaxElement>;
  IsInterface: Boolean);
var
  Opaque: TList<TSyntaxElement>;
begin
  if FReader.Matches('uses') then Children.Add(UsesClause);
  Opaque := TList<TSyntaxElement>.Create;
  try
    while not FReader.AtEOF do
    begin
      if IsInterface and FReader.Matches('implementation') then Break;
      if FReader.Matches('end') and (FReader.Matches('.', 1) or
        (FReader.PeekSignificant(1).Kind = tkEOF)) then Break;
      Take(Opaque);
    end;
    if Opaque.Count > 0 then
    begin
      Report('PAR003', 'Unsupported unit section preserved as opaque');
      Children.Add(Node(skOpaqueRegion, Opaque));
    end;
  finally
    Opaque.Free;
  end;
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
      if FLex.GetToken(I).Kind = tkCompilerDirective then HasDirective := True;
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
