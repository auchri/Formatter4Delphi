unit Tests.Coverage;

interface

uses DUnitX.TestFramework;

type
  [TestFixture]
  TCoverageTests = class
  public
    [Test] procedure StructuredManualCounts;
    [Test] procedure PartialOpaque;
    [Test] procedure DirectiveFallback;
    [Test] procedure ProtectedConditionalCoverage;
    [Test] procedure MissingTokens;
    [Test] procedure NestedOpaquePartition;
    [Test] procedure ErrorWinsOverOpaque;
    [Test] procedure TriviaAndLines;
    [Test] procedure Utf16AndEmpty;
    [Test] procedure DecodePolicies;
    [Test] procedure FileFailure;
    [Test] procedure DeterministicJsonCsv;
    [Test] procedure WeightedAggregation;
    [Test] procedure InvalidTreeRejected;
    [Test] procedure RepeatedFile;
    [Test] procedure ResourceStringContext;
    [Test] procedure OriginalTokenCategoryRuns;
    [Test] procedure LocalReportWithoutRepositories;
  end;

implementation

uses System.SysUtils, System.Classes, System.JSON, System.IOUtils,
  DelphiFormatter.Lexer.Scanner, DelphiFormatter.Lexer.Tokens,
  DelphiFormatter.Syntax.Nodes, DelphiFormatter.Syntax.Tree,
  DelphiFormatter.Syntax.Kinds, Coverage.Analysis, Coverage.Reports;

const Minimal = 'unit U; interface implementation end.';

procedure TCoverageTests.StructuredManualCounts;
var R: TJSONObject;
begin
  R := AnalyzeSource(Minimal);
  try
    // unit(4), U(1), ;(1), interface(9), implementation(14), end(3), .(1)
    Assert.AreEqual(33, R.GetValue<Integer>('codeUnits'));
    Assert.AreEqual(33, R.GetValue<Integer>('structuredCodeUnits'));
    Assert.AreEqual(4, R.GetValue<Integer>('triviaUnits'));
    Assert.AreEqual(0, R.GetValue<Integer>('opaqueCodeUnits'));
    Assert.AreEqual(100.0, R.GetValue<Double>('structuredPercent'));
  finally R.Free; end;
end;

procedure TCoverageTests.PartialOpaque;
var R: TJSONObject;
begin
  R := AnalyzeSource('unit U; interface type T = Integer; implementation end.');
  try
    Assert.IsTrue(R.GetValue<Integer>('structuredCodeUnits') > 0);
    Assert.IsTrue(R.GetValue<Integer>('opaqueCodeUnits') > 0);
    Assert.IsFalse(R.GetValue<Boolean>('completeOpaque'));
  finally R.Free; end;
end;

procedure TCoverageTests.ProtectedConditionalCoverage;
var R: TJSONObject;
begin
  R := AnalyzeSource('unit U; interface {$IFDEF X} procedure A; {$ELSE}' +
    'procedure B; {$ENDIF} procedure C; implementation end.');
  try
    Assert.IsFalse(R.GetValue<Boolean>('directiveFallback'));
    Assert.AreEqual(1, R.GetValue<Integer>('structuredUnitDeclarations'));
    Assert.AreEqual(1, R.GetValue<Integer>('protectedConditionalRegions'));
    // Two unknown branches are protected: procedure(9), name(1), semicolon(1).
    Assert.AreEqual(22, R.GetValue<Integer>('opaqueCodeUnits'));
    Assert.AreEqual(44, R.GetValue<Integer>('structuredCodeUnits'));
    Assert.AreEqual(0, R.GetValue<Integer>('errorCodeUnits'));
    Assert.IsTrue(R.GetValue<Boolean>('lossless'));
  finally R.Free; end;
end;
procedure TCoverageTests.DirectiveFallback;
var R: TJSONObject;
begin
  R := AnalyzeSource('{$IFDEF X}' + Minimal + #13#10);
  try
    Assert.IsTrue(R.GetValue<Boolean>('directiveFallback'));
    Assert.AreEqual(33, R.GetValue<Integer>('opaqueCodeUnits'));
    Assert.AreEqual(0, R.GetValue<Integer>('structuredCodeUnits'));
    Assert.AreEqual(10, R.GetValue<Integer>('directiveUnits'));
  finally R.Free; end;
end;

procedure TCoverageTests.MissingTokens;
var R: TJSONObject;
begin
  R := AnalyzeSource('unit U interface implementation end.');
  try
    Assert.IsTrue(R.GetValue<Integer>('missingTokens') > 0);
    Assert.IsTrue(R.GetValue<Integer>('errorCodeUnits') > 0);
    Assert.IsTrue(R.GetValue<Boolean>('lossless'));
  finally R.Free; end;
end;

function Synthetic(InnerError, Duplicate: Boolean): TSyntaxTree;
var Lex: TDelphiLexResult; A, W, B, Eof: TSyntaxToken;
  Inner, Outer, Root: TSyntaxNode; InnerKind: TSyntaxKind;
begin
  Lex := TDelphiLexer.Tokenize('A B');
  try
    A := TSyntaxToken.CreateOriginal(Lex.GetToken(0),0);
    W := TSyntaxToken.CreateOriginal(Lex.GetToken(1),1);
    B := TSyntaxToken.CreateOriginal(Lex.GetToken(2),2);
    Eof := TSyntaxToken.CreateOriginal(Lex.GetToken(3),3);
    InnerKind := skOpaqueRegion; if InnerError then InnerKind := skError;
    Inner := TSyntaxNode.Create(InnerKind, [B], 2);
    Outer := TSyntaxNode.Create(skOpaqueRegion, [A,W,Inner],0);
    if Duplicate then Root := TSyntaxNode.Create(skCompilationUnit,[Outer,B,Eof],0)
    else Root := TSyntaxNode.Create(skCompilationUnit,[Outer,Eof],0);
    Result := TSyntaxTree.Create('A B',Root,[A,W,B,Eof,Inner,Outer,Root],[]);
  finally Lex.Free; end;
end;

procedure TCoverageTests.NestedOpaquePartition;
var T: TSyntaxTree; R: TJSONObject;
begin
  T := Synthetic(False,False);
  try
    R := AnalyzeTree(T,'A B');
    try
      Assert.AreEqual(2,R.GetValue<Integer>('opaqueNodes'));
      Assert.AreEqual(2,R.GetValue<Integer>('opaqueCodeUnits'));
      Assert.AreEqual(3,R.GetValue<Integer>('opaqueUnits'));
      Assert.AreEqual(0,R.GetValue<Integer>('structuredUnits'));
    finally R.Free; end;
  finally T.Free; end;
end;

procedure TCoverageTests.ErrorWinsOverOpaque;
var T: TSyntaxTree; R: TJSONObject;
begin
  T := Synthetic(True,False);
  try
    R := AnalyzeTree(T,'A B');
    try
      // Direct skError child taints its immediate opaque owner, including A/space.
      Assert.AreEqual(2,R.GetValue<Integer>('errorCodeUnits'));
      Assert.AreEqual(0,R.GetValue<Integer>('opaqueCodeUnits'));
      Assert.AreEqual(3,R.GetValue<Integer>('errorUnits'));
    finally R.Free; end;
  finally T.Free; end;
end;

procedure TCoverageTests.TriviaAndLines;
var R: TJSONObject; Region: TJSONObject;
begin
  R := AnalyzeSource('// hi'#13#10 + 'unit U; interface'#13 + 'type T = Integer;'#10 + 'implementation end.');
  try
    Assert.IsTrue(R.GetValue<Integer>('triviaUnits') > 10);
    Region := TJSONObject(R.GetValue<TJSONArray>('opaqueRegions').Items[0]);
    Assert.AreEqual(3,Region.GetValue<Integer>('line'));
    Assert.IsTrue(Region.GetValue<Integer>('column') >= 1);
  finally R.Free; end;
end;

procedure TCoverageTests.Utf16AndEmpty;
var R: TJSONObject; S: string;
begin
  S := '{' + Char($D800) + Char($D83D) + Char($DE00) + '}' + Minimal;
  R := AnalyzeSource(S);
  try
    Assert.AreEqual(Length(S),R.GetValue<Integer>('utf16Units'));
    Assert.IsTrue(R.GetValue<Boolean>('lossless'));
  finally R.Free; end;
  R := AnalyzeSource('');
  try
    Assert.AreEqual(1,R.GetValue<Integer>('tokens'));
    Assert.IsTrue(R.GetValue('structuredPercent') is TJSONNull);
  finally R.Free; end;
end;

procedure TCoverageTests.DecodePolicies;
var S, E, Status: string;
begin
  Assert.IsTrue(DecodeSource(TBytes.Create($EF,$BB,$BF,$41),0,S,E,Status));
  Assert.AreEqual('A',S); Assert.AreEqual('utf-8-bom',E);
  Assert.IsTrue(DecodeSource(TBytes.Create($FF,$FE,$00,$D8),0,S,E,Status));
  Assert.AreEqual(1,Length(S)); Assert.AreEqual($D800,Ord(S[1]));
  Assert.IsTrue(DecodeSource(TBytes.Create($FE,$FF,$00,$41),0,S,E,Status));
  Assert.AreEqual('A',S);
  Assert.IsFalse(DecodeSource(TBytes.Create($FF,$FE,$41),0,S,E,Status));
  Assert.AreEqual('decode_failed',Status);
  Assert.IsFalse(DecodeSource(TBytes.Create($C0,$AF),0,S,E,Status));
  Assert.AreEqual('encoding_ambiguous',Status);
  Assert.IsTrue(DecodeSource(TBytes.Create($E4),1252,S,E,Status));
  Assert.AreEqual($E4,Ord(S[1]));
  Assert.IsFalse(DecodeSource(TBytes.Create($FF,$FE,0,0),0,S,E,Status));
end;

procedure TCoverageTests.FileFailure;
var R: TJSONObject;
begin
  R := AnalyzeFile('build/nonexistent-m2_7-file.pas',0,2);
  try Assert.AreEqual('file_error',R.GetValue<string>('status')); finally R.Free; end;
end;

procedure TCoverageTests.DeterministicJsonCsv;
var A, B: TJSONObject; Files: TJSONArray; Csv: string;
begin
  A := AnalyzeSource(Minimal); B := AnalyzeSource(Minimal); Files := TJSONArray.Create;
  try
    Assert.AreEqual(A.ToJSON,B.ToJSON);
    A.AddPair('path','a,"b.pas'); A.AddPair('repository','internal');
    Files.AddElement(A); A := nil;
    Csv := CsvReport(Files);
    Assert.IsTrue(Pos('"a,""b.pas"',Csv) > 0);
    Assert.AreEqual(Csv,CsvReport(Files));
  finally A.Free; B.Free; Files.Free; end;
end;

procedure TCoverageTests.WeightedAggregation;
var Files: TJSONArray; R, A, B: TJSONObject;
begin
  Files := TJSONArray.Create;
  try
    A := AnalyzeSource(Minimal); A.AddPair('repository','test'); Files.AddElement(A);
    B := AnalyzeSource('{$IFDEF X}'+Minimal+Minimal); B.AddPair('repository','test'); Files.AddElement(B);
    R := Aggregate(Files,'test','all');
    try
      Assert.AreEqual(99,R.GetValue<Integer>('codeUnits'));
      Assert.AreEqual(33,R.GetValue<Integer>('structuredCodeUnits'));
      Assert.AreEqual(100.0/3,R.GetValue<Double>('structuredPercent'),0.00001);
    finally R.Free; end;
    R := Aggregate(Files,'test','without-directives');
    try Assert.AreEqual(100.0,R.GetValue<Double>('structuredPercent')); finally R.Free; end;
  finally Files.Free; end;
end;

procedure TCoverageTests.InvalidTreeRejected;
var T: TSyntaxTree;
begin
  T := Synthetic(False,True);
  try
    Assert.WillRaise(procedure var R: TJSONObject;
      begin R := AnalyzeTree(T,'A B'); R.Free; end, ECoverageInvariant);
  finally T.Free; end;
end;

procedure TCoverageTests.RepeatedFile;
var Path: string; R: TJSONObject;
begin
  ForceDirectories('build'); Path := 'build/coverage-test-input.pas';
  TFile.WriteAllText(Path,Minimal,TEncoding.UTF8);
  R := AnalyzeFile(Path,0,3);
  try
    Assert.IsTrue(R.GetValue<Boolean>('deterministic'));
    Assert.AreEqual('structured',R.GetValue<string>('status'));
    Assert.AreEqual(3,R.GetValue<Integer>('repeatCount'));
  finally R.Free; TFile.Delete(Path); end;
end;

procedure TCoverageTests.ResourceStringContext;
var R: TJSONObject; Regions: TJSONArray;
begin
  R := AnalyzeSource('unit U; interface resourcestring S = ''hello''; implementation end.');
  try
    Regions := R.GetValue<TJSONArray>('opaqueRegions');
    Assert.AreEqual(1,Regions.Count);
    Assert.AreEqual('resource-string-section',TJSONObject(Regions.Items[0]).GetValue<string>('category'));
  finally R.Free; end;
  R := AnalyzeSource('unit U; interface type T = string; // resourcestring'#10'implementation end.');
  try
    Regions := R.GetValue<TJSONArray>('opaqueRegions');
    Assert.AreEqual('unsupported-type',TJSONObject(Regions.Items[0]).GetValue<string>('category'));
  finally R.Free; end;
end;

procedure TCoverageTests.OriginalTokenCategoryRuns;
var R: TJSONObject; Runs: TJSONArray; V: TJSONValue; Next: Integer;
begin
  R := AnalyzeSource('unit U; interface type T = Integer; implementation end.');
  try
    Runs := R.GetValue<TJSONArray>('tokenCategories'); Next := 0;
    Assert.IsTrue(Runs.Count >= 3);
    for V in Runs do
    begin
      Assert.AreEqual(Next,TJSONObject(V).GetValue<Integer>('firstToken'));
      Inc(Next,TJSONObject(V).GetValue<Integer>('count'));
    end;
    Assert.AreEqual(R.GetValue<Integer>('tokens'),Next);
  finally R.Free; end;
end;

procedure TCoverageTests.LocalReportWithoutRepositories;
var Report, F: TJSONObject; Files: TJSONArray; FirstJson, FirstCsv: string;
begin
  Report := TJSONObject.Create;
  try
    Report.AddPair('environment','test'); Files := TJSONArray.Create;
    Report.AddPair('files',Files); F := AnalyzeSource(Minimal);
    F.AddPair('repository','local'); F.AddPair('path','minimal.pas'); Files.AddElement(F);
    WriteReports(Report,'build/coverage-report-test');
    FirstJson := TFile.ReadAllText('build/coverage-report-test/coverage.json',TEncoding.UTF8);
    FirstCsv := TFile.ReadAllText('build/coverage-report-test/coverage.csv',TEncoding.UTF8);
    WriteReports(Report,'build/coverage-report-test');
    Assert.AreEqual(FirstJson,TFile.ReadAllText('build/coverage-report-test/coverage.json',TEncoding.UTF8));
    Assert.AreEqual(FirstCsv,TFile.ReadAllText('build/coverage-report-test/coverage.csv',TEncoding.UTF8));
  finally Report.Free; end;
end;

initialization
  TDUnitX.RegisterTestFixture(TCoverageTests);
end.
