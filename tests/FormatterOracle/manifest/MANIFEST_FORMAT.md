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

Every run record must contain all of these fields; `null` means "not applicable / not observed",
a missing field is an error. `toolchainId` is always required; formatter runs (also planned ones)
require `formatterSha256`, `commandLine` and `workingDirectory`; IDE runs require `profileId` and
`profileSha256`. `blocked`/`not-run` experiments list no runs, `executed`/`planned` ones at least one.

Cross-references: an id must name a record of the right kind (`toolchainId` → toolchain,
`profileId` → profile, `inputFixtureId` → fixture, `environmentId` → environment). A hash given
next to an id must equal that record's hash (`formatterSha256` = toolchain `formatter.exe.sha256`,
`profileSha256` = profile `sha256`, `inputSha256` = fixture `sha256`); a hash without its id is
rejected because it cannot be attributed.

Observation fields (`exitCode`, `stdoutSha256`, `stderrSha256`, `outputSha256`,
`observedDifference`, `repetitionsIdentical`, `evidenceStatus`) must be `null` unless executed, so a
plan can never be mistaken for a result. `supportedScope` states the narrowest claim the run
supports (toolchain, profile hash, key, value, syntax feature); anything wider is unverified.

## O2 extensions

All are additive; O1 records stay valid.

- Profile `origin: derived`: uncommitted profile made for an experiment, requires `derivation` text.
- `executedIn` on a planned experiment: manifest path that holds its executed record; checked.
- `plannedDeviation` and `comparison` on experiments: how execution differed from the plan, and the
  evaluation across runs.
- Optional run fields (executed runs only): `processOutcome` (`exited`, `dialog`, `timeout`,
  `start-failed`), `runnerClassification` (`success`, `formatter-error`, `aborted`, `guard-violation`),
  `timeoutSeconds`, `durationMs`, `killed`, `dialogClosedByRunner`, `failureClass`, `inputChanged`,
  `outputSizeBytes`, `createdFiles`, `localRunId`.
- The validator rejects a classification that contradicts outcome and exit code, so a failed run
  cannot read as success. `exitCode` after a closed dialog is what the process returned then.
- `regressionChecks` on executed experiments: `checkedOn`, `assertionStatus` (`passed`, `failed`,
  `blocked`, `unconfirmed`), `referenceStatus`, `assertionCount`, `localExperiment`, `note`. A check
  evaluates a rerun against recorded expectations. It is not a new measurement and does not replace
  the run records. `executed` stays the fact that an experiment ran; `passed` is never a manifest
  status.
- The executed run records are the reference data: `outputSha256` is a golden only for the exact
  formatter hash, profile hash, input hash, argument list, culture, UI culture and ANSI code page of its
  record (see the [README](../README.md#experiment-evaluation)). `Invoke-O2Experiments.ps1` only reads
  manifests; a new reference is a reviewed manual edit.
- `stdoutSha256` of a formatter run covers text with timestamps and paths and is not comparable
  between runs. `repetitionsIdentical` means state, exit code and file hashes, without logs and stdout.

Expected outputs ("goldens") are not part of this format version; they are added only after
reproducible O2 runs.
