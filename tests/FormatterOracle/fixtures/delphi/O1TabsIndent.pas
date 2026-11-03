unit O1TabsIndent;

{ O1 fixture: tab and space indentation, mixed on purpose. Self-authored. }

interface

procedure TabsAndSpaces;

implementation

procedure TabsAndSpaces;
var
	A: Integer;
    B: Integer;
begin
	A := 1;
    B := 2;
	if A < B then
	begin
		A := B;
	    B := A;
  		A := A + B;
	end;
end;

end.
