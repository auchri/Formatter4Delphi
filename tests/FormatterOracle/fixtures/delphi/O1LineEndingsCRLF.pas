unit O1LineEndingsCRLF;

{ O1 fixture: line endings (CRLF only, final CRLF). Content is identical across the
  O1LineEndings* fixtures except for the unit name and this line. Self-authored. }

interface

procedure LineEndings;

implementation

procedure LineEndings;
var
  A: Integer;
begin
  A := 1;
  A := A + 1;
end;

end.
