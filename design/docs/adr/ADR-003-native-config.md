# ADR-003 – Native Profile: Import, Relevanz, Capabilities und Herkunft

**Status:** A0-Entscheid zur Reviewfreigabe. **Befunde:** R-07/R-08/R-09.

## Entscheidung

NativeReader, versionsgebundene Registry und effektive Optionsbildung sind getrennt. Daten-/APIdefinitionen nur 14, Policy/Beobachtungen 07. Recognition ist nicht Support; Delphi-Relevance ist eine eigene Evidenzentscheidung. Capabilities gelten pro Zielversion/Key/Wert/Feature/Regelscope.

Lokal beobachtete native TabSize/IndentSize/UseTabs sind native Werte, keine ausschließlich eigenen Editoroptionen. Eigene Overrides sind separate Eingänge mit Provenance und nur belegter Priorität. Version=3 im Profil ist kein Beleg einer RAD-Produktversion. Kein Default oder Vorrang aus Dateiendung/Pfad raten.

Strict blockiert unknown mögliche Wirkung und unsupported angeforderte Wirkung; belegte irrelevante C++-/UIeinträge bleiben sichtbar ohne unnötigen Block. Neutralität eines Werts muss für den Scope belegt sein. Lenient akzeptiert nur explizite Supportabweichungen, niemals invalides/ambiges Profil oder unbekannte benötigte Defaults. Keine Safetyumgehung.

## Begründung / verworfene Alternativen

Alle unbekannten Einträge pauschal gleich zu behandeln würde reale gemischte Profile unnutzbar machen oder relevante Wirkung still ignorieren. Ein XMLimport allein beweist keine Formatierung. Ein einzelnes älteres Profil belegt weder 12.3-Schema noch Defaultverhalten. Alle Defaults vor dem ersten internen Formatter zu implementieren ist unnötig: S0 darf explizite eigene Optionen ohne Nativeclaim nutzen.

Echte Profile enthalten Typ-/Assemblyangaben; diese nur als Daten lesen. Kein Assemblyladen, DTD-/Entity-/externes IO im Reader. Engine hängt nur von effektiven Formatting.Options ab, nicht vom NativeReader.

## Folgen / Verifikation

CFG-01 bis CFG-07/FMT-10 → T-CONFIG/T-RELEVANCE/T-EFFECTIVE/T-ORACLE. E-CONFIG/E-TABS/E-ORACLE/E-CONDITIONAL/E-CASE/E-BYTES/E-LAYOUT/E-XML prüfen die verbleibenden empirischen Fragen. Lokale Original-EXE nur auf Kopien, keine proprietäre EXE im Repo, keine behauptete 100%-Parität.
