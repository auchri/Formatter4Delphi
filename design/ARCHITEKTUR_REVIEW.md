# Architekturreview Formatter4Delphi

**Datum:** 31.10.2026. **Ergebnis:** Grundrichtung geeignet, Spezifikation noch nicht unverändert zur Implementierung freigeben. Die unten genannten Sicherheits- und Schnittstellenentscheidungen müssen zuerst präzisiert werden. Kein AST, Compiler oder neues Produktfeature wurde implementiert.

## 1. Auftrag, Quellen und Verlässlichkeit

Alle 19 Dateien aus `Formatter4Delphi_Architektur_und_Anforderungen.zip` wurden unter `design/` abgelegt. Der gemeinsame ZIP-Wurzelordner wurde entfernt; die innere Verzeichnisstruktur und sämtliche Dateiinhalte blieben erhalten. `review-evidence/import-manifest.json` enthält den Archivhash, die Dateihashes und den bytegenauen Abgleich jedes Eintrags. Die importierten Dokumente sind Vorschläge; dieser Bericht ändert ihren Status nicht in „freigegeben“.

Gelesen wurden README, Implementierungsregeln, alle drei ADRs, sämtliche Spezifikationen 01–13 und die Fixture-Verträge. Geprüft wurden außerdem die vorhandenen Architektur-, CST-, Lexer-, Test-, Roadmap-, Entscheidungs- und Statusdokumente, die Core-/Lexer-/Syntax-/Parser-Implementierungen, die DUnitX-Suites und kompilierten Fixtures, die Coverage-Implementierung samt Manifest, Projektdateien und wesentliche Corpusberichte/Skripte. Die externen Upstream-Projekte wurden nicht vollständig auf Sprachkorrektheit oder Kompilierbarkeit untersucht.

Kennzeichnung im Bericht:

- **Befund:** direkt aus lokalem Code, eingelesenen Dateien, ausgeführten Programmen oder aktueller GitHub-Abfrage belegt.
- **Folgerung/Empfehlung:** technische Bewertung dieser Befunde, kein bereits implementiertes Verhalten.
- **Offen:** benötigt Entscheidung, Compilerprobe oder echte Referenzformatierung. Codebeispiele zu Risiken sind Entwurfs-/Negativtests und kein behaupteter Delphi-12.3-Compilerbeleg.

### Tatsächliche Repository-Basis

| Gegenstand | Verifizierter Stand |
|---|---|
| Remote | `https://github.com/auchri/Formatter4Delphi.git` |
| GitHub `main` | `98fdb7e6ec8f590f0239348463cb1bda4dcd23f7`, Merge von PR #9 / M2.7 |
| Aktueller Checkout | Branch `codex/m2.8-directive-aware`, HEAD `65000fca7ce3890541aa1f691a17666ef47cfb92` |
| Differenz zu Remote-main | ein Commit voraus; 27 Dateien, 3.298 Einfügungen, 49 Löschungen |
| Offene PRs | Abfrage ergab ausschließlich [PR #10](https://github.com/auchri/Formatter4Delphi/pull/10), offen, nicht Draft, nicht gemergt |
| PR-Head | identisch zum lokalen HEAD; Base identisch zum oben genannten Remote-main |
| Inline-Review-Threads #10 | GitHub meldete keine Threads; das ist keine fachliche Freigabe |
| Lokaler Branch `main` | veraltet (`b9f5b95`); nicht als aktuelle Architektur-Baseline verwenden |

Die Unterscheidung im ZIP zwischen main/M2.7 und PR #10/M2.8 ist weiterhin richtig. In diesem Bericht beziehen sich Codebefunde auf den lokalen M2.8-Head, soweit nicht anders angegeben. Es wurde weder gefetcht, gemergt, umgeschaltet noch ein PR erstellt oder kommentiert.

## 2. Gesamtbewertung

**Der primäre verlustfreie Source-CST ist die richtige Grundlage für einen echten Delphi-Formatter.** Ein unveränderlicher Baum mit expliziten Trivia-Blättern, stabilen Originaltoken-Indizes und eigener Source-Referenz ermöglicht lokale Layoutentscheidungen, nachvollziehbare Text-Edits und Fehlerdarstellung ohne Projektdatei. Ein AST würde Kommentare, Direktiven und konkrete Schreibweisen nicht hinreichend ersetzen. Die optionale Compilation-Sicht darf daher außerhalb des Formatter-Pfads bleiben.

Das vorhandene Speichermodell ist dafür brauchbar. `TSyntaxNode` kopiert seine Kinderliste; `TSyntaxTree` besitzt das flache Elementarena und den Source-String. Serialisierung und Destruktion sind iterativ. Die Parser-Suite prüft nach Freigabe des Lexer-Ergebnisses Originalindizes, Tokenarten, Spans, eindeutige Erreichbarkeit und Rekonstruktion. Ein Rewrite dieser Basis ist technisch nicht begründet.

**Die zentrale Einschränkung:** Ein Source-CST für alle bedingten Quellen ist kein einziger gewöhnlicher Delphi-Grammatikbaum für alle möglichen Compilerkonfigurationen. Direktiven können eine Produktion unterbrechen; gemeinsame Tokens außerhalb eines Branches dürfen nicht für jede mögliche Variante dupliziert werden. Die zusätzliche Ebene aus Conditional-Regionen, Branches und unaufgelösten Fragmenten ist deshalb erforderlich. Ihre formalen Grenzen sind im Entwurf noch nicht ausreichend definiert.

Für eine spätere AST-Ableitung reicht die Architektur **grundsätzlich**, sofern Knotenrollen und Vollständigkeit verbindlich werden. Ein vollständiger aktiver Programm-AST kann bei Includes und bedingter Grammatik zusätzliche Compilation-Kontexte benötigen. Diese spätere Sicht darf Originaltoken-Ursprünge referenzieren, aber den Originalbaum nicht ersetzen. AST-Readiness sollte durch CST-Queries nachgewiesen werden; es braucht dafür jetzt keine AST-Klassen und keine Symboltabellen.

Positiv sind insbesondere die getrennten Lossless-/Formatting-Invarianten, konservative Schutzbereiche, explizite Config-Kompatibilitätsstände und der frühe kleine Formatterversuch. Problematisch sind unbewiesene Include-Resynchronisierung, unpräzise Safety-Verträge, widersprüchliche Config-/Direktivenregeln und zu große vermeintliche Einzel-PRs.

## 3. Kritische Probleme und konkrete Korrekturen

### R-01 — Includes erlauben keine pauschale lokale Wiederaufnahme (blockiert Safety-Freigabe)

**Befund:** `04_SOURCE_CST`, §6 verlangt „Nie die gesamte Datei allein deshalb opaque machen“, während `05_DIRECTIVES` und ADR-001 zugleich beliebige syntaktische Include-Effekte anerkennen. Der bestehende `Execute`-Prepass schützt bei Includes vollständig (`Parser.Delphi.pas:2225`); das ist unter der bisherigen Informationslage konservativ und nicht einfach ein Parserfehler.

**Auswirkung:** Ein Include kann Deklarations- und Direktivenzustände verändern. Ein danach sichtbar vollständiges `procedure P;` beweist noch keinen unabhängigen Kontext: Ein unbekanntes Include könnte etwa eine bedingte Region öffnen, deren Auswertung nachfolgenden Text beeinflusst. Aus `;`, `end` oder einem Routinekeyword allein folgt keine universell sichere Grenze. Die offizielle Include-Dokumentation enthält zusätzlich Einschränkungen bei Statement-Parts; welche davon der Zielcompiler tatsächlich erzwingt, ist separat zu prüfen. Beliebige hypothetische Include-Fragmente dürfen deshalb auch nicht als compiler-validierte positive Fixtures gelten.

**Empfehlung:** Strukturgewinn und Editierbarkeit trennen. Include als Blatt/Knoten erhalten; eine nachfolgende Quellinsel gegebenenfalls als **vorläufige Struktur mit unbekanntem Eintrittszustand** anzeigen. Safety bleibt bis zu einer bewiesenen Grenze oder bis Dateiende gesperrt. Whole-file- beziehungsweise Suffix-Schutz muss als legitimes Ergebnis zugelassen bleiben. Bereits davor nachweisbar unabhängige Bereiche können erhalten bleiben, benötigen aber ebenfalls einen Kontextbeleg.

Eine optionale spätere Include-Zusammenfassung könnte nach expliziter Resolverfreigabe Zustandswirkungen nachweisen; sie ist kein aktuelles Pflichtfeature. Ohne Resolver und ohne verlässlichen Zustandsvertrag kann man keinen universellen kleinen Schutzradius versprechen. Negative Tests müssen Includes mit Grammatik- und Direktivenzustandsänderung abdecken. [Include-Dokumentation](https://docwiki.embarcadero.com/RADStudio/Sydney/en/Include_file_%28Delphi%29) ist hier ein Recherchehinweis aus einer älteren Dokumentationsversion, kein 12.3-Compilerbeleg.

### R-02 — Branch-Vollständigkeit braucht einen wirklichen Kontextvertrag (blockiert Branch-Formatter)

**Befund:** `04_SOURCE_CST`, §5 und `05_DIRECTIVES`, §4 nennen Entry-/ExitState, legen deren Inhalt und Gleichheit aber nicht fest. „Exakt alle Tokens konsumiert“ genügt nicht. Sichtbarkeit, Deklarationssektion, erwartete Separatoren, offenes `if`, Listenfortsetzung und Modifikatoren können trotz identischer Delimiterbalance unterschiedlich sein.

**Empfehlung:** Je freigegebenem Kontext einen kleinen endlichen Vertrag spezifizieren: erwartete Produktion/Liste, Separatorbesitz, offene grammatische Besitzer, maximal zulässiger Tokenbereich, Abbruchgründe und beobachtete Direktivenwirkungen. Zunächst nur Unit-Deklarationslisten; Member- und Statementlisten erhalten getrennte spätere Gates. Bei unbekanntem Eintrittszustand kein `complete` und keine Formatfreigabe. Ein fehlender ELSE ist eine mögliche leere Alternative und muss bei der Zustandszusammenführung mitbetrachtet werden.

Keine vollständige Variantenexploration oder Generalized-Parser-Infrastruktur einführen. Bei nicht zusammenführbaren Zuständen reicht ein geschütztes Fragment des umgebenden Besitzers. Damit vermeidet man exponentielle Kombinationen verschachtelter Bedingungen.

### R-03 — Einmalige Blattownership kollidiert mit naiver Alternativgrammatik (vor Kind-Erweiterungen entscheiden)

**Befund:** Das Ziel fordert eine strikte Baumstruktur und Originaltokens genau einmal. Bei `type T = {$IFDEF X}Integer{$ELSE}string{$ENDIF};` gehören `T`, `=` und `;` zu beiden gedachten aktiven Typdeklarationen, stehen aber nur einmal in der Datei.

**Empfehlung:** Ein physischer Originalbaum bleibt maßgeblich: `TypeDeclaration` mit gemeinsamer Präfix-/Suffixsyntax und einer bedingten RHS-Gruppe. Jeder Branch besitzt nur sein eigenes zusammenhängendes Originalintervall. Kontext-/Vollständigkeitsdaten liegen in unveränderlichen Metadaten oder einer durch den Tree besessenen Werttabelle. Keine gemeinsamen Kindreferenzen in mehreren Parents, keine duplizierten Originalblätter und keine in den Source-Baum eingefügten Tokens einer gewählten Compileransicht.

Der Grouper speichert zunächst Indizes/Intervalle; nur der zentrale Builder erzeugt Blätter. Opener/ELSEIF/ELSE, Bedingung, Body, Closer und dazwischenliegende Trivia brauchen eindeutige Besitzer. Der erste Branch darf den Opener nicht nochmals besitzen, wenn bereits die Region dessen Blatt besitzt. Das ist im ZIP noch offen.

### R-04 — „Gültiges Fragment“ und „wirklicher Syntaxfehler“ sind zu starke Zusagen

**Befund:** `04_SOURCE_CST` bezeichnet `SyntaxFragment` als gültigen Teil einer Produktion und reserviert `ErrorNode` für tatsächlich falsche Syntax. Gleichzeitig fehlen dem Parser Include-, Define- und teils Grammatikkenntnisse. CST-05 verlangt kategorisch keine fehlerhafte `else`-/`end`-Zuordnung; bei fehlenden Tokens ist die beabsichtigte Zuordnung nicht immer rekonstruierbar. Das erkennt die bestehende CST-Spezifikation bereits ausdrücklich an.

**Empfehlung:** `SyntaxFragment` bedeutet „in diesem Kontext nicht abgeschlossen/nicht entschieden“, nicht bewiesene Gültigkeit. Orthogonale Statuswerte vorsehen: `complete`, `incomplete`, `unsupported`, `context_unknown`, `malformed`. Diagnostics unterscheiden Kontextunsicherheit, Supportlücke, Ressourcenlimit und lokal belegbaren Fehler. Kein Zusatzboolean pro beliebiger Kombination.

Recovery muss deterministisch, verlustfrei und konservativ sein; korrekt gebundene gültige Syntax ist eine Muss-Anforderung. Bei mehrdeutig beschädigter Syntax schützt sie einen größeren Besitzer und dokumentiert die Unsicherheit. „Immer das beabsichtigte end erkennen“ ist kein erfüllbares Gate. Fehlende Tokens bleiben für normale Recovery erlaubt, qualifizieren einen Branch aber nicht als vollständig.

### R-05 — Safety-Intervalle lassen gefährliche Grenzfälle offen (blockiert ersten Formatter)

**Befund:** `06_FORMATTER`/ADR-002 beschreiben halboffene Intervalle und disjunkte Edits. Für Einfügungen `[p,p)` ist jedoch nicht festgelegt, ob eine geschützte Grenze links/rechts eingeschlossen wird. Mehrere Einfügungen am gleichen Offset können formal disjunkt erscheinen und trotzdem konfliktbehaftet sein. Kommentartextschutz schützt nicht automatisch Kommentarbindung.

**Empfehlung:** Formatierbare **Trivia-Slots zwischen konkreten Originaltokens** als Primärvertrag verwenden. Ein Slot trägt linken/rechten Tokenindex, ersetzbaren Bereich, erlaubte Änderungsklasse, Kontext und Ablehnungsgrund. Schutzintervalle bleiben für Darstellung und schnelle Abfragen nützlich. An Barrieren sind Insertions standardmäßig verboten; eine Freigabe muss die Seite explizit nennen. Mehrere Edits je Slot/Offset zuerst zu einer eindeutigen Entscheidung vereinigen oder ablehnen.

Beispiel: `DoA; // Hinweis` darf nicht durch Einfügen einer Zeile vor dem Kommentar anders zugeordnet werden, obwohl Kommentarlexem und Codelexeme gleich bleiben. Das Layout muss Zeilenkommentare, führende Dokumentationskommentare, Leerzeilengruppen und festgehaltene EOL-Slots berücksichtigen. Direktiven und mehrzeilige Literale bleiben im ersten Slice vollständig geschützt.

### R-06 — Re-Lexing/Re-Parsing ist notwendige Kontrolle, kein allgemeiner Semantikbeweis

**Befund:** Die vorgesehenen Token- und Tree-Fingerprints sind noch nicht exakt definiert. Derselbe Parser kann vor und nach einer Änderung denselben Fehler machen. Alle Tests gegen den eigenen Lexer teilen dessen Klassifikationslücken. Eine identische Liste „meaningful tokens“ kann Kommentarbindung oder compilerrelevante Positionseffekte übersehen.

**Empfehlung:** Für den ersten Slice alle Nicht-Whitespace-/Nicht-Newline-Tokenarten samt exaktem Text erhalten, einschließlich Kommentaren, Direktiven und Unknown. Lexikalische Fehler zunächst ganz verweigern. Zusätzlich Originaltoken-Korrespondenz, Kommentar-/Direktivenanker und Schutztexte mittels Edit-Mapping prüfen. Fingerprint versioniert definieren: Kind, Rollen, Operator-/Delimiterlexeme, Fehler-/Missingstatus; keine absoluten Offsets und keine veränderliche Trivia. Neue Diagnostics nach gemapptem Ort/Code vergleichen, nicht bloß die Fehlerzahl.

Für Bedingungen und Includes keine globale Gleichheit aller Compilersemantiken behaupten. Compiler-validierte positive Fixtures und unabhängige Negativfälle ergänzen die Selbstprüfung. Die Laufzeitpipeline braucht einen Lex-/Parse-Verifikationsdurchlauf; Idempotenz lässt sich regulär in Tests prüfen, ohne rekursiv `FormatText` aufzurufen. Ein Verifikationsfehler verwirft im ersten Release die gesamte Editmenge; keine unbeschränkte „entfernen und erneut versuchen“-Schleife.

### R-07 — Direktiven-/Kommentar-Invarianz widerspricht nativen Optionen

**Befund:** `06_FORMATTER` und SAFE-100 verbieten Direktivenverschiebung; gleichzeitig werden native Direktiven-Einrückung, Umgebungsleerzeilen und Capitalization angestrebt. Die lokal gelesenen Profile enthalten tatsächlich `DelphiFormatter.IndentCompilerDirectives`, `NumOfEmptyLinesAroundCompilerDirectives` und `CompilerDirectivesCapitalization`. Auch Kommentarinhaltsoptionen existieren. Ein normaler Edit vor einer Direktive verschiebt bereits deren absoluten UTF-16-Offset.

**Empfehlung:** „Position erhalten“ als Reihenfolge, bedingte Zugehörigkeit und Verankerung an Originaltoken-Nachbarn definieren; absolute Offsets dürfen sich durch frühere Edits ändern. Im Sicherheitsprofil S0 bleiben Direktiventext und ihre angrenzenden Slots unverändert. Spätere Freigaben für Einzug/Case brauchen eigene Policies und Tests. Bis dahin diese nativen Optionen als unsupported beziehungsweise nur bei nachgewiesen neutralem Wert behandeln. Sicherheitsbeschränkung und vollständige Referenzausgabe können nicht gleichzeitig für jeden Profilwert versprochen werden. Nicht nachträglich die Safety-Regel abschwächen, um ein Golden zu treffen.

### R-08 — Editoroptionen sind teilweise bereits Bestandteil nativer Profile

**Befund:** `02_ARCHITECTURE`/`07_RAD_CONFIG` trennen eigene Editor-/I/O-Einstellungen sinnvoll vom Import. Die lokale Datei enthält aber `DelphiFormatter.TabSize=2`, `IndentSize=2`, `UseTabs=False` in `Category=DelphiEditor`. Die Annahme „Tabs kommen ausschließlich aus eigener Editorkonfiguration“ wäre daher falsch. Das ist beobachtete ältere Profilstruktur, noch kein 12.3-Verhaltensnachweis.

**Empfehlung:** Trennung nach **Herkunft und Verantwortung**, nicht pauschal nach dem Wort „Editor“. Alle nativen Schlüssel unverändert inventarisieren, auch native Tab-/Indentwerte. Eigene Overrides sind explizite zusätzliche Eingänge mit Provenance und markiertem Kompatibilitätseinfluss. Vorrang zwischen Profil, IDE-Editorwerten und CLI ist durch Oracle-Tests zu bestimmen. Die reine Engine bekommt ein typisiertes effektives Optionsmodell; sie sollte keinen NativeReader aufrufen und kein Rohprofil benötigen.

### R-09 — Strict Config braucht Relevanz- und Capability-Modell

**Befund:** Alle vier lokalen Profile enthalten 158 aktive Option-Elemente: 84 `DelphiFormatter.*`, 72 `CppFormatter.*`, zwei allgemeine `Formatter.*`. „Jeder unbekannte Schlüssel blockiert“ würde ohne Relevanzklassifikation selbst normale Delphi-Profile wegen C++-/UI-Werten ablehnen. Umgekehrt ist unbekannt nicht automatisch irrelevant. Eine importierbare Option ist auch noch nicht ausführbar.

**Empfehlung:** Zwei Dimensionen trennen: Importstatus (`known`, `unknown`, `invalid`, `ambiguous`) und Verhaltenssupport pro Zielversion/Wert/Syntax (`verified`, `partial`, `unsupported`, `unverified`). Belegt irrelevante C++-/UI-Werte sichtbar inventarisieren, aber Delphi-Formatierung nicht deswegen blockieren. Unbekannte mögliche Delphi-Wirkung blockiert strict. Ungültiges oder strukturell mehrdeutiges Profil wird auch lenient nicht einfach toleriert; lenient darf lediglich ausdrücklich dokumentierte Supportlücken akzeptieren.

Zusätzlich zwischen neutralem Optionswert, tatsächlich verwendeter Regel und fehlender Regel unterscheiden. Sonst verweigert ein erster Formatter mit einer Regel jedes vollständige native Profil. Für frühe Tests sind interne explizite Optionen legitim, aber keine RAD-Kompatibilitätsbehauptung. Ein erfolgreicher Profilimport darf auch bei verweigerter Formatierung vollständig diagnostizierbar sein.

### R-10 — Ein Codepage-Roundtrip beweist keine richtige Decodierung

**Befund:** `06_FORMATTER`, §8 und E2E-07 setzen auf Encode/Decode-Roundtrip. Dieser erkennt Verlust, aber nicht die beabsichtigte Codepage: dieselben Bytes können unter mehreren Codepages exakt zurückcodierbar sein. Der bestehende Analyzer meldet solche Fälle konservativ als `encoding_ambiguous`; er ist kein universeller Encodingdetektor.

**Empfehlung:** BOM, explizite Codepage und dokumentierte UTF-8-Policy mit Provenance verwenden. Ohne Evidenz nicht behaupten, falsch interpretierte ANSI-Bytes immer zu erkennen. Malformed UTF-16 im String bleibt lossless; ungültige Byteeingabe/fehlender Codec darf der IO-Adapter ablehnen. `FormatText` selbst kann keinen Byte-Encodingfehler aus einem bereits gelieferten String diagnostizieren.

Für Write zusätzlich Source-Snapshot/Hash unmittelbar vor Ersetzung prüfen, damit Änderungen nach dem Read nicht überschrieben werden. Atomic Replace, Metadaten/ACL, Symlinks/Hardlinks und Backup-/Fehlerpolicy sind Adapterfragen mit separaten Tests. Byteorigin-Mapping ist erst bei bytebezogenen Edit-APIs nötig; das vollständige Ergebnis erneut mit dem ausgewählten Codec zu encodieren ist zunächst einfacher.

### R-11 — AST-Readiness benötigt Rollenverträge, keine Produktionsklassen

**Befund:** Geordnete Kinder und Tokenlexeme sind eine gute Grundlage. Das Mindestvokabular allein sagt aber nicht, welches Kind in einer Routine den Namen, Resulttyp oder Body liefert. `MethodDeclaration` hält Modifier heute als opaque Tail (`Parser.Delphi.pas:1675`), Typnamen sind nur einfach/qualifiziert (`TypeReference:1146`).

**Empfehlung:** Vor jedem neuen Grammatikfeature eine kleine Shape-Tabelle samt Rollenqueries definieren: obligatorische/optionale Kinder, Listen, Separatorbesitz, Keyword-/Operatorpositionen, Missing-/Opaque-Verhalten. Bestehende Klassen beibehalten; typisierte read-only Queryfunktionen oder ausgelagerte Walker reichen. Keine Parentpointer, Green/Red-Bäume oder stabilen Node-IDs auf Vorrat.

AST-Readiness gilt pro vollständig unterstütztem Konstrukt. Der spätere AST-Verbraucher darf Syntaxrollen über den CST auslesen; er muss nicht rohe Source erneut parsen. Opaque Modifier oder fragmentierte Generics begrenzen ausdrücklich dieses Versprechen. Ein konfigurationsfreier Variationsbaum und ein aktiver AST sind unterschiedliche spätere Verbraucher.

### R-12 — Generics sind richtig verortet, aber der geplante PR ist zu groß

**Befund:** Der Lexer entscheidet `<`/`>` bereits nicht semantisch; `IndexGenericCallOpeners:258` ist nur ein linearer konservativer Ambiguitätsindex. `09_IMPLEMENTATION_PLAN` C2 bündelt Typargumente, Parameter, Constraints, generische Aggregate und Methoden. Das ist kein kleiner unabhängiger PR.

**Empfehlung:** Erst qualifizierte Typnamen mit generischen Argumenten in eindeutigen Typpositionen; dann generische Deklarationsparameter; dann Constraints; dann generische Routinen und zuletzt mehrdeutige Expression-Callsites. Compilerfixtures für `>>`, `>=` an enger Token-Grenze, qualifizierte Namen und Kommentare zwischen Zeichen vorbereiten. Bestehende Originaltokens nicht nachträglich umtokenisieren oder in mehrere Originalblätter aufspalten; wenn der Compiler eine Lexemaufteilung verlangt, braucht dies einen eigenen API-/Lexerentscheid.

Bei echter syntaktischer Mehrdeutigkeit ist localized opaque/ambiguous zulässig. Kein Name-/Typauflöser als versteckte Formattervoraussetzung. Zuerst auf Typpositionen beschränken statt globale Heuristiken zu vergrößern.

### R-13 — Quellen lexikalisch beschädigter Branches begrenzen Direktivenpaarung

**Befund:** Ein ungeschlossener Blockkommentar oder Multiline-String kann nachfolgendes `{$ENDIF}` im eigenen Token absorbieren. Der Grouper sieht dann kein Direktiventoken. Der Entwurf fordert zugleich alle Branches, fehlerhaften Source und exakte Lexer-Invarianten.

**Empfehlung:** Garantie auf **vom Lexer erkannte** Direktiven begrenzen. Bei lexikalischer Beschädigung muss ein unvollständiger Source-CST mit passenden Diagnostics und großem Schutzbereich zulässig sein. Keine zweite Regex-Paarung über Kommentar-/Literaltext und keine überlappenden Tokens. Compilerverhalten beim Überspringen inaktiver, lexikalisch beschädigter Zweige ist ein eigenes Experiment; der Source-Lexer muss nicht behaupten, dieses kontextabhängige Verhalten nachzubilden.

`LEGACYIFEND` kann außerdem die erlaubten IF-Closer beeinflussen. Source-Pairing und Compilerkonformität sind getrennte Aussagen. Die aktuelle generische Paarung ist ein struktureller Index, kein vollständiger Direktivenvalidator. [Legacy-IFEND-Dokumentation](https://docwiki.embarcadero.com/RADStudio/Athens/en/Legacy_IFEND_%28Delphi%29).

### R-14 — Umfang, APIs und Testpflichten müssen widerspruchsfrei werden

**Befund:** `01` nennt vollständige Sprachziele, `10` priorisiert aber keine abschließende Sprachmatrix. Generics/anonymous methods stehen im Plan, weitere Formen wie `threadvar`, `label/goto`, `inherited`, Exports, Package-Listen, Initialization/Finalization, alte Object-Typen und `dispinterface` sind nur teilweise oder nicht ausdrücklich eingeplant. Dateiroots stehen erst unter P4, obwohl `.dpr/.dpk/.inc` Produktfälle sind.

`02` skizziert `FormattedSource`/`ProtectedRegions`, `06` dagegen `FormattedText`/`ProtectedRanges`; `TSourceParseResult` konkurriert mit `TSyntaxTree` als Ergebnis und bereits vorhandenen Diagnostics. Edittypen werden mehreren Units zugeordnet. Der Layerpfeil legt eine Lexer→Syntax-Abhängigkeit nahe, obwohl tatsächlich Syntax die Lexer-Tokenarten benutzt. Ein späteres `Core.Source` ist kein Grund, diese funktionierende Source-Referenz vorzeitig zu ersetzen.

**Empfehlung:** Verbindliches API-Dokument pro Slice statt konkurrierender „normativer konzeptueller“ Signaturen. Ein Tree besitzt Syntax/Diagnostics; zusätzliche Resultwrapper nur mit konkretem Mehrwert. Eine kanonische TextEdit-Definition; typisierte Options-DTOs unabhängig vom nativen Decoder. Tatsächlichen Abhängigkeitsgraphen explizit angeben: Core; Lexer→Core; Syntax→Core/Lexer; Parser→Core/Lexer/Syntax; Config-Decoder→Options/Core; Formatting→Parser/Syntax/Options; IO/CLI außen.

Sprachversion, Compilerfamilie/Plattformen und Features als testbare Matrix definieren. „12.3+“ bedeutet nicht automatisch alle künftigen Delphi-Erweiterungen. `.inc`-Fragmentroot/EntryMode früh spezifizieren; Program-/Library-/Package-Root als getrennte kleine Erweiterungen einplanen. Eine opaque Fragmentdatei ist lexikalisch unterstützt, aber nicht deshalb strukturell formatiert.

Die pauschale Testpflicht „ON/OFF für jede Regel“ passt nicht zu Enums/Integeroptionen. Pro tatsächlicher Wertedomäne und relevanter Interaktion testen. QA-02 muss PR-Art berücksichtigen: Ein Dokumentations-PR braucht keinen neuen Parser-Corpuslauf; ein Parser-PR keine erfundenen Formattertests. Requirement-/Test-IDs zentral zuordnen, denn z. B. CST-140 wird in verschiedenen Paketdateien für Methoden/Prozeduren in unterschiedlichen Kontexten verwendet.

## 4. Abgleich mit dem tatsächlichen Code

| Komponente / Klassen | Verifizierte Fähigkeit | Entscheidung und Begründung |
|---|---|---|
| `Core.Spans.TSourceSpan` | read-only Start/Länge, validierte UTF-16-Halboffenheit, Integer-Overflowprüfung | **Behalten.** Byteoffsets und Snapshotzugehörigkeit ergänzend modellieren, nicht in diese Span mischen. |
| `Core.Diagnostics.TDiagnostic` | Code, Text, Severity, Span als Werte | **Behalten.** Später Quelle/Phase/Kontext bei Bedarf separat ergänzen; keine vorzeitige globale Typmigration. |
| `Lexer.Tokens.TTokenKind/TDelphiToken/TDelphiLexResult` | Sourcehaltung, kopierte Wertarrays, validierter lückenloser Tokenstrom mit einem EOF | **Behalten.** Konstruktorfehler sind API-Missbrauch, nicht normale Syntaxfehler; das Exceptionverbot entsprechend präzisieren. |
| `Lexer.Scanner.TDelphiLexer` | monotone Scanner; Literale, Kommentare, Direktiven, Numerale, Unicode-Recovery | **Behalten und gezielt validieren.** Exakte 12.3- und Unicode-Grenzen offen; kein Neuschreiben wegen neuer Architektur. |
| `Lexer.Keywords.IsReservedWord` | 66 feste reservierte Wörter, ASCII-case-insensitiver Vergleich | **Behalten.** Kontextwörter im Parser. Dialekt-/Unicode-Regeln nur aufgrund Compilerbelegen ändern. |
| `Syntax.Kinds.TSyntaxKind` | M2.8 hat Ordinals 0–56, ConditionalRegion ist 56 | **Append-only erweitern.** Name/Ordinal nicht doppelt einführen. Schema-/API-Version bei exportierten Metriken festhalten. |
| `Syntax.Nodes.TSyntaxElement/Node/Token` | generische immutable Knoten, explizite Original-/Missing-Blätter | **Behalten.** Rollenqueries und Branch-/Fragmentstatus ergänzen; keine Klasse je Produktion. |
| `Syntax.Tree.TSyntaxTree` | eigene Source/Diagnostics/Arena; iterative Serialize/Free | **Behalten.** Quellidentität für Editanwendung ergänzen, sobald gebraucht; keine zweite Kindownership. |
| `Parser.Reader.TTokenReader` | nur Whitespace/Newline/Comment übersprungen; Direktiven signifikant | **Behalten.** Bounded Sicht später ergänzen. Heutiges EOF ist das Dateiende; Segmentende darf kein zusätzliches Original-EOF erzeugen. |
| `Parser.Delphi.Expression/Primary` | Präzedenz, Unary/Postfix, Calls, Member/Index/Deref, gewisse Fehlerfälle | **Behalten/erweitern.** Generics, Sets, inherited, anonyme Methoden etc. separat; Ambiguitätsindex ist keine Generic-Grammatik. |
| Deklarationen/Aggregate/Properties | einfache const/var, Routinen, klassische class/record, gewöhnliche Properties, einfache TypeReferences | **Behalten/gezielt erweitern.** Viele RHS/Modifier/komplexe Typen bleiben opaque. Ein vorhandener Outer-Kind beweist keine vollständige Deklaration. |
| Statement/Block/Control/Case/Try | M2.6-Loops, case/try, einfache raises und bekannte Else-/Separatorverträge | **Behalten.** Recovery für with/inline-for ist Schutz, keine Unterstützung. Eindeutige neue Kontexte einzeln freigeben. |
| `ClassifyDirective/IndexDirectives` | finite Klassifikation, linearer Stackindex, 32er Diagnosegate | **Herauslösen und wiederverwenden.** Erkennung ist nicht Parameter-/Compilersemantikprüfung. Kein zweiter konkurrierender Index. |
| `SectionDirective/SafeConditional/Execute` | schmale Unit-Boundary-Proofs; Branchinhalte vollständig opaque; globaler Fallback bleibt | **Stufenweise überarbeiten.** Index vom kleinen Pilot-Envelope trennen; globale Guards erst mit belegten Alternativen lockern. |
| `UnitDeclaration` und öffentliche Parse-Einstiege | Unit-, Expression-, Statement-Einstieg; keine Program-/Package-/allgemeine Fragmentgrammatik | **Kompatibel erweitern.** Explizite ParseModes, keine Dateiendungsheuristik im Core. |
| Parser-/Lexer-Tests und Fixtures | strukturelle Assertions, Fuzz/Stress, Lifetime, kompilierte positive Beispiele | **Behalten.** Lexer-Roundtrip ist kein unabhängiges Sprach-Orakel. Rollen-/Branch-/Boundedtests und 12.3-Proben ergänzen. |
| Coverage.Analysis/Runner/Reports | gepinnte Quellen, striktes Decoding, iterative Prüfungen, gewichtete Metriken | **Unverändert als Baseline behalten.** Neue Branch-/Safety-Metriken separat versionieren; alte Prozentwerte nicht nachträglich umdeuten. |
| Fetch/Test/Validate/Compare-Skripte | Corpusauswahl, Report-QA und Regressionsevidenz | **Behalten.** Analyse-I/O nicht zur produktiven Datei-/Encoding-API erklären. |
| Formatting, Config, produktives IO/CLI | nicht implementiert | **Neu, klein und schichtentreu.** Der Coverage-Console-Runner ist kein Produkt-CLI. |

### Lexer: Qualität ist belegt, Vollständigkeit noch nicht

40 Tests und compilerkompilierte Beispiele geben eine gute Basis. Noch offen sind insbesondere genaue 12.3-Grenzen, Unicode-Identifierklassen und Compilerbehandlung von Kontrollzeichen: `IsHorizontalBlank` klassifiziert U+0000 bis U+0020 außer CR/LF als Whitespace; `IsIdentifierPart` verwendet RTL-`IsNumber`. Das sind zu prüfende Regeln, keine hier nachgewiesenen Defekte. Ein Formatter darf beliebige als „Whitespace“ klassifizierte Controls nicht ohne Compilerbeleg löschen; zunächst nur Space/Tab/EOL freigeben und andere Controls schützen.

Multiline-Literalinhalt einschließlich schließender Einrückung bleibt unberührt, weil Änderungen den Literalwert beeinflussen können. Zahlenmagnitude, Constant Evaluation und Typprüfung bleiben außerhalb des Lexers. Zusätzliche Coverage durch realen Corpus und Compilerproben ist sinnvoller als ein API-Rewrite.

### PR #10: behalten, aber Anspruch begrenzen

Der Pilot hat einen nachvollziehbaren kleinen Zweck und konkrete Negativtests. Sein neues Conditional-Kind enthält **nur einen opaque Child**, keine strukturierten Branches. In den externen Corpusdateien besteht kein einziges Conditional-Island den sehr engen Proof. M2.8 ist daher eine brauchbare Zwischenstufe, keine fertige Direktivenarchitektur und kein Formatter-Safety-Nachweis.

Der Anstieg externer Parserfehler von 372 auf 616 zeigt durch weniger globalen Fallback sichtbar gewordene Lücken; er darf weder als 244 neue Quellfehler noch als automatisch unschädliche Veränderung verkauft werden. Die konkreten Hierarchien/Recoveryfälle entscheiden. Empfehlung: #10 unter seinem ursprünglichen Scope separat beurteilen; neue Architekturarbeit gegen einen explizit gewählten SHA basieren. Seine offene Merge-Entscheidung nicht mit einem neuen Architektur-/Grammar-Megapatch vermischen.

## 5. Offene Architekturentscheidungen

| ID | Entscheidungsvorschlag | Benötigter Nachweis / betroffener Gate |
|---|---|---|
| A-01 | Physischer Source-CST mit eindeutiger Blattownership; unbekannte Varianten als Fragmente | Shape-/Ownership-Verträge für Conditional-Opener, Branches, Closer und gemeinsame Suffixe |
| A-02 | Includes dürfen Schutz bis EOF oder ganze Datei verursachen | Zustands- und Resynchronisierungsmodell, Compilerproben zu Include-/Conditional-Grenzen |
| A-03 | Kontextunsicherheit getrennt von Syntaxfehler und Supportlücke | Diagnostik-/Statusmatrix für beschädigte und bedingte Syntax |
| A-04 | Tokengebundene Trivia-Slots; Insertions an Barrieren default verboten | konkrete Edit-API, Konflikt- und Kommentarankertests |
| A-05 | S0: reine Space-/Tab-/EOL-Änderungen in belegten fehlerfreien Kontexten | Tokenkorrespondenz, lokale Fingerprints, protected mapping; lexikalische Fehler verweigern |
| A-06 | Native Herkunft erhalten, inklusive nativer Tab-/Editorwerte | Originalprofile + IDE/CLI-Oracle für Prioritäten |
| A-07 | Strict nach Relevanz und Wert-Capabilities; lenient heilt keine ungültige Config | reale unbekannte/duplizierte Optionen und Fehlertests |
| A-08 | Eine Result-/Edit-/Optionsdefinition; Tree besitzt Syntaxdiagnostics | Delphi-kompilierte API-Tests mit Ownershipvertrag |
| A-09 | AST-Readiness pro Feature, aktiver AST bei Bedarf aus Zusatzsicht | Rollenqueries für Generics und Routinen, ohne AST-Code |
| A-10 | Sicherheitsbedingte Abweichung von Oracle ausdrücklich ausweisen | Produktentscheidung zur Compatibility-Matrix und Refused/Partial-Status |
| A-11 | FragmentMode früher, Dateiroots einzeln | `.inc` mit bekanntem/unbekanntem Kontext; Program/Library/Package-Fixtures |
| A-12 | Schreibpolicy mit Concurrent-change-Check; keine automatische Codepagebehauptung | Byte-/Dateisperr-/Hash-/Atomizitätstests vor CLI-Write |

Die vorgeschlagenen drei ADRs sollten diese Grenzen aufnehmen, bevor ihr Status auf accepted wechselt. Die vorhandenen alten D-xx-Entscheidungen müssen nicht pauschal verworfen werden; D-03/05/06/07/12–18 passen überwiegend. Aussagen zu einem konfigurationsabhängigen CST als primärem Nachfolger werden durch A-01 ersetzt. Historische Milestone-Abschnitte sollten als historische Stände gekennzeichnet werden; README enthält derzeit gleichzeitig M2.8 und einen alten M2.3-Absatz.

## 6. Native Config und Referenzdaten: gesichert versus offen

### Lokal nachgewiesen

Unter `C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\config` liegen vier echte mitgelieferte Profile. Es wurden nur Struktur, ausgewählte Werte und Hashes gelesen; die proprietären Dateien wurden nicht ins Repository kopiert.

| Datei | SHA-256 |
|---|---|
| Formatter_Default.config | `D8B4AC6C8DBE64168AC8AA1BCB2F47D01A8DDBEA6CC00858BAB30BB63285DEA1` |
| Formatter_Compact.config | `ED923D396E648EC77DAFC4B6666F8ACB39ED096874330E706ABFB440F4CE811B` |
| Formatter_Wide.config | `62C57C6E86B82769820B5F2FD27F1A655A358FF04F9A809EB601EB94C6A0EB98` |
| Formatter.config | identisch zu Default |

Alle haben XML-Root `TgConfig`, Attribut `Version="3"`, 158 aktive Option-Elemente und keine unter den direkten Option-Elementen beobachteten doppelten Namen. `Version=3` ist ein beobachteter Schemawert, **keine** RAD-Studio-Produktversion. Kommentare und nicht-Option-Elemente sind ebenfalls vorhanden; ein Reader darf nicht nur eine angenommene Name/Value-Liste aus beliebigem XML akzeptieren. Der Importer darf Typ-/Assemblyangaben aus Config niemals als ausführbaren Code laden.

`review-evidence/native-profile-inventory.json` hält die Inventardaten fest. Eine originale `Formatter.exe` liegt lokal vor; ihr Vorhandensein ist kein Verhaltens- oder Versionsnachweis. Kein Oracle-Golden wurde in dieser Aufgabe erzeugt. Eine genaue 12.3-Installation beziehungsweise zwei nachweisbare 12.3-IDE-Exporte wurden nicht festgestellt. Die vorhandene Toolchain ist laut dokumentierter IDE-Evidenz CE Update 1, Build 29.0.51961.7529; deren Profilwerte dürfen nicht pauschal nach 12.3 übertragen werden.

### Ohne zusätzliche Referenztests nicht verlässlich entscheidbar

1. Ob 12.3 exakt dasselbe Schema, dieselben Optionen und Defaults verwendet; Verhalten fehlender, unbekannter, doppelter und widersprüchlicher Einträge.
2. CLI-/IDE-Vorrang von TabSize, UseTabs, IndentSize, expliziten Editorwerten und Profilwerten; Wechselwirkung mit Alignment/RightMargin.
3. Effektive Abhängigkeiten zwischen Optionen: eine Variation bei sonst konstantem Profil ist nötig, reicht aber bei sich gegenseitig unterdrückenden Regeln allein nicht aus. Kleine Kombinationstests ergänzen.
4. Ob und wie der originale Formatter beide Conditional-Zweige, Includes und nicht compilierbare Quellen verändert. Dessen Ergebnis ist für fehlerhafte Quelle kein Safety-Orakel.
5. Compiler-Directive-/OtherWords-/Numeral-Capitalization, besonders Identifier ohne Symbolauflösung und localeabhängige Unicodefälle.
6. EOL, BOM, explizite Codepages, trailing newline/TrimSource und Verhalten bei gemischten Zeilenenden. Bytegleichheit und Layoutgleichheit getrennt reporten.
7. Aktuelle Suchpfade und Aufrufparameter der konkreten installierten EXE; keine IDE-Produktversion aus dem Installationsordner oder einem Profilattribut ableiten.

Diese offenen Punkte blockieren **behauptete native Kompatibilität**, nicht Lossless-CST-Arbeit oder einen internen Safety-Spike. Dokumentation belegt Optionsgruppen, nicht das vollständige Dateischema. Die [offizielle Optionsseite](https://docwiki.embarcadero.com/RADStudio/Athens/en/Formatter_Options) beschreibt u. a. Direktiven-/Kommentarformatierung; die [offizielle Formatter-CLI-Dokumentation](https://docwiki.embarcadero.com/RADStudio/Athens/de/Formatter.EXE%3A_Die_Befehlszeilen-Formatierung) warnt vor inkorrekten Ergebnissen bei nicht compilierbarem Source.

## 7. Empfohlene Reihenfolge kleiner Meilensteine

Dies ist eine **Planung**, keine Implementierungsfreigabe. Die bisherigen M2.8-Grenzen bleiben bis zu einem neuen Auftrag aktiv. Die Schritte sind absichtlich kleiner als die Phasen B/C/D des ZIP; nicht alle erfordern ein eigenes neues Modul. Abhängigkeiten sind explizit, unabhängige Stränge können nach Freigabe getrennt bearbeitet werden.

| Schritt | Enger Lieferumfang | Abhängigkeit | Nachweisbare Abnahme |
|---|---|---|---|
| A0 — Architektur und Baseline | A-01 bis A-08 entscheiden, gültige Dokumentenhierarchie und exakte Base/PR-Strategie festhalten | dieser Review | keine widersprüchlichen normativen APIs/Safety-Versprechen; dokumentierter Scope; 12.3-Verfügbarkeit ausdrücklich ausgewiesen |
| I1 — Direktivenindex extrahieren | vorhandene Klassifikation/Paarung vom Parser-Pilot entkoppeln, Verhalten unverändert | A0, gewählter M2.8-Base | unveränderte Kinds/Diagnosen/Tree-Shapes/Tokenfolge; alle bestehenden Tests und identische Corpusklassifikation |
| I2 — Begrenzte Tokenansicht | Fenster auf globalen Originalindizes, eigener End-of-window-Zustand | I1 oder unabhängig nach API-Entscheid | Lookahead/Consume überschreitet Fenster nie; Trivia am Rand eindeutig; keine zusätzlichen EOF-Blätter; Lifetime-/Nil-/leere-Fenster-Tests |
| I3 — Branch-Bodies nur gruppieren | Region/Branch/Fragment-Shapes, noch keine neue Grammar-/Editfreigabe | I1, A-01/A-03 | Opener/Branch/Closer je einmal, leere/nested/malformed Branches; keine bloße Hülle als Coveragegewinn; globale Guards bleiben |
| I4 — Eine Branch-Grammatik | ausschließlich vollständige Routine-Deklarationen in Unit-interface-Listen bounded parsen | I2/I3 | zwei echte Branchhierarchien plus unabhängiger Nachfolger; unvollständiger Header schützt Besitzer; kein Member-/Statement-Scope |
| S1 — Ein Formatter-Slot | nur Abstände an `:=` in vollständiger direktivenfreier Routine, reine String-API | A0; unabhängig von I2–I4 | exakte minimale Edits, token-/syntaxgleich, Kommentare/Opaque/Controls geschützt, idempotent, Fehler→refused; keine Config-/CLI-Abhängigkeit |
| O1 — Referenzpaket inventarisieren | echte Zielversionsprofile, Exportdeltas, EXE-/Compilerversion und Hashes | A0; unabhängig von Grammatikarbeit | reproduzierbare vorhandene Artefakte; fehlendes 12.3 explizit blockiert; keine erfundenen Keys/Defaults |
| O2 — Oracle-Harness | Originalformatter auf Kopien mit einem kontrollierten Profil/Optionspaar | O1 | Input/Outputhash, Kommando/Umgebung/Exitcode, wiederholbare Resultate; keine Nutzerdatenwrites |
| C1 — Nativen Import lesen | Schema/Encoding/Optioninventar, keine Rule-Unterstützung vortäuschen | O1 | echte Profile, sichere XML-Verarbeitung, Relevanz-/Unknown-/Duplicatefälle, kein Filesystem im Byte-Reader |
| C2 — Eine Option end-to-end | effektive Assignment-Abstände mit Provenance und Capabilityprüfung | S1/O2/C1 | belegte native Werte → Regel → Oracle-Fixture; strict/lenient/neutral/relevant-status separat getestet |
| G1 — Generic-Typreferenzen | verschachtelte Typargumente nur in eindeutigen Typkontexten | A0; unabhängig von Branch-Formatter | exakte TypeArgument-Hierarchie; `<`-Vergleiche unverändert; Compilerfixture + Recovery + post-lexer-lifetime |
| G2 ff. — je ein Grammatikfeature | Genericparameter, Constraints, Genericroutinen jeweils separat; danach priorisierte deklarative Lücken | G1 je nach Feature | positive Compilerfixture, Shape-/Recovery-/Safetygrenzen, identische Corpusdateien; keine Pflicht zu künstlichem Prozentzuwachs |
| R1 ff. — Roots/Fragmente | zuerst FragmentMode, dann Program, Library und Package jeweils getrennt | A0; früh spezifizieren, implementieren nach Bedarf | richtiger Root, EOF einmal, Fragmentkontext explizit, requires/contains/exports im jeweiligen Scope |
| D1 ff. — weitere Direktivenkontexte | Memberlisten, Statementlisten, geteilte Produktionen jeweils separat | I4 + passende Grammar | Entry-/Exit-/Separator-/Else-Gates; echte unbekannte Effekte schützen weiter; kein Include-Resolverzwang |
| F1 ff. — Layoutregeln | Einzug, Zeilenumbrüche, danach Alignment; jeweils eine Regelgruppe | S1/C2 + betroffene Grammar | Optionsdomäne/Interaktionen + Oracle + Negativbarrieren + Idempotenz; lokale Komplexitäts-/Speichermessung |
| IO1 — Datei-Lesen/Decoding | Byte-Snapshot, BOM/Codec/Hash, keine Writes | A0; unabhängig vom Layoutausbau | explizite Codecpolicy, Roundtrip/Verlusttests und unveränderte Originalbytes |
| CLI1 — check/diff | schmaler Adapter, eindeutiger Default und Exitcodes | S1/IO1, Profile soweit beansprucht | keine Writeröffnung, reproduzierbarer Diff, refused/partial sichtbar |
| IO2/CLI2 — explizites Write | Hashkonfliktprüfung, Encoding, atomarer Replace und Fehlertests | CLI1 | veränderte/gesperrte Datei nie überschrieben; kein Teilwrite; Metadatenpolicy geprüft |
| REL — behaupteter Releaseumfang | Compiler 12.3, Debug/Release, Feature-/Optionsmatrix | nur die als unterstützt ausgelieferten Schritte | veröffentlichte Grenzen statt „vollständig“ ohne Definition; 0 bekannte Safetyverletzungen in der freigegebenen Testmatrix |

`resourcestring` ist danach ein sinnvoller einzelner Grammatik-PR; es ist kein Ersatz für die Architekturentscheidung. Interfaces/Helper, Arrays/Pointers/Sets/Prozeduraltypen, Variant-/Nested-Typen, Class-Members, Attributes, Operatoren, Inline-Variablen und weitere Expressions werden anhand der veröffentlichten Sprachmatrix und realer Dateiausschnitte priorisiert. Bereits bekannte funktionale Notwendigkeit ist ein valides Gate, selbst wenn das gepinnte Corpus zufällig keinen Prozentzuwachs zeigt.

Kein vollständiger Parser vor dem ersten Formatter-Spike, kein großer Parserdatei-Refactor als Vorbedingung, kein eigener Preprocessor und kein AST. `Group/SoftLine/Align` erst einführen, wenn eine konkrete Regel sie benötigt; sechs Formatterunits sind für einen einzigen Assignment-Slot nicht zwingend.

## 8. Konkreter erster kleiner Implementierungs-PR

**Vorschlag nach Architekturfreigabe und geklärter #10-Basis:** „Extract directive classification and pairing without changing M2.8 parsing“.

**Zweck:** Eine einzige wiederverwendbare Direktivenstruktur schaffen, auf der spätere Branch-Knoten aufbauen können. Das reduziert Doppelimplementierung und lässt das funktionierende Pilotverhalten als kontrollierbare Baseline bestehen. Es implementiert noch keine neue Grammatik oder Formatierung.

**Scope:**

- Ein neues internes Modul, vorzugsweise `DelphiFormatter.Syntax.Directives.pas`, mit Klassifikation, Originaltoken-Grenzen, Pairing/Branchverknüpfungen und Wertdiagnostics. Es hängt nur von Core/Lexer ab; keine Parser-/Formatter-/IO-Abhängigkeit.
- `TDelphiParser` delegiert an den Index. Der spezielle M2.8-Procedure-Envelope und seine Boundary-/Fallbackentscheidung bleiben zunächst Parserpolitik. Kein zweiter allgemeiner und spezieller Paarungsscan.
- Parser besitzt den Index; dessen Abfragen verwenden Originalindizes und kopierte Werte, keine nach Parserende weitergereichten Lexer-Referenzen. Tree-Arena und Blattconsumer bleiben unverändert.
- Das heute öffentlich deklarierte `TDirectiveClass` darf nicht beiläufig verschwinden; vorhandene Namen/Ordinals über kompatiblen Alias erhalten oder diese konkrete API-Frage vor dem PR festlegen.

**Voraussichtliche Dateien:** neue Directives-Unit, `Parser.Delphi.pas`, fokussierte Tests, notwendige DPR/DPROJ-Referenzen und kurze Architektur-/Statusnotiz. Kein Lexer-/Reader-/Node-Rewrite und keine Änderungen am gepinnten Corpus oder Coverage-Algorithmus.

**Positive Fälle:** beide Direktiven-Kommentarschreibweisen; I+/I-Datei und R+/R-Datei; verschachtelte/fehlende ELSE-Alternativen; bestehende akzeptierte M2.8-Hüllen. **Negative Fälle:** Kommentare/Strings als Lookalikes, unbekannte/unterbrochene Direktiven, doppelte ELSE, ELSEIF nach ELSE, 32/33 Ebenen, Includes und unterbrochene Produktionen mit weiter unverändertem Fallback.

**Abnahmekriterien:**

1. Keine Änderung öffentlicher Parse-Signaturen oder bisheriger Kind-Ordinals; alle bisherigen Tree-Shapes/Diagnostics/Originaltokenfolgen unverändert.
2. 40 Lexer-, 128 Parser- und 18 Coverage-Tests bleiben grün; zusätzliche Indextests prüfen Grenzindizes und Fehlerorte unabhängig von Roundtrip.
3. Echter frischer Build auf der vereinbarten Toolchain mit EXE-/DCU-Nachweis. Falls nur CE Update 1 verfügbar ist, dies ausweisen; exakte 12.3-Abnahme bleibt offen.
4. Auf identischem Manifest und Decoding identische strukturierte/opaque/error Code-Units, Diagnosen und Fallbackzahlen. Timing nicht bytegleich verlangen.
5. Lineare Indexkonstruktion, begrenzte Rekursion/Stackstrategie und kein Originaltoken zweimal im finalen Baum. Keine neuen Branch-Formatterfreigaben.

Vor diesem Implementierungs-PR ist ein kleiner **Dokumentationsentscheid** A0 nötig. Dieser Review selbst hat weder die alten normativen Dokumente ersetzt noch weitere Milestones autorisiert. Wenn #10 nicht übernommen wird, muss I1 ausdrücklich gegen einen ausgewählten Stand neu zugeschnitten werden; nicht heimlich dessen kompletten Codeumfang in den ersten Refactor aufnehmen.

## 9. Tatsächlicher Build-/Teststatus dieser Review-Aufgabe

### Ausgeführt

- Alle 19 ZIP-Inhalte bytegenau mit den abgelegten Dateien verglichen: gleich.
- GitHub: offene PRs, #10-Metadaten, main→Head-Vergleich und Inline-Threads gelesen.
- Lokale vorhandene Win64/Debug-Testprogramme per SHA-256 mit den in `docs/M2_STATUS.md` dokumentierten M2.8-Artefakten abgeglichen: alle vier Programmhashes stimmen.
- Diese vorhandenen Testprogramme erneut ausgeführt, nicht frisch kompiliert:

| Programm | Ergebnis im finalen Lauf | Prozess-Exit |
|---|---|---|
| Lexer.Tests | 40 gefunden / 40 bestanden; 0 ignored/failed/errored/leaked laut Runner | 0 |
| Parser.Tests | 128 / 128; ebenfalls alle genannten Fehlerzähler 0 | 0 |
| Coverage.Tests | 18 / 18 im isolierten Arbeitsverzeichnis mit vorab angelegtem Build-Unterordner | 0 |

Logs: `review-evidence/lexer-rerun.txt`, `parser-rerun.txt`, `coverage-isolated-precreated-rerun.txt`. Der Coverage-Runner wurde zunächst auch aus dem Repository ausgeführt und hat seine bereits vorhandenen ignorierten generierten Testreports unter `build/coverage-report-test` erneut geschrieben. Das war eine Abweichung von der Vorgabe, bestehende Dateien nicht zu verändern; bestehender Quellcode, Dokumentation und versionierte Reports wurden nicht geändert. Ein anschließender isolierter Lauf hatte zunächst 17/18 mit einem Verzeichniserzeugungsfehler im Test `RepeatedFile`; nach Voranlage des Arbeitsunterordners bestand der erneute isolierte Lauf 18/18. Beide Logs sind erhalten; der fehlerhafte Lauf wird nicht als grün gezählt.

- Neuer Corpuslauf mit unverändertem M2.7-Manifest, vorhandener M2.8-Analyzer-EXE, drei Wiederholungen und neuem separatem Ausgabeverzeichnis unter `build/architecture-corpus-review-5e4f0eafcfeb4b8982f98798c843ebf7`.
- Report-QA durch `scripts/ValidateCoverageReport.ps1`: Schema, 167 CSV/JSON-Zeilen, Token-/Sourcepartitionen und gewichtete Aggregate **PASS**. Externe Zusammenfassung zusätzlich in `review-evidence/corpus-external-summary.json`.

| Frisch wiederholte Corpusauswertung, vorhandene EXE | Ergebnis |
|---|---:|
| Externe Dateien versucht / dekodiert | 160 / 154 |
| Structured Original-Code-Units | 150.327 von 3.927.296 |
| Structured-Anteil | 3,82774815038133 % |
| Opaque-/Error-Code-Units | 3.756.252 / 20.717 |
| Vollständige Opaque-Fallbacks | 130 |
| Analyzer-Exit | 1 wegen der sechs bekannten Decodingausschlüsse |

Die Zahlen bestätigen den archivierten M2.8-Report, nicht Sprachvollständigkeit oder Formattersicherheit. Lexer und Parser wurden dabei nicht auf allen Upstream-Compilerkonfigurationen gegen Delphi geprüft. Der gepinnte Korpus bleibt unverändert; keine Eingabedatei wurde formatiert.

### Buildgrenze

Ein echter Kommandozeilen-Buildversuch mit dem installierten `dcc64.exe`, `-B -Q`, Parser-Testprojekt und separaten EXE-/DCU-Ausgabepfaden erzeugte **kein frisches Executable**. Ausgabe: `This version of the product does not support command line compiling.` Prozess-Exit war irreführend 0. Siehe `review-evidence/compiler-attempt.txt`.

Deshalb gilt ausdrücklich: **kein erfolgreicher frischer Build in dieser Aufgabe, kein Delphi-12.3-Testnachweis, kein Release-/Plattformnachweis und keine neu erzeugten Compiler-Syntaxproben.** Die echte IDE-Buildhistorie für CE Update 1 (29.0.51961.7529) stammt aus den vorhandenen Statusdokumenten. Ein IDE-Rebuild wurde in dieser Dokumentationsaufgabe nicht vorgenommen. Es wurden keine AST-, Formatter-, Config- oder Grammarfeatures implementiert; keine bestehenden Klassen geändert und kein PR erzeugt.

Die versionierten Dateien waren vor Beginn sauber; abschließender Git-Abgleich muss ausschließlich neue Dateien unter `design/` zeigen. Neue ignorierte Laufzeitartefakte liegen unter `build/`; die oben genannte Ausnahme bei generierten Coverage-Testreports ist offengelegt.

## 10. Quellen- und Referenzgrenzen

Primäre lokale Belege: `docs/CST_SPEC.md`, `ARCHITECTURE.md`, `LEXER_SPEC.md`, `DECISIONS.md`, `TEST_PLAN.md`, `M2_8_DIRECTIVES.md`, `M1_STATUS.md`, `M2_STATUS.md`, `reports/m2_8/comparison.md`, `examples.md`, die im Komponentenabgleich genannten Units und die Review-Evidenzdateien. Relative Pfade in diesem Bericht sind repositorybezogen; die importierten Spezifikationen liegen unter `design/docs/`.

Online gelesen wurden die oben verlinkten offiziellen Embarcadero-Seiten sowie [Conditional Compilation](https://docwiki.embarcadero.com/RADStudio/Athens/en/Conditional_compilation_%28Delphi%29), die unter anderem 32 Verschachtelungsebenen und dateilokale Conditional-Paarung beschreibt. Einzelne englische Athens-Seiten lieferten HTTP 403; dafür wurden gekennzeichnete offizielle Sprach-/Versionsalternativen verwendet. Dokumentation ist Rechercheevidenz; strittige Zielcompilerregeln bleiben bis zum 12.3-Experiment offen.

Der nächste kleine Arbeitsschritt ist A0: Include-/Branch-/Edit-/Config-Verträge aus diesem Review fachlich entscheiden und die gültige Baseline festlegen. Danach kann der konkret beschriebene I1-PR separat beauftragt werden.
