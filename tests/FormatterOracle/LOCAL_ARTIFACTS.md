# Providing proprietary artifacts locally

`Formatter.exe`, its assemblies, shipped `.config` profiles, IDE-exported or active profiles and
original formatter output are Embarcadero/user artifacts. They are **never committed**. The
repository holds only their hashes, version metadata and derived, path-free inventories.

## Layout (git-ignored by `tests/FormatterOracle/.gitignore`)

~~~text
tests/FormatterOracle/local/
  ide-exports/            profiles saved with the IDE "Save As" button
  ide-active-snapshots/   byte copies of %APPDATA%\Embarcadero\BDS\<ver>\Formatter.config
  runs/<run-id>/          (O2) per-run copies of input, profile, output, log, run-result.json
~~~

`Formatter.exe` itself stays in the installation; O2 references it by absolute path and checks its
SHA-256 against the manifest toolchain record. Do not copy it into the repository tree.

## Rules

1. Work on copies. Before any IDE experiment, copy the active `Formatter.config` to
   `local/ide-active-snapshots/` and compare hashes afterwards: O1-X02 showed that **Save As also
   rewrites the active profile**. Restore from the copy if it changed.
2. Exported profiles contain `Config.FileSource` with the absolute export path. The inventory
   script replaces absolute-path values by a hash; never paste such values into committed files.
3. Name exports freely; the manifest identifies them by hash, not by file name.
4. Record each new artifact in a manifest (`committed: false`, location placeholder such as
   `$(BDS)\...`, `%APPDATA%\...` or `local/...`) and run `Test-OracleManifest.ps1`.
5. Never import manipulated or unknown profiles into the productive IDE configuration.
