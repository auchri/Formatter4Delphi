# M2.5 status - 2026-10-26

M2.5 is implemented on origin/main at f297942, branch
`codex/m2.5-properties`. Stop after M2.5. The M2.4 evidence below is historical.

## Implementation and supported syntax

- TDelphiParser.PropertyDeclaration, PropertyIndexParameters, PropertySpecifier,
  PropertySpecifierStart, PropertyType, PropertyName and PropertyFragment;
  integrated through AggregateDeclaration. OpaqueTypeFragment retains the
  complete class-property member/default marker fallback.
- Three appended Syntax.Kinds ordinals 42�44: skPropertyDeclaration,
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
