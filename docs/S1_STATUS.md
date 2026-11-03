# S1 – Safe formatter foundation and assignment spacing

Status: implemented on branch `codex/s1-safe-formatter-foundation`, based on
`main` e954d6e50d8fe6fc0ff769f1c1adae210a1068c8 (A0 merged via PR #11), including
the PR #12 review fixes (atomic S0, option-aware verification). PR #10 (M2.8
directives, head 65000fca7ce3890541aa1f691a17666ef47cfb92) stays open and
independent; no code from it is used. Stop after S1.

Normative target: `design/docs/spec/06_FORMATTER.md`, `14_CONTRACTS.md`
sections 6–9 and 11, ADR-002. This document records what is actually implemented
and executed; it is not a competing contract.

## Supported behaviour

`FormatText(Source, Options)` changes exactly one thing: the two horizontal
slots directly before and after `:=` of an `skAssignmentStatement` inside the
block body of a complete routine of a complete, directive-free unit. Everything
else is preserved byte for byte. `AssignmentSpacing` is an internal value
(`AsIs`, `None`, `Before`, `After`, `Both`), not a RAD Studio option name.

| Value | Slot before `:=` | Slot after `:=` |
|---|---|---|
| AsIs | original | original |
| None | empty | empty |
| Before | one U+0020 | empty |
| After | empty | one U+0020 |
| Both | one U+0020 | one U+0020 |

**Success/refusal semantics (atomic S0).** For a value other than `AsIs` every
assignment slot in scope is *requested*. The result is:

- `foChanged` – at least one edit, and afterwards **every** requested slot has
  exactly its target text (verified independently, see below);
- `foUnchanged` – every requested slot already has its target text (or `AsIs`);
- `foRefused` – any precondition fails, or a protected requested slot (comment
  anchor, string literal/char code anchor, line break) would need a change.
  All other planned edits are discarded: output = input, 0 edits.

A protected slot that already has its target text needs no edit and does not
block other changes; it is still reported as a protected range. A line break
can never hold a horizontal target text, so a requested line-break slot always
refuses the file; S0 never replaces a line break by spaces. `AsIs` requests
nothing, so protected slots never refuse it (whole-file preconditions still
apply). `foPartiallyChanged` is never produced.

Not supported (by design): declarations, `for` counters and any other `:=`
role, indentation, line breaks, alignment, capitalization, comments,
directives, partial formatting, native configuration, CLI and file IO.

## Units

| Unit | Responsibility |
|---|---|
| `Core.TextEdits` | `TTextEdit` (single edit DTO), `NormalizeTextEdits` (canonical sort, exact-duplicate removal, conflict detection), `ApplyTextEdits` (one back-to-front application) |
| `Syntax.Query` | Read-only borrowed role views: `TryGetAssignmentRoles` (Target, Operator, Value), `TryGetRoutineRoles` (Header, Body, FinalSemicolon), first/last anchor leaf of an element. No reparse, no new node kinds |
| `Formatting.Options` | Immutable `TFormattingOptions`; `TFormattingOptionsBuilder.TryBuild` validates every required setting and provenance; no defaults |
| `Formatting.Safety` | `TFormatRefusalReason(s)`, `TSlotDecision`, `TProtectedRange`, `ComputeSourceIdentity`, anchor/slot helpers, whole-file S0 preconditions, per-assignment slot decisions |
| `Formatting.Verification` | `LexicalSignatureV1`, `SyntaxFingerprintV1`, `VerifyAndApply` (including the rule target state) |
| `Formatting.Engine` | `TFormatOutcome`, immutable `TFormatResult`, `FormatText` pipeline with atomic planning |

Dependencies: Core.TextEdits → Core.Spans; Syntax.Query → Syntax/Lexer;
Formatting.Options → Core; Safety → Core/Lexer/Syntax; Verification →
Options/Safety/Parser/Lexer/Syntax/Core; Engine → all of the above. No cycles,
no VCL/FMX, no IO, no global mutable state.

## Pipeline

1. `SourceIdentity` = SHA-256 of the UTF-16 code units, low byte then high byte,
   no BOM, no surrogate repair, 64 uppercase hex digits.
2. Lex and parse once (`TDelphiLexer.Tokenize`, `TDelphiParser.Parse`).
3. Whole-file preconditions; any failure refuses the file.
4. Unit-level routines with proven roles; every `skAssignmentStatement` in
   their bodies; assignments elsewhere refuse the file.
5. For each assignment the slot before and after the operator is decided
   (positive release, everything not examined stays protected).
6. Atomic planning: target text per requested slot; released slot → edit only
   if the text differs; protected slot → no edit if it already matches,
   otherwise whole-file refusal (FMT016) before any edit is considered.
7. Canonical, conflict-free edit set; then verification (below), which applies
   the edits back to front exactly once and re-lexes/re-parses once.
8. Only a verified output is returned; otherwise the whole edit set is
   discarded.

Edits are never applied to the CST. The result holds no reference to options,
lexer result or tree.

## Slot safety

A slot is the gap between two adjacent anchors (every original token except
whitespace/newline; comments, directives, unknown tokens and EOF are anchors).
Identity: (SourceIdentity, LeftOriginalIndex, RightOriginalIndex), BOF = -1.

Whole-file refusal (`foRefused`, output = input, 0 edits):

| Condition | Reason | Code |
|---|---|---|
| any lexer diagnostic | frLexicalError | FMT001 |
| any compiler directive (including `{$R}`) | frDirectiveBoundary | FMT002 |
| `{$I name}`, `{$INCLUDE name}`, `(*$I name*)` | frUnresolvedInclude | FMT003 |
| any parser diagnostic (PAR001 missing, PAR002 syntax, PAR003 unsupported, PAR004 limit) | frMissing / frSyntaxError / frUnsupportedConstruct / frResourceLimit | FMT004 |
| opaque / error / missing node anywhere | frOpaque / frSyntaxError / frMissing | FMT005 / FMT006 / FMT007 |
| root is not exactly one unit plus EOF | frUnknownContext | FMT008 |
| assignment roles not recognized | frUnsupportedConstruct | FMT009 |
| non-space/tab whitespace control character in a requested slot | frUnsupportedWhitespace | FMT010 |
| edit conflict | frEditConflict | FMT011 |
| verification failure (safety or rule target state) | frValidationFailure | FMT012 |
| assignment outside a complete routine body | frUnknownContext | FMT013 |
| anchor is not the role edge token of the assignment | frUnknownContext | FMT014 |
| options other than S0 / EOL preserve | frConfigPolicy | FMT015 |
| protected requested slot would need a change | the slot's reasons (below) | FMT016 |

Protected requested slots (never edited; reported as `TProtectedRange` with
closed boundaries and an info diagnostic; refuse the file with FMT016 only when
their text differs from the target):

| Slot property | Reason | Code |
|---|---|---|
| comment anchor | frCommentAnchor | FMT101 |
| contains a line break | frUnsupportedWhitespace | FMT102 |
| string literal or char code anchor | frUnsupportedConstruct | FMT103 |
| other unsupported anchor token | frUnsupportedConstruct | FMT104 |

Released code anchors: before `:=` the last token of the target (identifier,
reserved-word member name, `)`, `]`, `.)`, `^`); after `:=` the first token of
the value (identifier, numeric literal, `nil`, `not`, `(`, `+`, `-`, `@`).
Released slot content: empty or only U+0020/U+0009.

Options diagnostics (`dsError`, no exception): FMT201 missing required setting,
FMT202 value out of range, FMT203 inconsistent provenance, FMT204 compatibility
claim without evidence-backed native settings.

## Edits and verification

`NormalizeTextEdits` sorts by a total order over all fields, removes exact
duplicates and rejects different edits at one offset, overlap and touching
spans (closed boundaries). `VerifyAndApply` receives the snapshot, the original
lexer result/tree, the validated `AssignmentSpacing` and the edits. It does
**not** receive planner decisions. It checks, in order:

1. snapshot string equals the analysed source exactly and its SourceIdentity
   matches (hash plus exact comparison);
2. its own S0 analysis of the original: preconditions hold, requested slots,
   their release and their owners; `AsIs` admits no edit;
3. every edit: in bounds, canonical and separated, rule `S0.AssignmentSpacing`,
   only U+0020/U+0009, denotes adjacent anchors, neither anchor protected,
   matches a released requested slot (monotonic merge over original token
   indices, identical span), not a line-break slot, actually changes the slot;
4. one back-to-front application;
5. re-lex: identical LexicalSignatureV1 (full sequence, not a hash), every
   anchor at its mapped offset, every slot text identical except the edited
   ones which equal their NewText, identical mapped lexer diagnostics;
6. **rule target state:** every requested slot of the output has exactly the
   target text, computed in Verification from the option value alone (a
   separate function from the engine's planner);
7. re-parse: lossless serialization, identical mapped parser diagnostics, S0
   preconditions still hold, same routine owners, anchor correspondence and
   identical SyntaxFingerprintV1 per owner with requested slots.

Steps 3 and 6 together reject wrong text (tab, two spaces, other horizontal
whitespace), missing edits, removed edit sets, extra edits on unrequested
slots, edits for another option value and any edit under `AsIs`.

SyntaxFingerprintV1 events: version tag, node kind open/close in preorder,
`(TokenKind, exact lexeme)` of every non-trivia leaf, `Missing(ExpectedText)`.
Spans, indices, whitespace and comments are excluded (comments are covered by
the lexical signature and slot texts). The existing tree has no issue fact
table; opaque/error/missing kinds encode issue status.

Performance: the former per-edit linear search over all slot decisions and
over all owners (quadratic for many assignments) is replaced by one sort of
the requested slots by right anchor index and a monotonic merge with the
canonical edits; anchor correspondence uses binary search. No caches or global
state. `ThousandsOfAssignments` formats 5,000 assignments (10,000 edits) in one
routine; no timing assertion is made.

## Public API and ownership

- `FormatText` borrows Options; nil Options raises `EArgumentNilException`.
  The caller owns and frees the returned `TFormatResult` exactly once.
- `TFormatResult` and `TFormattingOptions` cannot be constructed directly
  (`Create` raises `EInvalidOpException`). All members are read-only;
  `GetEdit`/`GetDiagnostic`/`GetProtectedRange` return value copies and raise
  `EArgumentOutOfRangeException` for invalid indices.
- Result diagnostics: lexer, then parser, then FMT diagnostics.
- `foPartiallyChanged` exists in the enum but is never produced.
- `FormatTextWithEditTransform` is a verification test seam: it lets tests
  corrupt the planned edit set before normalization. It is not part of the
  canonical contract and not a configuration mechanism.
- `TVerificationInput` is an internal record of Formatting.Verification, not a
  14 contract type; it changed in the review fix (planner decisions and owner
  ordinals removed, `AssignmentSpacing` added).

## Tests

Project `tests/DelphiFormatter.Formatting.Tests` (DUnitX, Win64/Debug, 44
methods). Fixture `tests/Fixtures/FormatterAssignmentCorpus.pas` is compiled into
the runner (X is declared) and read as the E2E-01 input; it is never written.

| Test contract | Methods |
|---|---|
| T-S0 positive | SingleAssignmentBoth, MultipleAssignmentsVaryingSpacing, AlreadyFormattedIsUnchanged, AllAssignmentSpacingValues, TabsInReleasedSlotsAreReplaced, MultipleRoutinesAndNestedStatements, UnitWithoutAssignmentIsUnchanged, CommentsElsewhereArePreserved, EolStylesArePreserved, ProtectedSlotAlreadySatisfiedDoesNotBlock, AsIsPreservesSourceExactly, SuccessfulOutputSatisfiesEveryRequestedSlot |
| T-S0 negative / atomic | AssignmentLookalikesInStringsAndComments, ColonEqualsOutsideAssignmentStatement, CommentAdjacentToOperatorFreezesSlot, LiteralAdjacentToOperatorFreezesSlot, LineBreaksAroundOperatorArePreserved, UnsatisfiableProtectedSlotRefusesWholeFile, CompilerDirectivesAreRefused, UnresolvedIncludesAreRefused, IncludeDirectiveClassification, OpaqueOrIncompleteSyntaxIsRefused, MalformedSourceIsReturnedUnchanged, ControlWhitespaceIsNotRemoved |
| T-SLOT | SlotIdentityAndSpans, ConflictingEditsAreDetected, EditsAtProtectedBoundariesAreRefused |
| T-VERIFY | ManipulatedEditsAndStaleSnapshotsAreRejected, ForcedVerificationFailureRefuses, TargetVerificationRejectsManipulatedEdits, TargetVerificationDirect, LexicalSignatureV1Comparison, SyntaxFingerprintV1Comparison, EndToEndE2E01 |
| T-IDEM | SecondRunIsIdempotent, DeterministicAndReproducible, EndToEndE2E01 |
| T-OWN | ResultOutlivesInputsAndCopiesValues, RepeatedAllocationAndRelease |
| T-API | ApiMisuseRaises, InvalidOptionsAreDiagnosed, SourceIdentityVectors, ApplyTextEditsBackToFront |
| T-PERF | ThousandsOfAssignments |
| T-LOSS | OutputTreeIsLossless (plus the lossless check inside every verification) |

Review-fix coverage: the cases comment before/after `:=`, string literal and
char code after `:=`, original spaces at protected slots, line break before
and after `:=` (all four values), mixed safe/unsafe assignments in both orders
and already-satisfied protected slots are tested separately. Target
verification via the test seam: space→tab, space→two spaces, removed required
edit, edit replaced by other horizontal whitespace, extra unrequested but
syntactically harmless edit, all edits removed, correct set passes, `AsIs` with
an injected edit; every invalid case ends `foRefused`, output = input, 0 edits,
FMT012. The same cases are checked directly on `VerifyAndApply`, including
edits for another option value. Every helper call asserts that no result is
partial.

E2E-01 asserts the exact output, the four exact minimal edits (two zero-width
insertions, two replacements of two spaces, with original token indices),
unchanged LexicalSignatureV1 and SyntaxFingerprintV1, and zero edits on a second
run.

Mutation checks (manual, reverted before the final build): (1) releasing
comment-anchored slots in Safety made two tests fail and verification refused
independently ("Edit at a protected boundary"); (2) disabling the rule
target-state step in Verification made exactly `TargetVerificationRejectsManipulatedEdits`
and `TargetVerificationDirect` fail.

## Actual build and test evidence

Toolchain: **Delphi 12 Community Edition Update 1**, IDE/compiler under
`C:\Program Files (x86)\Embarcadero\Studio\23.0` (dcc64 29.0). **This is not
Delphi 12.3**; no 12.3 result is claimed.

`dcc64.exe` on the command line refuses with "This version of the product does
not support command line compiling" (exit 0, no artifact). Supported
alternative route used: the IDE's own batch build,
`bds.exe -pDelphi -ns -b DelphiFormatter.groupproj -obuild\s1-fix-group.log`,
which ran the IDE-hosted dcc64 for all six projects (Win64/Debug) and reported
success in 5.2 s, started 2026-11-03 19:49:32 UTC. New code compiles without
warnings or hints; the only hints in new files are two H2077 in the fixture
(assigned value never used, intentional input shape). Pre-existing Coverage
W1002/H2443/H2077 are unchanged.

| Artifact | Bytes | Modified UTC | SHA-256 |
|---|---:|---|---|
| DelphiFormatter.Lexer.Tests.exe | 4,667,904 | 19:49:37 | F19B134E6AD8F1ACB2FB822868DD8F122E2345D15C6D3581CCBE5557F72A5EE4 |
| DelphiFormatter.Parser.Tests.exe | 4,921,856 | 19:49:39 | 67C4C9E0B4F64F85465515E6E54B7F931222FBE9924456E673C5C3EE3B461B49 |
| DelphiFormatter.Coverage.exe | 2,340,864 | 19:49:39 | 3E4C34601E3708C8BB3AC0B288673AE702A790EC1978BF669FAF2B0906B11410 |
| DelphiFormatter.Coverage.Tests.exe | 5,121,536 | 19:49:40 | 82C1058823ED3186D1C0849FF56C8CD085839D8442F4C07E986A9C6C1718492B |
| DelphiFormatter.Formatting.Tests.exe | 4,988,928 | 19:49:41 | 73A44396C1F202218147307653BEECA01AF766AE1B8B275F4CF3F5E137439FA2 |

All executables and the four `Formatting.*` DCUs are newer than the build
start; no Pascal source or project file is newer than the build. Runners
executed from the repository root with `--exitbehavior:Continue`:

| Runner | Found | Passed | Failed | Errored | Ignored | Leaked | Exit |
|---|---:|---:|---:|---:|---:|---:|---:|
| Lexer | 40 | 40 | 0 | 0 | 0 | 0 | 0 |
| Parser | 120 | 120 | 0 | 0 | 0 | 0 | 0 |
| Coverage | 17 | 17 | 0 | 0 | 0 | 0 | 0 |
| Formatting | 44 | 44 | 0 | 0 | 0 | 0 | 0 |

Logs (ignored): `build/s1-fix-group.log`,
`build/s1-fix-{lexer,parser,coverage,formatting}-tests.log`.
`ReportMemoryLeaksOnShutdown` produced no leak report. The pinned M2.7 corpus,
manifest, hashes and analyzer are unchanged and were not re-run (no lexer or
parser source changed). Before the review fix, an independent IDE build by the
repository owner also ran 40/120/17/37 green.

## Limitations and deviations

- Exact Delphi 12.3, Release, Win32 and non-Windows platforms are unverified.
- Atomic S0 is conservative: one protected requested slot that would need a
  change (for example `S:='a';` with `Both`, or any assignment split over two
  lines with a non-`AsIs` value) refuses the whole file.
- Literal-anchored slots use `frUnsupportedConstruct`; line-break slots use
  `frUnsupportedWhitespace` (the contract enum has no dedicated literal/EOL
  members). FMT016 carries the slot reasons; control characters are
  distinguished by FMT010.
- Touching edit spans are a conflict (closed boundaries); slots of one source
  can never touch, so this is stricter than needed only for foreign edit sets.
- `TOptionProvenance.EvidenceIds` is a comma-separated string, avoiding a
  shared dynamic array in a value record.
- All unit-level code must be free of directives, opaque, error and missing
  nodes; one unsupported construct anywhere refuses the whole file. Nested
  routines, `with`, inline `var`, initialization sections and non-unit roots
  are therefore refused today.
- The verifier runs its own S0 analysis, so analysis cost is paid twice per
  call; the target-text mapping is intentionally duplicated (engine planner
  and verifier) to keep the check independent.
- Compatibility is reported as given by the options; S1 never claims RAD
  Studio compatibility.

Next bounded task (proposal only, requires separate commission): C2 or F1 per
`design/docs/spec/09_IMPLEMENTATION_PLAN.md`, or I1 after an explicit PR #10
disposition.
