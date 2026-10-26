# M2.6 status - 2026-10-26

M2.6 is implemented on `codex/m2.6-control-flow`: control-flow statements,
120/120 parser and 40/40 lexer tests passing on Delphi 12 CE Update 1,
Win64/Debug. Exact 12.3 remains unvalidated. Stop after M2.6.
See the M2.6 section below for scope, recovery limits and fresh build evidence.

## Historical M2.5 status

M2.5 is implemented on origin/main at f297942, branch
`codex/m2.5-properties`. Stop after M2.5. The M2.4 evidence below is historical.

## Implementation and supported syntax

- TDelphiParser.PropertyDeclaration, PropertyIndexParameters, PropertySpecifier,
  PropertySpecifierStart, PropertyType, PropertyName and PropertyFragment;
  integrated through AggregateDeclaration. OpaqueTypeFragment retains the
  complete class-property member/default marker fallback.
- Three appended Syntax.Kinds ordinals 42-44: skPropertyDeclaration,
  skPropertyIndexParameters, skPropertySpecifier. All prior ordinals preserved.
  No lexer, Reader, node/tree ownership or public parser API changes.
- Ordinary/read-only/write-only properties, qualified/escaped names and types,
  read/write/stored/index/default/nodefault and simple qualified implements lists.
  Accessors are names, never call expressions. Signed constants use unary nodes;
  complex constant values are covered by opaque children.
- Array parameters use skParameterDeclaration groups, including grouped names,
  semicolon separators and const; complex types remain opaque. The trailing
  `; default;` belongs to the array property and differs from `default value`.
- Typeless inherited redeclarations have neither fabricated type nor colon.
  Explicit visibility contains properties just like fields/methods. No semantic
  accessor/type/interface/storage-order verification is performed.
- Missing punctuation/names/types/accessors emit diagnostics and zero-width
  leaves. Safe following member boundaries survive, including a field directly
  after a missing accessor. Delimiter/angle scans and raw type-name lookahead
  advance monotonically; no suffix rescans or extra token arrays.
- Changed production units: Parser.Delphi and Syntax.Kinds. Tests.Parser.Basics,
  parser DPR/DPROJ and new tests/Fixtures/PropertyCorpus.pas provide verification.
  AGENTS/CODEX_START and architecture/CST/roadmap/test/decision/status docs updated.

## Actual build and execution evidence

Toolchain: **Delphi 12 Community Edition Update 1**, IDE file version
**29.0.51961.7529**, installed under
`C:\Program Files (x86)\Embarcadero\Studio\23.0`. This is **not Delphi 12.3**.
No exact 12.3 language deviation or validation is claimed.

Final IDE Project > Alle Projekte erzeugen (Build All Projects), Win64/Debug,
started after **2026-10-26 09:27:13 UTC**. Success in 2.5 seconds, no compiler
errors/warnings/hints shown. Rebuilt both test projects and lexer package.
PropertyCorpus is compiled into the parser runner and produced a fresh DCU.
It was added through project management so the loaded DPR included the corpus.
The test editor was closed before the final rebuild to avoid stale buffers.
IDE-generated deployment metadata was removed afterwards; DCC build properties
are unchanged. Both project XML files remain valid.

Executed from repository root after that build:

```powershell
& ./build/Win64/Debug/DelphiFormatter.Parser.Tests.exe
& ./build/Win64/Debug/DelphiFormatter.Lexer.Tests.exe
```

- Parser: **94 found / 94 passed**, 0 ignored/leaked/failed/errored, exit 0.
- Lexer: **40 found / 40 passed**, 0 ignored/leaked/failed/errored, exit 0.
- Debug range/overflow checks and RTL shutdown leak reporting remain enabled.
  No unexpected leak dialog observed; no separate heap profiler run claimed.
- Seven new focused test methods, 2,048 consecutive properties, 1,024 index
  parameter groups and 300 deterministic malformed UTF-16 allocation/free
  lifetimes. Full leaf order/kind/span, unique reachability, hierarchy, property
  and specifier boundaries, missing leaves and post-lexer-disposal reconstruction.
  Existing lexer/parser suites remain passing. Historical opaque expectations
  changed only for the new supported property grammar.
- PropertyCorpus assertions: 13 properties, one property index list, 26 specifiers,
  no diagnostics. The real unit contains valid accessors, storage/index/default
  variants and inherited redeclarations. Invalid recovery inputs are separate
  embedded tests. No corpus object methods are executed on fabricated values.
- Ignored logs: build/Win64/Debug/M2.5.Parser.Tests.log and M2.5.Lexer.Tests.log.
  Parser EXE is newer than every Pascal source under src/tests. All listed
  artifacts are newer than the final build start. Git whitespace check passes.

| Artifact under build/Win64/Debug | Bytes | Last write UTC |
| --- | ---: | --- |
| DelphiFormatter.Parser.Tests.exe | 4859904 | 2026-10-26 09:27:44 |
| DelphiFormatter.Lexer.Tests.exe | 4667904 | 2026-10-26 09:27:42 |
| DelphiFormatter.Lexer.bpl | 98816 | 2026-10-26 09:27:42 |
| DelphiFormatter.Lexer.dcp | 150746 | 2026-10-26 09:27:42 |
| ParserTests/PropertyCorpus.dcu | 5977 | 2026-10-26 09:27:43 |

Parser EXE SHA-256: A4343FA10B259897EF9046593B5BC02059A48439BC81DE6C8E5EA3FB1F730762

Lexer EXE SHA-256: 639BD2E049FE65B533CFAFCD7B2F59792EFDC71A2A0D88B972DAF6447497D9B9

## Limitations and next small task

Class properties and unsafe anonymous/class-of/procedural property types may
remain complete opaque members. Generic types, unsupported parameter types and
complex constants retain opaque subregions; no full type grammar. Ambiguous
unbalanced syntax may preserve a larger region. Directive-dependent input keeps
the existing complete-input fallback. Interfaces/helpers, nested types, variant
parts, new statements, preprocessing, AST, semantic analysis, formatter, config,
CLI/IDE integration and incremental parsing remain outside M2.5.

Locally ready for review/merge subject to these documented limits and review;
no automatic merge. Exact Delphi 12.3+, Release and other platforms are untested.
Next small task: run the same suites and compiled corpora on exact Delphi 12.3+.
Any further grammar milestone requires separate authorization.

---

# M2.4 status - 2026-10-26

M2.4 is implemented on merged M2.3, origin/main at c52fa5f, on
`codex/m2.4-class-record`. Stop after M2.4.

## Implementation and supported syntax

- UnitSection dispatches TypeSection/TypeDeclaration: multiple individual type
  wrappers, multiple sections and recovery after opaque aliases.
- AggregateDeclaration shares class/record fields and methods. VisibilityStart
  recognizes private/protected/public/published/automated and strict private/
  protected. Initial members are direct aggregate children; explicit visibility
  sections own their members. AncestorList contains simple/dotted type names.
- FieldDeclaration groups names and reuses TypeReference; complex types/suffixes
  remain opaque. MethodDeclaration reuses factored RoutineHeader, Parameters and
  ReturnType nodes without expecting a body. Common method directives are one
  trailing opaque child retaining all semicolons.
- Constructors/destructors share the existing routine header/body machinery for
  simple qualified implementations. DeclarationStart/Boundary/Block include
  their recovery boundaries; no new statement grammar was implemented.
- OpaqueTypeFragment tracks blocks, brackets/parentheses and angles, excluding
  forward/class-of/class-member and of-object spellings from block nesting.
  Nested type sections and variant tails stay opaque through the body boundary.
  Properties are complete opaque members, including optional default/nodefault
  markers. Unsupported internal keywords cannot become fabricated methods.
- Eight appended Syntax.Kinds values, ordinals 34–41: TypeSection,
  TypeDeclaration, ClassDeclaration, RecordDeclaration, VisibilitySection,
  FieldDeclaration, MethodDeclaration, AncestorList (all with sk prefix).
  Lexer, Reader, Nodes, Tree and public parser APIs/ownership are unchanged.
- Changed code: Parser.Delphi, Syntax.Kinds, Tests.Parser.Basics, parser DPR/DPROJ,
  new tests/Fixtures/ClassRecordCorpus.pas; milestone/design/test documentation.

## Actual build and execution evidence

The original M2.4 evidence below is retained; the PR #6 review validation at the
end of this document supersedes its test count, artifact timestamps and hashes.

Toolchain: **Delphi 12 Community Edition Update 1**, IDE version
**29.0.51961.7529**, C:\Program Files (x86)\Embarcadero\Studio\23.0.
This is **not Delphi 12.3**; exact 12.3+ validation remains open.

Final IDE **Project > Build All Projects / Alle Projekte erzeugen**, Win64/Debug,
started after **2026-10-26 08:17:40 UTC**. IDE reported success, elapsed 2.5 s,
with no errors/warnings/hints shown. Lexer test project, lexer package and parser
project were rebuilt. The new corpus is compiled into the parser runner and
produced a fresh ClassRecordCorpus.dcu, not merely parsed as an input file.
The corpus was added through IDE project management because its loaded DPR
buffer initially omitted the disk change. Generated deployment metadata was
removed afterwards; all DCC property values compare equal to the built project.
IDE XML layout/reference normalization remains in the project diff.

Executed from the repository root after the final build:

```powershell
& ./build/Win64/Debug/DelphiFormatter.Parser.Tests.exe
& ./build/Win64/Debug/DelphiFormatter.Lexer.Tests.exe
```

- Parser: **84 found / 84 passed**, 0 ignored/leaked/failed/errored, exit 0.
- Lexer: **40 found / 40 passed**, 0 ignored/leaked/failed/errored, exit 0.
- Debug range/overflow checks and RTL shutdown leak reporting enabled.
  No unexpected leak dialog observed; no separate heap profiler run claimed.
- Sixteen new test methods use exact original token order/kinds/spans, unique
  reachability, hierarchical kinds, ordered span unions, missing leaves and
  leaf reconstruction after freeing the lexer. 400 seeded malformed type/member
  sequences compare trees and diagnostic code/message/spans across two parses;
  300 malformed UTF-16 allocation/free lifetimes are added. All existing
  precedence/postfix/assignment/routine/directive/generic recovery tests pass.
- ClassRecordCorpus tests assert five type declarations, one class/two records,
  five field groups, seven method headers and seven implementation bodies.
- Ignored logs: build/Win64/Debug/M2.4.Parser.Tests.log and M2.4.Lexer.Tests.log.
  Project XML and git whitespace checks pass. All listed artifacts are newer
  than build start; parser EXE is newer than every Pascal source in src/tests.

| Artifact under build/Win64/Debug | Bytes | Last write UTC |
| --- | ---: | --- |
| DelphiFormatter.Parser.Tests.exe | 4826624 | 2026-10-26 08:17:47 |
| DelphiFormatter.Lexer.Tests.exe | 4667904 | 2026-10-26 08:17:45 |
| DelphiFormatter.Lexer.bpl | 98816 | 2026-10-26 08:17:45 |
| DelphiFormatter.Lexer.dcp | 150746 | 2026-10-26 08:17:45 |
| ParserTests/ClassRecordCorpus.dcu | 5901 | 2026-10-26 08:17:46 |

Parser EXE SHA-256: BA536D89464C71EE526CF17808AEFDACD99D8E42EED09B7AE270F9D58395C661

Lexer EXE SHA-256: 6A007831038CCAA4DA3C20A7E84C2E4D1F8C2A8874B08745A71A6CB1E7DD78A0

## Limitations and next small task

Aliases/enums/arrays/sets/pointers/procedural types, generic declarations and
ancestors, forward/class-of types, helpers/interfaces, nested types, variant
parts, class members and operators remain opaque. Properties have boundaries
only. Method directives are preserved, not semantically classified. Malformed
unbalanced syntax can retain larger opaque regions; a missing aggregate end
before a routine is ambiguous, so the routine may remain within that aggregate
until a safe unit/type boundary. No full type/property grammar, new statements,
preprocessor, AST, formatter, config reader, CLI, IDE integration or incremental
parsing. Release and other platforms are untested.

Next small task: validate the suite and corpora on exact Delphi 12.3+.
A later property-grammar milestone needs separate authorization. Historical
M2.1–M2.3 implementation/build evidence remains in Git history.

## PR #6 review: linear lookahead (2026-10-26)

Only Parser.Delphi, Tests.Parser.Basics and this status document changed.
FieldStart now advances a local raw-token cursor through identifier/comma pairs
to the colon, including escaped identifiers. TypeDeclaration's generic-ancestor
preflight similarly advances through raw tokens, retaining the existing stops
at `)`, `;`, `end`, EOF and the opaque decision at `<`. Token-kind/length checks
prevent comment/string contents or escaped keyword names from acting as syntax.
The shared private SkipRawTrivia uses TTokenReader.IsTrivia; compiler directives
stay significant. Neither scan changes Reader.Position or consumes any token.

Each cursor advances monotonically; the trivia helper scans only the next gap,
never restarts from the reader position. Each examined token is read a bounded
number of times: O(n) time and O(1) auxiliary storage per lookahead, without
token arrays/caches or field-name text copies. Ancestor keyword comparison only
extracts a bounded three-code-unit candidate. Existing callers of FieldStart
also benefit; no broader parser complexity guarantee or grammar change is made.
Lexer/Reader public APIs, CST ownership and SyntaxKind ordinals are unchanged.

Three additional tests:

- LongFieldLookahead: 2,048 names, plain and heavily commented/whitespace forms,
  escaped names, one field node, exact field span/text, identifier/comma/colon
  counts, following method and no diagnostics.
- LongAncestorLookahead: 2,048 qualified names plus escaped `&end`, comments
  containing fake delimiters, and a variant with a final nested generic ancestor.
  Checks structured ancestors versus opaque RHS, following record, diagnostics
  and deterministic shape. The unsupported variant has no fabricated class.
- TypeLookaheadRecovery: missing colon/name/closer, EOF inside ancestors, nested
  generics, all preflight barriers, quoted fake delimiters, and conditional or
  standalone resource directives in both fields/ancestors. Checks subsequent
  record recovery or complete-input directive fallback and deterministic shape
  plus full diagnostic code/message/severity/span data.

All cases use the existing exact-token-order/span, unique-reachability and leaf
serialization helper after freeing the lexer. No fixed timing thresholds.

Actual validation: **Delphi 12 CE Update 1**, IDE **29.0.51961.7529**, Win64/Debug;
**not Delphi 12.3**. IDE Build All Projects started after **08:41:12 UTC** on
2026-10-26, rebuilt both test projects and the lexer package, and reported
success in 2.4 seconds with no compiler errors/warnings/hints shown.

Executed both fresh EXEs from the repository root: **87/87 parser**, **40/40
lexer**, both exit 0; 0 ignored/leaked/failed/errored. Range/overflow checks and
RTL shutdown leak reporting remain enabled; no unexpected leak dialog observed,
no separate heap profiler claimed. Ignored logs are
`build/Win64/Debug/M2.4.Lookahead.Parser.Tests.log` and
`M2.4.Lookahead.Lexer.Tests.log`. Whitespace checks pass; no project files changed.
The parser EXE is newer than every Pascal source in src/tests.

| Fresh artifact under build/Win64/Debug | Bytes | Last write UTC |
| --- | ---: | --- |
| DelphiFormatter.Parser.Tests.exe | 4835328 | 2026-10-26 08:41:23.0511473 |
| DelphiFormatter.Lexer.Tests.exe | 4667904 | 2026-10-26 08:41:21.7107632 |
| DelphiFormatter.Lexer.bpl | 98816 | 2026-10-26 08:41:21.9351664 |
| DelphiFormatter.Lexer.dcp | 150746 | 2026-10-26 08:41:21.9366962 |
| ParserTests/ClassRecordCorpus.dcu | 5901 | 2026-10-26 08:41:22.9814227 |
| ParserTests/DeclarationCorpus.dcu | 1983 | 2026-10-26 08:41:22.8376559 |
| ParserTests/PostfixCorpus.dcu | 5705 | 2026-10-26 08:41:22.9800726 |

Parser EXE SHA-256: 4615B453CFF8AAF458A556428E838C91CBF107F3C674D6ABCD680481A346E2E1

Lexer EXE SHA-256: 223F034532B146D19B58C6BE692511641A2ADE92F937B8066553A9C58E0E6CEB

Remaining limits are unchanged: exact Delphi 12.3+, Release and other platforms
remain unvalidated; unsupported/unbalanced syntax keeps conservative opaque
recovery. These changes address the two reviewed lookaheads only. No M2.5 work.

## PR #7 review fix: property recovery at field boundaries (2026-10-26)

The reported bug was reproduced before changing production code: the new
PropertyFieldBoundaryRecovery test failed with zero field declarations for
`property Name` followed by `FCount: Integer; procedure Save;`. The original
parser suite plus the other two new tests passed (96/97 overall, exit 1).
The missing-colon fallback consumed FCount as a property type and opaque
recovery then consumed the field's colon/type/semicolon.

Only PropertyDeclaration, PropertyFragment and PropertySpecifier change:

- PropertyDeclaration checks FieldStart before its missing-colon type fallback,
  after an explicit colon with a missing type, and before specifier dispatch.
  Thus a contextual field name such as Stored cannot become a property clause.
  Existing Expect(';') inserts a zero-width missing semicolon before pending
  trivia without consuming the following field.
- PropertyFragment stops at a clear field start at balanced delimiter depth.
  It avoids repeated FieldStart scans after commas in an opaque name list;
  nested parameter/type fragments retain their existing delimiter protection.
- PropertySpecifier rechecks FieldStart after a constant's unary sign, so a
  missing signed default value cannot consume a following field name.

PropertyType, FieldStart, MemberBoundary and Reader remain unchanged. No new
APIs/kinds/grammar. In particular, no unconditional field check is added inside
parameter type parsing: malformed array headers keep their existing recovery.
Lookahead does not change Reader.Position; the linear FieldStart is unchanged.

Three new DUnitX methods: PropertyFieldBoundaryRecovery runs 120 combinations
of incomplete headers, completed/missing accessors, default/opaque suffixes and
missing implements values, with plain/grouped/contextual fields and spaces,
LF, CR or CRLF plus comments. It asserts separate ordered member nodes, exact
property/field spans, the missing semicolon's spelling/zero-width anchor and
complete deterministic diagnostic data across two parses. The other methods
check recovery to a following property (missing accessor and semicolon), and
unchanged valid redeclaration/typed/array hierarchies without diagnostics.
Every parse uses the existing token-order/span/ownership/leaf reconstruction
checks after lexer disposal; repeated allocation/free is exercised throughout.

Final validation: **Delphi 12 CE Update 1**, IDE **29.0.51961.7529**, **not 12.3**.
IDE Project > Alle Projekte erzeugen, Win64/Debug, started after
**2026-10-26 09:48:12 UTC**, succeeded in 2.4 seconds with no compiler
errors/warnings/hints shown. Both runners and lexer package were rebuilt.
Executed both fresh EXEs from repository root: **97/97 parser**, **40/40 lexer**,
both exit 0, zero ignored/leaked/failed/errored. Debug range/overflow checks and
RTL shutdown leak reporting remain enabled; no unexpected leak dialog observed.
No separate heap profiler run claimed. All existing compiled corpus tests pass.

| Fresh artifact under build/Win64/Debug | Bytes | Last write UTC |
| --- | ---: | --- |
| DelphiFormatter.Parser.Tests.exe | 4869632 | 2026-10-26 09:48:34 |
| DelphiFormatter.Lexer.Tests.exe | 4667904 | 2026-10-26 09:48:33 |
| DelphiFormatter.Lexer.bpl | 98816 | 2026-10-26 09:48:33 |
| DelphiFormatter.Lexer.dcp | 150746 | 2026-10-26 09:48:33 |
| ParserTests/DeclarationCorpus.dcu | 1983 | 2026-10-26 09:48:34 |
| ParserTests/PostfixCorpus.dcu | 5705 | 2026-10-26 09:48:34 |
| ParserTests/ClassRecordCorpus.dcu | 5901 | 2026-10-26 09:48:34 |
| ParserTests/PropertyCorpus.dcu | 5977 | 2026-10-26 09:48:34 |

Parser EXE SHA-256: 0D076CC557BA39657B1A4E877347AC0E302F300359574196FCE92CDCCBF0E459

Lexer EXE SHA-256: 2CBDBE1168EA36D4A81A82DC9AB3A808F84FDF7FDED0061B566826CA12E7C97B

Parser EXE is newer than every Pascal source in src/tests. Git whitespace
checks pass. Ignored logs: M2.5.Review.Before.log,
M2.5.Review.Parser.Tests.log and M2.5.Review.Lexer.Tests.log under build/Win64/Debug.
Existing limitations remain: ambiguous unbalanced syntax can preserve larger
opaque regions; exact Delphi 12.3+, Release and other platforms are unvalidated.
Stop after this review fix; no automatic merge or subsequent milestone.

## M2.6 control-flow statements — 2026-10-26

Branch codex/m2.6-control-flow starts at current origin/main 00a7263, including
merged M2.5. Work stops after M2.6; no automatic merge or further grammar.

Changed core: TDelphiParser.Statement, Boundary, Block and OpaqueStatement;
new private ControlStatement, CaseStatement, CaseLabel, TryStatement,
ExceptionHandler, StatementList, ListEnd, HardStatementEnd and StatementBody.
Expression/Precedence, lexer/Reader/tree APIs and arena ownership are unchanged.
Syntax.Kinds appends eleven ordinals 45-55 after existing ordinal 44.
No new production-specific classes are introduced.

Supported: classic for/to/downto, for-in, while, repeat/until, case with multiple
simple/signed/qualified labels and ranges, case else, try/finally, catch-all
try/except, on handlers with optional variable and qualified TypeReference,
exception else, raise with/without simple Expression. Bodies use Statement;
repeat/try/else regions use iterative StatementList. Lists own semicolons;
case/handler separators belong to their enclosing statement. Recursive if
consumes its nearest unseparated else before case/exception section dispatch.
Block keeps its established hierarchy and orphaned-semicolon/else diagnostic.

Recovery adds zero-width missing leaves and deterministic diagnostics, leaves
enclosing control terminators untouched and protects hard following routines
and unit termination even in unfinished opaque nesting. Complex labels/header
suffixes stay opaque; inline for variables and raise-at remain opaque. Nesting
keeps the existing 128-entry Statement/Expression guard. Missing ends can be
ambiguous; available ends may bind to the inner construct. No semantic checks,
new type grammar, preprocessing, with/goto/assembler, AST or formatter.

Fifteen new DUnitX methods cover hierarchy, operator/list/semicolon ownership,
else binding, malformed punctuation/bodies/ends, following routines/handlers,
opaque/directive policy, 1,024 case alternatives, 2,048 sequential while loops,
150-deep control nesting, 300 deterministic malformed UTF-16 parse/free cycles
and the compiled corpus. Every Parse runs exact token-order/kind/span,
reachability, missing-leaf and reconstruction checks after freeing the lexer.
One historical unsupported-while expectation now asserts structured loops.
ControlFlowCorpus.pas is referenced by DPR/DPROJ and compiled into the runner;
its parser test asserts all new kinds, hierarchy via the shared focused tests,
zero diagnostics and zero opaque nodes. All earlier compiled corpora still pass.

Final validation: **Delphi 12 Community Edition Update 1**, IDE/compiler files
**29.0.51961.7529**, **not Delphi 12.3**. IDE Project > Alle Projekte erzeugen
(Build All Projects), **Win64/Debug**, after **2026-10-26 10:27:44 UTC**,
succeeded in **2.4 seconds** with no compiler errors/warnings/hints shown.
An initial corpus build warned about using loop variables after loop completion
and unused overwritten totals; the corpus was corrected and rebuilt cleanly.

Executed both fresh EXEs from the repository root with --exitbehavior:Continue:
**112/112 parser**, **40/40 lexer**, both exit **0**, zero ignored/leaked/failed/
errored tests. RTL ReportMemoryLeaksOnShutdown remains enabled, as do existing
Debug range/overflow checks. No unexpected RTL leak dialog was observed; no
separate heap-profiler result is claimed. Parser EXE is newer than every Pascal
source under src/tests (latest source 10:23:54 UTC). Fresh artifacts:

| Under build/Win64/Debug | Bytes | Last write UTC |
| --- | ---: | --- |
| DelphiFormatter.Parser.Tests.exe | 4899328 | 2026-10-26 10:27:55.509 |
| DelphiFormatter.Lexer.Tests.exe | 4667904 | 2026-10-26 10:27:54.159 |
| DelphiFormatter.Lexer.bpl | 98816 | 2026-10-26 10:27:54.377 |
| DelphiFormatter.Lexer.dcp | 150745 | 2026-10-26 10:27:54.378 |
| ParserTests/DeclarationCorpus.dcu | 1983 | 2026-10-26 10:27:55.288 |
| ParserTests/PostfixCorpus.dcu | 5705 | 2026-10-26 10:27:55.445 |
| ParserTests/ClassRecordCorpus.dcu | 5901 | 2026-10-26 10:27:55.447 |
| ParserTests/PropertyCorpus.dcu | 5977 | 2026-10-26 10:27:55.447 |
| ParserTests/ControlFlowCorpus.dcu | 3013 | 2026-10-26 10:27:55.451 |

Parser EXE SHA-256: 21AF31455A07EE02F04E6600ED50E488394B59FBF41B9E7C49CCD594CAAECC09

Lexer EXE SHA-256: 3AF7857E6ADB0DA1D88640B415CD51282083A6C00457156867740DB1D15E97EC

Ignored execution logs: build/Win64/Debug/M2.6.Parser.Tests.log and
M2.6.Lexer.Tests.log. Git whitespace validation passes. Exact Delphi 12.3+,
Release and other platforms remain unvalidated. Recommended next small task:
validate all suites/corpora on exact Delphi 12.3+ before another authorized
narrow grammar milestone. Stop implementation here.

## PR #8 review fix: unsupported statement recovery — 2026-10-26

The defect was reproduced before changing the parser at f5e5356. The first seven
new regression methods were compiled with the unchanged parser; the fresh
4,911,104-byte runner (12:26:12 UTC) reported **113/119 passed, six failed,
zero errored/leaked, exit 1**. All 112 previous tests passed. Exact-span failures:

- with Customer do if Active then Save else Reset stopped at
  with Customer do if Active, before then.
- for var I := 0 to 10 do Process(I) stopped at for var I, before :=.
- Inner/outer else, malformed envelope, trivia and stress assertions also failed.

The common fragment scanner OpaqueStatement stops at expression Boundary
(including then, else and :=). Its delimiter counter cannot bind if/else and
should not be changed globally because expressions, generic ambiguity and
malformed suffixes also use it. OpaqueStatement, Boundary, HardStatementEnd,
StatementList, StatementBody and IfStatement remain unchanged by this fix.

Only Statement and ControlStatement routing changes in production, plus the
new private OpaqueUnsupportedStatement. It recognizes envelopes for with and
inline for var, emits one opaque node with original leaves, and leaves the
outer semicolon untouched. SkipOne binds one optional else per skipped if;
do-prefixes return after one complete body. Compound begin/case/try/repeat
nesting is scanned iteratively. Returning through a with/for prefix leaves a
further else for the supported enclosing IfStatement. Recursive envelopes share
the existing 128-depth budget; PAR004 preserves a larger fragment at the limit.
All scanning is monotone, without Reader rollback, full token-array copying or
repeated suffix scans. Qualified keyword members, comments and strings cannot
change nesting; a broken trailing dot cannot hide a safe separator. Hard
following routine/unit/EOF boundaries and directive fallback are retained.

Eight new methods (112 -> 120) assert exact opaque extents, actual outer
condition/then/else hierarchy, parent-owned semicolons, no leaked inner nodes,
exact expected PAR003 warnings, malformed/EOF/following-routine recovery,
qualified keywords, all compound body forms and compiler directives. Stress:
256 consecutive opaque with statements, each with 32 nested if/else envelopes,
then three supported calls. Also 150-deep guard recovery and 200 repeated
invalid-UTF-16 parse/free lifetimes. Repeated parses compare complete diagnostic
code/message/severity/spans. Every Parse runs existing post-lexer-disposal exact
leaf order/kind/span, unique reachability, missing-leaf and reconstruction checks.

Final IDE **Build All Projects**, **Win64/Debug**, started after
**2026-10-26 12:36:20 UTC**, succeeded in **2.5 seconds**, with no compiler
errors/warnings/hints shown. Toolchain remains **Delphi 12 Community Edition
Update 1, 29.0.51961.7529**, **not Delphi 12.3**. Both fresh runners were executed
from the repository root with --exitbehavior:Continue: **120/120 parser** and
**40/40 lexer**, both exit **0**, zero ignored/failed/errored/leaked tests.
All compiled corpora, including ControlFlowCorpus.pas, were rebuilt and their
parser assertions passed. Existing Debug range/overflow checks and RTL shutdown
leak reporting remain enabled; no unexpected leak dialog observed. No separate
heap profiler or timing benchmark is claimed.

| Fresh artifact under build/Win64/Debug | Bytes | Last write UTC |
| --- | ---: | --- |
| DelphiFormatter.Parser.Tests.exe | 4921856 | 2026-10-26 12:36:29.308 |
| DelphiFormatter.Lexer.Tests.exe | 4667904 | 2026-10-26 12:36:27.927 |
| DelphiFormatter.Lexer.bpl | 98816 | 2026-10-26 12:36:28.183 |
| DelphiFormatter.Lexer.dcp | 150746 | 2026-10-26 12:36:28.184 |
| ParserTests/DeclarationCorpus.dcu | 1983 | 2026-10-26 12:36:29.061 |
| ParserTests/PostfixCorpus.dcu | 5705 | 2026-10-26 12:36:29.225 |
| ParserTests/ClassRecordCorpus.dcu | 5901 | 2026-10-26 12:36:29.228 |
| ParserTests/PropertyCorpus.dcu | 5977 | 2026-10-26 12:36:29.229 |
| ParserTests/ControlFlowCorpus.dcu | 3013 | 2026-10-26 12:36:29.232 |

DelphiFormatter.Parser.Tests.exe SHA-256: C28086FA44DA6CCE719BBCFDA94322BEC584C00DC72EB3D61BB9B41F98FB7205

DelphiFormatter.Lexer.Tests.exe SHA-256: 20F6E33F9E2A1A2368B2C10171AA523990078937A57496DBEC970139BB005182

Parser runner is newer than every Pascal source under src/tests; latest source: 2026-10-26 12:36:07.428 UTC.

Ignored logs: build/Win64/Debug/M2.6.Recovery.Before.log,
M2.6.Recovery.Parser.Tests.log and M2.6.Recovery.Lexer.Tests.log.
Git whitespace checks pass. No public lexer/Reader/CST/SyntaxKind APIs changed;
no corpus or project files changed. Missing/unbalanced delimiters and the depth
limit may conservatively retain a larger opaque region; this is not a full
with/inline-variable grammar. Exact Delphi 12.3+, Release and other platforms
remain unvalidated. Review assessment: this reported blocker is resolved with
compiled regressions; ready for human review subject to the existing version
validation gap. Keep PR #8 open, do not merge automatically, and stop here.
