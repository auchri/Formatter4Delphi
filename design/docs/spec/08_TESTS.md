# 08 – Testverträge und Evidenz

Requirementzuordnung: [15](15_TRACEABILITY.md). Folgende T-IDs bezeichnen **Testverträge**, nicht bereits implementierte DUnitX-Methoden oder ausgeführte Tests. Konkrete Testmethoden/Fixturepfade und EvidenceIds trägt der jeweilige PR nach. Quelle der Sprach-/Oracleexperimente: [11](11_OPEN_QUESTIONS.md).

## Testregister

| Test-ID | Positivnachweis | Gegenprobe / verbindliche Assertions |
|---|---|---|
| T-LEX | Tokenarten, Texte, UTF-16-Spans, ein EOF, echte Compilerfixtures | malformed/Unicode/Controls/quote runs, seeded fuzz, Grenzen und Diagnostics; Streamlossless allein reicht nicht |
| T-LOSS | Serialize über Blatttraversierung, Reihenfolge inklusive EOF | jedes Originalblatt einmal, Kind/Index/Span exakt, Parentunion/geordnete Kinder, keine DAG-/Arenaorphans |
| T-ROLES | Rollenqueries für vollständige Routinen/Generictypen | kein Source-Reparse; Modifier/Opaque klar unvollständig; Query nach Lexerfreigabe |
| T-REC | fehlende Satzzeichen, bekannte Grenzen und nearest-if else | damaged/unbalanced end/else/semicolon, größerer geschützter Besitzer bei Ambiguität; Diagnostics/Shapes deterministisch |
| T-WIN | leer/trivia-only/exakter Body, globaler Index | Lookahead/Consume vor Endmarker gestoppt, Endstatus kein Token/EOFblatt, trailing Trivia zugeordnet, Rollbackownership |
| T-COND | opener/Branches/closer, leerer/nested Branch, gemeinsame Präfix-/Suffixsyntax | keine Blattduplikate; fehlender Closer/unmatched marker; Container zählt nicht als structured |
| T-CONTEXT | unit-interface Entry/Exit exact, später separater Member-/Statementtest | fehlendes ELSE als leere Alternative; abweichende Visibility/Separator/Else-Owner machen Join unknown |
| T-INCLUDE | Originalinclude bleibt, kein IO, bekannte davorliegende Struktur | Include kann Kontext bis EOF tainten; vorläufiger Suffix keine Freigabe; keine keywordbasierte Resynchronisierung |
| T-DIR | beide Kommentarformen, I+/I-Datei, R+/R-Datei | unknown/malformed/pairing/32–33 Tiefe, LEGACYIFEND getrennt; String-/Commentlookalikes und absorbierte Marker |
| T-FRAGMENT | bekannter Fragmentmode und unknown-fragment lossless | keine erzwungene Unit, keine „gültig“-Behauptung; context_unknown statt bloß Syntaxerror |
| T-SLOT | Identität/Ankerpaar, leerer und horizontaler Slot | BOF/EOF, zero-width geschlossene Barrieren, gleiche Offsetinsertions, Überlappung, Konflikt statt LastWins |
| T-S0 | ausschließlich Assignmentabstände in vollständiger direktivenfreier Unit/Routine | Kommentare/Literale/Charcodes/Controls/EOL/Directives/Errors/Opaque/Missing verweigern oder eingefroren nach Profil; keine Partialausgabe |
| T-VERIFY | LexicalSignatureV1/SyntaxFingerprintV1 und gemappte Originalanker | Lexemfusion, Kommentarbindung, Diagnostic-Ortsverschiebung, Schutztextänderung, stale snapshot; jede Verletzung refused, 0 Edits |
| T-IDEM | gleicher Snapshot/Optionen → gleich; zweiter Lauf 0 Edits | wiederholte Runs, EOLmix, unterschiedliche Dictionaryreihenfolge; keine rekursive Enginevalidierung |
| T-CONFIG | echte Profile, Rohreihenfolge/-typen/-orte, sicheres XML | foreign XML/DTD/entities/Assemblyausführung, malformed/invalid Encoding, Duplicate/ambiguous statt stillem Default |
| T-RELEVANCE | belegte irrelevante C++-/UIoptionen blockieren nicht | unknown Wirkung blockiert strict; unsupported wirksamer Wert; neutral nur mit Featurebeleg |
| T-EFFECTIVE | Provenance/nativer Tabwert/explicit override, klare Lifetimes | fehlender notwendiger Wert, unbekannter Vorrang, lenient invalid verboten, Compatibility separat von Textoutcome |
| T-ORACLE | versions-/hashgebundene einzelfeaturebezogene native Ausgabe | geänderte Option isoliert + Interaktion; wiederholt, Compilerpositive, Text- und Bytediff; kein Oracle als Error-Safetybeweis |
| T-IO | BOM/explicit Codec/bytegenauer Roundtrip, Sourcehash | mehrdeutige ANSIbytes nicht „detektiert“, malformed bytes, nicht darstellbare Ausgabe, EOLmix/no final newline |
| T-WRITE | geprüfte Ersetzung und Metadatapolicy | geänderte/gesperrte/readonly Quelle, replace failure, Links/ACL/Backup; keine Teilwrites |
| T-CLI | Default=check; check/diff/write mit definierten Codes | check/diff öffnen keinen Writer, refused/Partial ohne opt-in kein Write, Pfade/Configfehler |
| T-OWN | Ergebnisse nach Inputfreigabe, wiederholte Allokation/Free | Arrayaliasmutation, Doppelowner, Arena-/Fensterrollback, nil/invalid APIs, Leakreport |
| T-API | vorhandene Signaturen/Kindordinals erhalten, additive neue API | genau kanonische DTOs aus 14; keine Aliasarrays, Dependency-Zyklus/Ownerbruch |
| T-CORPUS | unveränderter gepinnter Manifest/Hashes/Decoding, gleiche gültige Menge | gewichtete statt gemittelte Anteile, 6 bekannte Exclusions gesondert; Branchcontainer kein Coveragegaming |
| T-GRAMMAR | jede freigegebene Featurezeile aus 10 mit benannten Compilerpositiven und Rollen | zugehörige Recovery-/Ambiguitätsfälle, exakte Token-/Spans/Lifetime; keine „vollständig“-Meldung bei opaque Teilen |
| T-PERF | monotone Scans, lange Ketten/tiefe Nestings, feste Seeds | Ressourcenlimit/Progress, kein O(n²)-Suffixscan; Timerbeobachtung statt fragiler Millisekundenasserts |
| T-DOC | IDs/Links/Owner/API-Einzigkeit/Traceability konsistent | fehlende Test-/PR-/Experimentreferenz, widersprüchliche normative Definition oder unerfüllbares Gate ablehnen |
| T-BASE | main/#10/Base/Head und Doc-only-Diff eindeutig | offener #10 nicht als main-Fähigkeit, keine stillen Code-/Corpusübernahmen |

## Durchführung und Grenzen

DUnitX bleibt einzige Testbibliothek; Compilerpositive werden wirklich als Fixtures kompiliert, syntaktisch ungültige Recoveryinputs bleiben separate Stringtests. Bei Branchfixtures jede behauptete positive Auswahl in passenden Defines separat prüfen; kein Full-Preprocessor im Produkt.

Die bestehenden Parserhelper prüfen nach Lexerfreigabe Originaltokens/Spans/Shape. Der Coveragewalker prüft iterativ; bestehende rekursive Testwalker sind kein Beleg beliebig tiefer Traversierbarkeit. Tiefe/lange neue Fälle iterativ prüfen. Streamtoken-Gleichheit verwendet den eigenen Lexer und ersetzt keine Compilerpositive.

Gepinntes M2.7-Corpus und Analyzer bleiben als Vergleich unverändert. Neue Branch-/Slot-/Safe-Metriken separat versionieren, alten Nenner nicht ändern. Alle dekodierten Vorher/Nachher-Dateien identisch vergleichen, externe/internal getrennt, unsupported nicht als Quellfehler ausgeben.

## PR-spezifische Gates

Dokumentation: T-DOC/T-BASE und geprüfter Pfadumfang; kein Pflicht-Rebuild unveränderter EXEs. Lexer: T-LEX/T-LOSS/T-OWN und betroffene Compilerprobe. Parser: T-LOSS/T-ROLES/T-REC/T-OWN/T-CORPUS plus betroffene T-GRAMMAR/DIR/WIN. Formatter: T-SLOT/T-S0/T-VERIFY/T-IDEM plus Options-/Oracleprüfungen für beanspruchte Kompatibilität. IO/CLI: Byte-/Negativ-/Writerchecks, nicht nur Unit-Exitcode.

Ein Build ist nur frisch mit erzeugtem EXE/DCU, Timestamp/Hash und passender Sourcebaseline belegt. Delphi 12 CE Update 1, 29.0.51961.7529, ist kein Delphi 12.3. Exit 0 ohne Artefakt beweist nichts. Anzahl tatsächlich ausgeführter Tests, ignored/errors/leaks und Einschränkungen ausweisen. Keine historische Review-Evidenz als aktuellen A0-Run ausgeben.

## A0-Status

In A0 keine Compiler-, DUnitX-, Oracle- oder Corpusläufe erforderlich/behauptet. Die vorherige Reviewaufgabe führte vorhandene Binärprogramme erneut aus und dokumentierte den erfolglosen frischen CE-CLI-Buildversuch; siehe unveränderten ARCHITEKTUR_REVIEW.md. A0 prüft Dokumente und ausschließlich Dokumentationsdiff.
