unit Tests.Formatting;

interface

uses
  DUnitX.TestFramework, DelphiFormatter.Core.Diagnostics,
  DelphiFormatter.Core.TextEdits, DelphiFormatter.Formatting.Options,
  DelphiFormatter.Formatting.Safety, DelphiFormatter.Formatting.Engine;

type
  [TestFixture]
  TFormattingTests = class
  private
    function Options(Spacing: TAssignmentSpacing): TFormattingOptions;
    function Run(const Source: string; Spacing: TAssignmentSpacing;
      const Transform: TEditSetTransform = nil): TFormatResult;
    function Formatted(const Source: string; Spacing: TAssignmentSpacing): string;
    function DiagnosticText(R: TFormatResult): string;
    function HasDiagnostic(R: TFormatResult; const Code: string): Boolean;
    function ProtectedCount(R: TFormatResult; Reason: TFormatRefusalReason): Integer;
    procedure CheckRefused(const Source: string; Spacing: TAssignmentSpacing;
      Reason: TFormatRefusalReason; const Transform: TEditSetTransform = nil;
      const Code: string = '');
    procedure CheckSameEdit(const Expected, Actual: TTextEdit);
  public
    // Positive S0 behaviour (T-S0, T-SLOT, T-IDEM)
    [Test] procedure SingleAssignmentBoth;
    [Test] procedure MultipleAssignmentsVaryingSpacing;
    [Test] procedure AlreadyFormattedIsUnchanged;
    [Test] procedure AllAssignmentSpacingValues;
    [Test] procedure TabsInReleasedSlotsAreReplaced;
    [Test] procedure MultipleRoutinesAndNestedStatements;
    [Test] procedure UnitWithoutAssignmentIsUnchanged;
    [Test] procedure CommentsElsewhereArePreserved;
    [Test] procedure EolStylesArePreserved;
    [Test] procedure SecondRunIsIdempotent;
    [Test] procedure EndToEndE2E01;
    // Negative and protection behaviour (T-S0, T-SLOT, T-VERIFY)
    [Test] procedure AssignmentLookalikesInStringsAndComments;
    [Test] procedure ColonEqualsOutsideAssignmentStatement;
    [Test] procedure CommentAdjacentToOperatorFreezesSlot;
    [Test] procedure LiteralAdjacentToOperatorFreezesSlot;
    [Test] procedure CompilerDirectivesAreRefused;
    [Test] procedure UnresolvedIncludesAreRefused;
    [Test] procedure IncludeDirectiveClassification;
    [Test] procedure OpaqueOrIncompleteSyntaxIsRefused;
    [Test] procedure MalformedSourceIsReturnedUnchanged;
    [Test] procedure ControlWhitespaceIsNotRemoved;
    [Test] procedure LineBreaksAroundOperatorArePreserved;
    [Test] procedure ConflictingEditsAreDetected;
    [Test] procedure EditsAtProtectedBoundariesAreRefused;
    [Test] procedure InvalidOptionsAreDiagnosed;
    [Test] procedure ManipulatedEditsAndStaleSnapshotsAreRejected;
    [Test] procedure ForcedVerificationFailureRefuses;
    // Atomic S0 and option-aware verification (review fixes)
    [Test] procedure UnsatisfiableProtectedSlotRefusesWholeFile;
    [Test] procedure ProtectedSlotAlreadySatisfiedDoesNotBlock;
    [Test] procedure AsIsPreservesSourceExactly;
    [Test] procedure SuccessfulOutputSatisfiesEveryRequestedSlot;
    [Test] procedure TargetVerificationRejectsManipulatedEdits;
    [Test] procedure TargetVerificationDirect;
    [Test] procedure ThousandsOfAssignments;
    // Verification primitives, API and ownership (T-VERIFY, T-API, T-OWN)
    [Test] procedure LexicalSignatureV1Comparison;
    [Test] procedure SyntaxFingerprintV1Comparison;
    [Test] procedure SourceIdentityVectors;
    [Test] procedure SlotIdentityAndSpans;
    [Test] procedure ApplyTextEditsBackToFront;
    [Test] procedure ResultOutlivesInputsAndCopiesValues;
    [Test] procedure ApiMisuseRaises;
    [Test] procedure DeterministicAndReproducible;
    [Test] procedure RepeatedAllocationAndRelease;
    [Test] procedure OutputTreeIsLossless;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, DelphiFormatter.Core.Spans,
  DelphiFormatter.Lexer.Tokens, DelphiFormatter.Lexer.Scanner,
  DelphiFormatter.Syntax.Nodes, DelphiFormatter.Syntax.Tree,
  DelphiFormatter.Parser.Delphi, DelphiFormatter.Formatting.Verification;

const
  CRLF = #13#10;

function UnitWith(const Body: array of string; const Eol: string = CRLF;
  const Locals: string = '  X: Integer;'): string;
var
  Line: string;
begin
  Result := 'unit Example;' + Eol + Eol + 'interface' + Eol + Eol +
    'implementation' + Eol + Eol + 'procedure Test;' + Eol + 'var' + Eol +
    Locals + Eol + 'begin' + Eol;
  for Line in Body do
    Result := Result + '  ' + Line + Eol;
  Result := Result + 'end;' + Eol + Eol + 'end.' + Eol;
end;

function TokenIndices(Lex: TDelphiLexResult; const Text: string): TArray<Integer>;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Lex.TokenCount - 1 do
    if Lex.TokenText(I) = Text then
      Result := Result + [I];
end;

{ Helpers }

function TFormattingTests.Options(Spacing: TAssignmentSpacing): TFormattingOptions;
var
  Builder: TFormattingOptionsBuilder;
  Diagnostics: TArray<TDiagnostic>;
begin
  Builder := TFormattingOptionsBuilder.Create;
  try
    Builder.SetSafetyProfile(spS0, TOptionProvenance.ExplicitInternal('S0'));
    Builder.SetAssignmentSpacing(Spacing,
      TOptionProvenance.ExplicitInternal(IntToStr(Ord(Spacing))));
    Builder.SetEolPolicy(epPreserve, TOptionProvenance.ExplicitInternal('Preserve'));
    Builder.SetCompatibility(csNotRequested);
    Assert.IsTrue(Builder.TryBuild(Result, Diagnostics));
    Assert.AreEqual(0, Integer(Length(Diagnostics)));
  finally
    Builder.Free;
  end;
end;

function TFormattingTests.Run(const Source: string; Spacing: TAssignmentSpacing;
  const Transform: TEditSetTransform): TFormatResult;
var
  O: TFormattingOptions;
begin
  O := Options(Spacing);
  try
    Result := FormatTextWithEditTransform(Source, O, Transform);
  finally
    // Options are borrowed; every result below is read after this Free.
    O.Free;
  end;
  Assert.AreNotEqual(Ord(foPartiallyChanged), Ord(Result.Outcome),
    'S1 must never produce a partial result');
end;

function TFormattingTests.Formatted(const Source: string;
  Spacing: TAssignmentSpacing): string;
var
  R: TFormatResult;
begin
  R := Run(Source, Spacing);
  try
    Assert.AreNotEqual(Ord(foRefused), Ord(R.Outcome), DiagnosticText(R));
    Result := R.FormattedText;
  finally
    R.Free;
  end;
end;

function TFormattingTests.DiagnosticText(R: TFormatResult): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to R.DiagnosticCount - 1 do
    Result := Result + R.GetDiagnostic(I).Code + ' ' + R.GetDiagnostic(I).Message + '; ';
end;

function TFormattingTests.HasDiagnostic(R: TFormatResult; const Code: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to R.DiagnosticCount - 1 do
    if R.GetDiagnostic(I).Code = Code then
      Exit(True);
end;

function TFormattingTests.ProtectedCount(R: TFormatResult;
  Reason: TFormatRefusalReason): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to R.ProtectedRangeCount - 1 do
    if Reason in R.GetProtectedRange(I).Reasons then
    begin
      Assert.AreEqual(Ord(bpClosedBothSides), Ord(R.GetProtectedRange(I).BoundaryPolicy));
      Inc(Result);
    end;
end;

procedure TFormattingTests.CheckRefused(const Source: string;
  Spacing: TAssignmentSpacing; Reason: TFormatRefusalReason;
  const Transform: TEditSetTransform; const Code: string);
var
  R: TFormatResult;
begin
  R := Run(Source, Spacing, Transform);
  try
    Assert.AreEqual(Ord(foRefused), Ord(R.Outcome), DiagnosticText(R));
    Assert.IsTrue(Reason in R.RefusalReasons, DiagnosticText(R));
    Assert.AreEqual(Source, R.FormattedText);
    Assert.AreEqual(Source, R.OriginalSource);
    Assert.AreEqual(0, R.EditCount);
    Assert.AreEqual(1, R.ProtectedRangeCount);
    Assert.AreEqual(0, R.GetProtectedRange(0).Span.StartOffset);
    Assert.AreEqual(Length(Source), R.GetProtectedRange(0).Span.Length);
    Assert.IsTrue(R.RefusalReasons = R.GetProtectedRange(0).Reasons);
    Assert.AreEqual(ComputeSourceIdentity(Source), R.SourceIdentity);
    if Code <> '' then
      Assert.IsTrue(HasDiagnostic(R, Code), DiagnosticText(R));
  finally
    R.Free;
  end;
end;

procedure TFormattingTests.CheckSameEdit(const Expected, Actual: TTextEdit);
begin
  Assert.AreEqual(Expected.Span.StartOffset, Actual.Span.StartOffset, 'edit start');
  Assert.AreEqual(Expected.Span.Length, Actual.Span.Length, 'edit length');
  Assert.AreEqual(Expected.NewText, Actual.NewText, 'edit text');
  Assert.AreEqual(Expected.RuleId, Actual.RuleId, 'edit rule');
  Assert.AreEqual(Expected.LeftOriginalIndex, Actual.LeftOriginalIndex, 'left index');
  Assert.AreEqual(Expected.RightOriginalIndex, Actual.RightOriginalIndex, 'right index');
end;

{ Positive }

procedure TFormattingTests.SingleAssignmentBoth;
var
  Source: string;
  R: TFormatResult;
  Lex: TDelphiLexResult;
  Op: Integer;
begin
  Source := UnitWith(['X:=1;']);
  R := Run(Source, asBoth);
  Lex := TDelphiLexer.Tokenize(Source);
  try
    Assert.AreEqual(Ord(foChanged), Ord(R.Outcome), DiagnosticText(R));
    Assert.AreEqual(UnitWith(['X := 1;']), R.FormattedText);
    Assert.AreEqual(0, R.ProtectedRangeCount);
    Assert.IsTrue(R.RefusalReasons = []);
    Op := TokenIndices(Lex, ':=')[0];
    Assert.AreEqual(2, R.EditCount);
    CheckSameEdit(TTextEdit.Create(TSourceSpan.Create(Lex.GetToken(Op).Span.StartOffset, 0),
      ' ', S0AssignmentSpacingRuleId, Op - 1, Op), R.GetEdit(0));
    CheckSameEdit(TTextEdit.Create(TSourceSpan.Create(Lex.GetToken(Op).Span.EndOffset, 0),
      ' ', S0AssignmentSpacingRuleId, Op, Op + 1), R.GetEdit(1));
  finally
    Lex.Free;
    R.Free;
  end;
end;

procedure TFormattingTests.MultipleAssignmentsVaryingSpacing;
var
  R: TFormatResult;
begin
  R := Run(UnitWith(['X:=1;', 'X  :=  2;', 'X :=3;', 'X:= 4;', 'X := 5;']), asBoth);
  try
    Assert.AreEqual(Ord(foChanged), Ord(R.Outcome), DiagnosticText(R));
    Assert.AreEqual(UnitWith(['X := 1;', 'X := 2;', 'X := 3;', 'X := 4;', 'X := 5;']),
      R.FormattedText);
    // 2 insertions, 2 replacements, 1 + 1 single slots, none for the last.
    Assert.AreEqual(6, R.EditCount);
  finally
    R.Free;
  end;
end;

procedure TFormattingTests.AlreadyFormattedIsUnchanged;
var
  Source: string;
  R: TFormatResult;
begin
  Source := UnitWith(['X := 1;', 'X := X + 1;']);
  R := Run(Source, asBoth);
  try
    Assert.AreEqual(Ord(foUnchanged), Ord(R.Outcome), DiagnosticText(R));
    Assert.AreEqual(Source, R.FormattedText);
    Assert.AreEqual(0, R.EditCount);
    Assert.IsTrue(R.RefusalReasons = []);
  finally
    R.Free;
  end;
end;

procedure TFormattingTests.AllAssignmentSpacingValues;
var
  Source: string;
  R: TFormatResult;
begin
  Source := UnitWith(['X:=1;', 'X  :=  2;', 'X'#9':= 3;']);
  R := Run(Source, asAsIs);
  try
    Assert.AreEqual(Ord(foUnchanged), Ord(R.Outcome), DiagnosticText(R));
    Assert.AreEqual(Source, R.FormattedText);
    Assert.AreEqual(0, R.EditCount);
    Assert.AreEqual(0, R.ProtectedRangeCount);
  finally
    R.Free;
  end;
  Assert.AreEqual(UnitWith(['X:=1;', 'X:=2;', 'X:=3;']), Formatted(Source, asNone));
  Assert.AreEqual(UnitWith(['X :=1;', 'X :=2;', 'X :=3;']), Formatted(Source, asBefore));
  Assert.AreEqual(UnitWith(['X:= 1;', 'X:= 2;', 'X:= 3;']), Formatted(Source, asAfter));
  Assert.AreEqual(UnitWith(['X := 1;', 'X := 2;', 'X := 3;']), Formatted(Source, asBoth));
end;

procedure TFormattingTests.TabsInReleasedSlotsAreReplaced;
var
  Source: string;
begin
  Source := UnitWith(['X'#9':='#9#9'1;', 'X'#9' '#9':= 2;']);
  Assert.AreEqual(UnitWith(['X := 1;', 'X := 2;']), Formatted(Source, asBoth));
  Assert.AreEqual(UnitWith(['X:= 1;', 'X:= 2;']), Formatted(Source, asAfter));
  Assert.AreEqual(UnitWith(['X:=1;', 'X:=2;']), Formatted(Source, asNone));
  Assert.AreEqual(Source, Formatted(Source, asAsIs));
end;

procedure TFormattingTests.MultipleRoutinesAndNestedStatements;
const
  Template =
    'unit Nested;' + CRLF + CRLF +
    'interface' + CRLF + CRLF +
    'type' + CRLF +
    '  TFoo = class' + CRLF +
    '    FValue: Integer;' + CRLF +
    '    procedure Bar;' + CRLF +
    '  end;' + CRLF + CRLF +
    'function Sum(A: Integer): Integer;' + CRLF + CRLF +
    'implementation' + CRLF + CRLF +
    'procedure TFoo.Bar;' + CRLF +
    'begin' + CRLF +
    '  if FValue > 0 then FValue{0}1 else begin FValue{0}2; end;' + CRLF +
    '  Self.FValue{0}FValue * 2;' + CRLF +
    'end;' + CRLF + CRLF +
    'function Sum(A: Integer): Integer;' + CRLF +
    'var' + CRLF +
    '  I: Integer;' + CRLF +
    'begin' + CRLF +
    '  Result{0}0;' + CRLF +
    '  for I:=1 to A do Result{0}Result + I;' + CRLF +
    '  while A > 0 do begin A{0}A - 1; end;' + CRLF +
    '  repeat A{0}A + 1 until A > 3;' + CRLF +
    '  case A of' + CRLF +
    '    1: Result{0}-1;' + CRLF +
    '  else' + CRLF +
    '    Result{0}(Result);' + CRLF +
    '  end;' + CRLF +
    '  try' + CRLF +
    '    A{0}@A = nil;' + CRLF +
    '  finally' + CRLF +
    '    A{0}not A;' + CRLF +
    '  end;' + CRLF +
    'end;' + CRLF + CRLF +
    'end.' + CRLF;
var
  R: TFormatResult;
begin
  R := Run(StringReplace(Template, '{0}', ':=', [rfReplaceAll]), asBoth);
  try
    Assert.AreEqual(Ord(foChanged), Ord(R.Outcome), DiagnosticText(R));
    // The for-loop counter keeps its original 'I:=1' spelling.
    Assert.AreEqual(StringReplace(Template, '{0}', ' := ', [rfReplaceAll]),
      R.FormattedText);
    Assert.AreEqual(22, R.EditCount);
  finally
    R.Free;
  end;
end;

procedure TFormattingTests.UnitWithoutAssignmentIsUnchanged;
var
  Source: string;
  R: TFormatResult;
begin
  Source := 'unit Empty;' + CRLF + CRLF + 'interface' + CRLF + CRLF +
    'procedure Run;' + CRLF + CRLF + 'implementation' + CRLF + CRLF +
    'procedure Run;' + CRLF + 'begin' + CRLF + '  Run;' + CRLF + 'end;' + CRLF +
    CRLF + 'end.' + CRLF;
  R := Run(Source, asBoth);
  try
    Assert.AreEqual(Ord(foUnchanged), Ord(R.Outcome), DiagnosticText(R));
    Assert.AreEqual(Source, R.FormattedText);
    Assert.AreEqual(0, R.EditCount);
  finally
    R.Free;
  end;
  Assert.AreEqual('unit Minimal;' + CRLF + CRLF + 'interface' + CRLF + CRLF +
    'implementation' + CRLF + CRLF + 'end.' + CRLF,
    Formatted('unit Minimal;' + CRLF + CRLF + 'interface' + CRLF + CRLF +
    'implementation' + CRLF + CRLF + 'end.' + CRLF, asBoth));
end;

procedure TFormattingTests.CommentsElsewhereArePreserved;
var
  Source: string;
  R: TFormatResult;
begin
  Source := UnitWith(['// leading comment', 'X:=1; // trailing X:=2',
    '{ block } X:=2;', '(* star *)', 'X:=3 { before semicolon };'],
    CRLF, '  X: Integer; // counter');
  R := Run(Source, asBoth);
  try
    Assert.AreEqual(Ord(foChanged), Ord(R.Outcome), DiagnosticText(R));
    Assert.AreEqual(UnitWith(['// leading comment', 'X := 1; // trailing X:=2',
      '{ block } X := 2;', '(* star *)', 'X := 3 { before semicolon };'],
      CRLF, '  X: Integer; // counter'), R.FormattedText);
    Assert.AreEqual(6, R.EditCount);
    Assert.AreEqual(0, R.ProtectedRangeCount);
  finally
    R.Free;
  end;
end;

procedure TFormattingTests.EolStylesArePreserved;
const
  Eols: array[0..2] of string = (#13#10, #10, #13);
var
  Eol, Source, Expected, Output: string;
begin
  for Eol in Eols do
    Assert.AreEqual(UnitWith(['X := 1;', 'X := 2;'], Eol),
      Formatted(UnitWith(['X:=1;', 'X  :=2;'], Eol), asBoth));
  // Mixed line endings stay exactly where they were.
  Source := 'unit Mixed;'#13#10#13#10'interface'#10#10'implementation'#13#13 +
    'procedure Test;'#10'var'#13#10'  X: Integer;'#13'begin'#10 +
    '  X:=1;'#13#10'  X:=2;'#10'end;'#13#10#13#10'end.'#10;
  Expected := StringReplace(Source, 'X:=', 'X := ', [rfReplaceAll]);
  Output := Formatted(Source, asBoth);
  Assert.AreEqual(Expected, Output);
  Assert.AreEqual(Length(Source) + 4, Length(Output));
end;

procedure TFormattingTests.SecondRunIsIdempotent;
var
  Spacing: TAssignmentSpacing;
  Source, First: string;
  R: TFormatResult;
begin
  // Line-break slots are refused for every requested value (see
  // LineBreaksAroundOperatorAreNeverReplaced), so they are not part of this input.
  Source := UnitWith(['X:=1;', 'X  :=  2;', 'X'#9':= 3; // note', 'X := 4; { c }']);
  for Spacing := Low(TAssignmentSpacing) to High(TAssignmentSpacing) do
  begin
    First := Formatted(Source, Spacing);
    R := Run(First, Spacing);
    try
      Assert.AreEqual(Ord(foUnchanged), Ord(R.Outcome), DiagnosticText(R));
      Assert.AreEqual(0, R.EditCount);
      Assert.AreEqual(First, R.FormattedText);
    finally
      R.Free;
    end;
  end;
end;

procedure TFormattingTests.EndToEndE2E01;
const
  Expected =
    'unit FormatterAssignmentCorpus;' + CRLF + CRLF +
    'interface' + CRLF + CRLF +
    'implementation' + CRLF + CRLF +
    'procedure Test;' + CRLF +
    'var' + CRLF +
    '  X: Integer;' + CRLF +
    'begin' + CRLF +
    '  X := 1;' + CRLF +
    '  X := 2;' + CRLF +
    'end;' + CRLF + CRLF +
    'end.' + CRLF;
var
  Source: string;
  R, Second: TFormatResult;
  OldLex, NewLex: TDelphiLexResult;
  OldTree, NewTree: TSyntaxTree;
  Ops: TArray<Integer>;
begin
  // Compiled into this runner as a unit: X is declared, the source compiles.
  Source := TFile.ReadAllText('tests/Fixtures/FormatterAssignmentCorpus.pas',
    TEncoding.UTF8);
  Assert.AreEqual(StringReplace(StringReplace(Expected, 'X := 1', 'X:=1', []),
    'X := 2', 'X  :=  2', []), Source, 'fixture changed');
  R := Run(Source, asBoth);
  OldLex := TDelphiLexer.Tokenize(Source);
  OldTree := TDelphiParser.Parse(OldLex);
  NewLex := nil;
  NewTree := nil;
  try
    Assert.AreEqual(Ord(foChanged), Ord(R.Outcome), DiagnosticText(R));
    Assert.AreEqual(Expected, R.FormattedText);
    Assert.AreEqual(0, R.DiagnosticCount, DiagnosticText(R));
    Assert.AreEqual(0, R.ProtectedRangeCount);
    Assert.AreEqual(Ord(csNotRequested), Ord(R.Compatibility));
    // Exact minimal edits: two insertions, two replacements of '  '.
    Ops := TokenIndices(OldLex, ':=');
    Assert.AreEqual(2, Integer(Length(Ops)));
    Assert.AreEqual(4, R.EditCount);
    CheckSameEdit(TTextEdit.Create(TSourceSpan.Create(
      OldLex.GetToken(Ops[0]).Span.StartOffset, 0), ' ', S0AssignmentSpacingRuleId,
      Ops[0] - 1, Ops[0]), R.GetEdit(0));
    CheckSameEdit(TTextEdit.Create(TSourceSpan.Create(
      OldLex.GetToken(Ops[0]).Span.EndOffset, 0), ' ', S0AssignmentSpacingRuleId,
      Ops[0], Ops[0] + 1), R.GetEdit(1));
    CheckSameEdit(TTextEdit.Create(OldLex.GetToken(Ops[1] - 1).Span, ' ',
      S0AssignmentSpacingRuleId, Ops[1] - 2, Ops[1]), R.GetEdit(2));
    CheckSameEdit(TTextEdit.Create(OldLex.GetToken(Ops[1] + 1).Span, ' ',
      S0AssignmentSpacingRuleId, Ops[1], Ops[1] + 2), R.GetEdit(3));
    // Unchanged lexical signature and routine fingerprint.
    NewLex := TDelphiLexer.Tokenize(R.FormattedText);
    NewTree := TDelphiParser.Parse(NewLex);
    Assert.IsTrue(SameLexicalSignature(LexicalSignatureV1(OldLex),
      LexicalSignatureV1(NewLex)));
    Assert.AreEqual(1, Integer(Length(UnitRoutines(OldTree))));
    Assert.IsTrue(SameSyntaxFingerprint(
      SyntaxFingerprintV1(OldTree, UnitRoutines(OldTree)[0]),
      SyntaxFingerprintV1(NewTree, UnitRoutines(NewTree)[0])));
    // Second run produces zero edits.
    Second := Run(R.FormattedText, asBoth);
    try
      Assert.AreEqual(Ord(foUnchanged), Ord(Second.Outcome));
      Assert.AreEqual(0, Second.EditCount);
      Assert.AreEqual(Expected, Second.FormattedText);
    finally
      Second.Free;
    end;
  finally
    NewTree.Free;
    NewLex.Free;
    OldTree.Free;
    OldLex.Free;
    R.Free;
  end;
end;

{ Negative }

procedure TFormattingTests.AssignmentLookalikesInStringsAndComments;
var
  R: TFormatResult;
begin
  // Before: the literal-anchored slot after ':=' must stay empty, which it
  // already is, so the protected slot does not block the released one.
  R := Run(UnitWith(['S:=''X:=1'';', '// X:=2', '{ Y:=3 } X :=4;'], CRLF,
    '  X: Integer;' + CRLF + '  S: string;'), asBefore);
  try
    Assert.AreEqual(Ord(foChanged), Ord(R.Outcome), DiagnosticText(R));
    // String, comments and the literal-anchored slot stay byte-identical.
    Assert.AreEqual(UnitWith(['S :=''X:=1'';', '// X:=2', '{ Y:=3 } X :=4;'], CRLF,
      '  X: Integer;' + CRLF + '  S: string;'), R.FormattedText);
    Assert.AreEqual(1, R.EditCount);
    Assert.AreEqual(1, ProtectedCount(R, frUnsupportedConstruct));
    Assert.IsTrue(HasDiagnostic(R, 'FMT103'));
  finally
    R.Free;
  end;
end;

procedure TFormattingTests.ColonEqualsOutsideAssignmentStatement;
var
  Source: string;
  R: TFormatResult;
begin
  Source := UnitWith(['for I:=0 to 9 do X:=I;', 'for I  :=  0 to 9 do ;'], CRLF,
    '  X, I: Integer;');
  R := Run(Source, asBoth);
  try
    Assert.AreEqual(Ord(foChanged), Ord(R.Outcome), DiagnosticText(R));
    Assert.AreEqual(UnitWith(['for I:=0 to 9 do X := I;', 'for I  :=  0 to 9 do ;'],
      CRLF, '  X, I: Integer;'), R.FormattedText);
    Assert.AreEqual(2, R.EditCount);
  finally
    R.Free;
  end;
  // An inline variable initializer is another grammatical role; it stays
  // protected (the parser keeps it opaque) and the file is refused.
  CheckRefused(UnitWith(['var Y:=5;', 'X:=Y;']), asBoth, frOpaque);
end;

procedure TFormattingTests.CommentAdjacentToOperatorFreezesSlot;
var
  R: TFormatResult;
begin
  // Comment directly before / after ':=' and the slot would need a change.
  CheckRefused(UnitWith(['X:=1;', 'X{a}:=2;']), asBoth, frCommentAnchor, nil, 'FMT016');
  CheckRefused(UnitWith(['X:=1;', 'X:={b}2;']), asBoth, frCommentAnchor, nil, 'FMT016');
  CheckRefused(UnitWith(['X {a} := {b} 3;']), asNone, frCommentAnchor, nil, 'FMT016');
  CheckRefused(UnitWith(['X {a}:= 3;']), asBoth, frCommentAnchor, nil, 'FMT016');
  // Original spaces at protected slots that already match the request.
  R := Run(UnitWith(['X:=1;', 'X {a} := {b} 2;']), asBoth);
  try
    Assert.AreEqual(Ord(foChanged), Ord(R.Outcome), DiagnosticText(R));
    Assert.AreEqual(UnitWith(['X := 1;', 'X {a} := {b} 2;']), R.FormattedText);
    Assert.AreEqual(2, R.EditCount);
    Assert.AreEqual(2, ProtectedCount(R, frCommentAnchor));
    Assert.IsTrue(HasDiagnostic(R, 'FMT101'));
  finally
    R.Free;
  end;
  R := Run(UnitWith(['X:=1;', 'X(*c*):=(*d*)3;']), asNone);
  try
    Assert.AreEqual(Ord(foUnchanged), Ord(R.Outcome), DiagnosticText(R));
    Assert.AreEqual(2, ProtectedCount(R, frCommentAnchor));
  finally
    R.Free;
  end;
end;

procedure TFormattingTests.LiteralAdjacentToOperatorFreezesSlot;
const
  Locals = '  S: string;' + CRLF + '  C: Char;' + CRLF + '  X: Integer;';
var
  R: TFormatResult;
begin
  // String literal / char code directly after ':=' needing a change.
  CheckRefused(UnitWith(['S:=''a'';'], CRLF, Locals), asBoth, frUnsupportedConstruct,
    nil, 'FMT016');
  CheckRefused(UnitWith(['C:=#13;'], CRLF, Locals), asAfter, frUnsupportedConstruct,
    nil, 'FMT016');
  CheckRefused(UnitWith(['S  :=  ''b''#10;'], CRLF, Locals), asBefore,
    frUnsupportedConstruct, nil, 'FMT016');
  // Protected slots already in the requested state; numeric literals are
  // released code anchors.
  R := Run(UnitWith(['S:=''a'';', 'C:=#13;', 'X:=$FF;'], CRLF, Locals), asBefore);
  try
    Assert.AreEqual(Ord(foChanged), Ord(R.Outcome), DiagnosticText(R));
    Assert.AreEqual(UnitWith(['S :=''a'';', 'C :=#13;', 'X :=$FF;'], CRLF, Locals),
      R.FormattedText);
    Assert.AreEqual(3, R.EditCount);
    Assert.AreEqual(2, ProtectedCount(R, frUnsupportedConstruct));
  finally
    R.Free;
  end;
  R := Run(UnitWith(['S := ''a'';', 'C := #13;', 'X:=$FF;'], CRLF, Locals), asBoth);
  try
    Assert.AreEqual(Ord(foChanged), Ord(R.Outcome), DiagnosticText(R));
    Assert.AreEqual(UnitWith(['S := ''a'';', 'C := #13;', 'X := $FF;'], CRLF, Locals),
      R.FormattedText);
    Assert.AreEqual(2, R.EditCount);
  finally
    R.Free;
  end;
end;

procedure TFormattingTests.CompilerDirectivesAreRefused;
begin
  CheckRefused(UnitWith(['{$IFDEF DEBUG}', 'X:=1;', '{$ENDIF}']), asBoth,
    frDirectiveBoundary);
  CheckRefused(StringReplace(UnitWith(['X:=1;']), 'implementation' + CRLF,
    'implementation' + CRLF + '{$R *.res}' + CRLF, []), asBoth, frDirectiveBoundary);
  // Preconditions apply even when no slot is requested.
  CheckRefused(UnitWith(['{$IFDEF DEBUG}', 'X:=1;', '{$ENDIF}']), asAsIs,
    frDirectiveBoundary);
end;

procedure TFormattingTests.UnresolvedIncludesAreRefused;
begin
  CheckRefused(UnitWith(['{$I Shared.inc}', 'X:=1;']), asBoth, frUnresolvedInclude);
  CheckRefused(UnitWith(['{$INCLUDE Shared.inc}', 'X:=1;']), asBoth,
    frUnresolvedInclude);
  CheckRefused(StringReplace(UnitWith(['X:=1;']), 'implementation' + CRLF,
    'implementation' + CRLF + '(*$I Shared.inc*)' + CRLF, []), asBoth,
    frUnresolvedInclude);
end;

procedure TFormattingTests.IncludeDirectiveClassification;
begin
  Assert.IsTrue(IsIncludeDirective('{$I Shared.inc}'));
  Assert.IsTrue(IsIncludeDirective('{$i shared.inc}'));
  Assert.IsTrue(IsIncludeDirective('{$INCLUDE Shared.inc}'));
  Assert.IsTrue(IsIncludeDirective('(*$I Shared.inc*)'));
  Assert.IsFalse(IsIncludeDirective('{$I+}'));
  Assert.IsFalse(IsIncludeDirective('{$I-}'));
  Assert.IsFalse(IsIncludeDirective('{$IFDEF DEBUG}'));
  Assert.IsFalse(IsIncludeDirective('{$IOCHECKS ON}'));
  Assert.IsFalse(IsIncludeDirective('{$R *.res}'));
  Assert.IsFalse(IsIncludeDirective('{ $I comment }'));
end;

procedure TFormattingTests.OpaqueOrIncompleteSyntaxIsRefused;
var
  R: TFormatResult;
begin
  CheckRefused(UnitWith(['with X do Y:=1;']), asBoth, frOpaque);
  CheckRefused('program P;' + CRLF + 'var X: Integer;' + CRLF + 'begin' + CRLF +
    '  X:=1;' + CRLF + 'end.' + CRLF, asBoth, frUnknownContext);
  CheckRefused('unit Example;' + CRLF + 'interface' + CRLF + 'implementation' +
    CRLF + 'procedure Test;' + CRLF + 'begin' + CRLF + '  X:=1;' + CRLF, asBoth,
    frMissing);
  R := Run(UnitWith(['X:=1']), asBoth);
  try
    // A missing final semicolon before 'end' is valid Delphi and formatted.
    Assert.AreEqual(Ord(foChanged), Ord(R.Outcome), DiagnosticText(R));
  finally
    R.Free;
  end;
end;

procedure TFormattingTests.MalformedSourceIsReturnedUnchanged;
begin
  CheckRefused(UnitWith(['X:=''abc;']), asBoth, frLexicalError);
  CheckRefused(UnitWith(['X:=1 X:=2;']), asBoth, frOpaque);
  CheckRefused(UnitWith(['X:=;']), asBoth, frMissing);
  CheckRefused(UnitWith(['X:=1;', 'X:=' + #$D800 + ';']), asBoth, frLexicalError);
end;

procedure TFormattingTests.ControlWhitespaceIsNotRemoved;
var
  Source: string;
  R: TFormatResult;
begin
  Source := UnitWith(['X'#12':=1;']);
  CheckRefused(Source, asBoth, frUnsupportedWhitespace);
  CheckRefused(UnitWith(['X:='#11'1;']), asNone, frUnsupportedWhitespace);
  // Not requested: nothing is refused and nothing removed.
  R := Run(Source, asAsIs);
  try
    Assert.AreEqual(Ord(foUnchanged), Ord(R.Outcome), DiagnosticText(R));
    Assert.AreEqual(Source, R.FormattedText);
  finally
    R.Free;
  end;
end;

procedure TFormattingTests.LineBreaksAroundOperatorArePreserved;
var
  Spacing: TAssignmentSpacing;
  Source: string;
  R: TFormatResult;
begin
  // A line break is never replaced by horizontal spaces. It cannot hold any
  // requested horizontal target text, so every non-AsIs request refuses the
  // file atomically; nothing else is changed.
  for Spacing := asNone to asBoth do
  begin
    CheckRefused(UnitWith(['X:=1;', 'X' + CRLF + '    :=2;']), Spacing,
      frUnsupportedWhitespace, nil, 'FMT016');
    CheckRefused(UnitWith(['X:=1;', 'X:=' + CRLF + '    2;']), Spacing,
      frUnsupportedWhitespace, nil, 'FMT016');
  end;
  Source := UnitWith(['X' + CRLF + '    :=1;', 'X:=' + CRLF + '    2;',
    'X' + #10 + ':=' + #13 + '3;']);
  R := Run(Source, asAsIs);
  try
    Assert.AreEqual(Ord(foUnchanged), Ord(R.Outcome), DiagnosticText(R));
    Assert.AreEqual(Source, R.FormattedText);
  finally
    R.Free;
  end;
end;

procedure TFormattingTests.ConflictingEditsAreDetected;
var
  Normalized: TArray<TTextEdit>;
  A, B: TTextEdit;
begin
  A := TTextEdit.Create(TSourceSpan.Create(5, 0), ' ', 'R', 1, 2);
  B := TTextEdit.Create(TSourceSpan.Create(5, 0), #9, 'R', 1, 2);
  Assert.IsFalse(NormalizeTextEdits([A, B], Normalized), 'same offset, different text');
  Assert.AreEqual(0, Integer(Length(Normalized)));
  Assert.IsTrue(NormalizeTextEdits([A, A], Normalized), 'identical duplicates');
  Assert.AreEqual(1, Integer(Length(Normalized)));
  Assert.IsFalse(NormalizeTextEdits([TTextEdit.Create(TSourceSpan.Create(2, 4), '', 'R', 0, 1),
    TTextEdit.Create(TSourceSpan.Create(4, 3), '', 'R', 1, 2)], Normalized), 'overlap');
  Assert.IsFalse(NormalizeTextEdits([TTextEdit.Create(TSourceSpan.Create(2, 2), '', 'R', 0, 1),
    TTextEdit.Create(TSourceSpan.Create(4, 0), ' ', 'R', 1, 2)], Normalized),
    'touching closed boundary');
  Assert.IsTrue(NormalizeTextEdits([TTextEdit.Create(TSourceSpan.Create(9, 1), '', 'R', 3, 4),
    TTextEdit.Create(TSourceSpan.Create(2, 1), '', 'R', 0, 1)], Normalized), 'unsorted');
  Assert.AreEqual(2, Normalized[0].Span.StartOffset);
  Assert.AreEqual(9, Normalized[1].Span.StartOffset);
  // Engine: a second, different decision for the same slot refuses all edits.
  CheckRefused(UnitWith(['X:=1;']), asBoth, frEditConflict,
    procedure(var Edits: TArray<TTextEdit>)
    begin
      Edits := Edits + [Edits[0]];
      Edits[High(Edits)].NewText := #9;
    end);
end;

procedure TFormattingTests.EditsAtProtectedBoundariesAreRefused;
var
  Source: string;
  Lex: TDelphiLexResult;
  Op, Comment, Target: Integer;
  Boundary, Frozen: TTextEdit;
begin
  // The comment slot already has the requested ' '; only the slot after
  // ':=' is planned. Injected edits next to the comment must be rejected.
  Source := UnitWith(['X {a} :=1;']);
  Lex := TDelphiLexer.Tokenize(Source);
  try
    Op := TokenIndices(Lex, ':=')[0];
    Comment := PreviousAnchor(Lex, Op);
    Target := PreviousAnchor(Lex, Comment);
    Boundary := TTextEdit.Create(SlotSpan(Lex, Target, Comment), '',
      S0AssignmentSpacingRuleId, Target, Comment);
    Frozen := TTextEdit.Create(SlotSpan(Lex, Comment, Op), '',
      S0AssignmentSpacingRuleId, Comment, Op);
  finally
    Lex.Free;
  end;
  Assert.AreEqual(UnitWith(['X {a} := 1;']), Formatted(Source, asBoth));
  CheckRefused(Source, asBoth, frValidationFailure,
    procedure(var Edits: TArray<TTextEdit>)
    begin
      Edits := Edits + [Boundary];
    end, 'FMT012');
  CheckRefused(Source, asBoth, frValidationFailure,
    procedure(var Edits: TArray<TTextEdit>)
    begin
      Edits := Edits + [Frozen];
    end, 'FMT012');
end;

procedure TFormattingTests.InvalidOptionsAreDiagnosed;
var
  Builder: TFormattingOptionsBuilder;
  Options: TFormattingOptions;
  Diagnostics: TArray<TDiagnostic>;
  Bad: Integer;

  function Codes: string;
  var
    D: TDiagnostic;
  begin
    Result := '';
    for D in Diagnostics do
    begin
      Assert.AreEqual(Ord(dsError), Ord(D.Severity));
      Result := Result + D.Code + ';';
    end;
  end;

  procedure Complete(B: TFormattingOptionsBuilder);
  begin
    B.SetSafetyProfile(spS0, TOptionProvenance.ExplicitInternal('S0'));
    B.SetAssignmentSpacing(asBoth, TOptionProvenance.ExplicitInternal('Both'));
    B.SetEolPolicy(epPreserve, TOptionProvenance.ExplicitInternal('Preserve'));
    B.SetCompatibility(csNotRequested);
  end;

begin
  Builder := TFormattingOptionsBuilder.Create;
  try
    Assert.IsFalse(Builder.TryBuild(Options, Diagnostics));
    Assert.IsNull(Options);
    Assert.AreEqual('FMT201;FMT201;FMT201;FMT201;', Codes);
  finally
    Builder.Free;
  end;

  Builder := TFormattingOptionsBuilder.Create;
  try
    Builder.SetSafetyProfile(spS0, TOptionProvenance.ExplicitInternal('S0'));
    Builder.SetEolPolicy(epPreserve, TOptionProvenance.ExplicitInternal('Preserve'));
    Builder.SetCompatibility(csNotRequested);
    Assert.IsFalse(Builder.TryBuild(Options, Diagnostics));
    Assert.AreEqual('FMT201;', Codes);
    Assert.IsTrue(Pos('AssignmentSpacing', Diagnostics[0].Message) > 0);
  finally
    Builder.Free;
  end;

  Builder := TFormattingOptionsBuilder.Create;
  try
    Complete(Builder);
    Bad := 7;
    Builder.SetAssignmentSpacing(TAssignmentSpacing(Bad),
      TOptionProvenance.ExplicitInternal('7'));
    Assert.IsFalse(Builder.TryBuild(Options, Diagnostics));
    Assert.AreEqual('FMT202;', Codes);
  finally
    Builder.Free;
  end;

  Builder := TFormattingOptionsBuilder.Create;
  try
    Complete(Builder);
    Builder.SetAssignmentSpacing(asBoth,
      TOptionProvenance.Create(ooNativeValue, '', 'Both', '', '', ''));
    Assert.IsFalse(Builder.TryBuild(Options, Diagnostics));
    Assert.AreEqual('FMT203;', Codes);
    Builder.SetAssignmentSpacing(asBoth,
      TOptionProvenance.Create(ooExplicitInternal, 'Native.Key', 'Both', '', '', ''));
    Assert.IsFalse(Builder.TryBuild(Options, Diagnostics));
    Assert.AreEqual('FMT203;', Codes);
    Builder.SetAssignmentSpacing(asBoth,
      TOptionProvenance.Create(ooVerifiedDefault, '', '', '', '', ''));
    Assert.IsFalse(Builder.TryBuild(Options, Diagnostics));
    Assert.AreEqual('FMT203;', Codes);
  finally
    Builder.Free;
  end;

  Builder := TFormattingOptionsBuilder.Create;
  try
    Complete(Builder);
    Builder.SetCompatibility(csVerifiedSubset);
    Assert.IsFalse(Builder.TryBuild(Options, Diagnostics));
    Assert.AreEqual('FMT204;', Codes);
    Builder.SetCompatibility(csPartial);
    Assert.IsFalse(Builder.TryBuild(Options, Diagnostics));
    Assert.AreEqual('FMT204;', Codes);
    Builder.SetCompatibility(csUnverified);
    Assert.IsTrue(Builder.TryBuild(Options, Diagnostics));
    try
      Assert.AreEqual(0, Integer(Length(Diagnostics)));
      Assert.AreEqual(Ord(csUnverified), Ord(Options.Compatibility));
      Assert.AreEqual(Ord(ooExplicitInternal),
        Ord(Options.GetProvenance(fsAssignmentSpacing).Origin));
      Assert.AreEqual('Both', Options.GetProvenance(fsAssignmentSpacing).RawValue);
    finally
      Options.Free;
    end;
  finally
    Builder.Free;
  end;
end;

procedure TFormattingTests.ManipulatedEditsAndStaleSnapshotsAreRejected;
var
  Source, Output, Failure: string;
  Lex: TDelphiLexResult;
  Tree: TSyntaxTree;
  Analysis: TS0Analysis;
  Site: TAssignmentSlotSite;
  Input, Bad: TVerificationInput;
begin
  Source := UnitWith(['X:=1;']);
  Lex := TDelphiLexer.Tokenize(Source);
  Tree := TDelphiParser.Parse(Lex);
  try
    Input.OriginalSource := Source;
    Input.SourceIdentity := ComputeSourceIdentity(Source);
    Input.Snapshot := Source;
    Input.OriginalLex := Lex;
    Input.OriginalTree := Tree;
    Input.AssignmentSpacing := asBoth;
    Analysis := AnalyzeS0(Lex, Tree, Input.SourceIdentity, True);
    Assert.IsTrue(Analysis.Reasons = []);
    Assert.AreEqual(1, Integer(Length(Analysis.Sites)));
    Site := Analysis.Sites[0];
    Input.Edits := [
      TTextEdit.Create(Site.Before.Span, ' ', S0AssignmentSpacingRuleId,
        Site.Before.LeftOriginalIndex, Site.Before.RightOriginalIndex),
      TTextEdit.Create(Site.After.Span, ' ', S0AssignmentSpacingRuleId,
        Site.After.LeftOriginalIndex, Site.After.RightOriginalIndex)];
    Assert.IsTrue(VerifyAndApply(Input, Output, Failure), Failure);
    Assert.AreEqual(UnitWith(['X := 1;']), Output);

    Bad := Input;
    Bad.Snapshot := Source + ' ';
    Assert.IsFalse(VerifyAndApply(Bad, Output, Failure), 'stale snapshot');
    Assert.AreEqual('', Output);

    Bad := Input;
    Bad.SourceIdentity := ComputeSourceIdentity('other');
    Assert.IsFalse(VerifyAndApply(Bad, Output, Failure), 'identity');

    Bad := Input;
    Bad.Edits := Copy(Input.Edits);
    Bad.Edits[1].NewText := ' X';
    Assert.IsFalse(VerifyAndApply(Bad, Output, Failure), 'new token');

    Bad := Input;
    Bad.Edits := Copy(Input.Edits);
    Bad.Edits[0].Span := TSourceSpan.Create(Site.Before.Span.StartOffset - 1, 1);
    Assert.IsFalse(VerifyAndApply(Bad, Output, Failure), 'span over a token');

    Bad := Input;
    Bad.Edits := Copy(Input.Edits);
    Bad.Edits[0].RuleId := 'Other';
    Assert.IsFalse(VerifyAndApply(Bad, Output, Failure), 'unreleased rule');

    Bad := Input;
    Bad.Edits := Copy(Input.Edits);
    Bad.Edits[0].NewText := '';
    Assert.IsFalse(VerifyAndApply(Bad, Output, Failure), 'no-op edit');

    Bad := Input;
    Bad.Edits := [Input.Edits[1], Input.Edits[0]];
    Assert.IsFalse(VerifyAndApply(Bad, Output, Failure), 'not canonical');
  finally
    Tree.Free;
    Lex.Free;
  end;
end;

procedure TFormattingTests.ForcedVerificationFailureRefuses;
var
  Source: string;
  R: TFormatResult;
begin
  Source := UnitWith(['X:=1;', 'X:=2;']);
  R := Run(Source, asBoth,
    procedure(var Edits: TArray<TTextEdit>)
    begin
      Edits[High(Edits)].NewText := ' ;';
    end);
  try
    Assert.AreEqual(Ord(foRefused), Ord(R.Outcome));
    Assert.IsTrue(frValidationFailure in R.RefusalReasons);
    Assert.AreEqual(Source, R.FormattedText);
    Assert.AreEqual(0, R.EditCount);
    Assert.IsTrue(HasDiagnostic(R, 'FMT012'));
  finally
    R.Free;
  end;
end;

{ Atomic S0 and option-aware verification }

procedure TFormattingTests.UnsatisfiableProtectedSlotRefusesWholeFile;
const
  Locals = '  X: Integer;' + CRLF + '  S: string;';
begin
  // Earlier safe assignments are not changed when a later one is refused ...
  CheckRefused(UnitWith(['X:=1;', 'X  :=  2;', 'S:=''a'';'], CRLF, Locals), asBoth,
    frUnsupportedConstruct, nil, 'FMT016');
  // ... nor later ones after an earlier refusal.
  CheckRefused(UnitWith(['S:=''a'';', 'X:=1;'], CRLF, Locals), asBoth,
    frUnsupportedConstruct, nil, 'FMT016');
  CheckRefused(UnitWith(['X:=1;', 'X:={c}2;', 'X:=3;']), asAfter, frCommentAnchor,
    nil, 'FMT016');
end;

procedure TFormattingTests.ProtectedSlotAlreadySatisfiedDoesNotBlock;
const
  Locals = '  X: Integer;' + CRLF + '  S: string;';
var
  R: TFormatResult;
begin
  R := Run(UnitWith(['X:=1;', 'S :=''a'';', 'X {c} := 2;', 'X  :=3;'], CRLF, Locals),
    asBefore);
  try
    Assert.AreEqual(Ord(foChanged), Ord(R.Outcome), DiagnosticText(R));
    Assert.AreEqual(UnitWith(['X :=1;', 'S :=''a'';', 'X {c} :=2;', 'X :=3;'], CRLF,
      Locals), R.FormattedText);
    Assert.AreEqual(3, R.EditCount);
    Assert.AreEqual(1, ProtectedCount(R, frUnsupportedConstruct));
    Assert.AreEqual(1, ProtectedCount(R, frCommentAnchor));
    Assert.IsFalse(HasDiagnostic(R, 'FMT016'));
  finally
    R.Free;
  end;
end;

procedure TFormattingTests.AsIsPreservesSourceExactly;
var
  Source: string;
  R: TFormatResult;
begin
  Source := UnitWith(['X:=1;', 'X  :=  2;', 'X{a}:={b}3;', 'S:=''s''#13;',
    'X'#9':='#9'4;', 'X' + CRLF + '  :=' + #10 + '5;'], CRLF,
    '  X: Integer;' + CRLF + '  S: string;');
  R := Run(Source, asAsIs);
  try
    Assert.AreEqual(Ord(foUnchanged), Ord(R.Outcome), DiagnosticText(R));
    Assert.AreEqual(Source, R.FormattedText);
    Assert.AreEqual(0, R.EditCount);
    Assert.AreEqual(0, R.ProtectedRangeCount);
    Assert.IsTrue(R.RefusalReasons = []);
  finally
    R.Free;
  end;
end;

procedure TFormattingTests.SuccessfulOutputSatisfiesEveryRequestedSlot;
const
  // Independent expectation table for this test: [value, before?].
  Targets: array[asNone..asBoth, Boolean] of string = (('', ''), ('', ' '),
    (' ', ''), (' ', ' '));
var
  Spacing: TAssignmentSpacing;
  Output: string;
  Lex: TDelphiLexResult;
  Tree: TSyntaxTree;
  Analysis: TS0Analysis;
  Site: TAssignmentSlotSite;

  function Slot(const D: TSlotDecision): string;
  begin
    Result := Copy(Output, D.Span.StartOffset + 1, D.Span.Length);
  end;

begin
  for Spacing := asNone to asBoth do
  begin
    Output := Formatted(UnitWith(['X:=1;', 'X  :=  2;', 'X'#9':= 3;', 'X := 4; // c',
      'if X > 0 then X:=-X else X:= not X;']), Spacing);
    Lex := TDelphiLexer.Tokenize(Output);
    try
      Tree := TDelphiParser.Parse(Lex);
      try
        Analysis := AnalyzeS0(Lex, Tree, ComputeSourceIdentity(Output), True);
        Assert.IsTrue(Analysis.Reasons = []);
        Assert.AreEqual(6, Integer(Length(Analysis.Sites)));
        for Site in Analysis.Sites do
        begin
          Assert.AreEqual(Targets[Spacing, True], Slot(Site.Before));
          Assert.AreEqual(Targets[Spacing, False], Slot(Site.After));
        end;
      finally
        Tree.Free;
      end;
    finally
      Lex.Free;
    end;
  end;
end;

procedure TFormattingTests.TargetVerificationRejectsManipulatedEdits;
var
  Source: string;
  Lex: TDelphiLexResult;
  Plus, BeforePlus, Op: Integer;
  Extra, Injected: TTextEdit;
  R: TFormatResult;
begin
  Source := UnitWith(['X:=1;', 'X  :=  2;', 'X := X + 1;']);
  Lex := TDelphiLexer.Tokenize(Source);
  try
    Plus := TokenIndices(Lex, '+')[0];
    BeforePlus := PreviousAnchor(Lex, Plus);
    // Syntactically harmless, but not a requested assignment slot.
    Extra := TTextEdit.Create(SlotSpan(Lex, BeforePlus, Plus), '  ',
      S0AssignmentSpacingRuleId, BeforePlus, Plus);
  finally
    Lex.Free;
  end;
  CheckRefused(Source, asBoth, frValidationFailure,
    procedure(var Edits: TArray<TTextEdit>)
    begin
      Edits[0].NewText := #9;
    end, 'FMT012');
  CheckRefused(Source, asBoth, frValidationFailure,
    procedure(var Edits: TArray<TTextEdit>)
    begin
      Edits[0].NewText := '  ';
    end, 'FMT012');
  CheckRefused(Source, asBoth, frValidationFailure,
    procedure(var Edits: TArray<TTextEdit>)
    begin
      Delete(Edits, 1, 1);
    end, 'FMT012');
  CheckRefused(Source, asBoth, frValidationFailure,
    procedure(var Edits: TArray<TTextEdit>)
    begin
      Edits[High(Edits)].NewText := ' '#9;
    end, 'FMT012');
  CheckRefused(Source, asBoth, frValidationFailure,
    procedure(var Edits: TArray<TTextEdit>)
    begin
      Edits := Edits + [Extra];
    end, 'FMT012');
  CheckRefused(Source, asBoth, frValidationFailure,
    procedure(var Edits: TArray<TTextEdit>)
    begin
      Edits := nil;
    end, 'FMT012');
  // The untouched, correct edit set passes.
  R := Run(Source, asBoth,
    procedure(var Edits: TArray<TTextEdit>)
    begin
    end);
  try
    Assert.AreEqual(Ord(foChanged), Ord(R.Outcome), DiagnosticText(R));
    Assert.AreEqual(UnitWith(['X := 1;', 'X := 2;', 'X := X + 1;']), R.FormattedText);
    Assert.AreEqual(4, R.EditCount);
  finally
    R.Free;
  end;
  // AsIs requests nothing; any injected edit is rejected.
  Source := UnitWith(['X:=1;']);
  Lex := TDelphiLexer.Tokenize(Source);
  try
    Op := TokenIndices(Lex, ':=')[0];
    Injected := TTextEdit.Create(SlotSpan(Lex, Op - 1, Op), ' ',
      S0AssignmentSpacingRuleId, Op - 1, Op);
  finally
    Lex.Free;
  end;
  CheckRefused(Source, asAsIs, frValidationFailure,
    procedure(var Edits: TArray<TTextEdit>)
    begin
      Edits := Edits + [Injected];
    end, 'FMT012');
end;

procedure TFormattingTests.TargetVerificationDirect;
var
  Source, Output, Failure: string;
  Lex: TDelphiLexResult;
  Tree: TSyntaxTree;
  Analysis: TS0Analysis;
  Site: TAssignmentSlotSite;
  Input, Bad: TVerificationInput;
begin
  Source := UnitWith(['X:=1;']);
  Lex := TDelphiLexer.Tokenize(Source);
  Tree := TDelphiParser.Parse(Lex);
  try
    Input.OriginalSource := Source;
    Input.SourceIdentity := ComputeSourceIdentity(Source);
    Input.Snapshot := Source;
    Input.OriginalLex := Lex;
    Input.OriginalTree := Tree;
    Input.AssignmentSpacing := asBoth;
    Analysis := AnalyzeS0(Lex, Tree, Input.SourceIdentity, True);
    Site := Analysis.Sites[0];
    Input.Edits := [
      TTextEdit.Create(Site.Before.Span, ' ', S0AssignmentSpacingRuleId,
        Site.Before.LeftOriginalIndex, Site.Before.RightOriginalIndex),
      TTextEdit.Create(Site.After.Span, ' ', S0AssignmentSpacingRuleId,
        Site.After.LeftOriginalIndex, Site.After.RightOriginalIndex)];
    Assert.IsTrue(VerifyAndApply(Input, Output, Failure), Failure);

    Bad := Input;
    Bad.Edits := Copy(Input.Edits);
    Bad.Edits[0].NewText := #9;
    Assert.IsFalse(VerifyAndApply(Bad, Output, Failure), 'tab instead of space');
    Assert.IsTrue(Pos('AssignmentSpacing', Failure) > 0, Failure);
    Assert.AreEqual('', Output);

    Bad := Input;
    Bad.Edits := Copy(Input.Edits);
    Bad.Edits[1].NewText := '  ';
    Assert.IsFalse(VerifyAndApply(Bad, Output, Failure), 'two spaces');

    Bad := Input;
    Bad.Edits := [Input.Edits[0]];
    Assert.IsFalse(VerifyAndApply(Bad, Output, Failure), 'missing edit');

    Bad := Input;
    Bad.Edits := nil;
    Assert.IsFalse(VerifyAndApply(Bad, Output, Failure), 'no edits');

    Bad := Input;
    Bad.AssignmentSpacing := asNone;
    Assert.IsFalse(VerifyAndApply(Bad, Output, Failure), 'edits for another value');

    Bad := Input;
    Bad.AssignmentSpacing := asAsIs;
    Assert.IsFalse(VerifyAndApply(Bad, Output, Failure), 'AsIs with edits');

    Bad := Input;
    Bad.AssignmentSpacing := asAsIs;
    Bad.Edits := nil;
    Assert.IsTrue(VerifyAndApply(Bad, Output, Failure), Failure);
    Assert.AreEqual(Source, Output);

    Bad := Input;
    Bad.AssignmentSpacing := asNone;
    Bad.Edits := nil;
    Assert.IsTrue(VerifyAndApply(Bad, Output, Failure), 'None already holds');
  finally
    Tree.Free;
    Lex.Free;
  end;
end;

procedure TFormattingTests.ThousandsOfAssignments;
const
  Count = 5000;
var
  Body, Expected: TArray<string>;
  I: Integer;
  R: TFormatResult;
begin
  SetLength(Body, Count);
  SetLength(Expected, Count);
  for I := 0 to Count - 1 do
  begin
    if Odd(I) then Body[I] := 'X  :=  X + 1;' else Body[I] := 'X:=' + IntToStr(I) + ';';
    if Odd(I) then Expected[I] := 'X := X + 1;'
    else Expected[I] := 'X := ' + IntToStr(I) + ';';
  end;
  // Linear merge of edits and slots; no timing assertion (T-PERF).
  R := Run(UnitWith(Body), asBoth);
  try
    Assert.AreEqual(Ord(foChanged), Ord(R.Outcome), DiagnosticText(R));
    Assert.AreEqual(UnitWith(Expected), R.FormattedText);
    Assert.AreEqual(2 * Count, R.EditCount);
  finally
    R.Free;
  end;
end;

{ Verification primitives, API and ownership }

procedure TFormattingTests.LexicalSignatureV1Comparison;

  function Same(const A, B: string): Boolean;
  var
    LA, LB: TDelphiLexResult;
  begin
    LA := TDelphiLexer.Tokenize(A);
    LB := TDelphiLexer.Tokenize(B);
    try
      Result := SameLexicalSignature(LexicalSignatureV1(LA), LexicalSignatureV1(LB));
    finally
      LB.Free;
      LA.Free;
    end;
  end;

begin
  Assert.IsTrue(Same('X:=1;', 'X  :=' + CRLF + #9'1 ;'));
  Assert.IsFalse(Same('X:=1;', 'X:=2;'));
  Assert.IsFalse(Same('A B', 'AB'), 'lexeme fusion');
  Assert.IsFalse(Same('X:=1; {a}', 'X:=1; {b}'), 'comment text');
  Assert.IsFalse(Same('X:=1; {a}', 'X:=1;'), 'comment removed');
  Assert.IsFalse(Same('x:=1;', 'X:=1;'), 'no casefolding');
end;

procedure TFormattingTests.SyntaxFingerprintV1Comparison;

  function Fingerprint(const Body: string): TSyntaxFingerprintV1;
  var
    Lex: TDelphiLexResult;
    Tree: TSyntaxTree;
  begin
    Lex := TDelphiLexer.Tokenize(UnitWith([Body]));
    try
      Tree := TDelphiParser.Parse(Lex);
      try
        Result := SyntaxFingerprintV1(Tree, UnitRoutines(Tree)[0]);
      finally
        Tree.Free;
      end;
    finally
      Lex.Free;
    end;
  end;

begin
  Assert.AreEqual('SyntaxFingerprintV1', Fingerprint('X:=1;')[0]);
  Assert.IsTrue(SameSyntaxFingerprint(Fingerprint('X:=1;'), Fingerprint('X := 1 ;')));
  Assert.IsTrue(SameSyntaxFingerprint(Fingerprint('X:=1;'), Fingerprint('X:={c}1;')),
    'comments are covered by the lexical signature');
  Assert.IsFalse(SameSyntaxFingerprint(Fingerprint('X:=1;'), Fingerprint('X:=2;')));
  Assert.IsFalse(SameSyntaxFingerprint(Fingerprint('X:=1;'), Fingerprint('X:=(1);')));
  Assert.IsFalse(SameSyntaxFingerprint(Fingerprint('X:=1+2*3;'),
    Fingerprint('X:=(1+2)*3;')));
  Assert.IsFalse(SameSyntaxFingerprint(Fingerprint('X:=1;'), nil),
    'missing fingerprint is never equal');
end;

procedure TFormattingTests.SourceIdentityVectors;
var
  R: TFormatResult;
begin
  Assert.AreEqual('E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855',
    ComputeSourceIdentity(''));
  Assert.AreEqual('E61C21CA716B3B1AEFB7D1198F83679C4CA4D596E5792275DD6203B49216237D',
    ComputeSourceIdentity('A'));
  Assert.AreEqual('2D87FF616ABE761DC9FE747DD741CA1E4A1AA09371185ABE78C97FF36F48B405',
    ComputeSourceIdentity('X:=1;'));
  // Isolated surrogate hashed as-is (00 D8), never replaced.
  Assert.AreEqual('205022E3428B7C8276CF247B36E4E512DB5651E5CB3472C253D9EE893A8AC750',
    ComputeSourceIdentity(#$D800));
  R := Run(UnitWith(['X:=1;']), asBoth);
  try
    Assert.AreEqual(ComputeSourceIdentity(UnitWith(['X:=1;'])), R.SourceIdentity);
  finally
    R.Free;
  end;
end;

procedure TFormattingTests.SlotIdentityAndSpans;
var
  Lex: TDelphiLexResult;
  Span: TSourceSpan;
begin
  Lex := TDelphiLexer.Tokenize('  unit'#9'{c} X'#13#10);
  try
    // Tokens: ws, unit, tab, comment, ws, X, newline, EOF.
    Assert.AreEqual(-1, PreviousAnchor(Lex, 1), 'BOF sentinel');
    Span := SlotSpan(Lex, -1, 1);
    Assert.AreEqual(0, Span.StartOffset);
    Assert.AreEqual(2, Span.Length);
    Assert.AreEqual(3, NextAnchor(Lex, 1), 'comment is an anchor');
    Assert.AreEqual(5, NextAnchor(Lex, 3));
    Assert.AreEqual(7, NextAnchor(Lex, 5), 'EOF is the last anchor');
    Span := SlotSpan(Lex, 5, 7);
    Assert.AreEqual(Lex.GetToken(5).Span.EndOffset, Span.StartOffset);
    Assert.AreEqual(2, Span.Length);
    Span := SlotSpan(Lex, 3, 5);
    Assert.AreEqual(1, Span.Length);
  finally
    Lex.Free;
  end;
end;

procedure TFormattingTests.ApplyTextEditsBackToFront;
begin
  Assert.AreEqual('a b  c', ApplyTextEdits('a b c', [
    TTextEdit.Create(TSourceSpan.Create(3, 1), '  ', 'R', 0, 1)]));
  Assert.AreEqual('X := 1;', ApplyTextEdits('X:=1;', [
    TTextEdit.Create(TSourceSpan.Create(1, 0), ' ', 'R', 0, 1),
    TTextEdit.Create(TSourceSpan.Create(3, 0), ' ', 'R', 1, 2)]));
  Assert.AreEqual('X:=1;', ApplyTextEdits('X  :=  1;', [
    TTextEdit.Create(TSourceSpan.Create(1, 2), '', 'R', 0, 1),
    TTextEdit.Create(TSourceSpan.Create(5, 2), '', 'R', 1, 2)]));
  Assert.AreEqual('', ApplyTextEdits('  ', [
    TTextEdit.Create(TSourceSpan.Create(0, 2), '', 'R', -1, 0)]));
  Assert.AreEqual('abc', ApplyTextEdits('abc', []));
end;

procedure TFormattingTests.ResultOutlivesInputsAndCopiesValues;
var
  R: TFormatResult;
  Edit: TTextEdit;
  Diagnostic: TDiagnostic;
begin
  R := Run(UnitWith(['X {c} :=1;']), asBoth);
  try
    // Options, lexer result and tree are all freed by now.
    Assert.AreEqual(UnitWith(['X {c} := 1;']), R.FormattedText);
    Edit := R.GetEdit(0);
    Edit.NewText := 'changed';
    Assert.AreEqual(' ', R.GetEdit(0).NewText, 'edits are value copies');
    Diagnostic := R.GetDiagnostic(0);
    Diagnostic.Code := 'changed';
    Assert.AreEqual('FMT101', R.GetDiagnostic(0).Code);
    Assert.AreEqual(1, R.ProtectedRangeCount);
    Assert.IsTrue(R.GetProtectedRange(0).Reasons = [frCommentAnchor]);
  finally
    R.Free;
  end;
end;

procedure TFormattingTests.ApiMisuseRaises;
var
  R: TFormatResult;
begin
  Assert.WillRaise(
    procedure
    begin
      FormatText('unit A; interface implementation end.', nil).Free;
    end, EArgumentNilException);
  Assert.WillRaise(
    procedure
    begin
      TFormatResult.Create.Free;
    end, EInvalidOpException);
  Assert.WillRaise(
    procedure
    begin
      TFormattingOptions.Create.Free;
    end, EInvalidOpException);
  Assert.WillRaise(
    procedure
    begin
      ApplyTextEdits('abc', [TTextEdit.Create(TSourceSpan.Create(2, 2), '', 'R', 0, 1)]);
    end, EArgumentOutOfRangeException);
  Assert.WillRaise(
    procedure
    begin
      ApplyTextEdits('abcdef', [TTextEdit.Create(TSourceSpan.Create(3, 1), '', 'R', 1, 2),
        TTextEdit.Create(TSourceSpan.Create(1, 1), '', 'R', 0, 1)]);
    end, EArgumentException);
  R := Run(UnitWith(['X:=1;']), asBoth);
  try
    Assert.WillRaise(procedure begin R.GetEdit(-1); end, EArgumentOutOfRangeException);
    Assert.WillRaise(procedure begin R.GetEdit(R.EditCount); end,
      EArgumentOutOfRangeException);
    Assert.WillRaise(procedure begin R.GetDiagnostic(R.DiagnosticCount); end,
      EArgumentOutOfRangeException);
    Assert.WillRaise(procedure begin R.GetProtectedRange(0); end,
      EArgumentOutOfRangeException);
  finally
    R.Free;
  end;
end;

procedure TFormattingTests.DeterministicAndReproducible;
var
  Source: string;
  A, B: TFormatResult;
  I: Integer;
begin
  Source := UnitWith(['X {c} :=1;', 'X  :=  2;', 'S := ''s'';'], CRLF,
    '  X: Integer;' + CRLF + '  S: string;');
  A := Run(Source, asBoth);
  B := Run(Source, asBoth);
  try
    Assert.AreEqual(Ord(foChanged), Ord(A.Outcome), DiagnosticText(A));
    Assert.AreEqual(A.FormattedText, B.FormattedText);
    Assert.AreEqual(A.EditCount, B.EditCount);
    for I := 0 to A.EditCount - 1 do
      CheckSameEdit(A.GetEdit(I), B.GetEdit(I));
    Assert.AreEqual(A.DiagnosticCount, B.DiagnosticCount);
    for I := 0 to A.DiagnosticCount - 1 do
    begin
      Assert.AreEqual(A.GetDiagnostic(I).Code, B.GetDiagnostic(I).Code);
      Assert.AreEqual(A.GetDiagnostic(I).Span.StartOffset,
        B.GetDiagnostic(I).Span.StartOffset);
    end;
    Assert.AreEqual(A.ProtectedRangeCount, B.ProtectedRangeCount);
    for I := 0 to A.ProtectedRangeCount - 1 do
      Assert.AreEqual(A.GetProtectedRange(I).Span.StartOffset,
        B.GetProtectedRange(I).Span.StartOffset);
    // Canonical order: strictly increasing, separated spans.
    for I := 1 to A.EditCount - 1 do
      Assert.IsTrue(A.GetEdit(I).Span.StartOffset > A.GetEdit(I - 1).Span.EndOffset);
  finally
    B.Free;
    A.Free;
  end;
end;

procedure TFormattingTests.RepeatedAllocationAndRelease;
var
  I: Integer;
  R: TFormatResult;
  Source: string;
begin
  Source := UnitWith(['X:=1;', 'X{c}:=2;']);
  for I := 1 to 200 do
  begin
    R := Run(Source, TAssignmentSpacing(I mod (Ord(High(TAssignmentSpacing)) + 1)));
    try
      Assert.AreEqual(Source, R.OriginalSource);
    finally
      R.Free;
    end;
  end;
  for I := 1 to 50 do
  begin
    R := Run(UnitWith(['{$IFDEF X}', 'X:=1;', '{$ENDIF}']), asBoth);
    R.Free;
  end;
end;

procedure TFormattingTests.OutputTreeIsLossless;
var
  Output: string;
  Lex: TDelphiLexResult;
  Tree: TSyntaxTree;
begin
  Output := Formatted(UnitWith(['X:=1; // c', 'X  :=  X + 1;']), asBoth);
  Lex := TDelphiLexer.Tokenize(Output);
  try
    Tree := TDelphiParser.Parse(Lex);
    try
      Assert.AreEqual(Output, Tree.Serialize);
      Assert.AreEqual(0, Tree.DiagnosticCount);
    finally
      Tree.Free;
    end;
  finally
    Lex.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TFormattingTests);

end.
