# 07 – Native RAD-Profile, Relevanz und Kompatibilität

Anforderungen CFG-01 bis CFG-07/FMT-10; alle DTOs/APIs nur [14](14_CONTRACTS.md). [ADR-003](../adr/ADR-003-native-config.md). Keine geratenen nativen Schlüssel/Defaults/Prioritäten.

## Beobachtete echte Daten

Historischer Review hat die mitgelieferten Profile aus Studio/23.0/bin/config eingelesen. [Inventar](../../review-evidence/native-profile-inventory.json): je 158 aktive direkte Option-Elemente, davon 84 DelphiFormatter.*, 72 CppFormatter.* und 2 Formatter.*. Root TgConfig, Schemaattribut Version=3. Formatter.config entspricht Default. Die vollständigen SHA-256 stehen im Inventar; Dateien selbst werden nicht proprietär mitgeliefert.

Beobachtete Delphiwerte umfassen TabSize/IndentSize/UseTabs in DelphiEditor, AssignSpaces, IndentCompilerDirectives, NumOfEmptyLinesAroundCompilerDirectives und CompilerDirectivesCapitalization. Das sind **ältere lokale Beispieldaten**, kein Schema-/Verhaltensbeweis für 12.3. Root/Assemblies/Comments/Typ-/Kategorieattribute gehören zur Importinventur; Version=3 ist keine RAD-Produktversion.

## Getrennte Verarbeitung

1. **NativeReader:** Byteencoding/syntaktische Struktur mit sicheren Limits, Rohbytes/Eintragsreihenfolge/Originalorte und unbekannte Elemente erhalten. DTD/externe Entities untersagen, nie Assemblies/Typen aus Profil laden, kein string.Replace-Parser.
2. **Schema/Recognition:** echtes versioniertes Schema erkennen; unknown/invalid/ambiguous getrennt. Syntaktisch gültiges fremdes XML ist kein gültiges Profil.
3. **Relevance:** relDelphi, belegte relIrrelevantVerified oder relUnknown. Prefix allein ist kein universeller Wirkungsbeweis; echte Registry-/Experimentbelege erforderlich.
4. **Capabilities:** pro Zielversion/Key/Wert/Syntaxfeature/Regelumfang verified/partial/unsupported/unverified. Geparst bedeutet nicht ausführbar.
5. **EffectiveOptions:** explizite interne Werte oder belegte native Zuordnung/Defaults plus Provenance; benötigte fehlende Werte sind Fehler.

Native Tab-/Indentwerte bleiben native Werte. Eigene CLI-/Editoroverrides sind separate explizite Eingänge, die nur bei dokumentierter Priorität wirken und Kompatibilitätseinfluss ausweisen. Bis E-TABS beantwortet ist, bei gleichzeitig konkurrierenden nativen/eigenen Werten verweigern statt frei Vorrang wählen. Unbenötigte Overrides nicht anwenden.

## Strict-/Lenient-Policy

| Fall | Strict | Lenient |
|---|---|---|
| malformed/invalides Schema/Encoding, mehrdeutige Konflikte | Import/Optionsbildung scheitert | ebenso; kein Reparieren |
| belegte C++-/UI-Irrelevanz | sichtbar inventarisieren, nicht allein deswegen blockieren | ebenso |
| unbekannte mögliche Delphiwirkung/Relevance unknown | verweigern | nur explizite akzeptierte Supportlücke mit sichtbarer Warnung und partial compatibility |
| bekannte relevante Option, unsupported/unverified wirksamer Wert | verweigern | nur ausdrücklicher opt-in für genau diese Abweichung |
| bekannter belegter neutraler Wert für konkreten Feature-/Regelscope | kein Blocker wegen fehlender ungenutzter Regel | ebenso; Neutralitätsbeleg nennen |
| fehlender benötigter Wert/Default unbekannt | Fehler | ebenfalls Fehler, kein geratener Ersatz |
| verified Wert und alle Vorbedingungen erfüllt | erlaubte Wirkung | ebenso |

Duplikate nicht still „letzter gewinnt“. Rohreihenfolge erhalten; ohne versionsgebundenen E-CONFIG-Beleg ambiguous. Gleiche doppelte Werte sind erst nach explizitem nachgewiesenem Schemaentscheid akzeptierbar. Typinvalidität, invalides Profil oder unaufgelöster Konflikt sind keine Lenient-Supportlücke.

Auch lenient darf keine Safetybarriere umgehen. Die Option kann aus Sicht des Originals gültig und von S0 bewusst nicht ausführbar sein. Der Benutzer bekommt Key/RawValue/Quelle/Zielversion/Supportgrund. Produktresultat Compatibility ist getrennt vom Changed-/PartialText-Outcomestatus.

## Registry und native Parität

Maschinenlesbare Registry erst in C1/C2 aus Echtdaten erstellen: nativeKey, beobachteter Typ/Wertedomäne, schema evidence, relevance evidence, target RAD/Formatter version/hash, Capability pro Wert/Feature, verifizierter Default oder unknown, RuleIds, OracleFixtureIds. Kein Platzhaltereintrag als echte Option. Ein Testprofil ohne NativeReader kann S0 testen, aber keinen Configsupport belegen.

Oracleexperimente stehen konkret in [11](11_OPEN_QUESTIONS.md): Zielversion/Exportdeltas, Defaults/Duplikate/Unknown, native Tabs versus IDE/CLI, Optioneninteraktionen, Direktiven/Includeverhalten, Case, Bytes/EOL. Originalformatter ausschließlich lokal auf Kopien; Profil-/Input-/Output-/EXEhash, Kommando, Arbeitsverzeichnis, explizites Encoding, Umgebung und Wiederholungen speichern.

Kompatibilitätsclaim pro (RAD-Version, Formatterhash, Profilhash, Key, Wert, Syntaxfeature, Regelscope). Textlayout- und Byteparität separat. Dokumentierte Optionsgruppen sind Evidenz für den fachlichen Umfang, kein vollständiges Schema. Bei nicht compilierbarer Quelle ist Originalausgabe kein Safety-Orakel.

CLI entscheidet explizite Profile/Pfade. Automatische Suchpfadparität erst nach eigenem Experiment, keine BDS-Version hardcoden. Ohne verlässliche Zielversion nur unverified, niemals aus Ordnernamen auf 12.3 schließen.
