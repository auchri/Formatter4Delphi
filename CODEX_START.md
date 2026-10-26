# Current Codex entry point

Read `AGENTS.md`, `docs/CST_SPEC.md`, `docs/ARCHITECTURE.md` and
`docs/ROADMAP.md`. M1.0-M1.2 and M2.1-M2.5 lossless CST/declarations/postfix/class-record/property parser are implemented.
See `docs/M1_STATUS.md` and `docs/M2_STATUS.md` for actual scope and verification.

Implement only a newly authorized roadmap milestone. Preserve lexer APIs and
all original tokens; require hierarchical CST assertions as well as roundtrips.
Do not begin further grammar, AST, formatting, configuration, CLI or IDE integration
without a new task. Use Delphi 12.3-compatible pure RTL and DUnitX for tests.
Build all projects with Win64/Debug when available, execute both test runners,
verify fresh artifacts and report the exact toolchain and outstanding limits.

M2.5 is the active stopping point: ordinary/array properties, property specifiers,
both default forms and typeless redeclarations. Class properties, richer types
and generics remain opaque. Exact Delphi 12.3+ validation is still required;
see M2_STATUS.md. Do not start another grammar milestone without authorization.
