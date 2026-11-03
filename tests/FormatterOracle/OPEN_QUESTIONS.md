# Open compatibility questions after O1

Normative experiment register: [11_OPEN_QUESTIONS](../../design/docs/spec/11_OPEN_QUESTIONS.md).
This list narrows those experiments to what O1 could and could not settle for toolchain
`TC-BDS23-29.0.51961.7529`. "Planned run" refers to [o1-manifest.json](manifest/o1-manifest.json).

## A. Target version (blocks every 12.3 claim)

| Question | Status after O1 | Next step |
|---|---|---|
| Are 12.3 `Formatter.exe`, shipped profiles and IDE exports identical to build 29.0.51961.7529? | unknown, no 12.3 artifacts (O1-B01) | install/obtain 12.3, rerun the inventory script, diff against the committed inventory |
| Which RAD Studio release is build 29.0.51961.7529? | derived "12.1 / 12 Update 1", unverified | check against the vendor's release table |
| Does 12.3 still use `TgConfig Version="3"` and the same option set/types? | unknown | inventory diff (as above) |

## B. Profile semantics (C1)

| Question | Observed in O1 | Still open → planned run |
|---|---|---|
| Absent options | IDE always writes all 158 options plus `Config.*` | Formatter.exe handling of partial profiles → O2-P02 |
| Unknown option/element | none in original files | ignore/reject/report → O2-P03 |
| Duplicate keys | none in original files | first/last/error → O2-P04 |
| Value outside domain | all observed values inside the declared OpenAPI3 enum/Boolean/Int32 domains | fallback/error → O2-P05 |
| Profile encoding | shipped/active: no BOM, ASCII, CRLF; IDE export: UTF-8 BOM, CRLF | UTF-16 profile → O2-P06 |
| Commented-out `<Option>` nodes (9 per file) | present in all files, XML comments | assumed inert (comments), unverified by behavior |
| `Config.FileVersion/FileSource/Profile`, `IsBrowsable`, missing `Levels` | observed in IDE-written files only | effect on Formatter.exe → O2-P12 |
| `Formatter.Enabled/Confirmation` | IDE-level entries, Confirmation differs between shipped and active | relevance for CLI output → O2-P12 |
| `DelphiFormatter.*` versus `CppFormatter.*` | 84/72 by prefix and Category | prefix is not relevance evidence; vary single Cpp keys and compare Delphi output (E-CONFIG) |

## C. Formatting behavior (C2, F1–F4) – nothing observed in O1

| Option(s) | Hypothesis only | Planned run |
|---|---|---|
| `DelphiFormatter.AssignSpaces` (`USE_SPACE`) | `None`/`BeforeAndAfter` control blanks around `:=` | O2-P01 |
| `DelphiFormatter.TabSize/IndentSize/UseTabs` (Category `DelphiEditor`) | indentation unit and tab use of the formatter output | O2-P09 (E-TABS) |
| `IndentCompilerDirectives`, `NumOfEmptyLinesAroundCompilerDirectives`, `CompilerDirectivesCapitalization` | directive column, blank lines, case of directive keywords | O2-P10 (E-CONDITIONAL/E-CASE) |
| Source encoding / `-e` | unknown accepted values; BOM preservation unknown | O2-P07 (E-BYTES) |
| Line endings | unknown whether preserved | O2-P08 |

## D. Invocation (O2 runner contract)

| Question | Observed | Planned run |
|---|---|---|
| Console help | none; usage appears in a blocking dialog, exit code 1 | — |
| Does `-silent` suppress all dialogs? Exit codes on success/failure? `-log` content? | unknown | O2-P11 |
| Is the IDE/user `Formatter.config` read when `-config` is omitted? | unknown | O2 run without `-config` against a changed active profile copy (to be planned) |
| `-b` backup naming, in-place write vs. output file | documented in usage text only | O2 runs in isolated `local/runs/` copies |
