# Lexer specification — M1.2

## Scope

Turn arbitrary Delphi 12.3+ source text (`string`, UTF-16) into an ordered, fully covering token stream plus diagnostics. Do **not** parse declarations/statements and do **not** preprocess compiler directives.

Properties required:

1. **Coverage:** every UTF-16 code unit in source belongs to exactly one non-EOF token. Tokens sorted by start offset, adjacent, never overlapping. EOF is a single token at `(Length(Source), 0)`.
2. **Roundtrip:** concatenate slices of non-EOF tokens and obtain exactly original `string`.
3. **Correct classifications:** test token kinds, exact spans, and error diagnostics independently of roundtrip.
4. **Progress:** all scanner paths consume at least one UTF-16 code unit or terminate at EOF; empty input produces only EOF.
5. **Resilience:** invalid/incomplete input returns tokens and diagnostics; no information is lost.
6. **Pure function behavior:** identical input and options -> identical token sequence.

### Offset conventions

- `StartOffset` is **zero-based UTF-16 code-unit index**.
- Span is `[StartOffset, StartOffset + Length)`.
- `FSource[StartOffset + 1]` is the corresponding Delphi `string` element.
- A CRLF sequence is one `tkNewLine` token of length 2; CR and LF each standalone are length 1.
- Newlines inside a block comment or multiline string remain inside that token (no overlapping newline token); the future `TLineMap` scans the original source to derive line/column.
- No BOM or file encoding is handled by lexer; I/O layer handles it later.

## Token kinds and initial policy

| Kind | Recognition | Notes |
| --- | --- | --- |
| `tkIdentifier` | Valid Delphi identifier, including contextual directive words | Case is preserved; reserve only true keywords. |
| `tkReservedWord` | Delphi reserved words, case-insensitive | `virtual`, `override`, `read`, `write` remain identifiers; parser reclassifies contextually. |
| `tkNumber` | Decimal, `$` hex, `%` binary, real/exponent and `_` digit separators | Keep entire literal as is; validate and diagnose malformed separators/digits without truncating unknown text. |
| `tkStringLiteral` | Ordinary single-quoted and Delphi 12+ multiline string literals | Must handle doubled quotes in ordinary strings. |
| `tkCharCode` | Decimal/hex codes with optional digit separators | Separate tokens for adjacent codes/strings; range 0..65535. Binary codes are invalid. |
| `tkSymbol` | Single/multi-char special symbols and operators | Longest applicable match (`:=`, `..`, `<=`, `>=`, `<>`, `(.`, `.)`, etc.). |
| `tkCompilerDirective` | `{$...}` or `(*$...*)` | Begins with `$` immediately after opening delimiter; preserve entire directive. |
| `tkComment` | `{...}`, `(*...*)`, `//...` | Includes XML doc `///`, which remains source text, optional later subtype. |
| `tkWhitespace` | Horizontal spaces/tabs and other supported non-line-ending whitespace | Preserve exact sequence, no normalization. |
| `tkNewLine` | CRLF, CR, LF | Independent line endings preserved. |
| `tkUnknown` | Unrecognized character/source fragment | Consume safely, diagnose when meaningful. |
| `tkEOF` | End sentinel | Zero width, exactly once. |

Don't add semantic categories (types, method names, attributes) in lexer.

## Scanner dispatch order

At each position:

1. End-of-input?
2. CR/LF/CRLF -> new line.
3. Horizontal whitespace/control blanks -> whitespace.
4. `//` -> line comment (up to but **not including** EOL).
5. `{` or `(*` -> block comment or compiler directive if immediately followed by `$`; honor closing delimiter.
6. `'` -> ordinary or multiline string scanner.
7. Identifier start / `&` + identifier -> identifier or escaped identifier; escaped `&Type` can initially be `tkIdentifier`, provided the complete source span is retained.
8. Digit, `$`+hex, `%`+binary -> number scanner; handle conflicts with symbol/unknown.
9. `#` + valid char-code prefix -> char-code scanner.
10. Longest matching symbol/operator -> symbol.
11. Fallback -> unknown (at least one code unit).

**Lookahead is bounds-checked.** Prefer `Peek(Delta)` or `Matches` functions; no unguarded `Source[Position + Delta + 1]`.

## Delphi-specific lexical rules

### Identifier and reserved words

- Delphi is case insensitive for keywords/identifiers, yet token text and case remain untouched.
- Start: alphabetic Unicode character or `_`; continuation: allowed Unicode letters/numerals/digits/underscore; do not treat Unicode whitespace as identifier text. Unicode supplementary code points need careful surrogate-pair handling; verify exact compiler behavior, but always preserve unexpected code units.
- Extended identifiers: `&Type` is not a bitwise expression; recognition of `&` before a legal identifier start must be deliberate. `&` before a digit should not accidentally create a valid identifier.
- **Do not classify contextual directives like `virtual`, `read`, `write`, `override`, `static`, `strict` globally as reserved words.**
- Make keyword lookup small, case-insensitive, centralized and tested; preserve spelling. Official language reference is authoritative.

### Comments / directives

- `{comment}` and `(*comment*)` may contain newlines.
- Each block comment ends at the first closer of its own style. Other-style
  delimiters are inert. Thus `(* { hello } *)` works without a stack, while
  `{ (* } X` ends before `X`. Same-style openers do not increase depth.
  These boundaries were checked with the installed Delphi 12 compiler.
- `//` extends to, but does not absorb, newline.
- Compiler directive only when `$` appears immediately following `{` or `(*`; `//$IFDEF` is plain comment.
- Unterminated block comment/directive: one token to EOF plus diagnostic; never drop content.
- Avoid falsely starting a comment in a string literal.

### Numbers

- decimal integers, real literals with decimal separator `.`, optional exponent `e/E` with optional sign, numeric digit separators `_` with validated placement.
- hex via `$` prefix, binary via `%` prefix.
- Separators require digits on both sides in each digit component.
- `1.` is accepted; `1.ToString` and `1.e2` keep the dot as a separate symbol
  before an identifier. A fraction/exponent must not swallow member access.
- Malformed digit runs retain separators, exponent signs and invalid binary
  digits in one numeric token with `LEX004`. A nonnumeric suffix begins a
  following token (`$G` is invalid `$` then identifier `G`). Numeric magnitude
  is not evaluated, except char-code range checking. Parsing/type errors such
  as adjacent numeral/identifier tokens belong to the parser.
- **Important:** `1..10` = number `1`, symbol `..`, number `10` (do not absorb the first dot into float).
- Unary `+`/`-` are separate tokens, not part of number (except sign after `E/e` inside exponent).
- Unusual malformed numeric syntax must be preserved and diagnosed, with exact splitting validated against Delphi where possible.

### Strings / character codes

- Ordinary `'It''s Delphi'`: doubled quote escapes quote.
- Delphi 12+ multiline strings begin with an odd sequence of at least three quotes, followed by a newline; end with a matching-length closing quote sequence on a line of its own. Matching delimiters must be carefully validated (3, 5, 7, ...).
- The indentation of closing multiline delimiters changes string **value**, so lexer must never normalize spaces or line endings inside a multiline literal.
- Unterminated ordinary strings stop before CR/LF (or at EOF), allowing the
  next line to recover. Unterminated multiline strings extend to EOF. Both
  preserve all input and produce `LEX003`. Closing multiline quote runs must
  match the opening run exactly and follow only indentation on their line.
  Indentation validity/value calculation is outside lexical classification.
- `#13`, `#$0A`, `#1_0` are char-code tokens. `#%1010` is retained as a
  malformed char-code token with `LEX004` (compiler rejects binary codes).
  Combined string expressions consist of adjacent string and char-code tokens.
- Make ambiguous sequences of quotes explicit regression fixtures (2, 3, 4, 5, 6, 7 quotes; quotes inside multiline bodies).

### Special symbols

- At minimum cover `:=`, `<=`, `>=`, `<>`, `..`, `(.`, `.)`, plus ordinary punctuation and operators.
- Recognize `(*` as a comment opener **before** generic symbol scanning.
- `(.` and `.)` are alternate square brackets: recognize as indivisible symbols where applicable.
- Reserved-word operators (`and`, `or`, `div`, `mod`, `in`, `is`, `as`, `shl`, `shr`, `xor`, `not`) are word tokens, not punctuation.

## Diagnostics

Use a small stable code set, e.g.:

- `LEX001`: unterminated block comment
- `LEX002`: unterminated compiler directive
- `LEX003`: unterminated string literal
- `LEX004`: malformed numeric literal
- `LEX005`: unknown/invalid source character
- `LEX006`: reserved historical code for deferred M1.1 categories; M1.2 does
  not emit it. All regular categories have scanners.
- `LEX007`: invalid UTF-16 encoding (error); an isolated high or low surrogate,
  preserved in its containing token (one `tkUnknown` code unit outside a
  construct). `LEX005` means an unrecognized source character, not an encoding error.

Each diagnostic includes code, severity, span, message; location conversion can be added via `TLineMap` when needed. Don't throw for lexical errors.

### Implemented API details

- `TSourceSpan.Create(StartOffset, Length)` validates nonnegative values and
  Integer overflow; the two values are read-only properties, `EndOffset` is
  a function. The default record value is the valid empty span `(0, 0)`.
- `TDiagnosticSeverity = (dsInfo, dsWarning, dsError)`; `TDiagnostic` has
  `Code`, `Message`, `Severity`, `Span` and a matching constructor.
- `TDelphiLexer.Tokenize(const Source: string)` is a static class function.
  The caller frees the returned `TDelphiLexResult`.
- Result properties `Source`, `TokenCount`, `DiagnosticCount` are read-only;
  `GetToken`, `TokenText`, `GetDiagnostic` validate zero-based indices and
  raise `EArgumentOutOfRangeException` for API misuse (not lexical errors).
  Construction copies input arrays so callers cannot mutate the snapshot
  through aliases. Source strings retain RTL copy-on-write semantics.
  The public result constructor rejects noncontiguous/out-of-source token
  spans, missing/duplicate/misplaced EOF and out-of-source diagnostic spans
  with `EArgumentException`. Zero-width diagnostics at EOF are allowed.
- Baseline blanks are U+0000 through U+0020 except CR/LF, which produce
  newline tokens. BMP letters/underscore start identifiers; RTL Unicode
  letters/numbers/underscore continue them. Valid surrogate pairs form one
  length-2 unknown token with `LEX005` outside literals/comments; isolated
  surrogates use `LEX007` everywhere, including inside constructs. Valid pairs
  inside literals/comments have no encoding diagnostic. A supplementary letter
  in an identifier was rejected by the installed compiler; 12.3 revalidation
  remains outstanding. Encoding diagnostics precede scanner diagnostics.
- Keyword matching folds ASCII keyword letters without locale dependence.
  The documented reserved-word table plus `at`/`on` is centralized; contextual
  visibility/declaration directives remain identifiers.

## Algorithm sketch

```text
result.source = original source (string reference-counted snapshot)
position = 0
while position < source.length (UTF-16 code units):
    start = position
    detect the next category using bounded lookahead
    advance position to end of recognized item, or one code unit on fallback
    assert position > start
    append Token(kind, [start, position))
append Token(EOF, [source.length, source.length))
validate full coverage in debug/tests
```

## Explicitly excluded from lexer milestone

- CST nodes/grammar, parser recovery, semantic classification or type resolution.
- Expanding `{$I ...}`, evaluating `{$IFDEF}`, project defines, DFM parsing.
- Native `.config` parsing, layout, code writing, native formatter equivalence testing.
- Optimization without measurements, incremental parsing, background threads, reusable pools.

## Sources for validation

- https://docwiki.embarcadero.com/RADStudio/Athens/en/Fundamental_Syntactic_Elements_(Delphi)
- https://docwiki.embarcadero.com/RADStudio/Athens/en/String_Types_(Delphi)
- https://docwiki.embarcadero.com/RADStudio/Alexandria/en/Delphi_compiler_directives
