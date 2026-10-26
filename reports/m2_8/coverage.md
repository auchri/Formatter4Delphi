# M2.7 parser coverage

## Executive summary

Files attempted: 167; lossless validated: 161; weighted structural coverage: 3.97%.

Structural representation does not establish formatter safety. External and internal baselines are separate repository rows. Invalid/ambiguous input is excluded from coverage denominators.

## Toolchain and environment

Delphi 12 CE Update 1 29.0.51961.7529 (not 12.3); Win64 Debug, range/overflow checks; Windows NT 10.0.26300; AMD64 Family 25 Model 97 Stepping 2; 12 logical processors; UTF-8 strict; 3 repetitions

Times use TStopwatch; lexer/parser medians exclude validation. analysisMs includes independent re-lexing, traversal, hashing and serialization. totalMs includes I/O and every repetition. retainedTreeHeapBytes is the maximum RTL allocated-heap delta after parse and lexer disposal, before validation; it is neither peak memory nor a leak measurement. Memory profiling is not performed.

## Pinned repositories and provenance

- DUnitX `0bc0bcb538ad2bb9c2c2f59f625ab5aac665b5a0` - Apache-2.0 - https://github.com/VSoftTechnologies/DUnitX/tree/0bc0bcb538ad2bb9c2c2f59f625ab5aac665b5a0
- Indy `bd38a62c0089e5e40eeb00569a09b8a8410b8d7d` - Indy Modified BSD / MPL-1.1 (dual) - https://github.com/IndySockets/Indy/tree/bd38a62c0089e5e40eeb00569a09b8a8410b8d7d
- DelphiMVCFramework `8fed954c457a3e43f9fc3ddd43b0b1e979a14dd8` - Apache-2.0 - https://github.com/danieleteti/delphimvcframework/tree/8fed954c457a3e43f9fc3ddd43b0b1e979a14dd8
- mORMot2 `fc4c033da5520d25221025efb78fcc4ea55a55a0` - MPL-1.1 / GPL-2.0-or-later / LGPL-2.1-or-later (tri-license) - https://github.com/synopse/mORMot2/tree/fc4c033da5520d25221025efb78fcc4ea55a55a0

## Coverage by repository, size and directives

| Repository | Group | Files | Valid | Directive files | Complete opaque | Other opaque | Structured % | Opaque % | Error % |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
|  | all | 167 | 161 | 135 | 130 | 25 | 3.97 | 95.51 | 0.53 |
|  | without-directives | 26 | 26 | 0 | 0 | 21 | 64.14 | 29.88 | 5.98 |
|  | with-directives | 135 | 135 | 135 | 130 | 4 | 0.28 | 99.53 | 0.19 |
|  | complete-opaque | 130 | 130 | 130 | 130 | 0 | 0.00 | 100.00 | 0.00 |
|  | other-opaque | 25 | 25 | 4 | 0 | 25 | 52.29 | 37.46 | 10.25 |
|  | small | 76 | 74 | 55 | 51 | 18 | 11.57 | 85.16 | 3.27 |
|  | medium | 53 | 52 | 47 | 46 | 6 | 4.64 | 94.57 | 0.79 |
|  | large | 38 | 35 | 33 | 33 | 1 | 2.97 | 96.87 | 0.16 |
| DelphiMVCFramework | all | 40 | 39 | 31 | 28 | 11 | 5.18 | 93.45 | 1.37 |
| DelphiMVCFramework | without-directives | 8 | 8 | 0 | 0 | 8 | 64.14 | 23.57 | 12.28 |
| DelphiMVCFramework | with-directives | 31 | 31 | 31 | 28 | 3 | 0.69 | 98.76 | 0.54 |
| DelphiMVCFramework | complete-opaque | 28 | 28 | 28 | 28 | 0 | 0.00 | 100.00 | 0.00 |
| DelphiMVCFramework | other-opaque | 11 | 11 | 3 | 0 | 11 | 59.14 | 25.17 | 15.69 |
| DelphiMVCFramework | small | 14 | 13 | 8 | 6 | 7 | 20.96 | 64.61 | 14.43 |
| DelphiMVCFramework | medium | 13 | 13 | 11 | 10 | 3 | 10.95 | 86.17 | 2.88 |
| DelphiMVCFramework | large | 13 | 13 | 12 | 12 | 1 | 3.10 | 96.51 | 0.39 |
| DUnitX | all | 40 | 40 | 36 | 36 | 4 | 1.50 | 98.50 | 0.00 |
| DUnitX | without-directives | 4 | 4 | 0 | 0 | 4 | 41.20 | 58.80 | 0.00 |
| DUnitX | with-directives | 36 | 36 | 36 | 36 | 0 | 0.00 | 100.00 | 0.00 |
| DUnitX | complete-opaque | 36 | 36 | 36 | 36 | 0 | 0.00 | 100.00 | 0.00 |
| DUnitX | other-opaque | 4 | 4 | 0 | 0 | 4 | 41.20 | 58.80 | 0.00 |
| DUnitX | small | 30 | 30 | 26 | 26 | 4 | 5.06 | 94.94 | 0.00 |
| DUnitX | medium | 9 | 9 | 9 | 9 | 0 | 0.00 | 100.00 | 0.00 |
| DUnitX | large | 1 | 1 | 1 | 1 | 0 | 0.00 | 100.00 | 0.00 |
| external | all | 160 | 154 | 133 | 130 | 22 | 3.83 | 95.64 | 0.53 |
| external | without-directives | 21 | 21 | 0 | 0 | 19 | 63.45 | 30.45 | 6.10 |
| external | with-directives | 133 | 133 | 133 | 130 | 3 | 0.25 | 99.56 | 0.19 |
| external | complete-opaque | 130 | 130 | 130 | 130 | 0 | 0.00 | 100.00 | 0.00 |
| external | other-opaque | 22 | 22 | 3 | 0 | 22 | 51.68 | 37.91 | 10.41 |
| external | small | 69 | 67 | 53 | 51 | 15 | 9.69 | 86.97 | 3.34 |
| external | medium | 53 | 52 | 47 | 46 | 6 | 4.64 | 94.57 | 0.79 |
| external | large | 38 | 35 | 33 | 33 | 1 | 2.97 | 96.87 | 0.16 |
| Indy | all | 40 | 35 | 26 | 26 | 7 | 12.29 | 87.48 | 0.23 |
| Indy | without-directives | 9 | 9 | 0 | 0 | 7 | 65.48 | 33.31 | 1.21 |
| Indy | with-directives | 26 | 26 | 26 | 26 | 0 | 0.00 | 100.00 | 0.00 |
| Indy | complete-opaque | 26 | 26 | 26 | 26 | 0 | 0.00 | 100.00 | 0.00 |
| Indy | other-opaque | 7 | 7 | 0 | 0 | 7 | 39.04 | 58.86 | 2.09 |
| Indy | small | 15 | 14 | 9 | 9 | 4 | 19.03 | 78.86 | 2.12 |
| Indy | medium | 15 | 14 | 11 | 11 | 3 | 7.59 | 92.26 | 0.15 |
| Indy | large | 10 | 7 | 6 | 6 | 0 | 14.69 | 85.31 | 0.00 |
| internal | all | 7 | 7 | 2 | 0 | 3 | 94.71 | 5.12 | 0.17 |
| internal | without-directives | 5 | 5 | 0 | 0 | 2 | 97.39 | 2.61 | 0.00 |
| internal | with-directives | 2 | 2 | 2 | 0 | 1 | 85.50 | 13.75 | 0.74 |
| internal | complete-opaque | 0 | 0 | 0 | 0 | 0 | n/a | n/a | n/a |
| internal | other-opaque | 3 | 3 | 1 | 0 | 3 | 90.16 | 9.53 | 0.31 |
| internal | small | 7 | 7 | 2 | 0 | 3 | 94.71 | 5.12 | 0.17 |
| internal | medium | 0 | 0 | 0 | 0 | 0 | n/a | n/a | n/a |
| internal | large | 0 | 0 | 0 | 0 | 0 | n/a | n/a | n/a |
| mORMot2 | all | 40 | 40 | 40 | 40 | 0 | 0.00 | 100.00 | 0.00 |
| mORMot2 | without-directives | 0 | 0 | 0 | 0 | 0 | n/a | n/a | n/a |
| mORMot2 | with-directives | 40 | 40 | 40 | 40 | 0 | 0.00 | 100.00 | 0.00 |
| mORMot2 | complete-opaque | 40 | 40 | 40 | 40 | 0 | 0.00 | 100.00 | 0.00 |
| mORMot2 | other-opaque | 0 | 0 | 0 | 0 | 0 | n/a | n/a | n/a |
| mORMot2 | small | 10 | 10 | 10 | 10 | 0 | 0.00 | 100.00 | 0.00 |
| mORMot2 | medium | 16 | 16 | 16 | 16 | 0 | 0.00 | 100.00 | 0.00 |
| mORMot2 | large | 14 | 14 | 14 | 14 | 0 | 0.00 | 100.00 | 0.00 |

## Largest opaque regions

| File | Start | UTF-16 units | Parent | Heuristic |
|---|---:|---:|---|---|
| build/coverage-corpora/mORMot2/src/core/mormot.core.base.pas | 0 | 479023 | skCompilationUnit | directive-fallback |
| build/coverage-corpora/mORMot2/src/core/mormot.core.data.pas | 0 | 388743 | skCompilationUnit | directive-fallback |
| build/coverage-corpora/mORMot2/src/core/mormot.core.buffers.pas | 0 | 372192 | skCompilationUnit | directive-fallback |
| build/coverage-corpora/DelphiMVCFramework/sources/JsonDataObjects.pas | 0 | 330508 | skCompilationUnit | directive-fallback |
| build/coverage-corpora/DelphiMVCFramework/sources/TemplatePro.pas | 0 | 314057 | skCompilationUnit | directive-fallback |
| build/coverage-corpora/DelphiMVCFramework/sources/MVCFramework.ActiveRecord.pas | 0 | 253560 | skCompilationUnit | directive-fallback |
| build/coverage-corpora/mORMot2/src/core/mormot.core.fmt.pas | 0 | 232189 | skCompilationUnit | directive-fallback |
| build/coverage-corpora/Indy/Lib/Protocols/IdCharsets.pas | 0 | 181535 | skCompilationUnit | directive-fallback |
| build/coverage-corpora/mORMot2/src/core/mormot.core.fpcx64mm.pas | 0 | 164328 | skCompilationUnit | directive-fallback |
| build/coverage-corpora/mORMot2/src/core/mormot.core.datetime.pas | 0 | 162090 | skCompilationUnit | directive-fallback |
| build/coverage-corpora/Indy/Lib/Protocols/IdFTP.pas | 0 | 158657 | skCompilationUnit | directive-fallback |
| build/coverage-corpora/DelphiMVCFramework/sources/MVCFramework.Nullables.pas | 0 | 126111 | skCompilationUnit | directive-fallback |
| build/coverage-corpora/Indy/Lib/Protocols/IdCoderTNEF.pas | 0 | 124904 | skCompilationUnit | directive-fallback |
| build/coverage-corpora/Indy/Lib/Protocols/IdNNTPServer.pas | 0 | 113345 | skCompilationUnit | directive-fallback |
| build/coverage-corpora/DelphiMVCFramework/sources/MVCFramework.MinimalAPI.pas | 0 | 111975 | skCompilationUnit | directive-fallback |
| build/coverage-corpora/DelphiMVCFramework/sources/MVCFramework.Filters.pas | 0 | 109374 | skCompilationUnit | directive-fallback |
| build/coverage-corpora/DUnitX/Source/DUnitX.Utils.pas | 0 | 107331 | skCompilationUnit | directive-fallback |
| build/coverage-corpora/DelphiMVCFramework/sources/MVCFramework.Validators.pas | 0 | 104955 | skCompilationUnit | directive-fallback |
| build/coverage-corpora/mORMot2/src/orm/mormot.orm.sqlite3.pas | 0 | 102737 | skCompilationUnit | directive-fallback |
| build/coverage-corpora/DelphiMVCFramework/sources/MVCFramework.JSONRPC.pas | 0 | 101403 | skCompilationUnit | directive-fallback |

## Diagnostic frequencies

- PAR001: 421
- PAR002: 198
- PAR003: 471

## Opaque causes ranked by affected extent, files and frequency

Outermost regions only; UTF-16 extent includes trivia/errors. Directive fallback is a separate preprocessing cause. Effort and formatter relevance are recommendations in docs/PARSER_COVERAGE.md.

| Heuristic cause | UTF-16 extent | Files | Regions |
|---|---:|---:|---:|
| directive-fallback | 7008451 | 130 | 130 |
| resource-string-section | 51438 | 4 | 4 |
| unknown | 37085 | 16 | 188 |
| unsupported-type | 8482 | 13 | 44 |
| unsupported-statement | 5185 | 14 | 107 |
| method-directives | 1075 | 14 | 98 |
| protected-conditional | 131 | 1 | 1 |

## Performance outliers (largest parser medians)

| File | Bytes | Lexer ms | Parser ms | Tokens/s |
|---|---:|---:|---:|---:|
| build/coverage-corpora/DelphiMVCFramework/sources/MVCFramework.Nullables.pas | 126115 | 3.34 | 25.28 | 1051487.90 |
| build/coverage-corpora/mORMot2/src/core/mormot.core.base.pas | 479027 | 11.53 | 16.43 | 4272169.67 |
| build/coverage-corpora/DelphiMVCFramework/sources/MVCFramework.Swagger.Commons.pas | 82473 | 1.86 | 13.42 | 1154440.26 |
| build/coverage-corpora/mORMot2/src/core/mormot.core.data.pas | 388747 | 8.02 | 11.87 | 4367937.43 |
| build/coverage-corpora/mORMot2/src/core/mormot.core.buffers.pas | 372194 | 8.01 | 11.35 | 4770649.31 |
| build/coverage-corpora/DelphiMVCFramework/sources/JsonDataObjects.pas | 330510 | 7.70 | 10.40 | 4717325.13 |
| build/coverage-corpora/DelphiMVCFramework/sources/TemplatePro.pas | 314062 | 6.88 | 8.81 | 4604537.95 |
| build/coverage-corpora/DelphiMVCFramework/sources/ExprEvaluator.pas | 43008 | 0.87 | 8.27 | 1257494.86 |
| build/coverage-corpora/mORMot2/src/core/mormot.core.fmt.pas | 232203 | 5.28 | 7.87 | 4433815.93 |
| build/coverage-corpora/Indy/Lib/Core/IdAssignedNumbers.pas | 131301 | 1.72 | 7.41 | 1875246.48 |

## Exclusions and failures

- build/coverage-corpora/DelphiMVCFramework/sources/MVCFramework.BloomFilter.pas: encoding_ambiguous
- build/coverage-corpora/Indy/Lib/Core/IdContext.pas: encoding_ambiguous
- build/coverage-corpora/Indy/Lib/Core/IdCustomTCPServer.pas: encoding_ambiguous
- build/coverage-corpora/Indy/Lib/Protocols/IdCustomHTTPServer.pas: encoding_ambiguous
- build/coverage-corpora/Indy/Lib/Protocols/IdDNSServer.pas: encoding_ambiguous
- build/coverage-corpora/Indy/Lib/Protocols/IdFTPCommon.pas: encoding_ambiguous

## Limits and next milestones (recommendations, not measurements)

No preprocessor branches are evaluated. A complete directive fallback masks grammar gaps; it must not be attributed to types or statements. Heuristic unknowns stay unknown. Nested opaque spans in the inventory can overlap; coverage counts each original token exactly once. The stratified sample is not a population estimate. FPC path labels are heuristic and unreviewed units may contain compatibility code.

Prioritize any observed invariant violation as a separate minimal-reproducer fix. Otherwise M2.8 should design directive-aware lossless representation before interpreting external grammar coverage; M2.9 should remeasure and select a narrow declaration extension, with resource-string sections a concrete candidate in this corpus. Formatter-oracle infrastructure can follow as a separate task; these percentages do not authorize formatting.
