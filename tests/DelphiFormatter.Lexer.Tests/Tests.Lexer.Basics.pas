unit Tests.Lexer.Basics;

interface

uses
  DUnitX.TestFramework,
  DelphiFormatter.Lexer.Tokens;

type
  [TestFixture]
  TLexerBasics = class
  private
    procedure CheckCoverage(Lexed: TDelphiLexResult);
    procedure CheckToken(Lexed: TDelphiLexResult; Index: Integer;
      Kind: TTokenKind; Start, Count: Integer; const Text: string);
    procedure CheckWords(const Words: array of string; Kind: TTokenKind);
  public
    [Test] procedure EmptySource;
    [Test] procedure HorizontalBlanks;
    [Test] procedure MixedNewlines;
    [Test] procedure UnitDeclaration;
    [Test] procedure ReservedWords;
    [Test] procedure ContextualWords;
    [Test] procedure EscapedIdentifiers;
    [Test] procedure AssignmentWithDeferredNumber;
    [Test] procedure LongestSymbols;
    [Test] procedure SingleSymbolsAndLookaheadAtEOF;
    [Test] procedure BasicUnicodeIdentifiers;
    [Test] procedure InvalidUTF16;
    [Test] procedure DeferredCategoriesRemainLossless;
    [Test] procedure RangeDotsBeforeNumberScanner;
    [Test] procedure SourceSnapshotAndValueAccess;
    [Test] procedure AccessorBounds;
    [Test] procedure SpanValidation;
    [Test] procedure SmallUnitFixture;
  end;

implementation

uses
  System.SysUtils,
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
    CheckToken(L, 5, tkUnknown, 12, 1, '1');
    CheckToken(L, 7, tkUnknown, 14, 1, '&');
    Assert.AreEqual(3, L.DiagnosticCount);
    CheckCoverage(L);
  finally L.Free; end;
end;

procedure TLexerBasics.AssignmentWithDeferredNumber;
var
  L: TDelphiLexResult;
  D: TDiagnostic;
begin
  L := TDelphiLexer.Tokenize('Result:=A+1;');
  try
    Assert.AreEqual(7, L.TokenCount);
    CheckToken(L, 0, tkIdentifier, 0, 6, 'Result');
    CheckToken(L, 1, tkSymbol, 6, 2, ':=');
    CheckToken(L, 2, tkIdentifier, 8, 1, 'A');
    CheckToken(L, 3, tkSymbol, 9, 1, '+');
    CheckToken(L, 4, tkUnknown, 10, 1, '1');
    CheckToken(L, 5, tkSymbol, 11, 1, ';');
    Assert.AreEqual(1, L.DiagnosticCount);
    D := L.GetDiagnostic(0);
    Assert.AreEqual('LEX006', D.Code);
    Assert.AreEqual(Ord(dsWarning), Ord(D.Severity));
    Assert.AreEqual(10, D.Span.StartOffset);
    Assert.AreEqual(1, D.Span.Length);
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
  Source := Char($D83D) + Char($DE00) + Char($D800) + Char($DC00) + Char($FFFF);
  L := TDelphiLexer.Tokenize(Source);
  try
    Assert.AreEqual(6, L.TokenCount);
    Assert.AreEqual(5, L.DiagnosticCount);
    for I := 0 to 4 do
    begin
      CheckToken(L, I, tkUnknown, I, 1, Copy(Source, I + 1, 1));
      D := L.GetDiagnostic(I);
      Assert.AreEqual('LEX005', D.Code);
      Assert.AreEqual(Ord(dsError), Ord(D.Severity));
      Assert.AreEqual(I, D.Span.StartOffset);
      Assert.AreEqual(1, D.Span.Length);
    end;
    CheckCoverage(L);
  finally L.Free; end;
end;

procedure TLexerBasics.DeferredCategoriesRemainLossless;
var Source: string; L: TDelphiLexResult;
begin
  for Source in TArray<string>.Create('''abc', '// comment'#13#10,
    '{$IFDEF DEBUG}', '(* unfinished', '$FF %10 1.2e-3 #13', '''''''') do
  begin
    L := TDelphiLexer.Tokenize(Source);
    try
      Assert.IsTrue(L.DiagnosticCount > 0);
      CheckToken(L, 0, tkUnknown, 0, 1, Copy(Source, 1, 1));
      Assert.AreEqual('LEX006', L.GetDiagnostic(0).Code);
      CheckCoverage(L);
    finally L.Free; end;
  end;
end;

procedure TLexerBasics.RangeDotsBeforeNumberScanner;
var L: TDelphiLexResult;
begin
  L := TDelphiLexer.Tokenize('1..10');
  try
    Assert.AreEqual(5, L.TokenCount);
    Assert.AreEqual(3, L.DiagnosticCount);
    CheckToken(L, 0, tkUnknown, 0, 1, '1');
    CheckToken(L, 1, tkSymbol, 1, 2, '..');
    CheckToken(L, 2, tkUnknown, 3, 1, '1');
    CheckToken(L, 3, tkUnknown, 4, 1, '0');
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

initialization
  TDUnitX.RegisterTestFixture(TLexerBasics);

end.
