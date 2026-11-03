unit DelphiFormatter.Formatting.Safety;

interface

uses
  System.Generics.Collections, DelphiFormatter.Core.Spans,
  DelphiFormatter.Core.Diagnostics, DelphiFormatter.Lexer.Tokens,
  DelphiFormatter.Syntax.Nodes, DelphiFormatter.Syntax.Tree;

const
  // The only rule S0 releases in the first slice.
  S0AssignmentSpacingRuleId = 'S0.AssignmentSpacing';

type
  TFormatRefusalReason = (frOpaque, frSyntaxError, frMissing,
    frDirectiveBoundary, frConditionalFragment, frUnresolvedInclude,
    frUnknownContext, frUnsupportedConstruct, frLexicalError,
    frUnsupportedWhitespace, frCommentAnchor, frEditConflict,
    frValidationFailure, frConfigPolicy, frResourceLimit);
  TFormatRefusalReasons = set of TFormatRefusalReason;

  TBoundaryPolicy = (bpClosedBothSides);

  // Reporting view of protected source. Slot decisions stay edit-authoritative.
  TProtectedRange = record
    Span: TSourceSpan;
    Reasons: TFormatRefusalReasons;
    BoundaryPolicy: TBoundaryPolicy;
    constructor Create(const ASpan: TSourceSpan; AReasons: TFormatRefusalReasons);
  end;

  // A slot is the gap between two adjacent anchor tokens (every original
  // token except whitespace/newline); identity is (SourceIdentity, Left,
  // Right) with Left = -1 for BOF. AllowWhitespace is True only when Reasons
  // is empty and the S0 preconditions were positively established.
  TSlotDecision = record
    SourceIdentity: string;
    LeftOriginalIndex: Integer;
    RightOriginalIndex: Integer;
    Span: TSourceSpan;
    AllowWhitespace: Boolean;
    Reasons: TFormatRefusalReasons;
  end;

  // The two horizontal slots of one structurally proven assignment.
  TAssignmentSlotSite = record
    OperatorIndex: Integer;
    OwnerOrdinal: Integer;
    Before: TSlotDecision;
    After: TSlotDecision;
  end;

  // Value-only S0 analysis; holds no reference to the borrowed lexer/tree.
  TS0Analysis = record
    Reasons: TFormatRefusalReasons;
    Diagnostics: TArray<TDiagnostic>;
    Sites: TArray<TAssignmentSlotSite>;
  end;

// SHA-256 over the UTF-16 code units, low byte then high byte, no BOM and no
// surrogate repair; 64 uppercase hex characters.
function ComputeSourceIdentity(const Source: string): string;

function IsAnchorKind(Kind: TTokenKind): Boolean;
// {$I name}/{$INCLUDE name} in either directive spelling; {$I+}/{$I-} are
// switches, not includes.
function IsIncludeDirective(const Text: string): Boolean;
// Neighbouring anchor indices; PreviousAnchor returns -1 for BOF.
function PreviousAnchor(Lex: TDelphiLexResult; Index: Integer): Integer;
function NextAnchor(Lex: TDelphiLexResult; Index: Integer): Integer;
function SlotSpan(Lex: TDelphiLexResult; LeftAnchor, RightAnchor: Integer): TSourceSpan;

// Unit-level routine declarations in source order; empty unless the root is
// exactly one unit declaration plus EOF.
function UnitRoutines(Tree: TSyntaxTree): TArray<TSyntaxNode>;

// Whole-file S0 preconditions. Appends one FMT diagnostic per failed
// condition in a fixed order and returns the refusal reasons.
function CheckS0Preconditions(Lex: TDelphiLexResult; Tree: TSyntaxTree;
  Diagnostics: TList<TDiagnostic>): TFormatRefusalReasons;

// Preconditions plus, when RequestAssignmentSlots is set, the slot decisions
// of every assignment inside a complete routine body. Sites are empty when
// the file is refused.
function AnalyzeS0(Lex: TDelphiLexResult; Tree: TSyntaxTree;
  const SourceIdentity: string; RequestAssignmentSlots: Boolean): TS0Analysis;

implementation

uses
  System.SysUtils, System.Hash, DelphiFormatter.Syntax.Kinds,
  DelphiFormatter.Syntax.Query;

constructor TProtectedRange.Create(const ASpan: TSourceSpan;
  AReasons: TFormatRefusalReasons);
begin
  Span := ASpan;
  Reasons := AReasons;
  BoundaryPolicy := bpClosedBothSides;
end;

function ComputeSourceIdentity(const Source: string): string;
const
  ChunkUnits = 32768;
var
  Hash: THashSHA2;
  Buffer: TBytes;
  Digest: TBytes;
  Start, Count, I: Integer;
  Unit16: Word;
begin
  Hash := THashSHA2.Create(THashSHA2.TSHA2Version.SHA256);
  SetLength(Buffer, ChunkUnits * 2);
  Start := 0;
  while Start < Length(Source) do
  begin
    Count := Length(Source) - Start;
    if Count > ChunkUnits then
      Count := ChunkUnits;
    // Explicit byte order instead of relying on the host memory layout.
    for I := 0 to Count - 1 do
    begin
      Unit16 := Ord(Source[Start + I + 1]);
      Buffer[2 * I] := Byte(Unit16 and $FF);
      Buffer[2 * I + 1] := Byte(Unit16 shr 8);
    end;
    Hash.Update(Buffer, Cardinal(Count * 2));
    Inc(Start, Count);
  end;
  Digest := Hash.HashAsBytes;
  Result := '';
  for I := 0 to High(Digest) do
    Result := Result + IntToHex(Digest[I], 2);
end;

function IsAnchorKind(Kind: TTokenKind): Boolean;
begin
  Result := not (Kind in [tkWhitespace, tkNewLine]);
end;

function IsIncludeDirective(const Text: string): Boolean;
var
  I, NameStart: Integer;
  Name: string;
begin
  Result := False;
  if Copy(Text, 1, 2) = '{$' then
    I := 3
  else if Copy(Text, 1, 3) = '(*$' then
    I := 4
  else
    Exit;
  NameStart := I;
  while (I <= Length(Text)) and CharInSet(Text[I], ['A'..'Z', 'a'..'z']) do
    Inc(I);
  Name := UpperCase(Copy(Text, NameStart, I - NameStart));
  if Name = 'INCLUDE' then
    Exit(True);
  Result := (Name = 'I') and (I <= Length(Text)) and
    not CharInSet(Text[I], ['+', '-', '}', '*']);
end;

function PreviousAnchor(Lex: TDelphiLexResult; Index: Integer): Integer;
begin
  Result := Index - 1;
  while (Result >= 0) and not IsAnchorKind(Lex.GetToken(Result).Kind) do
    Dec(Result);
end;

function NextAnchor(Lex: TDelphiLexResult; Index: Integer): Integer;
begin
  // The final EOF is an anchor, so this always stops inside the stream.
  Result := Index + 1;
  while not IsAnchorKind(Lex.GetToken(Result).Kind) do
    Inc(Result);
end;

function SlotSpan(Lex: TDelphiLexResult; LeftAnchor, RightAnchor: Integer): TSourceSpan;
var
  Start: Integer;
begin
  Start := 0;
  if LeftAnchor >= 0 then
    Start := Lex.GetToken(LeftAnchor).Span.EndOffset;
  Result := TSourceSpan.Create(Start, Lex.GetToken(RightAnchor).Span.StartOffset - Start);
end;

function SignificantParts(Node: TSyntaxNode; out Parts: TArray<TSyntaxElement>): Integer;
var
  I: Integer;
begin
  Parts := nil;
  for I := 0 to Node.ChildCount - 1 do
    if not IsTriviaLeaf(Node.GetChild(I)) then
      Parts := Parts + [Node.GetChild(I)];
  Result := Length(Parts);
end;

function UnitDeclaration(Tree: TSyntaxTree): TSyntaxNode;
var
  Parts: TArray<TSyntaxElement>;
begin
  Result := nil;
  if (Tree.Root.Kind = skCompilationUnit) and (SignificantParts(Tree.Root, Parts) = 2) and
    (Parts[0].Kind = skUnitDeclaration) and (Parts[1] is TSyntaxToken) and
    not TSyntaxToken(Parts[1]).IsMissing and
    (TSyntaxToken(Parts[1]).OriginalToken.Kind = tkEOF) then
    Result := TSyntaxNode(Parts[0]);
end;

function UnitRoutines(Tree: TSyntaxTree): TArray<TSyntaxNode>;
var
  UnitNode: TSyntaxNode;
  I: Integer;
begin
  if Tree = nil then
    raise EArgumentNilException.Create('Tree');
  Result := nil;
  UnitNode := UnitDeclaration(Tree);
  if UnitNode = nil then
    Exit;
  for I := 0 to UnitNode.ChildCount - 1 do
    if UnitNode.GetChild(I).Kind = skRoutineDeclaration then
      Result := Result + [TSyntaxNode(UnitNode.GetChild(I))];
end;

function ParserReason(const Code: string): TFormatRefusalReasons;
begin
  if Code = 'PAR001' then Result := [frMissing]
  else if Code = 'PAR003' then Result := [frUnsupportedConstruct]
  else if Code = 'PAR004' then Result := [frResourceLimit]
  else Result := [frSyntaxError];
end;

function CheckS0Preconditions(Lex: TDelphiLexResult; Tree: TSyntaxTree;
  Diagnostics: TList<TDiagnostic>): TFormatRefusalReasons;
var
  I: Integer;
  FirstDirective, FirstInclude: Integer;
  ParserReasons: TFormatRefusalReasons;
  Stack: TStack<TSyntaxElement>;
  Element: TSyntaxElement;
  Node: TSyntaxNode;
  FirstOf: array[TSyntaxKind] of TSyntaxElement;

  procedure Refuse(Reason: TFormatRefusalReasons; const Code, Message: string;
    const Span: TSourceSpan);
  begin
    Result := Result + Reason;
    Diagnostics.Add(TDiagnostic.Create(Code, Message, dsWarning, Span));
  end;

begin
  if (Lex = nil) or (Tree = nil) or (Diagnostics = nil) then
    raise EArgumentNilException.Create('Lexer result, tree and diagnostics are required');
  if Lex.Source <> Tree.Source then
    raise EArgumentException.Create('Tree does not belong to the lexer result');
  Result := [];

  if Lex.DiagnosticCount > 0 then
    Refuse([frLexicalError], 'FMT001', 'Formatting refused: lexical diagnostics',
      Lex.GetDiagnostic(0).Span);

  FirstDirective := -1;
  FirstInclude := -1;
  for I := 0 to Lex.TokenCount - 1 do
    if Lex.GetToken(I).Kind = tkCompilerDirective then
    begin
      if FirstDirective < 0 then FirstDirective := I;
      if (FirstInclude < 0) and IsIncludeDirective(Lex.TokenText(I)) then
        FirstInclude := I;
    end;
  if FirstDirective >= 0 then
    Refuse([frDirectiveBoundary], 'FMT002',
      'Formatting refused: compiler directives are protected in S0',
      Lex.GetToken(FirstDirective).Span);
  if FirstInclude >= 0 then
    Refuse([frUnresolvedInclude], 'FMT003',
      'Formatting refused: include directive is not resolved',
      Lex.GetToken(FirstInclude).Span);

  // Tree diagnostics start with the lexer diagnostics, then parser ones.
  if Tree.DiagnosticCount > Lex.DiagnosticCount then
  begin
    ParserReasons := [];
    for I := Lex.DiagnosticCount to Tree.DiagnosticCount - 1 do
      ParserReasons := ParserReasons + ParserReason(Tree.GetDiagnostic(I).Code);
    Refuse(ParserReasons, 'FMT004', 'Formatting refused: parser diagnostics',
      Tree.GetDiagnostic(Lex.DiagnosticCount).Span);
  end;

  FillChar(FirstOf, SizeOf(FirstOf), 0);
  Stack := TStack<TSyntaxElement>.Create;
  try
    Stack.Push(Tree.Root);
    while Stack.Count > 0 do
    begin
      Element := Stack.Pop;
      if (Element.Kind in [skOpaqueRegion, skError, skMissingToken]) and
        (FirstOf[Element.Kind] = nil) then
        FirstOf[Element.Kind] := Element;
      if Element is TSyntaxNode then
      begin
        Node := TSyntaxNode(Element);
        for I := Node.ChildCount - 1 downto 0 do
          Stack.Push(Node.GetChild(I));
      end;
    end;
  finally
    Stack.Free;
  end;
  if FirstOf[skOpaqueRegion] <> nil then
    Refuse([frOpaque], 'FMT005', 'Formatting refused: opaque syntax',
      FirstOf[skOpaqueRegion].Span);
  if FirstOf[skError] <> nil then
    Refuse([frSyntaxError], 'FMT006', 'Formatting refused: syntax error node',
      FirstOf[skError].Span);
  if FirstOf[skMissingToken] <> nil then
    Refuse([frMissing], 'FMT007', 'Formatting refused: missing token',
      FirstOf[skMissingToken].Span);
  if UnitDeclaration(Tree) = nil then
    Refuse([frUnknownContext], 'FMT008',
      'Formatting refused: source is not one complete unit',
      TSourceSpan.Create(0, Length(Lex.Source)));
end;

type
  TSlotSide = (ssBefore, ssAfter);

function IsCodeAnchor(Lex: TDelphiLexResult; Index: Integer; Side: TSlotSide): Boolean;
var
  Text: string;
begin
  Text := Lex.TokenText(Index);
  case Lex.GetToken(Index).Kind of
    tkIdentifier:
      Result := True;
    tkNumber:
      Result := Side = ssAfter;
    tkReservedWord:
      // Before: a member name after '.'; after: nil literal or not operator.
      Result := (Side = ssBefore) or SameText(Text, 'nil') or SameText(Text, 'not');
    tkSymbol:
      if Side = ssBefore then
        Result := (Text = ')') or (Text = ']') or (Text = '.)') or (Text = '^')
      else
        Result := (Text = '(') or (Text = '+') or (Text = '-') or (Text = '@');
  else
    Result := False;
  end;
end;

function AnalyzeS0(Lex: TDelphiLexResult; Tree: TSyntaxTree;
  const SourceIdentity: string; RequestAssignmentSlots: Boolean): TS0Analysis;
var
  Diagnostics: TList<TDiagnostic>;
  Sites: TList<TAssignmentSlotSite>;
  Routines: TArray<TSyntaxNode>;
  Stack: TStack<TSyntaxElement>;
  Element: TSyntaxElement;
  Node: TSyntaxNode;
  Routine: TRoutineRoles;
  Assignment: TAssignmentRoles;
  Site: TAssignmentSlotSite;
  I, Ordinal, InBodies, InTree: Integer;

  procedure Refuse(Reason: TFormatRefusalReasons; const Code, Message: string;
    const Span: TSourceSpan);
  begin
    Result.Reasons := Result.Reasons + Reason;
    Diagnostics.Add(TDiagnostic.Create(Code, Message, dsWarning, Span));
  end;

  procedure Note(const Code, Message: string; const Span: TSourceSpan);
  begin
    Diagnostics.Add(TDiagnostic.Create(Code, Message, dsInfo, Span));
  end;

  function Decide(Left, Right, Neighbor, RoleAnchor: Integer;
    Side: TSlotSide): TSlotDecision;
  var
    J, K: Integer;
    Text: string;
    HasEol, HasControl: Boolean;
  begin
    Result.SourceIdentity := SourceIdentity;
    Result.LeftOriginalIndex := Left;
    Result.RightOriginalIndex := Right;
    Result.Span := SlotSpan(Lex, Left, Right);
    Result.Reasons := [];
    if Neighbor < 0 then
      Result.Reasons := [frUnknownContext]
    else
      case Lex.GetToken(Neighbor).Kind of
        tkComment:
          begin
            Result.Reasons := [frCommentAnchor];
            Note('FMT101', 'Assignment slot preserved: comment anchor', Result.Span);
          end;
        tkStringLiteral, tkCharCode:
          begin
            Result.Reasons := [frUnsupportedConstruct];
            Note('FMT103', 'Assignment slot preserved: literal anchor', Result.Span);
          end;
        tkCompilerDirective:
          Result.Reasons := [frDirectiveBoundary];
        tkUnknown, tkEOF:
          Result.Reasons := [frUnknownContext];
      else
        if Neighbor <> RoleAnchor then
        begin
          Result.Reasons := [frUnknownContext];
          Refuse([frUnknownContext], 'FMT014',
            'Formatting refused: assignment slot cannot be attributed to its roles',
            Result.Span);
        end
        else if not IsCodeAnchor(Lex, Neighbor, Side) then
        begin
          Result.Reasons := [frUnsupportedConstruct];
          Note('FMT104', 'Assignment slot preserved: unsupported anchor token',
            Result.Span);
        end;
      end;
    HasEol := False;
    HasControl := False;
    for J := Left + 1 to Right - 1 do
      if Lex.GetToken(J).Kind = tkNewLine then
        HasEol := True
      else
      begin
        Text := Lex.TokenText(J);
        for K := 1 to Length(Text) do
          if (Text[K] <> ' ') and (Text[K] <> #9) then
            HasControl := True;
      end;
    if HasEol then
    begin
      Include(Result.Reasons, frUnsupportedWhitespace);
      Note('FMT102', 'Assignment slot preserved: line break', Result.Span);
    end;
    if HasControl then
    begin
      Include(Result.Reasons, frUnsupportedWhitespace);
      Refuse([frUnsupportedWhitespace], 'FMT010',
        'Formatting refused: unsupported whitespace control character in requested slot',
        Result.Span);
    end;
    Result.AllowWhitespace := Result.Reasons = [];
  end;

begin
  if SourceIdentity = '' then
    raise EArgumentException.Create('SourceIdentity is required');
  Result := Default(TS0Analysis);
  Diagnostics := TList<TDiagnostic>.Create;
  Sites := TList<TAssignmentSlotSite>.Create;
  Stack := TStack<TSyntaxElement>.Create;
  try
    Result.Reasons := CheckS0Preconditions(Lex, Tree, Diagnostics);
    if (Result.Reasons = []) and RequestAssignmentSlots then
    begin
      Routines := UnitRoutines(Tree);
      InBodies := 0;
      for Ordinal := 0 to High(Routines) do
      begin
        if not TryGetRoutineRoles(Tree, Routines[Ordinal], Routine) then
          Continue;
        Stack.Push(Routine.Body);
        while Stack.Count > 0 do
        begin
          Element := Stack.Pop;
          if not (Element is TSyntaxNode) then
            Continue;
          Node := TSyntaxNode(Element);
          if Node.Kind = skAssignmentStatement then
          begin
            Inc(InBodies);
            if not TryGetAssignmentRoles(Tree, Node, Assignment) then
            begin
              Refuse([frUnsupportedConstruct], 'FMT009',
                'Formatting refused: assignment roles not recognized', Node.Span);
              Continue;
            end;
            Site.OwnerOrdinal := Ordinal;
            Site.OperatorIndex := Assignment.OperatorToken.OriginalIndex;
            Site.Before := Decide(PreviousAnchor(Lex, Site.OperatorIndex),
              Site.OperatorIndex, PreviousAnchor(Lex, Site.OperatorIndex),
              LastAnchorIndex(Assignment.Target), ssBefore);
            Site.After := Decide(Site.OperatorIndex,
              NextAnchor(Lex, Site.OperatorIndex), NextAnchor(Lex, Site.OperatorIndex),
              FirstAnchorIndex(Assignment.Value), ssAfter);
            Sites.Add(Site);
          end;
          for I := Node.ChildCount - 1 downto 0 do
            Stack.Push(Node.GetChild(I));
        end;
      end;
      // Every assignment in the tree must belong to a complete routine body.
      InTree := 0;
      Stack.Push(Tree.Root);
      while Stack.Count > 0 do
      begin
        Element := Stack.Pop;
        if Element is TSyntaxNode then
        begin
          Node := TSyntaxNode(Element);
          if Node.Kind = skAssignmentStatement then
            Inc(InTree);
          for I := Node.ChildCount - 1 downto 0 do
            Stack.Push(Node.GetChild(I));
        end;
      end;
      if InTree <> InBodies then
        Refuse([frUnknownContext], 'FMT013',
          'Formatting refused: assignment outside a complete routine body',
          TSourceSpan.Create(0, Length(Lex.Source)));
    end;
    Result.Diagnostics := Diagnostics.ToArray;
    if Result.Reasons = [] then
      Result.Sites := Sites.ToArray;
  finally
    Stack.Free;
    Sites.Free;
    Diagnostics.Free;
  end;
end;

end.
