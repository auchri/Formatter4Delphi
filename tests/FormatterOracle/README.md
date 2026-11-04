# FormatterOracle – original RAD Studio formatter as a comparison reference

Status: **O1 research base plus O2 runner**. O2 runs the original formatter on isolated copies and
records what it does. Nothing here reads native profiles for Formatter4Delphi or claims compatibility.
C1 (native reader) and C2 (effective options) are separate, not yet commissioned milestones
([plan](../../design/docs/spec/09_IMPLEMENTATION_PLAN.md), [native config](../../design/docs/spec/07_RAD_CONFIG.md),
[experiments](../../design/docs/spec/11_OPEN_QUESTIONS.md)).

The original formatter is a *compatibility reference*, never a safety oracle: source/token/safety
invariants of Formatter4Delphi always win over cosmetic parity.

## Contents

| Path | Purpose |
|---|---|
| [O1_REPORT.md](O1_REPORT.md) | Research report: artifacts, versions, profile schema, IDE export experiment, open points |
| [O2_REPORT.md](O2_REPORT.md) | Executed oracle experiments O2-P01 and O2-P11 and their results |
| [OPEN_QUESTIONS.md](OPEN_QUESTIONS.md) | Differentiated compatibility questions and the O2 experiment that answers each |
| [LOCAL_ARTIFACTS.md](LOCAL_ARTIFACTS.md) | How to provide proprietary artifacts locally without committing them |
| [manifest/MANIFEST_FORMAT.md](manifest/MANIFEST_FORMAT.md) | Manifest format (executed vs. planned, run record fields) |
| [manifest/o1-manifest.json](manifest/o1-manifest.json) | Toolchain, profile, fixture and experiment records of O1 incl. the planned follow-up runs |
| [manifest/o2-manifest.json](manifest/o2-manifest.json) | Executed O2 experiments with hashes and classifications |
| [inventory/](inventory/) | Generated, deterministic inventory of one local installation (hashes, schema, option catalog, comparisons) |
| [fixtures/README.md](fixtures/README.md) | Self-authored Delphi and profile fixtures, purpose and status |
| [scripts/Get-NativeArtifactInventory.ps1](scripts/Get-NativeArtifactInventory.ps1) | Read-only inventory generator |
| [scripts/Test-OracleManifest.ps1](scripts/Test-OracleManifest.ps1) | Read-only manifest/fixture/no-proprietary-file check |
| [scripts/RunFormatterOracle.ps1](scripts/RunFormatterOracle.ps1) | Controlled execution of the formatter on copies |
| [scripts/Invoke-O2Experiments.ps1](scripts/Invoke-O2Experiments.ps1) | Experiments O2-P01 and O2-P11 on top of the runner, with assertions and reference checks |
| [scripts/Test-OracleRunner.ps1](scripts/Test-OracleRunner.ps1), [FakeFormatter.ps1](scripts/FakeFormatter.ps1) | Runner and experiment tests with a controlled stand-in process, no RAD Studio needed; takes about 3 minutes |
| `local/` | Git-ignored place for local proprietary artifacts (see LOCAL_ARTIFACTS.md) |

## Prerequisites

- Windows with a RAD Studio installation (only for regenerating the inventory and for O2).
- PowerShell 7 (`pwsh`), same as `scripts/ValidateDesignDocs.ps1`.
- No Delphi build is needed for O1 artifacts.

## Checks (repository root)

~~~powershell
pwsh -NoProfile -File tests/FormatterOracle/scripts/Test-OracleManifest.ps1
pwsh -NoProfile -File tests/FormatterOracle/scripts/Test-OracleManifest.ps1 -Manifest manifest/o2-manifest.json
pwsh -NoProfile -File tests/FormatterOracle/scripts/Test-OracleScripts.ps1
pwsh -NoProfile -File tests/FormatterOracle/scripts/Test-OracleRunner.ps1
~~~

`Test-OracleScripts.ps1` needs no RAD Studio: it feeds manipulated manifest copies to the validator
and synthetic UTF-8/UTF-16/EOL profiles to the inventory script.

The local build 29.0.51961.7529 is the current reference toolchain; Delphi 12.3 is a future
compatibility target and not a prerequisite for O2 or C1.

Regenerating the inventory (needs the local installation and `local/` artifacts; output must be
byte-identical to the committed file for the same inputs):

~~~powershell
pwsh -NoProfile -Command "& ./tests/FormatterOracle/scripts/Get-NativeArtifactInventory.ps1 -BdsRoot 'C:\Program Files (x86)\Embarcadero\Studio\23.0' -UserConfigDir `"`$env:APPDATA\Embarcadero\BDS\23.0`" -ExtraProfileDir ./tests/FormatterOracle/local/ide-exports,./tests/FormatterOracle/local/ide-active-snapshots -OutFile ./build/inventory.json"
~~~

## Prerequisites for real oracle runs

- Windows with the reference RAD Studio installation (BDS 23.0, build 29.0.51961.7529). The runner
  refuses a `Formatter.exe` whose SHA-256 differs from the manifest toolchain.
- PowerShell 7. Install it with `winget install Microsoft.PowerShell`, or as a dotnet tool on .NET 9
  with `dotnet tool install --global PowerShell --version 7.5.4`.
- Everything else (self-tests, manifest checks) runs without RAD Studio.

## Running the formatter: RunFormatterOracle.ps1

The runner executes one specification (formatter, optional profile, inputs, argument list) one or
more times on copies. It assigns no meaning to formatter arguments: the caller passes them.

~~~powershell
& ./tests/FormatterOracle/scripts/RunFormatterOracle.ps1 `
  -FormatterPath 'C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\Formatter.exe' `
  -ArgumentTemplate '-delphi','-silent','-config','{profile}','-log','{log}','{input}' `
  -InputPath tests/FormatterOracle/fixtures/delphi/O1AssignSpacing.pas `
  -ProfilePath 'C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\config\Formatter_Default.config' `
  -RunName demo -Repetitions 3 -TimeoutSeconds 60
~~~

Run this from a `pwsh` prompt or script, as shown. Do not wrap it in `pwsh -File`: dash-prefixed
array elements are then taken for script parameters and the formatter gets a different argument
list. Check `arguments` in `run-result.json` when in doubt.

| Parameter | Meaning |
|---|---|
| `-FormatterPath` | Executable to run (required) |
| `-ArgumentTemplate` | Exact argument list (required). Placeholders: `{input}`, `{input:N}`, `{profile}`, `{repDir}`, `{log}` (`{repDir}\formatter.log`) |
| `-InputPath` | Source files; copied per repetition, originals are never passed to the process |
| `-ProfilePath` | Profile; copied per repetition as `profile-<name>`. Must be well-formed `TgConfig` XML unless `-AllowInvalidProfile` is set |
| `-RunName`, `-RunRoot` | Name prefix and parent directory. Default root `local/runs`; inside the repository only below `local/` |
| `-Repetitions`, `-TimeoutSeconds` | Default 3 and 60 |
| `-DialogGraceMilliseconds` | Wait after a window appears before its text is read (default 500) |
| `-Manifest`, `-ToolchainId` | Hash source; default `o1-manifest.json`, first toolchain |
| `-ExpectedFormatterSha256` | Explicit expected hash instead of the manifest (used by the self-tests) |
| `-ProtectedPath` | Extra files that must not change |

Runner exit codes: 0 `success`; 1 `formatter-error`, `aborted` or `guard-violation` (recorded);
2 precondition failure (nothing executed, no run directory).

**Safety mechanisms.** The formatter hash is checked before anything runs. Each repetition uses its
own new directory and copies; a lock file blocks reuse of the run directory. Sources must lie outside
the run root. The process is started directly, without a shell. Only the started process tree is
ever killed: on timeout, or if a dialog survives `WM_CLOSE` for 5 seconds. Inputs, the
profile and `%APPDATA%\Embarcadero\BDS\*\Formatter.config` are compared byte for byte per repetition;
a changed `%APPDATA%` profile is restored and reported as `guard-violation`. The runner cannot detect
writes to files it does not know about. The only file it deletes is its own lock file.

**Results** are stored only below `local/runs/<run-name>-<utc-stamp>/`, which is git-ignored:

~~~text
run-result.json       format formatter4delphi.oracle-run/1
rep-NN/               input and profile copies, formatter output, formatter.log
rep-NN.process/       stdout.txt, stderr.txt, dialog-N.txt
~~~

`run-result.json` holds formatter hash/version, environment, argument template and per repetition:
resolved arguments, state (`exited`, `dialog`, `timeout`, `start-failed`), exit code, duration, kill and
dialog flags, stdout/stderr, all files before and after with hashes, and created/changed/deleted lists.
`determinism` compares state, exit code and file hashes across repetitions. `formatter.log` and
stdout are excluded because they contain timestamps. Record findings in a manifest
(`manifest/o2-manifest.json`), not by committing outputs.

## Reproducing O2-P01 and O2-P11

~~~powershell
pwsh -NoProfile -File tests/FormatterOracle/scripts/Invoke-O2Experiments.ps1 -FormatterPath 'C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\Formatter.exe'
~~~

`-Experiment P01` or `-Experiment P11` runs one of them. Results go to
`local/runs/O2-P01-<stamp>/` (`analysis.json`, `diff-input-A.txt`, `diff-input-B.txt`, `diff-A-B.txt`,
`profiles/`, `runs/`) and `local/runs/O2-P11-<stamp>/` (`p11-summary.json`, `runs/`). See
[O2_REPORT.md](O2_REPORT.md) for results.

### Experiment evaluation

An experiment that ran has not necessarily passed. Three levels stay separate:

| Level | Field | Values | Says |
|---|---|---|---|
| One formatter call | `classification` in `run-result.json` | `success`, `formatter-error`, `aborted`, `guard-violation` | How the process ended |
| Experiment run | `executionStatus` | `executed`, `partial`, `not-executed` | Whether it ran |
| Experiment result | `assertionStatus` | `passed`, `failed`, `blocked`, `unconfirmed` | Whether the fixed expectations were met |

`compatibilityClaim` is always `none`: nothing here shows that Formatter4Delphi behaves the same. A
negative test passes when the formatter fails as expected, so a run with `aborted` or `formatter-error`
can belong to a `passed` experiment.

| Exit code | `assertionStatus` | Meaning |
|---|---|---|
| 0 | `passed` | All assertions met and every variant matched its reference record |
| 1 | `failed` | At least one assertion violated, or an exception occurred |
| 2 | `blocked` | A precondition failed; nothing ran, or the series stopped at the refusal |
| 3 | `unconfirmed` | Assertions met, but no reference evidence for this combination |

With several experiments the worst one sets the exit code: 1, then 2, then 3, then 0. The result file is
always written and raw outputs stay in place, also after a failure or an exception. It adds `assertions`
(each with `id`, `variant`, `result`, `expected`, `actual`), `failureReasons`, `blockedReasons` and
`reference` to the unchanged raw observations.

**Criteria for O2-P01.** Both variants: all repetitions (at least 3) `exited`, exit 0, `success`, no kill,
no guard issue, deterministic, one output hash, only the input changed and only `formatter.log` created.
Also: A and B differ only in `DelphiFormatter.AssignSpaces`, the outputs differ, they differ only in blanks
around `:=` outside strings and comments, the string and comment decoys stay intact, fixture and base
profile stay unchanged, and the output equals the bound reference hash.

**Criteria for O2-P11.** Each of the 11 variants has fixed expectations in `Invoke-O2Experiments.ps1`:
dialog or not, state, exit code, classification, input formatted or not, created files, and the message with
its channel. Two repetitions, deterministic, no kill, no guard issue. Bound variants with an input must also
match their reference output hash. A failing call must leave the input copy unchanged.

**Reference binding.** The executed run records of `manifest/o2-manifest.json` are the references. An
output hash counts as a golden only if formatter hash, profile hash, input hash, argument list, culture,
UI culture and ANSI code page all equal the record. The OS version is not part of the binding. If anything
differs, `reference.variants.<name>.mismatches` names it, no golden is applied and the result can reach
at most `unconfirmed`. With a matching combination, a different hash is `failed`, and the report gives
expected and actual hash and the variant.

**New formatter versions.** A formatter hash outside the reference toolchains is `blocked`.
`-AcceptUnknownFormatter` runs it anyway, on the hash the script just computed; the result stays
`unconfirmed` at best, or `failed` if expectations are violated. The expectations describe build
29.0.51961.7529, so a failure on another version may be a real behavior change and not a defect.

**Approving a new reference** is manual and never comes from a failed run:

1. Run with `-AcceptUnknownFormatter` and confirm exit code 3 in a second independent run.
2. Review `diff-*.txt`, `analysis.json` and the outputs by hand.
3. In a reviewed PR, add a new toolchain and environment and new run records. Keep the existing records.
4. Run again; it must now report `passed` with `reference.status = regression`.

No script writes to a manifest.

**Observed `Formatter.exe` behavior** (build 29.0.51961.7529): formats in place; exit 0 on success, 1
on the tested errors; without `-silent` errors block in a dialog; a config that cannot be loaded stops
the run with the input unformatted; unknown options are treated as file names. Use `-silent` and `-log`
for oracle runs. Details, limits and unverified points are in the report. Findings cover only the tested
build, arguments and fixture; they are no compatibility claim for Formatter4Delphi.
