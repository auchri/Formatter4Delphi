program DelphiFormatter.Lexer.Tests;

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  Tests.Lexer.Basics in 'Tests.Lexer.Basics.pas',
  DelphiFormatter.Core.Spans in '..\..\src\DelphiFormatter.Core\DelphiFormatter.Core.Spans.pas',
  DelphiFormatter.Core.Diagnostics in '..\..\src\DelphiFormatter.Core\DelphiFormatter.Core.Diagnostics.pas',
  DelphiFormatter.Lexer.Tokens in '..\..\src\DelphiFormatter.Lexer\DelphiFormatter.Lexer.Tokens.pas',
  DelphiFormatter.Lexer.Keywords in '..\..\src\DelphiFormatter.Lexer\DelphiFormatter.Lexer.Keywords.pas',
  DelphiFormatter.Lexer.Scanner in '..\..\src\DelphiFormatter.Lexer\DelphiFormatter.Lexer.Scanner.pas';

var
  Runner: ITestRunner;
  Results: IRunResults;
begin
  try
    TDUnitX.CheckCommandLine;
    Runner := TDUnitX.CreateRunner;
    Runner.UseRTTI := True;
    Runner.FailsOnNoAsserts := True;
    Runner.AddLogger(TDUnitXConsoleLogger.Create(True));
    Results := Runner.Execute;
    if not Results.AllPassed then
      ExitCode := 1;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := 2;
    end;
  end;
end.
