unit DelphiFormatter.Core.Spans;

interface

type
  TSourceSpan = record
  private
    FStartOffset: Integer;
    FLength: Integer;
  public
    constructor Create(AStartOffset, ALength: Integer);
    function EndOffset: Integer;
    property StartOffset: Integer read FStartOffset;
    property Length: Integer read FLength;
  end;

implementation

uses
  System.SysUtils;

constructor TSourceSpan.Create(AStartOffset, ALength: Integer);
begin
  if (AStartOffset < 0) or (ALength < 0) then
    raise EArgumentOutOfRangeException.Create('Source span must be nonnegative');
  if AStartOffset > High(Integer) - ALength then
    raise EArgumentOutOfRangeException.Create('Source span end overflows Integer');
  FStartOffset := AStartOffset;
  FLength := ALength;
end;

function TSourceSpan.EndOffset: Integer;
begin
  Result := FStartOffset + FLength;
end;

end.
