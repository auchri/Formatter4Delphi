# Corpus source examples

All paths below are relative to the pinned repository roots under
`build/coverage-corpora/`. Commits and complete file hashes are in the unchanged
manifest and both coverage reports. These are small locating excerpts, covered
by the existing upstream notices in `tests/CoverageCorpus/notices/`.

## Five improved locations (two external files, not five improved files)

M2.7 classified all code in each of these two files opaque because of
`{$SCOPEDENUMS ON}`. M2.8 preserves that switch explicitly and resumes independent
routines after the opaque type region. The first file now has 5,307 structured
code units (36.521919%); the second has 3,785 (46.271394%). These files still have
77 and 145 parser errors respectively in other, newly exposed unsupported code;
they are not claimed to be completely parsed.

Each full routine extent below was checked against the M2.8 opaque inventory and
error diagnostic spans: zero overlaps for all five. The existing routine/header,
block, call, assignment, if and expression grammar recognizes these fragments.
Offsets include the following separator trivia up to the next routine and refer
to exact decoded UTF-16 snapshots. No new statement grammar was added.

| Pinned file / line | UTF-16 extent | Locating excerpt | Why recognition is safe |
|---|---|---|---|
| DelphiMVCFramework/sources/MVCFramework.ActiveRecordController.pas:276 | [11170,11295) | `GetEntities(entityname);` | Complete GetEntitiesByRQL routine: simple parameter header, block and call. |
| Same file:356 | [13396,13552) | `Result := StrToIntDef(Config[TMVCConfigKey.MaxEntitiesRecordCount], 20);` | Complete GetMaxRecordCount function: ordinary call/index/member expressions and assignment. |
| Same file:361 | [13552,13653) | `Result := fURLSegment;` | Complete GetURLSegment function: simple return type and assignment. |
| DelphiMVCFramework/sources/MVCFramework.DotEnv.Parser.pas:197 | [5367,5707) | `Result := (fCurrentLineBreakLength = 1) and (fCurrChar = fCurrentLineBreak[1]);` | Complete IsPartOfLineBreak function: existing comparisons, grouping and indexing. |
| Same file:300 | [7717,7894) | `Result := fCode.Chars[fIndex] = Symbol;` | Complete MatchSymbol function: existing postfix chain, assignment and following if/call. |

The archived internal `Formatter4Delphi/tests/Fixtures/LexicalCorpus.pas` also
improves from 0 to 648 structured code units. Its nested-control-free
`{$IFDEF MSWINDOWS}` / `(*$WARN SYMBOL_PLATFORM OFF*)` / `{$ENDIF}` region contains
only a switch, so it is a protected opaque island. Generics and inherited
statements remain opaque; three existing grammar limitations are now diagnosed.
This internal result is excluded from the external improvement percentage.

## Remaining complete-input cases: observed context, not guessed prevalence

| Pinned file | Small excerpt / location | Exact remaining reason |
|---|---|---|
| DUnitX/Source/DUNitX.Loggers.GUIX.pas:30 | `{$I DUnitX.Inc}` | Actual include between header and interface. Its content may open arbitrary syntax; no expansion or assumption about its content. |
| DUnitX/Source/DUNitX.Loggers.MobileGUI.pas, FormCreate | `{$IFDEF CI}` followed by `var NUnitLogger : ITestLogger;` | Conditional local declaration in a method, followed by a second conditional statement region. Neither method-local nor statement boundaries are enabled in this pilot. |
| DUnitX/Source/DUnitX.Constants.pas | `const` then `{$IFDEF NEXTGEN}` and `MinStringOffset : integer = 0;` | Conditional contents depend on the already-open const section. They do not meet the complete routine-declaration envelope. |
| DelphiMVCFramework/sources/ExprEvaluator.pas:226 | `{$IF CompilerVersion >= 37}` between assignments in an anonymous function | Method/expression callback context; no statement-list conditional proof is enabled. Complete-input fallback remains. |
| DelphiMVCFramework/sources/MVCFramework.Signal.pas, uses clause | `MVCFramework` then `{$IF Defined(MSWINDOWS)}` / `,WinAPI.Windows` | Branch supplies a uses-list fragment, not an independently complete declaration. A matching closer cannot justify resumption. |
| DelphiMVCFramework/sources/MVCFramework.Nullables.pas:32 | `{$IF CompilerVersion >= 35}` / `{$DEFINE USE_EQUALS}` | Conditional before interface is outside UnitSection; later branches also contain alias/type-list fragments. No arbitrary preamble/type-list conditional support. |
| DelphiMVCFramework/sources/TemplatePro.pas | `{$REGION 'entities'}` | REGION/ENDREGION are outside the finite pilot whitelist; unknown-directive fallback is intentional. This does not assert the source is invalid. |

The same report's diagnostic reason tally distinguishes actual include,
unknown-directive and malformed-conditional blockers. The remaining
unproven-context category deliberately does not infer method/type/uses positions
from a single keyword. The table above is manual contextual evidence only;
there is no claim that the examples measure the distribution of those subtypes.

A further changed file is **not** an improvement in code coverage:
`DelphiMVCFramework/sources/MSHeap.pas` now retains the unit hierarchy and O+
switch before interface, but initialization and implementation modifiers expose
22 parser errors and no structured code units under the conservative error
metric. Its reduction in fallback count must not be described as increased
recognition. No syntax expansion was attempted to conceal those diagnostics.
