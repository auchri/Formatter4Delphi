# Current Codex entry point

Read AGENTS.md, docs/CST_SPEC.md, docs/ARCHITECTURE.md, docs/ROADMAP.md and
docs/M2_8_DIRECTIVES.md. M2.8 is the separately authorized directive-aware safe
pilot; all other grammar remains at M2.6. Stop after M2.8. AST, formatting,
configuration, product CLI, IDE integration and further grammar require a new task.

Preserve the lexer/reader/public parser APIs, original token order, UTF-16 spans
and arena ownership. Require hierarchical assertions and lossless roundtrips
after lexer disposal. Never evaluate conditional branches or expand includes.
Unknown/unsafe contexts retain complete-input fallback. Exact pilot boundaries
and the finite directive whitelist are documented in docs/M2_8_DIRECTIVES.md.

Actual validation: docs/M2_STATUS.md. Paired measurements and concrete examples:
reports/m2_8/comparison.md and reports/m2_8/examples.md. Keep the pinned M2.7
manifest, hashes, archived fixtures and decoding policy unchanged when comparing.

Use Delphi 12.3-compatible pure RTL and DUnitX. Build all five projects with
Win64/Debug, execute all three runners and verify fresh executable/corpus DCUs.
Reopen the group after changing DPR/DPROJ files: a loaded IDE can retain stale
project source. Delphi 12 CE Update 1 is available; it is not Delphi 12.3.
