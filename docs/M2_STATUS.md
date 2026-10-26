# M2.3 status - 2026-10-26

M2.3 is implemented on merged M2.2 (`origin/main` at `274ada8`). Stop after M2.3.

## Components and syntax

- `TDelphiParser.Primary`: iterative member `.`, index `[]` / `(. .)`, call `()`
  and postfix dereference `^`, folded in source order. Mixed bracket spellings
  are accepted. Prefix and binary precedence remain unchanged.
- New `IsAssignableTarget`: iterative receiver-spine check. `Statement` accepts
  designator assignments and plausible parameterless member calls; binary targets
  and bare calls on the left of `:=` produce error statements. No semantic checks.
- `AmbiguousGenericCall`: qualified candidates reuse the existing linear index.
  `Boundary` / `OpaqueStatement`: index delimiters and missing-closer recovery.
- `TSyntaxKind`: three appended expression kinds, ordinals 31-33. Previous
  ordinals, lexer/Reader/Nodes/Tree APIs, leaf storage and ownership are unchanged.
- Tests: 20 new methods in `Tests.Parser.Basics.pas`; DPR/DPROJ compile
  `PostfixCorpus.pas`. Its type section stays opaque; five routine bodies are
  structured. AGENTS, CODEX_START and parser design/test/roadmap docs reflect M2.3.

See `CST_SPEC.md` for grammar and `TEST_PLAN.md` for the test matrix.

## Actual build and tests

Toolchain: **Delphi 12 Community Edition Update 1**, IDE version
**29.0.51961.7529**, installed at
`C:\Program Files (x86)\Embarcadero\Studio\23.0`.
This is **not Delphi 12.3**. Exact 12.3+ validation remains open.
CE requires IDE builds; no successful command-line compilation is claimed.

Final **Project > Build All Projects / Projekt > Alle Projekte erzeugen**,
Win64/Debug, started after **2026-10-26 07:42:08 UTC**. IDE reported success,
0 errors/warnings/hints, elapsed 2.4 seconds, for lexer tests, lexer package and
parser tests. The corpus produced a fresh `PostfixCorpus.dcu` and is compiled
into the parser runner, rather than only read as parser input.

An initially loaded IDE DPR buffer omitted the corpus although parser tests
were green. Artifact inspection caught the missing DCU. Adding the unit through
the IDE corrected the loaded project; the final build includes it.
IDE-generated deployment boilerplate was removed afterwards; all DCC property
values were compared and are identical to those used for the build.

CE Update 1 rejected `Customer.Property` with E2029. The compiled fixture uses
`Customer.&Property`. The parser accepts qualified keyword names per the official
reference and requested examples; exact 12.3 behavior remains open. Both paired
and mixed alternative index brackets compiled successfully. See `DECISIONS.md`.

Executed from the repository root after the final build:

```powershell
& ./build/Win64/Debug/DelphiFormatter.Parser.Tests.exe
& ./build/Win64/Debug/DelphiFormatter.Lexer.Tests.exe
```

- Parser: **68 found / 68 passed**, 0 ignored/leaked/failed/errored, exit 0.
- Lexer: **40 found / 40 passed**, 0 ignored/leaked/failed/errored, exit 0.
- Debug range/overflow checks and RTL shutdown leak reporting enabled.
  No unexpected leak dialog observed; no separate heap profiler run claimed.
- Tests assert hierarchy, exact token order/spans, unique reachability, missing
  leaves and leaf serialization after freeing the lexer. Added stress cases:
  2,048 mixed postfix operators, malformed chains, 300 seeded token sequences
  parsed twice in two modes, and 400 repeated valid/malformed lifetimes.
  Existing precedence, if/else, declarations, generics and directive tests pass.
- Ignored local logs: `build/Win64/Debug/M2.3.Parser.Tests.log` and
  `M2.3.Lexer.Tests.log`. Project XML/reference and git whitespace checks pass.
- All listed artifacts are newer than build start; parser EXE is newer than all
  Pascal sources under `src/` and `tests/`.

| Fresh artifact under build/Win64/Debug | Bytes | Last write UTC |
| --- | ---: | --- |
| DelphiFormatter.Parser.Tests.exe | 4794368 | 2026-10-26 07:42:14.406649 |
| DelphiFormatter.Lexer.Tests.exe | 4667904 | 2026-10-26 07:42:13.075292 |
| DelphiFormatter.Lexer.bpl | 98816 | 2026-10-26 07:42:13.316544 |
| DelphiFormatter.Lexer.dcp | 150746 | 2026-10-26 07:42:13.317961 |
| ParserTests/PostfixCorpus.dcu | 5705 | 2026-10-26 07:42:14.345360 |

DelphiFormatter.Parser.Tests.exe SHA-256: `0CE6EA402B48C6D186C1D1A68B630E8F005B248D3709C3C4DF645F7246AF0778`

DelphiFormatter.Lexer.Tests.exe SHA-256: `52D2FC7FFFC06E15CE9CDA25E216A10895E6B5A0AFF9A375E0DF534C319AEC5D`

## Limitations and next small task

No full generics, class/record or complex type declarations, new statement kinds,
semantics, directive evaluation, AST, formatter, configuration, CLI, IDE integration
or incremental parsing. Generic ambiguities and unsafe directives remain opaque.
Recovery is bounded/conservative and may preserve larger unsupported fragments.
Qualified unescaped keyword acceptance differs from the available older compiler.
Release and other platforms have not been validated.

Recommended next small task: run this suite/corpus on exact Delphi 12.3+,
including qualified keyword member names, then agree a separately scoped M2.4.
No M2.4 implementation is included. Historical M2.2 evidence remains in Git history.
