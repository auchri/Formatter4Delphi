> Current milestone: **M2.8 directive-aware safe pilot**. Whitelisted switches
> and independently complete conditional procedure groups at unit boundaries
> preserve surrounding CST structure; all branches remain protected/opaque.
> Includes, unknown directives and member/body/header directives remain conservative.
> See [scope and safety](docs/M2_8_DIRECTIVES.md), [measured comparison](reports/m2_8/comparison.md)
> and [actual validation](docs/M2_STATUS.md). Other grammar remains at M2.6.
> No preprocessor, branch selection or formatter. Exact Delphi 12.3 remains unvalidated.
# Delphi Formatter — implementation blueprint

**Target:** a Delphi 12.3+ source formatter written in Delphi, independent of the Delphi IDE, with behavioral compatibility with the original Delphi formatter's `.config` profiles. Add separate settings for editor behavior (tabs, tab stops, indentation, line endings, encoding, etc.) without changing `.config` semantics.

**Start here (token efficient):** `CODEX_START.md` → `AGENTS.md` → `docs/CST_SPEC.md`. Read the longer technical documents only as needed.

**Current milestone: M2.3 postfix expressions and assignment targets.** The lexer APIs remain stable. Expressions, basic statements, const/var sections and routine headers/bodies, member/index/dereference chains and assignment targets have hierarchical, lossless CSTs; unsupported regions stay opaque. AST, formatter and integrations remain future work. See [M2 status](docs/M2_STATUS.md).

## Documents

- `CODEX_START.md`: current entry instructions for Codex.
- `AGENTS.md`: persistent repository conventions and scope boundaries.
- `docs/LEXER_HANDOFF.md`: historical lexer handoff.
- `docs/ARCHITECTURE.md`: layer boundaries, components, classes, APIs and ownership.
- `docs/LEXER_SPEC.md`: lexer contract, recognition order, Delphi edge cases and diagnostics.
- `docs/CST_SPEC.md`: implemented lossless CST/parser API, grammar and recovery contract.
- `docs/TEST_PLAN.md`: concrete tests and acceptance criteria.
- `docs/ROADMAP.md`: phased work with exit gates.
- `docs/DECISIONS.md`: settled architectural decisions and intentionally open questions.

## Reference documentation

- Delphi syntax / identifiers / numbers: https://docwiki.embarcadero.com/RADStudio/Athens/en/Fundamental_Syntactic_Elements_(Delphi)
- Delphi multiline strings: https://docwiki.embarcadero.com/RADStudio/Athens/en/String_Types_(Delphi)
- Delphi compiler directives: https://docwiki.embarcadero.com/RADStudio/Athens/en/Delphi_Compiler_Directives_(List)_Index
- Delphi native formatter CLI: https://docwiki.embarcadero.com/RADStudio/Florence/en/Formatter.EXE,_the_Command_Line_Formatter
- DUnitX: https://github.com/VSoftTechnologies/DUnitX

Documentation and test fixtures are project-authored. Do not copy implementation code from third-party parsers without a licensing review.

## Build and test

Open `DelphiFormatter.groupproj` in Delphi 12.3 and select Win64 / Debug.
The runtime package contains only RTL-based core/lexer units; the console
test projects compile their core/lexer and syntax/parser units directly and use bundled DUnitX.
No package installation into the IDE is needed.
Use **Project > Build All Projects** (German IDE: **Projekt > Alle Projekte
erzeugen**), then run both `build\Win64\Debug\DelphiFormatter.Lexer.Tests.exe` and `build\Win64\Debug\DelphiFormatter.Parser.Tests.exe`.

From the RAD Studio command prompt (with `rsvars.bat` already loaded):

```bat
msbuild DelphiFormatter.groupproj /t:Build /p:Config=Debug /p:Platform=Win64
build\Win64\Debug\DelphiFormatter.Lexer.Tests.exe
build\Win64\Debug\DelphiFormatter.Parser.Tests.exe
```

`DUnitXSource` defaults to `$(BDS)\source\DUnitX` and can be overridden with
`/p:DUnitXSource=C:\path\to\DUnitX\Source`. Build artifacts go under `build/`.
The test runner returns 0 for success, 1 for failed/empty test runs, 2 for runner errors.
Check that a fresh executable was produced before running tests: the installed
compiler can report unsupported command-line compilation with exit code 0.

The lexer was built through the installed Delphi 12 Community
Edition Update 1 IDE on Win64/Debug: **40/40 DUnitX tests passed**. That is a real
IDE build and execution; a build with exactly Delphi 12.3 is still unverified.

Implemented scope, validation results and limitations: [M1 status](docs/M1_STATUS.md).



M2.3 has **68/68 passing parser tests** on the same Win64/Debug toolchain.
See [M2 status](docs/M2_STATUS.md) for CST coverage, limits and fresh artifacts.
