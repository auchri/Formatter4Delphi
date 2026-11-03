unit O1NestedStatements;

{ O1 fixture: nested routines and statements. Self-authored. }

interface

function Outer(Value: Integer): Integer;

implementation

function Outer(Value: Integer): Integer;

  function Inner(X: Integer): Integer;
  begin
    if X > 0 then
    begin
      Result := X;
    end
    else
      Result := -X;
  end;

var
  I: Integer;
begin
  Result := 0;
  for I := 1 to Value do
  begin
    while Result < 100 do
    begin
      case I mod 3 of
        0: Result := Result + Inner(I);
        1:
          begin
            Result := Result + 1;
          end;
      else
        Result := Result + 2;
      end;
    end;
  end;
  try
    repeat
      Dec(Result);
    until Result <= 50;
  finally
    Result := Result * 2;
  end;
end;

end.
