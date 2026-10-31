# Codex session entry point

Read [design/README.md](design/README.md) first, then [requirements](design/docs/spec/01_PRODUCT_REQUIREMENTS.md) and [canonical API/data contracts](design/docs/spec/14_CONTRACTS.md). Other design/spec chapters and ADRs elaborate the target. Follow [AGENTS.md](AGENTS.md) and [contribution rules](design/CONTRIBUTING_IMPLEMENTATION.md). The [implementation plan](design/docs/spec/09_IMPLEMENTATION_PLAN.md) is a plan, not authorization.

**No implementation milestone is active.** Work only on the user's explicitly commissioned scope. Do not begin parser grammar, formatter, config, IO/CLI or other implementation merely because A0 describes it. A0 target APIs are not existing runtime capabilities.

## Actual starting point

Implemented: M1 lexer; M2.1–M2.6 lossless CST expressions/postfix, basic declarations/routines/classes/records/properties and control flow; M2.7 independent coverage/analyzer tooling. Unsupported syntax remains opaque. No production formatter, native config reader, product CLI, AST or include resolver.

[docs/CST_SPEC.md](docs/CST_SPEC.md), [docs/LEXER_SPEC.md](docs/LEXER_SPEC.md), [M1 status](docs/M1_STATUS.md), [M2 status](docs/M2_STATUS.md) and [coverage method](docs/PARSER_COVERAGE.md) describe implementation/evidence. Historical roadmap/milestone text under docs/ is not a competing target or a new task. Exact Delphi 12.3 verification remains open; old CE Update 1 results must stay identified as such.

PR #10 (M2.8 directive pilot) is independent of PR #11 (A0 architecture/integration). Neither its code nor its acceptance is implied by A0. Before implementation, inspect current main/PR status and follow the [baseline strategy](design/docs/spec/12_CURRENT_CODE_AUDIT.md). No automatic merge or cherry-pick of #10.

## Before changing files

Inspect status and preserve independent changes. Name requirement/test IDs, affected owners and acceptance criteria. Preserve lexer APIs, original tokens, UTF-16 spans, arena ownership and pinned corpus. For code, run scope-appropriate builds/tests and verify fresh artifacts; for documentation run the read-only validator:

~~~powershell
pwsh -NoProfile -File scripts/ValidateDesignDocs.ps1
~~~

It checks document structure/references, not semantic correctness of architecture or unimplemented APIs. Report actual checks and stop at the commissioned boundary.
