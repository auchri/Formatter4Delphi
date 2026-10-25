# Lossless CST and basic parser — M2.1

## Public API and ownership

The implemented units are `Syntax.Kinds`, `Syntax.Nodes`, `Syntax.Tree`,
`Parser.Reader` and `Parser.Delphi` (all prefixed `DelphiFormatter.`).
`TSyntaxKind` distinguishes roots, grammar nodes, errors, opaque regions,
original tokens and missing tokens. `TSyntaxElement` exposes read-only `Kind`
and `Span`; `TSyntaxNode` exposes ordered `ChildCount` / `GetChild(Index)`.
There are no parent pointers or classes per grammar production.

`TSyntaxToken.OriginalToken` is a value copy of the original token record;
`OriginalIndex` identifies its position in the original lexer stream.
`IsMissing` leaves have index -1, length zero and `ExpectedText`; their
`OriginalToken` is not meaningful. No original token text is copied into leaves.

`TDelphiParser.Parse(LexResult)`, `ParseExpression(LexResult)` and
`ParseStatement(LexResult)` each return an independently owned `TSyntaxTree`.
The caller frees the tree. The lexer result is borrowed during the call only;
it may be freed immediately afterwards. Each tree retains its own reference to
the immutable source string and copies the lexical diagnostic value records.

The parser owns every element in a `TObjectList` arena while constructing the
tree. On successful construction ownership of the element array transfers to
the tree. Nodes retain private copies of child-reference arrays and never own
children separately. Destroying a tree frees every arena element exactly once,
without recursive destruction. Root/child references are borrowed: do not free
them individually. Constructors are low-level construction APIs, not mutation
APIs; callers constructing a tree directly must supply a unique complete arena.
There is no public mutation of a finished tree or its child arrays.

## Losslessness and spans

Every original token, including whitespace, comments, newlines, directives and
EOF, appears exactly once in depth-first leaf order with its original index,
kind and span. Original spans are zero-based UTF-16 `[start, start + length)`.
Parent spans cover their ordered children including trivia. Empty nodes and
missing tokens are anchored before pending trivia, preserving sibling order.
Roots span the entire source, including trailing trivia and unexpected source.

`TSyntaxTree.Serialize` iteratively traverses the tree, appending source slices
for original leaves. Missing leaves and EOF contribute no text. It never returns
the stored whole source as a shortcut. `Serialize(Parse(Source)) = Source`
also applies to unsupported, incomplete and malformed UTF-16 input.

## Reader

`TTokenReader` borrows a validated non-nil `TDelphiLexResult`.
`Position` is the next unconsumed original index. `SignificantIndex`,
`PeekSignificant`, `Matches` and `AtEOF` skip only whitespace, newlines and
ordinary comments. Compiler directives remain significant. Text comparisons are
case-insensitive and restricted to identifiers, reserved words and symbols.
Negative lookahead clamps to zero; overshooting lookahead clamps to EOF.
`ConsumeWithTriviaInto(Children, Arena)` appends original leaves for pending
trivia plus the next significant token, registers their ownership and advances.
Repeated consumption after EOF is a no-op. Lookahead never consumes tokens.

## Supported grammar

- Identifiers, numbers, strings and character codes; adjacent string/char-code
  components form one literal node. `nil` and Boolean constants are accepted.
- Parentheses, prefix `+`, `-`, `not`, `@`, nested/simple calls with comma-separated
  arguments, including zero arguments. No member/index/dereference/set syntax.
- Binary precedence climbing, equal precedence left-associative:
  high `* / div mod and shl shr as`, then `+ - or xor`, then
  low `= <> < > <= >= in is`. Prefix operators bind above binary operators;
  calls bind above prefix operators. See the official
  [Delphi expression reference](https://docwiki.embarcadero.com/RADStudio/Athens/en/Expressions_(Delphi)).
- Simple identifier assignments, identifier/call statements, empty statements,
  `begin/end`, nested `if/then/else`. Separating semicolons belong to the block
  (or isolated statement root), not to statements. `else` binds to the nearest
  unmatched `if`; a preceding semicolon prevents binding and is diagnosed.
- `unit Name; interface ... implementation ... end.` with dotted names and
  one optional uses clause per section. Uses lists accept dotted names and
  optional `in 'filename'`. Declaration/routine bodies stay opaque.

The entry roots are `skCompilationUnit`, `skExpressionRoot`, `skStatementRoot`.
Each contains the parsed construct, any trailing opaque region, and EOF/trivia.

## Recovery and conservative boundaries

`PAR001` (error) means a missing expected token/expression/identifier;
`PAR002` (error) means unexpected source; `PAR003` (warning) means unsupported
syntax; `PAR004` (error) marks the parser nesting limit. Lexer diagnostics are
retained first, followed by parser diagnostics in deterministic discovery order.
Diagnostic spans identify the significant offending token; synthetic leaves
anchor before its leading trivia. No original token is synthesized or duplicated.

Expression boundaries include `; end else then ) , interface implementation`
and EOF. Missing operands/closers preserve these tokens for their caller.
Unsupported statements scan to contextual boundaries, tracking nested blocks,
parentheses and brackets. Blocks preserve unexpected boundary tokens in error
nodes and continue. Unsupported unit sections scan to `implementation` or final
`end.` / incomplete `end` at EOF, retaining inner class/routine `end;` tokens.
Unsupported trailing input becomes an opaque root child. A name followed by an angle-bracket list and a call opener is ambiguous with generic specialization and is conservatively opaque, including nested call arguments. M2.1 does not resolve that ambiguity semantically.

If the input contains ANY compiler directive, the entire input body is one
opaque region. This deliberately conservative M2.1 policy avoids treating
conditional branches and includes as one definite grammar. Directives and all
branches remain original leaves; no preprocessing occurs.

Recursive expression/statement entry depth is limited to 128. Exceeding it emits
PAR004 and preserves the remaining fragment via opaque recovery. Binary chains,
serialization and destruction do not require recursion proportional to chain
length. All continuing loops consume original tokens (operators, separators,
opaque/recovery tokens), or explicitly break/return on unchanged input.

## Acceptance and next scope

The parser suite checks exact original leaf sequence/kinds/spans, unique element
reachability, ordered parent spans, reconstruction after freeing the lexer,
non-flat syntax shape, precedence/associativity, statements, units, recovery,
directives, deterministic malformed input and ownership. See `M2_STATUS.md` and
`TEST_PLAN.md` for actual execution evidence.

Future work: basic declarations and routine bodies, then richer expressions and
statements. Full grammar, directive evaluation, AST, semantic analysis,
formatting and incremental parsing are outside M2.1.
