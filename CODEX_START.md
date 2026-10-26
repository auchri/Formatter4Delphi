# Current Codex entry point

Read `AGENTS.md`, `docs/CST_SPEC.md`, `docs/ARCHITECTURE.md` and
`docs/ROADMAP.md`. M1.0-M1.2 and M2.1-M2.3 lossless CST/declarations/postfix parser are implemented.
See `docs/M1_STATUS.md` and `docs/M2_STATUS.md` for actual scope and verification.

Implement only a newly authorized roadmap milestone. Preserve lexer APIs and
all original tokens; require hierarchical CST assertions as well as roundtrips.
Do not begin further grammar, AST, formatting, configuration, CLI or IDE integration
without a new task. Use Delphi 12.3-compatible pure RTL and DUnitX for tests.
Build all projects with Win64/Debug when available, execute both test runners,
verify fresh artifacts and report the exact toolchain and outstanding limits.
