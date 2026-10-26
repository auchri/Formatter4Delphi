unit Coverage.Runner;

interface

function RunCoverage: Integer;

implementation

uses System.SysUtils, System.Classes, System.IOUtils, System.JSON, System.Hash,
  System.Masks, System.Generics.Collections, System.Generics.Defaults,
  Coverage.Analysis, Coverage.Reports;

type
  TInput = record
    Path, DisplayPath, Repository, Commit, Category, Compatibility, Hash: string;
    Bytes: Int64;
  end;

function RunCoverage: Integer;
var
  ManifestPath, DirectoryPath, FilePath, OutputDirectory, IncludeMask, ExcludeMask,
    EnvironmentText, Root, P, Arg, Value, Status: string;
  CodePage, RepeatCount, I, Modes: Integer;
  ManifestValue: TJSONValue;
  Manifest, Repo, FileSpec, Report, FileResult: TJSONObject;
  Repos, Files: TJSONArray;
  R, F: TJSONValue;
  Inputs: TList<TInput>;
  Input: TInput;
  function Allowed(const Path: string): Boolean;
  begin
    Result := MatchesMask(ExtractFileName(Path), IncludeMask) and
      ((ExcludeMask = '') or not MatchesMask(ExtractFileName(Path), ExcludeMask));
  end;
  procedure AddDirectory(const Path, Repository: string);
  var Name: string; Entry: TInput;
  begin
    for Name in TDirectory.GetFiles(Path, '*.pas', TSearchOption.soAllDirectories) do
      if Allowed(Name) then
      begin
        Entry := Default(TInput); Entry.Path := TPath.GetFullPath(Name);
        Entry.DisplayPath := ExtractRelativePath(IncludeTrailingPathDelimiter(Root), Entry.Path).Replace('\','/');
        Entry.Repository := Repository; Entry.Category := 'directory'; Entry.Bytes := -1;
        Inputs.Add(Entry);
      end;
  end;
begin
  Result := 0; CodePage := 0; RepeatCount := 2; OutputDirectory := 'reports/m2_7';
  IncludeMask := '*.pas'; ExcludeMask := ''; ManifestPath := ''; DirectoryPath := ''; FilePath := '';
  EnvironmentText := 'Unspecified host/toolchain; provide --environment. ';
  {$IFDEF DEBUG}EnvironmentText := EnvironmentText + 'Debug';{$ELSE}EnvironmentText := EnvironmentText + 'Release';{$ENDIF}
  {$IFDEF WIN64}EnvironmentText := EnvironmentText + ', Win64';{$ENDIF}
  I := 1;
  while I <= ParamCount do
  begin
    Arg := ParamStr(I);
    if Arg = '--help' then
    begin
      Writeln('Coverage --manifest PATH | --directory PATH | --file PATH');
      Writeln('  --output DIR --repeat N (default 2) --codepage N (default strict UTF-8)');
      Writeln('  --include MASK --exclude MASK (filename globs) --environment TEXT');
      Exit;
    end;
    Inc(I); if I > ParamCount then raise EArgumentException.Create('Missing value for ' + Arg);
    Value := ParamStr(I);
    if Arg = '--manifest' then ManifestPath := Value
    else if Arg = '--directory' then DirectoryPath := Value
    else if Arg = '--file' then FilePath := Value
    else if Arg = '--output' then OutputDirectory := Value
    else if Arg = '--include' then IncludeMask := Value
    else if Arg = '--exclude' then ExcludeMask := Value
    else if Arg = '--environment' then EnvironmentText := Value
    else if Arg = '--repeat' then RepeatCount := StrToInt(Value)
    else if Arg = '--codepage' then CodePage := StrToInt(Value)
    else raise EArgumentException.Create('Unknown argument ' + Arg);
    Inc(I);
  end;
  Modes := Ord(ManifestPath <> '') + Ord(DirectoryPath <> '') + Ord(FilePath <> '');
  if (Modes <> 1) or (RepeatCount < 1) or (CodePage < 0) then
    raise EArgumentException.Create('Choose exactly one input; repeat >= 1; codepage >= 0');
  Root := TDirectory.GetCurrentDirectory;
  Inputs := TList<TInput>.Create; ManifestValue := nil; Report := TJSONObject.Create;
  try
    Report.AddPair('schemaVersion', TJSONNumber.Create(1));
    Report.AddPair('environment', EnvironmentText);
    Report.AddPair('encodingPolicy', 'BOM overrides; otherwise strict UTF-8 or explicit --codepage; exact byte re-encoding required');
    Report.AddPair('codepage', TJSONNumber.Create(CodePage));
    Report.AddPair('repeatCount', TJSONNumber.Create(RepeatCount));
    Files := TJSONArray.Create; Report.AddPair('files', Files);
    if ManifestPath <> '' then
    begin
      ManifestPath := TPath.GetFullPath(ManifestPath);
      ManifestValue := TJSONObject.ParseJSONValue(TFile.ReadAllText(ManifestPath, TEncoding.UTF8));
      if not (ManifestValue is TJSONObject) then raise EArgumentException.Create('Invalid manifest JSON');
      Manifest := TJSONObject(ManifestValue);
      if Manifest.GetValue<Integer>('schemaVersion') <> 1 then raise EArgumentException.Create('Manifest schema');
      // Repository root is fixed relative to the checked-in manifest, independent of CWD.
      Root := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ManifestPath), '../..'));
      Report.AddPair('manifestSha256', THashSHA2.GetHashStringFromFile(ManifestPath));
      Repos := Manifest.GetValue<TJSONArray>('repositories');
      Report.AddPair('repositories', Repos.Clone as TJSONArray);
      for R in Repos do
      begin
        Repo := TJSONObject(R);
        if Length(Repo.GetValue<string>('commit')) <> 40 then raise EArgumentException.Create('Unpinned repository');
        for F in Repo.GetValue<TJSONArray>('files') do
        begin
          FileSpec := TJSONObject(F); Input := Default(TInput);
          Input.DisplayPath := Repo.GetValue<string>('root') + '/' + FileSpec.GetValue<string>('path');
          Input.Path := TPath.GetFullPath(TPath.Combine(Root, Input.DisplayPath));
          if not Input.Path.StartsWith(IncludeTrailingPathDelimiter(Root), True) then
            raise EArgumentException.Create('Manifest path outside repository');
          Input.Repository := Repo.GetValue<string>('name'); Input.Commit := Repo.GetValue<string>('commit');
          Input.Category := FileSpec.GetValue<string>('category');
          Input.Compatibility := FileSpec.GetValue<string>('compatibility', 'unreviewed');
          Input.Hash := FileSpec.GetValue<string>('sha256'); Input.Bytes := FileSpec.GetValue<Int64>('bytes');
          if Allowed(Input.Path) then Inputs.Add(Input);
        end;
      end;
      for F in Manifest.GetValue<TJSONArray>('internalFiles') do
      begin
        FileSpec := TJSONObject(F); Input := Default(TInput);
        Input.DisplayPath := Manifest.GetValue<string>('internalRoot') + '/' + FileSpec.GetValue<string>('path');
        Input.Path := TPath.GetFullPath(TPath.Combine(Root, Input.DisplayPath));
        Input.Repository := 'internal'; Input.Category := 'internal-fixture';
        Input.Commit := Manifest.GetValue<string>('internalCommit');
        Input.Hash := FileSpec.GetValue<string>('sha256'); Input.Bytes := FileSpec.GetValue<Int64>('bytes');
        if Allowed(Input.Path) then Inputs.Add(Input);
      end;
    end
    else if DirectoryPath <> '' then AddDirectory(TPath.GetFullPath(DirectoryPath), 'local')
    else
    begin
      Input := Default(TInput); Input.Path := TPath.GetFullPath(FilePath);
      Input.DisplayPath := Input.Path; Input.Repository := 'local'; Input.Bytes := -1;
      if Allowed(Input.Path) then Inputs.Add(Input);
    end;
    if Inputs.Count = 0 then raise EArgumentException.Create('No matching input files');
    Inputs.Sort(TComparer<TInput>.Construct(
      function(const A, B: TInput): Integer
      begin Result := CompareStr(A.DisplayPath, B.DisplayPath); end));
    P := '';
    for Input in Inputs do
    begin
      if SameText(P, Input.Path) then raise EArgumentException.Create('Duplicate input ' + P);
      P := Input.Path;
      FileResult := nil;
      // A bad file is a row, never an abort of the remaining corpus.
      try
        if Input.Hash <> '' then
        begin
          if not SameText(THashSHA2.GetHashStringFromFile(Input.Path), Input.Hash) then
            raise EArgumentException.Create('Pinned file hash mismatch');
          if TFile.GetSize(Input.Path) <> Input.Bytes then raise EArgumentException.Create('Pinned size mismatch');
        end;
        FileResult := AnalyzeFile(Input.Path, CodePage, RepeatCount);
      except
        on E: Exception do
        begin
          FileResult := TJSONObject.Create; FileResult.AddPair('status','corpus_file_error');
          FileResult.AddPair('encoding','');
          FileResult.AddPair('exception', E.ClassName + ': ' + E.Message);
        end;
      end;
      FileResult.RemovePair('path').Free;
      FileResult.AddPair('path', Input.DisplayPath); FileResult.AddPair('repository', Input.Repository);
      FileResult.AddPair('commit', Input.Commit); FileResult.AddPair('category', Input.Category);
      FileResult.AddPair('compatibility', Input.Compatibility); FileResult.AddPair('sha256', Input.Hash);
      Status := FileResult.GetValue<string>('status');
      if (Status = 'invariant_failed') or (Status = 'parser_exception') then Result := 2
      else if not FileResult.GetValue<Boolean>('lossless', False) and (Result = 0) then Result := 1;
      Writeln(Input.Repository, ': ', Input.DisplayPath, ' -> ', Status);
      Files.AddElement(FileResult);
    end;
    Report.AddPair('exitCode', TJSONNumber.Create(Result));
    WriteReports(Report, OutputDirectory);
  finally Report.Free; ManifestValue.Free; Inputs.Free; end;
end;

end.
