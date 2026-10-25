# Historical lexer handoff

M1.0, M1.1 and M1.2 are implemented. Read `M1_STATUS.md` for current syntax
coverage, actual build/test evidence and remaining Delphi 12.3 validation.
The baseline instructions below are historical; do not reimplement them or
use them to limit the active parser milestone. M2.1 is now implemented; read `CST_SPEC.md` and `M2_STATUS.md` for current scope.

## Historical M1.0 + M1.1 handoff

Target is Delphi **12.3+**, pure RTL Delphi code. The long-term project is a native-`.config`-compatible Delphi formatter, built on a reusable lossless CST; optional AST/linter/LSP later. **For this task implement only the first lexer and DUnitX tests.** For fuller rationale/details see `ARCHITECTURE.md`, `LEXER_SPEC.md`, and `TEST_PLAN.md` on demand.

## Build now

1. `src/DelphiFormatter.Core/DelphiFormatter.Core.Spans.pas`: `TSourceSpan` with `StartOffset`, `Length`, computed `EndOffset`; offsets zero-based, half-open `[start,end)` in UTF-16 code units.
2. `src/DelphiFormatter.Core/DelphiFormatter.Core.Diagnostics.pas`: `TDiagnostic` with stable code, message, severity and span.
3. `src/DelphiFormatter.Lexer/DelphiFormatter.Lexer.Tokens.pas`: `TTokenKind` (`tkIdentifier`, `tkReservedWord`, `tkNumber`, `tkStringLiteral`, `tkCharCode`, `tkSymbol`, `tkCompilerDirective`, `tkComment`, `tkWhitespace`, `tkNewLine`, `tkUnknown`, `tkEOF`), `TDelphiToken` (Kind+Span), `TDelphiLexResult` (retained original `string`, token array and diagnostic array, read-only accessors `TokenCount`, `GetToken`, `TokenText`, `DiagnosticCount`, `GetDiagnostic`). No per-token source-string copies.
4. `src/DelphiFormatter.Lexer/DelphiFormatter.Lexer.Scanner.pas`: `TDelphiLexer.Tokenize(Source)` -> owned `TDelphiLexResult`; bounded lookahead and forward-only UTF-16 indexing. M1.1 handles identifiers, real reserved words, horizontal whitespace, CR/LF/CRLF, simple/multi-char symbols, EOF. Unimplemented string/comment/number variants must remain safely represented without dropping source; defer complete scanners to M1.2.
5. Optional `src/DelphiFormatter.Lexer/DelphiFormatter.Lexer.Keywords.pas`: centralized case-insensitive keyword recognition. Context-sensitive directives (`virtual`, `override`, `read`, `write`, etc.) must remain identifier tokens. Avoid duplicating keyword tables in several units.
6. DUnitX test runner and focused lexer tests under `tests/DelphiFormatter.Lexer.Tests/`, and a minimal Delphi project setup fitting any existing repository.

## Absolute invariants

- Every source UTF-16 code unit appears **exactly once** in one non-EOF token, adjacent spans with positive length and no overlap; EOF token at `(Length(Source),0)` exactly once.
- Roundtrip reconstructs original source from **token slices** using `Copy(Source, Offset+1, Length)` (not simply returning `Source`).
- No infinite loops: each scan step advances or returns EOF.
- Invalid code produces diagnostics and `tkUnknown` or other preserved tokens, not dropped code.
- Token classification and spans require assertions; a roundtrip-only test is insufficient.
- Do not normalize whitespace, CRLF, case, Unicode or comments; no source file I/O/encoding in lexer.

## First test matrix

- Empty string -> only EOF.
- Whitespace spaces/tabs -> exact spans.
- CRLF/CR/LF -> separate newline tokens (CRLF length 2).
- `unit Foo;` -> reserved/identifier/symbol.
- `virtual override` -> identifiers.
- `Result:=A+1;` -> `:=` one symbol and roundtrip.
- `1..10` -> do not consume `..` as a decimal dot when number scanning is implemented.
- `// comment\r\n` -> comment excluding newline when comment scanner is implemented.
- `{$IFDEF DEBUG}` -> directive token when that scanner is implemented.
- Non-ASCII characters and malformed source -> no missing UTF-16 code units, no hang.

## Explicitly NOT now

No CST parser, AST, formatting engine, `.config` parser, CLI, LSP, incremental parsing, green/red trees or performance micro-optimizations. Full string/comment/directive/numeric scanning belongs to **M1.2**, not current task.

## Finish report

List created/changed files, which lexical categories actually work, test results (or explicit lack of Delphi 12.3 toolchain), known limitations and recommended M1.2 scope. Do not automatically start M1.2.
