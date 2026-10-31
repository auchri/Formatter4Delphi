# 04 – Physischer Source-CST und Child-Rollen

Verträge: CST-01 bis CST-10, DIR-01/DIR-04, API-02. Status-/APIdefinition ausschließlich [14](14_CONTRACTS.md); Kontextregeln [05](05_DIRECTIVES.md).

## Ein Baum, einmalige Originalblätter

Der Tree besitzt ein flaches Arena; Child/Root-Referenzen sind geliehen. Kein DAG, keine mehrfachen Parents, keine Branchkopien. Alle Originaltokens einschließlich Trivia/EOF liegen genau einmal in Depth-first-Blattreihenfolge; Serialize traversiert diese Blätter. Missing sind zero-width, index -1, tragen keinen Source-Text bei. Elternspan ist die geordnete Kinderhülle einschließlich Trivia. Leere Knoten/Missing werden vor noch unzugeordnetem Trivia verankert; Geschwister überlappen nicht.

Tokenintervalle sind [FirstOriginalIndex, AfterLastOriginalIndex). Ein Grouper besitzt nur Intervalle/Werte. Nur der zentrale Parser-Consumer erzeugt/registriert Originalblätter. Tentative Versuche nutzen Buildercheckpoints für Arena/Childliste/Diagnostics; ein verworfener Versuch hinterlässt kein finales Blatt, keine orphan Arenaelemente und keine leaked Diagnostics.

## Rollenregister

Dieses Register ist der einzige normative Ort für Child-Rollen. Rollenqueries dürfen bestehende direkte Blatt-/Knotenformen interpretieren; keine pauschale Neuschichtung vorhandener Bäume. Neue Rollen sind additiv; jeder featurebezogene PR pinnt Kindnamen/Ordinals und exakte positive/negative Shapes. Notation: ? optional, * Liste, + nichtleer. Alle Keywords/Delimiter/Operatoren/Separatoren sind Originalblätter; sie sind unten nur zugunsten der Rollen abgekürzt. Eine Rolle kann als Blattintervall statt neuer Wrapper realisiert sein, wenn die Query ohne Source-Reparse eindeutig ist.

| Shape-ID | Konstrukt | Geordnete semantische Rollen und Tokenbesitz |
|---|---|---|
| N-ROOT | File/Expression/Statement/FragmentRoot | Construct(s), TrailingFragment?, TrailingTrivia, einziges echtes EOF; File enthält Unit/Program/Library/Package oder geschützte unbekannte Source |
| N-UNIT | Unit | Header(keyword/name/semicolon), InterfaceSection, ImplementationSection, Initialization?, Finalization?, Terminator(end/dot); vorhandene direkte Sectionmarker dürfen als Rollen gelesen werden |
| N-USES | Uses/Requires/Contains | Keyword, Item+ getrennt durch eigene Kommas, Semicolon; Item=(QualifiedName, InFilename?) |
| N-DECL | Const/Var/Threadvar/Resourcestring | SectionKeyword, Declaration*; Declaration=(Names, Type?, Initializer?, Modifier*, Semicolon); RHS-Operator bleibt eigenes Blatt |
| N-TYPE | TypeSection/TypeDeclaration | SectionKeyword, TypeDeclaration*; Declaration=(Name, GenericParameters?, Equals, RHS, Semicolon); RHS kann Conditional oder Fragment sein |
| N-AGG | Class/Record/Object/Interface/Dispinterface/Helper | Flavor/Modifier*, Ancestors?, InterfaceGuid?, TargetType?, Member* oder VisibilitySection*, End; Anker vor erster Visibility ist explizit/default-unresolved |
| N-MEMBER | Visibility/Field/ClassMember/Operator | Visibility=(strict?, marker, members*); Field=(Names, Colon, Type, Modifier*, Semicolon); ClassPrefix/OperatorName separat, nicht als globale Routine deuten |
| N-ROUTINE | Routine/Method | Header, Directive*, LocalDeclaration*, Body?, FinalSemicolon?; Header=(Flavor, QualifiedName, GenericParameters?, Parameters?, ReturnType?, HeaderSemicolon); für reine Methode Body abwesend; Headersemicolon bleibt Header, Bodysemicolon Routine |
| N-PARAM | ParameterList/ParameterGroup | Open, Group* mit Listensemikola, Close; Group=(Modifier?, Names mit Kommas, Colon, Type, Default?); Propertyindex-Klammern haben eigene Rolle, kein IndexExpression |
| N-PROP | Property | Keyword, Name, IndexParameters?, Colon/Type?, Specifier*, Semicolon, DefaultMarker?; redeclaration darf Type fehlen; jeder Specifier besitzt sein Keyword und Wert; trailing default besitzt zweites Semicolon |
| N-TREF | Qualified/GenericTypeReference | NameSegment+ mit Punkten; Segment=(Name, TypeArguments?); TypeArguments=(OpenAngle, TypeReference+ mit Kommas, CloseAngle) |
| N-GPARAM | GenericParameterList/Constraint | OpenAngle, ParameterGroup+ mit Separatoren, CloseAngle; Group=(Names, ConstraintList?); Constraint=(Flavor oder TypeReference); keine Symbolauflösung |
| N-TFORMS | Array/Set/Pointer/ClassOf/File/Enum/Subrange | Array=(array, Bounds?, of, ElementType); Set=(set, of, BaseType); Pointer=(caret, Target); ClassOf=(class, of, Target); File=(file, of/Type?); Enum=(open, Member+ mit value?, close); Subrange=(Low, RangeOperator, High) |
| N-PROCTYPE | Procedural/ReferenceType | reference-to?, Flavor, Parameters?, ReturnType?, of-object?, CallingConvention*, Directive*; nicht als Routinebody |
| N-NEST | Nested/VariantTypes | NestedDeclaration* als reguläre Rollen; Variant=(case, Tag/Type?, of, VariantArm*); Arm=(Labels, Colon, Open, Field*, Close); fehlendes end schützt Besitzer |
| N-ATTR | Attributes | OpenBracket, Attribute+ mit Kommas, CloseBracket; Attribute=(QualifiedType, Arguments?); eigener Kontext statt Set/Index |
| N-BLOCK | Block/StatementList | Block besitzt begin/end und Listenseparatoren; bestehende direkte Statementkinder bleiben; StatementList besitzt seine Separatoren, nie das end des Aufrufers |
| N-IF | If | if, Condition, then, ThenStatement, else/ElseStatement?; nächstes ungetrenntes else bindet nächstem offenen if |
| N-LOOP | For/ForIn/While/Repeat/With | Counter/inline Declaration?, Start/Limit/Direction oder Collection, Body; while=(Condition, Body); repeat=(List, until, Condition); with=(DesignatorList, do, Body) |
| N-CASE | Case | Selector, of, Branch* mit Separatoren, ElseList?, end; Branch=(LabelList mit Range?, Colon, Statement) |
| N-TRY | Try/ExceptionHandler/Raise | try List finally List end oder try List except Handlers/ElseList end; Handler=(on, Variable?, Type, do, Statement); raise=(Object?, at/Address?) |
| N-STMT | Assignment/Call/Label/Goto/Asm/InlineVar | Assignment=(Target, Operator, Value); Call=(Designator); Label=(Name, Colon, Statement); Goto=(goto, Target); Asm=(asm, protected Body, end); InlineVar=(var, Names, Type?, Initializer?) |
| N-EXPR | Literal/Identifier/Unary/Binary/Parenthesized | Original literal components oder Name; Unary=(Operator, Operand); Binary=(Left, Operator, Right); Paren=(Open, Inner, Close) |
| N-POST | Call/Member/Index/Dereference/Inherited/Set | receiver left-fold, jeweilige Delimiter/Members/Arguments; Inherited=(keyword, Designator/Arguments?); Set=(Open, Elements/Ranges mit Kommas, Close); Call-format-arguments können Width/Precision-Rollen tragen |
| N-ANON | AnonymousMethod | procedure/function, Parameters?, ReturnType?, LocalDeclarations*, Block; keine AST-/Closuresemantik |
| N-DROOT | Program/Library/Package | Header, Uses/Requires/Contains?, Declarations*, MainBlock/Exports?, EndDot; Exports=(keyword, Item+ mit index/name modifiers, Semicolon) |
| N-COND | ConditionalRegion | OpenDirective, Branch0, Branch1..n, CloseDirective?; Branch0 hat keinen eigenen Marker; spätere Branches=(BranchMarker, Body); Body enthält nur seinen Originalbereich |
| N-FRAG | SyntaxFragment/Opaque/Error | contiguous original Children, TSyntaxIssues/Kontextfakten außerhalb der Blätter; kein Syntaxvaliditätsversprechen |

N-POST umfasst geplante ergänzende Callargumentformen (z. B. Write(X:Width:Precision)); bestehende Parsercalls besitzen diese Fähigkeit noch nicht. Eigenschaften des Zielregisters sind nicht automatisch Code-Coverage.

## Conditional- und Triviaownership

OpenDirective besitzt genau seinen Opener (inklusive davor noch ausstehender Trivia). Branch0 enthält nur Body. Ein ELSEIF/ELSE-Marker gehört genau dem folgenden Branch, Closer der Region. Die erste Bedingung referenziert den Opener per Originalindex, dupliziert aber dessen Blatt nicht. Markertoken bleiben vollständig tkCompilerDirective; eine optionale Parameterquery darf Subspans lesen, nie überlappende Originalblätter erzeugen.

Jeder Body erhält das rohe Fenster direkt nach seinem Marker bis direkt vor dem nächsten Marker/Closer. **Die gesamte darin enthaltene Trivia, auch trailing Trivia, gehört diesem Body.** Der bounded Consumer konsumiert sie beim Abschluss. Deshalb besitzen nachfolgende Marker keine schon im Body verbrauchte führende Trivia. Leerer Body ist ein zero-width-Knoten am Markerendoffset. Diese explizite Fensterregel überschreibt nur hier die sonstige „führende Trivia beim nächsten Token“-Zuordnung.

Fehlender Closer: kein erfundenes echtes ENDIF; Region hat keine CloseDirective-Rolle und Issues incomplete/context_unknown. Ungepaarter ELSE/Closer: Error um Originaldirective, lokal belegte malformed-Paarung. Lexikalisch absorbierter Marker wird nicht aus Rawtext herausgeschnitten.

## Gemeinsame Syntax über Alternativen

Bei „type T = IFDEF… Integer …ELSE… string …ENDIF ;“ besitzt TypeDeclaration Name/Equals und Semicolon genau einmal; RHS ist die ConditionalRegion. Bodyrollen bleiben TypeReference-Fragmente im erwarteten RHS-Kontext, bis dieser Kontext gesondert unterstützt/belegt ist. Es gibt keine zwei vollständigen T-Deklarationen und keine aufeinanderfolgend aktiven RHS.

Dasselbe gilt für Routineheader mit bedingten Parametern und if/else über Branchgrenzen: gemeinsamer Präfix/Suffix im Besitzer, branchlokale Originalbereiche darunter. Ist die Produktion nicht beweisbar geschlossen, schützt SyntaxFragment den abhängigen Besitzer, auch wenn einzelne Branchteile strukturiert aussehen. Ein Sourcebaum kann nicht für alle konfigurierten Compileransichten gleichzeitig ein gewöhnlicher Grammatikbaum sein.

## Recovery und AST-Readiness

Fehlende erwartete Tokens erhalten bei gewöhnlicher bekannter Grammatik Missing; übersprungene originale Tokens Error nur bei lokaler Verletzung, sonst Opaque/Fragment mit passendem Issue. Mehrdeutig beschädigte Syntax darf größeren Bereich schützen. Kein Versprechen, ein ausgelassenes end dem „beabsichtigten“ Owner zuzuordnen. Loopfortschritt, Rekursions-/Ressourcenlimit und deterministische Diagnostics sind Pflicht.

AST-Readiness bedeutet: Rollen, Operatorgrouping, Names, Typen, Parameter/ReturnType, Modifier und Block ohne Regex-/Source-Reparse abfragbar. Nicht unterstützte Modifier bleiben als solche markiert. Eine spätere aktive AST-Sicht darf Compilation-Kontext benötigen; jetzt nur CST-Rollenqueries, keine ASTobjekte. T-ROLES überprüft u. a. verschachtelte Genericargumente und Routineparameter/Body nach Freigabe des Lexers.
