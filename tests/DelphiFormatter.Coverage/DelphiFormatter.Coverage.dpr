program DelphiFormatter.Coverage;

{$APPTYPE CONSOLE}

uses System.SysUtils, Coverage.Analysis, Coverage.Reports, Coverage.Runner;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    ExitCode := RunCoverage;
  except
    on E: Exception do
    begin
      Writeln(ErrOutput, E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
