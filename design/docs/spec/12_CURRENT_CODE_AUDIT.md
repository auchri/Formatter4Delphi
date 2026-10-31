# 12 – Bestandsverträge und verbindliche Baselinestrategie

Anforderungen BASE-01/CST-06/API-02/API-03/QA-02/QA-03. Geprüft 31.10.2026 über GitHub-Metadaten/Compare und lokalen Code. Historische Evidenz wird nicht als neue Ausführung ausgegeben.

## main, PR #10 und A0

Remote-main: 98fdb7e6ec8f590f0239348463cb1bda4dcd23f7 (M2.7 nach PR #9). [PR #10](https://github.com/auchri/Formatter4Delphi/pull/10) offen/nicht gemergt, Head 65000fca7ce3890541aa1f691a17666ef47cfb92, ein Commit voraus, 27 Dateien. Der ursprüngliche lokale Checkout entsprach diesem PR-Head, der lokale main-Branch war veraltet. Kein lokales main als ungeprüfte Baseline verwenden.

**A0-Strategie:** reiner Dokumentationsbranch codex/a0-architecture-consolidation direkt vom geprüften Remote-main-SHA. Keine Produktions-/Corpusänderungen aus #10 im Diff. Der vorhandene uncommittete design-Ordner wurde vor Korrektur bytegenau als ZIP und Hashmanifest unter ignoriertem build/a0-original-ffdfd06ab1684e3e900b2f399ff0275b gesichert; ursprüngliche Branch-/HEAD-/Statusinformation liegt daneben. Bestehende unabhängige Änderungen dürfen nicht überschrieben werden. Branchwechsel erst nach dieser Sicherung und sauberem versioniertem Arbeitsstand.

**Weiterarbeit:** #10 wird separat fachlich beurteilt, weder von A0 gemergt noch verworfen. Empfohlene Disposition ist Übernahme als begrenzte M2.8-Zwischenstufe nach eigenem Review. I1 startet erst, wenn diese Disposition ausdrücklich dokumentiert und der akzeptierte Stand auf main verfügbar ist. Dann frischen main-SHA samt #10-Merge/äquivalentem akzeptiertem Commit erfassen, Implementierungsbranch von diesem main erzeugen, tatsächliche Testbaseline neu belegen.

Bei Ablehnung/Änderung von #10 bleibt I1 nach jetzigem Plan blockiert; ein eigener neuer Scope entscheidet, wie Indexarbeit gegen M2.7 geschnitten wird. Kein stilles Cherry-Pick und kein Refactor mit versteckter Pilotimplementierung. Unabhängige S1/O1/L1-Arbeit kann nach separater Beauftragung gegen ihren konkret gepinnten main beginnen, ohne #10-Fähigkeiten zu behaupten. Nach A0-PR-Erstellung stoppen.

## PR #10: passend versus Übergang

| Bestandteil | Bewertung / weitere Behandlung |
|---|---|
| finite Directive-Klassifikation und linearer Paarungsindex | nützliche wiederverwendbare Basis; I1 extrahiert, keine zweite Paarungsimplementierung |
| unveränderte Lexer-/Reader-/Arena-/Tokenverträge | beibehalten |
| skConditionalDirectiveRegion ordinal 56, ein opaque Child | Übergang; falls übernommen Ordinal erhalten, I3 erweitert Rollen statt zweiter Region-Kind |
| enge Procedure-Envelopes im Index | Pilotpolitik, keine allgemeine Grammatik; im Parser behalten/isolieren, später bounded Grammar |
| globaler Include-/unknown-/inside-production-Fallback | sichere Übergangslösung; darf bis belegter Alternative bestehen bleiben |
| akzeptierte Branches vollständig opaque | keine vollständige Branchunterstützung/AST-Readiness; I4ff liefern echte Rollen |
| Coverage zählt Conditional-Inhalt opaque | korrekt; neue Metriken separat, gepinnten Analyzervergleich nicht umdeuten |
| behauptete Tests 128 Parser/40 Lexer/18 Coverage | historische CE-Update-1-Evidenz, kein 12.3- oder A0-Build |

## Jede vorhandene Unit: Verantwortung, Grenzen, Migration

Präfix bei Produktionsunits jeweils DelphiFormatter.; das Rollen-/APIregister steht nur in 14. „Pflichtchecks“ meint bei Änderung die passenden Testverträge aus 08 plus tatsächlichen Buildnachweis, nicht pauschal alle zukünftigen Tests.

| Unit / Datei | Weiterverantwortung und stabile API | Geplante Erweiterung / heutige Grenze | Pflichtchecks |
|---|---|---|---|
| Core.Spans | TSourceSpan constructor/StartOffset/Length/EndOffset, UTF-16 | Byteoffsets getrennt, kein Rewrite | T-API/T-OWN, Grenz-/Overflowtests |
| Core.Diagnostics | TDiagnostic/TDiagnosticSeverity | neue Codefamilien nur separat, kein zweites DTO | T-API/T-REC |
| Lexer.Tokens | TTokenKind/TDelphiToken/TDelphiLexResult, Count/Get/TokenText | Source/Wertarrays behalten, constructor misuse darf Exception | T-LEX/T-OWN/T-API |
| Lexer.Scanner | statisches Tokenize | belegte einzelne 12.3-Regeln; keine Defines/Includes/Generics | T-LEX/T-PERF/E-LEX |
| Lexer.Keywords | IsReservedWord | contextual spelling nicht global reservieren; 66 bestehende ReservedWords | T-LEX/T-API |
| Syntax.Kinds | append-only TSyntaxKind | main 0–55; #10 ergänzt 56; Rolle vor neuem Kind definieren | T-API/T-ROLES |
| Syntax.Nodes | Element/Node/Token, Kind/Span/ChildCount/GetChild, OriginalIndex/Missing | generic immutable Nodes, keine Parentpointer/Childowner | T-LOSS/T-OWN/T-ROLES |
| Syntax.Tree | Source/Root/Serialize/Diagnostics und Arena | Tree-owned Fakttabelle additiv bei Bedarf, kein Source-Rewrite | T-LOSS/T-OWN/T-API |
| Parser.Reader | signifikanter Reader/Consume, Trivia explizit | API unverändert; bounded Ansicht daneben, kein Fenster-EOF | T-WIN/T-LOSS/T-API |
| Parser.Delphi | Parse/ParseExpression/ParseStatement, vorhandene Grammatik | I1-Indexentkopplung, gezielte Grammatik/Modes; Includes konservativ | T-REC/T-ROLES/T-OWN/T-CORPUS + Featuretest |
| Tests.Lexer.Basics | exakte Token/Spans/Diag/Fuzz | neue Sprachregel unabhängig vom Roundtrip beweisen | T-LEX/T-OWN |
| Tests.Parser.Basics | Shape-/Order-/Span-/Lifetime/Recovery | neue Rollen-/bounded-/Statusfälle, tiefe Queries iterativ | T-LOSS/T-ROLES/T-REC |
| Coverage.Analysis | Source/File-Analyse, DecodeSource, iterative Validierung | Analyse-I/O kein Produkt-IO; heutige Prozentmetrik kein Safetybeweis | T-CORPUS/T-LOSS/T-OWN |
| Coverage.Runner | RunCoverage, Manifest-/lokale Auswahl | Analyseconsole kein FormatterCLI, CLI-Scope unverändert | T-CORPUS, vorhandene Consolechecks |
| Coverage.Reports | JSON/CSV/Markdown/gewichtete Aggregate | neue Metrik nur separat versioniert | T-CORPUS, Schema-/Partitionschecks |
| Tests.Coverage | 17 main-Tests, #10 ein zusätzlicher | isolierte Arbeitsverzeichnisse; generierte Reports nicht als Input überschreiben | T-CORPUS, vorhandene Assertions |
| Fixtures.Minimal | kleiner gültiger Lexerbaselineinput | unverändert, keine Produktfunktion | T-LEX/T-LOSS |
| Fixtures.LexicalCorpus | compilierbare Lexikfälle | neue 12.3-Proben separat/dokumentiert | T-LEX/E-COMP |
| Fixtures.DeclarationCorpus | Routine-/Deklarationspositive inkl. Ressource | keine Syntaxkorrektur still beim Parsen | T-GRAMMAR/T-ROLES/E-COMP |
| Fixtures.PostfixCorpus | gültige Designator-/Postfixkombinationen | komplexe Typen noch opaque | T-GRAMMAR/T-ROLES/E-COMP |
| Fixtures.ClassRecordCorpus | gültige Aggregat-/Memberformen | kein vollständiger Typegrammarbeweis | T-GRAMMAR/T-ROLES/E-COMP |
| Fixtures.PropertyCorpus | gewöhnliche Property-/Specifierformen | class/generic/komplexe Formen teilweise opaque | T-GRAMMAR/T-ROLES/E-COMP |
| Fixtures.ControlFlowCorpus | gültige Loop/Case/Try/Elsepositive | with/inline-for nur opaque Recovery | T-GRAMMAR/T-REC/E-COMP |
| Fixtures.DirectiveCorpus (nur #10) | compilierbare enge Pilotfälle | nicht im gepinnten M2.7-Manifest, keine allgemeinen Branchrollen | T-DIR/T-ROLES/E-COMP |

Dateinamen/Ordner unter src und tests sind unverändert. Die drei Test-DPRs sind Console-Runs; Coverage.dpr ist Analyzer; Lexer.dproj das RTL-Lexerpackage. Group/DPR/DPROJ bei neuen Units nur um benötigte Referenzen erweitern, keine VCL/FMX. Existierende Skripte Fetch/Test/Validate/Compare behalten ihre Analyseverantwortung. Corpusmanifest, Sourcehashes/Archives/Encodingpolicy bleiben unverändert.

Formatter-, Config-, produktive IO- und CLIunits existieren noch nicht; keine Bestandsklassen in diese Rollen umdeuten. Syntax.Query/Directives/Parser.TokenWindow werden erst im jeweils beauftragten Schritt angelegt.

## Evidenzgrenzen

Historische main-Suites: 40 Lexer/120 Parser/17 Coverage; #10: 40/128/18. Die vorherige Reviewaufgabe führte vorhandene hashgeprüfte #10-EXEs erneut aus und bestätigte Corpus 3,827748 % structured/130 complete-fallbacks bei 154/160 extern dekodierten Dateien. Ein frischer CLI-Build scheiterte trotz Exit 0 an CE-Beschränkung. In A0 werden diese Programme **nicht erneut ausgeführt** und keine 12.3-/Oracleergebnisse behauptet.

ARCHITEKTUR_REVIEW.md/review-evidence sind historisch unverändert und bleiben von aktuellen normativen Verträgen getrennt. Details dort sind keine alternative Baselineentscheidung.
