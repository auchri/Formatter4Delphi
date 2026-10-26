# M2.8 directive-aware safe pilot

## Contract and safety argument

M2.8 is separately authorized after M2.7. It changes only directive processing;
M2.6 expression, statement, type, generic ambiguity and recovery rules remain.
The public lexer, reader, parser entry points and arena ownership are unchanged.
`skConditionalDirectiveRegion` is appended at ordinal 56. It contains one
`skOpaqueRegion` with every original token of every branch, including nested
conditional directives. No branch is selected, evaluated or parsed as active code.
The analyzer treats either kind as opaque, independently of node counts.

The old Execute rejected every directive except line-isolated resources before
parsing any grammar. Take and Missing also detected directives inside tentative
productions and discarded the entire arena/tree construction. M2.8 retains that
second guard and the complete-input fallback. Includes and unknown directives
still reject the complete input in the prepass, even inside conditional branches.
An include can introduce any open grammar context; no expansion is attempted.

IndexDirectives classifies each lexer directive once, without moving the reader.
A stack pairs openers/closers, links branch boundaries, validates ELSE ordering,
and computes branch-envelope safety bottom-up. Nested groups combine only at
complete declaration boundaries. Each raw token is visited once, without suffix
rescanning, branch-source copies or recursive branch parsing. Storage is O(tokens)
plus an amortized growing stack. Supported conditional nesting is 32 levels;
excess nesting, missing closers, unmatched branches/closers and branches after
ELSE produce deterministic PAR005 errors with original directive spans. The scan
still finishes linearly beyond the limit and the entire input remains opaque.

## Recognized directives

Names are case-insensitive, with full word boundaries and whitespace handling.
Both `{$...}` and `(*$...*)` are accepted only on lexer tkCompilerDirective tokens.
Ordinary comments and string contents cannot become directives.

- Openers: IFDEF, IFNDEF, IF, IFOPT.
- Branches: ELSEIF, ELSE; closers: ENDIF, IFEND. Expressions are never evaluated.
- Includes: I followed by a file parameter, INCLUDE. I+ and I- are switches.
- Resources: R followed by a file parameter, RESOURCE. R+ and R- are switches.
- Single-letter +/- switches (A-D, F-Z), including comma-separated groups such
  as B+,R-,S-. Other spellings (numeric switches, unknown names) remain opaque.
- Finite long-name/control whitelist: DEFINE, UNDEF, WARN, HINTS, WARNINGS,
  RANGECHECKS, OVERFLOWCHECKS, ASSERTIONS, OPTIMIZATION, INLINE, ALIGN, IOCHECKS,
  LONGSTRINGS, BOOLEVAL, STACKFRAMES, SCOPEDENUMS.

This is classification, not compiler validation or semantic interpretation of
parameters. Malformed/unclosed lexer tokens remain unknown. Resource directives
retain the old horizontal-whitespace-only, own-line restriction at section level.
Switches and DEFINE/UNDEF are explicit skDirective nodes, never whitespace.
SCOPEDENUMS controls name scope; it does not add enumeration grammar.

## Supported boundaries

Standalone whitelisted switches are accepted before unit, between its completed
header semicolon and interface, and at interface/implementation declaration
boundaries. Resources remain accepted at unit-section boundaries only.

Conditional groups are accepted only at UnitSection boundaries, with all branches
independently matching a deliberately small envelope:

- Interface: zero or more `procedure Identifier;` declarations.
- Implementation: zero or more `procedure Identifier; begin end;` implementations.
- Whitelisted switches/resources and nested groups can occur only between these
  complete envelopes; an absent ELSE represents an empty branch.

Every branch must finish in the initial state. Shared names, parameters, types,
separators or body delimiters across directives fail this proof. Additional
semicolons and incomplete branches are rejected. Following independent routines
remain structured. The pilot does not accept parameterized/function headers,
const/type/var branch contents, member conditional groups or statement-list
conditional groups. Those are conservative limitations, not new grammar bugs.
Directives consumed inside TypeSection/AggregateDeclaration/Block/StatementList,
headers, expressions or recovery still trigger complete-input fallback. An
unproven unit-level opaque prefix cannot establish a later directive boundary.

A future formatter must treat both directive leaves and complete conditional
regions as immutable barriers. A recognized switch may affect compiler behavior
across later text. Structural recognition alone never authorizes moving it or
formatting unknown branches. No define sets, macro evaluation, include expansion,
AST, formatter or additional type/statement grammar is included.

## Validation and measurements

See `../reports/m2_8/comparison.md` for paired measurements, diagnostics and timing;
`../reports/m2_8/examples.md` records actual improved files and remaining blockers.
The manifest, commit SHAs, selected file hashes, archived internal fixtures and
strict UTF-8/BOM policy are unchanged. DirectiveCorpus is a new compiled regression
fixture, deliberately excluded from the pinned M2.7 corpus comparison.

Eight new parser methods exercise classification by observable integration,
conditional branching/nesting, exact opaque spans and node hierarchy, unsafe
contexts, errors, comments, 1,024 consecutive groups, depths 1-33, long tokens,
200 malformed UTF-16 parse/free pairs and deterministic diagnostics. All use the
existing independent post-lexer-disposal token/span/ownership/serialization checks.
A coverage regression manually counts 22 protected branch code units and 44
structured code units; the new kind must not inflate structural recognition.
Timing assertions are deliberately absent.

Language references:
- https://docwiki.embarcadero.com/RADStudio/Athens/en/Delphi_compiler_directives
- https://docwiki.embarcadero.com/RADStudio/Athens/en/Conditional_compilation_(Delphi)
- https://docwiki.embarcadero.com/RADStudio/Athens/en/Delphi_Compiler_Directives_(List)_Index
- https://docwiki.embarcadero.com/RADStudio/Athens/en/Scoped_Enums_(Delphi)
