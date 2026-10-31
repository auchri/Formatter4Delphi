# 13 – Abnahmeszenarien

Testverträge aus [08](08_TESTS.md), Requirementlinks in [15](15_TRACEABILITY.md). Dies sind zukünftige erwartete Ergebnisse, keine ausgeführten Resultate und keine erfundenen Oracle-Goldens.

| Szenario | Input / explizite Vorbedingungen | Erwartetes Ergebnis / verbotener Effekt |
|---|---|---|
| E2E-01 / S1 | vollständige directive-free Unit mit deklariertem X und Routine P, Body X:=1; interne AssignmentSpacing=Both, alle anderen Einstellungen ausdrücklich AsIs/Preserve | echte Routine/Assignmentrollen, genau zwei horizontale Slotentscheidungen, X := 1;, unveränderte LexicalSignature/Fingerprint, zweiter Lauf 0 Edits; kein IO/Configclaim |
| E2E-02 / I3,I4 | vollständige Unit mit IFDEF DEBUG um procedure A; versus procedure B; im interface, danach procedure C; | Open/Branch0/Branch1/Close einmalig; I3 Bodies noch Fragment/opaque, I4 beide vollständigen Routine-Rollen; C außerhalb; keine Aktivitätsauswahl; S0 verweigert Formatierung |
| E2E-03 / C1,C2 | echtes Zielprofil mit schemazulässigem unbekanntem potentiell Delphi-wirksamem Feld | Rohkey/-wert/-ort sichtbar; strict verweigert; explizit lenient kann Supportlücke melden, niemals invalid/ambiguous Profil heilen; keine Datei writes |
| E2E-04 / D3 | gemeinsame Typdeklaration mit Integer-/string-RHS unter IFDEF | gemeinsamer Name/Equals/Semicolon einmal, bedingte RHS-Bodyrollen; zunächst SyntaxFragment; keine zwei aktiven Typdeklarationen, keine ungeprüften Edits |
| E2E-05 / DIR-02 | unresolved Include in Class-Owner oder vor möglichem Conditional-Suffix | Include nie öffnen; abhängiger Suffix bis EOF/Datei darf protected bleiben; vorläufige Methode danach keine Safetyfreigabe |
| E2E-06 / IO1,CLI1,IO2 | eigene UTF-8-BOM/CRLF-Dateikopie, erfolgreicher S0-Input | check/diff unveränderte Bytes; write nur explizit nach Sourcehash-/Codec-/Replaceprüfung, BOM/EOL erhalten |
| E2E-07 / IO1 | Bytes mit mehreren roundtripfähigen ANSIinterpretationen ohne Codecprovenance | keine behauptete sichere Erkennung der „falschen“ Interpretation; explizite Codecwahl verlangen oder refuse; kein Verlustwrite |
| E2E-08 / O2,C2 | echte Zielversionsprofile/-EXE, gemessene unterstützte Assignmentoptionwerte | nur für belegte Capability gleiche Ausgabe; unsupported Direktiven-/Case-/Tabwirkung sichtbar statt ignoriert |
| E2E-09 / T-SLOT | zwei unterschiedliche zero-width Insertions bei gleichem Offset beziehungsweise direkt an Schutzgrenze | keine Disjunktheitslücke, Konflikt/refused, input=output, 0 Edits |
| E2E-10 / T-VERIFY | gleichbleibende Codelexeme, aber drohende geänderte Zeilenkommentar-/Doccommentbindung | Anchorinvariant verhindert Änderung; Kommentartextgleichheit allein genügt nicht |
| E2E-11 / R1 | eigenständige .inc als expliziter pmFragment/pcUnknown-String ohne Dateizugriff | lossless FragmentRoot mit einzigem originalem EOF; context_unknown; keine Unit-Reparatur/Formatierungsfreigabe |
| E2E-12 / G1 | TypeReference TDictionary<string,TList<Integer>> im unterstützten Typkontext | zwei Typargumente, verschachtelter GenericTypeReference, keine neue Lexerklassifikation; Rollenquery ohne String-Reparse |
| E2E-13 / FMT-03 | malformed UTF-16 oder lexikalisch ungeschlossener Literal-/Kommentartoken | Lexer/Tree lossless mit Diagnostics; FormatText refused ganze Datei, Text unverändert, keine neue Rawtext-Direktivensicht |

Die Positivquelle für E2E-01 muss X tatsächlich deklarieren; ein bloß parsergültiges unaufgelöstes X ist kein Compilerpositiv. Compiler-/Oraclebelege werden erst in den jeweiligen Implementierungs-/Experiment-PRs ergänzt. Erfolgreiches unchanged beweist nicht volle Profilunterstützung; Compatibility separat prüfen.
