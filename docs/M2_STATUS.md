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
