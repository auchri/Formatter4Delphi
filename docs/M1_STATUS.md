# M1.0 / M1.1 status — 2026-10-25

Implementation stops at M1.1. The review corrections were compiled through the
installed RAD Studio IDE and all **24/24 DUnitX tests passed** on Win64/Debug.
The installed version is Delphi 12 Community Edition Update 1, not Delphi 12.3;
validation with exactly the requested 12.3 toolchain remains outstanding.

## Files

- `DelphiFormatter.groupproj`: runtime package and Win64 DUnitX project.
- `src/DelphiFormatter.Core/DelphiFormatter.Core.Spans.pas`: validated UTF-16 spans.
- `src/DelphiFormatter.Core/DelphiFormatter.Core.Diagnostics.pas`: diagnostic values.
- `src/DelphiFormatter.Lexer/DelphiFormatter.Lexer.Tokens.pas`: token kinds, spans,
  retained source snapshot and read-only accessors.
- `src/DelphiFormatter.Lexer/DelphiFormatter.Lexer.Keywords.pas`: reserved words.
- `src/DelphiFormatter.Lexer/DelphiFormatter.Lexer.Scanner.pas`: baseline lexer.
- `src/DelphiFormatter.Lexer/DelphiFormatter.Lexer.dpk` / `.dproj`: RTL runtime package.
- `tests/DelphiFormatter.Lexer.Tests/DelphiFormatter.Lexer.Tests.dpr` / `.dproj`:
  console runner, Win64 Debug/Release and configurable DUnitX source path.
- `tests/DelphiFormatter.Lexer.Tests/Tests.Lexer.Basics.pas`: 24 test methods
  (18 baseline methods, with corrected `InvalidUTF16`, plus 6 regressions).
- `tests/Fixtures/Minimal.pas`: basic source fixture; a fixed CRLF equivalent
  is embedded in the test to avoid file I/O and checkout line-ending assumptions.
- `README.md`, `docs/LEXER_SPEC.md`, `docs/DECISIONS.md`, this file: build/API/status notes.

## Supported syntax

EOF, Delphi control blanks/spaces/tabs, CR/LF/CRLF, basic BMP Unicode identifiers,
escaped identifiers (`&Type`), case-insensitive reserved words, contextual words
as identifiers, single punctuation/operators and longest matches for `:=`, `<=`,
`>=`, `<>`, `..`, `(.`, `.)`. All offsets count UTF-16 code units.

Fallback consumes one code unit, or one valid surrogate pair (two code units),
and emits a diagnostic. It preserves all source, including NUL, isolated
surrogates and unfinished input. No file I/O or source normalization occurs;
token text is sliced only on request.

Review corrections:

- Valid UTF-16 pairs are kept together as length-2 `tkUnknown` spans with
  `LEX006` warnings. Isolated high/low surrogates use `LEX007` encoding errors;
  BMP non-identifier characters use `LEX005` source-character errors.
- Tests distinguish emoji, supplementary letters, scalar boundaries, isolated
  surrogates, BMP letters and BMP non-identifier characters. Added regressions
  cover EOF fallbacks, deterministic tokens/diagnostics, array-copy isolation,
  and invalid caller-supplied result spans.
- Result construction validates full token coverage, exactly one trailing EOF
  and diagnostic bounds before retaining source/arrays. Public API shapes and
  ownership remain unchanged. Empty token text avoids offset arithmetic.
- Project files now declare Base/Debug/Release inheritance recognized by the
  IDE, explicitly select Win64 and import Delphi targets once. The original
  group omitted `BorlandProject/Default.Personality` and loaded without projects;
  the group was regenerated in the IDE and successfully reopened with both.
- `DCC_DebugInformation` uses numeric values 1/0; the original boolean value
  caused compiler warning W1030 (invalid directive `true`). Char helper calls
  replace deprecated `TCharacter` calls, removing their W1000 warnings.
- The runner rejects an empty run instead of accepting a vacuous success.
  No TestInsight define/dependency is needed; local `TestInsightSettings.ini`
  is ignored. `.dpk`/`.groupproj` now use the declared Delphi CRLF policy.

## Verification

The installed `C:\Program Files (x86)\Embarcadero\Studio\23.0` includes
`dcc64.exe`, RTL and DUnitX. The IDE About dialog reports Delphi 12 Community
Edition, version **29.0.51961.7529**, installed **Update 1**. This is not evidence
of a Delphi 12.3 build. No toolchain upgrade was performed.

Earlier command-line attempts (historical, superseded by the IDE validation):

1. Direct `dcc64.exe -B tests\DelphiFormatter.Lexer.Tests\DelphiFormatter.Lexer.Tests.dpr`
   prints `This version of the product does not support command line compiling.`
   Its exit code is 0, but it produces no test executable.
2. Framework64 MSBuild on the group fails with internal `MSB0001`/FormatException.
3. Framework (32-bit) MSBuild reaches Embarcadero targets but cannot read registry
   information inside the sandbox. Repeating outside the sandbox with `BDS` set
   reaches the compiler and produces the same unsupported-compilation message,
   again without a test executable.

Actual review validation via the computer-use skill:

1. Opened RAD Studio, inspected About, loaded the corrected test project,
   selected Win64/Debug and built it through **Project > Build**.
2. Executed the newly generated test EXE: 24 tests found, 24 passed, 0 ignored,
   0 failed, 0 errored, 0 reported leaks; process exit code 0.
3. Added and built the RTL runtime package. Regenerated/saved the project group,
   closed it, reopened it and confirmed that both projects and Debug configuration
   load correctly. Fixed W1030 and performed **Build All Projects** again.
4. Final group rebuild after the target-import cleanup started
   **2026-10-25 17:58:34.092 UTC**. All artifacts below
   were created after that time. The resulting test EXE was executed again with
   **24/24 passed**, no ignored/failed/errored/leaked tests and exit code 0.

| Final Win64/Debug artifact | Bytes | Last write (UTC) |
| --- | ---: | --- |
| `build/Win64/Debug/DelphiFormatter.Lexer.Tests.exe` | 4,363,776 | 17:58:35.2377157 |
| `build/Win64/Debug/DelphiFormatter.Lexer.bpl` | 95,744 | 17:58:35.4495211 |
| `build/Win64/Debug/DelphiFormatter.Lexer.dcp` | 146,812 | 17:58:35.4500323 |

Test EXE SHA-256:
`EE2348AD903E54C64D62F2C4719EF7DD71BC0E4A92325BC439BC7249076FAFE9`.
The older `build/Win64/Base` executable was not used for these review results.

Static checks also validate project XML, source references, configuration keys,
single target imports, keyword-table size and test method declarations.
Release and platforms other than Win64 were not executed.

## Limitations and next small task

Numbers (including decimal digits), strings, comments, compiler directives and
character codes are deliberately incomplete. Their introducers/digits become
`tkUnknown` plus `LEX006` warning, and following content is scanned normally.
Consequently comment/string contents can currently appear as identifiers or
symbols. No unterminated string/comment diagnostics are claimed yet.
Supplementary Unicode identifiers require compiler validation; valid pairs are
preserved together without claiming identifier support. No parser, AST or
formatter exists.

No known local build/test blocker remains for M1.0/M1.1. For an unconditional
claim that the stated Delphi 12.3 acceptance gate is met, repeat the group build
and suite on Delphi 12.3. That is the next small validation task. M1.2 remains
outside this review; no new lexical scanners were added.
