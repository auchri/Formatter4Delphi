# Formatter4Delphi – konsolidierte Zielspezifikation A0

**Stand:** 31.10.2026. **Status:** zur Freigabe durch den A0-Dokumentations-PR. Architekturentscheidungen dieses Pakets sind festgelegt; ihre Annahme erfolgt durch Review dieses PRs. Keine Implementierungsfreigabe und kein Nachweis vollständiger RAD-Studio-Kompatibilität.

Ziele: hochwertiger verlustfreier Delphi-Lexer, physischer projektunabhängiger Source-CST und sicherer Formatter mit überprüfbarer Unterstützung originaler RAD-Studio-Profile. AST, vollständiger Compiler/Preprocessor, Include-Resolver, LSP und IDE-Plugin sind außerhalb des Vorhabens.

## Gültigkeit und Navigation

Anforderungen stehen ausschließlich in [01](docs/spec/01_PRODUCT_REQUIREMENTS.md); kanonische Daten-/API-Verträge ausschließlich in [14](docs/spec/14_CONTRACTS.md). Fachdetails konkretisieren diese Verträge ohne konkurrierende Typdefinitionen. [15](docs/spec/15_TRACEABILITY.md) verknüpft Anforderungen, Tests, Schritte und R-01 bis R-14. [16](docs/spec/16_A0_CHANGELOG.md) dokumentiert Änderungen, Selbstprüfung und Archivgrenzen.

| Dokument | Verantwortung |
|---|---|
| [01 Anforderungen](docs/spec/01_PRODUCT_REQUIREMENTS.md) | eindeutige Muss-/Soll-IDs und Scope |
| [02 Architektur](docs/spec/02_ARCHITECTURE.md) | Layer, Owner, Abhängigkeiten |
| [03 Lexer](docs/spec/03_LEXER.md) | verlustfreie Lexik, Compilergrenzen |
| [04 Source-CST](docs/spec/04_SOURCE_CST.md) | physische Shapes und Rollen |
| [05 Direktiven](docs/spec/05_DIRECTIVES.md) | Kontexte, Branches, Includes |
| [06 Formatter](docs/spec/06_FORMATTER.md) | Slots, S0, Verifikation |
| [07 Native Config](docs/spec/07_RAD_CONFIG.md) | Import, Relevanz, Capabilities |
| [08 Tests](docs/spec/08_TESTS.md) | benannte Testverträge und Evidenzregeln |
| [09 Implementierungsplan](docs/spec/09_IMPLEMENTATION_PLAN.md) | einzelne PRs mit Gates/Nichtzielen |
| [10 Sprachmatrix](docs/spec/10_LANGUAGE_COVERAGE.md) | Delphi-12.3-Features, Rollen, Compilerproben |
| [11 Experimente](docs/spec/11_OPEN_QUESTIONS.md) | offene Oracle-/Compilerfragen |
| [12 Codeabgleich/Baseline](docs/spec/12_CURRENT_CODE_AUDIT.md) | vorhandene Units, main versus PR #10 |
| [13 Abnahmeszenarien](docs/spec/13_ACCEPTANCE_SCENARIOS.md) | E2E ohne erfundene Goldens |
| [14 Kanonische Verträge](docs/spec/14_CONTRACTS.md) | einzige normative API-/DTO-Definition |
| [15 Traceability](docs/spec/15_TRACEABILITY.md) | Requirement → Test → PR; Reviewbefunde |
| [16 A0-Änderungen](docs/spec/16_A0_CHANGELOG.md) | Entscheidungen, Prüfung, Migration |
| [Implementierungsregeln](CONTRIBUTING_IMPLEMENTATION.md) | Arbeits- und Reviewablauf |

ADRs: [001 Source-CST](docs/adr/ADR-001-source-cst.md), [002 sichere Slots](docs/adr/ADR-002-safe-editing.md), [003 native Profile](docs/adr/ADR-003-native-config.md), [004 Verträge/Baseline](docs/adr/ADR-004-contracts-and-baseline.md).

## Aktueller Code ist nicht Zielimplementierung

Geprüftes Remote-main: M2.7, SHA 98fdb7e6ec8f590f0239348463cb1bda4dcd23f7. Offener [PR #10](https://github.com/auchri/Formatter4Delphi/pull/10): M2.8-Head 65000fca7ce3890541aa1f691a17666ef47cfb92. A0 basiert auf main und enthält nur Dokumentation. Details: 12. I1 wartet auf eine ausdrücklich dokumentierte Disposition von #10; kein automatisches Merge.

Nach Annahme von A0 regelt dieses Paket die zukünftige Architektur. Root-AGENTS.md und CODEX_START.md führen zu derselben Dokumentenhierarchie und regeln sicheres, ausdrücklich beauftragtes Arbeiten. docs/* beschreibt implementierte APIs, vorhandene Tests und historische Evidenz; diese Dokumente sind keine konkurrierende Zielarchitektur. Keine Implementierung ist allein durch A0 autorisiert. Jede Implementierungsaufgabe nennt ihren neu beauftragten Scope; notwendige Bestandsvertragsänderungen erfolgen im betreffenden PR.

ARCHITEKTUR_REVIEW.md und review-evidence/* bleiben unveränderte historische Belege der vorherigen Reviewaufgabe. Ihre damaligen Vorschläge/Resultate sind keine zweite normative Architektur. import-manifest.json belegt den Import **vor A0**, nicht aktuelle Dokumenthashes. Die uncommitteten Eingaben wurden vor Bearbeitung gesichert; siehe 16.

Ein Originalbaum mit einmaliger Tokenownership; keine Branch-Auswahl. Includes dürfen Schutz bis EOF/gesamte Datei verursachen. Struktur und Editfreigabe sind getrennt. S0 verändert nur positiv freigegebene Trivia-Slots. Native Tab-/Indentwerte bleiben native Werte mit Herkunft; keine stillen eigenen Defaults. Kompatibilität gilt nur je Version/Option/Wert/Feature mit echter Evidenz.

## Reproduzierbare Dokumentenvalidierung

PowerShell 7, vom Repositoryroot:

~~~powershell
pwsh -NoProfile -File scripts/ValidateDesignDocs.ps1
~~~

Der [versionierte Validator](../scripts/ValidateDesignDocs.ps1) ist rein lesend und benötigt weder lokale build-Backups noch eine persönliche Verzeichnisstruktur. Der Standardroot wird aus dem Skriptpfad abgeleitet; -Repository erlaubt einen anderen Checkout. Harte Fehler (Exit 1) nennen Datei/Zeile/Ursache, Hinweise sind getrennt; Erfolg ist Exit 0. Geprüft werden Register/Traceability, relative Markdownlinks und offensichtliche konkurrierende Pascal-APIdeklarationen in Codeblöcken. Das ist kein Beweis semantischer Widerspruchsfreiheit oder der Kompilierbarkeit geplanter APIs. Historische Reviewdateien werden nicht als normative Zielregister eingelesen.
