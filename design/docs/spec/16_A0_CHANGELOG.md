# 16 – A0-Änderungsnachweis und Selbstprüfung

**Stand:** 31.10.2026. Dieses Dokument beschreibt die tatsächlich durchgeführte Dokumentkonsolidierung, nicht die Implementierung der Zielverträge. Reviewbefunde sind vollständig in [15](15_TRACEABILITY.md) disponiert.

## Schutz vorhandener Dateien / Baseline

Vor Beginn war ausschließlich design/ untracked, der versionierte Arbeitsstand sauber. Alle vorhandenen design-Dateien wurden vor Korrektur in build/a0-original-ffdfd06ab1684e3e900b2f399ff0275b/design-before-a0.zip samt hashes.json und ursprünglicher HEAD-/Statusinformation gesichert. Der bisherige M2.8-Branch bleibt bestehen. Der A0-Branch basiert ausdrücklich auf Remote-main 98fdb7e6ec8f590f0239348463cb1bda4dcd23f7; er enthält keinen #10-Code. #10 wurde erneut als offen bestätigt und nicht verändert/gemergt.

Die 19 importierten Dokumente werden direkt korrigiert, nicht durch einen zweiten Review ersetzt. ARCHITEKTUR_REVIEW.md und sämtliche schon vorhandenen review-evidence-Dateien bleiben als historische Belege bytegleich. Deren import-manifest.json hält die ursprünglichen Importhashes fest, nicht aktuelle A0-Hashzusagen. Geplante APIs sind dokumentiert, nicht implementiert/kompiliert.

## Änderungen gegenüber v1.0

| Dokument | Änderung |
|---|---|
| README | Dokumentenhierarchie, Freigabestatus, exakte main/#10-Grenze und Historienkennzeichnung |
| CONTRIBUTING_IMPLEMENTATION | scopeangemessene Evidenz, Backup-/Baselinepflicht, keine pauschale Pflicht zu unpassenden Runtime-/Oracleläufen |
| ADR-001 | eindeutiger physischer Baum; Include-/EOF-Schutz zulässig, Branchkontexte und Fragmente präzisiert |
| ADR-002 | Slots statt Intervallfreigabe allein; Randinsertions/Konflikte/Anker/S0/Verifikation |
| ADR-003 | getrennte Recognition/Relevance/Capabilities; native Tabs/Overrides, striktes Invalidverhalten |
| 01 | 49 eindeutige Anforderungen; realistische Recovery-/Include-/Compatibilitygates |
| 02 | richtiger Abhängigkeitsgraph/Owner; Engine kennt effektive Optionen, keinen NativeReader |
| 03 | vorhandenen Lexer erhalten; offene 12.3-/Control-/Unicodegrenzen und absorbierte Marker explizit |
| 04 | vollständiges Rollenregister, gemeinsame Tokens, Marker-/Triviaownership, AST-Readiness ohne AST |
| 05 | finite Kontextverträge, exakter Windowverbrauch, Join einschließlich fehlendem ELSE, konservative Includeeffekte |
| 06 | konkretes S0, Anker-/Slotkonflikt-/Fingerprintalgorithmus, refused/partial, kein semantischer Universalbeweis |
| 07 | echte ältere Profilbefunde statt Schema-Unkenntnis als pauschale Aussage; keine Übertragung nach 12.3 ohne Evidenz |
| 08 | benannte zukünftige Testverträge und PR-spezifische Gates, historische Testzahlen nicht aktuelle Ausführung |
| 09 | kleine PRs mit Voraussetzungen/Dateien/APIs/Tests/Gates/Nichtzielen; früher unabhängiger S1-/Oracle-Strang |
| 10 | priorisierte LF-Featurematrix inklusive aller Reviewlücken, konkrete positive/Recovery-/Compilerproben pro Form |
| 11 | offene empirische Fragen mit konkretem Experiment/Owner/Gate/Fallback; entschiedene Architekturfragen entfernt |
| 12 | Verantwortung/stabile APIs/Grenzen/Tests jeder vorhandenen Unit, main versus #10, verbindliche Dispositionstrategie |
| 13 | E2E-Verträge auf S0/Config-/Include-/Byte-/Slotentscheidungen angepasst; keine falsche ANSI-Erkennung |
| fixtures/contracts | Entwurfstatus und Verweis auf eindeutige Test-/Rollenregister statt doppelter abweichender Skizzen |
| neu: 14 | einziger Definitionsort der Daten-/API-Verträge, Status/Window/Slots/Edit/Options/Results/Config |
| neu: 15 | vollständige Requirement→Test→Schritt-Matrix, R-01–R-14-Zuordnung |
| neu: ADR-004 | Vertrags-/Baseline-/Sliceentscheidungen technisch begründet |
| neu: 16 | Migrations- und Selbstprüfnachweis |

## Migration früherer IDs

Anforderungsnummern gelten ab hier im **A0-Dokumentstand**; ältere Paket-/Review-IDs sind historische Referenzen. Kein Compiler-/persistiertes APIordinal wird dadurch geändert. Wesentliche fachliche Umordnung:

| v1.0-Referenz | A0-Nachfolger / Änderung |
|---|---|
| LEX-01..03 | gleiche Grundbereiche, LEX-04 ergänzt echte Sprachbelege |
| CST-01..06 | Grundbereiche erhalten, CST-03/CST-05 mit Unsicherheits-/Recoverypräzisierung; CST-07..10 ergänzt |
| DIR-01/02 | gleiche Hauptbereiche, DIR-02 gestattet jetzt beleglos größeren Schutz statt unmöglicher lokaler Garantie |
| FMT-01 | FMT-01 |
| FMT-02 (Regelstufen) | FMT-09 |
| FMT-03 (sichere Edits) | FMT-02/FMT-03/FMT-05/FMT-06 |
| FMT-04 (Idempotenz) | FMT-04 |
| FMT-05 (CLI) | IO-02/IO-03; A0-FMT-05 bezeichnet nun Editkonfliktvertrag |
| FMT-06 (Encoding) | IO-01/IO-04; A0-FMT-06 bezeichnet Verifikation |
| CFG-01 | CFG-01 |
| CFG-02 | CFG-02/CFG-05/CFG-06 |
| CFG-03 | CFG-03, präzisiert um native Editorwerte |
| CFG-04 (Oracle) | CFG-07; A0-CFG-04 bezeichnet ungeprüfte Defaults/Versionen/Prioritäten |
| QA-01/02 | QA-01..04, passend zur jeweiligen PR-Art |
| CST-100..190/SAFE-100..190 und ältere Fixture-Skizzen | Testentwürfe, keine Requirementdefinition; ersetzt durch T-Register in 08 und E2E in 13 |
| Q-01..12 | durch konkrete E-Experimente in 11 ersetzt; CLIdefault/S0/Slot-/Status-/Policyentscheidungen sind nicht länger offene Fragen |
| A-/B-/C-/D-/E-/F-/G-Großphasen | durch einzeln überprüfbare Schritte in 09 ersetzt |

## Beschlossen im Entwurf versus experimentell offen

Entschieden: physischer Originalbaum, additive Rollenqueries, orthogonale Issues, Tree als einziges ParseResult, Window-Endstatus ohne Token, tokengebundene Slots/geschlossene Grenzen, S0, einmalige vollständige Verifikation, fehlgeschlagene Invariante→refused, CLIdefault check, Relevance-/Recognition-/Supporttrennung, keine geratenen Prioritäten, #10-Disposition als I1-Voraussetzung.

Offen und gezielt blockierend: tatsächliche Delphi-12.3-Lexik-/Generic-/Directive-/Includegrenzen, natives 12.3-Schema/Defaults/Duplikate/Tabs-/IDEvorrang, Oracleausgaben/Interaktionen/Case, Codec-/Write-/Plattformexperimente. Vollständig benannte Experimente ausschließlich in 11. A0 beansprucht keine Resultate dieser Experimente.

## Selbstprüfung

Automatischer Dokumentcheck am 31.10.2026: **PASS** für 23 normative Dokumente, 49 eindeutige Anforderungen und 49 vollständige Traceabilityzeilen, 27 Testverträge, 32 PR-Schritte (zuzüglich einzeln instanziierter K-Featureformen), 33 Features, 28 Rollen und 14 Experimente. 57 lokale Markdownlinks lösen auf; referenzierte Requirement-/Test-/Rollen-/Experiment-IDs sind definiert. Kanonische Typdefinitionen stehen nur in 14. Alle 12 zuvor vorhandenen historischen Review-/Evidenzdateien wurden gegen die gesicherten Originalhashes geprüft und sind unverändert.

Das Prüfhilfsskript liegt ausschließlich als lokales ignoriertes Artefakt unter build/a0-check-docs.ps1 und gehört nicht zum Dokumentations-PR. Sein erster Lauf hatte die Reviewzeilen R-01–R-14 irrtümlich als Requirements gelesen; nach Eingrenzen auf die tatsächlichen Requirementpräfixe bestand der Check. Zusätzlich manuelle Prüfung von Owner-/Scope-/Safetyaussagen; maschinell aufgelöste Links sind kein semantischer Konsistenzbeweis. Git-Diff-/Whitespaceprüfung: PASS; alle 36 gestagten Dateien liegen unter design/. Keine Produktions-/Corpuspfade im Commit. Die gestagten historischen Evidenzblobs wurden zusätzlich mit git hash-object --no-filters gegen die Originaldateien verglichen: bytegleich.

Zusätzliche Archivmetadatei review-evidence/.gitattributes verhindert Git-EOL-Normalisierung der unveränderten Belege und kennzeichnet deren CRLF als gültiges Zeilenende. Die bereits vorhandene abschließende Leerzeile von coverage-isolated-rerun.txt wird gezielt als historischer Output zugelassen; normative Dokumente erhalten keine Whitespaceausnahme. So bleiben auch die versionierten Archivbytes den ursprünglichen Hashbelegen entsprechend.

Manuell gegengeprüft: keine Pflicht zu universeller Include-Resynchronisierung, keine garantierte Absichtsrekonstruktion bei malformed Source, keine automatische Gleichsetzung von Struktur/Safety/Kompatibilität, kein Extra-EOF im Fenster, keine duplizierten Conditional-Owner, keine erfundenen RADdefaults, kein voller Parser als S1-Voraussetzung, keine unbounded Revalidierungsschleife und keine Freigabe von I1/S1 durch den Dokumentationsplan.

Build-/DUnitX-/Corpus-/Compiler-/Oracleläufe wurden in A0 nicht ausgeführt. Das ist eine reine Dokumentänderung. Historische Reviewlogs bleiben ausdrücklich historisch; neue Delphi-APIverträge müssen erst beim jeweiligen Implementierungs-PR tatsächlich kompiliert werden.
