# M2.7 / M2.8 paired corpus comparison

The manifest and all paths, commits, byte counts and SHA-256 values are unchanged. Strict encoding policy and three repetitions match. Every table uses the same files successfully analyzed in both runs. Internal fixtures remain separate from the external corpus. No encoding failures enter coverage denominators.

Paired successful files: 161 total, 154 external. Attempted: 167 total, 160 external. Both runs have six external encoding failures; analyzer exit 1 is the expected partial-input result, not a parser/invariant failure.

| Repository | Paired files | Structured % before | Structured % after | Opaque % before | Opaque % after | Directive fallbacks before / after |
|---|---:|---:|---:|---:|---:|---:|
| external | 154 | 3.596240 | 3.827748 | 96.057847 | 95.644739 | 133 / 130 |
| DUnitX | 40 | 1.503982 | 1.503982 | 98.496018 | 98.496018 | 36 / 36 |
| Indy | 35 | 12.294543 | 12.294543 | 87.477542 | 87.477542 | 26 / 26 |
| DelphiMVCFramework | 39 | 4.532334 | 5.176350 | 94.599746 | 93.450548 | 31 / 28 |
| mORMot2 | 40 | 0.000000 | 0.000000 | 100.000000 | 100.000000 | 40 / 40 |
| internal | 7 | 83.866109 | 94.711297 | 16.133891 | 5.121339 | 1 / 0 |

All percentages sum original UTF-16 code units before division; directives/trivia remain excluded. Conditional-region nodes and their contents count as opaque. Error takes priority. A reduced fallback count alone does not imply more recognized code.

| Paired external metric | M2.7 | M2.8 |
|---|---:|---:|
| codeUnits | 3927296 | 3927296 |
| structuredCodeUnits | 141235 | 150327 |
| opaqueCodeUnits | 3772476 | 3756252 |
| errorCodeUnits | 13585 | 20717 |
| lexerDiagnostics | 0 | 0 |
| parserDiagnostics | 775 | 1074 |
| parserErrors | 372 | 616 |
| Files with nonzero structured code | 20 | 22 |
| Unit hierarchies retained | 21 | 24 |
| Lossless checks passed | 154 | 154 |
| Determinism checks passed | 154 | 154 |

The old report did not count unit nodes directly: the baseline unit-hierarchy count is inferred from its non-fallback compilation trees (nodes > 2); M2.8 counts skUnitDeclaration directly. This is hierarchy retention, not a claim that all descendants are supported or error-free.

Recognized protected conditional islands: 1 across paired files, 131 UTF-16 units including leading trivia/directives. External islands: 0. All (100%) accepted branch contents remain opaque; no branch is interpreted as active. Whole-file fallbacks protect additional conditionals, but this island count does not pretend to count or locate those hidden branches.

## Runtime under comparable conditions

Before: Delphi 12 CE Update 1 29.0.51961.7529 (not 12.3); Win64 Debug, range/overflow checks; Windows NT 10.0.26300; AMD64 Family 25 Model 97 Stepping 2; 12 logical processors; UTF-8 strict; 3 repetitions

After: Delphi 12 CE Update 1 29.0.51961.7529 (not 12.3); Win64 Debug, range/overflow checks; Windows NT 10.0.26300; AMD64 Family 25 Model 97 Stepping 2; 12 logical processors; UTF-8 strict; 3 repetitions

| Sum over paired external files | Before ms | After ms |
|---|---:|---:|
| lexerMs | 136.267500 | 149.085100 |
| parserMs | 190.345300 | 270.448900 |
| analysisMs | 1065.454900 | 1215.591700 |
| totalMs | 3290.102700 | 3748.533900 |

lexerMs/parserMs/analysisMs sum per-file medians; totalMs sums complete per-file repeated runs including I/O. Same installed compiler, Debug checks, host and repeat count; runs are sequential historical observations with ordinary scheduling/cache variation, not controlled performance guarantees. The directive prepass and newly exposed CST construction add work; no timing threshold is asserted.

## Encoding exclusions

- DelphiMVCFramework: `build/coverage-corpora/DelphiMVCFramework/sources/MVCFramework.BloomFilter.pas` — encoding_ambiguous in both runs.
- Indy: `build/coverage-corpora/Indy/Lib/Core/IdContext.pas` — encoding_ambiguous in both runs.
- Indy: `build/coverage-corpora/Indy/Lib/Core/IdCustomTCPServer.pas` — encoding_ambiguous in both runs.
- Indy: `build/coverage-corpora/Indy/Lib/Protocols/IdCustomHTTPServer.pas` — encoding_ambiguous in both runs.
- Indy: `build/coverage-corpora/Indy/Lib/Protocols/IdDNSServer.pas` — encoding_ambiguous in both runs.
- Indy: `build/coverage-corpora/Indy/Lib/Protocols/IdFTPCommon.pas` — encoding_ambiguous in both runs.

## Parser diagnostic changes

- `build/coverage-corpora/DelphiMVCFramework/sources/MSHeap.pas`: errors 0 -> 22; added 22, removed 0.
- `build/coverage-corpora/DelphiMVCFramework/sources/MVCFramework.ActiveRecordController.pas`: errors 0 -> 77; added 77, removed 0.
- `build/coverage-corpora/DelphiMVCFramework/sources/MVCFramework.DotEnv.Parser.pas`: errors 0 -> 145; added 145, removed 0.
- `build/coverage-corpora/Formatter4Delphi/tests/Fixtures/LexicalCorpus.pas`: errors 0 -> 3; added 3, removed 0.

Exact new/removed error code, severity, message and UTF-16 span records are in [diagnostic-changes.json](diagnostic-changes.json). Removing whole-input protection exposes existing unsupported grammar and recovery diagnostics; these are measured parser errors, not proof that upstream source fails to compile. No foreign units were compiled. Warning-message/span refinements also identify include/unknown blockers directly; the complete original diagnostics remain in each report.

## Remaining complete-input blockers

- include: 118 files (parser diagnostic evidence; one priority category per fallback).
- unknown-directive: 6 files (parser diagnostic evidence; one priority category per fallback).
- unproven-context: 6 files (parser diagnostic evidence; one priority category per fallback).

Include/unknown/malformed categories are explicit parser reasons, not raw keyword guesses. Other contexts are not automatically labeled as type/method/declaration positions. Manual contextual evidence, five improved source excerpts and at least five remaining problem cases are in [examples.md](examples.md).
