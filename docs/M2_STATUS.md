# M2.1 status — 2026-10-25

M2.1 adds a lossless CST and a deliberately small Delphi parser on top of the
unchanged M1.2 lexer. Implementation stops at M2.1.

## Changed files and classes

- `src/DelphiFormatter.Syntax/DelphiFormatter.Syntax.Kinds.pas`: `TSyntaxKind`.
- `src/DelphiFormatter.Syntax/DelphiFormatter.Syntax.Nodes.pas`:
  `TSyntaxElement`, immutable `TSyntaxNode`, original/missing `TSyntaxToken`.
- `src/DelphiFormatter.Syntax/DelphiFormatter.Syntax.Tree.pas`: `TSyntaxTree`,
  retained source/diagnostics, arena ownership and iterative leaf serialization.
- `src/DelphiFormatter.Parser/DelphiFormatter.Parser.Reader.pas`: `TTokenReader`.
- `src/DelphiFormatter.Parser/DelphiFormatter.Parser.Delphi.pas`: `TDelphiParser`
  with compilation-unit, expression and isolated-statement entry points.
- `tests/DelphiFormatter.Parser.Tests/`: standalone DUnitX DPR/DPROJ and fixture.
- `DelphiFormatter.groupproj`: parser test project and Build/Make/Clean targets.
- `AGENTS.md`, `CODEX_START.md`, `README.md`, `CST_SPEC.md`, `ARCHITECTURE.md`,
  `ROADMAP.md`, `TEST_PLAN.md`, `LEXER_HANDOFF.md`, `DECISIONS.md` and this report:
  concrete contracts, current scope and historical lexer-only entry guidance.

Lexer implementation, public APIs and existing tests are unchanged.

## Implemented syntax and behavior

- Identifiers, numeric/string/character-code literals (including adjacent
  string/code components), parentheses, unary + / - / not / @.
- All 20 basic binary operators in the Delphi precedence groups, associating
  equally ranked operators to the left; nested calls and argument lists.
- Identifier assignments, simple calls and parameterless identifier statements,
  empty statements, begin/end, nested if/then/else and nearest-if else binding.
- Minimal units, dotted unit names, uses clauses in interface/implementation,
  dotted used-unit names and optional `in 'filename'` entries.
- All original leaves, trivia and EOF retained in order. Missing tokens are
  zero-width; errors and unsupported regions preserve their original tokens.
- Independent tree lifetime after freeing the original lexer, read-only child
  arrays, one owning element arena, no parent pointers or recursive destruction.
- Deterministic diagnostics and contextual recovery. Nesting beyond 128 recursive
  expression/statement entries produces PAR004 and opaque recovery.

## Verification

Installed toolchain: **Delphi 12 Community Edition Update 1**, file version
**29.0.51961.7529**, at `C:\Program Files (x86)\Embarcadero\Studio\23.0`.
This is NOT Delphi 12.3. Exact Delphi 12.3+ validation remains outstanding.
The installed CE compiler restricts command-line compilation, so builds used
the actual IDE's **Build All Projects / Alle erzeugen** action with Win64/Debug.

Final build timestamp recorded before invocation: **2026-10-25 19:09:55 UTC**.
All three projects built successfully in 2.4 seconds, with no warnings or hints.
New artifact timestamps and SHA-256 values are recorded below. Every artifact
is newer than that timestamp; the parser EXE is also newer than all parser,
syntax and parser-test Pascal sources.

Executed after the final full build:

```powershell
& ./build/Win64/Debug/DelphiFormatter.Parser.Tests.exe
& ./build/Win64/Debug/DelphiFormatter.Lexer.Tests.exe
```

- Parser: **32 found, 32 passed**, 0 ignored/failed/errored/leaked; exit code 0.
- Lexer: **40 found, 40 passed**, 0 ignored/failed/errored/leaked; exit code 0.
- Both test Debug configurations enable range/overflow checks. The parser runner
  also enables RTL shutdown leak reporting; no leak dialog was observed.
- Parser coverage compares original leaf indices/kinds/spans and unique
  reachability, parent-span unions and exact serialization after lexer disposal.
  Tests assert real grammar hierarchy, every binary operator, mixed precedence,
  calls, blocks, dangling else, unit/uses shapes, diagnostic codes/spans and
  continued parsing after missing operands or an invalid semicolon before else.
- 300 seeded malformed token-sequence cases are parsed twice across all three
  entry modes and compared for structure and diagnostics. Another 200 inputs
  contain arbitrary UTF-16 code units. Additional tests cover 400 nested
  parentheses, 300-operator chains, repeated lifetimes, independent trees,
  directive/include fallback and ambiguous generic calls inside arguments.
- Project XML/reference checks and git whitespace checks complete the static
  verification. Local test logs are under ignored `build/Win64/Debug/M2.*.log`.

## PR #3 review corrections

- Replaced repeated significant-token suffix scans with one lazily built raw
  token index. Matching angle pairs are computed with a stack, ordinary trivia
  remains ignored only for lookahead, and the original barriers are preserved.
  Construction is O(tokens + source text), with O(tokens) parser-local storage.
  Successive comparison operands reuse the index. No reader state, tokens,
  lexer behavior or public API changed; no generic grammar was introduced.
- `True` / `False` deliberately remain identifier expressions in every casing;
  unreachable literal-branch checks were removed. The syntax/semantic boundary
  and Delphi predefined-constant rationale are recorded in `DECISIONS.md`.
- Four additional regression tests exercise a 1,025-opener nested generic
  candidate with substantial trivia, both incomplete at EOF and completed with
  a call; 768 comparisons plus a missing final operand; eight Boolean spellings
  and operator hierarchy; and resource/include/conditional directives in all
  three entry modes (including malformed UTF-16). Long candidate parses also
  compare deterministic trees. The common coverage helper checks every token,
  ordered spans and leaf serialization after disposing of the lexer result.
- Complete-document directive fallback is unchanged and documented. All prior
  error/missing/opaque, determinism, ownership and lifetime tests still pass.
- Review-fix logs are `build/Win64/Debug/M2.Review.Parser.Tests.log` and
  `build/Win64/Debug/M2.Review.Lexer.Tests.log` (ignored build outputs).
- Merge assessment: the identified review issues are addressed; local
  Win64/Debug validation passes. Exact Delphi 12.3 validation remains open.

## Known limitations

- No complete grammar or semantic/type validation. Assignment targets are simple
  identifiers; member/index/dereference/set expressions, advanced statements,
  declarations, classes/records, generics and method bodies are unsupported.
- Any compiler directive makes the complete input body opaque. Includes and
  conditional branches are preserved, never expanded/evaluated.
- Potential generic specialization calls are opaque rather than interpreted as
  relational expressions. This can conservatively protect a comparison spelling
  with the same token shape; M2.1 intentionally does not resolve it semantically.
- Unit declarations/routine sections are opaque and warn PAR003. Recovery is a
  bounded foundation, not compiler-equivalent recovery for all Delphi syntax.
- A recursion guard limits pathological nested input. Long flat binary chains
  remain supported; incremental parsing and performance profiling are deferred.
- Release, other platforms and exact Delphi 12.3 are not validated. There is no
  AST, formatter/layout engine, config support, CLI, LSP or IDE integration.

## Recommended next small milestone

First repeat this Win64/Debug build and both suites on exact Delphi 12.3.
Then authorize M2.2: basic const/var declarations and procedure/function
headers/bodies, retaining the same leaf-coverage and opaque-recovery contract.
No M2.2 implementation was started in this task.

## Fresh artifacts (UTC)

| Artifact | Bytes | Last write UTC |
| --- | ---: | --- |
| DelphiFormatter.Parser.Tests.exe | 4466176 | 2026-10-25 19:10:12.3279175 |
| DelphiFormatter.Lexer.Tests.exe | 4667904 | 2026-10-25 19:10:11.0074705 |
| DelphiFormatter.Lexer.bpl | 98816 | 2026-10-25 19:10:11.2840853 |
| DelphiFormatter.Lexer.dcp | 150746 | 2026-10-25 19:10:11.2845975 |

DelphiFormatter.Parser.Tests.exe SHA-256: `EFB177028480E8E9AD1C58C7E04919C2DEAB70AFBA6CA4FC5EA05166FBA4DE59`

DelphiFormatter.Lexer.Tests.exe SHA-256: `6280E1D3333404D0074A504F80A0CD0E6BA2C1A3ABF5B5C124377DF790AA51AA`
