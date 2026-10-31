# 02 – Architektur, Owner und Abhängigkeiten

Anforderungen: API-01 bis API-03, CST-04, FMT-01, CFG-01 bis CFG-07, IO-01 bis IO-04. **Typen/Signaturen stehen ausschließlich in [14](14_CONTRACTS.md).** Zielvertrag ist nicht Implementierungsbestand.

## Datenfluss

Bytequelle → IO-Decoder → UTF-16 → Lexer → physischer Source-CST mit Kontextfakten → Slot-Safety → Regeln/Layout → Edits → Verifikation → String → optional geprüfter Writer.

Profilbytes → NativeReader → Registry/Relevanz → EffectiveOptionsBuilder → immutable FormattingOptions. Die Engine bekommt Optionen, lädt aber keine Profile. Der S0-Testaufrufer darf explizite interne Optionen liefern, ohne native Kompatibilität zu behaupten.

Eine spätere Compilation-Sicht kann SourceOrigin(FileId, Span)-Referenzen auf mehrere Trees bilden. Sie ersetzt den physischen Baum nicht und ist kein aktuelles Gate, AST- oder Preprocessorauftrag.

## Abhängigkeiten (A → B bedeutet A benutzt B)

| Owner | Darf benutzen | Verantwortung |
|---|---|---|
| Core.Spans/Diagnostics | RTL | UTF-16/Diagnostics |
| Core.TextEdits (S1) | Core/RTL | einziges Editrecord, keine Freigabe |
| Lexer.* | Core/RTL | Tokenisierung; keine Syntax/Defines/Dateien |
| Syntax.Kinds/Nodes/Tree | Core/Lexer/RTL | Originalbaum/Arena/Fakten |
| Syntax.Directives (I1) | Core/Lexer/RTL | Klassifikation/Paarungsindex, keine Grammatikfreigabe |
| Syntax.Query (bei Bedarf) | Syntax/Core/Lexer | geliehene Rollen-/Statusqueries |
| Parser.Reader/TokenWindow/Delphi | Syntax/Lexer/Core/RTL | Grammatik/Kontexte/Recovery |
| Formatting.Options | Core/RTL | DTOs/Herkunft, kein NativeReader |
| Config.Native/Schema | Core/RTL | Rohprofil/Registry, kein IO/Engine |
| Config.Effective | Config + Formatting.Options/Core | Optionen/Policy/Capabilities |
| Formatting.Safety/Rules/Layout/Edits/Verification/Engine | Parser/Syntax/Lexer/Core/Formatting.Options | Slots/Layout/Verifikation, kein Configdecoder/IO |
| IO.TextFiles | Core/RTL | Bytes/Codec/Hashes/gesicherter Writer |
| CLI | IO/Config/Formatting/RTL | Pfade/Argumente/Exitcodes |
| Oracle-/Corpusadapter | benötigte Bibliotheken + Plattformtools | externe Testkopien; nie Coreabhängigkeit auf Tests |

Nicht für jede logische Rolle sofort eine Unit erzeugen. S1 darf Verifikation privat in Engine/Edits halten. Parser.Expressions/Declarations/Statements erst bei konkretem Nutzen und identischer Regressionsevidenz auslagern. Kein Infrastruktur-Rewrite vor einem benötigten Feature.

## Ownership

Lexer besitzt Source/Wertarrays. Parser leiht ihn während Parse, konstruiert arenaeigene Elemente und überträgt auf Erfolg genau eine Arena an den Tree. Kinder/Root sind geliehen, keine rekursive Childownership. Fakttabelle gehört demselben Tree.

Direktivenindex besitzt Wertdaten/Diagnostics, niemals Blätter. Tokenansichten leben höchstens so lange wie der geliehene Lexer. Ein Window besitzt weder EOF noch Arena.

FormatText leiht Optionen, besitzt temporäre Lexer-/Tree-/Layoutdaten und liefert ein unabhängiges FormatResult. ConfigResult besitzt Rohbytes/Einträge; EffectiveOptionsResult besitzt seine Optionen. Read-only Count/Get statt öffentlicher Aliasarrays, siehe 14.

## Fehler und Snapshots

Lossless Lexing, lossless Tree und sichere Formatierung sind verschiedene Aussagen. Struktur erteilt keine Editberechtigung. Unbekannter Kontext darf über Nachfolger fortwirken.

Sourcefehler ergeben Diagnostics/Recovery; Configfehler Import-/Optionsfehler; Formatierungsfehler refused mit unverändertem Input; IOfehler keinen Teiloverwrite. API-Missbrauch bleibt Exception, Allocation-/OSfehler kein vermeintlicher Parsererfolg.

Zunächst Ganzdatei-Verarbeitung mit vorhandenen Stringreferenzen, kein SourceSnapshot-Rewrite. SourceIdentity/exakte Snapshotgleichheit schützt Edits; Byte-/Codecorigin gehört später IO. LineMap bei Bedarf aus Originaltext einschließlich Kommentaren/Literalen; Spalten als UTF-16-Codeunits, visuelle Tabbreite separat.

Core: Delphi-12.3-kompatible RTL, DUnitX einzige Testbibliothek. XML-Reader ohne DTD/External-Entity-/Assemblyausführung; Auswahl und Plattformnachweis im C1-PR.
