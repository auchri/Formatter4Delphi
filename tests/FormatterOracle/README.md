# FormatterOracle – original RAD Studio formatter as a comparison reference

Status: **O1 research base**. Nothing here runs the original formatter on source files, reads
native profiles for Formatter4Delphi or claims compatibility. O2 (controlled `Formatter.exe` runs),
C1 (native reader) and C2 (effective options) are separate, not yet commissioned milestones
([plan](../../design/docs/spec/09_IMPLEMENTATION_PLAN.md), [native config](../../design/docs/spec/07_RAD_CONFIG.md),
[experiments](../../design/docs/spec/11_OPEN_QUESTIONS.md)).

The original formatter is a *compatibility reference*, never a safety oracle: source/token/safety
invariants of Formatter4Delphi always win over cosmetic parity.

## Contents

| Path | Purpose |
|---|---|
| [O1_REPORT.md](O1_REPORT.md) | Research report: artifacts, versions, profile schema, IDE export experiment, open points |
| [OPEN_QUESTIONS.md](OPEN_QUESTIONS.md) | Differentiated compatibility questions and the O2 experiment that answers each |
| [LOCAL_ARTIFACTS.md](LOCAL_ARTIFACTS.md) | How to provide proprietary artifacts locally without committing them |
| [manifest/MANIFEST_FORMAT.md](manifest/MANIFEST_FORMAT.md) | Manifest format (executed vs. planned, run record fields) |
| [manifest/o1-manifest.json](manifest/o1-manifest.json) | Toolchain, profile, fixture and experiment records of O1 incl. planned O2 runs |
| [inventory/](inventory/) | Generated, deterministic inventory of one local installation (hashes, schema, option catalog, comparisons) |
| [fixtures/README.md](fixtures/README.md) | Self-authored Delphi and profile fixtures, purpose and status |
| [scripts/Get-NativeArtifactInventory.ps1](scripts/Get-NativeArtifactInventory.ps1) | Read-only inventory generator |
| [scripts/Test-OracleManifest.ps1](scripts/Test-OracleManifest.ps1) | Read-only manifest/fixture/no-proprietary-file check |
| `local/` | Git-ignored place for local proprietary artifacts (see LOCAL_ARTIFACTS.md) |

## Prerequisites

- Windows with a RAD Studio installation (only for regenerating the inventory and for O2).
- PowerShell 7 (`pwsh`), same as `scripts/ValidateDesignDocs.ps1`.
- No Delphi build is needed for O1 artifacts.

## Checks (repository root)

~~~powershell
pwsh -NoProfile -File tests/FormatterOracle/scripts/Test-OracleManifest.ps1
~~~

Regenerating the inventory (needs the local installation and `local/` artifacts; output must be
byte-identical to the committed file for the same inputs):

~~~powershell
pwsh -NoProfile -Command "& ./tests/FormatterOracle/scripts/Get-NativeArtifactInventory.ps1 -BdsRoot 'C:\Program Files (x86)\Embarcadero\Studio\23.0' -UserConfigDir `"`$env:APPDATA\Embarcadero\BDS\23.0`" -ExtraProfileDir ./tests/FormatterOracle/local/ide-exports,./tests/FormatterOracle/local/ide-active-snapshots -OutFile ./build/inventory.json"
~~~

## Execution concept for O2 (not implemented)

1. Verify the toolchain record (EXE hash, version) of the manifest against the local `Formatter.exe`.
2. Copy fixture and profile into a fresh run directory below `local/runs/`; never format repository files.
3. Invoke `Formatter.exe` with absolute paths, `-silent`, `-log` and an explicit `-config` from that
   directory, under a timeout (O1-X01 showed that the help/usage path opens a blocking dialog).
4. Record command line, working directory, encoding argument, exit code, stdout/stderr and
   input/output hashes; repeat; fill a run record with `status: executed`.
5. Derive a capability only for the measured (toolchain, profile hash, key, value, syntax feature).
