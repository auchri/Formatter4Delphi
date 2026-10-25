# M1.0 / M1.1 status — 2026-10-25

Implementation stops at M1.1. Build/test acceptance remains unverified.

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
- `tests/DelphiFormatter.Lexer.Tests/Tests.Lexer.Basics.pas`: 18 test methods.
- `tests/Fixtures/Minimal.pas`: basic source fixture; a fixed CRLF equivalent
  is embedded in the test to avoid file I/O and checkout line-ending assumptions.
- `README.md`, `docs/LEXER_SPEC.md`, `docs/DECISIONS.md`, this file: build/API/status notes.

## Supported syntax

EOF, Delphi control blanks/spaces/tabs, CR/LF/CRLF, basic BMP Unicode identifiers,
escaped identifiers (`&Type`), case-insensitive reserved words, contextual words
as identifiers, single punctuation/operators and longest matches for `:=`, `<=`,
`>=`, `<>`, `..`, `(.`, `.)`. All offsets count UTF-16 code units.

Fallback consumes one code unit and emits a diagnostic. It preserves all source,
including NUL, isolated surrogates and unfinished input. No file I/O or source
normalization occurs; token text is sliced only on request.

## Verification

The installed `C:\Program Files (x86)\Embarcadero\Studio\23.0` includes
`dcc64.exe`, RTL and DUnitX. Actual compiler version/12.3 compatibility could
not be confirmed by compilation.

Attempts:

1. Direct `dcc64.exe -B tests\DelphiFormatter.Lexer.Tests\DelphiFormatter.Lexer.Tests.dpr`
   prints `This version of the product does not support command line compiling.`
   Its exit code is 0, but it produces no test executable.
2. Framework64 MSBuild on the group fails with internal `MSB0001`/FormatException.
3. Framework (32-bit) MSBuild reaches Embarcadero targets but cannot read registry
   information inside the sandbox. Repeating outside the sandbox with `BDS` set
   reaches the compiler and produces the same unsupported-compilation message,
   again without a test executable.

Therefore **no Delphi compilation or DUnitX execution is confirmed**. The tests
are authored, not reported as passing. Static checks validate XML, referenced
source paths, test declarations and keyword-table size; installed DUnitX/RTL
declarations were consulted for the used APIs. These checks are not compilation.

## Limitations and next small task

Numbers (including decimal digits), strings, comments, compiler directives and
character codes are deliberately incomplete. Their introducers/digits become
`tkUnknown` plus `LEX006` warning, and following content is scanned normally.
Consequently comment/string contents can currently appear as identifiers or
symbols. No unterminated string/comment diagnostics are claimed yet.
Supplementary Unicode identifiers require compiler validation; surrogate code
units are preserved with `LEX005`. No parser, AST or formatter exists.

First compile and run the existing Win64 suite in a usable Delphi 12.3 IDE or
command-line installation. The recommended next implementation task, only when
authorized, is the M1.2 ordinary-string scanner with doubled-quote and
unterminated-string regression tests, then the remaining M1.2 scanners.
