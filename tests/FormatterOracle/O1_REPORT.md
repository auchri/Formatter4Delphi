# O1 – RAD Studio formatter: native artifacts and configuration (research report)

Base: `main` e30c48e3bed4a0ee299b2dda937c398fef917f43 (PR #12 / S1 merged). PR #10 (M2.8 pilot,
head 65000fca7ce3890541aa1f691a17666ef47cfb92) is open and was neither used nor changed.
Observation date 2026-11-03. Records: [manifest](manifest/o1-manifest.json),
[inventory](inventory/rad-studio-23.0_29.0.51961.7529.inventory.json).

**Scope of every finding below: toolchain `TC-BDS23-29.0.51961.7529` only. Delphi 12.3
compatibility is unverified.** No native formatter compatibility of Formatter4Delphi is claimed.

## 1. Available and missing artifacts

| Artifact | Status |
|---|---|
| RAD Studio BDS 23.0 (only installation; registry `ProductVersion=29`, `Edition=Starter`, `InstallLanguage=DE`) | present |
| `$(BDS)\bin\Formatter.exe` 29.0.51961.7529, 373 232 bytes, SHA-256 `11637F75…F42BFBA`, .NET assembly `Formatter, Version=29.0.0.0`, PE x86, console subsystem | present |
| `Embarcadero.Modeling.Formatter.dll`, `…Formatter.Resources.dll` (identical copy under `de\`), `Embarcadero.Modeling.OPENAPI3.DLL` | present, hashed |
| Shipped profiles `Formatter.config`, `Formatter_Default/Compact/Wide.config` | present, hashed |
| Active IDE profile `%APPDATA%\Embarcadero\BDS\23.0\Formatter.config` | present, hashed (before/after experiment) |
| Two IDE exports (O1-X02) | present locally, hashed |
| Command-line compiler | **absent**: `dcc32.exe`/`dcc64.exe` report that this edition does not support command-line compiling |
| Any RAD Studio 12.3 artifact | **missing** (O1-B01) |

Proprietary files stay in the installation or in the git-ignored `local/` folder
([LOCAL_ARTIFACTS](LOCAL_ARTIFACTS.md)).

## 2. Confirmed versions

| Layer | Observed value | Evidence |
|---|---|---|
| IDE product | `bds.exe` FileVersion 29.0.51961.7529, ProductVersion 29.0, ProductName "Personal"; BDS key 23.0 | file version resource, registry |
| Compiler | `dcc32290.dll`/`dcc64290.dll` FileVersion 29.0.51961.7529 | file version resource; no compiler banner (no CLI) |
| Original formatter | `Formatter.exe` FileVersion/ProductVersion 29.0.51961.7529 | file version resource, SHA-256 |
| Native config schema | root `TgConfig`, attribute `Version="3"`, `SubLevelDisabled="False"` | profile XML; a schema attribute, not a product version |
| Release name | "12 Athens Update 1 (12.1)" | **derived, unverified** (build number vs. repository history label "CE 12 Update 1") |

The shipped-profile hashes equal those of the historical
[native-profile-inventory.json](../../design/review-evidence/native-profile-inventory.json): the
historical review evidently used the same build. That is consistency with history, not new 12.3 data.

## 3. Observed native profile schema

- XML declaration `version="1.0"` without encoding; root `TgConfig`; one `Assemblies/Assembly`
  (`Embarcadero.Modeling.OpenAPI3`, `Culture=neutral`); then flat `Option` elements; 33 XML comments,
  9 of which are commented-out `<Option …>` entries.
- `Option` attributes in shipped files: `Name`, `Type`, `Category`, optional `SubCategory`,
  `Value`, `Levels="Formatter"`.
- 158 options per shipped file: 2 `Formatter.*` (Category `Editor`), 72 `CppFormatter.*`,
  84 `DelphiFormatter.*`. Delphi categories: Linebreaks 36, Indentation 16, Spaces 14, Align 11,
  Capitalization 4, Editor 3. No duplicate names, no unknown elements.
- 17 distinct `Type` values: `System.Boolean`, `System.Int32`, `System.String` and 14 enums of
  namespace `Borland.Together.OpenAPI3.Config`. Their members were read from assembly **metadata
  constants only** (nothing loaded/executed), e.g. `USE_SPACE` = None 0, BeforeOnly 1, AfterOnly 2,
  BeforeAndAfter 3, AsIs 4; `CAPITALIZATION` = AsIs, lowercase, UPPERCASE, FirstUpperCase,
  AsFirstOccurence. Every stored value in every observed file lies in its declared domain.
- The same metadata declares attribute names `DisplayName`, `IsReadOnly`, `IsBrowsable`,
  `DefaultValue` and `Level` beyond those used; only `IsBrowsable` occurs (in IDE-written files).
  No profile carries a `DefaultValue`, so defaults cannot be read from profiles.
- Encoding: shipped and active files ASCII, no BOM, CRLF, no final newline; IDE exports add a
  UTF-8 BOM.

Requested option names, confirmed present in all observed files (full names):

| Option | Type | Category / SubCategory | Default / Compact / Wide |
|---|---|---|---|
| `DelphiFormatter.AssignSpaces` | `USE_SPACE` | DelphiSpaces / OperatorSpacing | BeforeAndAfter (all) |
| `DelphiFormatter.TabSize` | Int32 | DelphiEditor | 2 (all) |
| `DelphiFormatter.IndentSize` | Int32 | DelphiEditor | 2 (all) |
| `DelphiFormatter.UseTabs` | Boolean | DelphiEditor | False (all) |
| `DelphiFormatter.IndentCompilerDirectives` | Boolean | DelphiIndentation | False (all) |
| `DelphiFormatter.NumOfEmptyLinesAroundCompilerDirectives` | Int32 | DelphiLinebreaks / NumberOfEmptyLines | 0 (all) |
| `DelphiFormatter.CompilerDirectivesCapitalization` | `CAPITALIZATION` | DelphiCapitalization | UPPERCASE (all) |

`CppFormatter.TabSize/IndentSize/UseTabs/IndentCompilerDirectives` exist separately (Cpp TabSize
4/2/4, UseTabs True/False/True for Default/Compact/Wide).

## 4. Profiles and differences

- `Formatter.config` is byte-identical to `Formatter_Default.config`.
- Default vs. Compact: 29 values differ (13 Delphi, 16 C++); Default vs. Wide: 31 (17 Delphi,
  14 C++); Compact vs. Wide: 55 (27 Delphi, 28 C++). Same 158 names and order in all three.
- Only structural difference: `CppFormatter.ForceBraces` has Category `CppIndentation` in Wide and
  `CppLinebreaks` elsewhere.
- Delphi differences are confined to indentation (e.g. `IndentCaseLabels`,
  `IndentFunctionImplementationBody`), spacing (`ColonSpaces`, bracket spaces,
  `UnaryPreOperatorSpaces`), line breaks (14 `NewLine*`/`Remove*` keys,
  `NumOfEmptyLinesBeforeTypeKeyword`) and alignment (`AlignParameterTypes`, `AlignTypeColon`).
  None of the seven requested options differs between the shipped profiles, so the shipped set
  cannot show their effect. The full per-option table is the inventory `optionCatalog`.
- Effect on Delphi code is **hypothesis only**: names suggest Compact removes blank lines/breaks and
  Wide adds breaks, spaces and alignment. Profile values are not defaults or priorities.

## 5. IDE export experiment (O1-X02, executed manually, German UI)

1. Default profile selected, *Save As* → export A.
2. Only "Leerzeichen um Zuweisungsoperatoren festlegen" set to "Keine", *Save As* → export B.

Observed:
- A vs. shipped Default: UTF-8 BOM; `Formatter.Confirmation` True→False (already so in the active
  profile); three appended options `Config.FileVersion` (= build), `Config.FileSource` (absolute
  export path), `Config.Profile` (file name), each `System.String`, Category `Internal`,
  `IsBrowsable="False"`, no `Levels`. All 158 options keep order, type and category.
- B vs. A: exactly `DelphiFormatter.AssignSpaces` BeforeAndAfter→None (plus the file-specific
  `Config.*` values). UI value "Keine" ↔ stored `None`.
- Side effect: *Save As* also rewrote the active `%APPDATA%` profile (AssignSpaces=None,
  `Config.FileSource`=its own path, `Config.Profile`=""). It was restored from a byte backup; hash
  verified. The active profile before the experiment already contained `Config.FileVersion`.
- Not done: a third export after restoring the value (export determinism), and any IDE import of
  manipulated profiles (deliberately not attempted).

Handling of unset, unknown, duplicate, wrongly typed and differently encoded entries could not be
observed without running the original formatter; self-authored fixtures and planned runs O2-P02 to
O2-P06 cover them.

## 6. Established findings

- Exact hashes/versions of the formatter, its assemblies, profiles and IDE-written files for this build.
- Usage/parameter list of this `Formatter.exe` (`-cpp`, `-delphi`, `-config`, `-e`, `-d`, `-r`, `-b`,
  `-log`, `-silent`, file names/wildcards; Delphi extensions .pas .dpr .dpk .dpkw .inc) and that the
  usage path is a blocking GUI dialog with exit code 1 and no console output.
- Native profile structure, option names, types, categories, stored values and declared enum
  domains; Delphi tab/indent values are stored as `DelphiFormatter.*` options in category
  `DelphiEditor` (consistent with ADR-003: native values).
- IDE-written profiles contain internal `Config.*` options and a BOM; *Save As* changes the active profile.
- One UI-value ↔ stored-value mapping (`AssignSpaces`, Keine ↔ None).
- The inventory generation is deterministic (two runs, identical bytes).

## 7. Still unconfirmed

Everything about formatting behavior; defaults for absent keys; handling of unknown/duplicate/
invalid entries and other encodings; relevance of `Formatter.*`, `Config.*` and `CppFormatter.*`
entries for Delphi output; whether the CLI reads the active IDE profile; exit codes and dialog
behavior with `-silent`; the release name of the build; compilability of the fixtures.

## 8. Missing for exact Delphi 12.3 compatibility

12.3 `Formatter.exe` (hash/version) and assemblies, 12.3 shipped profiles, 12.3 IDE exports with a
single-option delta, a 12.3 compiler for fixture verification, and O2 reference runs on 12.3.

## 9. Prerequisites for O2 and C1

O2: this manifest; a local `Formatter.exe` whose hash matches a toolchain record; isolated run
directories; runner with timeout and dialog detection (O1-X01); explicit `-config`, `-silent`,
`-log`, absolute paths, explicit `-e` where tested; repetitions and input/output/stdout/stderr hashes;
first experiment O2-P01 (AssignSpaces) followed by O2-P11 (failure behavior).

C1: sufficient now for syntactic import of the observed shape (root, `Assemblies`, flat `Option`
attributes, comments, BOM/no BOM, CRLF) and for a recognition catalog of the 161 observed names
with declared domains – **for this build only**. Not sufficient for: rules for unknown/duplicate/
invalid entries (still "ambiguous/refused" per 07), defaults, relevance decisions, any 12.3
recognition, and any capability. Reading `AssignSpaces=None` from a profile does not show that
Formatter4Delphi reproduces its effect; that needs O2-P01 and C2.

## Checks performed in O1

| Check | Result |
|---|---|
| `pwsh -NoProfile -File scripts/ValidateDesignDocs.ps1` (PowerShell 7.5.4) | PASS, 26 documents, 111 local links, 0 warnings |
| `pwsh -NoProfile -File tests/FormatterOracle/scripts/Test-OracleManifest.ps1` | PASS (13 profiles, 8 fixtures, 19 experiments/runs) |
| Inventory generated twice | byte-identical (SHA-256 of output equal) |
| `git diff --check` (working tree and staged) | clean |
| Pinned corpus / `src` / existing fixtures | unchanged |
| Delphi rebuild/DUnitX | not run (no source/project change) |
| Fixture compilation | blocked (no command-line compiler, O1-B02) |
