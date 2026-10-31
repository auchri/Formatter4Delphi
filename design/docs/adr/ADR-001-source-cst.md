# ADR-001 – Physischer Source-CST, Kontexte und optionale Compilation-Sicht

**Status:** A0-Entscheid zur Reviewfreigabe. **Befunde:** R-01/R-02/R-03/R-04/R-11/R-13.

## Entscheidung

Genau ein physischer Originalbaum pro UTF-16-Dateisnapshot, arenaowned/immutable mit einmaligen Originalblättern. Konkrete Rollen in 04, Status-/Kontext-/Fenstervertrag in 14. ConditionalRegion enthält alle lexikalisch erkannten Branchbereiche; keine Aktivitätswahl, kein dupliziertes gemeinsames Präfix/Suffix. Unbekannte/unterbrochene Produktionen bleiben Fragment/opaque mit expliziten Issues.

Unresolved Includes und unbekannte Effekte dürfen einen Besitzer/Suffix bis EOF oder die ganze Datei schützen. Vorläufige nachfolgende Struktur ist zulässig, aber keine Formatfreigabe. Branches nur bei nachgewiesenem Entry/Exit und exaktem Fensterverbrauch vollständig nennen; fehlendes ELSE als leere Alternative im Join. Lexikalisch absorbierte Marker nicht neu aus Rawtext tokenisieren.

Eine spätere Compilation-Sicht darf aktive Tokens/SourceOrigins auf Originaltrees referenzieren und einen konfigurierten AST-Verbraucher bedienen. Sie ersetzt den Source-CST nicht und ist keine Formattervoraussetzung. Jetzt kein AST/Resolver/Preprocessor.

## Begründung und Alternativen

Formatierung benötigt Trivia, inaktive Source und Originalspans. Nur aktive Compilation-CST würde Source verlieren und Projektkontext erzwingen. Ein Baum je Konfiguration dupliziert gemeinsame Originaltokens oder benötigt einen ungewollten DAG. Ein vollständiger Variationsparser ist unnötig; konservative Fragmente sind ehrlicher und begrenzen Komplexität.

Immer alle Conditionals opaque wäre langfristig zu schwach; alle Includes zwingend lokal resynchronisieren wäre ohne Effektbeleg unsicher. Daher unabhängige Branchkontexte schrittweise erweitern und größere Schutzbereiche explizit zulassen. „Fragment“ bedeutet nicht bewiesene Sprachgültigkeit, „complete“ nicht semantische Kompilierbarkeit.

## Konsequenzen / Verifikation

Bestehende Node-/Token-/Arenamodelle bleiben; #10-Regionordinal bei Übernahme erhalten. Keine mehrfachen Parents, Parentpointer oder Produktionsklassen. Bounded Window hat Endstatus statt extra EOFtoken; Root besitzt einziges Original-EOF. Rollenqueries begründen featureweise AST-Readiness ohne ASTobjekte.

CST-01 bis CST-10/DIR-01 bis DIR-06 → T-LOSS/T-WIN/T-COND/T-CONTEXT/T-INCLUDE/T-ROLES/T-REC. Zielcompilerfragen E-COMP/E-DIR/E-INCLUDE bleiben offen und blockieren nur ihre jeweilige stärkere Behauptung.
