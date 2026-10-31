# Arbeiten mit der A0-Spezifikation

Verbindliche Scope-/Nachweisregeln: 01/08/09/12; APIdefinitionen ausschließlich 14, Traceability 15. Dieses Dokument autorisiert keine Implementierung.

1. Aktuellen autorisierten Schritt, Base/Head, PR-#10-Disposition und schützenswerte uncommittete Änderungen feststellen. Niemals branchwechseln, stagen oder fremde Änderungen committen, ohne ihren Umfang zu kennen und sie abzusichern.
2. Betroffene Requirement-/Feature-/Test-IDs nennen; 14 und passende Rollen/Detailkapitel lesen. Historische docs/* und Reviewevidenz nicht als konkurrierende Zielverträge benutzen.
3. Genau eine kleine PR-Instanz nach 09 festlegen: Voraussetzungen, konkrete Dateien/APIs, positive/negative Source, Compiler-/Oracleevidenz, Nichtziele.
4. Bei Language-/Nativeverhalten zuerst Experiment aus 11. Fehlende Daten blockieren gezielt die Capability, nicht das ganze Projekt. Keine erfundenen Defaults/Configkeys/12.3-Ergebnisse.
5. Originaltoken-/Arena-/Snapshot-/bounded-/Slotverträge erhalten. Keine IO im Core, kein Resolver, keine AST- oder Preprocessorimplementierung.
6. Scopeangemessene Tests ausführen und frische Artefakte prüfen; Exitcode allein genügt nicht. Dokumentations-PR benötigt keine erneute unveränderte Runtime-Suite.
7. Traceability/Featurestatus/ADRs im selben PR aktualisieren; belegte Abweichung begründen. Kein Merkmal als structured/verified markieren, wenn nur opaque erhalten/importiert.
8. PR erstellen nur bei Auftrag; nicht automatisch mergen. Nach dem autorisierten Gate stoppen.

## PR-Beschreibung

Problem/resultierendes Verhalten, gewählte Base/Head-SHAs und Scope. Geänderte öffentliche APIs/Kinds/Owner und betroffene Requirement-/Test-IDs. Tatsächliche Compiler-/Test-/Oracle-/Corpusresultate samt Grenzen; „nicht ausgeführt“ ausdrücklich statt historischer Counts als aktuelle Resultate. Positive und negative Safety-/Ownershipbelege. Keine Gesprächschronik/abandoned Ansätze, außer sie erklären einen realen Tradeoff.

Bei Dokumentation: verwendete Baseline, Zusammenfassung fachlicher Entscheidungen, ID-/Link-/Traceabilityprüfung und dokumentationsreiner Diff; keine Implementierungsfreigabe implizieren. Bei Config: Zielversions-/Profil-/EXEhash. Bei Parser: identische gepinnte Vergleichsdateien. Bei Writer: Schutz vor Concurrent-change und Teilwrites.

## Widersprüche

Source-/Token-/Safetyinvarianten schlagen kosmetische Oracleparität. Compilerbeleg schlägt unbelegte Sprachheuristik; Originalformatter ist nur Kompatibilitätsreferenz, nicht Error-Safety-Orakel. A0 selbst bleibt Reviewentwurf bis angenommen; spätere konkrete Aufgaben autorisieren nur ihren expliziten Scope.
