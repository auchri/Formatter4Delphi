# Oracle manifest format `formatter4delphi.oracle-manifest/1`

One UTF-8 JSON document (LF) per milestone, e.g. [o1-manifest.json](o1-manifest.json). It is checked
by [Test-OracleManifest.ps1](../scripts/Test-OracleManifest.ps1). Paths are repository-relative or
placeholders (`$(BDS)`, `%APPDATA%`, `local/...`, `<run-dir>`, `<abs:...>`); personal absolute paths
are rejected. Hashes are upper-case SHA-256 hex.

## Top level

| Key | Content |
|---|---|
| `manifestFormat` | `formatter4delphi.oracle-manifest/1` |
| `milestone`, `description` | owner milestone and scope |
| `repositoryBase` | branch/commit the records were made against |
| `toolchains[]` | `id`; `ide` (registry key/version/edition, bds.exe version+hash); `compiler` (DLL versions, CLI availability); `formatter.exe` (location, sha256, size, file/product version, PE machine/subsystem, managed assembly) and `documentedParameters`; `nativeConfigSchema`; `productRelease` with its own `evidenceStatus`; mandatory `matchesTarget12_3` |
| `environments[]` | `id`, OS version/architecture, culture, UI culture, ANSI code page |
| `profiles[]` | `id`, `origin` (`shipped`, `ide-active`, `ide-export`, `self-authored`), `committed`, `location` or `path`, `sha256`, `sizeBytes`, encoding, schema attribute, notes. Only `self-authored` may be `committed: true`; uncommitted ones link to the inventory by `inventoryLabel` |
| `fixtures[]` | Delphi inputs: `id`, `path`, `sha256`, `sizeBytes`, `purpose`, `encoding`, `eol`, `compileStatus` (`designed-not-compiled` or `compiled` + `compileEvidence`), `defineConfigurations` |
| `experiments[]` | see below |

## Experiments and runs

`experiments[]`: `id`, `title`, `experimentRefs` (IDs from 11_OPEN_QUESTIONS), `status`, `runs[]`.

| status | meaning | required |
|---|---|---|
| `executed` | really performed | every run `status: executed`, `evidenceStatus: observed`, `observedDifference`, `repetitions >= 1`, `supportedScope`; formatter runs also `exitCode`, `commandLine`, `workingDirectory` |
| `planned` | designed for a later milestone (`plannedFor`) | `question`, `decisionUse`; runs carry **no** observation fields |
| `blocked` | cannot run with available artifacts | `reason` |
| `not-run` | intentionally skipped | `reason` |

Run record fields (all present, `null` when not applicable): `runId`, `status`, `kind`
(`formatter-cli`, `ide-export`, `ide-side-effect`, `static-analysis`), `toolchainId`, `environmentId`,
`formatterSha256`, `profileId`, `profileSha256`, `inputFixtureId`, `inputSha256`, `outputSha256`,
`commandLine` (argument array), `workingDirectory`, `encodingArgument`, `exitCode`, `stdoutSha256`,
`stderrSha256`, `repetitions`, `repetitionsIdentical`, `observedDifference`, `evidenceStatus`,
`supportedScope`.

Observation fields (`exitCode`, `stdoutSha256`, `stderrSha256`, `outputSha256`,
`observedDifference`, `repetitionsIdentical`, `evidenceStatus`) must be `null` unless executed, so a
plan can never be mistaken for a result. `supportedScope` states the narrowest claim the run
supports (toolchain, profile hash, key, value, syntax feature); anything wider is unverified.

Expected outputs ("goldens") are not part of this format version; they are added only after
reproducible O2 runs.
