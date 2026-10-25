# Planned lossless CST and parser — NOT part of initial coding task

## Purpose

Turn lexer tokens into syntactically grouped, exact-coverage syntax nodes. Every original token is reachable exactly once under the root; reconstructing from leaf tokens must yield the **exact** UTF-16 string. Parse errors do not invalidate this guarantee.

## Node hierarchy

```text
TSyntaxTree
  Source: string
  Root: TCompilationUnitSyntax / TUnparsedDocumentSyntax
  Diagnostics: array

TSyntaxElement (conceptual base)
  TSyntaxToken (leaf, original TDelphiToken or zero-width MissingToken)
  TSyntaxNode (immutable ordered children, SyntaxKind, [start,end) span)

TSyntaxKind examples:
  skCompilationUnit, skUnitDeclaration, skUsesClause,
  skTypeSection, skVariableSection, skProcedureDeclaration,
  skClassDeclaration, skRecordDeclaration,
  skBlockStatement, skIfStatement, skAssignmentStatement,
  skBinaryExpression, skUnaryExpression, skCallExpression,
  skParenthesizedExpression, skError, skOpaqueRegion
```

No premature class per grammar production is necessary. Initially use enum-kind nodes + ordered element children. Add typed wrappers/query helpers later if ergonomic.

## Children / trivia rules

- **Preferred initial CST model:** raw lexer trivia (`tkComment`, `tkWhitespace`, `tkNewLine`, `tkCompilerDirective`) remain explicit leaf tokens in original order. This is simple and unambiguous; implement skipping via a *lookahead view* only.
- Parser's `PeekSignificant` may ignore whitespace and normal comments for grammar decisions, but consuming a significant token must **attach all intervening original tokens** to the resulting tree.
- Compiler directives should not be casually ignored as trivia in grammar decisions. They can split legal constructs or select incompatible branches; preserve in context/opaque nodes when unsupported.
- The root includes initial trivia, trailing trivia and nonstandard source beyond normal `end.`.
- Error nodes wrap unexpected **actual** tokens. Missing tokens have zero width and no source contribution.
- Span parent = union of ordered child spans (including trivia); nodes never duplicate text.

## Suggested parser API (conceptual)

```text
TDelphiParser.Parse(lexResult) -> TSyntaxTree
TTokenReader.PeekSignificant(lookahead)
TTokenReader.ConsumeWithTriviaInto(builder)
TDelphiParser.ParseCompilationUnit
TDelphiParser.ParseUnit
TDelphiParser.ParseUsesClause
TDelphiParser.ParseDeclarationSection
TDelphiParser.ParseRoutineDeclaration
TDelphiParser.ParseBlock
TDelphiParser.ParseStatement
TDelphiParser.ParseExpression(minPrecedence)
TDelphiParser.ParsePrimaryExpression
```

## First grammar slices (in later parser milestones)

1. Atom expressions: identifier, number, string, parenthesized expression; unary +/-, binary +, *, assignments as statement-level operators.
2. `begin` / `end` block, semicolon-separated statement list, optional empty statement, `if ... then ... else`, calls.
3. `unit Name; interface ... implementation ... end.` with uses clauses and simple var/const/type and routine declarations.
4. More declarations and classes, generics, method directives, advanced expressions.
5. `program`, `library`, `package`, `include` fragments, conditional compiler paths, inline assembler, modern syntax.

## Error recovery

- At an expected token mismatch: emit a diagnostic with an expected-set and span. Prefer a zero-width synthetic missing token if it allows grammar to continue.
- Otherwise consume into `skError` until a context-specific synchronization token (e.g. `;`, `end`, `interface`, `implementation`, or EOF). Synchronization always respects nesting and consumes at least one token if continuing.
- No infinite loops: assert token index increases per loop or a method returns/throws an internal programming exception.
- If conditionals or include boundaries make a region semantically ambiguous, prefer `skOpaqueRegion` preserving all tokens; future formatter must not change it automatically.

## Source identity and memory

- Build mutable nodes internally, freeze on completion, then treat the tree as immutable.
- Source text is a retained immutable `string` snapshot; no per-token text copies.
- Avoid parent pointers initially; future typed views can hold a tree and a node index (similar to red nodes) if needed.
- Incremental reparse and persistent green/red trees are future optimization, *not* prerequisites for v1.

## Later AST lowering

- `TAstBuilder` walks CST nodes and creates semantic-focused nodes, omitting trivia but retaining source span or CST identity.
- Compiler configuration can influence AST (conditional defines, platform, included files). The CST remains the authoritative lossless source representation.
- Formatter uses CST directly and never requires AST or symbol resolution.

## Required CST acceptance tests (later)

1. Root-leaf token identity = original lexer token stream in same order, ignoring only zero-width synthetic leaves.
2. Exact source roundtrip from CST leaves for valid, invalid, partial and conditional Delphi input.
3. Correct node shape and operator precedence for targeted grammar slices.
4. Diagnostics and continuing parsing after errors without dropping tokens.
5. Deterministic trees for same input.
