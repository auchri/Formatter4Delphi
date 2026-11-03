# O1 oracle fixtures

All files are self-authored for Formatter4Delphi and byte-exact experiment inputs
(`.gitattributes`: `-text -whitespace`, so tabs, CR/LF/mixed endings, BOMs and missing final
newlines survive). They are **inputs only**: no expected outputs are committed. Hashes and sizes are
recorded in [../manifest/o1-manifest.json](../manifest/o1-manifest.json).

## Delphi sources (`delphi/`)

Compile status of every file: **designed-not-compiled** (the installed RAD Studio edition has no
command-line compiler, O1-B02). A supplementary run of the existing M2.7 coverage tool (O1-X05)
checked lossless lexing/parsing only.

| Id | File | Purpose | F4D M2.7 parse |
|---|---|---|---|
| FX-ASSIGN | O1AssignSpacing.pas | `:=` with 0/1/2 spaces and tabs, broken RHS, `for`, decoys in string/comments | structured |
| FX-NESTED | O1NestedStatements.pas | nested local function, if/else, for/while, case-else, try/finally, repeat | lossless, PAR001 at the nested routine (F4D grammar gap) |
| FX-TABS | O1TabsIndent.pas | tab, space and mixed indentation | structured |
| FX-EOL-CRLF / -LF / -MIXED | O1LineEndings*.pas | same code with CRLF, LF, rotating CRLF/LF/CR without final newline | structured |
| FX-COMMENTS | O1CommentsStrings.pas | `//`, `{}`, `(* *)`, multi-line comment, strings with `:=`/`''`/`#13#10`, UTF-8 BOM, non-ASCII | structured |
| FX-DIRECTIVES | O1CompilerDirectives.pas | IFDEF/ELSE/ENDIF, IF/IFEND, IFOPT, lowercase ifdef, indented directives, region | opaque (directive fallback) |

FX-DIRECTIVES is designed to be valid with no defines and with `DEBUG`, and deliberately invalid
with `O1_UNDEFINED_SYMBOL` (inactive `uses` of a missing unit). None of these configurations was
compiled; the file must not be treated as valid in arbitrary define sets.

## Profiles (`profiles/`)

Self-authored minimal/negative profiles in the observed `TgConfig Version="3"` shape. They are not
copies of original profiles; how the IDE or `Formatter.exe` treats them is unobserved (planned
O2-P02 to O2-P06).

| Id | File | Case |
|---|---|---|
| PR-FX-MIN-ASSIGN-NONE | O1MinimalAssignNone.config | only `DelphiFormatter.AssignSpaces=None` |
| PR-FX-UNKNOWN | O1UnknownOption.config | unknown option name and unknown element |
| PR-FX-DUPLICATE | O1DuplicateConflict.config | `AssignSpaces` twice, None then BeforeAndAfter |
| PR-FX-INVALID | O1InvalidValues.config | value outside `USE_SPACE`, non-integer `TabSize` |
| PR-FX-MIN-UTF16 | O1MinimalAssignNoneUtf16.config | UTF-16LE BOM, `encoding="utf-16"` |
