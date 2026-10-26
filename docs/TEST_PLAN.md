# Test plan — DUnitX from day one

## M2.7 independent analyzer tests

`DelphiFormatter.Coverage.Tests` is a separate DUnitX Win64/Debug project.
Seventeen focused methods verify manually counted 33 code units and four trivia
units in a minimal unit, partial opacity, full directive fallback including
trailing CRLF, missing leaves, nested opaque overlap, error priority, mixed line
endings, malformed/supplementary UTF-16, empty denominators, BOMs/invalid bytes/
explicit CP1252, missing files, deterministic JSON/CSV escaping, weighted 33/99
aggregation (not averaging file percentages), invalid trees, repeated files,
resource-string context versus keyword-in-comment false positives and complete
original-token category runs including EOF, plus local reports without manifest
metadata and repeated writer calls producing identical JSON/CSV.
The source helper frees the parser's lexer before an independent token oracle
and leaf serialization. No timing assertions.

`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/TestCoverageCorpus.ps1`
checks an exact three-file selection over artificial size/directive strata.
`-CheckPinnedFiles` additionally reconstructs the selected external paths,
categories, sizes and hashes and verifies commits and internal fixture hashes.
Reports are checked against `tests/CoverageCorpus/coverage.schema.json` and
independently recomputed aggregate partitions with
`pwsh -File scripts/ValidateCoverageReport.ps1`. `TestCoverageCli.ps1` checks
single-file/directory modes, include/exclude selection, new output directories
and file/configuration failure exit codes. See `PARSER_COVERAGE.md` and
`M2_STATUS.md` for actual execution and toolchain limitations.

## Important

A trivial 'roundtrip is equal' test is necessary, but **not sufficient**: a broken lexer returning the entire source as `tkUnknown` would pass it. Assert precise kinds, spans and diagnostics. All lexer calls work on `string` input. Focused cases are embedded; the realistic corpus is loaded explicitly as UTF-8 by test code and also compiled into the runner.

## Common invariant assertion (`AssertTokenCoverage`)

For `Source` and `Tokens[0..N-1]`:

1. Exactly one trailing `tkEOF`, `Span=(Length(Source), 0)`.
2. For each non-EOF token: `Length > 0`, `StartOffset = PreviousToken.EndOffset`, `EndOffset <= Length(Source)`.
3. Last non-EOF `EndOffset = Length(Source)`; empty source has only EOF.
4. Concatenation of `Copy(Source, StartOffset+1, Length)` of non-EOF tokens equals Source code-unit-for-code-unit.
5. Every token category scan can terminate in bounded progress. Diagnostics offsets are in `[0..Length(Source)]` with valid lengths.

## Concrete lexical cases

| ID | Source (conceptual) | Key assertions |
| --- | --- | --- |
| L001 | empty string | Only EOF. |
| L002 | ` ` / TAB / multiple spaces | One or more `tkWhitespace`, exact span. |
| L003 | CRLF, CR, LF independently | Each kind `tkNewLine`, CRLF length 2. |
| L004 | `unit Foo;` | `unit` reserved, `Foo` identifier, `;` symbol. |
| L005 | `ReSuLt := A;` | Case retained; contextual/classification validated. |
| L006 | `virtual override read write` | Contextual words classified as identifiers. |
| L007 | `&Type` | Complete escaped identifier, span including `&`. |
| L008 | `A:=B;` | `:=` one symbol, no lost text. |
| L009 | `1..10` | Number `1`, symbol `..`, number `10`. |
| L010 | `1.25e-3 + 7E2` | Real/exponent recognized; `+` outside exponent separate. |
| L011 | `$FF`, `%1010`, `2_000_000` | Three numeric tokens, exact original text. |
| L012 | `1__2`, `$`, `1e+` | Preserve and issue appropriate diagnostics or tested lexical fallback. |
| L013 | `#13#10'Hi'` | Character-code and string token boundaries. |
| L014 | `'It''s Delphi'` | One string token, no premature termination. |
| L015 | `''` | Empty ordinary string. |
| L016 | Valid `'''` multiline literal with CRLF | One string token retains full content. |
| L017 | Valid `'''''` multiline literal | Odd-delimiter length recognized and retained. |
| L018 | Unclosed `'abc` | Token to EOF + string diagnostic, roundtrip. |
| L019 | Unterminated multiline literal | Token to EOF + diagnostic, roundtrip. |
| L020 | `// comment` + newline | Comment excludes newline; newline separate. |
| L021 | `{ comment }` | One comment token. |
| L022 | `(* comment *)` | One comment token. |
| L023 | `(* { nested } *)` | Cross-style nested comments handled after compiler validation. |
| L024 | `{$IFDEF DEBUG}` | Compiler directive token. |
| L025 | `(*$H+*)` | Compiler directive token. |
| L026 | `//$IFDEF DEBUG` | Normal comment, NOT compiler directive. |
| L027 | Unterminated `{comment` | Comment token + diagnostic. |
| L028 | Unterminated `{$IFDEF` | Directive token + diagnostic. |
| L029 | `// ' {` | String/comment markers inside comment are inert. |
| L030 | `'// { (*'` | Comment markers inside ordinary string are inert. |
| L031 | `A(.0.)` | Alternative brackets recognized as symbols. |
| L032 | `<= >= <> := ..` | Longest operators matched. |
| L033 | `Änderung_1` | Unicode identifier accepted (case retained). |
| L034 | Non-BMP text / isolated UTF-16 surrogate | No crash, no lost code units; classification based on verified rules. |
| L035 | NUL/unusual control char outside string | Preserve safely and classify/diagnose. |
| L036 | `/// <summary>` | Comment including XML-doc prefix. |
| L037 | Mixed line endings through comments/strings | Exact reconstruction and correct source spans. |
| L038 | `end.` + trailing whitespace / garbage | Entire source tokenized, no early stop. |
| L039 | Realistic small .pas file | Token kinds, spans, roundtrip. |
| L040 | Random input of up to several thousand code units | No infinite loops/exceptions, exact coverage. |

## DUnitX test organization

```text
tests/DelphiFormatter.Lexer.Tests/
  DelphiFormatter.Lexer.Tests.dpr
  Tests.Lexer.Basics.pas
  Tests.Lexer.Strings.pas
  Tests.Lexer.Comments.pas
  Tests.Lexer.Numbers.pas
  Tests.Lexer.Unicode.pas
  Tests.Lexer.Roundtrip.pas
```

Start with one test fixture unit if simpler, split as tests grow. Tests should not depend on the library internal scanning implementation; use public lexer result API.

M1.2 keeps one fixture with 40 test methods. Added cases cover quote runs
1..12, multiline delimiters 3/5/7/9 with all newline forms, exact string recovery,
comment/directive boundaries, valid/malformed numerals, numeric member access,
char-code boundaries/ranges, encoding errors inside constructs and the compiled
`LexicalCorpus.pas` fixture. `SeededMalformedInputs` uses an explicit 32-bit LCG
seed `$4D312E32` for 500 cases, including arbitrary UTF-16; each case is scanned
twice and compared for kinds, spans and diagnostic code/spans. Coverage checks
independently reconstruct every token slice. See `M1_STATUS.md` for actual runs.

## M2.1 CST test obligations

- Leaf-token sequence matches lexer sequence exactly (synthetic missing tokens excluded).
- Reconstruct from CST token leaves (NOT raw source passthrough).
- Tree precedence and grammar shape tests, including error nodes.
- No syntax token dropped in recovery; all token stream gaps accounted for.

## Compilation and verification

- Attempt build / DUnitX execution with a real Delphi 12.3 toolchain when available. Report exact commands and environment if run.
- If no Delphi compiler available, do code review/static sanity checks and report tests as **not run**, not passing.
- Never weaken a failing test just to make a build green; add a documented language-rule decision when behavior is disputed.

## Implemented parser suite (32 tests)

`tests/DelphiFormatter.Parser.Tests/` is an independent DUnitX console project
in `DelphiFormatter.groupproj`, using the same core/lexer units plus the five
new syntax/parser units. Debug enables range/overflow checks. The test runner
also enables RTL leak reporting.

Every parser helper frees the original lexer result before checking the tree.
Coverage independently re-lexes its source and compares every original leaf's
index, kind, offset and length, including EOF. Missing leaves must have length
zero, index -1 and expected spelling. Unique reachability, ordered children,
parent span unions, full root span and actual leaf serialization are asserted.

Focused tests check binary hierarchy, all 20 binary operators and equal-group
left association, mixed Delphi word-operator precedence, prefix/parenthesized
expressions, nested/empty calls, string/char-code components, assignments,
blocks/empty statements, nearest-if else binding, else after a block, invalid
semicolon-before-else recovery, minimal/dotted units and uses clauses. Missing
operands/closers/headers, malformed uses and statements check diagnostics and
continued structural parsing. Directive/include input and unknown declarations
must expose opaque nodes rather than fabricated grammar.

Seeded malformed token-sequence inputs are parsed twice in all three entry
modes, comparing structure and diagnostic codes/messages/spans. Seeded arbitrary
UTF-16 inputs exercise controls and isolated surrogates. Deep parentheses test
the nesting guard; long binary chains test shape and iterative serialization.
Repeated construction/destruction, independent trees from one lexer and lexical
diagnostic survival exercise ownership. Lexer tests remain intact.

Use the IDE Build All Projects with Win64/Debug, then execute both generated
EXEs in `build/Win64/Debug`. Verify timestamps before trusting results.
`M2_STATUS.md` records the actual compiler version, counts and fresh artifacts;
Delphi 12 Update 1 success is not an exact Delphi 12.3 validation claim.

PR #3 review regressions add long nested/unclosed angle lists, long comparison
chains with substantial trivia and a missing final operand, Boolean identifier
classification/casing within operator trees, and resource/include/conditional
directives in all entry modes. Long-input tests assert coverage and structure;
complexity follows the single-pass index rather than a flaky wall-time limit.

## M2.2 additions

The parser suite now has 48 tests. The original 32 remain, with the historical
opaque-unit-section expectation updated to expect a structured routine body.
New tests cover const/var sections, qualified types, initializers, modifiers,
defaults, empty/qualified routines, interface versus implementation hierarchy,
local declarations and nested supported statements. Recovery cases include
missing names/colons/types/separators/parameter closers/return types/body markers,
truncated routines and following valid routines. Opaque nested classes, forward
classes, variant records, procedural aliases and anonymous/procedural parameter
types must not produce fabricated global routines.

Resource directives are tested in both comment spellings at section boundaries;
inline resources and resources interrupting parameters/bodies force fallback.
Existing conditional/include and all-entry-mode directive tests remain.
All additions use the common exact-leaf/span/reconstruction helper after lexer
disposal. A further 300 seeded malformed declaration sequences compare trees
and diagnostics, and 100 declaration lifetimes include malformed UTF-16.

`DeclarationCorpus.pas` is compiled into the parser runner and read as UTF-8 for
CST checks. Run both EXEs from the repository root (the fixture path is explicit).
`DeclarationCorpus.res` is a checked-in 32-byte empty Windows resource header,
so its real standalone resource directive compiles without generated inputs.
See `M2_STATUS.md` for actual build/test evidence and toolchain limitations.

## M2.3 additions

The suite has 68 parser tests (20 new methods) and the unchanged 40 lexer tests.
New checks cover member hierarchy/names/trivia, single/multiple/nested/complex
indices, alternative and mixed bracket spellings, repeated dereferences, mixed
postfix order, unchanged unary/binary precedence, assignment designators,
invalid binary/call targets, parameterless member calls, if/else and routine
bodies, qualified generic fallback and directive fallback. Historical opaque
expectations for `A.B` / `A[0]` are replaced by structural tests.

Twelve malformed postfix forms test PAR001, missing leaves and recovery to the
next assignment. A chain of 2,048 mixed postfix operators verifies nesting order
without consuming parser recursion depth; an unfinished chain verifies recovery.
300 seeded malformed sequences are parsed twice in expression and statement
modes, comparing hierarchy and full diagnostic data. 200 valid and 200 malformed
UTF-16 lifetimes exercise disposal. All use the common coverage helper after
freeing the lexer. Enum ordinals are explicitly pinned.

`PostfixCorpus.pas` must appear in the runner DPR and DPROJ and produce a fresh
`PostfixCorpus.dcu`; add the unit through the IDE if an already loaded project
still uses its previous DPR buffer. In M2.4 its class/record types and all five routine bodies are structured;
array/pointer aliases and complex field types remain opaque. The fixture
contains ordinary and keyword/escaped member names, multi-index and alternative
brackets, `P^`, `PP^^`, method calls and assignments. It is compiled, not executed
with fabricated object/pointer values. Actual results and artifact freshness are
recorded only in `M2_STATUS.md`.

## M2.4 additions

Sixteen new test methods bring the parser suite to 84. Table cases cover empty
and multiple aggregates, mixed unsupported aliases, procedural signatures of
object, generic constraints/ancestors, multiple type sections around const/var/
routines, all visibility forms, grouped/qualified fields, record methods,
constructors/destructors and their implementation bodies. Directives assert
exact trailing opaque spans; properties assert a single complete opaque span
and following structured fields/methods, including default-property markers.

Recovery covers missing field/header/end punctuation, incomplete ancestors,
invalid fields, nested anonymous records, variant parts, nested types, class
member prefixes, helpers/interfaces/forward/class-of/generic types and safe
continuation. Provisorily parsed keywords in opaque type syntax must never
become fabricated methods. Historical opaque-section expectations are updated
only where M2.4 adds structure. Eight enum ordinals are appended; old pins remain.

400 seeded malformed type/member sequences are parsed twice, comparing shape
and complete diagnostic code/message/spans. 300 repeated malformed UTF-16
aggregate lifetimes exercise ownership. Every case invokes the existing exact
leaf sequence, unique reachability, span/zero-width and post-lexer-disposal
serialization checks. The 40 lexer tests are unchanged.

ClassRecordCorpus.pas is referenced by DPR/DPROJ, compiled into the runner,
and parsed as UTF-8 with counts for type wrappers, aggregates, fields, methods
and seven real implementation bodies. Require its fresh DCU as build evidence.
Actual execution results and compiler identity are recorded in M2_STATUS.md.

## M2.5 additions

Seven focused methods bring the suite to 94 tests. PropertySpecifiers checks
read-only/write-only, qualified/escaped names and trivia, storage clauses,
negative defaults, index/implements and different syntactic clause orders.
PropertyHierarchy asserts exact specifier spans, unary/literal nesting and both
semicolons of a default-array property. PropertyArrays checks grouped/const and
semicolon-separated parameters, complex opaque types and following properties
and methods. PropertyRedeclarations checks absent types without synthetic colons.
Historical complete-opaque expectations change only where M2.5 adds structure.

PropertyRecovery checks missing names/colons/types/accessors/brackets/semicolons,
unfinished default markers, unsupported generic/complex constants/call-shaped
accessors and procedural parameter types. Class properties and directives remain
protected. Following fields/methods/properties remain structured. Two parses
compare shape and diagnostics. PropertyStress checks 2,048 consecutive properties,
1,024 index parameter groups and 300 deterministic malformed property lifetimes
with isolated UTF-16 surrogates. All use post-lexer-disposal exact token order,
unique reachability, spans, missing leaves and leaf serialization assertions.

PropertyCorpus.pas is referenced in DPR/DPROJ, compiled into the runner and read
as UTF-8 to assert 13 properties, one index list and 26 specifiers. The corpus
includes real accessor implementations, storage/default/nodefault/index clauses,
a default array property and inherited redeclarations. Invalid recovery inputs
are embedded tests, never part of this compilable unit. Require a fresh DCU.
See M2_STATUS.md for actual execution evidence; CE Update 1 is not 12.3.

## M2.6 additions

Fifteen methods extend the parser fixture from 97 to 112 tests. ControlLoops,
ControlHierarchy, ControlCases, ControlExceptions and ControlElseBinding assert
actual nested expression/statement/list/branch/handler nodes, existing enum
ordinals, case label groups/ranges/signs, loop variants, qualified exception
types and nearest-if else ownership. ControlSeparatorsAndTrivia counts direct
semicolon leaves, empty statements, CRLF/comments and exact statement end spans.

ControlRecovery compares shape and complete diagnostic code/message/spans over
repeated malformed parses. ControlRoutineRecovery checks following routines
after incomplete try/case/repeat/while. ControlHandlerRecovery checks a valid
handler following missing variable/colon/type and unsupported generic headers.
ControlDirectives checks whole-input protection. ControlOpaqueFallback checks
with, inline for variables, raise-at and complex labels before valid branches.

ControlStress asserts 1,024 case branches and 2,048 consecutive while statements.
ControlDepth exercises 150 nested while/for/try/case constructs beyond the guard.
ControlMalformedLifetimes parses 300 deterministic malformed fragments with
isolated UTF-16 surrogates twice, comparing shape and diagnostic counts. Every
parse invokes Coverage after freeing the lexer: exact leaf indices/kinds/spans,
unique reachability, ordered spans, missing leaves, root extent and leaf-based
serialization. No input files are reformatted.

ControlFlowCorpus.pas is referenced by DPR/DPROJ, compiled into the runner and
parsed from UTF-8 with explicit node counts, no diagnostics or opaque regions.
It covers all new statements, nested loops/cases/try, qualified handlers with
and without variables, handler else, catch-all except and both raise forms.
Require its fresh DCU alongside all existing corpus DCUs. Actual build evidence
and version limitations: M2_STATUS.md. The 40 lexer tests are unchanged.

## M2.6 review: unsupported statement recovery

Eight tests extend the fixture from 112 to 120. Before any parser change, the
first seven were built against f5e5356: 113/119 passed, six failed. With/if stopped
before then; even simple inline for var stopped before :=. Exact opaque extent,
outer hierarchy and absence of leaked inner nodes exposed the defect despite
unchanged lossless reconstruction. See M2_STATUS.md for execution evidence.

OpaqueWithBodies and OpaqueInlineForBodies check exact opaque spans for single
calls, assignments, if/else, do-loop chains, begin/end, case/else, try/finally,
try/except, repeat and nested with. CheckOpaqueBody also verifies both direct
outer-block semicolon leaves, one following ContinueWork, no structured inner
nodes/missing leaves, and exactly the expected PAR003 warning.
OpaqueElseOwnership asserts actual outer if condition/opaque-then/call-else
children, two supported nested ifs, and nearest-inner else entirely opaque.
OpaqueKeywordTrivia covers comments, CRLF, strings, escaped names, qualified
keyword members and a qualified Procedure name inside a real routine.

OpaqueMalformedStatements covers missing do/end, incomplete branches, EOF and
following routines. OpaqueUnsupportedDirectives verifies complete-input fallback
for conditional/include/resource directives. OpaqueUnsupportedStress uses 256
opaque with statements with 32 nested if/else envelopes each, followed by three
supported calls. OpaqueUnsupportedDepthAndLifetimes tests 150 nested envelopes,
PAR004 without further recursion, and 200 repeated invalid-UTF-16 lifetimes.
There are no timing assertions. Repeated parses compare complete diagnostic
code/message/severity/spans and shape where applicable. Every parse uses the
existing post-lexer-free exact token/span/reachability/reconstruction checks.
