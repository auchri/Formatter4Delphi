unit DelphiFormatter.Formatting.Verification;

interface

uses
  DelphiFormatter.Core.TextEdits, DelphiFormatter.Lexer.Tokens,
  DelphiFormatter.Syntax.Nodes, DelphiFormatter.Syntax.Tree,
  DelphiFormatter.Formatting.Safety;

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
  // edits are applied to; it must equal OriginalSource exactly.
  TVerificationInput = record
    OriginalSource: string;
    SourceIdentity: string;
    Snapshot: string;
    OriginalLex: TDelphiLexResult;
    OriginalTree: TSyntaxTree;
    Decisions: TArray<TSlotDecision>;
    OwnerOrdinals: TArray<Integer>;
    Edits: TArray<TTextEdit>;
  end;

function LexicalSignatureV1(Lex: TDelphiLexResult): TLexicalSignatureV1;
function SameLexicalSignature(const A, B: TLexicalSignatureV1): Boolean;
function SyntaxFingerprintV1(Tree: TSyntaxTree; Owner: TSyntaxElement): TSyntaxFingerprintV1;
function SameSyntaxFingerprint(const A, B: TSyntaxFingerprintV1): Boolean;

// Checks the snapshot and edit set, applies the edits once, re-lexes and
// re-parses once and verifies every S0 invariant. Returns False with
// Formatted='' and a Failure description on the first violation.
function VerifyAndApply(const Input: TVerificationInput; out Formatted: string;
  out Failure: string): Boolean;

implementation

uses
  System.SysUtils, System.Generics.Collections, DelphiFormatter.Core.Spans,
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

function VerifyAndApply(const Input: TVerificationInput; out Formatted: string;
  out Failure: string): Boolean;
var
  Lex, NewLex: TDelphiLexResult;
  NewTree: TSyntaxTree;
  Edits: TArray<TTextEdit>;
  Edit: TTextEdit;
  Decision: TSlotDecision;
  OldAnchors, NewAnchors: TArray<Integer>;
  OldRoutines, NewRoutines: TArray<TSyntaxNode>;
  Scratch: TList<TDiagnostic>;
  Output, Expected, Actual: string;
  I, J, K, P, Delta, Ordinal, OldStart, NewStart, Left: Integer;
  Found, Covered: Boolean;

  function Fail(const Message: string): Boolean;
  begin
    Failure := Message;
    Result := False;
  end;

begin
  Formatted := '';
  Failure := '';
  if (Input.OriginalLex = nil) or (Input.OriginalTree = nil) then
    raise EArgumentNilException.Create('Original lexer result and tree are required');
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

  // 2. Canonical, released, horizontal-only edits; one per slot.
  OldRoutines := UnitRoutines(Input.OriginalTree);
  for I := 0 to High(Edits) do
  begin
    Edit := Edits[I];
    if Edit.Span.EndOffset > Length(Input.Snapshot) then
      Exit(Fail('Edit outside source bounds'));
    if (I > 0) and (Edit.Span.StartOffset <= Edits[I - 1].Span.EndOffset) then
      Exit(Fail('Edits are not canonical, disjoint and separated'));
    if Edit.RuleId <> S0AssignmentSpacingRuleId then
      Exit(Fail('Edit from an unreleased rule: ' + Edit.RuleId));
    for J := 1 to Length(Edit.NewText) do
      if (Edit.NewText[J] <> ' ') and (Edit.NewText[J] <> #9) then
        Exit(Fail('Edit text is not horizontal whitespace'));
    if (Edit.RightOriginalIndex <= 0) or
      (Edit.RightOriginalIndex >= Lex.TokenCount) or
      not IsAnchorKind(Lex.GetToken(Edit.RightOriginalIndex).Kind) or
      (Edit.LeftOriginalIndex <> PreviousAnchor(Lex, Edit.RightOriginalIndex)) then
      Exit(Fail('Edit does not denote a slot between adjacent anchors'));
    if IsProtectedAnchor(Lex, Edit.LeftOriginalIndex) or
      IsProtectedAnchor(Lex, Edit.RightOriginalIndex) then
      Exit(Fail('Edit at a protected boundary'));
    Found := False;
    for Decision in Input.Decisions do
      if (Decision.LeftOriginalIndex = Edit.LeftOriginalIndex) and
        (Decision.RightOriginalIndex = Edit.RightOriginalIndex) then
      begin
        Found := Decision.AllowWhitespace and (Decision.Reasons = []) and
          (Decision.SourceIdentity = Input.SourceIdentity) and
          (Decision.Span.StartOffset = Edit.Span.StartOffset) and
          (Decision.Span.Length = Edit.Span.Length);
        Break;
      end;
    if not Found then
      Exit(Fail('Edit is not covered by a released slot decision'));
    if (SlotSpan(Lex, Edit.LeftOriginalIndex, Edit.RightOriginalIndex).StartOffset <>
      Edit.Span.StartOffset) or
      (SlotSpan(Lex, Edit.LeftOriginalIndex, Edit.RightOriginalIndex).Length <>
      Edit.Span.Length) then
      Exit(Fail('Edit span differs from its slot span'));
    Actual := Copy(Input.Snapshot, Edit.Span.StartOffset + 1, Edit.Span.Length);
    if (Pos(#13, Actual) > 0) or (Pos(#10, Actual) > 0) then
      Exit(Fail('Edit replaces a line-break slot'));
    if Actual = Edit.NewText then
      Exit(Fail('Edit does not change its slot'));
    // The slot must lie inside one released complete owner.
    Covered := False;
    for Ordinal in Input.OwnerOrdinals do
      if (Ordinal >= 0) and (Ordinal <= High(OldRoutines)) and
        (FirstAnchorIndex(OldRoutines[Ordinal]) < Edit.LeftOriginalIndex) and
        (LastAnchorIndex(OldRoutines[Ordinal]) > Edit.RightOriginalIndex) then
        Covered := True;
    if not Covered then
      Exit(Fail('Edit outside every released owner'));
  end;

  // 3. Apply exactly once, back to front.
  Output := ApplyTextEdits(Input.Snapshot, Edits);

  // 4. Re-lex once: signature, mapped anchors and every slot text.
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

    // 5. Re-parse once: diagnostics, preconditions and owner fingerprints.
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
      if (Length(Edits) > 0) and (Length(Input.OwnerOrdinals) = 0) then
        Exit(Fail('Edits without a released owner'));
      for Ordinal in Input.OwnerOrdinals do
      begin
        if (Ordinal < 0) or (Ordinal > High(OldRoutines)) then
          Exit(Fail('Unknown released owner'));
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
  Formatted := Output;
  Result := True;
end;

end.
