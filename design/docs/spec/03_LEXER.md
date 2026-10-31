# 03 – Lexer

Verträge: LEX-01 bis LEX-04, API-02; APIs nur in [14](14_CONTRACTS.md). Bestehende Lexer.Scanner/Tokens/Keywords bleiben Ausgangsbasis. Kein Rewrite, keine Direktiven-/Includeauswertung und keine Genericentscheidung.

## Tokenisierung und Recovery

Genau ein EOF mit Span (Length(Source),0). Alle anderen Tokens haben positive Länge, decken den String lückenlos/überlappungsfrei ab und werden nie gefiltert. Source wird referenzgezählt gehalten, Token enthält nur Kind/Span; TokenText materialisiert auf Bedarf. Reentrant ohne globale mutable Zustände.

Scanner priorisiert CR/LF/CRLF, horizontale Trivia, Strings, Kommentare/Direktiven, Numerale, Identifier/escaped Identifier, maximal gültige Symbole und unknown. Literale/Kommentare dürfen eingebettete Direktiventexte nicht zu Tokens machen. CRLF ist ein Newline-Token; Newlines innerhalb blockartiger Tokens bleiben darin und werden nicht dupliziert.

| Kategorie | Positive Mindestfälle | Negative/Recovery / Nachweis |
|---|---|---|
| Identifier | ASCII/BMP, underscore, escaped keyword, contextual words | RTL-IsNumber-/Unicodeklassen und Supplementary-Zeichen per 12.3-Probe; isolierte Surrogate exakt erhalten |
| Strings | doubled quotes, leer, Quote-Runs, multiline 3/5/7+ mit passenden Closern | ordinary newline/EOF: begrenzte Recovery; multiline EOF: ein Token plus Diagnose; keine Inhalts-/Indentnormalisierung |
| Numerale | decimal/hex/binary, separator, fraction/exponent, range 1..10 | incomplete prefix/exponent/separator; keine Typ-/Wertauswertung außer bestehender CharCode-Grenzprüfung |
| CharCode | decimal/hex und erlaubte Separatoren | binary/overflow/missing digits nach Compilerfixture |
| Kommentare | line, brace, paren-star, crossed closer | eigener Closer beendet Block; anderer Stil inert, bestehende Compilerbelege erhalten |
| Direktiven | beide echten Kommentarformen mit unmittelbarem Dollarzeichen | ungeschlossen: Token bis EOF + Diagnose; Lookalikes in Kommentaren/Strings inert |
| Symbole | assignment, relational, range, alternative square brackets | maximal gültige Länge; Generic-Tokens neutral lassen |
| Controls/EOL | CR/LF/CRLF, Space/Tab, NUL und weitere Controls lossless | Klassifikation nicht automatisch Löschfreigabe; S0 schützt andere Controls |

Fehlerhafte UTF-16-Codeunits bleiben unverändert einschließlich innerhalb Literalen/Kommentaren. Gültige Surrogatpaare sind kein Encodingfehler; sprachlich nicht unterstützte Zeichen bekommen unterscheidbare Diagnostics. Datei-BOM/Codec ist nicht Lexeraufgabe.

## Unveränderte Baseline versus offene Sprachregeln

Der bestehende Scanner klassifiziert U+0000..U+0020 außer CR/LF als whitespace und verwendet RTL-IsLetter/IsNumber für Identifier. Das bleibt bis zu belegtem eigenem Änderungs-PR bestehen; es ist kein vollständiger 12.3-Nachweis. Der Formatter darf daraus nicht die sichere Entfernung beliebiger Controls folgern.

Bestehende CE-Update-1-Belege zu Quote-Runs, crossed comments, Numeric-Memberpunkt und CharCode stehen historisch in docs/DECISIONS.md und M1_STATUS.md. Sie sind kein 12.3-Ergebnis. Sprachexperimente E-COMP/ E-LEX in 11 ergänzen sie. Magnitude, Constant Evaluation, multiline Stringwerte und Typechecking gehören nicht in Tokenize.

## Qualitätsgate

T-LEX: exakte Kind-/Text-/Span-/Diagnosticsequenzen und Coverage, Kopier-/Lifetimeverträge, wiederholte Ausführung und feste Fuzzseeds. 40 vorhandene Lexer-Methoden unverändert erhalten; neue Bugs mit Negativ-/Regressionstest. O(n)-Ziel durch monotone Scans/beschränktes Lookahead, keine Timingflakiness als Unit-Test. Ressourcenlimits müssen progress-/verlusttreu terminieren. Benchmarks nach Korrektheitsgate.

Bei lexikalischer Beschädigung können sichtbare IFEND-Texte in einem String-/Kommentar-Token liegen. DIR-05: keine zweite überlappende Tokenisierung; der Source-CST darf deswegen unvollständig bleiben.
