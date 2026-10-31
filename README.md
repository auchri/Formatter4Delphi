# Formatter4Delphi

A Delphi 12.3-targeted, pure-RTL parsing toolkit and planned safe source formatter. The product goals are an exact lossless lexer, a structural Source-CST suitable for later AST lowering, and verified support for original RAD-Studio formatter profiles (*.config). AST implementation, a full compiler/preprocessor, LSP and IDE plugins are outside the current scope.

## Start here: target architecture

[design/README.md](design/README.md) is the architecture entry point. [Product requirements](design/docs/spec/01_PRODUCT_REQUIREMENTS.md) define the scope; [canonical API/data contracts](design/docs/spec/14_CONTRACTS.md) define target interfaces. Other design/spec chapters and ADRs elaborate these contracts. See the [small-PR implementation plan](design/docs/spec/09_IMPLEMENTATION_PLAN.md), [feature matrix](design/docs/spec/10_LANGUAGE_COVERAGE.md) and [traceability](design/docs/spec/15_TRACEABILITY.md).

These are target specifications, not implemented capabilities or authorization to begin implementation. **No implementation milestone is currently active.** Codex sessions also follow [AGENTS.md](AGENTS.md), [CODEX_START.md](CODEX_START.md) and [contribution rules](design/CONTRIBUTING_IMPLEMENTATION.md).

## Implemented baseline

- Lossless lexer for identifiers, literals/numerals, comments/compiler directives, symbols and trivia, with UTF-16 spans and diagnostics.
- Generic immutable Source-CST and M2.1–M2.6 grammar: expressions/postfix chains, assignments/blocks/if, basic declarations/routines, classical classes/records, ordinary properties and control flow. Unsupported syntax remains opaque; this is not complete Delphi grammar.
- M2.7 independent corpus/coverage analyzer and reproducible pinned corpus. It is an analysis console, not the product formatter CLI.

There is no production formatter, native config reader, product CLI, AST or include resolver yet. The open [PR #10](https://github.com/auchri/Formatter4Delphi/pull/10) contains the separate M2.8 directive pilot. A0/PR #11 neither incorporates nor merges it. Follow the [baseline strategy](design/docs/spec/12_CURRENT_CODE_AUDIT.md) before implementation.

## Implementation and historical evidence

The documents under docs/ describe actual implementation, existing tests and historical milestones/decisions; they do not override the A0 target architecture.

| Document | Purpose |
|---|---|
| [Lexer specification](docs/LEXER_SPEC.md) | implemented token/diagnostic contract |
| [CST specification](docs/CST_SPEC.md) | implemented parser API, ownership, grammar and recovery |
| [Architecture](docs/ARCHITECTURE.md) | implementation-era architecture and evolution |
| [Test plan](docs/TEST_PLAN.md) | existing test obligations and history |
| [M1 status](docs/M1_STATUS.md) / [M2 status](docs/M2_STATUS.md) | actual builds, test counts and limitations |
| [Corpus analysis](docs/PARSER_COVERAGE.md) | pinned corpus, decoding, metrics and analyzer |
| [Decisions](docs/DECISIONS.md) / [historical roadmap](docs/ROADMAP.md) | recorded decisions/milestones, not new commissions |
| [Lexer handoff](docs/LEXER_HANDOFF.md) | historical handoff |

Recorded local builds used Delphi 12 Community Edition Update 1, not exact 12.3. Consult the status documents for source baselines and counts; old results are not a fresh build of the current checkout.

## Build and test

Open DelphiFormatter.groupproj in Delphi 12.3, choose Win64/Debug and **Project > Build All Projects**. Core/lexer use only RTL; the console tests use bundled DUnitX and compile parser/syntax units directly. No IDE package installation is needed.

From a RAD Studio command prompt with rsvars.bat loaded:

~~~bat
msbuild DelphiFormatter.groupproj /t:Build /p:Config=Debug /p:Platform=Win64
build\Win64\Debug\DelphiFormatter.Lexer.Tests.exe
build\Win64\Debug\DelphiFormatter.Parser.Tests.exe
~~~

Run the lexer/parser runners from the repository root. Run the additional coverage test runner with an isolated writable working directory and its build subdirectory available, as it generates test reports; see the coverage/test documentation. Preserve original corpus inputs. DUnitXSource defaults to the installation's source/DUnitX directory and can be overridden as an MSBuild property. Artifacts go under build/.

The test runners return 0 on success, 1 for failed/empty runs and 2 for runner exceptions. Verify fresh executables and corpus DCUs: the CE command-line compiler can refuse compilation while returning exit code 0. Do not report an old executable rerun as a fresh build.

## Validate documentation

Requires PowerShell 7. Run from the repository root:

~~~powershell
pwsh -NoProfile -File scripts/ValidateDesignDocs.ps1
~~~

The [read-only validator](scripts/ValidateDesignDocs.ps1) derives its default repository path from the script location; an explicit -Repository path supports another checkout. It validates required documents, IDs, traceability, relative Markdown links and obvious competing fenced API definitions. Errors include file/line/cause and exit code 1; success returns 0. Warnings are separate. Text heuristics do not prove full semantic consistency, Delphi compilation or native formatter compatibility.

## References

- [Delphi syntax and lexical elements](https://docwiki.embarcadero.com/RADStudio/Athens/en/Fundamental_Syntactic_Elements_%28Delphi%29)
- [Delphi string types](https://docwiki.embarcadero.com/RADStudio/Athens/en/String_Types_%28Delphi%29)
- [Compiler directives](https://docwiki.embarcadero.com/RADStudio/Athens/en/Delphi_Compiler_Directives_%28List%29_Index)
- [Native formatter CLI](https://docwiki.embarcadero.com/RADStudio/Florence/en/Formatter.EXE,_the_Command_Line_Formatter)
- [DUnitX](https://github.com/VSoftTechnologies/DUnitX)

Documentation and fixtures are project-authored. Do not copy third-party parser implementations without a licensing review.
