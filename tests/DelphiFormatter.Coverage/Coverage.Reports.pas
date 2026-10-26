unit Coverage.Reports;

interface

uses System.JSON;

function Aggregate(Files: TJSONArray; const Repository, Group: string): TJSONObject;
function CsvReport(Files: TJSONArray): string;
procedure WriteReports(Report: TJSONObject; const OutputDirectory: string);

implementation

uses System.SysUtils, System.Math, System.Classes, System.IOUtils, System.Generics.Collections,
  System.Generics.Defaults, Coverage.Analysis;

function Number(Obj: TJSONObject; const Key: string): Int64;
begin Result := Obj.GetValue<Int64>(Key, 0); end;

function Aggregate(Files: TJSONArray; const Repository, Group: string): TJSONObject;
var Item: TJSONValue; F: TJSONObject; Total, Structured, Opaque, Errors: Int64;
  Count, Valid, Directives, Complete, OtherOpaque: Integer; Include: Boolean; Bytes: Int64;
begin
  Total := 0; Structured := 0; Opaque := 0; Errors := 0;
  Count := 0; Valid := 0; Directives := 0; Complete := 0; OtherOpaque := 0;
  for Item in Files do
  begin
    F := TJSONObject(Item);
    if Repository = 'external' then
    begin if F.GetValue<string>('repository', '') = 'internal' then Continue; end
    else if (Repository <> '') and (F.GetValue<string>('repository', '') <> Repository) then Continue;
    Bytes := Number(F, 'bytes'); Include := True;
    if Group = 'without-directives' then Include := (F.GetValue('hasDirectives') <> nil) and
      not F.GetValue<Boolean>('hasDirectives', False)
    else if Group = 'with-directives' then Include := F.GetValue<Boolean>('hasDirectives', False)
    else if Group = 'complete-opaque' then Include := F.GetValue<Boolean>('completeOpaque', False)
    else if Group = 'other-opaque' then Include := (Number(F, 'opaqueNodes') > 0) and
      not F.GetValue<Boolean>('completeOpaque', False)
    else if Group = 'small' then Include := Bytes < 16384
    else if Group = 'medium' then Include := (Bytes >= 16384) and (Bytes < 65536)
    else if Group = 'large' then Include := Bytes >= 65536;
    if not Include then Continue;
    Inc(Count);
    if not F.GetValue<Boolean>('lossless', False) then Continue;
    Inc(Valid);
    if F.GetValue<Boolean>('hasDirectives', False) then Inc(Directives);
    if F.GetValue<Boolean>('completeOpaque', False) then Inc(Complete)
    else if Number(F, 'opaqueNodes') > 0 then Inc(OtherOpaque);
    Inc(Total, Number(F, 'codeUnits')); Inc(Structured, Number(F, 'structuredCodeUnits'));
    Inc(Opaque, Number(F, 'opaqueCodeUnits')); Inc(Errors, Number(F, 'errorCodeUnits'));
  end;
  Result := TJSONObject.Create;
  Result.AddPair('repository', Repository); Result.AddPair('group', Group);
  Result.AddPair('files', TJSONNumber.Create(Count));
  Result.AddPair('validFiles', TJSONNumber.Create(Valid));
  Result.AddPair('filesWithDirectives', TJSONNumber.Create(Directives));
  Result.AddPair('completeOpaqueFiles', TJSONNumber.Create(Complete));
  Result.AddPair('otherOpaqueFiles', TJSONNumber.Create(OtherOpaque));
  Result.AddPair('codeUnits', TJSONNumber.Create(Total));
  Result.AddPair('structuredCodeUnits', TJSONNumber.Create(Structured));
  Result.AddPair('opaqueCodeUnits', TJSONNumber.Create(Opaque));
  Result.AddPair('errorCodeUnits', TJSONNumber.Create(Errors));
  Result.AddPair('structuredPercent', Percentage(Structured, Total));
  Result.AddPair('opaquePercent', Percentage(Opaque, Total));
  Result.AddPair('errorPercent', Percentage(Errors, Total));
end;

function CsvCell(const Value: string): string;
begin Result := '"' + StringReplace(Value, '"', '""', [rfReplaceAll]) + '"'; end;

function CsvReport(Files: TJSONArray): string;
const Fields: array[0..35] of string = ('repository','commit','path','category','bytes','encoding',
  'utf16Units','tokens','nonTriviaTokens','triviaTokens','directiveTokens','nodes','opaqueNodes',
  'errorNodes','missingTokens','lexerDiagnostics','parserDiagnostics','codeUnits',
  'structuredCodeUnits','opaqueCodeUnits','errorCodeUnits','structuredPercent','opaquePercent',
  'errorPercent','structuredIncludingTriviaPercent','hasDirectives','completeOpaque',
  'lexerMs','parserMs','analysisMs','totalMs','tokensPerSecond','status','lossless','deterministic','retainedTreeHeapBytes');
var Text: TStringBuilder; I: Integer; Item, Value: TJSONValue;
begin
  Text := TStringBuilder.Create;
  try
    for I := Low(Fields) to High(Fields) do
    begin if I > 0 then Text.Append(','); Text.Append(Fields[I]); end;
    Text.Append(#13#10);
    for Item in Files do
    begin
      for I := Low(Fields) to High(Fields) do
      begin
        if I > 0 then Text.Append(',');
        Value := TJSONObject(Item).GetValue(Fields[I]);
        if Value <> nil then Text.Append(CsvCell(Value.Value)) else Text.Append('""');
      end;
      Text.Append(#13#10);
    end;
    Result := Text.ToString;
  finally Text.Free; end;
end;

function MetricText(Obj: TJSONObject; const Key: string): string;
var V: TJSONValue;
begin
  V := Obj.GetValue(Key);
  if (V = nil) or (V is TJSONNull) then Exit('n/a');
  if (V is TJSONNumber) and (Key.EndsWith('Percent') or Key.EndsWith('Ms') or
    (Key = 'tokensPerSecond')) then
    Exit(FormatFloat('0.00', TJSONNumber(V).AsDouble, TFormatSettings.Invariant));
  Result := V.Value;
end;

function MdCell(const S: string): string;
begin
  Result := StringReplace(S, '|', '\|', [rfReplaceAll]);
  Result := StringReplace(Result, #13, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
end;

procedure WriteReports(Report: TJSONObject; const OutputDirectory: string);
const Groups: array[0..7] of string = ('all','without-directives','with-directives',
  'complete-opaque','other-opaque','small','medium','large');
var
  Files, Summaries, Repos: TJSONArray;
  Item, R, RegionValue, DiagnosticValue: TJSONValue;
  F, Summary, Region, Entry: TJSONObject;
  Repositories: TStringList;
  Text: TStringBuilder;
  RepoName, Group, Key: string;
  Regions, Performance: TList<TJSONObject>;
  Diagnoses: TDictionary<string, Integer>;
  Causes: TObjectDictionary<string, TJSONObject>;
  CauseFiles: TDictionary<string, Byte>;
  CauseOrder: TList<TJSONObject>;
  CauseArray: TJSONArray;
  Cause: TJSONObject;
  Keys: TArray<string>;
  I, Count: Integer;
  Amount: Int64;
  Total: TJSONObject;
begin
  Files := Report.GetValue<TJSONArray>('files');
  Report.RemovePair('summaries').Free;
  Report.RemovePair('opaqueRanking').Free;
  Summaries := TJSONArray.Create; Report.AddPair('summaries', Summaries);
  Repositories := TStringList.Create; Text := TStringBuilder.Create;
  Regions := TList<TJSONObject>.Create; Performance := TList<TJSONObject>.Create;
  Diagnoses := TDictionary<string, Integer>.Create;
  Causes := TObjectDictionary<string, TJSONObject>.Create([doOwnsValues]);
  CauseFiles := TDictionary<string, Byte>.Create;
  CauseOrder := TList<TJSONObject>.Create;
  try
    Repositories.Sorted := True; Repositories.Duplicates := dupIgnore;
    Repositories.Add('');
    Repositories.Add('external');
    for Item in Files do Repositories.Add(TJSONObject(Item).GetValue<string>('repository'));
    for RepoName in Repositories do
      for Group in Groups do Summaries.AddElement(Aggregate(Files, RepoName, Group));
    Total := TJSONObject(Summaries.Items[0]);
    Text.AppendLine('# M2.7 parser coverage').AppendLine;
    Text.AppendLine('## Executive summary').AppendLine;
    Text.Append('Files attempted: ').Append(Files.Count).Append('; lossless validated: ')
      .Append(MetricText(Total, 'validFiles')).Append('; weighted structural coverage: ')
      .Append(MetricText(Total, 'structuredPercent')).AppendLine('%.').AppendLine;
    Text.AppendLine('Structural representation does not establish formatter safety. External and internal baselines are separate repository rows. Invalid/ambiguous input is excluded from coverage denominators.').AppendLine;
    Text.AppendLine('## Toolchain and environment').AppendLine;
    Text.AppendLine(Report.GetValue<string>('environment')).AppendLine;
    Text.AppendLine('Times use TStopwatch; lexer/parser medians exclude validation. analysisMs includes independent re-lexing, traversal, hashing and serialization. totalMs includes I/O and every repetition. retainedTreeHeapBytes is the maximum RTL allocated-heap delta after parse and lexer disposal, before validation; it is neither peak memory nor a leak measurement. Memory profiling is not performed.').AppendLine;
    Text.AppendLine('## Pinned repositories and provenance').AppendLine;
    Repos := TJSONArray(Report.GetValue('repositories'));
    if Repos <> nil then for R in Repos do
      Text.Append('- ').Append(TJSONObject(R).GetValue<string>('name')).Append(' `')
        .Append(TJSONObject(R).GetValue<string>('commit')).Append('` - ')
        .Append(TJSONObject(R).GetValue<string>('license')).Append(' - ')
        .AppendLine(TJSONObject(R).GetValue<string>('licenseSource'));
    Text.AppendLine.AppendLine('## Coverage by repository, size and directives').AppendLine;
    Text.AppendLine('| Repository | Group | Files | Valid | Directive files | Complete opaque | Other opaque | Structured % | Opaque % | Error % |');
    Text.AppendLine('|---|---|---:|---:|---:|---:|---:|---:|---:|---:|');
    for Item in Summaries do
    begin
      Summary := TJSONObject(Item);
      Text.Append('| ').Append(Summary.GetValue<string>('repository')).Append(' | ')
        .Append(Summary.GetValue<string>('group')).Append(' | ')
        .Append(MetricText(Summary,'files')).Append(' | ').Append(MetricText(Summary,'validFiles'))
        .Append(' | ').Append(MetricText(Summary,'filesWithDirectives')).Append(' | ')
        .Append(MetricText(Summary,'completeOpaqueFiles')).Append(' | ').Append(MetricText(Summary,'otherOpaqueFiles'))
        .Append(' | ').Append(MetricText(Summary,'structuredPercent')).Append(' | ')
        .Append(MetricText(Summary,'opaquePercent')).Append(' | ').Append(MetricText(Summary,'errorPercent')).AppendLine(' |');
    end;
    for Item in Files do
    begin
      F := TJSONObject(Item);
      if F.GetValue('parserMs') <> nil then Performance.Add(F);
      if F.GetValue('opaqueRegions') <> nil then
        for RegionValue in F.GetValue<TJSONArray>('opaqueRegions') do
        begin
          Region := TJSONObject(RegionValue);
          Entry := TJSONObject(Region.Clone);
          Entry.AddPair('path', F.GetValue<string>('path'));
          Entry.AddPair('repository', F.GetValue<string>('repository'));
          Regions.Add(Entry);
          if Region.GetValue<Boolean>('outermost', True) then
          begin
            Key := Region.GetValue<string>('category');
            if not Causes.TryGetValue(Key, Cause) then
            begin
              Cause := TJSONObject.Create; Cause.AddPair('category', Key);
              Cause.AddPair('units', TJSONNumber.Create(0));
              Cause.AddPair('regions', TJSONNumber.Create(0));
              Cause.AddPair('files', TJSONNumber.Create(0));
              Causes.Add(Key, Cause); CauseOrder.Add(Cause);
            end;
            Amount := Number(Cause,'units') + Number(Region,'length');
            Cause.RemovePair('units').Free; Cause.AddPair('units', TJSONNumber.Create(Amount));
            Amount := Number(Cause,'regions') + 1;
            Cause.RemovePair('regions').Free; Cause.AddPair('regions', TJSONNumber.Create(Amount));
            Key := Key + '|' + F.GetValue<string>('path');
            if not CauseFiles.ContainsKey(Key) then
            begin
              CauseFiles.Add(Key,0); Amount := Number(Cause,'files') + 1;
              Cause.RemovePair('files').Free; Cause.AddPair('files', TJSONNumber.Create(Amount));
            end;
          end;
        end;
      if F.GetValue('diagnostics') <> nil then
        for DiagnosticValue in F.GetValue<TJSONArray>('diagnostics') do
        begin
          Key := TJSONObject(DiagnosticValue).GetValue<string>('code');
          if not Diagnoses.TryGetValue(Key, Count) then Count := 0;
          Diagnoses.AddOrSetValue(Key, Count + 1);
        end;
    end;
    Regions.Sort(TComparer<TJSONObject>.Construct(
      function(const A, B: TJSONObject): Integer
      begin
        Result := CompareValue(Number(B,'length'), Number(A,'length'));
        if Result = 0 then Result := CompareStr(A.GetValue<string>('path'), B.GetValue<string>('path'));
        if Result = 0 then Result := CompareValue(Number(A,'start'), Number(B,'start'));
      end));
    Text.AppendLine.AppendLine('## Largest opaque regions').AppendLine;
    Text.AppendLine('| File | Start | UTF-16 units | Parent | Heuristic |');
    Text.AppendLine('|---|---:|---:|---|---|');
    for I := 0 to Regions.Count - 1 do
    begin
      if I >= 20 then Break; Region := Regions[I];
      Text.Append('| ').Append(MdCell(Region.GetValue<string>('path'))).Append(' | ')
        .Append(MetricText(Region,'start')).Append(' | ').Append(MetricText(Region,'length'))
        .Append(' | ').Append(Region.GetValue<string>('parent')).Append(' | ')
        .Append(Region.GetValue<string>('category')).AppendLine(' |');
    end;
    Text.AppendLine.AppendLine('## Diagnostic frequencies').AppendLine;
    Keys := Diagnoses.Keys.ToArray; TArray.Sort<string>(Keys);
    for Key in Keys do Text.Append('- ').Append(Key).Append(': ').Append(Diagnoses[Key]).AppendLine;
    CauseOrder.Sort(TComparer<TJSONObject>.Construct(
      function(const A, B: TJSONObject): Integer
      begin
        Result := CompareValue(Number(B,'units'),Number(A,'units'));
        if Result = 0 then Result := CompareValue(Number(B,'files'),Number(A,'files'));
        if Result = 0 then Result := CompareValue(Number(B,'regions'),Number(A,'regions'));
        if Result = 0 then Result := CompareStr(A.GetValue<string>('category'),B.GetValue<string>('category'));
      end));
    CauseArray := TJSONArray.Create; Report.AddPair('opaqueRanking',CauseArray);
    Text.AppendLine.AppendLine('## Opaque causes ranked by affected extent, files and frequency').AppendLine;
    Text.AppendLine('Outermost regions only; UTF-16 extent includes trivia/errors. Directive fallback is a separate preprocessing cause. Effort and formatter relevance are recommendations in docs/PARSER_COVERAGE.md.').AppendLine;
    Text.AppendLine('| Heuristic cause | UTF-16 extent | Files | Regions |');
    Text.AppendLine('|---|---:|---:|---:|');
    for Cause in CauseOrder do
    begin
      CauseArray.AddElement(Cause.Clone as TJSONObject);
      Text.Append('| ').Append(Cause.GetValue<string>('category')).Append(' | ')
        .Append(MetricText(Cause,'units')).Append(' | ').Append(MetricText(Cause,'files'))
        .Append(' | ').Append(MetricText(Cause,'regions')).AppendLine(' |');
    end;
    Performance.Sort(TComparer<TJSONObject>.Construct(
      function(const A, B: TJSONObject): Integer
      var X, Y: Double;
      begin
        X := A.GetValue<Double>('parserMs'); Y := B.GetValue<Double>('parserMs');
        if X < Y then Result := 1 else if X > Y then Result := -1
        else Result := CompareStr(A.GetValue<string>('path'), B.GetValue<string>('path'));
      end));
    Text.AppendLine.AppendLine('## Performance outliers (largest parser medians)').AppendLine;
    Text.AppendLine('| File | Bytes | Lexer ms | Parser ms | Tokens/s |');
    Text.AppendLine('|---|---:|---:|---:|---:|');
    for I := 0 to Performance.Count - 1 do
    begin
      if I >= 10 then Break; F := Performance[I];
      Text.Append('| ').Append(MdCell(F.GetValue<string>('path'))).Append(' | ')
        .Append(MetricText(F,'bytes')).Append(' | ').Append(MetricText(F,'lexerMs'))
        .Append(' | ').Append(MetricText(F,'parserMs')).Append(' | ').Append(MetricText(F,'tokensPerSecond')).AppendLine(' |');
    end;
    Text.AppendLine.AppendLine('## Exclusions and failures').AppendLine;
    for Item in Files do
    begin
      F := TJSONObject(Item);
      if not F.GetValue<Boolean>('lossless', False) then
        Text.Append('- ').Append(MdCell(F.GetValue<string>('path'))).Append(': ')
          .AppendLine(F.GetValue<string>('status'));
    end;
    Text.AppendLine.AppendLine('## Limits and next milestones (recommendations, not measurements)').AppendLine;
    Text.AppendLine('No preprocessor branches are evaluated. A complete directive fallback masks grammar gaps; it must not be attributed to types or statements. Heuristic unknowns stay unknown. Nested opaque spans in the inventory can overlap; coverage counts each original token exactly once. The stratified sample is not a population estimate. FPC path labels are heuristic and unreviewed units may contain compatibility code.').AppendLine;
    Text.AppendLine('Prioritize any observed invariant violation as a separate minimal-reproducer fix. Otherwise M2.8 should design directive-aware lossless representation before interpreting external grammar coverage; M2.9 should remeasure and select a narrow declaration extension, with resource-string sections a concrete candidate in this corpus. Formatter-oracle infrastructure can follow as a separate task; these percentages do not authorize formatting.');
    ForceDirectories(TPath.GetFullPath(OutputDirectory));
    TFile.WriteAllText(TPath.Combine(OutputDirectory,'coverage.json'), Report.ToJSON + #10, TEncoding.UTF8);
    TFile.WriteAllText(TPath.Combine(OutputDirectory,'coverage.csv'), CsvReport(Files), TEncoding.UTF8);
    TFile.WriteAllText(TPath.Combine(OutputDirectory,'coverage.md'), Text.ToString, TEncoding.UTF8);
  finally
    for Entry in Regions do Entry.Free;
    CauseOrder.Free; CauseFiles.Free; Causes.Free;
    Diagnoses.Free; Performance.Free; Regions.Free; Text.Free; Repositories.Free;
  end;
end;

end.
