# 14 – Kanonische Daten- und API-Verträge (A0)

**Status:** normative Zielspezifikation zur A0-Freigabe, keine implementierte API. Bestehende APIs bleiben gültig. **Einziger Definitionsort** für die hier genannten Typen und Funktionen. Andere Dokumente referenzieren diesen Vertrag; sie dürfen keine abweichenden Signaturen definieren. Anforderungen und Nachweise: [01](01_PRODUCT_REQUIREMENTS.md), [15](15_TRACEABILITY.md).

## 1. Regeln für alle Ergebnisse

Alle Quellspans sind TSourceSpan aus Core.Spans: nullbasierte halboffene UTF-16-Codeunit-Intervalle. Ein Span ist nur mit seinem passenden Source-Snapshot sinnvoll. Ein Tokenindex bezeichnet immer den vollständigen ursprünglichen Lexerstream einschließlich dessen einzigem EOF; keine segmentlokale Umnummerierung. Byteoffsets gehören ausschließlich dem IO-Adapter.

Neue Ergebnisobjekte besitzen Source-Referenzen, private Wertarrays und gegebenenfalls eigene Objektarenen; öffentlich nur read-only Properties, Count/Get-Methoden und Wertkopien. Ein Get liefert bei Records einen Wert, bei Syntaxelementen eine geliehene Referenz. Dynamische Arrays werden weder öffentlich als veränderliche Properties zurückgegeben noch vom Konstruktor unkopiert übernommen. Fehlgeschlagene Konstruktion überträgt kein Eigentum. Caller gibt jedes zurückgelieferte Ergebnisobjekt genau einmal frei.

Gewöhnliche ungültige Source, Config oder verweigerte Formatierung ergeben Diagnostics/Status, keine Exception. Ungültige API-Indizes, nil statt Pflichtobjekten, inkonsistente fremde Tokenstreams und nicht erfüllbare Allocation sind getrennte Programmier-/Systemfehler. „Keine Syntaxexceptions“ bedeutet nicht „alle Exceptions verschlucken“.

## 2. Vorhandene APIs und Diagnostics

Owner: vorhandene Units Core.Diagnostics, Lexer.Tokens/Scanner, Syntax.Nodes/Tree, Parser.Delphi. Unverändert:

~~~pascal
class function TDelphiLexer.Tokenize(const Source: string): TDelphiLexResult; static;
class function TDelphiParser.Parse(ALex: TDelphiLexResult): TSyntaxTree; static;
class function TDelphiParser.ParseExpression(ALex: TDelphiLexResult): TSyntaxTree; static;
class function TDelphiParser.ParseStatement(ALex: TDelphiLexResult): TSyntaxTree; static;
function TSyntaxTree.Serialize: string;
~~~

Diese qualifizierten Methodenköpfe dokumentieren Owner und bestehende Signaturen, keine alleinstehende zu kompilierende Unit. Lexerresultat wird während Parse geliehen; der Rückgabe-Tree besitzt unabhängig Source, Diagnostics und Arena. Root/Children sind geliehen und dürfen nicht separat freigegeben werden.

TDiagnostic bleibt das bestehende Record mit Code, Message, Severity, Span; TDiagnosticSeverity bleibt dsInfo/dsWarning/dsError. Keine zweite Diagnosticklasse. Bestehende LEX-/PAR-Codes behalten ihre Bedeutung. Neue Phasen verwenden stabile eigene Codes (CFG, FMT, IO); konkrete Nummern werden im jeweiligen kleinen Implementierungs-PR mit Tests registriert. Syntaxunsicherheit, unsupported und LimitReached sind unterscheidbare Gründe und nicht pauschal dsError.

Reihenfolge: im Tree zuerst ursprüngliche Lexerdiagnostics, danach Parserdiagnostics in deterministischer Entdeckungsreihenfolge. Formatterresultat übernimmt Inputdiagnostics in dieser Reihenfolge, danach eigene Diagnostics; Configdiagnostics werden vom aufrufenden Adapter separat angezeigt beziehungsweise als geordnete Vorstufe übernommen, nie doppelt angehängt. Vorläufige Diagnosen aus verworfenen Builderversuchen gelangen nicht ins endgültige Ergebnis.

## 3. Genau ein Parse-Ergebnis und Syntaxstatus

Owner: Syntax.Tree für Tree/Fakten, Syntax.Query für geliehene Rollenabfragen; Enumdefinitionen in Syntax.Kinds (append-only).

TSyntaxTree bleibt das einzige Source-CST-Parse-Ergebnis; kein TSourceParseResult und keine parallele Diagnosticsownership. Bestehende Source, Root, DiagnosticCount/GetDiagnostic und Serialize bleiben bestehen. Eine zukünftige additive Fassade:

~~~pascal
type
  TSourceParseMode = (pmFile, pmFragment, pmExpression, pmStatement);
  TParseContextKind = (pcUnknown, pcUnitDeclarations, pcMembers,
    pcStatements, pcTypeReference, pcExpression);
  TSyntaxIssue = (siIncomplete, siUnsupported, siContextUnknown,
    siMalformed, siLimitReached);
  TSyntaxIssues = set of TSyntaxIssue;
~~~

Additive Methode von TDelphiParser (im Einführungs-PR als overload deklarieren):

~~~pascal
class function ParseSource(const Source: string; Mode: TSourceParseMode;
  FragmentContext: TParseContextKind): TSyntaxTree; static;
~~~

FragmentContext muss außerhalb pmFragment pcUnknown sein. pmFragment mit pcUnknown ist ausdrücklich erlaubt und erzeugt vorläufige Token-/Direktivengruppierung ohne Grammatikfreigabe. Kein Core-Dateiendungsraten. pmFile erkennt unterstützte Dateiroots aus Syntax; unbekannter Root bleibt geschützt. Parse(ALex) bleibt bestehender Dateieinstieg; seine Verhaltenserweiterung gehört erst zum Root-Milestone.

TSyntaxIssues sind eine **Menge unabhängiger Feststellungen**, keine widersprüchlichen Statusbooleans:

| Issue | Bedeutung |
|---|---|
| siIncomplete | bekannte Produktion benötigt nicht vorhandene Teile; normale Missing-Recovery möglich |
| siUnsupported | vorhandene Syntax wird in diesem Scope nicht strukturiert verstanden |
| siContextUnknown | Eintritts-/Fortsetzungszustand nicht belegt, etwa nach unbekanntem Include |
| siMalformed | lokal im bekannten Kontext nachweisbare Verletzung |
| siLimitReached | Analyse bewusst begrenzt, keine Syntaxbehauptung |

Leere Menge bedeutet vollständig nur für die betreffende Rolle **und** den belegten Kontext, nicht semantische Kompilierbarkeit. Ein Opaque-Kind erhält mindestens unsupported oder context_unknown. Ein SyntaxFragment erhält mindestens incomplete, unsupported oder context_unknown. Ein Error-Kind ist mit lokal belegtem malformed verknüpft. LimitReached verlangt Schutz und ein erklärendes Diagnostic. Fehlende Tokens kennzeichnen incomplete; ein offenes EOF-Fragment ist nicht automatisch malformed.

Tree besitzt eine unveränderliche Fakttabelle über seine Elemente; externe Queries nehmen Tree + geliehenes Element. Kein mutable Safetyflag im Knoten. LocalIssues und SubtreeIssues werden getrennt abgefragt (SubtreeIssues ist die Vereinigungsmenge über Nachfahren). Rollenqueries umgehen den Tree nicht und halten keine Referenz nach dessen Freigabe. Ein Status kann Kontextunsicherheit ausdrücklich bis zu Nachfolgern übertragen, auch wenn deren lokale Form vollständig aussieht.

## 4. Physische Rollen und Conditional-Fakten

TSyntaxNode/Token bleiben generisch. Kindnamen für neue Formen sind semantische Bezeichnungen; der einführende PR vergibt append-only Enumwerte. Falls M2.8 übernommen wurde, bleibt skConditionalDirectiveRegion ordinal 56 erhalten und übernimmt die ConditionalRegion-Rolle; kein zweiter gleichbedeutender Region-Kind.

Die **verbindlichen Rollenformen** und deren Tokenownership stehen ausschließlich in [04](04_SOURCE_CST.md). Ein späterer Rollenquery liefert Rolle, Kind, Tokenintervall und geliehenes Element, nie nachgeparsten Source-Text. Metadaten zu einer ConditionalRegion:

| Feld | Typ / Vertrag |
|---|---|
| Context | TParseContextKind |
| Entry | TContextState, bekannter oder explizit unbekannter Zustand |
| Branches | Original-Branchreihenfolge; jeder Branch besitzt einen Body-Tokenbereich |
| EachBranchExit | TContextState + TSyntaxIssues + exact-consumption-Befund |
| JoinedExit | nur bekannt, wenn sämtliche möglichen Alternativen den Kontextvertrag erfüllen |

TContextState ist ein unveränderliches Wertmodell (Owner Syntax.Directives/Query, gebaut vom Parser): ContextKind, Section (interface/implementation/none), ExpectedRole, SeparatorState, OpenOwnerKinds (geordnet), MemberSectionAnchor (Originaltokenindex oder -1), Continuation (closed/list-continuation/unknown), GrammarEffects (none/known-structural/unknown) und IsKnown. ExpectedRole/SeparatorState beziehen sich auf die finite Kontextregistrierung aus 05; keine frei interpretierbaren Textlabels in der Implementierung. Die konkreten Enums werden je Kontext nur um dessen benötigte Fälle erweitert. Keine Defines, Symboltabellen oder Compiler-Auswertungszustände.

Zustandsvergleich ist strukturell über diese Felder; keine Pointergleichheit. Ein Branch darf vollständige Produktionen enthalten, obwohl sich ein nachfolgender Zustand nicht zusammenführen lässt (etwa unterschiedliche Membersection-Anker). Dann bleibt JoinedExit unbekannt, nachfolgende Struktur vorläufig und Editfreigabe verweigert. „structurally complete“ ist ein abgeleiteter Befund: Issues leer, Entry bekannt, Window exakt konsumiert, kein Missing und Kontext-Exit erfüllt. Kein zweites Branchstatus-Enum.

## 5. Bounded Tokenansicht

Owner: neue Parser.TokenWindow; bestehender Parser.Reader bleibt kompatibel. Der Parser besitzt/borrowed die Ansicht, die nur während der geliehenen Lexer-Lifetime lebt.

~~~pascal
type
  TWindowRead = record
    IsEnd: Boolean;
    OriginalIndex: Integer;
    Token: TDelphiToken;
  end;
~~~

TTokenWindow erhält ALex und [First, AfterLast), wobei 0 <= First <= AfterLast <= IndexOfOriginalEOF. Methodenrollen:

| Operation | Ergebnis / Verhalten |
|---|---|
| Position | nächster roher Originalindex, monoton in [First, AfterLast] |
| PeekSignificant(Lookahead >= 0) | TWindowRead, überspringt nur bekannte gewöhnliche Trivia innerhalb des Fensters |
| AtEnd | kein signifikanter Token im Fenster; eventuell liegen noch rohe Trivia vor |
| ConsumeSignificant | verarbeitet führende Trivia und einen echten Token bis maximal AfterLast |
| ConsumeRemainingTrivia | verarbeitet nur die noch im Fenster liegenden gewöhnlichen Trivia |

Negative Lookaheads sind API-Missbrauch; bestehender Reader behält sein altes Clamping. Bei Fensterende gilt IsEnd=True, OriginalIndex=AfterLast; Token ist undefiniert und darf nicht gelesen/serialisiert werden. **Kein virtueller TDelphiToken, kein Missing-EOF und kein zusätzliches Original-EOF.** Der Dateiroot konsumiert das einzige echte EOF außerhalb aller Teilfenster. Leere/Trivia-only-Fenster bleiben exakt zuordenbar; AtEnd allein beweist nicht exact-consumption, dafür muss Position=AfterLast gelten.

Der zentrale Parser-Consumer erzeugt Originalblätter. Die Ansicht kann Indizes/Verbrauch liefern, besitzt keine eigene Syntaxarena. Jeder tentative Versuch hat einen eigenen monotonen Windowcursor; der äußere bereits committete Cursor bleibt bis zur Übernahme unverändert. Scheitert der Versuch, werden sein Cursor, Nodes, Arenaeinträge und Diagnostics bis zum Buildercheckpoint verworfen. Danach darf ein neues Fenster denselben noch nicht committeten Bereich einmal als Fragment übernehmen. Kein Zurücksetzen bereits committeter Blattownership. Index-/Probephasen erzeugen gar keine Blätter. Pro Besitzer ist höchstens ein solcher Grammarversuch plus ein konservativer Fallback erlaubt; kein unbeschränktes Backtracking. Commit registriert das Originalintervall genau einmal und rückt den äußeren Cursor bis AfterLast vor.

## 6. Tokengebundene Trivia-Slots und Freigabe

Owner: Formatting.Safety; Spans/Identität aus passendem Tree/Source. Ein Slot ist die Lücke zwischen zwei aufeinanderfolgenden **Ankertokens**, also allen Originaltokens außer tkWhitespace/tkNewLine. Kommentar, Directive, Unknown und EOF sind Anker. Links vor dem ersten Anker gibt es den Index -1 als BOF-Sentinel ohne Originalblatt; rechts ist stets ein echter Anker, spätestens EOF.

Identität: (SourceIdentity, LeftOriginalIndex, RightOriginalIndex). SourceIdentity ist ein String aus 64 uppercase ASCII-Hexzeichen: SHA-256 der UTF-16-Codeunits, je Codeunit Lowbyte dann Highbyte, ohne BOM und ohne Ersatz fehlerhafter Surrogate. Vor Anwendung ist zusätzlich exakte Source-Gleichheit zu prüfen, ein Hash ist kein alleiniger Gleichheitsbeweis. Keine neue allgemeine Sourceklasse ist für den ersten Slice erforderlich.

SlotSpan reicht vom linken Ankerende (BOF=0) zum rechten Ankerstart. In ihm dürfen nur echte Whitespace-/Newline-Tokens liegen; ein leerer Slot [p,p) ist zulässig. Ein Slot ist unteilbar für Regelentscheidungen. Ankergrenzen, Eigentümerrollen, Original-EOL und dokumentierte Kommentarbindungen sind Teil der Safetyprüfung.

~~~pascal
type
  TFormatRefusalReason = (frOpaque, frSyntaxError, frMissing,
    frDirectiveBoundary, frConditionalFragment, frUnresolvedInclude,
    frUnknownContext, frUnsupportedConstruct, frLexicalError,
    frUnsupportedWhitespace, frCommentAnchor, frEditConflict,
    frValidationFailure, frConfigPolicy, frResourceLimit);
  TFormatRefusalReasons = set of TFormatRefusalReason;
~~~

TSlotDecision (Owner Formatting.Safety) liefert Slotidentität/Span, AllowWhitespace:Boolean und Reasons:TFormatRefusalReasons. AllowWhitespace=True genau bei leerer Reasons-Menge **und** positiv belegten S0-Regelvorbedingungen. Jeder nicht untersuchte Slot ist abgelehnt, nicht implizit freigegeben. TProtectedRange enthält Span, Reasons und BoundaryPolicy=closed-both-sides; auch Einfügen bei Start/End und bei zero-width Barrieren ist verboten. Schutzintervalle dienen Reporting/Abfragen, Slotentscheidungen sind editautoritativ.

## 7. TextEdit – einzige Definition

Owner: neue Core.TextEdits; kennt weder Syntax noch Config/IO. S0 hat ausschließlich Whitespaceedits; Capitalization ist ein späterer separater Vertrag und kein heute freigegebener Enumfall.

~~~pascal
type
  TTextEdit = record
    Span: TSourceSpan;
    NewText: string;
    RuleId: string;
    LeftOriginalIndex: Integer;
    RightOriginalIndex: Integer;
  end;
~~~

SourceIdentity gehört zur gesamten Editmenge/FormatResult, nicht redundant in jedes Edit. Span muss exakt dem freigegebenen SlotSpan entsprechen; NewText darf nur freigegebene Space-/Tab-/EOL-Zeichen enthalten. Unveränderte Slots erzeugen kein Edit. Kein Kommentar-/Direktiven-/Literaltextedit und kein neues Pascallexem. ProtectedRange- und Snapshotprüfung gilt auch bei Länge null.

Kanonische Sortierung nach Span.StartOffset; maximal ein Edit je Slot. Zwei unterschiedliche Edits am gleichen Offset oder überlappende Spans sind Konflikt. Identische Entscheidungen werden dedupliziert; abweichende Entscheidungen zuerst nach der expliziten Regelpriorität aufgelöst oder die ganze Editmenge verweigert. Keine zufällige Dictionaryreihenfolge und keine nachträgliche stille Überschreibung. Layout erzeugt eine finale Slotentscheidung, Edits werden einmal rückwärts angewendet.

## 8. FormattingOptions

Owner: Formatting.Options, ohne NativeReader-/IO-Abhängigkeit. Config.Schema/Effective und Engine benutzen diese DTOs, niemals umgekehrt. TFormattingOptions ist immutable und wird vom Builder vollständig validiert. S0-Datenfelder:

| Feld | Domäne / Bedeutung |
|---|---|
| SafetyProfile | ausschließlich S0 im ersten Slice |
| AssignmentSpacing | AsIs / None / Before / After / Both; interne Regelwerte, keine Behauptung nativer Value-Namen |
| EolPolicy | Preserve; erzeugt kein systemabhängiges Default-EOL |
| Compatibility | not-requested / verified-subset / partial / unverified |
| Provenance je effektivem Feld | origin, nativeKey falls vorhanden, rawValue, sourceIdentity/path, targetVersion, evidenceIds |

AssignmentSpacing wirkt auf die zwei horizontalen Slots an :=: AsIs erhält beide; None setzt beide auf leer; Before setzt links genau U+0020 und rechts leer; After umgekehrt; Both setzt beide auf genau U+0020. Vorhandene Tabs im freigegebenen Slot werden dabei durch diesen ausdrücklich gewünschten Wert ersetzt. Ein EOL-/geschützter Slot wird nie für die Option freigegeben.

Eine effektive Einstellung ist entweder explizit intern, aus belegtem nativem Wert, aus explizitem Override oder aus verifiziertem versionsgebundenem Default. Fehlende benötigte Werte sind ein Optionsfehler. Keine automatische Defaultbildung aus dem Host. Nicht beanspruchte Felder können für S0 entfallen; später erweitern, statt ein universelles Optionsobjekt vorab zu erfinden. Kein eigenes Editor-/Tabdefault überschreibt native Werte stillschweigend.

## 9. FormattingResult und Engine

Owner: Formatting.Engine; Referenzen zu TTextEdit aus Core.TextEdits, Safetywerten aus Formatting.Safety, Optionen aus Formatting.Options.

~~~pascal
type
  TFormatOutcome = (foUnchanged, foChanged, foPartiallyChanged, foRefused);
~~~

TFormatResult ist immutable, vom Caller zu besitzen, und bietet genau:

| Read-only Mitglied | Vertrag |
|---|---|
| OriginalSource / SourceIdentity | exakt angewendeter UTF-16-Snapshot und Identität |
| FormattedText | verifizierte Ausgabe; bei refused exakt OriginalSource |
| Outcome | TFormatOutcome |
| Compatibility | derselbe unabhängige Kompatibilitätsstatus wie effektive Optionen |
| EditCount / GetEdit(Index) | kanonische tatsächlich angewendete Edits als Wertkopien |
| DiagnosticCount / GetDiagnostic(Index) | TDiagnostic als Wertkopien |
| ProtectedRangeCount / GetProtectedRange(Index) | TProtectedRange als Wertkopien |
| RefusalReasons | Gesamtablehnung/-einschränkung als TFormatRefusalReasons |

~~~pascal
function FormatText(const Source: string;
  Options: TFormattingOptions): TFormatResult;
~~~

Options wird während des Calls geliehen; das Ergebnis speichert keine lebende Abhängigkeit darauf, Tree oder LexResult. Ein gültiges Outcome ist nicht gleich vollständige RAD-Kompatibilität.

foUnchanged: erfolgreiche Prüfung, kein Edit. foChanged: sämtliche für den expliziten Slice angeforderten Änderungen erfolgreich. foPartiallyChanged: sichere Änderung plus ausdrücklich gemeldete ausgelassene angeforderte Regionen/Regeln; **im ersten S0-Slice nicht erzeugt**. foRefused: fehlerhafte Eingabe/Policy/Invariante, keine Edits, Ausgabe=Input. Partial ist kein Weg, fehlgeschlagene Verifikation zu verschweigen.

## 10. Config-Import und effektive Optionen

Owner: Config.Native für Import, Config.Schema für versionsgebundene Evidenz/Katalog, Config.Effective für Optionsbildung. Config-Einstellungen verwenden Core.Diagnostics und Formatting.Options, nie Engine/Syntax/Parser/IO.

~~~pascal
type
  TConfigImportState = (cisValid, cisInvalid);
  TOptionRecognition = (orKnown, orUnknown, orInvalid, orAmbiguous);
  TOptionRelevance = (relDelphi, relIrrelevantVerified, relUnknown);
  TOptionSupport = (osVerified, osPartial, osUnsupported, osUnverified);
  TConfigPolicy = (cpStrict, cpLenient);
~~~

TNativeProfileResult ist ein immutable owned Objekt mit ImportState, SourceIdentity, ProfileSource (nur Label), ObservedSchemaVersion (nicht Produktversion), TargetVersion (leer wenn unbelegt), EntryCount/GetEntry und DiagnosticCount/GetDiagnostic. Jeder Entry enthält Rohname/-wert/-typ, geordnete Position und Originalort, Recognition, Relevance sowie EvidenceIds. Rohbytes werden einmal im Ergebnis gehalten; unbekannte Elemente/Attribute müssen referenzierbar bleiben. Support gehört **nicht** zu syntaktischer Recognition, sondern zur abgefragten Capability (Zielversion, Key, Wert, Syntaxfeature, Regelumfang).

~~~pascal
function LoadNativeProfile(const Bytes: TBytes;
  const ProfileSource: string): TNativeProfileResult;
~~~

Inputarrays werden nur geliehen, erforderliche Daten kopiert. Dateipfade werden nicht geöffnet, XML-Assembly-/Typewerte niemals geladen/ausgeführt.

Config.Effective besitzt TEffectiveOptionsResult mit Succeeded, Options (geliehen aus diesem Ergebnis), Compatibility und Diagnostics. Erfolg besitzt genau ein TFormattingOptions; bei Fehlschlag Options=nil. Der Caller besitzt das Ergebnis und nicht Options separat. BuildEffectiveOptions(Profile, ExplicitOverrides, TargetVersion, Policy) ist die einzige Builderrolle; exakte Delphi-Argumenttypen für typisierte Overrides werden erst im C2-PR definiert, **keine zweite heute normative Funktionssignatur**. Profile und Overrides sind geliehen. Config.Native und Config.Schema erzeugen keine impliziten Formatter-Defaults.

## 11. Verifikation und Fingerprints

Owner: Formatting.Verification (darf anfangs als privater Teil von Engine/Edits implementiert sein); Algorithmus und Pipeline in [06](06_FORMATTER.md). Zwei kanonische Fingerprintrollen, beide versioniert:

- LexicalSignatureV1: geordnete (TokenKind, exakter UTF-16-Text) aller Tokens außer tkWhitespace/tkNewLine; einschließlich Kommentare, Direktiven, Unknown und genau EOF. Keine offsets/Trivia. Vergleich via vollständiger Sequenz, ein Hash allein ist kein Gleichheitsbeweis.
- SyntaxFingerprintV1: geordnete (Kind, Child-Rollenfolge, strukturierte Operator-/Delimiter-/Keyword-/Name-/Literallexeme, LocalIssues, Missing.ExpectedText)-Ereignisse eines vollständig freigegebenen Besitzers. Keine Source-Spans, Tokenindizes oder ordinary Trivia; Kommentare/Direktiven durch LexicalSignature und Ankervergleich separat erfasst. Rohlexeme bleiben exakt, kein freies Casefolding.

Die implementierende Rolle muss die in 04 angegebenen Rollen deterministisch abfragen; fehlende Rolle/unknown fingerprint version führt zur Verweigerung. Lokale Fingerprints werden über gemappte Originaltoken-Korrespondenz verglichen. Kein neuer Compiler-/Semantikbeweis behauptet.
