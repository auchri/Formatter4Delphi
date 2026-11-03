unit O1AssignSpacing;

{ O1 fixture: assignment operators with different original spacing.
  Self-authored for Formatter4Delphi oracle experiments. }

interface

procedure AssignVariants;

implementation

procedure AssignVariants;
var
  A, B, C, D, E, F, I: Integer;
  S: string;
begin
  A:=1;
  B :=2;
  C:= 3;
  D := 4;
  E  :=  5;
  F	:=	6;
  A :=
    B + C;
  for I:=0 to 2 do
    D:=D+I;
  S := 'x:=y';
  { comment with A:=B inside }
  // line comment with C  :=  D
  if A=B then E:=F else F :=E;
end;

end.
