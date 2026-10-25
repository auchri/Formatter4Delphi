# Delphi Formatter — implementation blueprint

**Target:** a Delphi 12.3+ source formatter written in Delphi, independent of the Delphi IDE, with behavioral compatibility with the original Delphi formatter's `.config` profiles. Add separate settings for editor behavior (tabs, tab stops, indentation, line endings, encoding, etc.) without changing `.config` semantics.

**Start here (token efficient):** `CODEX_START.md` → `AGENTS.md` → `docs/LEXER_HANDOFF.md`. Read the longer technical documents only as needed.

**Current coding scope: lexer only.** The CST and subsequent components are designed but must not be prematurely implemented. The lexer is the foundation for a standalone, lossless CST that can later be lowered into an AST.

## Documents

- `CODEX_START.md`: compact first-task instructions for Codex.
- `AGENTS.md`: persistent repository conventions and scope boundaries.
- `docs/LEXER_HANDOFF.md`: short, self-contained active lexer task for Codex.
- `docs/ARCHITECTURE.md`: layer boundaries, components, classes, APIs and ownership.
- `docs/LEXER_SPEC.md`: lexer contract, recognition order, Delphi edge cases and diagnostics.
- `docs/CST_SPEC.md`: later lossless CST / parser model and recovery strategy.
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

## M1.0 / M1.1 implementation

Open `DelphiFormatter.groupproj` in Delphi 12.3 and select Win64 / Debug.
The runtime package contains only RTL-based core/lexer units; the console
test project compiles these same units directly and uses bundled DUnitX.
No package installation into the IDE is needed.

From the RAD Studio command prompt (with `rsvars.bat` already loaded):

```bat
msbuild DelphiFormatter.groupproj /t:Build /p:Config=Debug /p:Platform=Win64
build\Win64\Debug\DelphiFormatter.Lexer.Tests.exe
```

`DUnitXSource` defaults to `$(BDS)\source\DUnitX` and can be overridden with
`/p:DUnitXSource=C:\path\to\DUnitX\Source`. Build artifacts go under `build/`.
The test runner returns 0 for success, 1 for failed tests, 2 for runner errors.
Check that a fresh executable was produced before running tests: the installed
compiler can report unsupported command-line compilation with exit code 0.

Implemented scope, validation results and limitations: [M1 status](docs/M1_STATUS.md).
