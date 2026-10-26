unit DeclarationCorpus;

interface

const
  Version = 1;
  DefaultCount: Integer = 2;
var
  Counter: Integer = 0;
  X, Y: Double;

function Add(A: Integer; B: Integer = Version): Integer;
procedure Reset;
procedure Configure(const Name: string; var Value: Integer; out OK: Boolean);

implementation

{$R DeclarationCorpus.res}

function Add(A, B: Integer): Integer;
const
  Multiplier = 2;
var
  Temp: Integer;
begin
  Temp := A + B;
  Result := Temp * Multiplier;
end;

procedure Reset;
begin
  Counter := 0;
end;

procedure Configure(const Name: string; var Value: Integer; out OK: Boolean);
begin
  OK := True;
  Value := DefaultCount;
end;

end.
