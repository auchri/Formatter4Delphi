# S1 – Safe formatter foundation and assignment spacing

Status: implemented on branch `codex/s1-safe-formatter-foundation`, based on
`main` e954d6e50d8fe6fc0ff769f1c1adae210a1068c8 (A0 merged via PR #11). PR #10
(M2.8 directives, head 65000fca7ce3890541aa1f691a17666ef47cfb92) stays open and
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
| `Formatting.Verification` | `LexicalSignatureV1`, `SyntaxFingerprintV1`, `VerifyAndApply` |
| `Formatting.Engine` | `TFormatOutcome`, immutable `TFormatResult`, `FormatText` pipeline |

Dependencies: Core.TextEdits → Core.Spans; Syntax.Query → Syntax/Lexer;
Formatting.Options → Core; Safety → Core/Lexer/Syntax; Verification →
Safety/Parser/Lexer/Syntax/Core; Engine → all of the above. No cycles, no
VCL/FMX, no IO, no global mutable state.

## Pipeline

1. `SourceIdentity` = SHA-256 of the UTF-16 code units, low byte then high byte,
   no BOM, no surrogate repair, 64 uppercase hex digits.
2. Lex and parse once (`TDelphiLexer.Tokenize`, `TDelphiParser.Parse`).
3. Whole-file preconditions; any failure refuses the file.
4. Unit-level routines with proven roles; every `skAssignmentStatement` in
   their bodies; assignments elsewhere refuse the file.
5. For each assignment the slot before and after the operator is decided
   (positive release, everything not examined stays protected).
6. Desired text per released slot; an edit only when the text changes.
7. Canonical, conflict-free edit set; then verification (below) which applies
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
| verification failure | frValidationFailure | FMT012 |
| assignment outside a complete routine body | frUnknownContext | FMT013 |
| anchor is not the role edge token of the assignment | frUnknownContext | FMT014 |
| options other than S0 / EOL preserve | frConfigPolicy | FMT015 |

Requested slots that S0 freezes (no edit, reported as `TProtectedRange` with
closed boundaries and an info diagnostic; the file is still formatted):

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
spans (closed boundaries). `VerifyAndApply` then checks, in order:

1. snapshot string equals the analysed source exactly and its SourceIdentity
   matches (hash plus exact comparison);
2. every edit: in bounds, canonical and separated, rule `S0.AssignmentSpacing`,
   only U+0020/U+0009, denotes adjacent anchors, neither anchor protected,
   covered by a released decision with identical identity/span, not a
   line-break slot, actually changes the slot, inside a released owner;
3. one back-to-front application;
4. re-lex: identical LexicalSignatureV1 (full sequence, not a hash), every
   anchor at its mapped offset, every slot text identical except the edited
   ones which equal their NewText, identical mapped lexer diagnostics;
5. re-parse: lossless serialization, identical mapped parser diagnostics, S0
   preconditions still hold, same routine owners, anchor correspondence and
   identical SyntaxFingerprintV1 per released owner.

SyntaxFingerprintV1 events: version tag, node kind open/close in preorder,
`(TokenKind, exact lexeme)` of every non-trivia leaf, `Missing(ExpectedText)`.
Spans, indices, whitespace and comments are excluded (comments are covered by
the lexical signature and slot texts). The existing tree has no issue fact
table; opaque/error/missing kinds encode issue status.

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

## Tests

Project `tests/DelphiFormatter.Formatting.Tests` (DUnitX, Win64/Debug, 37
methods). Fixture `tests/Fixtures/FormatterAssignmentCorpus.pas` is compiled into
the runner (X is declared) and read as the E2E-01 input; it is never written.

| Test contract | Methods |
|---|---|
| T-S0 positive | SingleAssignmentBoth, MultipleAssignmentsVaryingSpacing, AlreadyFormattedIsUnchanged, AllAssignmentSpacingValues, TabsInReleasedSlotsAreReplaced, MultipleRoutinesAndNestedStatements, UnitWithoutAssignmentIsUnchanged, CommentsElsewhereArePreserved, EolStylesArePreserved |
| T-S0 negative | AssignmentLookalikesInStringsAndComments, ColonEqualsOutsideAssignmentStatement, CommentAdjacentToOperatorFreezesSlot, LiteralAdjacentToOperatorFreezesSlot, CompilerDirectivesAreRefused, UnresolvedIncludesAreRefused, IncludeDirectiveClassification, OpaqueOrIncompleteSyntaxIsRefused, MalformedSourceIsReturnedUnchanged, ControlWhitespaceIsNotRemoved, LineBreaksAroundOperatorArePreserved |
| T-SLOT | SlotIdentityAndSpans, ConflictingEditsAreDetected, EditsAtProtectedBoundariesAreRefused |
| T-VERIFY | ManipulatedEditsAndStaleSnapshotsAreRejected, ForcedVerificationFailureRefuses, LexicalSignatureV1Comparison, SyntaxFingerprintV1Comparison, EndToEndE2E01 |
| T-IDEM | SecondRunIsIdempotent, DeterministicAndReproducible, EndToEndE2E01 |
| T-OWN | ResultOutlivesInputsAndCopiesValues, RepeatedAllocationAndRelease |
| T-API | ApiMisuseRaises, InvalidOptionsAreDiagnosed, SourceIdentityVectors, ApplyTextEditsBackToFront |
| T-LOSS | OutputTreeIsLossless (plus the lossless check inside every verification) |

E2E-01 asserts the exact output, the four exact minimal edits (two zero-width
insertions, two replacements of two spaces, with original token indices),
unchanged LexicalSignatureV1 and SyntaxFingerprintV1, and zero edits on a second
run. Every helper call additionally asserts that no result is partial.

A manual mutation check (comment-anchored slots temporarily released in
Safety) made two tests fail; the verification layer independently refused the
edit with "Edit at a protected boundary". The mutation was reverted before the
final build.

## Actual build and test evidence

Toolchain: **Delphi 12 Community Edition Update 1**, IDE/compiler under
`C:\Program Files (x86)\Embarcadero\Studio\23.0` (dcc64 29.0). **This is not
Delphi 12.3**; no 12.3 result is claimed.

`dcc64.exe` on the command line refuses with "This version of the product does
not support command line compiling" (exit 0, no artifact). Supported
alternative route used: the IDE's own batch build,
`bds.exe -pDelphi -ns -b DelphiFormatter.groupproj -obuild\s1-bds-group.log`,
which ran the IDE-hosted dcc64 for all six projects (Win64/Debug) and reported
success in 5.9 s, started 2026-11-03 19:25:54 UTC. New code compiles without
warnings or hints; the only hints in new files are two H2077 in the fixture
(assigned value never used, intentional input shape). Pre-existing Coverage
W1002/H2443/H2077 are unchanged.

| Artifact | Bytes | Modified UTC | SHA-256 |
|---|---:|---|---|
| DelphiFormatter.Lexer.Tests.exe | 4,667,904 | 19:26:00 | 283C86F512B0D5D00A8039CCCE185C05D215DC06F10E3CED818A94047039789C |
| DelphiFormatter.Parser.Tests.exe | 4,921,856 | 19:26:02 | 215DC6D5528A0ACE49C22730427D4345B73521D8D97B30DF82539D8F89222768 |
| DelphiFormatter.Coverage.exe | 2,340,864 | 19:26:02 | 5E5AE8D208CD270E5FE294F8C7DA1E1B50B1FAA3A6FA3D94CB333252C30AC06C |
| DelphiFormatter.Coverage.Tests.exe | 5,121,536 | 19:26:04 | 5C863E2EA9C42FCAA9348A8EE365879E143154ECBE4DCD531A0386A4A580DACA |
| DelphiFormatter.Formatting.Tests.exe | 4,968,448 | 19:26:05 | 5BCC82812D92AC8EB6A3D896F07F77B46DA3F5EC2FC096DEFBACA92BC4984486 |

All executables and the new DCUs (`Core.TextEdits`, `Syntax.Query`, four
`Formatting.*`, fixture) are newer than the build start. Runners executed from
the repository root with `--exitbehavior:Continue`:

| Runner | Found | Passed | Failed | Errored | Ignored | Leaked | Exit |
|---|---:|---:|---:|---:|---:|---:|---:|
| Lexer | 40 | 40 | 0 | 0 | 0 | 0 | 0 |
| Parser | 120 | 120 | 0 | 0 | 0 | 0 | 0 |
| Coverage | 17 | 17 | 0 | 0 | 0 | 0 | 0 |
| Formatting | 37 | 37 | 0 | 0 | 0 | 0 | 0 |

Logs (ignored): `build/s1-bds-group.log`, `build/s1-{lexer,parser,coverage,formatting}-tests.log`.
`ReportMemoryLeaksOnShutdown` produced no leak report. The pinned M2.7 corpus,
manifest, hashes and analyzer are unchanged and were not re-run (no lexer or
parser source changed).

## Limitations and deviations

- Exact Delphi 12.3, Release, Win32 and non-Windows platforms are unverified.
- Literal-anchored slots use `frUnsupportedConstruct`; line-break slots use
  `frUnsupportedWhitespace` as freeze reason (the contract enum has no
  dedicated literal/EOL members). Control characters are distinguished by the
  file-level refusal FMT010.
- Touching edit spans are a conflict (closed boundaries); slots of one source
  can never touch, so this is stricter than needed only for foreign edit sets.
- `TOptionProvenance.EvidenceIds` is a comma-separated string, avoiding a
  shared dynamic array in a value record.
- All unit-level code must be free of directives, opaque, error and missing
  nodes; one unsupported construct anywhere refuses the whole file. Nested
  routines, `with`, inline `var`, initialization sections and non-unit roots
  are therefore refused today.
- Compatibility is reported as given by the options; S1 never claims RAD
  Studio compatibility.

Next bounded task (proposal only, requires separate commission): C2 or F1 per
`design/docs/spec/09_IMPLEMENTATION_PLAN.md`, or I1 after an explicit PR #10
disposition.
