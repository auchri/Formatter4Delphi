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
  Exact 12.3 validation remains open; see `M1_STATUS.md`. M2.1 follows below.

### M1.3 — Lexer corpus and stabilization
- Real `.pas`, `.dpr`, `.dpk`, `.inc` fixture samples; fuzz/property tests.
- Profile allocations/performance on representative source. Optimize only known bottlenecks.
- **Gate:** documented lexical syntax coverage; deterministic roundtrips and diagnostics; stable public contract.

### M2.1 — Lossless CST foundation and basic Delphi parser
- Syntax nodes, tree, builder, token reader, error/missing/opaque leaves.
- Basic expressions/calls with Delphi operator groups; assignments, blocks, if/else; minimal units and uses clauses. Unsupported declarations and directive-bearing input stay opaque.
- **Gate:** exact CST roundtrip and correct tree shape; no discarded original tokens under error recovery.

- Implemented scope and actual build/test evidence: `M2_STATUS.md`.
- M2.1 is complete; M2.2 was separately authorized.

### M2.2 — Basic declarations and routine bodies (completed)
- Implemented: const/var sections, qualified type/routine names, parameter groups/defaults, local declarations and existing statement blocks.
- Resource directives at safe section boundaries remain explicit; conditional/include directives retain complete-input fallback.
- Nested unsupported types and procedural signatures remain opaque with contextual recovery.
- Acceptance evidence: `M2_STATUS.md`. Exact Delphi 12.3 validation remains open.

### M2.3 — Member/index/dereference expressions (completed)
- Iterative mixed postfix chains, syntactic assignment targets and member call statements.
- Lossless recovery, qualified generic fallback and compiled postfix corpus.
- Evidence: `M2_STATUS.md`. Exact Delphi 12.3 validation remains open.

### M2.4 — Class and record declarations (completed)
- Type sections and individual type wrappers; classical classes/records, simple
  ancestors, visibility sections, fields and body-free method declarations.
- Properties, richer types, generics, interfaces/helpers, class members, nested
  types and variant tails retain opaque protection. No new statement grammar.
- Actual build/test evidence and remaining toolchain limitation: M2_STATUS.md.

### M2.5 — Lossless property declarations (completed)
- Ordinary/read-only/write-only properties; read/write/stored/index/default/
  nodefault and simple implements clauses; typeless redeclarations.
- Array property parameters and the distinct trailing `; default;` marker.
- Conservative opaque type/constant fragments and class-property fallback;
  contextual recovery, exact leaf/span/lifetime invariants and compiled corpus.
- Actual validation and toolchain limits: M2_STATUS.md. M2.6 was authorized separately.

### M2.6 — Control-flow statements (completed grammar scope)
- For/to/downto, for-in, while, repeat/until, case labels/ranges/else,
  try/finally, catch-all except, on handlers with optional else, simple raise.
- Contextual lists, separator/else ownership, hard routine/unit boundaries,
  unchanged nesting guard and opaque protection for unsupported fragments.
- Compiled ControlFlowCorpus and hierarchy/recovery/stress/lifetime tests.
- Actual validation and version limitations: M2_STATUS.md. Grammar stops here.

### M2.7 — Real-world coverage and corpus analysis (analysis stopping point)
- Independent Delphi console analyzer, strict/reproducible decoding, original
  token-length coverage, iterative lifetime/lossless validation and repetitions.
- Pinned DUnitX/Indy/DelphiMVCFramework/mORMot2 corpus plus separate archived
  internal fixtures; stratified deterministic selection and source hashes.
- JSON/CSV/Markdown reports, directive-fallback groups, opaque inventory/ranking,
  high-resolution timing medians and an RTL retained-tree heap observation.
- Method/tests/actual measurements: `PARSER_COVERAGE.md`, `M2_STATUS.md` and
  `reports/m2_7/coverage.md`. No grammar or formatter changes. Stop after M2.7.

### Next small task (proposal only, requires new authorization)
- Validate the suite and all compiled corpora on exact Delphi 12.3+.
- M2.8 proposal from the measured corpus: directive-aware lossless design/pilot;
  M2.9 proposal: resource-string sections, then remeasure narrow declaration gaps.
  See `PARSER_COVERAGE.md` and `M2_STATUS.md`; neither is implemented here.
- A subsequent narrow grammar milestone must be authorized separately.

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
