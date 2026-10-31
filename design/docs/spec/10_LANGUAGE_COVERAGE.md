# 10 – Priorisierte Sprach-/Featurematrix Delphi 12.3

Status ist **bestehender** Code auf main/M2.7; PR #10 ändert ausschließlich die in LF-04 benannte Direktivenbehandlung. I=implementiert strukturiert im dokumentierten Scope, P=teilweise strukturiert, O=bewusst opaque Grammatik, N=kein dedizierter Einstieg/Support. Auch N-Input bleibt grundsätzlich lossless durch Opaque-Recovery. I ist CE-Update-1-belegt, **kein neuer 12.3-Nachweis**. Ziel ist diese abgeschlossene überprüfbare Featureliste, keine Behauptung jeder zukünftigen Delphi-Syntax.

Child-Rollen sind ausschließlich im Register [04](04_SOURCE_CST.md) definiert. Jede Zeile benennt ihr eigenes positives Beispiel, Recoveryfall, Zielcompilerbeleg und eigenen kleinen PR. Beispiele sind **Testentwürfe**; jede positive Fixture erhält einen vollständigen compilierbaren Kontext inklusive Deklarationen/Uses/Implementation. Kein Beispiel ist hier als bereits auf 12.3 ausgeführt markiert.

| Feature-ID / Priorität | Bestehender Scope/Status | Zielrollen | Positiver Testentwurf | Eigene Recovery-/Ambiguitätsprobe | Compiler-/PRgate |
|---|---|---|---|---|---|
| LF-01 / P0 | Lexer I mit offenen Unicode-/Controlgrenzen | Originaltokens | multiline/escaped/numerals gemäß 03 | broken quote/Unicode/Controls | E-LEX/E-COMP; L1 |
| LF-02 / P0 | unit/routine/const/var/class/record/property P | N-UNIT/N-DECL/N-TYPE/N-AGG/N-ROUTINE/N-PROP | vorhandene compilierte Corpora | vorhandene Recovery + Rollenqueries fehlender Subteile | E-COMP; Bestand und passende K-Slices |
| LF-03 / P0 | expressions/postfix/if/loops/case/try P | N-EXPR/N-POST/N-IF/N-LOOP/N-CASE/N-TRY | vorhandene ControlFlow/PostfixCorpora, vollständige Wrapper | precedence/else/semicolon/missing closer | E-COMP/T-REC; Bestand |
| LF-04 / P0 | main: meist global O; #10: eng P, alle Branchbodies O | N-COND/N-FRAG | IFDEF um zwei vollständige interface-Prozeduren | fehlendes ELSE, split header, Visibility-/Elsejoin | E-DIR/E-COMP; I1–I4, D1–D3 |
| LF-05 / P0 | includes O | N-COND/N-FRAG, IncludeDirective | Originalinclude in bekannter Quellregion erhalten | nachfolgendes scheinbares procedure im unbekannten Zustand | E-INCLUDE; keine Resolverimplementierung |
| LF-06 / P0 | fragment N | N-ROOT/N-FRAG | expliziter unknown-fragment mit Feldliste | fehlender Kontext/Delimiter nicht als Unit reparieren | E-COMP für bekannte Kontexte; R1 |
| LF-07 / P1 | Generic-Typreferenzen O/P | N-TREF | Feld/Parameter mit TDictionary<string,TList<Integer>> | missing >, nested >> / >=, qualified segment | E-GENERICS/E-COMP; G1 |
| LF-08 / P1 | Generic-Deklarationsparameter O | N-GPARAM/N-TYPE | TBox<T> = class mit Feld T | missing name/comma/close | E-GENERICS/E-COMP; G2 |
| LF-09 / P1 | Constraints O | N-GPARAM | separate class/constructor-/record-/Typeconstraints | misplaced colon/incompatible constraints als Compilernegative | E-GENERICS/E-COMP; G3 |
| LF-10 / P1 | Generic-Routinedeklaration O/P | N-ROUTINE/N-GPARAM | class function Convert<T>(...) mit gültiger Implementation | split returntype, missing constraint/close | E-GENERICS/E-COMP; G4 |
| LF-11 / P2 | Generic-Callsites O bei erkanntem Kandidat | N-POST/N-TREF | bekannter gültiger Factory<T>()-Call | A<B, A<B>(C), qualifizierte Fälle; echte Ambiguität opaque | E-GENERICS/E-COMP; G5 |
| LF-12 / P1 | resourcestring O | N-DECL | resourcestring S='x'; nachfolgende Routine | missing equals/literal/semicolon, nächste Section | E-COMP; K-LF-12 |
| LF-13 / P1 | interface/dispinterface O | N-AGG/N-ROUTINE/N-PROP | ITest=interface(IInterface) mit GUID/Methode | missing GUIDclose/end, dispid-Suffix | E-COMP; K-LF-13 und separater dispinterface-Folge-PR |
| LF-14 / P2 | class/record helper O | N-AGG | record helper for Integer mit Methode | missing for/target/end, folgender Typ | E-COMP; K-LF-14 |
| LF-15 / P1 | arrays O/P | N-TFORMS | static/dynamic/open arrays in je eigenem Typ-/Paramkontext | missing bracket/of/element; Argumentliste nicht verwechseln | E-COMP; K-LF-15, open-array separat |
| LF-16 / P1 | pointers/class-of/file O | N-TFORMS | ^Integer, class of TObject, file of Byte | missing target/of, qualified target | E-COMP; K-LF-16 je Form eigener PR |
| LF-17 / P1 | enums/subranges/set types O | N-TFORMS | (a,b), 1..10, set of enum | missing comma/closer/range endpoint | E-COMP; K-LF-17 je Form eigener PR |
| LF-18 / P1 | procedural/reference types O | N-PROCTYPE | procedure(X:Integer) of object; reference to function:Integer | missing parameterclose/of object/returntype | E-COMP; K-LF-18 je Flavor eigener PR |
| LF-19 / P2 | anonymous methods O | N-ANON | gültiger reference-to-Typ + function body | missing end, locals, nested routine boundary | E-COMP; K-LF-19 |
| LF-20 / P2 | attributes O | N-ATTR | selbst deklarierter TCustomAttribute vor Typ/Member | missing ]/argumentclose; Index/Setkontext | E-COMP; K-LF-20 |
| LF-21 / P1 | method/routine directives P, häufig opaque Tail | N-ROUTINE | overload/override/calling conventions/forward/external/message mit gültigen Kontexten | Feld namens Virtual; missing semicolon/parameter | E-COMP; K-LF-21 je endlicher Direktivenfamilie |
| LF-22 / P1 | class methods/var/property/operator O/P | N-MEMBER/N-ROUTINE/N-PROP | class procedure, class var, class property, record operator | Präfix nicht als globaler Start, fehlende Trenner | E-COMP; K-LF-22 je Memberform |
| LF-23 / P2 | nested types/variant records O | N-NEST/N-AGG | nested type und separater tagged variant record | missing end/variant parens, class-of/proctype nicht Block | E-COMP; K-LF-23 je Form |
| LF-24 / P1 | initialization/finalization O/P | N-UNIT/N-BLOCK | Unit mit Initializer und Finalizer, jeweils Statements | fehlende Trenner/end, EndDot nicht konsumieren | E-COMP; K-LF-24 |
| LF-25 / P1 | program N | N-DROOT/N-ROOT | minimal program mit Uses/Var/Mainblock | missing header/end/dot, trailing Source | E-COMP; R2 |
| LF-26 / P2 | library N | N-DROOT/N-ROOT | library mit exportierter Routine/Exports | exports name/index/missing separator | E-COMP; R3 |
| LF-27 / P2 | package N | N-DROOT/N-USES/N-ROOT | package requires/contains mit fixture-Units | fehlender Itemname/in-String/semicolon/end | E-COMP auf passenden Package-Targets; R4 |
| LF-28 / P1 | threadvar/nested routines O/P | N-DECL/N-ROUTINE | threadvar + eigene lokale Routine mit Call | fehlender Body, äußeres end, Routineboundary | E-COMP; K-LF-28 je Form |
| LF-29 / P1 | inherited/sets/format-arguments O/P | N-POST/N-EXPR | inherited Foo; Setliteral [a..b]; Write(X:4:2) jeweils gültig | missing receiver/range/precision; Set versus Index | E-COMP; K-LF-29 je Form |
| LF-30 / P2 | inline var/for var/with O | N-STMT/N-LOOP | inline var, for var, with mit echten Decltypes | opaque Envelope/Elseownership muss erhalten bleiben | E-COMP; K-LF-30 je Statement |
| LF-31 / P2 | label/goto/raise-at O/P | N-STMT/N-TRY | deklarierte Labels/Goto, gültiges raise at | missing colon/target/address, nächste Anweisung | E-COMP; K-LF-31 je Form |
| LF-32 / P3 | asm O | N-STMT/N-FRAG | asm-Block in gültigem Zielcompilerkontext | string/comment end-Lookalikes, missing end | E-COMP targetgebunden; K-LF-32 nur Envelope, Operanden bleiben protected |
| LF-33 / P3 | old object/packed forms O/P | N-AGG/N-TFORMS | object/packed record/packed array in separaten Fixtures | fehlendes end/of/semicolon | E-COMP; K-LF-33 je Form |

Schreibweisen, die sich der gleiche Rollenquery erschließt, sind kein Anlass für Produktionsklassen. Zusätzlich je unterstütztem Flavor Routine-/Property-/Type-Modifikatoren, alternative Klammern, escaped/qualified Namen und gesetzte Compileroptionen im Featuremanifest nennen.

K-Featurezeilen mit mehreren Formen sind **PR-Familien, keine gebündelten Einzel-PRs**; die 09-Vorlage wird pro genannter Form instanziiert. Ein Release kann noch opaque Bereiche ausweisen, aber nicht deren AST-Readiness/Formatfreigabe behaupten. Asm wird ausdrücklich nur als sicher begrenzter opaque Envelope angestrebt; vollständige Assemblysyntax ist nicht Ziel des Delphi-Formatters.

Unabhängige Prioritäten: L1-Lexerqualität, I-Branchstruktur, S1-Formatter-Safety und O-Configreferenz können nach ihren jeweiligen Voraussetzungen ohne kompletten Parser laufen. G1 beginnt in eindeutigen Typpositionen, G5 zuletzt; keine semantische Namensauflösung als Pflicht.
