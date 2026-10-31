# 05 – Direktiven, Kontexte und Includes

Anforderungen DIR-01 bis DIR-06/CST-07/CST-08. Daten-/Statusmodell nur [14](14_CONTRACTS.md); physische Ownership nur [04](04_SOURCE_CST.md).

## Strukturelle Erkennung, keine Auswertung

Grouper arbeitet ausschließlich auf tkCompilerDirective: IFDEF/IFNDEF/IF/IFOPT öffnen; ELSEIF/ELSE wechseln; ENDIF/IFEND schließen strukturell. Define/undef, short/long Switches, Ressource, Include und unknown werden erhalten/klassifiziert, ohne Parameter-/Compilersemantik zu behaupten. I+ ist kein I-Dateiinclude; R+ keine Ressource. Vollständige Namensgrenzen und beide Kommentarformen beachten.

M2.8 besitzt eine finite Whitelist und linearen Paarungsindex. Dieses Verhalten ist Ausgangspunkt, keine vollständige Direktivenliste. LEGACYIFEND und weitere grammatikrelevante Direktiven können die Compilerkonformität beeinflussen: strukturelle Paarung und tatsächliche gültige Closerkombination sind verschiedene Fragen (E-DIR). Limit 32 beschreibt dokumentierte Compilerbasis, der Index muss auch darüber linear/terminierend erhalten und LimitReached melden. Keine willkürliche Aktivitätswahl.

Bei ungeschlossenen Kommentaren/Multiline-Strings kann ein vermeintlicher Closer im Literal-/Kommentartoken liegen. Der Index erfasst nur vorhandene Direktiventokens; er verspricht dann keine vollständige Branchliste. Kein Regex-Nachscanner, keine überlappende Lexik. Fehlende/überzählige Marker deterministisch diagnostizieren.

## Finite Kontextregistrierung

TContextState in 14 hat für jeden **implementierten** Kontext eine dokumentierte endliche Interpretation. Zusätzliche Kontexte werden einzeln mit Tests registriert. Gemeinsame Pflicht: bekannter Eintritt, exakte Bodygrenze, keine Missing-/Error-/Unknownteile, exakter Verbrauch einschließlich trailing Trivia und zulässiger Austritt.

| Kontext | Eintritt / erlaubte unabhängige Einheit | Separator-/Ownervertrag | Austritt / Join |
|---|---|---|---|
| unit-declarations/interface (I4) | abgeschlossene Deklarationsgrenze, erwartet RoutineDeclaration; anfangs procedure-Identifier-Semicolon | Header besitzt Semicolon; kein offener Name/Parameter/Typ/const-Abschnitt | wieder dieselbe abgeschlossene Listengrenze; kein neuer Owner |
| unit-declarations/implementation (späterer eigener Scope) | abgeschlossene Routinegrenze, vollständige Implementation | Bodyabschluss und finales Semicolon im Branch; keine übergreifenden local sections | wieder geschlossene Routinenliste |
| member-list (D1) | bekannter Class/Record-Owner und Visibilityanker | Membersemicolon/Visibilityowner eindeutig | Änderung von Visibility muss in allen Alternativen identisch bekannt sein; sonst JoinedExit unknown |
| statement-list (D2) | bekannter Listenowner und keine offene Then-/Do-Fortsetzung | Separatorstatus und offene If-Owner im Entry; kein stilles Semicolon am Fensterende ergänzen | derselbe zulässige Separator-/Elsezustand; gemeinsamen nachfolgenden else nicht umhängen |
| type-reference/expression (D3) | konkrete erwartete Rolle plus vollständiger gemeinsamer Besitzer | keine wiederverwendeten Präfix-/Suffixblätter, Operator-/Delimiterstatus bekannt | nur nach gesonderter Grammatikfreigabe; sonst Fragment/protected |
| unknown-fragment (R1) | kein Kontextbeleg | nur Original-/Direktivengruppierung | IsKnown=False, keine Formatfreigabe |

ExpectedRole ist jeweils die genannte N-*-Rolle; SeparatorState zunächst boundary-complete oder needs-separator/continuation, unbekannt explizit unknown. Section und OpenOwnerKinds dürfen beim Branchparse nicht unerlaubt wechseln. MemberSectionAnchor referenziert den Originalmarker, nicht einen geratenen semantischen Sichtbarkeitswert. GrammarEffects=unknown blockiert Join; bekannte Klassifikation allein beweist keine wirkungslose Direktive.

## Branchprüfung und Zusammenführung

1. Grouper liefert physische Branchbereiche, keine Syntaxblätter.
2. EntryState des Besitzers belegen; bei unknown nur vorläufige Struktur.
3. Jeden Body unabhängig im begrenzten Fenster und demselben Entry parsen. Ein Checkpoint darf verworfen werden, ohne finale Blätter zu verdoppeln.
4. Exact-consumption, Issues, Missing, Separator-/OpenOwner-/Effects-Zustand prüfen.
5. Alle möglichen Alternativen zusammenführen, **einschließlich leerer Alternative bei fehlendem ELSE**. Keine Auswertung, ob IF immer wahr sein könnte.
6. Nur äquivalente bekannte erlaubte Exitstates ergeben bekannten JoinedExit. Sonst den gemeinsamen Besitzer/Nachfolger als context_unknown schützen.

Jeder Branch kann lokal echte Methodenknoten enthalten und dennoch einen unbekannten Join erzeugen. Syntaxvollständigkeit ist kein Safetybeweis. Keine exponentielle Kombination von Defined-Werten, kein allgemeiner GLR-/Variationsparser. Verschachtelung linear indizieren; bei nicht unterstütztem Join Fragment vergrößern statt alle Konfigurationen auszuprobieren.

## Includes und unbekannte Effekte

Ein unresolved Include kann Deklarations-/Direktivenzustände verändern. Daher folgt weder aus Semicolon noch Routinekeyword oder sichtbarem end eine universelle Resynchronisierungsgrenze. Include wird nie automatisch gelesen/expandiert. Ein sicherer Suffix kann nicht allein aus lokal wohlgeformter Syntax bewiesen werden.

Nach Include darf der Parser nachfolgende Inseln als **vorläufige** Hierarchie mit context_unknown darstellen; Safety schützt den abhängigen Besitzer/Suffix bis zu einer nachgewiesenen Grenze oder EOF. Die ganze Datei opaque/protected zu belassen ist zulässig, wenn der Eintritt bereits unbekannt ist. Vorher bekannte unabhängige Regionen können strukturiert bleiben; ihre Editierbarkeit braucht eigenen Nichtabhängigkeitsbeleg. Kein normatives „nie whole-file opaque“.

Dieselbe konservative Behandlung gilt für unbekannte Direktiven mit möglicher fortwirkender Grammatik-/Lexikeffekt. Keine aktuelle Resolver-/Summary-Implementierung. Compilerrestriktionen für Includes innerhalb Statement-Parts werden durch E-INCLUDE geprüft; hypothetische Risikobeispiele sind Negativ-/Unsicherheitstests, keine als gültig ausgegebenen Compilerfixtures.

## Formatterkonsequenz und Migration

S0 erster Slice verweigert Dateien mit Direktiven/unsicherem Kontext insgesamt. Später kann lokale Teilformatierung freigeschaltet werden, wenn Besitzer, Kommentar-/Direktivenanker und JoinedExit geprüft sind. Keine Edits an Markertexten, keine Branchverschiebung; absolute Offsets dürfen nur durch gemappte vorherige Edits verschoben sein.

I1 isoliert bestehenden Index, I3 gruppiert Bodies, I4 parst einen Unit-interface-Kontext. Includes/unknown/inside-production-Guards bleiben, bis ein gesonderter PR den jeweiligen sicheren Ersatz belegt. Entfernen von FUnsafeDirective ist kein akzeptierter allgemeiner Migrationsschritt.
