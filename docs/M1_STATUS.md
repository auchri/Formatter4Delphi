# M1.2 status — 2026-10-25

M1.2 implements the regular lexer categories without changing the public API.
No CST, AST, formatter, config reader or CLI was added.

## Changed files

- `src/DelphiFormatter.Lexer/DelphiFormatter.Lexer.Scanner.pas`: specialized
  string, comment, directive, numeric/char-code and symbol scanners; source-wide
  UTF-16 validation.
- `tests/DelphiFormatter.Lexer.Tests/Tests.Lexer.Basics.pas`: updated baseline
  expectations and 16 new test methods (40 total), including deterministic fuzz.
- Test `.dpr` / `.dproj`: compile the language-syntax corpus as an ordinary unit.
- `tests/Fixtures/LexicalCorpus.pas`: generics, classes/methods, comments,
  directives, Unicode, classic/multiline strings, numbers and character codes.
- `README.md`, `LEXER_HANDOFF.md`, `LEXER_SPEC.md`, `TEST_PLAN.md`, `ROADMAP.md`, `DECISIONS.md`
  and this status: current coverage, compiler evidence and remaining limits.

## Supported syntax

Identifiers/BMP Unicode and escaped identifiers, reserved/contextual words,
all existing symbols, blanks and CR/LF/CRLF; classic strings with doubled
apostrophes; odd-delimiter multiline strings; line/XML-doc and both block
comment styles; both compiler-directive forms; decimal/hex/binary numbers,
fractions/exponents and digit separators; decimal/hex character codes.

All input remains lossless, including NUL and isolated surrogates. Adjacent
character codes remain separate tokens. No directive is evaluated. Malformed
constructs use LEX001..LEX005 or LEX007; LEX006 is no longer emitted.
See `LEXER_SPEC.md` for recovery boundaries and `DECISIONS.md` for syntax probes.

## Verification

Installed toolchain: Delphi 12 Community Edition Update 1,
version **29.0.51961.7529**, under
`C:\Program Files (x86)\Embarcadero\Studio\23.0`.
This is not Delphi 12.3. Its command-line compiler refuses compilation even
with exit code 0, so builds were performed through the RAD Studio IDE.

Win64/Debug tests: **40 found, 40 passed, 0 ignored, failed, errored or leaked**;
process exit code 0. Range and overflow checking are enabled in this configuration.
The suite includes 500 seeded malformed/random UTF-16 inputs, each tokenized twice
and checked for deterministic token kinds, exact spans, diagnostics and coverage.
A 100,000-character ordinary string and a 10,000-digit number exercise long input.
The realistic corpus is both compiler-checked and tokenized with mixed CR/LF/CRLF
endings, requiring all expected categories and no unknown tokens or diagnostics.

Final IDE **Project > Build All Projects** started at
**2026-10-25 18:17:30.016 UTC** and completed successfully without warnings.
Both projects were rebuilt; the executable above was then run again.

| Win64/Debug artifact | Bytes | Last write UTC |
| --- | ---: | --- |
| DelphiFormatter.Lexer.Tests.exe | 4,667,904 | 18:17:31.1621506 |
| DelphiFormatter.Lexer.bpl | 98,816 | 18:17:31.4099540 |
| DelphiFormatter.Lexer.dcp | 150,746 | 18:17:31.4104661 |

Test EXE SHA-256:
FF5CA2BF33D3E02BCDFE3FF400509B0EDE06E8DC67D0AF633DF4CE0305523BA1.
All three artifacts are newer than the recorded build start. Static validation
also checked project XML/source references and git diff whitespace.

## Limitations and next small task

- Exact Delphi 12.3 validation remains outstanding; Release/other targets were
  not executed. Repeat the Win64/Debug group build and 40-test suite on 12.3.
- Supplementary identifier letters are rejected by the installed compiler and
  preserved as unknown scalars with LEX005. Valid pairs inside strings/comments
  are accepted; isolated surrogates anywhere use LEX007.
- Multiline indentation/value rules, numeric magnitude/type semantics, parser
  syntax and conditional-compilation semantics are intentionally not evaluated.
  Malformed-number recovery preserves digit components rather than attempting
  to reproduce compiler parser recovery for every invalid source spelling.
- Corpus loading is test-only, explicit UTF-8, relative to the standard build
  output directory; run the executable from its generated location in the checkout.

Recommended next small task: validate this exact branch with Delphi 12.3 before
M2 CST work. M1.3 remains optional corpus expansion/stabilization; no later
milestone was started.
