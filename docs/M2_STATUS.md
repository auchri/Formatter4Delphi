# M2.2 status — 2026-10-26

M2.2 is implemented on top of the merged M2.1 parser. Work stops at M2.2.

## Components and syntax

- `TDelphiParser` in `src/DelphiFormatter.Parser/DelphiFormatter.Parser.Delphi.pas`:
  section dispatch, const/var declarations, simple qualified type references,
  procedure/function headers, parameter groups/defaults, qualified method names,
  local const/var sections and routine bodies through the existing Block parser.
- `TSyntaxKind` in `src/DelphiFormatter.Syntax/DelphiFormatter.Syntax.Kinds.pas`:
  declaration/header/parameter/type/return/resource nodes. Existing kind ordinals
  are preserved; no unused body-wrapper kind or per-production classes.
- Parser DPR/DPROJ and `Tests.Parser.Basics.pas`: 16 additional tests, compiled
  `tests/Fixtures/DeclarationCorpus.pas` and its 32-byte empty resource fixture.
  `.gitignore` permits that single resource file. Existing lexer tests unchanged.
- AGENTS, CST_SPEC, ARCHITECTURE, ROADMAP, TEST_PLAN, DECISIONS, CODEX_START,
  README and this report describe the active scope and actual validation.

Lexer, Reader, Nodes and Tree public APIs and ownership are unchanged. Every
original leaf, including directives, trivia and EOF, retains its index/kind/span.
Serialization still traverses leaves after the original lexer has been freed.

See `CST_SPEC.md` for concrete examples and the distinction between structured,
partially opaque and fully opaque input. `DeclarationCorpus.pas` now provides a
real compiled and parsed unit with three interface declarations, three routine
implementations, typed/untyped constants, initialized/global/local variables,
parameter modifiers, a default parameter and a standalone resource directive.

## Actual build and tests

Toolchain: **Delphi 12 Community Edition Update 1**, IDE file version
**29.0.51961.7529**, installed at
`C:\Program Files (x86)\Embarcadero\Studio\23.0`.
This is **not Delphi 12.3**. Exact 12.3+ validation is still outstanding.
CE requires IDE builds; no successful command-line compilation is claimed.

Final **Project > Build All Projects / Projekt > Alle Projekte erzeugen**:
Win64 / Debug, started after **2026-10-26 07:08:30 UTC**. The IDE reported
**success, 0 errors, 0 warnings, 0 hints**, elapsed **2.4 seconds**, across the
lexer test runner, lexer package and parser test runner. The corpus is compiled
into the parser runner. An earlier corpus build correctly rejected a typed
constant as a parameter default (E2026); the final fixture uses the untyped
`Version` constant and compiles successfully. No parser semantic analysis was
added for this compiler-enforced rule.

Both freshly built EXEs were executed from the repository root:

```powershell
& ./build/Win64/Debug/DelphiFormatter.Parser.Tests.exe
& ./build/Win64/Debug/DelphiFormatter.Lexer.Tests.exe
```

- Parser: **48 found / 48 passed**, 0 ignored, leaked, failed or errored; exit 0.
- Lexer: **40 found / 40 passed**, 0 ignored, leaked, failed or errored; exit 0.
- Debug range/overflow checks and parser RTL shutdown leak reporting remain on.
  No unexpected leak dialog was observed. Logs are ignored local files
  `build/Win64/Debug/M2.2.Parser.Tests.log` and `M2.2.Lexer.Tests.log`.
- Assertions check hierarchy, spans, operator grouping, exact original leaf
  sequence, unique reachability and serialization after lexer disposal. Added
  recovery tests include class-method prefixes, variant records, procedural type
  aliases/parameter types, unsafe resource positions and following valid routines.
  Another 300 seeded malformed declaration inputs compare deterministic trees and
  diagnostics; 100 repeated lifetimes include malformed UTF-16. All M2.1 tests
  remain, with one obsolete opaque-section expectation updated for routine bodies.
- Freshness was checked against the build start and all parser/syntax/test/corpus
  Pascal sources. Project XML/reference and git whitespace checks also passed.

| Fresh artifact | Bytes | Last write UTC |
| --- | ---: | --- |
| DelphiFormatter.Parser.Tests.exe | 4771840 | 2026-10-26 07:08:44.2150598 |
| DelphiFormatter.Lexer.Tests.exe | 4667904 | 2026-10-26 07:08:42.9141438 |
| DelphiFormatter.Lexer.bpl | 98816 | 2026-10-26 07:08:43.1383260 |
| DelphiFormatter.Lexer.dcp | 150746 | 2026-10-26 07:08:43.1388344 |

Parser EXE SHA-256: `CD1500BE36AFD3558EE3EF5CBA2F93094AF533E4594DE661437B93F2B223A55E`

Lexer EXE SHA-256: `6CF84346F2351A6AB1D0FD5E43EA4371CC40C122F013E10D5A514B503C1B3A5F`

## Limitations and next task

All type sections remain opaque, including aliases. Complex type expressions,
classes/records, generics, anonymous methods, nested routines, routine modifiers,
advanced statements and member/index/dereference expressions are outside the
supported grammar. Recovery on malformed or ambiguous nesting can retain larger
opaque fragments; it is not compiler-equivalent. Name/type/default validity
remains the compiler's responsibility.

Only closed resource directives alone on their line at supported section
boundaries gain structure. Conditional/include/unknown directives retain the
complete-input fallback. No preprocessor, AST, formatter, configuration parser,
CLI, IDE integration or incremental parser has been added.

Risks remaining: exact Delphi 12.3, Release and other platforms are unvalidated;
recovery is bounded and conservative, not complete Delphi grammar coverage.
For M2.3, first repeat validation on exact 12.3, then consider a separately
scoped member/index-expression task with assignment/call regressions. No M2.3
implementation is included. Historical M2.1 evidence remains in Git history.
