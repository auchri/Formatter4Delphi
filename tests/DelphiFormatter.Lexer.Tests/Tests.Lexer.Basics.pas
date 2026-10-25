unit Tests.Lexer.Basics;

interface

uses
  DUnitX.TestFramework,
  DelphiFormatter.Lexer.Tokens;

type
  [TestFixture]
  TLexerBasics = class
  private
    procedure CheckSingle(const Source: string; Kind: TTokenKind;
      const Code: string = '');
    procedure CheckCoverage(Lexed: TDelphiLexResult);
    procedure CheckToken(Lexed: TDelphiLexResult; Index: Integer;
      Kind: TTokenKind; Start, Count: Integer; const Text: string);
    procedure CheckWords(const Words: array of string; Kind: TTokenKind);
  public
    [Test] procedure OrdinaryStrings;
    [Test] procedure QuoteRuns;
    [Test] procedure MultilineStrings;
    [Test] procedure StringRecovery;
    [Test] procedure CommentForms;
    [Test] procedure CommentBoundaries;
    [Test] procedure CompilerDirectives;
    [Test] procedure ValidNumbers;
    [Test] procedure InvalidNumbers;
    [Test] procedure NumberBoundaries;
    [Test] procedure CharacterCodes;
    [Test] procedure UTF16InsideConstructs;
    [Test] procedure SeededMalformedInputs;
    [Test] procedure NumericMemberAccess;
    [Test] procedure MultilineBoundaries;
    [Test] procedure RealisticCorpus;
    [Test] procedure EmptySource;
    [Test] procedure HorizontalBlanks;
    [Test] procedure MixedNewlines;
    [Test] procedure UnitDeclaration;
    [Test] procedure ReservedWords;
    [Test] procedure ContextualWords;
    [Test] procedure EscapedIdentifiers;
    [Test] procedure AssignmentWithNumber;
    [Test] procedure LongestSymbols;
    [Test] procedure SingleSymbolsAndLookaheadAtEOF;
    [Test] procedure BasicUnicodeIdentifiers;
    [Test] procedure InvalidUTF16;
    [Test] procedure ValidUTF16Pairs;
    [Test] procedure NonIdentifierBMP;
    [Test] procedure FallbackAtEOF;
    [Test] procedure DeterministicResults;
    [Test] procedure ResultCopiesArrays;
    [Test] procedure ResultRejectsInvalidSpans;
    [Test] procedure CompletedCategories;
    [Test] procedure RangeDots;
    [Test] procedure SourceSnapshotAndValueAccess;
    [Test] procedure AccessorBounds;
    [Test] procedure SpanValidation;
    [Test] procedure SmallUnitFixture;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  DelphiFormatter.Core.Spans,
  DelphiFormatter.Core.Diagnostics,
  DelphiFormatter.Lexer.Scanner;

procedure TLexerBasics.CheckCoverage(Lexed: TDelphiLexResult);
var
  I, Offset, EOFCount: Integer;
  Token: TDelphiToken;
  Diagnostic: TDiagnostic;
  Rebuilt: string;
begin
  Offset := 0;
  EOFCount := 0;
  Rebuilt := '';
  Assert.IsTrue(Lexed.TokenCount > 0);
  for I := 0 to Lexed.TokenCount - 1 do
  begin
    Token := Lexed.GetToken(I);
    Assert.AreEqual(Offset, Token.Span.StartOffset);
    if Token.Kind = tkEOF then
    begin
      Inc(EOFCount);
      Assert.AreEqual(Lexed.TokenCount - 1, I);
      Assert.AreEqual(Length(Lexed.Source), Token.Span.StartOffset);
      Assert.AreEqual(0, Token.Span.Length);
      Assert.AreEqual('', Lexed.TokenText(I));
    end
    else
    begin
      Assert.IsTrue(Token.Span.Length > 0);
      Assert.IsTrue(Token.Span.EndOffset <= Length(Lexed.Source));
      // Independent slicing: do not reconstruct by simply reading Source.
      Rebuilt := Rebuilt + Copy(Lexed.Source, Token.Span.StartOffset + 1,
        Token.Span.Length);
      Assert.AreEqual(Copy(Lexed.Source, Offset + 1, Token.Span.Length),
        Lexed.TokenText(I));
      Offset := Token.Span.EndOffset;
    end;
  end;
  Assert.AreEqual(1, EOFCount);
  Assert.AreEqual(Length(Lexed.Source), Offset);
  Assert.AreEqual(Lexed.Source, Rebuilt);
  for I := 0 to Lexed.DiagnosticCount - 1 do
  begin
    Diagnostic := Lexed.GetDiagnostic(I);
    Assert.IsTrue(Diagnostic.Span.StartOffset >= 0);
    Assert.IsTrue(Diagnostic.Span.Length > 0);
    Assert.IsTrue(Diagnostic.Span.EndOffset <= Length(Lexed.Source));
    Assert.IsTrue(Diagnostic.Message <> '');
  end;
end;

procedure TLexerBasics.CheckToken(Lexed: TDelphiLexResult; Index: Integer;
  Kind: TTokenKind; Start, Count: Integer; const Text: string);
var
  Token: TDelphiToken;
begin
  Token := Lexed.GetToken(Index);
  Assert.AreEqual(Ord(Kind), Ord(Token.Kind));
  Assert.AreEqual(Start, Token.Span.StartOffset);
  Assert.AreEqual(Count, Token.Span.Length);
  Assert.AreEqual(Text, Lexed.TokenText(Index));
end;

procedure TLexerBasics.EmptySource;
var L: TDelphiLexResult;
begin
  L := TDelphiLexer.Tokenize('');
  try
    Assert.AreEqual(1, L.TokenCount);
    Assert.AreEqual(0, L.DiagnosticCount);
    CheckToken(L, 0, tkEOF, 0, 0, '');
    CheckCoverage(L);
  finally L.Free; end;
end;

procedure TLexerBasics.HorizontalBlanks;
const Source = ' '#9#11#12#0#31'  ';
var L: TDelphiLexResult;
begin
  L := TDelphiLexer.Tokenize(Source);
  try
    Assert.AreEqual(2, L.TokenCount);
    Assert.AreEqual(0, L.DiagnosticCount);
    CheckToken(L, 0, tkWhitespace, 0, Length(Source), Source);
    CheckCoverage(L);
  finally L.Free; end;
end;

procedure TLexerBasics.MixedNewlines;
var L: TDelphiLexResult;
begin
  L := TDelphiLexer.Tokenize(#13#10#13#10#10#13);
  try
    Assert.AreEqual(5, L.TokenCount);
    Assert.AreEqual(0, L.DiagnosticCount);
    CheckToken(L, 0, tkNewLine, 0, 2, #13#10);
    CheckToken(L, 1, tkNewLine, 2, 2, #13#10);
    CheckToken(L, 2, tkNewLine, 4, 1, #10);
    CheckToken(L, 3, tkNewLine, 5, 1, #13);
    CheckCoverage(L);
  finally L.Free; end;
end;

procedure TLexerBasics.UnitDeclaration;
var L: TDelphiLexResult;
begin
  L := TDelphiLexer.Tokenize('UnIt Foo;');
  try
    Assert.AreEqual(5, L.TokenCount);
    Assert.AreEqual(0, L.DiagnosticCount);
    CheckToken(L, 0, tkReservedWord, 0, 4, 'UnIt');
    CheckToken(L, 1, tkWhitespace, 4, 1, ' ');
    CheckToken(L, 2, tkIdentifier, 5, 3, 'Foo');
    CheckToken(L, 3, tkSymbol, 8, 1, ';');
    CheckCoverage(L);
  finally L.Free; end;
end;

procedure TLexerBasics.CheckWords(const Words: array of string; Kind: TTokenKind);
var
  Word: string;
  L: TDelphiLexResult;
begin
  for Word in Words do
  begin
    L := TDelphiLexer.Tokenize(UpperCase(Word));
    try
      Assert.AreEqual(2, L.TokenCount, Word);
      Assert.AreEqual(0, L.DiagnosticCount, Word);
      CheckToken(L, 0, Kind, 0, Length(Word), UpperCase(Word));
      CheckCoverage(L);
    finally L.Free; end;
  end;
end;

procedure TLexerBasics.ReservedWords;
begin
  CheckWords(['and', 'array', 'as', 'asm', 'at', 'begin', 'case', 'class',
    'const', 'constructor', 'destructor', 'dispinterface', 'div', 'do',
    'downto', 'else', 'end', 'except', 'exports', 'file', 'finalization',
    'finally', 'for', 'function', 'goto', 'if', 'implementation', 'in',
    'inherited', 'initialization', 'inline', 'interface', 'is', 'label',
    'library', 'mod', 'nil', 'not', 'object', 'of', 'on', 'or', 'packed',
    'procedure', 'program', 'property', 'raise', 'record', 'repeat',
    'resourcestring', 'set', 'shl', 'shr', 'string', 'then', 'threadvar',
    'to', 'try', 'type', 'unit', 'until', 'uses', 'var', 'while', 'with',
    'xor'], tkReservedWord);
end;

procedure TLexerBasics.ContextualWords;
begin
  CheckWords(['virtual', 'override', 'read', 'write', 'static', 'strict',
    'private', 'protected', 'public', 'published', 'automated', 'out',
    'helper', 'reference', 'operator', 'package', 'contains', 'requires',
    'Result', 'unitName', '_', 'a1'], tkIdentifier);
end;

procedure TLexerBasics.EscapedIdentifiers;
var L: TDelphiLexResult;
begin
  L := TDelphiLexer.Tokenize('&Type &foo &1 &');
  try
    CheckToken(L, 0, tkIdentifier, 0, 5, '&Type');
    CheckToken(L, 2, tkIdentifier, 6, 4, '&foo');
    CheckToken(L, 4, tkUnknown, 11, 1, '&');
    CheckToken(L, 5, tkNumber, 12, 1, '1');
    CheckToken(L, 7, tkUnknown, 14, 1, '&');
    Assert.AreEqual(2, L.DiagnosticCount);
    CheckCoverage(L);
  finally L.Free; end;
end;

procedure TLexerBasics.AssignmentWithNumber;
var L: TDelphiLexResult;
begin
  L := TDelphiLexer.Tokenize('Result:=A+1;');
  try
    Assert.AreEqual(7, L.TokenCount);
    Assert.AreEqual(0, L.DiagnosticCount);
    CheckToken(L, 0, tkIdentifier, 0, 6, 'Result');
    CheckToken(L, 1, tkSymbol, 6, 2, ':=');
    CheckToken(L, 2, tkIdentifier, 8, 1, 'A');
    CheckToken(L, 3, tkSymbol, 9, 1, '+');
    CheckToken(L, 4, tkNumber, 10, 1, '1');
    CheckToken(L, 5, tkSymbol, 11, 1, ';');
    CheckCoverage(L);
  finally L.Free; end;
end;

procedure TLexerBasics.LongestSymbols;
const Symbols: array[0..6] of string = (':=', '<=', '>=', '<>', '..', '(.', '.)');
var S: string; L: TDelphiLexResult;
begin
  for S in Symbols do
  begin
    L := TDelphiLexer.Tokenize(S);
    try
      Assert.AreEqual(2, L.TokenCount);
      Assert.AreEqual(0, L.DiagnosticCount);
      CheckToken(L, 0, tkSymbol, 0, 2, S);
      CheckCoverage(L);
    finally L.Free; end;
  end;
end;

procedure TLexerBasics.SingleSymbolsAndLookaheadAtEOF;
const Symbols = '+-*/=,;()[]^@:<>';
var I: Integer; L: TDelphiLexResult;
begin
  for I := 1 to Length(Symbols) do
  begin
    L := TDelphiLexer.Tokenize(Symbols[I]);
    try
      Assert.AreEqual(2, L.TokenCount);
      Assert.AreEqual(0, L.DiagnosticCount);
      CheckToken(L, 0, tkSymbol, 0, 1, Symbols[I]);
      CheckCoverage(L);
    finally L.Free; end;
  end;
  L := TDelphiLexer.Tokenize('.');
  try
    CheckToken(L, 0, tkSymbol, 0, 1, '.');
    CheckCoverage(L);
  finally L.Free; end;
end;

procedure TLexerBasics.BasicUnicodeIdentifiers;
var L: TDelphiLexResult; Source: string;
begin
  Source := Char($00C4) + 'nderung_1';
  L := TDelphiLexer.Tokenize(Source);
  try
    Assert.AreEqual(2, L.TokenCount);
    Assert.AreEqual(0, L.DiagnosticCount);
    CheckToken(L, 0, tkIdentifier, 0, Length(Source), Source);
    CheckCoverage(L);
  finally L.Free; end;
end;

procedure TLexerBasics.InvalidUTF16;
var L: TDelphiLexResult; Source: string; I: Integer; D: TDiagnostic;
begin
  // No adjacent high/low pair: high + letter, low + high at EOF.
  Source := Char($D800) + 'A' + Char($DC00) + Char($DBFF);
  L := TDelphiLexer.Tokenize(Source);
  try
    Assert.AreEqual(5, L.TokenCount);
    Assert.AreEqual(3, L.DiagnosticCount);
    CheckToken(L, 0, tkUnknown, 0, 1, Char($D800));
    CheckToken(L, 1, tkIdentifier, 1, 1, 'A');
    CheckToken(L, 2, tkUnknown, 2, 1, Char($DC00));
    CheckToken(L, 3, tkUnknown, 3, 1, Char($DBFF));
    for I := 0 to 2 do
    begin
      D := L.GetDiagnostic(I);
      Assert.AreEqual('LEX007', D.Code);
      Assert.AreEqual(Ord(dsError), Ord(D.Severity));
      Assert.IsTrue(Pos('Invalid UTF-16', D.Message) > 0);
      if I = 0 then
        Assert.AreEqual(0, D.Span.StartOffset)
      else
        Assert.AreEqual(I + 1, D.Span.StartOffset);
      Assert.AreEqual(1, D.Span.Length);
    end;
    CheckCoverage(L);
  finally L.Free; end;
end;

procedure TLexerBasics.ValidUTF16Pairs;
var Source, Pair: string; L: TDelphiLexResult; I: Integer; D: TDiagnostic;
begin
  // Emoji U+1F600, supplementary letter U+10400, scalar boundaries.
  // None is claimed to be an implemented Delphi identifier in M1.1.
  for Pair in TArray<string>.Create(Char($D83D) + Char($DE00),
    Char($D801) + Char($DC00), Char($D800) + Char($DC00),
    Char($DBFF) + Char($DFFF)) do
    for Source in TArray<string>.Create(Pair, 'A' + Pair + 'B') do
    begin
      L := TDelphiLexer.Tokenize(Source);
      try
        I := 0;
        if Length(Source) = 4 then
        begin
          Assert.AreEqual(4, L.TokenCount);
          CheckToken(L, 0, tkIdentifier, 0, 1, 'A');
          CheckToken(L, 2, tkIdentifier, 3, 1, 'B');
          I := 1;
        end
        else
          Assert.AreEqual(2, L.TokenCount);
        CheckToken(L, I, tkUnknown, I, 2, Pair);
        Assert.AreEqual(1, L.DiagnosticCount);
        D := L.GetDiagnostic(0);
        Assert.AreEqual('LEX005', D.Code);
        Assert.AreEqual(Ord(dsError), Ord(D.Severity));
        Assert.AreEqual(I, D.Span.StartOffset);
        Assert.AreEqual(2, D.Span.Length);
        Assert.IsTrue(Pos('Supplementary Unicode', D.Message) > 0);
        Assert.AreEqual(0, Pos('Invalid UTF-16', D.Message));
        CheckCoverage(L);
      finally L.Free; end;
    end;
end;

procedure TLexerBasics.NonIdentifierBMP;
var C: Char; L: TDelphiLexResult; D: TDiagnostic;
begin
  // Snowman and noncharacter: correctly encoded BMP, not invalid UTF-16.
  for C in TArray<Char>.Create(Char($2603), Char($FFFF)) do
  begin
    L := TDelphiLexer.Tokenize(C);
    try
      Assert.AreEqual(2, L.TokenCount);
      CheckToken(L, 0, tkUnknown, 0, 1, C);
      Assert.AreEqual(1, L.DiagnosticCount);
      D := L.GetDiagnostic(0);
      Assert.AreEqual('LEX005', D.Code);
      Assert.AreEqual(Ord(dsError), Ord(D.Severity));
      Assert.AreEqual(0, D.Span.StartOffset);
      Assert.AreEqual(1, D.Span.Length);
      Assert.AreEqual('Unrecognized source character', D.Message);
      CheckCoverage(L);
    finally L.Free; end;
  end;
end;

procedure TLexerBasics.FallbackAtEOF;
var S: string;
begin
  for S in TArray<string>.Create('}', '&', '?') do
    CheckSingle(S, tkUnknown, 'LEX005');
end;

procedure TLexerBasics.DeterministicResults;
var Source: string; A, B: TDelphiLexResult; I: Integer; DA, DB: TDiagnostic;
begin
  Source := 'unit A;'#0#13#10'&Type:=1..10;{''' + Char($D83D) +
    Char($DE00) + Char($D800) + 'Z';
  A := TDelphiLexer.Tokenize(Source);
  try
    B := TDelphiLexer.Tokenize(Source);
    try
      Assert.AreEqual(A.TokenCount, B.TokenCount);
      Assert.AreEqual(A.DiagnosticCount, B.DiagnosticCount);
      for I := 0 to A.TokenCount - 1 do
        CheckToken(B, I, A.GetToken(I).Kind, A.GetToken(I).Span.StartOffset,
          A.GetToken(I).Span.Length, A.TokenText(I));
      for I := 0 to A.DiagnosticCount - 1 do
      begin
        DA := A.GetDiagnostic(I);
        DB := B.GetDiagnostic(I);
        Assert.AreEqual(DA.Code, DB.Code);
        Assert.AreEqual(DA.Message, DB.Message);
        Assert.AreEqual(Ord(DA.Severity), Ord(DB.Severity));
        Assert.AreEqual(DA.Span.StartOffset, DB.Span.StartOffset);
        Assert.AreEqual(DA.Span.Length, DB.Span.Length);
      end;
      CheckCoverage(A);
      CheckCoverage(B);
    finally B.Free; end;
  finally A.Free; end;
end;

procedure TLexerBasics.ResultCopiesArrays;
var
  Tokens: TArray<TDelphiToken>;
  Diagnostics: TArray<TDiagnostic>;
  L: TDelphiLexResult;
  D: TDiagnostic;
begin
  Tokens := TArray<TDelphiToken>.Create(
    TDelphiToken.Create(tkUnknown, TSourceSpan.Create(0, 1)),
    TDelphiToken.Create(tkEOF, TSourceSpan.Create(1, 0)));
  Diagnostics := TArray<TDiagnostic>.Create(TDiagnostic.Create('LEX005',
    'Unrecognized source character', dsError, TSourceSpan.Create(0, 1)));
  L := TDelphiLexResult.Create('&', Tokens, Diagnostics);
  try
    Tokens[0].Kind := tkIdentifier;
    Diagnostics[0].Code := 'changed';
    D := L.GetDiagnostic(0);
    D.Message := 'changed';
    Tokens := nil;
    Diagnostics := nil;
    CheckToken(L, 0, tkUnknown, 0, 1, '&');
    Assert.AreEqual('LEX005', L.GetDiagnostic(0).Code);
    Assert.AreEqual('Unrecognized source character', L.GetDiagnostic(0).Message);
    CheckCoverage(L);
  finally L.Free; end;
end;

procedure TLexerBasics.ResultRejectsInvalidSpans;
var
  Tokens: TArray<TDelphiToken>;
  Diagnostics: TArray<TDiagnostic>;
  procedure Reject;
  begin
    Assert.WillRaise(
      procedure
      var L: TDelphiLexResult;
      begin
        L := TDelphiLexResult.Create('A', Tokens, Diagnostics);
        L.Free;
      end, EArgumentException);
  end;
begin
  Tokens := nil;
  Diagnostics := nil;
  Reject;
  Tokens := TArray<TDelphiToken>.Create(
    TDelphiToken.Create(tkIdentifier, TSourceSpan.Create(0, 2)),
    TDelphiToken.Create(tkEOF, TSourceSpan.Create(1, 0)));
  Reject;
  Tokens[0] := TDelphiToken.Create(tkIdentifier, TSourceSpan.Create(1, 1));
  Reject;
  Tokens[0] := TDelphiToken.Create(tkIdentifier, TSourceSpan.Create(0, 0));
  Reject;
  Tokens[0] := TDelphiToken.Create(tkEOF, TSourceSpan.Create(0, 0));
  Reject;
  Tokens[0] := TDelphiToken.Create(tkIdentifier, TSourceSpan.Create(0, 1));
  Tokens[1] := TDelphiToken.Create(tkEOF, TSourceSpan.Create(0, 0));
  Reject;
  Tokens[1] := TDelphiToken.Create(tkEOF, TSourceSpan.Create(1, 1));
  Reject;
  Tokens := TArray<TDelphiToken>.Create(
    TDelphiToken.Create(tkIdentifier, TSourceSpan.Create(0, 1)));
  Reject;
  Tokens := TArray<TDelphiToken>.Create(
    TDelphiToken.Create(tkIdentifier, TSourceSpan.Create(0, 1)),
    TDelphiToken.Create(tkEOF, TSourceSpan.Create(1, 0)));
  Diagnostics := TArray<TDiagnostic>.Create(TDiagnostic.Create('LEX005',
    'Bad span', dsError, TSourceSpan.Create(1, 1)));
  Reject;
end;

procedure TLexerBasics.CompletedCategories;
begin
  CheckSingle(#39'abc', tkStringLiteral, 'LEX003');
  CheckSingle('// comment', tkComment);
  CheckSingle('{$IFDEF DEBUG}', tkCompilerDirective);
  CheckSingle('(* unfinished', tkComment, 'LEX001');
  CheckSingle('$FF', tkNumber);
end;

procedure TLexerBasics.RangeDots;
var L: TDelphiLexResult;
begin
  L := TDelphiLexer.Tokenize('1..10');
  try
    Assert.AreEqual(4, L.TokenCount);
    Assert.AreEqual(0, L.DiagnosticCount);
    CheckToken(L, 0, tkNumber, 0, 1, '1');
    CheckToken(L, 1, tkSymbol, 1, 2, '..');
    CheckToken(L, 2, tkNumber, 3, 2, '10');
    CheckCoverage(L);
  finally L.Free; end;
end;

procedure TLexerBasics.SourceSnapshotAndValueAccess;
var Source: string; L, Other: TDelphiLexResult; Token: TDelphiToken;
begin
  Source := 'unit Foo;';
  L := TDelphiLexer.Tokenize(Source);
  try
    Source[1] := 'X';
    CheckToken(L, 0, tkReservedWord, 0, 4, 'unit');
    Token := L.GetToken(0);
    Token.Kind := tkUnknown;
    CheckToken(L, 0, tkReservedWord, 0, 4, 'unit');
    Other := TDelphiLexer.Tokenize('');
    try CheckCoverage(Other); finally Other.Free; end;
    CheckCoverage(L);
  finally L.Free; end;
end;

procedure TLexerBasics.AccessorBounds;
var L: TDelphiLexResult;
begin
  L := TDelphiLexer.Tokenize('');
  try
    Assert.WillRaise(procedure begin L.GetToken(-1); end, EArgumentOutOfRangeException);
    Assert.WillRaise(procedure begin L.GetToken(1); end, EArgumentOutOfRangeException);
    Assert.WillRaise(procedure begin L.TokenText(1); end, EArgumentOutOfRangeException);
    Assert.WillRaise(procedure begin L.GetDiagnostic(0); end, EArgumentOutOfRangeException);
    Assert.WillRaise(procedure begin L.GetDiagnostic(-1); end, EArgumentOutOfRangeException);
  finally L.Free; end;
end;

procedure TLexerBasics.SpanValidation;
var Span: TSourceSpan;
begin
  Span := TSourceSpan.Create(3, 4);
  Assert.AreEqual(7, Span.EndOffset);
  Span := TSourceSpan.Create(High(Integer), 0);
  Assert.AreEqual(High(Integer), Span.EndOffset);
  Assert.WillRaise(procedure begin TSourceSpan.Create(-1, 1); end, EArgumentOutOfRangeException);
  Assert.WillRaise(procedure begin TSourceSpan.Create(0, -1); end, EArgumentOutOfRangeException);
  Assert.WillRaise(procedure begin TSourceSpan.Create(High(Integer), 1); end, EArgumentOutOfRangeException);
end;

procedure TLexerBasics.SmallUnitFixture;
const Source = 'unit Minimal;'#13#10'interface'#13#10'implementation'#13#10'end.'#13#10;
var L: TDelphiLexResult;
begin
  L := TDelphiLexer.Tokenize(Source);
  try
    Assert.AreEqual(13, L.TokenCount);
    Assert.AreEqual(0, L.DiagnosticCount);
    CheckToken(L, 0, tkReservedWord, 0, 4, 'unit');
    CheckToken(L, 2, tkIdentifier, 5, 7, 'Minimal');
    CheckToken(L, 5, tkReservedWord, 15, 9, 'interface');
    CheckToken(L, 7, tkReservedWord, 26, 14, 'implementation');
    CheckToken(L, 9, tkReservedWord, 42, 3, 'end');
    CheckToken(L, 10, tkSymbol, 45, 1, '.');
    CheckCoverage(L);
  finally L.Free; end;
end;

procedure TLexerBasics.CheckSingle(const Source: string; Kind: TTokenKind;
  const Code: string);
var L: TDelphiLexResult; D: TDiagnostic;
begin
  L := TDelphiLexer.Tokenize(Source);
  try
    Assert.AreEqual(2, L.TokenCount, Source);
    CheckToken(L, 0, Kind, 0, Length(Source), Source);
    if Code = '' then Assert.AreEqual(0, L.DiagnosticCount, Source)
    else
    begin
      Assert.AreEqual(1, L.DiagnosticCount, Source);
      D := L.GetDiagnostic(0);
      Assert.AreEqual(Code, D.Code, Source);
      Assert.AreEqual(Ord(dsError), Ord(D.Severity));
      Assert.AreEqual(0, D.Span.StartOffset);
      Assert.AreEqual(Length(Source), D.Span.Length);
    end;
    CheckCoverage(L);
  finally L.Free; end;
end;

procedure TLexerBasics.OrdinaryStrings;
var S: string;
begin
  for S in TArray<string>.Create(#39'Hello World'#39, #39'It'#39#39's Delphi'#39,
    #39#39, #39#39#39#39, #39'// { (* {$IFDEF X}'#39,
    #39 + Char($00E4) + Char($D83D) + Char($DE00) + #39,
    #39 + StringOfChar('x', 100000) + #39) do CheckSingle(S, tkStringLiteral);
end;

procedure TLexerBasics.QuoteRuns;
var N: Integer; S: string;
begin
  for N := 1 to 12 do
  begin
    S := StringOfChar(#39, N);
    if Odd(N) then CheckSingle(S, tkStringLiteral, 'LEX003')
    else CheckSingle(S, tkStringLiteral);
  end;
  CheckSingle(StringOfChar(#39, 3) + 'abc', tkStringLiteral, 'LEX003');
end;

procedure TLexerBasics.MultilineStrings;
var N: Integer; Q, EOL, S: string;
begin
  for N in TArray<Integer>.Create(3, 5, 7, 9) do
    for EOL in TArray<string>.Create(#13#10, #13, #10) do
    begin
      Q := StringOfChar(#39, N);
      S := Q + EOL + '  SELECT ' + #39 + 'R&D' + #39 + EOL +
        '  // { (* $' + EOL + '  ' + Q;
      CheckSingle(S, tkStringLiteral);
      CheckSingle(Q + EOL + '  text', tkStringLiteral, 'LEX003');
      CheckSingle(Q + EOL + 'text' + Q, tkStringLiteral, 'LEX003');
    end;
  Q := StringOfChar(#39, 5);
  CheckSingle(Q + #10 + '  ' + StringOfChar(#39, 3) + #13#10 +
    '  ' + Q, tkStringLiteral);
end;

procedure TLexerBasics.StringRecovery;
var L: TDelphiLexResult;
begin
  L := TDelphiLexer.Tokenize(#39'abc'#13#10'unit');
  try
    Assert.AreEqual(4, L.TokenCount);
    CheckToken(L, 0, tkStringLiteral, 0, 4, #39'abc');
    CheckToken(L, 1, tkNewLine, 4, 2, #13#10);
    CheckToken(L, 2, tkReservedWord, 6, 4, 'unit');
    Assert.AreEqual(1, L.DiagnosticCount);
    Assert.AreEqual('LEX003', L.GetDiagnostic(0).Code);
    Assert.AreEqual(0, L.GetDiagnostic(0).Span.StartOffset);
    Assert.AreEqual(4, L.GetDiagnostic(0).Span.Length);
    CheckCoverage(L);
  finally L.Free; end;
end;

procedure TLexerBasics.CommentForms;
var S: string; L: TDelphiLexResult;
begin
  for S in TArray<string>.Create('//', '/// <summary>', '// '#39' { (*',
    '{}', '(**)', '{ a'#13#10' b }', '(* a'#10' b *)',
    '(* { nested } *)', '{ (* nested *) }', '{ {$IFDEF X}',
    '(* (* first closer *)') do CheckSingle(S, tkComment);
  for S in TArray<string>.Create('{', '{abc', '(*', '(*abc') do
    CheckSingle(S, tkComment, 'LEX001');
  L := TDelphiLexer.Tokenize('// a'#13#10'X');
  try
    CheckToken(L, 0, tkComment, 0, 4, '// a');
    CheckToken(L, 1, tkNewLine, 4, 2, #13#10);
    CheckToken(L, 2, tkIdentifier, 6, 1, 'X');
    Assert.AreEqual(0, L.DiagnosticCount);
    CheckCoverage(L);
  finally L.Free; end;
end;

procedure TLexerBasics.CommentBoundaries;
var L: TDelphiLexResult;
begin
  L := TDelphiLexer.Tokenize('{ { } X');
  try
    CheckToken(L, 0, tkComment, 0, 5, '{ { }');
    CheckToken(L, 2, tkIdentifier, 6, 1, 'X');
    Assert.AreEqual(0, L.DiagnosticCount);
    CheckCoverage(L);
  finally L.Free; end;
  L := TDelphiLexer.Tokenize('{ (* } X');
  try
    CheckToken(L, 0, tkComment, 0, 6, '{ (* }');
    CheckToken(L, 2, tkIdentifier, 7, 1, 'X');
    Assert.AreEqual(0, L.DiagnosticCount);
    CheckCoverage(L);
  finally L.Free; end;
end;

procedure TLexerBasics.CompilerDirectives;
var S: string;
begin
  for S in TArray<string>.Create('{$IFDEF DEBUG}', '{$ELSE}', '{$ENDIF}',
    '{$I filename.inc}', '{$WARNINGS OFF}', '(*$IFDEF DEBUG*)',
    '{$MESSAGE '#39'hello'#39'}') do CheckSingle(S, tkCompilerDirective);
  for S in TArray<string>.Create('{$', '(*$', '{$IFDEF X', '(*$I X') do
    CheckSingle(S, tkCompilerDirective, 'LEX002');
  CheckSingle('{ $IFDEF X}', tkComment);
  CheckSingle('(* $IFDEF X*)', tkComment);
  CheckSingle('//$IFDEF X', tkComment);
end;

procedure TLexerBasics.ValidNumbers;
var S: string;
begin
  for S in TArray<string>.Create('0', '123', '12345', '12.34', '1.5E-3',
    '2E+10', '1.', '$FF', '$1234ABCD', '%101010', '1_000_000', '$FF_FF',
    '%10_10', '1_2.3_4e+5_6', StringOfChar('9', 10000)) do
    CheckSingle(S, tkNumber);
end;

procedure TLexerBasics.InvalidNumbers;
var S: string;
begin
  for S in TArray<string>.Create('$', '%', '$_F', '%_1', '%102',
    '1_', '1__2', '$FF_', '%10__1', '1e', '1e+', '1e-', '1e_2',
    '1.2_e3', '1.2e+_3') do CheckSingle(S, tkNumber, 'LEX004');
end;

procedure TLexerBasics.NumberBoundaries;
var L: TDelphiLexResult;
begin
  L := TDelphiLexer.Tokenize('-12+2E-10');
  try
    Assert.AreEqual(5, L.TokenCount);
    Assert.AreEqual(0, L.DiagnosticCount);
    CheckToken(L, 0, tkSymbol, 0, 1, '-');
    CheckToken(L, 1, tkNumber, 1, 2, '12');
    CheckToken(L, 2, tkSymbol, 3, 1, '+');
    CheckToken(L, 3, tkNumber, 4, 5, '2E-10');
    CheckCoverage(L);
  finally L.Free; end;
  L := TDelphiLexer.Tokenize('A(.0.)');
  try
    Assert.AreEqual(5, L.TokenCount);
    Assert.AreEqual(0, L.DiagnosticCount);
    CheckToken(L, 1, tkSymbol, 1, 2, '(.');
    CheckToken(L, 2, tkNumber, 3, 1, '0');
    CheckToken(L, 3, tkSymbol, 4, 2, '.)');
    CheckCoverage(L);
  finally L.Free; end;
end;

procedure TLexerBasics.CharacterCodes;
var S: string; L: TDelphiLexResult;
begin
  for S in TArray<string>.Create('#0', '#13', '#10', '#$0A', '#65535', '#1_0',
    '#$FFFF') do CheckSingle(S, tkCharCode);
  for S in TArray<string>.Create('#', '#$', '#65536', '#$10000', '#_1',
    '#1_', '#%1010', '#' + StringOfChar('9', 10000)) do
    CheckSingle(S, tkCharCode, 'LEX004');
  L := TDelphiLexer.Tokenize(#39'Hello'#39'#13#10'#39'World'#39);
  try
    Assert.AreEqual(5, L.TokenCount);
    Assert.AreEqual(0, L.DiagnosticCount);
    CheckToken(L, 0, tkStringLiteral, 0, 7, #39'Hello'#39);
    CheckToken(L, 1, tkCharCode, 7, 3, '#13');
    CheckToken(L, 2, tkCharCode, 10, 3, '#10');
    CheckToken(L, 3, tkStringLiteral, 13, 7, #39'World'#39);
    CheckCoverage(L);
  finally L.Free; end;
end;

procedure TLexerBasics.UTF16InsideConstructs;
var Prefix, S: string; L: TDelphiLexResult;
begin
  for Prefix in TArray<string>.Create(#39, '{', '(*', '//', '{$') do
  begin
    S := Prefix + Char($D800);
    L := TDelphiLexer.Tokenize(S);
    try
      Assert.AreEqual('LEX007', L.GetDiagnostic(0).Code);
      Assert.AreEqual(Length(Prefix), L.GetDiagnostic(0).Span.StartOffset);
      Assert.AreEqual(1, L.GetDiagnostic(0).Span.Length);
      Assert.IsTrue(L.GetToken(0).Kind <> tkUnknown);
      CheckCoverage(L);
    finally L.Free; end;
  end;
end;

procedure TLexerBasics.SeededMalformedInputs;
var Seed: UInt64; N, J, I: Integer; S: string; A, B: TDelphiLexResult;
const Alphabet = 'abcXYZ019_$%#'':;.+-/*(){}[]'#0#9#13#10;
  function NextValue: Cardinal;
  begin
    Seed := (Seed * 1664525 + 1013904223) and $FFFFFFFF;
    Result := Cardinal(Seed);
  end;
begin
  Seed := $4D312E32;
  for N := 1 to 500 do
  begin
    SetLength(S, Integer(NextValue mod 512) + 1);
    for J := 1 to Length(S) do
      if N mod 3 = 0 then S[J] := Char(NextValue mod 65536)
      else S[J] := Alphabet[Integer(NextValue mod Cardinal(Length(Alphabet))) + 1];
    A := TDelphiLexer.Tokenize(S);
    try
      B := TDelphiLexer.Tokenize(S);
      try
        CheckCoverage(A);
        CheckCoverage(B);
        Assert.AreEqual(A.TokenCount, B.TokenCount);
        Assert.AreEqual(A.DiagnosticCount, B.DiagnosticCount);
        for I := 0 to A.TokenCount - 1 do
          CheckToken(B, I, A.GetToken(I).Kind, A.GetToken(I).Span.StartOffset,
            A.GetToken(I).Span.Length, A.TokenText(I));
        for I := 0 to A.DiagnosticCount - 1 do
        begin
          Assert.AreEqual(A.GetDiagnostic(I).Code, B.GetDiagnostic(I).Code);
          Assert.AreEqual(A.GetDiagnostic(I).Span.StartOffset,
            B.GetDiagnostic(I).Span.StartOffset);
          Assert.AreEqual(A.GetDiagnostic(I).Span.Length,
            B.GetDiagnostic(I).Span.Length);
        end;
      finally B.Free; end;
    finally A.Free; end;
  end;
end;

procedure TLexerBasics.RealisticCorpus;
var S, Path: string; L: TDelphiLexResult; I: Integer;
  Counts: array[TTokenKind] of Integer; K: TTokenKind;
begin
  Path := ExpandFileName(ExtractFilePath(ParamStr(0)) +
    '..\..\..\tests\Fixtures\LexicalCorpus.pas');
  S := TFile.ReadAllText(Path, TEncoding.UTF8);
  // Exercise mixed endings independently of Git's checkout normalization.
  S := StringReplace(S, #13#10, #10, [rfReplaceAll]);
  S := StringReplace(S, 'interface'#10, 'interface'#13, []);
  S := StringReplace(S, 'implementation'#10, 'implementation'#13#10, []);
  FillChar(Counts, SizeOf(Counts), 0);
  L := TDelphiLexer.Tokenize(S);
  try
    Assert.AreEqual(0, L.DiagnosticCount);
    Assert.IsTrue(L.TokenCount > 250);
    for I := 0 to L.TokenCount - 1 do
    begin
      Assert.IsTrue(L.GetToken(I).Kind <> tkUnknown, L.TokenText(I));
      Inc(Counts[L.GetToken(I).Kind]);
    end;
    for K in [tkIdentifier, tkReservedWord, tkNumber, tkStringLiteral,
      tkCharCode, tkComment, tkCompilerDirective, tkSymbol, tkNewLine] do
      Assert.IsTrue(Counts[K] > 0);
    CheckToken(L, 0, tkReservedWord, 0, 4, 'unit');
    CheckToken(L, 2, tkIdentifier, 5, 13, 'LexicalCorpus');
    CheckCoverage(L);
  finally L.Free; end;
end;

procedure TLexerBasics.NumericMemberAccess;
var S: string; L: TDelphiLexResult;
begin
  for S in TArray<string>.Create('1.ToString', '1.e2', '1._2') do
  begin
    L := TDelphiLexer.Tokenize(S);
    try
      Assert.AreEqual(4, L.TokenCount);
      Assert.AreEqual(0, L.DiagnosticCount);
      CheckToken(L, 0, tkNumber, 0, 1, '1');
      CheckToken(L, 1, tkSymbol, 1, 1, '.');
      CheckToken(L, 2, tkIdentifier, 2, Length(S) - 2, Copy(S, 3, MaxInt));
      CheckCoverage(L);
    finally L.Free; end;
  end;
end;

procedure TLexerBasics.MultilineBoundaries;
var Q, S: string; L: TDelphiLexResult;
begin
  Q := StringOfChar(#39, 3);
  S := Q + #10 + '  text' + #13#10 + '  ' + Q;
  L := TDelphiLexer.Tokenize(S + ';X');
  try
    Assert.AreEqual(4, L.TokenCount);
    Assert.AreEqual(0, L.DiagnosticCount);
    CheckToken(L, 0, tkStringLiteral, 0, Length(S), S);
    CheckToken(L, 1, tkSymbol, Length(S), 1, ';');
    CheckToken(L, 2, tkIdentifier, Length(S) + 1, 1, 'X');
    CheckCoverage(L);
  finally L.Free; end;
  CheckSingle(Q + #10 + 'text' + #10 + StringOfChar(#39, 5),
    tkStringLiteral, 'LEX003');
end;

initialization
  TDUnitX.RegisterTestFixture(TLexerBasics);

end.
