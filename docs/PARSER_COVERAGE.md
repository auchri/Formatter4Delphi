# Reproducible parser coverage — M2.7 baseline and M2.8 comparison

M2.7 was an analysis milestone with M2.6 grammar. M2.8 adds the narrow directive pilot documented below; reports/m2_7 remains the immutable baseline.
The existing scanner API is `TDelphiLexer.Tokenize`, not `Scan`. The analyzer uses
the public `TDelphiLexResult`, `TSyntaxTree`, generic node/token APIs, kinds,
UTF-16 spans and diagnostic value records without changing them.

## Reproduction

From the repository root, on Windows with Git and PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/FetchCoverageCorpus.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/TestCoverageCorpus.ps1 -CheckPinnedFiles
```

Open `DelphiFormatter.groupproj` in Delphi, select Win64/Debug and Build All
Projects. If an already loaded IDE retains the old group, reopen it or open and
build both new DPROJ files separately. Require fresh executable/DCU timestamps.
CE Update 1 does not support command-line compilation; a full licensed compiler
may use MSBuild with its configured RAD Studio environment. This is not evidence
of exact Delphi 12.3 compatibility.

```powershell
build/Win64/Debug/DelphiFormatter.Lexer.Tests.exe --exitbehavior:Continue
build/Win64/Debug/DelphiFormatter.Parser.Tests.exe --exitbehavior:Continue
build/Win64/Debug/DelphiFormatter.Coverage.Tests.exe --exitbehavior:Continue
build/Win64/Debug/DelphiFormatter.Coverage.exe --manifest tests/CoverageCorpus/manifest.json --output reports/m2_8 --repeat 3 --environment "record compiler/version, platform, configuration, OS and host here"
```

Inputs may instead be `--file path.pas` or `--directory path` (recursive `.pas`).
Exactly one input mode is required. `--include` / `--exclude` accept one filename
glob each; directory enumeration and final processing order are deterministic.
Defaults: two repetitions, strict UTF-8 without BOM, output `reports/m2_7`.
`--codepage 1252` explicitly selects Windows-1252 for BOMless files; a BOM always
overrides it. Such a run must remain a separately labeled comparison. No defines
are evaluated, files formatted, includes expanded, or foreign units compiled.

Exit codes: **0** completed analysis with lossless guarantees (opaque/syntax or
lexical diagnostics are allowed); **1** input/configuration/hash/I/O/decode
failure (partial reports are still produced for per-file failures); **2** parser
exception, nondeterminism or invariant violation. A report-write/configuration
failure can prevent output and returns 1. No artificial timeout is used.

## Corpus and provenance

`tests/CoverageCorpus/manifest.json` pins four actual repository commits and
40 files each. Initial creation used `FetchCoverageCorpus.ps1 -Initialize`;
initialization refuses to overwrite an existing manifest. Ordinary runs use only
the pinned versions, verify checked-out HEAD and every selected size/SHA-256.
An initial sandbox DNS failure was resolved by authorized network execution;
all four repositories were downloaded successfully. No external-run blocker is
being claimed.

Candidates are recursive `.pas` under DUnitX `Source`, Indy `Lib`, MVC `sources`
and mORMot2 `src`. Size strata: small <16 KiB, medium <64 KiB, large otherwise.
Directive-candidate strata: none, 1–9, >=10 raw `{$`/`(*$` occurrences. This is a
selection heuristic and can match comments/strings; actual directive metrics
come exclusively from lexer tokens. Stratified groups and paths use ordinal
sorting, and selection takes one file from each nonempty group per round until
40 are selected. No random seed or favorable coverage filter is used. Categories
do not claim that size/directive density predicts syntactic complexity.

Git's local `core.autocrlf=false; core.eol=lf` is explicit; upstream attributes
still apply. Exact checkout hashes detect drift. Seven existing `tests/Fixtures`
units are separately snapshotted using `git archive` at `internalCommit`, under
ignored `build/coverage-corpora/Formatter4Delphi`. This avoids editing input
files or depending on working-copy line endings. Paths/hashes are fixed in the
manifest. The normal parser suite still compiles/reads the original fixtures.

All candidates are eligible, including compatibility code. `fpc-path` marks
obvious FPC filename/path components; other units are `unreviewed`, not certified
Delphi-12.3 units. Conditional FPC branches may exist in any project. Reported
coverage measures preservation/structural recognition, not compiler acceptance.
The sample is deliberately stratified, not a statistically unbiased estimate of
each whole repository. Comparisons must keep manifest version and decode/build
policy fixed.

### Licenses

Provenance and commit-specific links are in the manifest/report. DUnitX and
DelphiMVCFramework carry Apache-2.0 licenses (`LICENSE.txt` / `License.txt`).
Indy offers Indy Modified BSD or MPL-1.1 (`LICENSE.md`, `LICENSE-IndyBSD`).
mORMot2 offers MPL-1.1-or-later/GPL-2.0-or-later/LGPL-2.1-or-later with the stated
linking exception (`LICENCE.md`); credit: Arnaud Bouchez / https://synopse.info.
Indy credit: Chad Z. Hower and the Indy Pit Crew / https://www.indyproject.org/.
These license identifiers summarize upstream notices; individual vendored units
may carry their own notices. Consult the pinned upstream source before reuse.

No foreign source tree is committed or linked into the analyzer executable.
Reports contain at most 160 UTF-16 units per opaque-region excerpt for locating
the measured region. Retain provenance/notices when distributing extracts; the
reports do not relicense upstream material. Local downloads retain all upstream
license files. Full source redistribution is outside this workflow.
Copies of upstream license notices, including the vendored JsonDataObjects MIT
notice, accompany the report excerpts under `tests/CoverageCorpus/notices/`.

## Decoding

Read bytes once, without trimming, newline conversion or normalization. BOMs
identify UTF-8 and UTF-16 LE/BE; UTF-32 is explicitly rejected. Odd UTF-16 byte
counts fail. UTF-16 is decoded as exact pairs, preserving isolated surrogates.
BOMless input follows the declared UTF-8 policy or explicit numeric codepage,
never the machine ANSI default. Decode/re-encode must reproduce every payload
byte. Invalid/ambiguous bytes yield `decode_failed` / `encoding_ambiguous` and
are excluded from all coverage denominators. A valid UTF-8 decoding is a policy,
not proof of the author's intended encoding. File bytes and decoded UTF-16 code
units are separate report fields; the BOM is not a parser character.

## Coverage definition and recovery priority

Every original token including EOF is checked once, in leaf order. For each
token, its UTF-16 length is assigned to exactly one category:

1. **error**: under `skError`, under an immediate owner with an `skError` or
   missing-token child, or intersecting a nonempty error-severity diagnostic;
2. **opaque**: under at least one `skOpaqueRegion`, unless error takes priority;
3. **structured**: otherwise.

The immediate damaged owner taints its descendants; damage does not propagate
up to all ancestors and automatically classify every unit as an error. This is
a deliberately conservative recognition metric, not a formal validity proof.
Warning-only PAR003 does not itself turn opaque code into error code.

Main denominator **codeUnits** excludes ordinary whitespace, newlines, comments,
compiler directives and EOF. `nonTriviaTokens` includes directives and excludes
EOF; `codeTokens` excludes directives as well. Main coverage is `100 * structuredCodeUnits /
codeUnits`. Opaque and error percentages use the identical denominator, so the
three mutually exclusive counts sum exactly to codeUnits. Directive tokens and
trivia have separate token/unit counts. `*IncludingTriviaPercent` uses all decoded
source units (including directives); its three categories also partition the
source. Missing tokens and EOF contribute no length. A zero denominator is
JSON `null` / Markdown n/a, never fabricated 100% coverage.

`tokenCategories` is run-length encoding over original lexer indices, including
EOF: `{firstToken,count,category}`. It makes every original token's classification
recoverable without writing a potentially enormous token table. Syntax node
counts are descriptive; they never weight coverage. A flat original-token tree
does not establish recognition; the unchanged parser's hierarchy is covered by
the existing parser suite.

Complete opacity means the compilation root has only one opaque descendant
node (no grammar nodes), containing all non-trivia code. Trailing trivia may be
root leaves; requiring the opaque span to equal source length would miss normal
fallbacks. A complete opaque file with directive tokens is separately labeled
`directiveFallback`, not attributed to unsupported type/statement grammar.

Repository/size/directive aggregates sum **units before division**. Internal
fixtures and `external` have separate rows; the empty repository label means
all attempted inputs. Decode failures belong to attempt counts but neither a
valid-directive group nor a coverage denominator.

## Lossless checks, diagnostics and determinism

An independent lexer result is created after the parse's lexer has been freed.
Iterative traversal checks unique element reachability (cycles/duplicate nodes
fail), valid/ordered contained spans, original leaf indices/kinds/spans against
every token including EOF, contiguous token source coverage, zero-width missing
tokens and exact leaf-based serialization. Each tree is freed between runs.
Repeated analyses compare structure hashes, complete diagnostic JSON, regions,
category runs and all untimed metrics. With one repetition, `deterministic=false`
means it was not checked, not that nondeterminism was observed.

Per-file statuses are `structured`, `opaque`, `syntax_diagnostics` (parser error
severity), `lexer_error`, `parser_exception`, `invariant_failed`, `file_error`,
`corpus_file_error`, `decode_failed`, `encoding_ambiguous`. Node/diagnostic flags
retain multiple conditions even where status has a single precedence. Failed
rows have no invented coverage. Ordinary unsupported syntax is not a critical
failure. A parser exception or missing original token is critical.

## Opaque inventory and ranking

Each region records half-open offsets/length, 1-based line/UTF-16 column (CRLF,
CR and LF handled), immediate parent kind, overlapping diagnostic codes and a
bounded excerpt. Parent context supports only broad heuristic categories:
`unsupported-type`, `unsupported-statement`, `method-directives`; a first
significant reserved `resourcestring` token in a unit-level region is labeled
`resource-string-section` (tested against keyword-in-comment false positives). Complete
directive fallback has its own category. Everything else is `unknown`. No single
keyword is used to assert generics, interfaces or attribute grammar.

Inventory entries may nest. Coverage never double-counts nested spans. The
cause ranking sums only outermost opaque extents, including trivia/error units,
and orders by affected extent, distinct files, occurrences, then category name.
It is an opportunity estimate, not the claim that implementing the category
will recover all those characters. Directive fallback is a separate cause and
masks inner grammar gaps. Detailed generics/interface/attribute prevalence is
therefore not measurable from these whole-file fallbacks.

Effort/relevance estimates (recommendations, not measured facts):

| Cause | Expected effort | Formatter relevance / next action |
|---|---|---|
| Directive fallback | High; design branches/includes without preprocessing | Highest gate to meaningful real-world structural coverage |
| Resource-string section | Low–medium; extends declaration sections | Largest directly recognizable non-directive gap in this sample |
| Unsupported types | Medium–high; narrow scope first | High; remeasure after directives before selecting aliases/generics/interfaces |
| Unsupported statements | Medium; one construct at a time | High within method bodies; choose from verified context/examples |
| Method directives | Low–medium for explicit finite syntax | Useful, but lower impact than whole-file fallback |
| Unknown | Unknown until manual/minimal reproduction | Investigate; do not invent a grammar ranking |

## Performance and output schema

`TStopwatch` measures lexer and parser independently. Each is reported as a
median over repetitions; tokens/s uses their combined median durations.
`analysisMs` is the median of parse plus validation, independent re-lexing,
hashing and serialization. `totalMs` includes I/O/decoding and all repetitions.
No warm-up is discarded; timing varies with scheduling/caches. Compare the same
compiler/build/host and keep Debug/Release results separate. Debug range and
overflow checking stay enabled. The report itself may dominate tiny-file times.

`retainedTreeHeapBytes` observes the maximum RTL allocated-heap delta after
parsing and disposing the lexer, before validation. It is useful for large-tree
scale, but is not peak allocation, process working set or proof of no leaks.
The analyzer intentionally retains all JSON result rows until report writing.
No parser optimization or heap profiler is part of M2.7.

`coverage.schema.json` is the version-1 JSON Schema. Additional properties are
allowed for descriptive metrics. Successful file rows include source sizes,
token/node/diagnostic counts, category units/percentages, directive flags,
inventory/diagnostic arrays, deterministic structure hash, repetitions and
timings. Failure rows require identity, encoding and status, optionally exception
text. `summaries` contains weighted rows for each repository/group;
`opaqueRanking` contains outermost affected extent/files/occurrences. Numeric
percentages/timings use JSON decimal notation independently of OS locale.
CSV uses fixed columns, quoting/doubled quotes and one logical row per file.
The writers are deterministic for identical data, but actual timing/heap
observations intentionally vary between executions.

Actual results and the final milestone recommendation follow in `M2_STATUS.md`
and the checked-in report. Exact Delphi 12.3+, Release, other platforms, full
upstream builds and formatter safety remain unvalidated. Stop after M2.7.

## M2.8 — directive-aware safe pilot (supersedes historical directive policy)

M2.8 is separately authorized. Other grammar remains at M2.6; stop after M2.8.
See [M2_8_DIRECTIVES.md](M2_8_DIRECTIVES.md) for the exact finite classifier,
linear stack index, 32-level guard, PAR005 diagnostics, supported UnitSection
boundaries and deliberately narrow branch-envelope proof. Switches remain
explicit skDirective nodes. Appended kind skConditionalDirectiveRegion (56)
contains a completely opaque protected child; the analyzer protects both kinds.
Includes, unknown directives and directives inside productions retain complete
input fallback. No branches are evaluated and no member/statement contexts or
new type grammar are enabled. A future formatter must preserve these barriers.

The unchanged pinned corpus comparison, actual diagnostics and runtime results
are recorded in [comparison.md](../reports/m2_8/comparison.md); concrete source
examples and limitations are in [examples.md](../reports/m2_8/examples.md).
DirectiveCorpus is compiled by the parser test runner but does not change the
pinned manifest. The suite adds eight parser methods and one coverage method.
Delphi 12 CE Update 1 validation is distinct from still-open exact Delphi 12.3.