# 15 – Requirement-to-Test-to-PR-Traceability

Einzige Requirementdefinitionen in [01](01_PRODUCT_REQUIREMENTS.md), Testdefinitionen in [08](08_TESTS.md), Schritte in [09](09_IMPLEMENTATION_PLAN.md), Experimente in [11](11_OPEN_QUESTIONS.md). Diese Tabelle beschreibt Sollnachweise, keine ausgeführten Tests. Alle 49 A0-Anforderungen haben mindestens einen Test und einen Schritt. K-LF-xx steht für die einzeln instanziierte Featurefamilie aus 09/10; nicht für einen Megapatch.

| Requirement | Verbindliche Testverträge | Implementierungsschritte | Detail / empirische Grenze |
|---|---|---|---|
| LEX-01 | T-LEX, T-LOSS | L1 | 03/14 |
| LEX-02 | T-LEX, T-GRAMMAR | L1 | 03; E-LEX |
| LEX-03 | T-LEX, T-PERF | L1 | 03 |
| LEX-04 | T-LEX, T-GRAMMAR | L1, REL | E-LEX/E-COMP |
| CST-01 | T-LOSS, T-OWN | I1, I3, G1 | 04/14 |
| CST-02 | T-ROLES, T-GRAMMAR, T-CORPUS | I4, G1, K-LF-12 | 04/10 |
| CST-03 | T-REC, T-COND, T-FRAGMENT | I3, R1 | 04/14 |
| CST-04 | T-LOSS, T-INCLUDE, T-FRAGMENT | I3, R1 | 02/05 |
| CST-05 | T-REC, T-CONTEXT, T-PERF | I4, D2 | 04/05 |
| CST-06 | T-API, T-OWN | I1, I3 | 12/14 |
| CST-07 | T-COND, T-LOSS | I3, D3 | 04 |
| CST-08 | T-WIN, T-OWN | I2 | 14 |
| CST-09 | T-ROLES, T-GRAMMAR | G1, G4, I4 | 04/10 |
| CST-10 | T-FRAGMENT, T-API, T-GRAMMAR | R1, R2, R3, R4 | 04/14 |
| DIR-01 | T-COND, T-DIR | I1, I3 | 04/05 |
| DIR-02 | T-INCLUDE, T-CONTEXT | I3, D3 | 05; E-INCLUDE |
| DIR-03 | T-CONTEXT, T-WIN | I4, D1, D2, D3 | 05 |
| DIR-04 | T-CONTEXT, T-INCLUDE, T-S0 | I4, D1, S1 | 05/06 |
| DIR-05 | T-DIR, T-LEX | I3, L1 | 03/05 |
| DIR-06 | T-DIR, T-PERF | I1, I3 | E-DIR |
| FMT-01 | T-S0, T-API | S1 | 02/06/14 |
| FMT-02 | T-SLOT, T-S0 | S1 | 06/14 |
| FMT-03 | T-S0, T-VERIFY | S1 | 06 |
| FMT-04 | T-IDEM, T-ORACLE | S1, F1 | 06 |
| FMT-05 | T-SLOT, T-VERIFY | S1 | 06/14 |
| FMT-06 | T-VERIFY, T-ROLES | S1 | 06/14 |
| FMT-07 | T-S0, T-EFFECTIVE, T-VERIFY | S1, C2, F5 | 06/14 |
| FMT-08 | T-S0, T-IDEM, T-IO | S1, IO1, F2 | 06; E-BYTES |
| FMT-09 | T-S0, T-ORACLE | S1, F1, F2, F3 | 06/07 |
| FMT-10 | T-RELEVANCE, T-EFFECTIVE, T-ORACLE | C2, F4 | 07; E-CONDITIONAL/E-CASE |
| CFG-01 | T-CONFIG, T-OWN | O1, C1 | 07; E-CONFIG/E-XML |
| CFG-02 | T-RELEVANCE, T-EFFECTIVE | C1, C2 | 07 |
| CFG-03 | T-EFFECTIVE, T-ORACLE | C2, F1 | 07; E-TABS |
| CFG-04 | T-CONFIG, T-EFFECTIVE | O1, C1, C2 | 07; E-CONFIG |
| CFG-05 | T-RELEVANCE, T-EFFECTIVE | C2 | 07 |
| CFG-06 | T-CONFIG, T-EFFECTIVE | C1, C2 | 07 |
| CFG-07 | T-ORACLE | O2, C2, REL | 11 |
| IO-01 | T-IO | IO1 | E-BYTES |
| IO-02 | T-CLI | CLI1 | 06 |
| IO-03 | T-WRITE, T-VERIFY | IO2 | E-WRITE |
| IO-04 | T-IO, T-WRITE | IO1, IO2 | E-BYTES/E-WRITE |
| API-01 | T-DOC, T-API | A0, S1, C1 | 14 |
| API-02 | T-OWN, T-API | I1, I2, S1, C1 | 14 |
| API-03 | T-API, T-DOC | A0, I1, S1, C1 | 02 |
| QA-01 | T-LOSS, T-ROLES, T-REC, T-OWN | I3, G1, REL | 08 |
| QA-02 | T-DOC, T-BASE | A0, REL | 08/12 |
| QA-03 | T-CORPUS | I1, I3, REL | 08/12 |
| QA-04 | T-DOC, T-GRAMMAR, T-ORACLE | A0, REL | 08/10/11 |
| BASE-01 | T-BASE | A0, I1 | 12 |

## Feature-Traceability

Jede LF-Zeile in 10 nennt Zielrollen N-*, eigenen Positiv-/Recoveryfall, E-COMP/E-GENERICS oder andere passende Evidenz und konkreten Schritt. T-GRAMMAR/T-ROLES/T-REC/T-LOSS/T-OWN werden pro LF-/Syntaxform mit benannten Testmethoden/Fixtures instanziiert. Asm bleibt bewusst opaque Operandensyntax; „nicht AST-ready“ bleibt sichtbar. Die Requirements CST-02/CST-05/CST-09/LEX-04/QA-04 gelten für jede dieser Instanzen.

## Reviewbefunde: Entscheidungen und betroffene Kapitel

| Befund | A0-Entscheidung | Direkt korrigierte Dokumente | Requirement-/Testbezug |
|---|---|---|---|
| R-01 | whole-file-/EOF-Schutz für Includeeffekte zulässig; vorläufiger Suffix nicht editierbar | 01/04/05/09/11/12/13, ADR-001 | DIR-02/DIR-04; T-INCLUDE/E-INCLUDE |
| R-02 | finite Kontextregistrierung, exact-consumption und Join aller Alternativen | 04/05/14/09, ADR-001 | DIR-03/CST-08; T-CONTEXT/T-WIN |
| R-03 | physischer Baum, einmalige gemeinsame Tokens, klare Marker-/Bodyownership | 04/14/13, ADR-001 | CST-01/CST-07; T-COND/T-LOSS |
| R-04 | Issues als Menge, Fragment nicht Gültigkeitsbeweis; mehrdeutige Recovery schützen | 01/04/05/14, ADR-001 | CST-03/CST-05; T-REC |
| R-05 | tokengebundene Slots, geschlossene Grenzen und eindeutige Offsetkonflikte | 06/14/13, ADR-002 | FMT-02/FMT-05; T-SLOT |
| R-06 | exakte LexicalSignature, Rollenfingerprint, gemappte Anker/Diagnostics; kein Semantikclaim | 06/08/14, ADR-002 | FMT-06/QA-01; T-VERIFY |
| R-07 | relative Anker statt absoluter Offsets; S0 sperrt native Directive-/Comment-/Casewirkung | 06/07/14/11, ADR-002/003 | FMT-03/FMT-10; T-S0/T-ORACLE |
| R-08 | native Tabs/Indent sind native Herkunft; Overrides nur ausdrücklich belegt | 02/07/14/11, ADR-003 | CFG-03/CFG-04; T-EFFECTIVE/E-TABS |
| R-09 | Recognition/Relevance/Capabilities getrennt; Lenient heilt invalid nicht | 07/14/11/13, ADR-003 | CFG-02/CFG-05/CFG-06; T-RELEVANCE |
| R-10 | Codepageprovenance statt vermeintlicher Detektion; IO und concurrent Write getrennt | 01/06/11/13/14, ADR-002 | IO-01/IO-03/IO-04; T-IO/T-WRITE |
| R-11 | kanonische Rollenqueries mit featureweiser AST-Readiness, keine ASTklassen | 04/10/12/14, ADR-001/004 | CST-09; T-ROLES |
| R-12 | Typreferenz → Parameter → Constraints → Methoden → Calls als eigene PRs | 09/10/11, ADR-004 | CST-02/CST-06; T-GRAMMAR/E-GENERICS |
| R-13 | Pairing nur echter Lexertokens; Compilerkonformität separat | 03/04/05/11, ADR-001 | DIR-05/DIR-06; T-DIR/E-DIR |
| R-14 | ein API-/Ownerregister, vollständige Feature-/Testmatrix, konkrete Baseline und kleine PRs | README/01/02/08/09/10/12/14/15/16, ADR-004 | API-01/API-03/BASE-01/QA-04; T-DOC/T-BASE |

## Nachweiszustände

A0 liefert konsolidierte Dokumente und dokumentiert Selbstchecks, keine Runtimecapability. Vorherige Review-/CE-Logs sind historische Evidenz. Implementierungs-PRs ergänzen je zugeordneter Testinstanz exakten Testnamen, Quelle, Toolchain, Datum/Hash/Ergebnis oder ausdrücklich blocked/not-run. Ein geplanter Testvertrag darf niemals als passed interpretiert werden.

Kein Gate verlangt vor S1 vollständige Grammatik oder vor internen Optionen native Defaultkenntnis. Fehlende Oracleevidenz verhindert nur den nativen Claim; ungeprüfte Compiler-/Includeeffekte erlauben keine Lockerung der Schutzregeln.
