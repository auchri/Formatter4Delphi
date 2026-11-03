unit DelphiFormatter.Core.TextEdits;

interface

uses
  DelphiFormatter.Core.Spans;

type
  // The single edit DTO (design 14, section 7). Span is a half-open UTF-16
  // interval of the snapshot the edit set was planned against; the snapshot
  // identity belongs to the whole edit set, not to each edit.
  TTextEdit = record
    Span: TSourceSpan;
    NewText: string;
    RuleId: string;
    LeftOriginalIndex: Integer;
    RightOriginalIndex: Integer;
    constructor Create(const ASpan: TSourceSpan; const ANewText, ARuleId: string;
      ALeftOriginalIndex, ARightOriginalIndex: Integer);
    function SameEdit(const Other: TTextEdit): Boolean;
  end;

// Sorts canonically by span start and removes exact duplicates. Returns False
// and an empty set when two different edits share an offset or when spans
// overlap or touch: boundaries are closed, so no insertion order is implied.
function NormalizeTextEdits(const Edits: array of TTextEdit;
  out Normalized: TArray<TTextEdit>): Boolean;

// Applies a normalized edit set exactly once, back to front. Unsorted,
// touching or out-of-range edits are API misuse and raise.
function ApplyTextEdits(const Source: string;
  const Edits: array of TTextEdit): string;

implementation

uses
  System.SysUtils, System.Generics.Collections, System.Generics.Defaults;

constructor TTextEdit.Create(const ASpan: TSourceSpan;
  const ANewText, ARuleId: string; ALeftOriginalIndex, ARightOriginalIndex: Integer);
begin
  Span := ASpan;
  NewText := ANewText;
  RuleId := ARuleId;
  LeftOriginalIndex := ALeftOriginalIndex;
  RightOriginalIndex := ARightOriginalIndex;
end;

function TTextEdit.SameEdit(const Other: TTextEdit): Boolean;
begin
  Result := (Span.StartOffset = Other.Span.StartOffset) and
    (Span.Length = Other.Span.Length) and (NewText = Other.NewText) and
    (RuleId = Other.RuleId) and (LeftOriginalIndex = Other.LeftOriginalIndex) and
    (RightOriginalIndex = Other.RightOriginalIndex);
end;

function CompareEdits(const A, B: TTextEdit): Integer;
begin
  // Total order over all fields: sorting never depends on input order.
  Result := A.Span.StartOffset - B.Span.StartOffset;
  if Result = 0 then Result := A.Span.Length - B.Span.Length;
  if Result = 0 then Result := CompareStr(A.NewText, B.NewText);
  if Result = 0 then Result := CompareStr(A.RuleId, B.RuleId);
  if Result = 0 then Result := A.LeftOriginalIndex - B.LeftOriginalIndex;
  if Result = 0 then Result := A.RightOriginalIndex - B.RightOriginalIndex;
end;

function NormalizeTextEdits(const Edits: array of TTextEdit;
  out Normalized: TArray<TTextEdit>): Boolean;
var
  Sorted: TArray<TTextEdit>;
  Unique: TList<TTextEdit>;
  I: Integer;
begin
  Normalized := nil;
  SetLength(Sorted, Length(Edits));
  for I := 0 to High(Edits) do
    Sorted[I] := Edits[I];
  TArray.Sort<TTextEdit>(Sorted, TComparer<TTextEdit>.Construct(
    function(const A, B: TTextEdit): Integer
    begin
      Result := CompareEdits(A, B);
    end));
  Unique := TList<TTextEdit>.Create;
  try
    for I := 0 to High(Sorted) do
    begin
      if Unique.Count > 0 then
      begin
        if Sorted[I].SameEdit(Unique.Last) then
          Continue;
        if Sorted[I].Span.StartOffset <= Unique.Last.Span.EndOffset then
          Exit(False);
      end;
      Unique.Add(Sorted[I]);
    end;
    Normalized := Unique.ToArray;
    Result := True;
  finally
    Unique.Free;
  end;
end;

function ApplyTextEdits(const Source: string;
  const Edits: array of TTextEdit): string;
var
  I, NewLength, SourceEnd, TargetEnd, Count: Integer;
  Target: PChar;
begin
  NewLength := Length(Source);
  for I := 0 to High(Edits) do
  begin
    if Edits[I].Span.EndOffset > Length(Source) then
      raise EArgumentOutOfRangeException.Create('Edit span exceeds source length');
    if (I > 0) and (Edits[I].Span.StartOffset <= Edits[I - 1].Span.EndOffset) then
      raise EArgumentException.Create('Edits must be normalized');
    NewLength := NewLength - Edits[I].Span.Length + Length(Edits[I].NewText);
  end;
  SetLength(Result, NewLength);
  if NewLength = 0 then
    Exit;
  Target := PChar(Result);
  SourceEnd := Length(Source);
  TargetEnd := NewLength;
  // Back to front: every copied original range keeps its original offsets
  // until it is placed, so no edit observes a shifted position.
  for I := High(Edits) downto 0 do
  begin
    Count := SourceEnd - Edits[I].Span.EndOffset;
    Dec(SourceEnd, Count);
    Dec(TargetEnd, Count);
    if Count > 0 then
      Move(PChar(Source)[SourceEnd], Target[TargetEnd], Count * SizeOf(Char));
    Count := Length(Edits[I].NewText);
    Dec(TargetEnd, Count);
    if Count > 0 then
      Move(PChar(Edits[I].NewText)^, Target[TargetEnd], Count * SizeOf(Char));
    SourceEnd := Edits[I].Span.StartOffset;
  end;
  if SourceEnd > 0 then
    Move(PChar(Source)^, Target^, SourceEnd * SizeOf(Char));
end;

end.
