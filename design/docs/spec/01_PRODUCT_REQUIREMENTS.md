# 01 – Anforderungen und Scope

**Normativ:** MUSS ist Abnahmekriterium, SOLL eine begründet abweichbare Empfehlung. Einziger Definitionsort für Requirement-IDs. Andere Dokumente referenzieren diese IDs. Nachweise/Schritte: [15](15_TRACEABILITY.md). Datenmodelle: [14](14_CONTRACTS.md).

Zielbasis: Delphi 12.3, pure RTL, zuerst Win64. Compilerfamilie/Plattform und spätere Sprachversionen werden separat ausgewiesen. „12.3+“ verspricht keine ungeprüften künftigen Features. Ein Release benennt seinen tatsächlich unterstützten Sprach-/Optionsumfang nach 10; Lossless/Opaque ist keine vollständige Grammatikunterstützung. Vollständige Delphi-12.3-Grammatik bleibt Entwicklungsziel. AST, Semantik-/Symbolauflösung, Compiler/Preprocessor, Include-Resolver, MSBuild, LSP und IDE-Plugin sind außerhalb des Plans.

## Lexer

| ID | Stärke | Vertrag |
|---|---|---|
| LEX-01 | MUSS | Deterministischer Stream deckt jede UTF-16-Codeunit exakt einmal ab; ein originales EOF am Sourceende. |
| LEX-02 | MUSS | Tokenarten/Literale/Kommentare/Direktiven/Numerale/Identifier nach 03 unterscheiden; keine Generic-/Define-/Includeentscheidung im Lexer. |
| LEX-03 | MUSS | Malformed Source lossless mit stabilen Diagnostics; jeder Loop konsumiert, beendet oder gibt zurück. |
| LEX-04 | MUSS | Sprachgrenzen durch Token-/Span-/Diagnostic- und zielcompilergebundene Tests belegen; Unicode/Controls getrennt von Lossless prüfen. |

## Source-CST

| ID | Stärke | Vertrag |
|---|---|---|
| CST-01 | MUSS | Physischer Baum enthält jedes Originaltoken inklusive Trivia/EOF genau einmal in Originalreihenfolge; Serialize traversiert Blätter. |
| CST-02 | MUSS | Freigegebene Grammatik besitzt Hierarchie/Rollen nach 04/10; Container allein zählen nicht als Strukturgewinn. |
| CST-03 | MUSS | SyntaxIssues und Missing/Error/Opaque/Fragment nach 14 unterscheiden; Kontextunsicherheit ist kein bewiesener Syntaxfehler. |
| CST-04 | MUSS | Source-CST benötigt keine Projektkonfiguration, Includes oder Filesystemoperationen. |
| CST-05 | MUSS | Gültige unterstützte Syntax bindet Separatoren/else/end korrekt; mehrdeutige Fehler-Recovery ist deterministisch, lossless und geschützt, ohne Absichtsrekonstruktion zu versprechen. |
| CST-06 | MUSS | Bestehende APIs/Enumwerte und Arena-/Sourceownership bewahren; notwendige Änderungen explizit migrieren. |
| CST-07 | MUSS | Conditional-/Fragment- und gemeinsame Präfix-/Suffixsyntax haben eindeutige Owner; keine Blattduplikate oder konkurrierenden Source-Bäume. |
| CST-08 | MUSS | Bounded Ansicht hält globale Tokenindizes ein und erzeugt kein zusätzliches Original-/virtuelles EOF-Blatt. |
| CST-09 | MUSS | Child-Rollen erlauben Queries ohne Source-Reparse; AST-Readiness nur pro vollständig unterstütztem Konstrukt. |
| CST-10 | MUSS | Explizite File-/Fragment-/Expression-/Statement-Modi; unbekannter Fragmentkontext bleibt vorläufig/protected. |

## Direktiven

| ID | Stärke | Vertrag |
|---|---|---|
| DIR-01 | MUSS | Alle lexikalisch erkannten Conditional-Tokens/Branches in Originalreihenfolge, ohne Aktivitätsauswahl. |
| DIR-02 | MUSS | Includes nur erhalten/klassifizieren; ohne Zustandsbeleg darf Schutz bis EOF oder ganze Datei reichen. |
| DIR-03 | MUSS | Branch-Vollständigkeit durch bekannte Entry-/Exit-Kontexte, exakten Fensterverbrauch, Separatorbesitz und sämtliche Alternativen belegen. |
| DIR-04 | MUSS | Vorläufige Struktur und Formatfreigabe trennen; unbekannter JoinedExit propagiert Kontextunsicherheit. |
| DIR-05 | MUSS | Lexikalisch absorbierte Direktiventexte nicht durch Rawtext-Paarung zu überlappenden Tokens erheben. |
| DIR-06 | MUSS | Strukturpaarung, Compilerkonformität, Limits und unbekannte Direktivenwirkungen trennen; keine Preprocessoremulation. |

## Formatter

| ID | Stärke | Vertrag |
|---|---|---|
| FMT-01 | MUSS | FormatText ist reine Source-CST-basierte Stringtransformation ohne AST, IO oder Compilerkontext. |
| FMT-02 | MUSS | Nur positiv freigegebene tokengebundene Trivia-Slots editieren; Identität/Anker/Barrieren nach 14. |
| FMT-03 | MUSS | S0 schützt Direktiven/Kommentare/Literale/Opaque/Error/Missing und unsichere Besitzer; Input-Lexerfehler verweigert ganze Formatierung. |
| FMT-04 | MUSS | Determinismus/Idempotenz erfolgreicher Formatierung; keine Host-/Dictionarydefaults. |
| FMT-05 | MUSS | Eine konfliktfreie kanonische Editmenge auf unverändertem Snapshot; keine Insertions an geschlossenen Schutzgrenzen. |
| FMT-06 | MUSS | Re-Lexing, Rollenfingerprint, gemappte Token-/Anker-/Schutztextprüfung; keine neuen Diagnostics im freigegebenen Kontext. |
| FMT-07 | MUSS | Unchanged/Changed/Partial/Refused und Compatibility getrennt melden; S0 erster Slice erzeugt kein Partial. |
| FMT-08 | MUSS | Preserve-EOL ohne implizite Normalisierung; S0 führt keine neuen EOL ein und erhält vorhandene. |
| FMT-09 | MUSS | Regelumfang/Optionwerte/Priorität/Safetyvorbedingungen sichtbar; keine Autofixes/Syntaxreparaturen. |
| FMT-10 | MUSS | Sicherheitsbeschränkte native Regeln als nicht/teilweise unterstützt melden, statt Safety für Oraclegleichheit aufzuheben. |

## Config

| ID | Stärke | Vertrag |
|---|---|---|
| CFG-01 | MUSS | Echte versionierte Profile sicher einlesen; alle Einträge mit Originalherkunft inventarisieren. |
| CFG-02 | MUSS | Recognition, Delphi-Relevance und Capabilitysupport je Wert/Feature getrennt bestimmen. |
| CFG-03 | MUSS | Native Tab-/Indentoptionen als native Herkunft; eigene Overrides explizit ausweisen. |
| CFG-04 | MUSS | Keine unbestätigten Defaults, Produktversionen oder Prioritäten aus Schemawert/Dateipfad raten. |
| CFG-05 | MUSS | Strict blockiert unbekannte mögliche Wirkung/unsupported angeforderte Wirkung; belegte Irrelevanz darf nicht unnötig blockieren. |
| CFG-06 | MUSS | Lenient darf explizite Supportlücken akzeptieren/melden, invalid/ambiguous Config nie still heilen. |
| CFG-07 | MUSS | Native Kompatibilität nur für belegte Version/Key/Wert/Feature/Regelumfang mit reproduzierbaren Oraclefixtures. |

## IO, APIs, Nachweise

| ID | Stärke | Vertrag |
|---|---|---|
| IO-01 | MUSS | BOM/Codec-Provenance getrennt von UTF-16; Roundtrip beweist keine beabsichtigte Codepage. |
| IO-02 | MUSS | check/diff öffnen keinen Writer; CLI ohne Modus ist check, niemals impliziter Write. |
| IO-03 | MUSS | write erst nach Verifikation/Darstellbarkeits-/Sourcehashprüfung und gesichertem atomarem Replace; kein Teiloverwrite. |
| IO-04 | MUSS | Byte-/EOL-/Metadata-/Backup-/Linkpolicy vor Writerfreigabe testen/dokumentieren. |
| API-01 | MUSS | Genau ein kanonischer Vertrag nach 14 für Tree/Diagnostics/Status/Edit/Optionen/FormatResult/ConfigResult/Slotfreigabe. |
| API-02 | MUSS | Immutable Ergebnisse, klare Lifetimes, keine Aliasarrays oder Dangling-Lexerreferenzen. |
| API-03 | MUSS | Abhängigkeiten nach 02; Lexer/CST kennen keine Config-/IO-/Compilerzustände. |
| QA-01 | MUSS | Roundtrip plus Hierarchie-/Rollen-/Span-/Tokenorder-/Lifetime-/Recoverytests; reproduzierbare Fuzz-/Stressdaten. |
| QA-02 | MUSS | Nur ausgeführte Checks samt Toolchain/Artefakten ausweisen; Altprogramme sind kein frischer Build. |
| QA-03 | MUSS | M2.7-Corpus unverändert; identische dekodierte Dateimenge und gewichtete Metriken vergleichen. |
| QA-04 | MUSS | Requirement-Test-Schritt-Links und Compiler-/Oracle-Lücken je Feature pflegen; keine fiktiven Resultate. |
| BASE-01 | MUSS | #10 ausdrücklich disponieren; Dokumentations-/Implementierungsbasis und historische Evidenz nach 12 trennen. |

Ressourcenlimits gegen Stack-/Zeit-/Speicherexzesse gehören zu LEX-03/CST-05/DIR-06/FMT-06. Der einführende PR nennt konkrete Limits und deterministische Abbruchdiagnosen. API-/Testskizzen sind keine zusätzliche Implementierungsfreigabe.
