# Technical architecture

## Goal and design boundaries

Build a reusable Delphi parsing toolkit that supports a Delphi 12.3+ source formatter with **original Delphi `.config` behavior**, and separately configured editor settings (tabs, tab stops, indentation, line endings, encoding, exclusions). Later optional consumers: AST lowering, linter, refactorings, VS Code extension/Language Server, Delphi IDE integration.

**First deliverable = standalone lossless lexer + tests.** No formatter or parser implementation in the first task.

## Data flow and dependencies

```text
Decoded source snapshot (UTF-16 string)
     |
     v
  Lexer ---> token array + lexical diagnostics + exact source spans
     |
     v
  CST parser ---> lossless syntax tree + syntax diagnostics
     |                       |
     |                       +--> Formatting rules (Delphi .config + own settings)
     |                                  |
     |                             Layout planner
     |                                  |
     |                         Validated source edits / writer
     |
     +--> CST -> AST lowering -> symbols/types -> linter/refactoring/LSP

Source I/O (later): original bytes/encoding/BOM <-> source snapshot
```

Dependency direction must stay downward: lexer never knows about syntax nodes; CST never depends on AST/formatter; AST never required for formatting.

## Proposed repository layout

```text
src/
  DelphiFormatter.Core/
    DelphiFormatter.Core.Spans.pas
    DelphiFormatter.Core.Diagnostics.pas
    DelphiFormatter.Core.LineMap.pas           # optional, after lexer core
  DelphiFormatter.Lexer/
    DelphiFormatter.Lexer.Tokens.pas
    DelphiFormatter.Lexer.Scanner.pas
    DelphiFormatter.Lexer.Keywords.pas
  DelphiFormatter.Syntax/                     # FUTURE
    DelphiFormatter.Syntax.Kinds.pas
    DelphiFormatter.Syntax.Nodes.pas
    DelphiFormatter.Syntax.Tree.pas
  DelphiFormatter.Parser/                     # FUTURE
    DelphiFormatter.Parser.Reader.pas
    DelphiFormatter.Parser.Delphi.pas
  DelphiFormatter.Formatting/                 # FUTURE
    DelphiFormatter.Formatting.Options.pas
    DelphiFormatter.Formatting.Rules.pas
    DelphiFormatter.Formatting.Layout.pas
    DelphiFormatter.Formatting.Edits.pas
  DelphiFormatter.Ast/                        # FUTURE
    DelphiFormatter.Ast.Nodes.pas
    DelphiFormatter.Ast.Builder.pas
  DelphiFormatter.Cli/                        # FUTURE
tests/
  DelphiFormatter.Lexer.Tests/
  DelphiFormatter.Parser.Tests/               # FUTURE
  DelphiFormatter.Formatting.Tests/           # FUTURE
  Fixtures/
docs/
  ARCHITECTURE.md
  LEXER_SPEC.md
  CST_SPEC.md
  TEST_PLAN.md
  ROADMAP.md
  DECISIONS.md
AGENTS.md
CODEX_START.md
README.md
```

**Initial actual files only:** spans, diagnostics, tokens, scanner, keywords (if useful), DUnitX lexer project/tests/fixtures. No placeholder Pascal units for future folders.

## Concrete types and roles

| Layer | Type / unit | Responsibility | Lifetime / notes |
| --- | --- | --- | --- |
| Core | `TSourceSpan` (`Core.Spans`) | `StartOffset`, `Length`, computed end; validate ranges. | Value record; 0-based UTF-16. |
| Core | `TDiagnostic`, `TDiagnosticSeverity` (`Core.Diagnostics`) | Stable code, message, span, severity. | Value records; diagnostics collect, don't raise for syntax errors. |
| Core | `TLineMap` (`Core.LineMap`, later) | Map offset -> 1-based line/column; handles CR, LF, CRLF. | Built once per source when requested. |
| Lexer | `TTokenKind`, `TDelphiToken` (`Lexer.Tokens`) | Token classification, span, no copied token text. | Value records. |
| Lexer | `TDelphiLexResult` (`Lexer.Tokens`) | Retains source snapshot and token/diagnostic arrays, provides `GetToken(Index)` and `TokenText(Index)`. | Owns arrays and source string. |
| Lexer | `TDelphiLexer` (`Lexer.Scanner`) | Lookahead, `Scan*` functions, tokenization loop. | One scanner per invocation, no global mutable state. |
| Lexer | Keyword classifier (`Lexer.Keywords`) | Case-insensitive reserved-word recognition only. | Context-sensitive words remain identifiers. |
| CST | `TSyntaxKind` (`Syntax.Kinds`) | Kinds for nodes and token-likes. | Expandable by category. |
| CST | `TSyntaxElement` / `TSyntaxNode` / `TSyntaxToken` (`Syntax.Nodes`) | Lossless ordered tree leaves and nodes. | Immutable post-build, tree owns root/lifetime. |
| CST | `TSyntaxTree` (`Syntax.Tree`) | Source snapshot, root, diagnostics, queries. | Tree owns source and nodes. |
| Parser | `TTokenReader` (`Parser.Reader`) | Significant-token lookahead without discarding trivia. | Preserves every token; no copying text. |
| Parser | `TDelphiParser` (`Parser.Delphi`) | Recursive descent grammar, Pratt/precedence for expressions. | Local parse state and contextual recovery. |
| Formatter | `TFormattingOptions` | Effective native + extended settings, provenance. | Later. |
| Formatter | `TLayoutDocument` | Group, indent, text, soft/hard line primitives. | Later; configurable rather than opinionated defaults. |
| Formatter | `TTextEdit` | `(StartOffset, DeleteLength, NewText)` validated edits. | Later; non-overlapping spans, applied back-to-front. |
| AST | `TAstBuilder` | Lower CST to semantic-focused AST with source links. | Later, not on formatter path. |

## Suggested first public API (conceptual, implement Delphi-valid equivalent)

```pascal
type
  TSourceSpan = record
    StartOffset: Integer;
    Length: Integer;
    function EndOffset: Integer;
  end;

  TTokenKind = (
    tkIdentifier, tkReservedWord, tkNumber, tkStringLiteral,
    tkCharCode, tkSymbol, tkCompilerDirective, tkComment,
    tkWhitespace, tkNewLine, tkUnknown, tkEOF
  );

  TDelphiToken = record
    Kind: TTokenKind;
    Span: TSourceSpan;
  end;

  // TDelphiLexResult retains the original string and exposes read-only
  // access via TokenCount/GetToken/TokenText/DiagnosticCount/GetDiagnostic.
  // TDelphiLexer.Tokenize(Source: string) returns one owned result object.
```

These are API sketches, not compiled source. Codex should choose valid unit declarations and constructors; avoid returning a mutable array as a 'read-only' public property.

### Ownership rules

- Lexer stores one original `string` snapshot in `TDelphiLexResult`; token text is accessed by slicing with `Copy(Source, StartOffset + 1, Length)` only on demand.
- Lexer tokens do not own independent string copies. A text snapshot shared with future `TSyntaxTree` must have a clear owner; Delphi strings are reference-counted, so retain the snapshot explicitly in each result that needs it.
- `TDelphiLexResult` is disposable without invalidating **value-only** spans, but consumers must not dereference them without a living matching source snapshot.
- Diagnostics never mutate source.
- `TSyntaxTree` later owns all syntax nodes and keeps exact source and token references; parse error recovery adds nodes/leaves, not silent drops.

## Parser design for later milestones

- Handwritten recursive descent for units, declarations, blocks, statements.
- Precedence-climbing or Pratt parser for expression operators, unary/postfix components, including argument lists, indexing, generics.
- Trivia stays in token leaves or deterministic attached trivia; choose one model before parser implementation. **Preferred**: CST leaves for all tokens initially, with no trivia ownership ambiguities; only consolidate trivia later if it demonstrably helps.
- Tree root has ordered full source coverage, including leading/trailing trivia and tokens following an apparently completed unit.
- Error nodes contain skipped *original tokens*; missing expected tokens are zero-width synthetic leaves; a parser loop must always consume a token or exit.
- Conditional compilation directives: preserve both branches and avoid formatting semantically unsafe regions until properly modeled; includes not expanded during initial CST parse.
- AST lowering later may need a selected defines/platform/project context; do not assume CST maps to exactly one active AST.

## Formatter design for later milestones

- `.config` interpreted in a compatibility layer, own editor settings in a separate layer.
- Record settings and provenance; validate unknown, unsupported, conflicting options.
- Native reference oracle: `Formatter.exe` from Delphi 12.3, controlled fixtures/profiles/IDE settings, compare byte- or text-exact outputs as appropriate.
- CST -> format/layout plan -> guarded, non-overlapping edits. Preserve syntax-sensitive strings, comments and opaque/unknown regions. Validation with reparsing and roundtrip invariants. No AST requirement.
- Original byte I/O and encoding/BOM preserved when writing files; isolate it from in-memory UTF-16 formatting.

## Dependency/test policies

- Delphi 12.3, RTL; DUnitX only for tests.
- No incidental changes in application projects, no external Delphi IDE automation for the initial lexer.
- Build Win64 locally if toolchain exists; support cross-platform RTL code where practical but do not promise untested platforms.
