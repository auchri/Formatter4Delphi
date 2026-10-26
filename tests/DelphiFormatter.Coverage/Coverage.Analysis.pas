unit Coverage.Analysis;

interface

uses System.SysUtils, System.JSON, DelphiFormatter.Syntax.Tree;

type
  ECoverageInvariant = class(Exception);

// Returned objects are owned by the caller. No source file is ever written.
function AnalyzeSource(const Source: string): TJSONObject;
function AnalyzeTree(Tree: TSyntaxTree; const Source: string): TJSONObject;
function DecodeSource(const Bytes: TBytes; CodePage: Integer;
  out Source, EncodingName, Status: string): Boolean;
function AnalyzeFile(const Path: string; CodePage, RepeatCount: Integer): TJSONObject;
function Percentage(Numerator, Denominator: Int64): TJSONValue;

implementation

uses System.Classes, System.IOUtils, System.Diagnostics, System.TypInfo, System.Hash,
  System.Generics.Collections, System.Generics.Defaults,
  DelphiFormatter.Core.Diagnostics, DelphiFormatter.Lexer.Scanner,
  DelphiFormatter.Lexer.Tokens, DelphiFormatter.Syntax.Nodes,
  DelphiFormatter.Syntax.Kinds, DelphiFormatter.Parser.Delphi;

type
  TFrame = record
    Element: TSyntaxElement;
    Parent: TSyntaxKind;
    Category: Integer; // structured=0, opaque=1, error=2
    OpaqueDepth: Integer;
  end;

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then raise ECoverageInvariant.Create(MessageText);
end;

function KindName(Kind: TSyntaxKind): string;
begin
  Result := GetEnumName(TypeInfo(TSyntaxKind), Ord(Kind));
end;

function Percentage(Numerator, Denominator: Int64): TJSONValue;
begin
  if Denominator = 0 then Result := TJSONNull.Create
  else Result := TJSONNumber.Create(100.0 * Numerator / Denominator);
end;

function AnalyzeTree(Tree: TSyntaxTree; const Source: string): TJSONObject;
const Names: array[0..2] of string = ('structured', 'opaque', 'error');
var
  Stack: TStack<TFrame>;
  Seen: TDictionary<TSyntaxElement, Byte>;
  Lex: TDelphiLexResult;
  Frame, Child: TFrame;
  Element: TSyntaxElement;
  Node: TSyntaxNode;
  Leaf: TSyntaxToken;
  Original: TDelphiToken;
  Counts, Code: array[0..2] of Int64;
  I, J, NextToken, Offset, PreviousEnd, Category, Nodes, OpaqueCount,
    Errors, Missing, TriviaTokens, CodeTokens, DirectiveTokens,
    Line, Column, Posn, LexDiagnostics, ParserDiagnostics, ParserErrors: Integer;
  TriviaUnits, DirectiveUnits, ProtectedConditionalUnits: Int64;
  ProtectedConditionals, StructuredUnits: Integer;
  Regions, Diagnostics, Codes, TokenCategories: TJSONArray;
  Region, Diagnostic, TokenRun: TJSONObject;
  RunCategory, RunCount: Integer;
  BadTokens: TArray<Boolean>;
  FirstToken, LastToken, Probe: Integer;
  D: TDiagnostic;
  HasDirectives, CompleteOpaque, Damaged: Boolean;
  Reason: string;
  LineStarts: TList<Integer>;
  LowLine, HighLine, Middle: Integer;
  Shape: TStringBuilder;
begin
  Result := TJSONObject.Create;
  Stack := TStack<TFrame>.Create;
  Seen := TDictionary<TSyntaxElement, Byte>.Create;
  LineStarts := TList<Integer>.Create;
  Lex := nil;
  Shape := TStringBuilder.Create;
  try
   try
    // Independent token oracle, created after the parse's lexer has been freed.
    Lex := TDelphiLexer.Tokenize(Source);
    FillChar(Counts, SizeOf(Counts), 0); FillChar(Code, SizeOf(Code), 0);
    NextToken := 0; Offset := 0; Nodes := 0; OpaqueCount := 0;
    Errors := 0; Missing := 0; TriviaTokens := 0; CodeTokens := 0;
    DirectiveTokens := 0; TriviaUnits := 0; DirectiveUnits := 0;
    ProtectedConditionalUnits := 0; ProtectedConditionals := 0; StructuredUnits := 0;
    HasDirectives := False; CompleteOpaque := False;
    LexDiagnostics := Lex.DiagnosticCount; ParserDiagnostics := 0; ParserErrors := 0;
    LineStarts.Add(0); Posn := 1;
    while Posn <= Length(Source) do
    begin
      if Source[Posn] = #13 then
      begin
        if (Posn < Length(Source)) and (Source[Posn + 1] = #10) then Inc(Posn);
        LineStarts.Add(Posn);
      end
      else if Source[Posn] = #10 then LineStarts.Add(Posn);
      Inc(Posn);
    end;
    Regions := TJSONArray.Create; Result.AddPair('opaqueRegions', Regions);
    TokenCategories := TJSONArray.Create; Result.AddPair('tokenCategories', TokenCategories);
    TokenRun := nil; RunCategory := -1; RunCount := 0;
    Diagnostics := TJSONArray.Create; Result.AddPair('diagnostics', Diagnostics);
    SetLength(BadTokens, Lex.TokenCount);
    for I := 0 to Tree.DiagnosticCount - 1 do
    begin
      D := Tree.GetDiagnostic(I);
      Require((D.Span.StartOffset >= 0) and (D.Span.EndOffset <= Length(Source)), 'diagnostic span');
      if I >= LexDiagnostics then
      begin
        Inc(ParserDiagnostics);
        if D.Severity = dsError then Inc(ParserErrors);
      end;
      Diagnostic := TJSONObject.Create;
      Diagnostic.AddPair('code', D.Code); Diagnostic.AddPair('message', D.Message);
      Diagnostic.AddPair('severity', GetEnumName(TypeInfo(TDiagnosticSeverity), Ord(D.Severity)));
      Diagnostic.AddPair('start', TJSONNumber.Create(D.Span.StartOffset));
      Diagnostic.AddPair('length', TJSONNumber.Create(D.Span.Length));
      Diagnostics.AddElement(Diagnostic);
      if D.Severity = dsError then
      begin
        // Binary search the first possibly intersecting original token.
        FirstToken := 0; LastToken := Lex.TokenCount - 1;
        while FirstToken < LastToken do
        begin
          Probe := (FirstToken + LastToken) div 2;
          if Lex.GetToken(Probe).Span.EndOffset <= D.Span.StartOffset then FirstToken := Probe + 1
          else LastToken := Probe;
        end;
        while FirstToken < Lex.TokenCount do
        begin
          if Lex.GetToken(FirstToken).Span.StartOffset >= D.Span.EndOffset then Break;
          BadTokens[FirstToken] := True; Inc(FirstToken);
        end;
      end;
    end;
    Require(Tree.Source = Source, 'source snapshot');
    Require((Tree.Root.Span.StartOffset = 0) and
      (Tree.Root.Span.EndOffset = Length(Source)), 'root extent');
    Frame.Element := Tree.Root; Frame.Category := 0; Frame.Parent := Tree.Root.Kind; Frame.OpaqueDepth := 0;
    Stack.Push(Frame);
    while Stack.Count > 0 do
    begin
      Frame := Stack.Pop; Element := Frame.Element;
      Shape.Append(Ord(Element.Kind)).Append(':').Append(Element.Span.StartOffset)
        .Append(':').Append(Element.Span.Length).Append(';');
      Require(not Seen.ContainsKey(Element), 'duplicate element / cycle'); Seen.Add(Element, 0);
      Require((Element.Span.StartOffset >= 0) and
        (Element.Span.EndOffset <= Length(Source)), 'element span');
      Category := Frame.Category;
      if Element.Kind = skError then Category := 2
      else if (Element.Kind in [skOpaqueRegion, skConditionalDirectiveRegion]) and
        (Category < 1) then Category := 1;
      if Element is TSyntaxNode then
      begin
        Node := TSyntaxNode(Element); Inc(Nodes);
        if Node.Kind = skUnitDeclaration then Inc(StructuredUnits);
        if Node.Kind = skConditionalDirectiveRegion then
        begin
          Inc(ProtectedConditionals);
          Inc(ProtectedConditionalUnits, Node.Span.Length);
        end;
        if Node.Kind = skError then Inc(Errors);
        // A missing/error descendant taints this immediate node's other leaves.
        // Propagation upwards would mark the entire document unsafe and hide useful structure.
        Damaged := False;
        for I := 0 to Node.ChildCount - 1 do
          if Node.GetChild(I).Kind in [skMissingToken, skError] then Damaged := True;
        if Damaged then Category := 2;
        if Node.Kind = skOpaqueRegion then
        begin
          Inc(OpaqueCount);
          if (Node.Span.StartOffset = 0) and (Node.Span.Length = Length(Source)) then
            CompleteOpaque := True;
          Region := TJSONObject.Create;
          Region.AddPair('outermost', TJSONBool.Create(Frame.OpaqueDepth = 0));
          Region.AddPair('start', TJSONNumber.Create(Node.Span.StartOffset));
          Region.AddPair('end', TJSONNumber.Create(Node.Span.EndOffset));
          Region.AddPair('length', TJSONNumber.Create(Node.Span.Length));
          LowLine := 0; HighLine := LineStarts.Count - 1;
          while LowLine < HighLine do
          begin
            Middle := (LowLine + HighLine + 1) div 2;
            if LineStarts[Middle] <= Node.Span.StartOffset then LowLine := Middle
            else HighLine := Middle - 1;
          end;
          Line := LowLine + 1; Column := Node.Span.StartOffset - LineStarts[LowLine] + 1;
          Region.AddPair('line', TJSONNumber.Create(Line));
          Region.AddPair('column', TJSONNumber.Create(Column));
          Region.AddPair('parent', KindName(Frame.Parent));
          Region.AddPair('snippet', Copy(Source, Node.Span.StartOffset + 1, 160));
          // Context is evidence; isolated keyword occurrences are not.
          Reason := 'unknown';
          if Frame.Parent = skConditionalDirectiveRegion then Reason := 'protected-conditional';
          if Frame.Parent = skMethodDeclaration then Reason := 'method-directives'
          else if Frame.Parent = skTypeDeclaration then Reason := 'unsupported-type'
          else if Frame.Parent in [skBlockStatement, skStatementList] then Reason := 'unsupported-statement';
          // A section-start token plus the enclosing unit is stronger evidence
          // than finding a keyword somewhere in the opaque text.
          if Frame.Parent = skUnitDeclaration then
          begin
            FirstToken := 0; LastToken := Lex.TokenCount - 1;
            while FirstToken < LastToken do
            begin
              Probe := (FirstToken + LastToken) div 2;
              if Lex.GetToken(Probe).Span.StartOffset < Node.Span.StartOffset then FirstToken := Probe + 1
              else LastToken := Probe;
            end;
            while (FirstToken < Lex.TokenCount - 1) and
              (Lex.GetToken(FirstToken).Kind in [tkComment, tkWhitespace, tkNewLine]) do Inc(FirstToken);
            if (Lex.GetToken(FirstToken).Span.StartOffset < Node.Span.EndOffset) and
              (Lex.GetToken(FirstToken).Kind = tkReservedWord) and
              SameText(Lex.TokenText(FirstToken), 'resourcestring') then Reason := 'resource-string-section';
          end;
          Region.AddPair('category', Reason);
          Codes := TJSONArray.Create; Region.AddPair('diagnosticCodes', Codes);
          for J := 0 to Tree.DiagnosticCount - 1 do
          begin
            D := Tree.GetDiagnostic(J);
            if (D.Span.StartOffset < Node.Span.EndOffset) and
              (D.Span.EndOffset >= Node.Span.StartOffset) then Codes.Add(D.Code);
          end;
          Regions.AddElement(Region);
        end;
        PreviousEnd := Node.Span.StartOffset;
        for I := 0 to Node.ChildCount - 1 do
        begin
          Require(Node.GetChild(I).Span.StartOffset >= PreviousEnd, 'child order/overlap');
          Require(Node.GetChild(I).Span.EndOffset <= Node.Span.EndOffset, 'child containment');
          PreviousEnd := Node.GetChild(I).Span.EndOffset;
        end;
        for I := Node.ChildCount - 1 downto 0 do
        begin
          Child.Element := Node.GetChild(I); Child.Category := Category; Child.Parent := Node.Kind;
          Child.OpaqueDepth := Frame.OpaqueDepth + Ord(Node.Kind = skOpaqueRegion);
          Stack.Push(Child);
        end;
      end
      else
      begin
        Require(Element is TSyntaxToken, 'unknown leaf class'); Leaf := TSyntaxToken(Element);
        if Leaf.IsMissing then
        begin
          Inc(Missing); Require((Leaf.Span.Length = 0) and (Leaf.OriginalIndex = -1), 'missing token');
          Continue;
        end;
        Require(NextToken < Lex.TokenCount, 'extra original token');
        Original := Lex.GetToken(NextToken);
        if BadTokens[NextToken] then Category := 2;
        Require((Leaf.OriginalIndex = NextToken) and
          (Leaf.OriginalToken.Kind = Original.Kind) and
          (Leaf.Span.StartOffset = Original.Span.StartOffset) and
          (Leaf.Span.Length = Original.Span.Length), 'original token order/kind/span');
        Require(Original.Span.StartOffset = Offset, 'token coverage gap/overlap');
        if Category <> RunCategory then
        begin
          if TokenRun <> nil then TokenRun.AddPair('count', TJSONNumber.Create(RunCount));
          TokenRun := TJSONObject.Create; TokenCategories.AddElement(TokenRun);
          TokenRun.AddPair('firstToken', TJSONNumber.Create(NextToken));
          TokenRun.AddPair('category', Names[Category]);
          RunCategory := Category; RunCount := 0;
        end;
        Inc(RunCount);
        Offset := Original.Span.EndOffset; Inc(NextToken);
        if Original.Kind = tkEOF then Continue;
        Inc(Counts[Category], Original.Span.Length);
        if Original.Kind in [tkComment, tkWhitespace, tkNewLine] then
        begin Inc(TriviaTokens); Inc(TriviaUnits, Original.Span.Length); end
        else if Original.Kind = tkCompilerDirective then
        begin
          HasDirectives := True; Inc(DirectiveTokens); Inc(DirectiveUnits, Original.Span.Length);
        end
        else begin Inc(CodeTokens); Inc(Code[Category], Original.Span.Length); end;
      end;
    end;
    Require((NextToken = Lex.TokenCount) and (Offset = Length(Source)), 'incomplete token coverage');
    if TokenRun <> nil then TokenRun.AddPair('count', TJSONNumber.Create(RunCount));
    Require(Tree.Serialize = Source, 'leaf serialization after lexer disposal');
    Require(Counts[0] + Counts[1] + Counts[2] = Length(Source), 'category partition');
    // The parser keeps trailing ordinary trivia beside the opaque node and EOF.
    // Full fallback therefore means a root with only one opaque node, not a
    // character span equal to the entire source including trailing whitespace.
    CompleteOpaque := (OpaqueCount = 1) and (Nodes = 2) and (Code[0] = 0);
    if HasDirectives and CompleteOpaque then
      for I := 0 to Regions.Count - 1 do
      begin
        Region := TJSONObject(Regions.Items[I]);
        Region.RemovePair('category').Free; Region.AddPair('category', 'directive-fallback');
      end;
    Result.AddPair('utf16Units', TJSONNumber.Create(Length(Source)));
    Result.AddPair('tokens', TJSONNumber.Create(Lex.TokenCount));
    Result.AddPair('nonTriviaTokens', TJSONNumber.Create(CodeTokens + DirectiveTokens));
    Result.AddPair('codeTokens', TJSONNumber.Create(CodeTokens));
    Result.AddPair('triviaTokens', TJSONNumber.Create(TriviaTokens));
    Result.AddPair('directiveTokens', TJSONNumber.Create(DirectiveTokens));
    Result.AddPair('triviaUnits', TJSONNumber.Create(TriviaUnits));
    Result.AddPair('directiveUnits', TJSONNumber.Create(DirectiveUnits));
    Result.AddPair('codeUnits', TJSONNumber.Create(Code[0] + Code[1] + Code[2]));
    for I := 0 to 2 do
    begin
      Result.AddPair(Names[I] + 'Units', TJSONNumber.Create(Counts[I]));
      Result.AddPair(Names[I] + 'CodeUnits', TJSONNumber.Create(Code[I]));
      Result.AddPair(Names[I] + 'Percent', Percentage(Code[I], Code[0] + Code[1] + Code[2]));
      Result.AddPair(Names[I] + 'IncludingTriviaPercent', Percentage(Counts[I], Length(Source)));
    end;
    Result.AddPair('nodes', TJSONNumber.Create(Nodes));
    Result.AddPair('structuredUnitDeclarations', TJSONNumber.Create(StructuredUnits));
    Result.AddPair('protectedConditionalRegions', TJSONNumber.Create(ProtectedConditionals));
    Result.AddPair('protectedConditionalUnits', TJSONNumber.Create(ProtectedConditionalUnits));
    Result.AddPair('opaqueNodes', TJSONNumber.Create(OpaqueCount));
    Result.AddPair('errorNodes', TJSONNumber.Create(Errors));
    Result.AddPair('missingTokens', TJSONNumber.Create(Missing));
    Result.AddPair('lexerDiagnostics', TJSONNumber.Create(LexDiagnostics));
    Result.AddPair('parserDiagnostics', TJSONNumber.Create(ParserDiagnostics));
    Result.AddPair('parserErrors', TJSONNumber.Create(ParserErrors));
    Result.AddPair('hasDirectives', TJSONBool.Create(HasDirectives));
    Result.AddPair('completeOpaque', TJSONBool.Create(CompleteOpaque));
    Result.AddPair('directiveFallback', TJSONBool.Create(HasDirectives and CompleteOpaque));
    Result.AddPair('lossless', TJSONBool.Create(True));
    Result.AddPair('structureSha256', THashSHA2.GetHashString(Shape.ToString));
    Reason := 'structured';
    if OpaqueCount > 0 then Reason := 'opaque';
    if ParserErrors > 0 then Reason := 'syntax_diagnostics';
    if LexDiagnostics > 0 then Reason := 'lexer_error';
    Result.AddPair('status', Reason);
  except
    Result.Free; raise;
   end;
  finally
    Shape.Free; Lex.Free; LineStarts.Free; Seen.Free; Stack.Free;
  end;
end;

function ParseSource(const Source: string; out LexMs, ParseMs: Double): TSyntaxTree;
var Lex: TDelphiLexResult; Clock: TStopwatch;
begin
  Clock := TStopwatch.StartNew; Lex := TDelphiLexer.Tokenize(Source);
  LexMs := Clock.Elapsed.TotalMilliseconds;
  try
    Clock := TStopwatch.StartNew; Result := TDelphiParser.Parse(Lex);
    ParseMs := Clock.Elapsed.TotalMilliseconds;
  finally Lex.Free; end;
end;

function AnalyzeSource(const Source: string): TJSONObject;
var Tree: TSyntaxTree; LexMs, ParseMs: Double;
begin
  Tree := ParseSource(Source, LexMs, ParseMs);
  try Result := AnalyzeTree(Tree, Source); finally Tree.Free; end;
end;

function DecodeSource(const Bytes: TBytes; CodePage: Integer;
  out Source, EncodingName, Status: string): Boolean;
var Enc: TEncoding; Skip, I, Value: Integer; Payload, Roundtrip: TBytes;
begin
  Result := False; Source := ''; Status := 'decode_failed'; Skip := 0;
  EncodingName := '';
  // Reject UTF-32 before considering the UTF-16 LE prefix.
  if (Length(Bytes) >= 4) and
    (((Bytes[0] = $FF) and (Bytes[1] = $FE) and (Bytes[2] = 0) and (Bytes[3] = 0)) or
     ((Bytes[0] = 0) and (Bytes[1] = 0) and (Bytes[2] = $FE) and (Bytes[3] = $FF))) then Exit;
  if (Length(Bytes) >= 2) and
    (((Bytes[0] = $FF) and (Bytes[1] = $FE)) or ((Bytes[0] = $FE) and (Bytes[1] = $FF))) then
  begin
    Skip := 2; if Odd(Length(Bytes) - Skip) then Exit;
    if Bytes[0] = $FF then EncodingName := 'utf-16le-bom' else EncodingName := 'utf-16be-bom';
    SetLength(Source, (Length(Bytes) - Skip) div 2);
    for I := 1 to Length(Source) do
    begin
      if Bytes[0] = $FF then Value := Bytes[2*I] + 256*Bytes[2*I+1]
      else Value := 256*Bytes[2*I] + Bytes[2*I+1];
      Source[I] := Char(Value); // preserves even isolated surrogate code units
    end;
    Status := 'ok'; Exit(True);
  end;
  if (Length(Bytes) >= 3) and (Bytes[0] = $EF) and (Bytes[1] = $BB) and (Bytes[2] = $BF) then
  begin Skip := 3; EncodingName := 'utf-8-bom'; end
  else if CodePage > 0 then EncodingName := 'explicit-cp' + IntToStr(CodePage)
  else EncodingName := 'utf-8-strict';
  if (Skip = 3) or (CodePage = 0) or (CodePage = 65001) then
    Enc := TUTF8Encoding.Create(False)
  else Enc := TEncoding.GetEncoding(CodePage);
  try
    try
      Payload := Copy(Bytes, Skip, Length(Bytes) - Skip);
      if (Skip = 0) and (CodePage = 0) then Status := 'encoding_ambiguous';
      Source := Enc.GetString(Payload); Roundtrip := Enc.GetBytes(Source);
      if Length(Payload) <> Length(Roundtrip) then Exit;
      for I := 0 to High(Payload) do if Payload[I] <> Roundtrip[I] then Exit;
      // BOMless UTF-8 is a declared policy, not a claim of encoding detection.
      Status := 'ok'; Result := True;
    except
      on E: EEncodingError do
        if Skip = 0 then Status := 'encoding_ambiguous';
    end;
  finally Enc.Free; end;
end;

function Median(const Values: TArray<Double>): Double;
var Sorted: TArray<Double>; N: Integer;
begin
  Sorted := Copy(Values); TArray.Sort<Double>(Sorted); N := Length(Sorted);
  if Odd(N) then Result := Sorted[N div 2]
  else Result := (Sorted[N div 2 - 1] + Sorted[N div 2]) / 2;
end;

function AllocatedHeap: Int64;
var State: TMemoryManagerState; Block: TSmallBlockTypeState;
begin
  GetMemoryManagerState(State);
  Result := Int64(State.TotalAllocatedMediumBlockSize) + Int64(State.TotalAllocatedLargeBlockSize);
  for Block in State.SmallBlockTypeStates do
    Inc(Result, Int64(Block.AllocatedBlockCount) * Block.UseableBlockSize);
end;

function AnalyzeFile(const Path: string; CodePage, RepeatCount: Integer): TJSONObject;
var
  Bytes: TBytes; Source, EncodingName, Status, Fingerprint: string;
  Tree: TSyntaxTree; Sample: TJSONObject; LexTimes, ParseTimes, TotalTimes: TArray<Double>;
  I: Integer; Clock: TStopwatch; TotalClock: TStopwatch; TotalMs: Double;
  HeapBefore, RetainedHeap, MaxRetainedHeap: Int64;
begin
  Result := nil; EncodingName := ''; Status := 'file_error'; Sample := nil;
  try
    Require(RepeatCount >= 1, 'repeat must be positive');
    TotalClock := TStopwatch.StartNew;
    Bytes := TFile.ReadAllBytes(Path);
    if not DecodeSource(Bytes, CodePage, Source, EncodingName, Status) then
    begin
      Result := TJSONObject.Create; Result.AddPair('status', Status);
      Result.AddPair('bytes', TJSONNumber.Create(Length(Bytes)));
    end
    else
    begin
      SetLength(LexTimes, RepeatCount); SetLength(ParseTimes, RepeatCount);
      SetLength(TotalTimes, RepeatCount); Fingerprint := ''; MaxRetainedHeap := 0;
      for I := 0 to RepeatCount - 1 do
      begin
        Status := 'parser_exception'; Clock := TStopwatch.StartNew;
        HeapBefore := AllocatedHeap;
        Tree := ParseSource(Source, LexTimes[I], ParseTimes[I]);
        try
          RetainedHeap := AllocatedHeap - HeapBefore;
          if RetainedHeap > MaxRetainedHeap then MaxRetainedHeap := RetainedHeap;
          Status := 'invariant_failed'; Sample := AnalyzeTree(Tree, Source);
        finally Tree.Free; end;
        TotalTimes[I] := Clock.Elapsed.TotalMilliseconds;
        if I = 0 then begin Fingerprint := Sample.ToJSON; Result := Sample; Sample := nil; end
        else
        begin
          Require(Sample.ToJSON = Fingerprint, 'nondeterministic structure/diagnostics/metrics');
          FreeAndNil(Sample);
        end;
      end;
      Result.AddPair('bytes', TJSONNumber.Create(Length(Bytes)));
      Result.AddPair('lexerMs', TJSONNumber.Create(Median(LexTimes)));
      Result.AddPair('parserMs', TJSONNumber.Create(Median(ParseTimes)));
      Result.AddPair('analysisMs', TJSONNumber.Create(Median(TotalTimes)));
      TotalMs := Median(LexTimes) + Median(ParseTimes);
      if TotalMs > 0 then Result.AddPair('tokensPerSecond', TJSONNumber.Create(
        Result.GetValue<Integer>('tokens') * 1000.0 / TotalMs));
      Result.AddPair('repeatCount', TJSONNumber.Create(RepeatCount));
      Result.AddPair('retainedTreeHeapBytes', TJSONNumber.Create(MaxRetainedHeap));
      Result.AddPair('deterministic', TJSONBool.Create(RepeatCount > 1));
      Result.AddPair('totalMs', TJSONNumber.Create(TotalClock.Elapsed.TotalMilliseconds));
    end;
  except
    on E: Exception do
    begin
      Sample.Free; Result.Free; Result := TJSONObject.Create;
      Result.AddPair('status', Status); Result.AddPair('exception', E.ClassName + ': ' + E.Message);
    end;
  end;
  Result.AddPair('encoding', EncodingName);
  Result.AddPair('path', Path);
end;

end.
