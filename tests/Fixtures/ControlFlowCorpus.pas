unit ControlFlowCorpus;

interface

procedure Exercise;

implementation

uses
  System.SysUtils;

procedure Exercise;
var
  I, J, Total: Integer;
  Ch: Char;
  Text: string;
begin
  Total := 0;
  Text := 'Delphi';
  for I := 0 to 10 do
    Total := Total + I;
  for I := 10 downto 0 do
  begin
    for J := 0 to I do
      Total := Total + J;
  end;
  for Ch in Text do
    Total := Total + Ord(Ch);
  while Total > 20 do
  begin
    Total := Total - 1;
  end;
  repeat
    Inc(Total);
    repeat
      Inc(Total);
    until Total > 20;
  until Total >= 20;
  I := 0;
  J := 0;
  case Total of
    -1: Total := 0;
    0, 1, 2: Total := 3;
    3..10:
      case I of
        0: if J = 0 then Total := 11 else Total := 12;
      else
        Total := 13;
      end;
  else
    Total := 20;
    Inc(Total);
  end;
  try
    try
      if Total < 0 then
        raise Exception.Create('Invalid total');
    except
      on E: System.SysUtils.EArgumentException do
        Total := Length(E.Message);
      on System.SysUtils.EInvalidOp do
        raise;
    else
      Total := 0;
      Inc(Total);
    end;
  finally
    Inc(Total);
  end;
  Writeln(Total);
  try
    Inc(Total);
  except
    Total := 0;
  end;
  Writeln(Total);
end;

end.
