unit DelphiFormatter.Formatting.Options;

interface

uses
  DelphiFormatter.Core.Diagnostics;

type
  // Internal formatter values (design 14, section 8). They are not verified
  // RAD Studio option names or values.
  TSafetyProfile = (spS0);
  TAssignmentSpacing = (asAsIs, asNone, asBefore, asAfter, asBoth);
  TEolPolicy = (epPreserve);
  TCompatibilityStatus = (csNotRequested, csVerifiedSubset, csPartial,
    csUnverified);
  TOptionOrigin = (ooExplicitInternal, ooNativeValue, ooExplicitOverride,
    ooVerifiedDefault);
  TFormattingSetting = (fsSafetyProfile, fsAssignmentSpacing, fsEolPolicy);

  TFormattingOptionsBuilder = class;

  // Where an effective setting came from. EvidenceIds is a comma-separated
  // list of evidence identifiers; an empty string means no evidence.
  TOptionProvenance = record
    Origin: TOptionOrigin;
    NativeKey: string;
    RawValue: string;
    SourceIdentity: string;
    TargetVersion: string;
    EvidenceIds: string;
    constructor Create(AOrigin: TOptionOrigin; const ANativeKey, ARawValue,
      ASourceIdentity, ATargetVersion, AEvidenceIds: string);
    // A value chosen explicitly by the caller of the internal API.
    class function ExplicitInternal(const ARawValue: string): TOptionProvenance; static;
  end;

  // Immutable, completely validated options. Only TFormattingOptionsBuilder
  // creates instances; the caller owns and frees them.
  TFormattingOptions = class
  private
    FSafetyProfile: TSafetyProfile;
    FAssignmentSpacing: TAssignmentSpacing;
    FEolPolicy: TEolPolicy;
    FCompatibility: TCompatibilityStatus;
    FProvenance: array[TFormattingSetting] of TOptionProvenance;
    constructor CreateValidated(Builder: TFormattingOptionsBuilder);
  public
    // Options are only created validated by the builder.
    constructor Create;
    function GetProvenance(Setting: TFormattingSetting): TOptionProvenance;
    property SafetyProfile: TSafetyProfile read FSafetyProfile;
    property AssignmentSpacing: TAssignmentSpacing read FAssignmentSpacing;
    property EolPolicy: TEolPolicy read FEolPolicy;
    property Compatibility: TCompatibilityStatus read FCompatibility;
  end;

  // Collects settings; nothing has a default. Every setting and the
  // compatibility status must be supplied explicitly before TryBuild.
  TFormattingOptionsBuilder = class
  private
    FSafetyProfile: TSafetyProfile;
    FAssignmentSpacing: TAssignmentSpacing;
    FEolPolicy: TEolPolicy;
    FCompatibility: TCompatibilityStatus;
    FProvenance: array[TFormattingSetting] of TOptionProvenance;
    FAssigned: set of TFormattingSetting;
    FCompatibilityAssigned: Boolean;
  public
    procedure SetSafetyProfile(Value: TSafetyProfile;
      const Provenance: TOptionProvenance);
    procedure SetAssignmentSpacing(Value: TAssignmentSpacing;
      const Provenance: TOptionProvenance);
    procedure SetEolPolicy(Value: TEolPolicy; const Provenance: TOptionProvenance);
    procedure SetCompatibility(Value: TCompatibilityStatus);
    // On success returns True and a new caller-owned Options object. Missing,
    // out-of-range or inconsistent settings return False, Options=nil and
    // FMT2xx error diagnostics; nothing is defaulted silently.
    function TryBuild(out Options: TFormattingOptions;
      out Diagnostics: TArray<TDiagnostic>): Boolean;
  end;

const
  SettingNames: array[TFormattingSetting] of string = ('SafetyProfile',
    'AssignmentSpacing', 'EolPolicy');

implementation

uses
  System.SysUtils, System.Generics.Collections, DelphiFormatter.Core.Spans;

constructor TOptionProvenance.Create(AOrigin: TOptionOrigin; const ANativeKey,
  ARawValue, ASourceIdentity, ATargetVersion, AEvidenceIds: string);
begin
  Origin := AOrigin;
  NativeKey := ANativeKey;
  RawValue := ARawValue;
  SourceIdentity := ASourceIdentity;
  TargetVersion := ATargetVersion;
  EvidenceIds := AEvidenceIds;
end;

class function TOptionProvenance.ExplicitInternal(
  const ARawValue: string): TOptionProvenance;
begin
  Result := TOptionProvenance.Create(ooExplicitInternal, '', ARawValue, '', '', '');
end;

constructor TFormattingOptions.Create;
begin
  raise EInvalidOpException.Create('Use TFormattingOptionsBuilder.TryBuild');
end;

constructor TFormattingOptions.CreateValidated(Builder: TFormattingOptionsBuilder);
var
  Setting: TFormattingSetting;
begin
  inherited Create;
  FSafetyProfile := Builder.FSafetyProfile;
  FAssignmentSpacing := Builder.FAssignmentSpacing;
  FEolPolicy := Builder.FEolPolicy;
  FCompatibility := Builder.FCompatibility;
  for Setting := Low(TFormattingSetting) to High(TFormattingSetting) do
    FProvenance[Setting] := Builder.FProvenance[Setting];
end;

function TFormattingOptions.GetProvenance(
  Setting: TFormattingSetting): TOptionProvenance;
begin
  if Integer(Byte(Setting)) > Ord(High(TFormattingSetting)) then
    raise EArgumentOutOfRangeException.Create('Unknown formatting setting');
  Result := FProvenance[Setting];
end;

procedure TFormattingOptionsBuilder.SetSafetyProfile(Value: TSafetyProfile;
  const Provenance: TOptionProvenance);
begin
  FSafetyProfile := Value;
  FProvenance[fsSafetyProfile] := Provenance;
  Include(FAssigned, fsSafetyProfile);
end;

procedure TFormattingOptionsBuilder.SetAssignmentSpacing(
  Value: TAssignmentSpacing; const Provenance: TOptionProvenance);
begin
  FAssignmentSpacing := Value;
  FProvenance[fsAssignmentSpacing] := Provenance;
  Include(FAssigned, fsAssignmentSpacing);
end;

procedure TFormattingOptionsBuilder.SetEolPolicy(Value: TEolPolicy;
  const Provenance: TOptionProvenance);
begin
  FEolPolicy := Value;
  FProvenance[fsEolPolicy] := Provenance;
  Include(FAssigned, fsEolPolicy);
end;

procedure TFormattingOptionsBuilder.SetCompatibility(Value: TCompatibilityStatus);
begin
  FCompatibility := Value;
  FCompatibilityAssigned := True;
end;

function TFormattingOptionsBuilder.TryBuild(out Options: TFormattingOptions;
  out Diagnostics: TArray<TDiagnostic>): Boolean;
var
  Errors: TList<TDiagnostic>;
  Setting: TFormattingSetting;
  P: TOptionProvenance;
  HasEvidence, MissingEvidence: Boolean;

  procedure Fail(const Code, Message: string);
  begin
    Errors.Add(TDiagnostic.Create(Code, Message, dsError, TSourceSpan.Create(0, 0)));
  end;

begin
  Options := nil;
  Errors := TList<TDiagnostic>.Create;
  try
    for Setting := Low(TFormattingSetting) to High(TFormattingSetting) do
      if not (Setting in FAssigned) then
        Fail('FMT201', 'Required formatting setting missing: ' + SettingNames[Setting]);
    if not FCompatibilityAssigned then
      Fail('FMT201', 'Required formatting setting missing: Compatibility');

    if (fsSafetyProfile in FAssigned) and
      (Integer(Byte(FSafetyProfile)) > Ord(High(TSafetyProfile))) then
      Fail('FMT202', 'SafetyProfile value out of range');
    if (fsAssignmentSpacing in FAssigned) and
      (Integer(Byte(FAssignmentSpacing)) > Ord(High(TAssignmentSpacing))) then
      Fail('FMT202', 'AssignmentSpacing value out of range');
    if (fsEolPolicy in FAssigned) and
      (Integer(Byte(FEolPolicy)) > Ord(High(TEolPolicy))) then
      Fail('FMT202', 'EolPolicy value out of range');
    if FCompatibilityAssigned and
      (Integer(Byte(FCompatibility)) > Ord(High(TCompatibilityStatus))) then
      Fail('FMT202', 'Compatibility value out of range');

    HasEvidence := False;
    MissingEvidence := False;
    for Setting := Low(TFormattingSetting) to High(TFormattingSetting) do
    begin
      if not (Setting in FAssigned) then
        Continue;
      P := FProvenance[Setting];
      case P.Origin of
        ooExplicitInternal:
          if P.NativeKey <> '' then
            Fail('FMT203', SettingNames[Setting] +
              ': explicit internal value must not claim a native key');
        ooNativeValue:
          if (P.NativeKey = '') or (P.RawValue = '') or
            (P.SourceIdentity = '') or (P.TargetVersion = '') then
            Fail('FMT203', SettingNames[Setting] +
              ': native value requires key, raw value, source and target version');
        ooExplicitOverride:
          ;
        ooVerifiedDefault:
          if (P.TargetVersion = '') or (P.EvidenceIds = '') then
            Fail('FMT203', SettingNames[Setting] +
              ': verified default requires target version and evidence');
      else
        Fail('FMT203', SettingNames[Setting] + ': provenance origin out of range');
      end;
      if P.Origin in [ooNativeValue, ooVerifiedDefault] then
        if P.EvidenceIds <> '' then HasEvidence := True
        else MissingEvidence := True;
    end;
    // A compatibility claim needs evidence-backed settings; internal values
    // alone can only be not-requested or unverified.
    if FCompatibilityAssigned and (FCompatibility in [csVerifiedSubset, csPartial]) and
      (not HasEvidence or ((FCompatibility = csVerifiedSubset) and MissingEvidence)) then
      Fail('FMT204', 'Compatibility claim requires evidence-backed native settings');

    Diagnostics := Errors.ToArray;
    Result := Errors.Count = 0;
    if Result then
    begin
      Options := TFormattingOptions.CreateValidated(Self);
    end;
  finally
    Errors.Free;
  end;
end;

end.
