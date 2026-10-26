# Codex working instructions

1. Read `docs/CST_SPEC.md`, `docs/ARCHITECTURE.md`, and `docs/ROADMAP.md` first for parser work. Consult `docs/LEXER_SPEC.md`, `docs/TEST_PLAN.md` and `docs/DECISIONS.md` as needed. These are design authority unless a Delphi 12.3 compiler test disproves a detail; record deviations in `docs/DECISIONS.md`.
2. Implement only the explicitly active milestone. M2.7 measures real-world coverage using an independent read-only coverage/benchmark console tool; parser grammar remains at M2.6. Stop after M2.7; further grammar requires a new task. Class properties, generics, interfaces/helpers, nested types and variant parts remain opaque. No AST, formatter, configuration reader, product CLI, IDE plugin or incremental parsing.
3. Use Delphi 12.3-compatible Object Pascal and RTL, no VCL/FMX in core. DUnitX is the only test dependency. Prefer Win64/Debug and keep core platform-neutral.
4. Follow the declared public API shapes and filenames. Document necessary API changes. Preserve the lexer APIs and tests.
5. Preserve every UTF-16 code unit, including malformed ones. Every original token, including EOF, occurs exactly once in CST leaf order. Serialization traverses leaves; it must not return the stored source wholesale.
6. Spans are half-open zero-based UTF-16 code-unit spans. Delphi string indexing is one-based; file byte offsets are a separate concern. Missing tokens are zero-width and have no original index/text contribution.
7. Every scanner/parser loop must consume a token, exit or return. Ordinary syntax errors produce diagnostics and lossless recovery, never exceptions. Unsupported and directive-dependent syntax stays opaque.
8. Roundtrip alone is insufficient. Assert hierarchical node kinds, spans, operator grouping, diagnostics and exact original token order. A flat tree is not successful parsing.
9. Keep tests deterministic and add regressions for bugs. Test after freeing the lexer result and exercise repeated allocation/freeing. Do not format input files while parsing them.
10. Run real compilation and all tests when Delphi is available; verify fresh artifacts. Report the exact toolchain and distinguish 12 Update 1 from 12.3. Never claim unexecuted tests passed or rely on compiler exit code alone.
11. Finish with changed files/classes, supported syntax, actual test/build status, limitations and the next small task.
12. Prefer generic immutable syntax nodes and explicit trivia leaves. The tree owns an element arena; child and root references are borrowed. No parent pointers, class-per-production, green/red trees or speculative concurrency.
