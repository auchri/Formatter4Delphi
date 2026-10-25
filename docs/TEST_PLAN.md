# Test plan — DUnitX from day one

## Important

A trivial 'roundtrip is equal' test is necessary, but **not sufficient**: a broken lexer returning the entire source as `tkUnknown` would pass it. Assert precise kinds, spans and diagnostics. All lexer calls work on `string` input. Focused cases are embedded; the realistic corpus is loaded explicitly as UTF-8 by test code and also compiled into the runner.

## Common invariant assertion (`AssertTokenCoverage`)

For `Source` and `Tokens[0..N-1]`:

1. Exactly one trailing `tkEOF`, `Span=(Length(Source), 0)`.
2. For each non-EOF token: `Length > 0`, `StartOffset = PreviousToken.EndOffset`, `EndOffset <= Length(Source)`.
3. Last non-EOF `EndOffset = Length(Source)`; empty source has only EOF.
4. Concatenation of `Copy(Source, StartOffset+1, Length)` of non-EOF tokens equals Source code-unit-for-code-unit.
5. Every token category scan can terminate in bounded progress. Diagnostics offsets are in `[0..Length(Source)]` with valid lengths.

## Concrete lexical cases

| ID | Source (conceptual) | Key assertions |
| --- | --- | --- |
| L001 | empty string | Only EOF. |
| L002 | ` ` / TAB / multiple spaces | One or more `tkWhitespace`, exact span. |
| L003 | CRLF, CR, LF independently | Each kind `tkNewLine`, CRLF length 2. |
| L004 | `unit Foo;` | `unit` reserved, `Foo` identifier, `;` symbol. |
| L005 | `ReSuLt := A;` | Case retained; contextual/classification validated. |
| L006 | `virtual override read write` | Contextual words classified as identifiers. |
| L007 | `&Type` | Complete escaped identifier, span including `&`. |
| L008 | `A:=B;` | `:=` one symbol, no lost text. |
| L009 | `1..10` | Number `1`, symbol `..`, number `10`. |
| L010 | `1.25e-3 + 7E2` | Real/exponent recognized; `+` outside exponent separate. |
| L011 | `$FF`, `%1010`, `2_000_000` | Three numeric tokens, exact original text. |
| L012 | `1__2`, `$`, `1e+` | Preserve and issue appropriate diagnostics or tested lexical fallback. |
| L013 | `#13#10'Hi'` | Character-code and string token boundaries. |
| L014 | `'It''s Delphi'` | One string token, no premature termination. |
| L015 | `''` | Empty ordinary string. |
| L016 | Valid `'''` multiline literal with CRLF | One string token retains full content. |
| L017 | Valid `'''''` multiline literal | Odd-delimiter length recognized and retained. |
| L018 | Unclosed `'abc` | Token to EOF + string diagnostic, roundtrip. |
| L019 | Unterminated multiline literal | Token to EOF + diagnostic, roundtrip. |
| L020 | `// comment` + newline | Comment excludes newline; newline separate. |
| L021 | `{ comment }` | One comment token. |
| L022 | `(* comment *)` | One comment token. |
| L023 | `(* { nested } *)` | Cross-style nested comments handled after compiler validation. |
| L024 | `{$IFDEF DEBUG}` | Compiler directive token. |
| L025 | `(*$H+*)` | Compiler directive token. |
| L026 | `//$IFDEF DEBUG` | Normal comment, NOT compiler directive. |
| L027 | Unterminated `{comment` | Comment token + diagnostic. |
| L028 | Unterminated `{$IFDEF` | Directive token + diagnostic. |
| L029 | `// ' {` | String/comment markers inside comment are inert. |
| L030 | `'// { (*'` | Comment markers inside ordinary string are inert. |
| L031 | `A(.0.)` | Alternative brackets recognized as symbols. |
| L032 | `<= >= <> := ..` | Longest operators matched. |
| L033 | `Änderung_1` | Unicode identifier accepted (case retained). |
| L034 | Non-BMP text / isolated UTF-16 surrogate | No crash, no lost code units; classification based on verified rules. |
| L035 | NUL/unusual control char outside string | Preserve safely and classify/diagnose. |
| L036 | `/// <summary>` | Comment including XML-doc prefix. |
| L037 | Mixed line endings through comments/strings | Exact reconstruction and correct source spans. |
| L038 | `end.` + trailing whitespace / garbage | Entire source tokenized, no early stop. |
| L039 | Realistic small .pas file | Token kinds, spans, roundtrip. |
| L040 | Random input of up to several thousand code units | No infinite loops/exceptions, exact coverage. |

## DUnitX test organization

```text
tests/DelphiFormatter.Lexer.Tests/
  DelphiFormatter.Lexer.Tests.dpr
  Tests.Lexer.Basics.pas
  Tests.Lexer.Strings.pas
  Tests.Lexer.Comments.pas
  Tests.Lexer.Numbers.pas
  Tests.Lexer.Unicode.pas
  Tests.Lexer.Roundtrip.pas
```

Start with one test fixture unit if simpler, split as tests grow. Tests should not depend on the library internal scanning implementation; use public lexer result API.

M1.2 keeps one fixture with 40 test methods. Added cases cover quote runs
1..12, multiline delimiters 3/5/7/9 with all newline forms, exact string recovery,
comment/directive boundaries, valid/malformed numerals, numeric member access,
char-code boundaries/ranges, encoding errors inside constructs and the compiled
`LexicalCorpus.pas` fixture. `SeededMalformedInputs` uses an explicit 32-bit LCG
seed `$4D312E32` for 500 cases, including arbitrary UTF-16; each case is scanned
twice and compared for kinds, spans and diagnostic code/spans. Coverage checks
independently reconstruct every token slice. See `M1_STATUS.md` for actual runs.

## M2.1 CST test obligations

- Leaf-token sequence matches lexer sequence exactly (synthetic missing tokens excluded).
- Reconstruct from CST token leaves (NOT raw source passthrough).
- Tree precedence and grammar shape tests, including error nodes.
- No syntax token dropped in recovery; all token stream gaps accounted for.

## Compilation and verification

- Attempt build / DUnitX execution with a real Delphi 12.3 toolchain when available. Report exact commands and environment if run.
- If no Delphi compiler available, do code review/static sanity checks and report tests as **not run**, not passing.
- Never weaken a failing test just to make a build green; add a documented language-rule decision when behavior is disputed.

## Implemented parser suite (28 tests)

`tests/DelphiFormatter.Parser.Tests/` is an independent DUnitX console project
in `DelphiFormatter.groupproj`, using the same core/lexer units plus the five
new syntax/parser units. Debug enables range/overflow checks. The test runner
also enables RTL leak reporting.

Every parser helper frees the original lexer result before checking the tree.
Coverage independently re-lexes its source and compares every original leaf's
index, kind, offset and length, including EOF. Missing leaves must have length
zero, index -1 and expected spelling. Unique reachability, ordered children,
parent span unions, full root span and actual leaf serialization are asserted.

Focused tests check binary hierarchy, all 20 binary operators and equal-group
left association, mixed Delphi word-operator precedence, prefix/parenthesized
expressions, nested/empty calls, string/char-code components, assignments,
blocks/empty statements, nearest-if else binding, else after a block, invalid
semicolon-before-else recovery, minimal/dotted units and uses clauses. Missing
operands/closers/headers, malformed uses and statements check diagnostics and
continued structural parsing. Directive/include input and unknown declarations
must expose opaque nodes rather than fabricated grammar.

Seeded malformed token-sequence inputs are parsed twice in all three entry
modes, comparing structure and diagnostic codes/messages/spans. Seeded arbitrary
UTF-16 inputs exercise controls and isolated surrogates. Deep parentheses test
the nesting guard; long binary chains test shape and iterative serialization.
Repeated construction/destruction, independent trees from one lexer and lexical
diagnostic survival exercise ownership. Lexer tests remain intact.

Use the IDE Build All Projects with Win64/Debug, then execute both generated
EXEs in `build/Win64/Debug`. Verify timestamps before trusting results.
`M2_STATUS.md` records the actual compiler version, counts and fresh artifacts;
Delphi 12 Update 1 success is not an exact Delphi 12.3 validation claim.
