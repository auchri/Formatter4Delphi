unit DelphiFormatter.Formatting.Engine;

interface

uses
  DelphiFormatter.Core.Diagnostics, DelphiFormatter.Core.TextEdits,
  DelphiFormatter.Formatting.Options, DelphiFormatter.Formatting.Safety;

type
  TFormatOutcome = (foUnchanged, foChanged, foPartiallyChanged, foRefused);

  // Immutable, caller-owned result (design 14, section 9). It keeps no
  // reference to the options, lexer result or tree used to produce it.
  TFormatResult = class
  private
    FOriginalSource: string;
    FSourceIdentity: string;
    FFormattedText: string;
    FOutcome: TFormatOutcome;
    FCompatibility: TCompatibilityStatus;
    FEdits: TArray<TTextEdit>;
    FDiagnostics: TArray<TDiagnostic>;
    FProtectedRanges: TArray<TProtectedRange>;
    FRefusalReasons: TFormatRefusalReasons;
    constructor CreateResult(const AOriginalSource, ASourceIdentity,
      AFormattedText: string; AOutcome: TFormatOutcome;
      ACompatibility: TCompatibilityStatus; const AEdits: TArray<TTextEdit>;
      const ADiagnostics: TArray<TDiagnostic>;
      const AProtectedRanges: TArray<TProtectedRange>;
      ARefusalReasons: TFormatRefusalReasons);
    function GetEditCount: Integer;
    function GetDiagnosticCount: Integer;
    function GetProtectedRangeCount: Integer;
  public
    // Results are only produced by FormatText.
    constructor Create;
    function GetEdit(Index: Integer): TTextEdit;
    function GetDiagnostic(Index: Integer): TDiagnostic;
    function GetProtectedRange(Index: Integer): TProtectedRange;
    property OriginalSource: string read FOriginalSource;
    property SourceIdentity: string read FSourceIdentity;
    property FormattedText: string read FFormattedText;
    property Outcome: TFormatOutcome read FOutcome;
    property Compatibility: TCompatibilityStatus read FCompatibility;
    property EditCount: Integer read GetEditCount;
    property DiagnosticCount: Integer read GetDiagnosticCount;
    property ProtectedRangeCount: Integer read GetProtectedRangeCount;
    property RefusalReasons: TFormatRefusalReasons read FRefusalReasons;
  end;

  // Verification test seam (T-VERIFY): may corrupt the planned edit set
  // before normalization and verification. Not part of the canonical API.
  TEditSetTransform = reference to procedure(var Edits: TArray<TTextEdit>);

// Options are borrowed for the call. Ordinary refusals are reported through
// the result; nil Options is API misuse and raises.
function FormatText(const Source: string;
  Options: TFormattingOptions): TFormatResult;

function FormatTextWithEditTransform(const Source: string;
  Options: TFormattingOptions; const Transform: TEditSetTransform): TFormatResult;

implementation

uses
  System.SysUtils, System.Generics.Collections, DelphiFormatter.Core.Spans,
  DelphiFormatter.Lexer.Tokens, DelphiFormatter.Lexer.Scanner,
  DelphiFormatter.Syntax.Tree, DelphiFormatter.Parser.Delphi,
  DelphiFormatter.Formatting.Verification;

constructor TFormatResult.Create;
begin
  raise EInvalidOpException.Create('Use FormatText');
end;

constructor TFormatResult.CreateResult(const AOriginalSource, ASourceIdentity,
  AFormattedText: string; AOutcome: TFormatOutcome;
  ACompatibility: TCompatibilityStatus; const AEdits: TArray<TTextEdit>;
  const ADiagnostics: TArray<TDiagnostic>;
  const AProtectedRanges: TArray<TProtectedRange>;
  ARefusalReasons: TFormatRefusalReasons);
begin
  inherited Create;
  FOriginalSource := AOriginalSource;
  FSourceIdentity := ASourceIdentity;
  FFormattedText := AFormattedText;
  FOutcome := AOutcome;
  FCompatibility := ACompatibility;
  FEdits := Copy(AEdits);
  FDiagnostics := Copy(ADiagnostics);
  FProtectedRanges := Copy(AProtectedRanges);
  FRefusalReasons := ARefusalReasons;
end;

function TFormatResult.GetEditCount: Integer;
begin
  Result := Length(FEdits);
end;

function TFormatResult.GetDiagnosticCount: Integer;
begin
  Result := Length(FDiagnostics);
end;

function TFormatResult.GetProtectedRangeCount: Integer;
begin
  Result := Length(FProtectedRanges);
end;

function TFormatResult.GetEdit(Index: Integer): TTextEdit;
begin
  if (Index < 0) or (Index >= EditCount) then
    raise EArgumentOutOfRangeException.Create('Edit index out of range');
  Result := FEdits[Index];
end;

function TFormatResult.GetDiagnostic(Index: Integer): TDiagnostic;
begin
  if (Index < 0) or (Index >= DiagnosticCount) then
    raise EArgumentOutOfRangeException.Create('Diagnostic index out of range');
  Result := FDiagnostics[Index];
end;

function TFormatResult.GetProtectedRange(Index: Integer): TProtectedRange;
begin
  if (Index < 0) or (Index >= ProtectedRangeCount) then
    raise EArgumentOutOfRangeException.Create('Protected range index out of range');
  Result := FProtectedRanges[Index];
end;

function DesiredSlotText(Spacing: TAssignmentSpacing; Before: Boolean): string;
begin
  case Spacing of
    asBefore:
      if Before then Result := ' ' else Result := '';
    asAfter:
      if Before then Result := '' else Result := ' ';
    asBoth:
      Result := ' ';
  else
    Result := '';
  end;
end;

function RunFormat(const Source: string; Options: TFormattingOptions;
  const Transform: TEditSetTransform): TFormatResult;
var
  Identity, Formatted, Failure: string;
  Lex: TDelphiLexResult;
  Tree: TSyntaxTree;
  Analysis: TS0Analysis;
  Site: TAssignmentSlotSite;
  Diagnostics: TList<TDiagnostic>;
  Ranges: TList<TProtectedRange>;
  Planned: TList<TTextEdit>;
  Decisions: TList<TSlotDecision>;
  Owners: TList<Integer>;
  Edits, Normalized: TArray<TTextEdit>;
  Input: TVerificationInput;
  Reasons: TFormatRefusalReasons;
  I: Integer;

  procedure Plan(const Decision: TSlotDecision; Before: Boolean; Owner: Integer);
  var
    Current, Desired: string;
  begin
    Decisions.Add(Decision);
    if not Decision.AllowWhitespace then
    begin
      // Requested but frozen by the S0 profile: reported, never edited.
      Ranges.Add(TProtectedRange.Create(Decision.Span, Decision.Reasons));
      Exit;
    end;
    if (Owners.Count = 0) or (Owners.Last <> Owner) then
      Owners.Add(Owner);
    Current := Copy(Source, Decision.Span.StartOffset + 1, Decision.Span.Length);
    Desired := DesiredSlotText(Options.AssignmentSpacing, Before);
    if Current <> Desired then
      Planned.Add(TTextEdit.Create(Decision.Span, Desired, S0AssignmentSpacingRuleId,
        Decision.LeftOriginalIndex, Decision.RightOriginalIndex));
  end;

  procedure Refuse(Reason: TFormatRefusalReasons; const Code, Message: string);
  begin
    Reasons := Reasons + Reason;
    Diagnostics.Add(TDiagnostic.Create(Code, Message, dsWarning,
      TSourceSpan.Create(0, Length(Source))));
  end;

begin
  if Options = nil then
    raise EArgumentNilException.Create('Options');
  Identity := ComputeSourceIdentity(Source);
  Formatted := Source;
  Normalized := nil;
  Reasons := [];
  Diagnostics := TList<TDiagnostic>.Create;
  Ranges := TList<TProtectedRange>.Create;
  Planned := TList<TTextEdit>.Create;
  Decisions := TList<TSlotDecision>.Create;
  Owners := TList<Integer>.Create;
  try
    Lex := TDelphiLexer.Tokenize(Source);
    try
      Tree := TDelphiParser.Parse(Lex);
      try
        // Input diagnostics first (lexer, then parser), formatter ones after.
        for I := 0 to Tree.DiagnosticCount - 1 do
          Diagnostics.Add(Tree.GetDiagnostic(I));
        if (Options.SafetyProfile <> spS0) or (Options.EolPolicy <> epPreserve) then
          Refuse([frConfigPolicy], 'FMT015',
            'Formatting refused: only safety profile S0 with EOL preserve is supported');
        if Reasons = [] then
        begin
          Analysis := AnalyzeS0(Lex, Tree, Identity,
            Options.AssignmentSpacing <> asAsIs);
          Diagnostics.AddRange(Analysis.Diagnostics);
          Reasons := Analysis.Reasons;
        end;
        if Reasons = [] then
        begin
          for Site in Analysis.Sites do
          begin
            Plan(Site.Before, True, Site.OwnerOrdinal);
            Plan(Site.After, False, Site.OwnerOrdinal);
          end;
          Edits := Planned.ToArray;
          if Assigned(Transform) then
            Transform(Edits);
          if not NormalizeTextEdits(Edits, Normalized) then
            Refuse([frEditConflict], 'FMT011',
              'Formatting refused: conflicting text edits')
          else
          begin
            Input.OriginalSource := Source;
            Input.SourceIdentity := Identity;
            Input.Snapshot := Source;
            Input.OriginalLex := Lex;
            Input.OriginalTree := Tree;
            Input.Decisions := Decisions.ToArray;
            Input.OwnerOrdinals := Owners.ToArray;
            Input.Edits := Normalized;
            if not VerifyAndApply(Input, Formatted, Failure) then
              Refuse([frValidationFailure], 'FMT012',
                'Formatting refused: verification failed: ' + Failure);
          end;
        end;
      finally
        Tree.Free;
      end;
    finally
      Lex.Free;
    end;
    if Reasons <> [] then
    begin
      // The whole edit set is discarded: output is the input, zero edits.
      Ranges.Clear;
      Ranges.Add(TProtectedRange.Create(TSourceSpan.Create(0, Length(Source)), Reasons));
      Result := TFormatResult.CreateResult(Source, Identity, Source, foRefused,
        Options.Compatibility, nil, Diagnostics.ToArray, Ranges.ToArray, Reasons);
    end
    else if Length(Normalized) = 0 then
      Result := TFormatResult.CreateResult(Source, Identity, Source, foUnchanged,
        Options.Compatibility, nil, Diagnostics.ToArray, Ranges.ToArray, [])
    else
      Result := TFormatResult.CreateResult(Source, Identity, Formatted, foChanged,
        Options.Compatibility, Normalized, Diagnostics.ToArray, Ranges.ToArray, []);
  finally
    Owners.Free;
    Decisions.Free;
    Planned.Free;
    Ranges.Free;
    Diagnostics.Free;
  end;
end;

function FormatText(const Source: string;
  Options: TFormattingOptions): TFormatResult;
begin
  Result := RunFormat(Source, Options, nil);
end;

function FormatTextWithEditTransform(const Source: string;
  Options: TFormattingOptions; const Transform: TEditSetTransform): TFormatResult;
begin
  Result := RunFormat(Source, Options, Transform);
end;

end.
