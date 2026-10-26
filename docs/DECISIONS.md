# Architecture decision record (initial)

| ID | Decision | Reason |
| --- | --- | --- |
| D-01 | Target Delphi **12.3 minimum**; allow later language versions through tested extensions. | One testable baseline. |
| D-02 | Implement in **Delphi**, pure RTL core, no VCL/FMX dependency. | Reusable code across CLI/IDE/tools. |
| D-03 | Implement a **lossless CST** first; derive optional AST in a later independent layer. | Formatting needs trivia; semantic tools need abstraction. |
| D-04 | Handwritten deterministic scanner with lookahead, not regex-driven. | Precise Delphi lexical rules, malformed-code resilience. |
| D-05 | Lexer's public stream includes comments, directives, horizontal whitespace, and line breaks. | No loss and straightforward first-stage verification. |
| D-06 | Tokens are small value records with spans into the retained original `string` source. | Avoid per-token string allocation. |
| D-07 | Half-open zero-based UTF-16 spans. | Clean offsets, useful for editor APIs. |
| D-08 | Lexer EOF has `(Length(Source), 0)` and is not reconstructed. | Explicit end sentinel. |
| D-09 | Keep lexical compiler directives as first-class tokens, NOT normal comments or processed macros. | Preprocessing postponed without discarding information. |
| D-10 | Treat context-sensitive declaration directives (e.g. `virtual`, `override`) as identifiers at lex time. | Proper context belongs to parser. |
| D-11 | Preserve malformed input; produce error diagnostics, never throw for ordinary source syntax. | Works with in-progress editor text. |
| D-12 | CST nodes become immutable **after construction**; own/refer to a source snapshot. Do not introduce green/red trees yet. | No needless initial complexity. |
| D-13 | CST exact reconstruction traverses token leaves, not a source-copy shortcut. | Strong correctness invariant. |
| D-14 | Formatter later builds a layout plan and guarded edits, not arbitrary CST/token mutation. | Original syntax protection. |
| D-15 | AST + semantic resolution are optional, separate from formatting. | Avoid burdening basic formatting. |
| D-16 | Config precedence and native formatter equivalence will be specified/tested in formatter phase, not the lexer. | Preserve milestone focus. |
| D-17 | The original encoding/BOM and byte-preserving writes are a separate Source I/O layer; lexer gets decoded UTF-16 `string`. | No accidental byte/character confusion. |
| D-18 | Use DUnitX with tests for token kinds and full coverage in addition to roundtrips. | Lossless does not imply lexical correctness. |

## Open questions (do not block lexer)

- Exact `.config` schema across Delphi 12.3 and subsequent releases, precedence against editor overrides, and behavior of conflicting options.
- Precise Unicode identifier edge cases with supplementary code points: assert against Delphi compiler behavior where uncertain; preserve source even when classifying uncertain input as unknown.
- Parser handling of conditional compilation through incompatible grammar fragments: plan opaque protected regions first, configuration-aware CST second.
- Preferred serialization format for additional settings (tentative `delphifmt.toml`), and `.editorconfig` precedence.
- How exact cross-version output compatibility is defined when Embarcadero changes formatter behavior.

Document validated deviations in this file.

## M1.0/M1.1 implementation refinements (2026-10-25)

- Span members use read-only properties with constructor range validation;
  this preserves the conceptual API while preventing invalid mutable spans.
- `LEX006` is a warning for intentionally deferred M1.2 categories, distinct
  from `LEX005` errors for unrecognized code units. No string/comment/number
  scanner is claimed by M1.1. See `LEXER_SPEC.md` for exact fallback behavior.
- No language-rule deviation has been established by compiler tests. The
  installed toolchain refuses command-line compilation; see `M1_STATUS.md`.

## M1.1 review correction (2026-10-25)

UTF-16 recovery distinguishes encoding from lexical support: a valid surrogate
pair remains a single length-2 source span with an unsupported-category warning
(`LEX006`); an isolated surrogate receives an encoding error (`LEX007`). This
corrects the original per-code-unit fallback without extending Delphi identifier
recognition or changing the public API. BMP non-identifier characters retain
`LEX005` with a source-character message rather than an encoding-error message.

## M1.2 compiler-checked refinements (2026-10-25)

Public APIs remain unchanged. Documentation was checked against the official
Athens language reference and the installed Delphi 12 Community Edition Update 1
compiler (29.0.51961.7529), rather than assuming rules from other Pascal dialects.
Exactly Delphi 12.3 remains a separate validation gate.

- Block comments stop at their first own-style closer. Cross-style delimiters
  are inert, so a delimiter stack would incorrectly absorb following code.
  The compiled corpus includes both crossed-closing examples and ordinary
  mixed-style comments; unit tests cover same-style early closure.
- Compiler accepted 3/5/7-quote multiline literals, decimal/hex/binary digit
  separators, separators in fraction/exponent components, trailing decimal
  points and decimal char-code separators. The corpus is compiled into the
  test executable as a continuing language-syntax check.
- Compiler rejected binary char code `#%1010` with E2026. M1.2 diagnoses it
  as LEX004 while preserving the complete malformed char-code spelling.
- Compiler rejected `1.e2` with E2018: a dot before an identifier must stay
  separate (also permits numeric type-helper/member access).
- A supplementary U+10400 letter in an identifier produced E2038. Valid pairs
  outside strings/comments now use LEX005, never an invalid-encoding error.
  LEX007 checks all source code units, including within strings/comments.
- LEX006 is retained as a historical code but no longer emitted. Ordinary
  unterminated strings recover before the newline; multiline strings and block
  comments/directives recover at EOF. Value-level multiline indentation and
  numeric type/range semantics remain outside this lexer.

## M2.1 CST implementation refinements (2026-10-25)

- Original token references are immutable value records plus original indices;
  retaining the reference-counted source independently avoids keeping a borrowed
  lexer result alive. No lexer public API changed.
- A tree-owned flat arena owns every node/token once. Ordered child arrays are
  immutable, non-owning references. This keeps construction cleanup and tree
  destruction simple, including long left-associative binary chains.
- Any directive-bearing input is conservatively one opaque body in M2.1.
  Ambiguous generic call spellings also stay opaque rather than masquerading
  as comparisons. This is intentionally smaller grammar coverage, not directive
  evaluation or generic parsing.
- The Delphi operator groups follow the official Athens Expressions (Delphi)
  reference, including multiplicative `as` and left association of equal groups:
  https://docwiki.embarcadero.com/RADStudio/Athens/en/Expressions_(Delphi)
- No language-rule deviation was established by this task. Validation used the
  installed 12 CE Update 1 toolchain; exact 12.3 remains open (`M2_STATUS.md`).

## M2.1 PR #3 review corrections (2026-10-25)

- `True` and `False` remain `skIdentifierExpression`, including mixed case.
  Delphi defines them as predefined constants, not reserved words; resolving
  their declarations/values belongs to later semantic analysis. The parser
  therefore follows the lexer identifier classification and removes unreachable
  Boolean conditions from the literal branch. `nil` remains a reserved literal.
  References: https://docwiki.embarcadero.com/RADStudio/Athens/en/Simple_Types_(Delphi)
  and https://docwiki.embarcadero.com/RADStudio/Athens/en/Fundamental_Syntactic_Elements_(Delphi).
- Generic ambiguity lookahead uses a lazily built per-parser Boolean index of
  angle openers whose matching closer is followed by a significant `(`.
  A stack indexes the immutable raw token stream once; only ordinary trivia is
  skipped. Existing `;`, `(`, `then` and `end` barriers are unchanged. Each token
  is visited at most twice and each opener is pushed/removed once. Subsequent
  candidates use the index, so long comparison chains do not repeatedly scan
  overlapping suffixes. Cost is O(tokens + source text) time and O(tokens)
  temporary/parser-local memory, with no public API or Reader state change.
  This is delimiter lookahead only, not an implementation of generic grammar.
- The complete-body opaque fallback for any compiler directive is unchanged.
  Resource, include and conditional directives are tested in every entry mode;
  differentiated directive handling remains a later parser milestone.

## M2.2 directive and recovery boundaries (2026-10-26)

Only closed resource directives alone on a line at supported unit-section
boundaries gain explicit structure. No general preprocessor or directive trivia
policy was added. If one interrupts a header/declaration/body, construction is
discarded and the complete original stream is rebuilt as opaque leaves; lexical
diagnostics survive. Conditional/include/unknown directives retain M2.1 fallback.

Routine bodies reuse Block/Statement. Declaration recovery tracks nesting and
only synchronizes opaque type sections after a top-level semicolon; procedural
type aliases and class-method prefixes therefore cannot become global routines.
No public lexer/reader/tree API or ownership contract changed. New syntax kinds
are the only public API addition. Exact Delphi 12.3 validation remains open.

## M2.3 postfix and syntactic designators (2026-10-26)

Primary now folds `.`, brackets, calls and `^` iteratively in source order.
The existing binary precedence table and Expression algorithm are unchanged.
Only three appended syntax kinds are public additions; no Reader/lexer/tree
API, ownership, token storage or per-production class changes were needed.
Assignment classification walks the receiver spine iteratively, permitting
calls inside a member/index/dereference designator but rejecting a bare call
or binary-expression target. Parameterless member calls remain syntactically
plausible CallStatements; type/writability resolution is deferred.

Qualified generic candidates call the same lazy linear angle-opener index as
unqualified names. No generic grammar or repeated suffix scan was introduced.
Missing index closers preserve `:=`, semicolons and enclosing delimiters.

The official Fundamental Syntactic Elements (Delphi) reference permits keyword
spellings after qualification and equates `[`/`]` with `(.`/`.)`:
https://docwiki.embarcadero.com/RADStudio/Athens/en/Fundamental_Syntactic_Elements_(Delphi)
The parser accepts qualified keyword spellings per that reference and the
requested `GetObject().Property` example. The available CE Update 1 compiler
rejects `Customer.Property` with E2029, so the compiled corpus uses
`Customer.&Property`; exact 12.3 behavior remains unverified. This older
compiler observation does not establish a 12.3 language-rule deviation.
Paired/mixed bracket spellings are also exercised by the corpus. Exact build
evidence is in `M2_STATUS.md`.

## M2.4 type/member boundaries (2026-10-26)

TypeSection uses individual TypeDeclaration wrappers even for opaque types,
so an alias cannot absorb the next supported aggregate. AggregateDeclaration
shares class/record member dispatch without recursion into unsupported nested
types. Explicit visibility owns its members; default visibility is represented
by direct children, without inferring semantics. AncestorList is the eighth
appended kind. No other public API or arena/Reader/lexer changes are needed.

RoutineHeader is factored from Routine and reused by MethodDeclaration. Common
method directives are a finite opaque tail, including every semicolon; arbitrary
identifiers are not treated as directives because they may start fields.
Constructors/destructors share the existing routine machinery for their simple
qualified implementations; this is the minimal support needed by the corpus.
No inherited/operator/new statement grammar was added.

Opaque recovery tracks block, bracket/parenthesis and generic angle depth.
Class-of, forward classes, class member prefixes and procedural of-object
signatures do not open blocks. Angle constraints do not open class/record
blocks. Nested records inside variant parentheses do open blocks. Generic
ancestors stay opaque as a complete RHS. Properties scan their entire balanced
member and optional default/nodefault marker, without dispatching their internal
keywords as methods. Unbalanced properties/types may preserve a larger region.
Nested type sections and variant tails stay opaque to the enclosing end; no
false structure is invented for those members. Hard unit boundaries terminate
even unfinished recovery. Existing directive fallback remains unchanged.

No Delphi 12.3 language-rule deviation was established. Execution uses the
available Delphi 12 CE Update 1; see M2_STATUS.md for evidence.

## M2.5 property syntax and conservative recovery (2026-10-26)

The separately authorized M2.5 supersedes M2.4's property-only opaque boundary.
Three appended node kinds suffice; nodes/arena/Reader/lexer APIs are unchanged.
Accessors use qualified identifier structure, never general call expressions.
Array indices are declarations. Both meanings of default use PropertySpecifier,
with the trailing array marker owning its own semicolon inside the property.
Redeclarations omit type structure entirely. Semantic restrictions documented
in the official Properties (Delphi) reference are not resolved by this CST.

Unsupported generic property types and complex constants retain opaque children;
class properties and unsafe anonymous/class-of property types can stay entirely
opaque. Hard member boundaries take priority over malformed delimiter nesting.
No new grammar beyond M2.5, preprocessing or semantic validity checks are added.
No Delphi 12.3 language deviation is established by the CE Update 1 build.
