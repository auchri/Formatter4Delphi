unit O1LineEndingsMixed;

{ O1 fixture: line endings (CRLF, LF and CR mixed, no final newline). Content is identical across the  O1LineEndings* fixtures except for the unit name and this line. Self-authored. }

interface
procedure LineEndings;
implementation

procedure LineEndings;var
  A: Integer;
begin  A := 1;
  A := A + 1;
end;
end.