# ADR-004 – Kanonische Verträge, Slice-Scope und Baseline

**Status:** A0-Entscheid zur Reviewfreigabe; Implementierung nur mit gesondertem Auftrag. **Befunde:** R-11/R-12/R-14 und offene #10-Basis.

## Entscheidung

Anforderungen einmal in 01, API-/DTO-Verträge einmal in 14, physische Rollen einmal in 04, Testverträge einmal in 08. Andere Kapitel referenzieren diese Definitionen. SyntaxIssues sind eine orthogonale Menge, kein konkurrierendes Branchstatus-Enum. Ein Tree besitzt Diagnose-/Kontextfakten; kein zusätzlicher ParseResultwrapper.

Append-only Kind-/APIerweiterungen, vorhandene Core-/Lexer-/Arena-/Readerverträge bleiben. Rollenqueries statt Produktionsklassen/Parentpointer, Kontextfenster statt Kopieren/Retokenisieren von Source. Generic-Typreferenzen vor Constraints/Methoden/Expressioncalls, jede Form als kleiner Schritt.

A0 basiert nur auf gepinntem main/M2.7. #10 wird separat ausdrücklich disponiert; empfohlener erster Code-PR I1 setzt seine akzeptierte Integration voraus. Ablehnung führt zu neuem Scope, nicht stiller Übernahme. Unabhängiges S0/Oracle darf nach eigener Autorisierung auf konkret gepinntem main starten. 12 enthält genaue SHA-/Backupstrategie.

## Begründung / verworfene Alternativen

Mehrere Konzeptsignaturen erzeugen untestbare Owner-/Lifetimeabweichungen. Ein großes Parserrefactoring vor Nutzen würde funktionierende Regressionsevidenz entwerten. Ein PR auf #10 mit Ziel main würde dessen Codeänderungen als Dokumentationsänderung verschleiern. Automatisches Mergen ist weder erforderlich noch autorisiert.

G0/Architecture heißt konsistente umsetzbare Verträge, nicht angeblich geprüfte Sprach-/Oracleergebnisse. Whole-file-Schutz ist zulässig; „immer beabsichtigte Recovery“ und „jede Änderung muss Corpusprozente erhöhen“ werden nicht als erfüllbare Gates gefordert.

## Folgen / Nachweise

T-DOC/T-BASE/T-API/T-OWN; eindeutige Traceability in 15. Historische docs/*, ARCHITEKTUR_REVIEW.md und review-evidence bleiben als Bestand/Evidenz, nicht als aktuelle konkurrierende Architektur. Compiler-/Oraclefragen nur in 11. Der A0-PR selbst implementiert nichts und autorisiert keinen folgenden Milestone.
