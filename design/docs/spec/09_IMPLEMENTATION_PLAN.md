# 09 – Kleine Implementierungs-PRs

**Nur Planung, keine Implementierungsfreigabe.** A0 endet mit Dokumentations-PR. IDs/Tests sind in [01](01_PRODUCT_REQUIREMENTS.md)/[08](08_TESTS.md) definiert; Verknüpfung in [15](15_TRACEABILITY.md). Baselinevorschrift [12](12_CURRENT_CODE_AUDIT.md) gilt für jeden PR.

## Gemeinsame PR-Abnahme

Jeder PR nennt Base/Head/aktive Requirement-/Feature-IDs, genaue Compiler-/Artefaktevidenz, neue positive/negative Methoden, Token-/Rollen-/Ownershipnachweise und tatsächliche Grenzen. Tests gelten nach Scope: Dokumentation T-DOC/T-BASE; keine fiktiven Build-/Oracle-/Corpusläufe. Parseränderungen zusätzlich T-LOSS/T-OWN/T-REC/T-CORPUS und passende Featurefixtures; Lexer bleibt regressionsgeprüft. Timinggleichheit ist kein Gate.

Spalten „API“ bezeichnen nur diese konkrete Erweiterung; alle übrigen bestehenden APIs bleiben. „Gate“ ergänzt jeweils die verbindlichen Tests. Ein Schritt darf bei fehlender Referenzevidenz als experimentell dokumentiert, aber nicht als erfüllte Capability ausgeliefert werden.

| PR-ID | Voraussetzungen | Betroffene Dateien/Units | API / funktionaler Umfang | Verbindliche Tests / Gate | Nichtziele |
|---|---|---|---|---|---|
| A0 | Review R-01–R-14 | design/*, neue zentrale Verträge/Traceability/ADRs | Dokumente direkt konsolidieren, keine Runtime-APIänderung | T-DOC/T-BASE; nur Dokumentationsdiff | Code, Corpus, #10-Merge |
| I1 | A0 angenommen; #10 ausdrücklich akzeptiert und in gewählter main-Basis vorhanden | Syntax.Directives neu, Parser.Delphi, Tests + DPR/DPROJ | bestehende Klassifikation/Paarung herauslösen; TDirectiveClass über kompatiblen Alias erhalten; Pilotproof bleibt Parserpolitik | T-DIR/T-API plus Basistests; identische Kinds/Tree-Shapes/Diagnostics/Corpuspartition | neue Grammar, Branchkinds, Fallbacklockerung |
| I2 | A0; für Integration I1 | Parser.TokenWindow neu, Reader unverändert, fokussierte Tests | WindowRead/Endstatus nach 14; globale Indizes, begrenzter zentraler Consume | T-WIN/T-OWN/T-API; kein Token außerhalb, kein Extra-EOF | neue Branchgrammar/Readerrewrite |
| I3 | I1/I2 | Syntax.Kinds/Tree/Query, Parser.Delphi, Tests | N-COND/N-FRAG, Bodyintervalle und Issues; noch Bodies geschützt | T-COND/T-DIR/T-WIN/T-LOSS; keine Container-Coverageinflation | neue Branchgrammatik, Includes lokalisieren |
| I4 | I3, E-COMP passend | Parser.Delphi/Query/Tests | ausschließlich unit-interface procedure-Identifier-Semicolon unabhängig bounded parsen | T-CONTEXT/T-ROLES/T-GRAMMAR; beide Branches plus unabhängiger Nachfolger und negative Header | Member-/Statement-/Implementationskontexte |
| L1 | A0, passende E-LEX/E-COMP-Evidenz | Lexer.Scanner/Keywords, Lexer.Tests/Fixtures, docs betroffener Regeln | genau eine belegte Lexikregel; Signaturen/Tokenmodell bleiben | T-LEX/T-LOSS/T-OWN/T-PERF; Compilergegenprobe und Regression | Parser/Config/Rewrites |
| S1 | A0; aktueller strukturierter directive-free Unit-Scope | Core.TextEdits, Formatting.Options/Engine/Safety/Edits nach Bedarf, Formatting.Tests | S0 Assignmentslots + kanonisches FormatResult; keine zusätzliche Layoutinfrastrukturpflicht | T-SLOT/T-S0/T-VERIFY/T-IDEM/T-OWN; exakte Edits + refused-Fälle | Config/IO/Partial/Indent/Case/Direktiven |
| O1 | A0, lokale echte Zielartefakte | tests/FormatterOracle Manifest/Anleitung, keine proprietäre EXE einchecken | Zielversion/Profil-/EXEhash, Exportdeltas und bekannte Lücken | E-CONFIG/E-COMP; echte Inputnachweise, unverified bei fehlendem 12.3 | Configreader/Regeln |
| O2 | O1 | scripts/RunFormatterOracle.ps1, eigene Testkopien/Manifeste | kontrollierter EXEaufruf mit einer Optionsvariation | T-ORACLE/E-ORACLE, Wiederholung/Input-/Outputhash/Exit | ProduktCLI, fremde Sourcewrites |
| C1 | O1, E-XML/E-CONFIG | Config.Native/Schema, Config.Tests | 14-Importresultat, Rohinventur/Recognition/Relevance, sichere Byte-API | T-CONFIG/T-RELEVANCE/T-OWN; echte Profile/foreign XML/unknown/duplicate | Formatterwirkung/Defaults raten |
| C2 | S1/O2/C1, passende E-TABS/E-CONFIG | Config.Effective/Schema, Formatting.Options, Tests | eine native Assignmentoption end-to-end mit Capability/Provenance | T-EFFECTIVE/T-ORACLE/T-S0; strict/lenient/neutral/invalid getrennt | alle Profile vollständig unterstützen |
| G1 | A0/E-GENERICS Typreferenzfälle | Parser.TypeReference innerhalb Parser.Delphi, Kinds/Query/Tests | N-TREF mit nested TypeArguments nur eindeutige Typkontexte | T-GRAMMAR/T-ROLES; LF-07 plus Vergleichsregressionen | Generic-Decl/Expressioncalls, Lexerretokenisierung |
| G2 | G1 | Parser/Kinds/Query/Tests | N-GPARAM deklarative Namen ohne Constraints | LF-08/T-GRAMMAR, genaue Separator-/Name-Rollen | Constraints/Genericmethods |
| G3 | G2/E-GENERICS Constraints | Parser/Query/Tests | eine definierte Constraintfamilie je PR | LF-09/T-GRAMMAR; Compilernegative + Recovery | Typauflösung/weitere Familien |
| G4 | G2/G3 je benötigter Constraint | Parser/Kinds/Query/Tests | generische Routinedeklaration/-Implementation N-ROUTINE | LF-10/T-GRAMMAR; Header/Body/returntype | Expression-Callheuristik |
| G5 | G1/G4/E-GENERICS Calls | Parser.Primary/postfix, Query/Tests | Genericcalls im freigegebenen Kontext, Ambiguität geschützt | LF-11/T-GRAMMAR; relationalen < > unverändert | Symbolauflösung, globale Lexerentscheidung |
| R1 | A0/I2 für bekannte Fenster | Parser.Fassade, Kinds/Query/Tests | ParseSource/pmFragment, unknown standardmäßig protected | T-FRAGMENT/T-API/T-LOSS; LF-06 | .inc automatisch lesen/formatieren |
| R2 | A0 | Parser.Delphi/Kinds/Query/Fixtures | Programroot N-DROOT | LF-25/T-GRAMMAR, EOF/trailing source | Library/Package im selben PR |
| R3 | R2, Exportrollenprobe | Parser/Kinds/Query/Fixtures | Libraryroot plus Exports | LF-26/T-GRAMMAR | ProduktDLL/IO |
| R4 | A0, Packagecompilerprobe | Parser/Kinds/Query/Fixtures | Packageroot, requires/contains | LF-27/T-GRAMMAR, in-String/Items | Compiler-/Buildsystememulation |
| D1 | I4, entsprechende Membergrammatik | Parser/Syntax.Directives/Query/Tests | Branches in einer Memberlistenform | T-CONTEXT/T-COND/LF-04; Visibilityjoin | Statements/IncludeResolver |
| D2 | I4, entsprechende Statementgrammatik | Parser/Query/Tests | geschlossene Statementlistenbranches, explizites Separator/Else-Modell | T-CONTEXT/T-REC/LF-04 | gesplittete Expressions/typeref |
| D3 | I4 + passende Grammar, E-DIR | Parser/Query/Tests | genau eine geteilte Produktionsrolle mit gemeinsamem Präfix/Suffix | T-COND/T-CONTEXT/T-ROLES, kein Doppeltoken | generelle Variantenexploration |
| F1 | S1/C2, betroffene vollständige Rollen | Formatting.Rules/Layout/Tests | genau eine Indent-/Spacing-Regelfamilie; eigene Optionsdomäne | T-VERIFY/T-IDEM/T-ORACLE/E-TABS | vollständiges Layout/Partial |
| F2 | F1, E-LAYOUT/E-BYTES | Formatting.Layout/Rules/Tests | eine Zeilenumbruchfamilie mit eigener Preserve-/Explicit-EOLpolicy | T-VERIFY/T-IDEM/T-ORACLE; Einfüge-/Kommentar-/EOLfälle | stiller EOLwechsel, Alignment |
| F3 | F2/E-LAYOUT | Formatting.Layout/Rules/Tests | eine homogene Alignmentfamilie | T-ORACLE/T-IDEM, Margin-/Tabsinteraktionen | globales Alignment über Barrieren |
| F4 | S1 + spezieller Vertrag/ADR, E-CASE/E-CONDITIONAL je Umfang | Formatting.Rules/Safety/Verification, 14 gezielt migrieren | genau eine bisher gesperrte Token-/Direktiven-/Case-Regelklasse | T-VERIFY/T-ORACLE, neue spezifische Äquivalenzbelege | S0 still erweitern/Identifierauflösung |
| F5 | S1/I4, bestätigte lokale Nichtabhängigkeit und eigener Scope | Formatting.Safety/Verification/Engine, Tests | explizite sichere Teilformatierung; genau ein Owner-/Kontexttyp je PR | T-VERIFY/T-SLOT/T-IDEM/T-INCLUDE; jede Teilmenge vollständig validiert, gemeldete Skipgründe, Fehler weiterhin global refused | Includeeffekte erraten, beliebige Edit-Subset-Suchschleife |
| IO1 | A0/E-BYTES | IO.TextFiles/Core DTOs bei Bedarf, IO.Tests | Byte-Snapshot/BOM/Codec/Hash, keine Writer | T-IO, Mehrdeutigkeit/verlustbehaftete Codecs | SourceSnapshot-Core-Rewrite |
| CLI1 | S1/IO1, C2 nur falls native Config beansprucht | Cli.dpr, CLI.Tests | check/default/diff, 0/1/2-Codes | T-CLI/T-IO; keine Writeröffnung | Write, IDE, breite Pfadsuche |
| IO2 | CLI1/E-WRITE | IO.Writer/TextFiles, CLI explizites write, Tests | concurrent-source-check, Encode/AtomicReplace/Metadatapolicy | T-WRITE/T-CLI; locked/changed/replace failure | ungeprüfte Links/Metadatagarantien |
| REL | nur tatsächlich freigegebene Steps | Feature-/Optionsmatrix, Releasebericht | konkrete 12.3-/Target-/Profil-Capabilities dokumentieren | E-COMP Debug/Release, Scope-Suites/Oracle/Corpus, 0 bekannte Safetyverletzungen | generelles 100%-Claim ohne Scope |

## Einzelne weitere Grammatik-PRs: K-Featurefamilien

Für jede LF-Zeile aus 10 mit K-LF-xx wird **pro genannter Syntaxform ein eigener PR** instanziiert, z. B. K-LF-16-pointer zuerst, class-of später. Vollständiger Vertrag je Instanz:

- Voraussetzung: A0; passende E-COMP-Positiv-/Negativfixture; erforderliche Type-/Expressionrollen aus vorherigen kleinen PRs; Body/Generic-/Branchvoraussetzungen nur falls verwendet.
- Dateien: ausschließlich betroffene Parser.Delphi-Produktionen, additiv Syntax.Kinds/Query-Rollen und Parser.Tests/Fixtures/DPR/DPROJ; keine pauschale Modulzerlegung. Lexer nur bei separat belegter Lexikregel.
- API: append-only Kind für die bereits in 04 benannte Rolle, lesbare Rollenquery, kein Wechsel bestehender Parse-/Arena-/Tokenverträge.
- Funktion: genau der eigene Positivfall aus der LF-Zeile strukturiert; alle anderen Varianten behalten bisherigen konservativen Schutz.
- Tests: eigener Positiv-/Recovery-/Ambiguitätsfall der LF-Zeile, T-GRAMMAR/T-LOSS/T-ROLES/T-REC/T-OWN/T-CORPUS; E-COMP-Nachweis und Formatter-Safetygrenze dokumentieren.
- Gate: konkrete korrekte Hierarchie und erhaltene Nachfolger/Token, unveränderte Basistests; Corpusverbesserung **oder belegte funktionale Notwendigkeit**, kein erfundener Prozentzwang.
- Nichtziele: übrige Formen der Familie, semantische Prüfung, Formatterregel, Resolver/AST/Compiler.

Erste deklarative kleine Option nach G-/I-Basis ist K-LF-12-resourcestring; sie darf früh unabhängig von vollständigen Generics freigegeben werden. Kein „C2 komplette Generics“ oder „D komplette Config“ als Megapatch.

## Unabhängige Stränge und Stop

S1 benötigt I3/I4/G1 **nicht**. O1/O2 benötigt S1/G1 **nicht**. IO1 benötigt vollständige Grammar **nicht**. L1 bearbeitet nur belegte Lexikgrenzen. I1 ist der erste empfohlene Code-PR nach ausdrücklicher #10-Disposition; wenn #10 abgelehnt wird, ist dessen I1-Voraussetzung unerfüllt und ein neu geschnittener, separat autorisierter Ersatz nötig.

Nach A0 weder I1 noch S1 starten. PR erstellen, nicht mergen, danach stoppen.
