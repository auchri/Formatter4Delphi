# Roadmap with acceptance gates

**Work on one small task at a time. Do not code future milestones merely because they are documented.**

## Phase 1 — Parsing foundation (immediate priority)

### M1.0 — Skeleton and tests
- Minimal pure RTL units for spans, diagnostics, tokens.
- Delphi 12.3 project file, a DUnitX Win64 test project and one basic source fixture.
- Toolchain detection and honest compilation/test status.
- **Gate:** projects syntactically/build correctly where Delphi 12.3 available; otherwise document inability to run tests.

### M1.1 — Lossless lexer baseline (**first implementation goal**)
- Scanner with bounded lookahead, EOF, whitespace/newlines, identifiers/keywords, basic symbols/operators.
- `TDelphiLexResult` provides source/token/diagnostic reads.
- Verify adjacent nonoverlapping offsets and original-string reconstruction.
- **Gate:** token kinds/spans plus roundtrip tests pass on baseline fixtures.

### M1.2 — Complete lexical edge cases
- Ordinary and Delphi 12+ multiline strings, comments, compiler directives, binary/hex/real/underscored numerals, char-code sequences, Unicode.
- Diagnostics for malformed/unfinished constructs; no loss on invalid input.
- **Gate:** all defined lexer test matrix cases pass; no hangs; 100% coverage property on tested source snapshots.
- Implemented: 40/40 tests pass on Delphi 12 CE Update 1, Win64/Debug.
  Exact 12.3 validation remains open; see `M1_STATUS.md`. Stop implementation
  here for this task; M2 is not started.

### M1.3 — Lexer corpus and stabilization
- Real `.pas`, `.dpr`, `.dpk`, `.inc` fixture samples; fuzz/property tests.
- Profile allocations/performance on representative source. Optimize only known bottlenecks.
- **Gate:** documented lexical syntax coverage; deterministic roundtrips and diagnostics; stable public contract.

### M2 — Lossless CST core
- Syntax nodes, tree, builder, token reader, error/missing/opaque leaves.
- Expressions, statements, basic units, then extended Delphi 12.3+ grammar.
- **Gate:** exact CST roundtrip and correct tree shape; no discarded original tokens under error recovery.

### M3 — Grammar completion and validation
- Real-world projects and conditional compiler directives/inclusions handled conservatively.
- **Gate:** supported syntax coverage measured; unsupported regions protected from unsafe edits.

## Phase 2 — Original Delphi-compatible formatter

### M4 — Configuration & oracle harness
- Parse native Delphi `.config` without silently ignoring options.
- Additional editor behavior settings in separate project config.
- Automated controlled comparison against original Delphi 12.3 `Formatter.exe` output, including environment/editor option controls.
- **Gate:** explicit per-option compatibility coverage and reproducible comparisons.

### M5 — Formatting rules, layout & source edits
- CST-driven rules + configurable line breaking/indentation.
- Guarded edits, idempotence, parse-invariance checks, unsafe-region no-op behavior.
- **Gate:** original formatter output equivalence for supported profiles/features; no source semantic damage in test fixtures.

### M6 — CLI and file I/O
- File/folder format, `--check`, `--diff`, overwrite flag, exit codes.
- Preserve BOM/encoding/line endings unless explicitly configured.
- **Gate:** deterministic behavior in scripts and CI, no writes in check/diff mode.

## Phase 3 — Integrations and tools

### M7 — IDE/VS Code
- Format document/selection/save through CLI or library bridge.

### M8 — AST, semantic analysis, refactoring, LSP (independent future)
- CST-to-AST lowering, symbol tables, references, types, linter and Language Server.
- No part of M8 may be a dependency for formatting.

## Order note

Developing a config/oracle comparison **test harness** in parallel with later parser work is useful, but it must not disrupt or complicate the initial lexer milestone.
