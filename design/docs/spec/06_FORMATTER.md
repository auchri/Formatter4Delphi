# 06 – Formatter-Safety, S0 und Verifikation

Anforderungen FMT-01 bis FMT-10. Slot/Edit/Result/Options/Fingerprintdefinitionen stehen ausschließlich in [14](14_CONTRACTS.md). Keine alternative Signatur hier. [ADR-002](../adr/ADR-002-safe-editing.md) begründet die Entscheidung.

## Pipeline und positive Freigabe

Parse unveränderten Snapshot → Syntax-/Kontextfakten → tokengebundene Slots → Safetyentscheidungen → Regel/Layoutentscheidungen → kanonische Editmenge → einmal anwenden → einmal Re-Lex/Re-Parse → verifiziertes Result.

Safety ist parserextern. Jeder Slot ohne positiven Kontext-/Regelbeleg ist geschützt. ProtectedIntervals sind Anzeige/Abfragehilfe und kein Ersatz für Slotfreigabe. Keine Erlaubnis allein wegen gleichem Parent, strukturiertem Knotennamen oder leerer Diagnosticliste.

## Sicherheitsprofil S0 (erster Slice S1)

Freigegebene Funktion: ausschließlich horizontale Abstände direkt vor/nach := einer AssignmentStatement in einer vollständig strukturierten Routine einer vollständigen direktivenfreien Unit. Interne Option AssignmentSpacing wird explizit gesetzt, ohne RAD-Kompatibilitätsclaim.

- Datei hat keine Lexical-Error-Diagnostics, keine Opaque-/Error-/Missing-/Fragment-/Limit-/ContextUnknownteile; keine Compiler-Direktiven. Andernfalls refused für die ganze Datei.
- Beide benachbarten Anker sind echte bekannte Codetokens; am :=-Slot sind Identifier, numerische Literale und bekannte Designatordelimiter zulässig. Kommentare, Stringliteral-/CharCode-Anker und Unknown sind ausgeschlossen. Rolle des Assignments und sein vollständiger Routineowner sind belegt. Literaltoken-Inhalt wird niemals geändert.
- Slot enthält nur U+0020 oder U+0009 oder ist leer. Jeder EOL-Slot und jeder Slot an Kommentar-/Stringliteral-/CharCode-/Direktivengrenzen bleibt exakt erhalten; numerische Literale sind als unveränderte Anker am Assignment erlaubt. Andere Control-Whitespace führt bei einer angeforderten betroffenen Stelle zur Verweigerung, niemals stilles Entfernen.
- Keine neuen Zeilen, kein Ändern vorhandener EOL, kein Indent-/Alignment-/Case-/Commenttext-/Directiveedit, kein Syntax-Autofix. Ein explizites AsIs erzeugt keine Edits.
- Wenn keine angeforderte Regelstelle vorhanden ist: erfolgreich unchanged nach Verifikation der Inputvorbedingungen.
- Nur unchanged/changed/refused; kein Partial. Erster Slice darf konservativ mehr verweigern, muss Gründe nennen; keine Safetyzusagen für Include-/Branchformatierung.

Diese engere Erstfreigabe hindert nicht die spätere deklarierte Erweiterung des Profils. Jede Erweiterung benennt eigene Voraussetzungen, Tests und Kompatibilitätswirkung. Ein unbekannter Compilersemantikeffekt ist kein neuer Rewriteauftrag.

## Kommentar- und Direktivenanker

Zeilenkommentar behält linken Codeanker, Originalzeilenbindung und folgenden EOL; keine Leerzeile vor Kommentar, die ihn einer anderen Anweisung zuordnet. Führende Dokumentationskommentare behalten rechten Deklarationsanker, Reihenfolge und relevante Leerzeilengruppen. Blockkommentare behalten Ankerpaar; mehrzeiliger Inhalt und EOL darin bleiben exakt. S0 schützt vorsorglich beide angrenzenden Slots. Literale bleiben unverändert einschließlich schließender Multilineeinrückung.

Direktiven bleiben in derselben Originaltokenreihenfolge, Branchzugehörigkeit und Ankernachbarschaft; **absolute UTF-16-Offsets sind kein Invariant**, weil frühere sichere Edits Längen ändern können. S0 schützt Direktiventext und angrenzende Slots. Native Directiveindent/Capitalization/Leerzeilenoptionen sind dadurch zunächst nicht unterstützt; ein Oracle darf Safety nicht überstimmen.

## Regeln, Konflikte und Layout

Jede Regel registriert RuleId, Optionswertedomäne, unterstützte N-*-Rollen, Preconditions, beeinflusste Slots, Priorität und gegebenenfalls Oracle-EvidenceIds. Booloptionen ON/OFF, Enum-/Integerwerte domänengerecht testen. Reihenfolge: Safety → explizite Optionsconstraints → dokumentierte Priorität. Identische Slotentscheidungen deduplizieren; ungelöster Unterschied führt refused, kein „letzter gewinnt“.

S0 benötigt keinen universellen Group/Align-Frameworkbau. Spätere Regeln dürfen Textanker/Space/SoftLine/HardLine/Indent/Group/Align/Barrier als Layoutprimitive einführen, sobald nötig. Textanker reproduzieren Originallexeme. Ein gefrorener Slot ist harte Layoutconstraint; nicht in anderen Regeln indirekt neu schreiben.

Edits sind maximal eine vollständige Slotersetzung je Slot. Dieselbe Offsetposition mit unterschiedlichen Insertions ist Konflikt, auch bei Länge null. Geschlossene Barrieren schützen beide Randpunkte. Ausnahmen erfordern später explizite neue Boundarypolicy mit Tests; keine implizite Halboffenheitslücke.

## Verifikationsalgorithmus

1. SourceIdentity plus exakte OriginalSource-Gleichheit gegen den zu ändernden String prüfen; alle Editspans in Bounds, sortiert, disjunkt, regel-/slotgebunden und barrierenkonform.
2. Nur Space/Tab/EOL gemäß jeweiliger Profilfreigabe in NewText; S0 nur horizontale Zeichen. Alle unveränderten Slots ergeben 0 Edits.
3. Einmal rückwärts anwenden. Erzeuge eine monotone Editmap der unveränderten Originalanker und Bereiche; bei gemeinsamen Einfügepunkten ist wegen Konfliktregel keine unbestimmte Ordnung zulässig.
4. Neu lexen. LexicalSignatureV1 exakt vergleichen; vollständige Sequenz statt bloß Hash. Tokenkorrespondenz stellt Kommentar-/Directive-/Unknown-/EOF-Erhaltung sicher.
5. Neu parsen. Je freigegebenem vollständigem Owner SyntaxFingerprintV1 vergleichen. Diagnostic-Code/Severity/Message und gemappten Ort vergleichen; keine neuen Lexer-/Parserdiagnosen im freigegebenen Bereich, nicht nur gleich viele.
6. Geschützte Source-Slices nach Editmap und Ankerbeziehungen exakt vergleichen. EOL-/Kommentarbindung zusätzlich prüfen; reine meaningful-token-Gleichheit reicht nicht.
7. Bei jeder Verletzung gesamte Editmenge verwerfen, output=input, 0 Edits, refused. Kein unbeschränktes Entfernen einzelner Edits und erneut Versuchen.

Gleicher Parser/Lexer vor/nach Edit ist ein notwendiger Schutz, kein Compiler-/Semantikbeweis. Compiler-validierte Positivfixtures und unabhängige Gegenbeispiele bleiben erforderlich. Idempotenz wird in Tests durch zweimaliges FormatText geprüft; Engine ruft sich nicht rekursiv zum Beweis auf.

## Ergebnis und spätere Teilformatierung

Outcomes und Compatibility sind unabhängig nach 14. Lenient Config kann partial-compatibility tragen, ohne dass nur ein Textteil formatiert wurde. foPartiallyChanged ist ausschließlich für tatsächlich geänderte sichere Regionen bei gemeldeten ausgelassenen angeforderten Regionen. Es ist erst nach separatem Gate für Edit-Subset-Verifikation zulässig. Ein fehlgeschlagener globaler Invariant ergibt immer refused.

## IO/CLI-Grenze

Engine sieht keine Bytecodepage und öffnet keine Datei. CLI ohne Modus ist check; 0=erfolgreich ohne Unterschied, 1=verifizierter Unterschied, 2=refused/Config-/Encoding-/IOfehler. diff verwendet dieselben Codes und schreibt nur den Diff nach stdout. write ist explizit und erst IO2/CLI-Write-Scope; Codec/BOM/Hashkonflikt/Atomizität nach 01/09. Spätere Partials verlangen ausdrücklichen CLI-opt-in, sonst Exit 2 ohne Write.
