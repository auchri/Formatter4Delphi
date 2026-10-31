# ADR-002 – Tokengebundene Trivia-Slots und S0

**Status:** A0-Entscheid zur Reviewfreigabe. **Befunde:** R-05/R-06/R-07/R-10.

## Entscheidung

Tokengebundene Slots sind die editautoritativ freigegebenen Stellen; Intervalle nur Reporting-/Abfragehilfe. Slotidentität, Anker, geschlossene Schutzgrenzen, TextEdit/Result/Signaturen ausschließlich in 14. Bei gleicher Offsetposition nur eine finale Entscheidung, identische deduplizieren, abweichende ausdrücklich auflösen oder refused.

S0 nach 06 erlaubt nur horizontale Assignmentabstände in vollständigen direktivenfreien Unit-/Routinekontexten. Keine Kommentare-/Direktiven-/Literal-/EOL-/Caseänderung; lexikalische Fehler verweigern ganze Datei. Keine Partialausgabe im ersten Slice.

Einmalige Editanwendung und einmaliges Re-Lex/Re-Parse plus gemappte Token-/Rollen-/Diagnostic-/Anker-/Schutztextprüfung. Bei Verletzung gesamte Menge verwerfen, input=output. Idempotenz als Testgate, kein rekursiver Enginebeweis.

## Begründung / Alternativen

Lossless Parser und gleicher Parent beweisen keine Editsicherheit. Halboffene Intervalle allein lassen zero-width Randinsertions offen. Bedeutungsvolle Codelexeme allein schützen Kommentarbindung nicht. Derselbe Parser vor/nachher kann denselben Fehler machen; Compilerpositive bleiben nötig, kein allgemeiner Semantikbeweis.

Verzicht auf größere Layoutinfrastruktur ist für S0 ausreichend. Spätere native Direktiven-/Case-/Commentoptionen benötigen expliziten neuen Vertrag statt heimlicher Lockerung. Safety schlägt kosmetische Oracleparität; unsupported Wirkung sichtbar melden.

Codec/BOM/Byteorigin und gesicherter Writer bleiben außerhalb der Engine. Roundtripfähige Decodierung beweist nicht die beabsichtigte Codepage; vor Write Concurrent-source-Hash prüfen.

## Folgen / Verifikation

FMT-01 bis FMT-10/IO-01 bis IO-04 → T-SLOT/T-S0/T-VERIFY/T-IDEM/T-IO/T-WRITE/T-CLI. Weitere Rule-/Partial-/Tokenrewritefreigaben nur mit eigenem Scope und spezifischem Nachweis. Native Kompatibilität bleibt vom Textoutcome getrennt.
