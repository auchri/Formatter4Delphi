unit O1CommentsStrings;

{ O1 fixture: comments and string literals, UTF-8 with BOM, non-ASCII text.
  Self-authored. Grüße, Ünïcödé, € }

interface

procedure CommentsAndStrings;

implementation

(* Block comment with := and begin end keywords *)
procedure CommentsAndStrings;
var
  S, T: string;
  C: Char;
begin
  S := 'It''s a := b; { not a comment }';    // trailing comment
  T := 'Grüße' + #13#10 + 'line2' + #$20AC;  { brace comment }
  C := 'x';
  S:='begin'+'end';                          (* paren-star comment *)
  // commented-out code: S := T;
  {
    multi-line brace comment
      with indentation
  }
  T := S;
end;

end.
