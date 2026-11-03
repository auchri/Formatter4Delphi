unit DelphiFormatter.Formatting.Verification;

interface

uses
  DelphiFormatter.Core.TextEdits, DelphiFormatter.Lexer.Tokens,
  DelphiFormatter.Syntax.Nodes, DelphiFormatter.Syntax.Tree,
  DelphiFormatter.Formatting.Options, DelphiFormatter.Formatting.Safety;

type
  TLexicalSignatureEntry = record
    Kind: TTokenKind;
    Text: string;
  end;
  // Ordered (TokenKind, exact text) of every token except whitespace and
  // newline, including comments, directives, unknown tokens and EOF.
  TLexicalSignatureV1 = TArray<TLexicalSignatureEntry>;
  // Ordered events of one owner: version tag, node kind open/close, exact
  // non-trivia token lexemes and missing expectations. No spans or indices.
  TSyntaxFingerprintV1 = TArray<string>;

  // Borrowed inputs of one verification run. Snapshot is the string the
  // edits are applied to; it must equal OriginalSource exactly. The requested
  // slots, their release and their target texts are derived again here from
  // the original tree and AssignmentSpacing; planner decisions are no input.
  TVerificationInput = record
    OriginalSource: string;
    SourceIdentity: string;
    Snapshot: string;
    OriginalLex: TDelphiLexResult;
    OriginalTree: TSyntaxTree;
    AssignmentSpacing: TAssignmentSpacing;
    Edits: TArray<TTextEdit>;
  end;

function LexicalSignatureV1(Lex: TDelphiLexResult): TLexicalSignatureV1;
function SameLexicalSignature(const A, B: TLexicalSignatureV1): Boolean;
function SyntaxFingerprintV1(Tree: TSyntaxTree; Owner: TSyntaxElement): TSyntaxFingerprintV1;
function SameSyntaxFingerprint(const A, B: TSyntaxFingerprintV1): Boolean;

// Checks the snapshot and edit set, applies the edits once, re-lexes and
// re-parses once and verifies every S0 invariant, including that every
// requested assignment slot of the output has its AssignmentSpacing target
// text. Returns False with Formatted='' and a Failure description on the
// first violation.
function VerifyAndApply(const Input: TVerificationInput; out Formatted: string;
  out Failure: string): Boolean;

implementation

uses
  System.SysUtils, System.Generics.Collections, System.Generics.Defaults,
  DelphiFormatter.Core.Spans,
  DelphiFormatter.Core.Diagnostics, DelphiFormatter.Lexer.Scanner,
  DelphiFormatter.Syntax.Query, DelphiFormatter.Parser.Delphi;

const
  FingerprintVersion = 'SyntaxFingerprintV1';

function LexicalSignatureV1(Lex: TDelphiLexResult): TLexicalSignatureV1;
var
  I, Count: Integer;
begin
  if Lex = nil then
    raise EArgumentNilException.Create('Lex');
  SetLength(Result, Lex.TokenCount);
  Count := 0;
  for I := 0 to Lex.TokenCount - 1 do
    if IsAnchorKind(Lex.GetToken(I).Kind) then
    begin
      Result[Count].Kind := Lex.GetToken(I).Kind;
      Result[Count].Text := Lex.TokenText(I);
      Inc(Count);
    end;
  SetLength(Result, Count);
end;

function SameLexicalSignature(const A, B: TLexicalSignatureV1): Boolean;
var
  I: Integer;
begin
  Result := Length(A) = Length(B);
  for I := 0 to High(A) do
    if not Result then
      Break
    else
      Result := (A[I].Kind = B[I].Kind) and (A[I].Text = B[I].Text);
end;

function SyntaxFingerprintV1(Tree: TSyntaxTree; Owner: TSyntaxElement): TSyntaxFingerprintV1;
var
  Stack: TStack<TSyntaxElement>;
  Events: TList<string>;
  Element: TSyntaxElement;
  Node: TSyntaxNode;
  Token: TSyntaxToken;
  I: Integer;
begin
  if (Tree = nil) or (Owner = nil) then
    raise EArgumentNilException.Create('Tree and owner are required');
  Stack := TStack<TSyntaxElement>.Create;
  Events := TList<string>.Create;
  try
    Events.Add(FingerprintVersion);
    Stack.Push(Owner);
    while Stack.Count > 0 do
    begin
      Element := Stack.Pop;
      if Element = nil then
        Events.Add(')')
      else if Element is TSyntaxNode then
      begin
        Node := TSyntaxNode(Element);
        Events.Add('N' + IntToStr(Ord(Node.Kind)) + '(');
        Stack.Push(nil);
        for I := Node.ChildCount - 1 downto 0 do
          Stack.Push(Node.GetChild(I));
      end
      else
      begin
        Token := TSyntaxToken(Element);
        if Token.IsMissing then
          Events.Add('M' + Token.ExpectedText)
        else if not IsTriviaLeaf(Token) then
          Events.Add('T' + IntToStr(Ord(Token.OriginalToken.Kind)) + ':' +
            Copy(Tree.Source, Token.Span.StartOffset + 1, Token.Span.Length));
      end;
    end;
    Result := Events.ToArray;
  finally
    Events.Free;
    Stack.Free;
  end;
end;

function SameSyntaxFingerprint(const A, B: TSyntaxFingerprintV1): Boolean;
var
  I: Integer;
begin
  Result := (Length(A) = Length(B)) and (Length(A) > 0) and
    (A[0] = FingerprintVersion) and (B[0] = FingerprintVersion);
  for I := 1 to High(A) do
    if not Result then
      Break
    else
      Result := A[I] = B[I];
end;

function AnchorIndices(Lex: TDelphiLexResult): TArray<Integer>;
var
  I, Count: Integer;
begin
  SetLength(Result, Lex.TokenCount);
  Count := 0;
  for I := 0 to Lex.TokenCount - 1 do
    if IsAnchorKind(Lex.GetToken(I).Kind) then
    begin
      Result[Count] := I;
      Inc(Count);
    end;
  SetLength(Result, Count);
end;

function AnchorOrdinal(const Anchors: TArray<Integer>; Index: Integer): Integer;
var
  Lo, Hi, Middle: Integer;
begin
  Lo := 0;
  Hi := Length(Anchors) - 1;
  while Lo <= Hi do
  begin
    Middle := (Lo + Hi) div 2;
    if Anchors[Middle] = Index then
      Exit(Middle);
    if Anchors[Middle] < Index then
      Lo := Middle + 1
    else
      Hi := Middle - 1;
  end;
  Result := -1;
end;

function SlotText(Lex: TDelphiLexResult; const Source: string;
  Left, Right: Integer): string;
var
  Span: TSourceSpan;
begin
  Span := SlotSpan(Lex, Left, Right);
  Result := Copy(Source, Span.StartOffset + 1, Span.Length);
end;

function IsProtectedAnchor(Lex: TDelphiLexResult; Index: Integer): Boolean;
begin
  Result := (Index < 0) or (Lex.GetToken(Index).Kind in [tkComment,
    tkStringLiteral, tkCharCode, tkCompilerDirective, tkUnknown, tkEOF]);
end;

// Offset of an original position after all edits ending at or before it.
function MapOffset(const Edits: TArray<TTextEdit>; Offset: Integer): Integer;
var
  I: Integer;
begin
  Result := Offset;
  for I := 0 to High(Edits) do
    if Edits[I].Span.EndOffset <= Offset then
      Result := Result + Length(Edits[I].NewText) - Edits[I].Span.Length;
end;

function SameDiagnostic(const Old, New: TDiagnostic;
  const Edits: TArray<TTextEdit>): Boolean;
var
  Start, Stop: Integer;
begin
  Start := MapOffset(Edits, Old.Span.StartOffset);
  Stop := MapOffset(Edits, Old.Span.EndOffset);
  Result := (Old.Code = New.Code) and (Old.Message = New.Message) and
    (Old.Severity = New.Severity) and (New.Span.StartOffset = Start) and
    (New.Span.Length = Stop - Start);
end;

type
  TRequestedSlot = record
    Decision: TSlotDecision;
    Before: Boolean;
  end;

// Target text of one assignment slot. Deliberately derived here from the
// option value alone, independent of the engine's planning code.
function TargetSlotText(Spacing: TAssignmentSpacing; Before: Boolean): string;
begin
  case Spacing of
    asNone:
      Result := '';
    asBefore:
      if Before then Result := ' ' else Result := '';
    asAfter:
      if Before then Result := '' else Result := ' ';
    asBoth:
      Result := ' ';
  else
    raise EArgumentException.Create('AsIs has no target slot text');
  end;
end;

function VerifyAndApply(const Input: TVerificationInput; out Formatted: string;
  out Failure: string): Boolean;
var
  Lex, NewLex: TDelphiLexResult;
  NewTree: TSyntaxTree;
  Edits: TArray<TTextEdit>;
  Edit: TTextEdit;
  Analysis: TS0Analysis;
  Site: TAssignmentSlotSite;
  Requested: TList<TRequestedSlot>;
  Slots: TArray<TRequestedSlot>;
  Slot: TRequestedSlot;
  Owners: TList<Integer>;
  OldAnchors, NewAnchors: TArray<Integer>;
  OldRoutines, NewRoutines: TArray<TSyntaxNode>;
  Scratch: TList<TDiagnostic>;
  Output, Expected, Actual: string;
  I, J, K, P, Delta, Ordinal, OldStart, NewStart, Left: Integer;

  function Fail(const Message: string): Boolean;
  begin
    Failure := Message;
    Result := False;
  end;

  procedure Request(const Decision: TSlotDecision; Before: Boolean);
  var
    Item: TRequestedSlot;
  begin
    Item.Decision := Decision;
    Item.Before := Before;
    Requested.Add(Item);
  end;

begin
  Formatted := '';
  Failure := '';
  if (Input.OriginalLex = nil) or (Input.OriginalTree = nil) then
    raise EArgumentNilException.Create('Original lexer result and tree are required');
  if Integer(Byte(Input.AssignmentSpacing)) > Ord(High(TAssignmentSpacing)) then
    raise EArgumentOutOfRangeException.Create('AssignmentSpacing out of range');
  Lex := Input.OriginalLex;
  Edits := Input.Edits;

  // 1. Exact snapshot, identity and matching analysis.
  if Input.Snapshot <> Input.OriginalSource then
    Exit(Fail('Stale snapshot: source to edit differs from the analysed source'));
  if (Input.SourceIdentity = '') or
    (ComputeSourceIdentity(Input.Snapshot) <> Input.SourceIdentity) then
    Exit(Fail('Source identity does not match the snapshot'));
  if (Lex.Source <> Input.OriginalSource) or
    (Input.OriginalTree.Source <> Input.OriginalSource) then
    Exit(Fail('Analysis does not belong to the snapshot'));

  // 2. Independent S0 analysis: requested slots, their release and owners.
  Analysis := AnalyzeS0(Lex, Input.OriginalTree, Input.SourceIdentity,
    Input.AssignmentSpacing <> asAsIs);
  if Analysis.Reasons <> [] then
    Exit(Fail('S0 preconditions do not hold for the input'));
  if (Input.AssignmentSpacing = asAsIs) and (Length(Edits) > 0) then
    Exit(Fail('AsIs requests no edits'));
  Requested := TList<TRequestedSlot>.Create;
  Owners := TList<Integer>.Create;
  try
    for Site in Analysis.Sites do
    begin
      Request(Site.Before, True);
      Request(Site.After, False);
      if (Owners.Count = 0) or (Owners.Last <> Site.OwnerOrdinal) then
        Owners.Add(Site.OwnerOrdinal);
    end;
    Slots := Requested.ToArray;
    // Ordered by right anchor so edits and slots merge monotonically.
    TArray.Sort<TRequestedSlot>(Slots, TComparer<TRequestedSlot>.Construct(
      function(const A, B: TRequestedSlot): Integer
      begin
        Result := A.Decision.RightOriginalIndex - B.Decision.RightOriginalIndex;
      end));

    // 3. Canonical, released, horizontal-only edits; one per requested slot.
    OldRoutines := UnitRoutines(Input.OriginalTree);
    J := 0;
    for I := 0 to High(Edits) do
    begin
      Edit := Edits[I];
      if Edit.Span.EndOffset > Length(Input.Snapshot) then
        Exit(Fail('Edit outside source bounds'));
      if (I > 0) and (Edit.Span.StartOffset <= Edits[I - 1].Span.EndOffset) then
        Exit(Fail('Edits are not canonical, disjoint and separated'));
      if Edit.RuleId <> S0AssignmentSpacingRuleId then
        Exit(Fail('Edit from an unreleased rule: ' + Edit.RuleId));
      for K := 1 to Length(Edit.NewText) do
        if (Edit.NewText[K] <> ' ') and (Edit.NewText[K] <> #9) then
          Exit(Fail('Edit text is not horizontal whitespace'));
      if (Edit.RightOriginalIndex <= 0) or
        (Edit.RightOriginalIndex >= Lex.TokenCount) or
        not IsAnchorKind(Lex.GetToken(Edit.RightOriginalIndex).Kind) or
        (Edit.LeftOriginalIndex <> PreviousAnchor(Lex, Edit.RightOriginalIndex)) then
        Exit(Fail('Edit does not denote a slot between adjacent anchors'));
      if IsProtectedAnchor(Lex, Edit.LeftOriginalIndex) or
        IsProtectedAnchor(Lex, Edit.RightOriginalIndex) then
        Exit(Fail('Edit at a protected boundary'));
      while (J <= High(Slots)) and
        (Slots[J].Decision.RightOriginalIndex < Edit.RightOriginalIndex) do
        Inc(J);
      if (J > High(Slots)) or
        (Slots[J].Decision.RightOriginalIndex <> Edit.RightOriginalIndex) or
        (Slots[J].Decision.LeftOriginalIndex <> Edit.LeftOriginalIndex) or
        not Slots[J].Decision.AllowWhitespace or
        (Slots[J].Decision.Span.StartOffset <> Edit.Span.StartOffset) or
        (Slots[J].Decision.Span.Length <> Edit.Span.Length) then
        Exit(Fail('Edit is not covered by a released requested slot'));
      Actual := Copy(Input.Snapshot, Edit.Span.StartOffset + 1, Edit.Span.Length);
      if (Pos(#13, Actual) > 0) or (Pos(#10, Actual) > 0) then
        Exit(Fail('Edit replaces a line-break slot'));
      if Actual = Edit.NewText then
        Exit(Fail('Edit does not change its slot'));
    end;

    // 4. Apply exactly once, back to front.
    Output := ApplyTextEdits(Input.Snapshot, Edits);

    // 5. Re-lex once: signature, mapped anchors and every slot text.
    NewLex := TDelphiLexer.Tokenize(Output);
    try
      if not SameLexicalSignature(LexicalSignatureV1(Lex), LexicalSignatureV1(NewLex)) then
        Exit(Fail('LexicalSignatureV1 differs'));
      OldAnchors := AnchorIndices(Lex);
      NewAnchors := AnchorIndices(NewLex);
      P := 0;
      Delta := 0;
      for K := 0 to High(OldAnchors) do
      begin
        Left := -1;
        if K > 0 then Left := OldAnchors[K - 1];
        Expected := SlotText(Lex, Input.Snapshot, Left, OldAnchors[K]);
        if (P <= High(Edits)) and (Edits[P].RightOriginalIndex = OldAnchors[K]) then
        begin
          Expected := Edits[P].NewText;
          Delta := Delta + Length(Edits[P].NewText) - Edits[P].Span.Length;
          Inc(P);
        end;
        Left := -1;
        if K > 0 then Left := NewAnchors[K - 1];
        if SlotText(NewLex, Output, Left, NewAnchors[K]) <> Expected then
          Exit(Fail('Slot text changed outside the released edits'));
        OldStart := Lex.GetToken(OldAnchors[K]).Span.StartOffset;
        NewStart := NewLex.GetToken(NewAnchors[K]).Span.StartOffset;
        if NewStart <> OldStart + Delta then
          Exit(Fail('Anchor offset does not follow the edit map'));
      end;
      if P <> Length(Edits) then
        Exit(Fail('Edit not matched to an original slot'));
      if NewLex.DiagnosticCount <> Lex.DiagnosticCount then
        Exit(Fail('Lexical diagnostics changed'));
      for I := 0 to Lex.DiagnosticCount - 1 do
        if not SameDiagnostic(Lex.GetDiagnostic(I), NewLex.GetDiagnostic(I), Edits) then
          Exit(Fail('Lexical diagnostics changed'));

      // 6. Rule target state: every requested slot of the output has exactly
      // the text AssignmentSpacing demands. Missing, extra or wrong edits and
      // protected slots that would need a change all fail here.
      if Input.AssignmentSpacing <> asAsIs then
        for Slot in Slots do
        begin
          K := AnchorOrdinal(OldAnchors, Slot.Decision.RightOriginalIndex);
          if K < 0 then
            Exit(Fail('Requested slot has no anchor correspondence'));
          Left := -1;
          if K > 0 then Left := NewAnchors[K - 1];
          if SlotText(NewLex, Output, Left, NewAnchors[K]) <>
            TargetSlotText(Input.AssignmentSpacing, Slot.Before) then
            Exit(Fail(Format('Output does not satisfy AssignmentSpacing at the ' +
              'slot between original tokens %d and %d',
              [Slot.Decision.LeftOriginalIndex, Slot.Decision.RightOriginalIndex])));
        end;

      // 7. Re-parse once: diagnostics, preconditions and owner fingerprints.
      NewTree := TDelphiParser.Parse(NewLex);
      Scratch := nil;
      try
        Scratch := TList<TDiagnostic>.Create;
        if NewTree.Serialize <> Output then
          Exit(Fail('Re-parsed tree is not lossless'));
        if NewTree.DiagnosticCount <> Input.OriginalTree.DiagnosticCount then
          Exit(Fail('Parser diagnostics changed'));
        for I := 0 to NewTree.DiagnosticCount - 1 do
          if not SameDiagnostic(Input.OriginalTree.GetDiagnostic(I),
            NewTree.GetDiagnostic(I), Edits) then
            Exit(Fail('Parser diagnostics changed'));
        if CheckS0Preconditions(NewLex, NewTree, Scratch) <> [] then
          Exit(Fail('S0 preconditions do not hold for the output'));
        NewRoutines := UnitRoutines(NewTree);
        if Length(NewRoutines) <> Length(OldRoutines) then
          Exit(Fail('Routine owners changed'));
        for Ordinal in Owners do
        begin
          if AnchorOrdinal(OldAnchors, FirstAnchorIndex(OldRoutines[Ordinal])) <>
            AnchorOrdinal(NewAnchors, FirstAnchorIndex(NewRoutines[Ordinal])) then
            Exit(Fail('Owner correspondence lost'));
          if not SameSyntaxFingerprint(
            SyntaxFingerprintV1(Input.OriginalTree, OldRoutines[Ordinal]),
            SyntaxFingerprintV1(NewTree, NewRoutines[Ordinal])) then
            Exit(Fail('SyntaxFingerprintV1 differs'));
        end;
      finally
        Scratch.Free;
        NewTree.Free;
      end;
    finally
      NewLex.Free;
    end;
  finally
    Owners.Free;
    Requested.Free;
  end;
  Formatted := Output;
  Result := True;
end;

end.
