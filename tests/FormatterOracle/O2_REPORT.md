# O2 – Original formatter oracle runs (report)

Base: `main` e58bf12b3b638ca919e1ee0a06e0d4d110504da6 (PR #13 / O1 merged). Records:
[o2-manifest.json](manifest/o2-manifest.json). Reproduction: [README](README.md#reproducing-o2-p01-and-o2-p11).

**Scope of every finding: `Formatter.exe` 29.0.51961.7529 (SHA-256 `11637F75…F42BFBA`, BDS 23.0
Starter), Windows 10.0.26300, UI culture de-DE, only the argument lists and the fixture named here.**
Delphi 12.3 stays a future target. Nothing here is a compatibility claim for Formatter4Delphi, and
the original formatter is a comparison reference, not a safety oracle.

Formatted outputs stay under `local/` and are not published. This report describes them and gives
their hashes; code shown below is **input** from our own fixture.

## O2-P01: `DelphiFormatter.AssignSpaces`

**Setup.** Profiles A (`BeforeAndAfter`) and B (`None`) both derive from the shipped
`Formatter_Default.config` (`PR-SHIP-DEFAULT`, hash checked against the manifest). Parsing all 158
options proved `DelphiFormatter.AssignSpaces` is the only difference; A is byte-identical to the
base. Three independent repetitions per variant, each on a fresh copy of
[O1AssignSpacing.pas](fixtures/delphi/O1AssignSpacing.pas) with a fresh profile copy.

Arguments: `-delphi -config <profile-copy> -log <rep-dir>\formatter.log <input-copy>`, working
directory = repetition directory.

| Variant | Profile SHA-256 | Exit | Output SHA-256 | Size | Identical over repetitions |
|---|---|---|---|---|---|
| Input | – | – | `69EA85F5ADC7…` | 546 | – |
| A BeforeAndAfter | `D8B4AC6C8DBE…` | 0, 0, 0 | `A5D2D5121F6E…` | 567 | yes, 3 of 3 |
| B None | `7CE01D5C52A2…` | 0, 0, 0 | `14D5627F482F…` | 543 | yes, 3 of 3 |

The same two output hashes were also produced in a separate session the day before.

**Effect of AssignSpaces (A versus B).** A and B have the same line count. They differ on 12 lines,
and on each of those the difference is fully explained by the blanks around `:=` outside string
literals (checked programmatically for the earlier run; the output hashes of both runs are equal).

| Context in the input | A | B |
|---|---|---|
| `A:=1;` / `B :=2;` / `C:= 3;` / `D := 4;` | one blank each side | no blanks |
| `E  :=  5;` (two blanks), `F<tab>:=<tab>6;` (tabs) | one blank each side | no blanks |
| `A :=` with the right side on the next line | one blank each side, joined | no blanks, joined |
| `for I:=0 to 2 do` | one blank each side | no blanks |
| `D:=D+I;` as loop body | one blank each side | no blanks |
| `S := 'x:=y';` | one blank each side, string unchanged | no blanks, string unchanged |
| `if A=B then E:=F else F :=E;` branches | one blank each side | no blanks |

**Unchanged.** The `:=` inside the string literal, inside the brace comment and inside the line
comment, in both variants. In this run A leaves `D := 4;`, `S := 'x:=y';` and both comment lines
byte-identical to the input.

**Other effects, present in both variants** (so not caused by AssignSpaces, but also not attributed
to any particular option):

- blanks are added around `+` and `=`,
- the line-broken assignment is joined onto one line,
- the one-line `if … then … else …` is split over four lines,
- tabs around `:=` are gone (neither output contains a tab).

CRLF line ends, the final CRLF and the absence of a BOM stayed the same for this fixture. The profile
copies were not changed. `-config` is honored: only the profile differed between A and B.

## O2-P11: normal and faulty invocations

Eleven variants, two repetitions each, all with isolated directories. State, exit code and output
hash were identical over the repetitions and matched a separate session the day before. No run
needed a kill; the guards reported nothing.

| Variant | Process outcome | Exit | Classification | Input formatted | Where the message went |
|---|---|---|---|---|---|
| success (`-log`) | exited | 0 | success | yes | log; stdout empty |
| success without `-log` | exited | 0 | success | yes | stdout |
| missing input | dialog | 1 | aborted | – | dialog + log |
| missing input, `-silent` | exited | 1 | formatter-error | – | log |
| missing config path | dialog | 1 | aborted | **no** | dialog + log |
| missing config path, `-silent` | exited | 1 | formatter-error | **no** | log |
| malformed config | dialog | 1 | aborted | **no** | dialog + log (twice) |
| malformed config, `-silent` | exited | 1 | formatter-error | **no** | log (once) |
| unknown option before a valid input | dialog | 1 | aborted | **no** | dialog + stdout |
| same, `-silent` | exited | 1 | formatter-error | **no** | stdout |
| `-?` | dialog | 1 | aborted | – | usage dialog only |

Observed messages: `File <path> doesn't exist`, `Cannot load config file "<path>"` and
`Unable to load config options: <XML error>`. The XML error text is localized (German here), so it is
not a stable contract. Each line starts with a `HH:mm:ss.fff` timestamp, so stdout and logs differ
between repetitions and are excluded from the determinism comparison.

Conclusions for this build and these argument lists:

- Exit 0 and 1 are the only codes seen. All faulty cases gave 1.
- Without `-silent`, every error blocks in a modal dialog until it is closed. The runner detected,
  recorded and closed each one with `WM_CLOSE`, in about one second. The exit code after closing
  matches the `-silent` run. Oracle runs should therefore always use `-silent`.
- A config that cannot be loaded stops the run; there is no fallback to defaults or the user profile.
- An unknown option is not rejected as an option. It is treated as a file name relative to the
  working directory, and the valid input after it is not formatted.
- A dialog variant is classified `aborted` even though the experiment observed it as expected.
  These are observations of failing invocations, not successful formatter runs.

## Exploratory CLI findings (one repetition, not manifest records)

Early runs with one repetition showed that formatting works in place and that `-delphi`, `-silent`,
`-config <file>`, `-config:<file>`, `-log <file>` and `-log:<file>` are all accepted; both log forms
create the log file. The colon form is not in the usage text; string literals in the `Formatter.exe`
metadata (`config:`, `log:`, `d:`, `e:`) suggest it for `-d` and `-e` too, which was not tested.

## Not verified

- `AssignSpaces` values `BeforeOnly`, `AfterOnly`, `AsIs`; any syntax outside this fixture, for example
  `:=` in declarations, initializers, or directive-bearing or non-compilable sources.
- Which options cause the "other effects", and interactions between options.
- Whether the user profile in `%APPDATA%` is read when `-config` is omitted. A run without `-config`
  gave the same output as Default, but the active profile has the same formatting values, so this
  proves nothing. Testing it would mean changing that profile, which O2 must not do.
- A real timeout of `Formatter.exe`: none occurred, so that path is tested only with the stand-in.
- Other error kinds (read-only or locked files, unparsable source), `-e`, `-d`, `-r`, `-b`, wildcards,
  several files, and whether the position of an unknown option matters.
- Any other UI culture, RAD Studio version or build, and fixture compilability (still blocked).

## Next steps

1. O2-P02 to O2-P06: profile semantics, which C1 needs (missing, unknown, duplicate, invalid entries,
   UTF-16 profile).
2. O2-P09 and further single-option variations, to attribute the "other effects" to options.
3. Compare Formatter4Delphi S0 with these results only after C2 maps the native option.
