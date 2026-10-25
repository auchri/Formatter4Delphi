# Codex working instructions

1. For the initial lexer milestone, read **only** `docs/LEXER_HANDOFF.md` first. Consult `docs/LEXER_SPEC.md`, `docs/ARCHITECTURE.md`, `docs/TEST_PLAN.md`, and `docs/DECISIONS.md` only when extra detail is needed. These documents are design authority unless a Delphi 12.3 compiler test disproves a detail; record deviations in `docs/DECISIONS.md`.
2. **Implement only the active roadmap milestone.** Initially implement source/token/diagnostic foundations, the lexer, and DUnitX lexer tests. Do not implement CST parser, AST, formatter, `.config` reader, CLI, IDE plugin or generic abstractions that are not immediately needed.
3. Use Delphi 12.3-compatible Object Pascal and RTL, no VCL/FMX in core. Avoid dependencies except DUnitX for tests. Prefer Win64 test/build configuration initially; keep core platform-neutral.
4. Follow the declared public API shapes and file names where practical. If an API must change for correctness/compilation, update its specification and explain the change, not just the code.
5. Preserve **all** source UTF-16 code units, including invalid/unusual ones, in the lexer output. No token may overlap, be skipped, or be silently normalized. EOF is zero-length and excluded from reconstruction.
6. Token offsets are zero-based UTF-16 code-unit offsets in `[start, start + length)`; Delphi string indexing remains one-based. Never conflate source-character offsets with file byte offsets.
7. Every scanner iteration must make progress or reach EOF. Unterminated constructs produce a diagnostic and remain lossless.
8. A test which only round-trips is insufficient: add assertions for token *kinds, spans and diagnostics*; otherwise a single `Unknown` token would falsely pass.
9. Keep tests small and deterministic. Add regression tests for each lexical bug. Do not format source files while merely lexing them.
10. Run compilation and tests if Delphi is available. If not available, clearly state that they are unverified; do not claim they passed. Do not introduce invented build-tool commands.
11. Finish each task with: changed files, supported syntax, test status, known limitations, and recommended next small task.
12. Prioritize simple maintainable code over elaborate patterns. Avoid speculative multithreading, incremental parsing, green/red syntax infrastructure, AST and semantically aware keyword classification in the first lexer milestone.
