program DelphiFormatter.Formatting.Tests;

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  FormatterAssignmentCorpus in '..\Fixtures\FormatterAssignmentCorpus.pas',
  Tests.Formatting in 'Tests.Formatting.pas',
  DelphiFormatter.Core.Spans in '..\..\src\DelphiFormatter.Core\DelphiFormatter.Core.Spans.pas',
  DelphiFormatter.Core.Diagnostics in '..\..\src\DelphiFormatter.Core\DelphiFormatter.Core.Diagnostics.pas',
  DelphiFormatter.Core.TextEdits in '..\..\src\DelphiFormatter.Core\DelphiFormatter.Core.TextEdits.pas',
  DelphiFormatter.Lexer.Tokens in '..\..\src\DelphiFormatter.Lexer\DelphiFormatter.Lexer.Tokens.pas',
  DelphiFormatter.Lexer.Keywords in '..\..\src\DelphiFormatter.Lexer\DelphiFormatter.Lexer.Keywords.pas',
  DelphiFormatter.Lexer.Scanner in '..\..\src\DelphiFormatter.Lexer\DelphiFormatter.Lexer.Scanner.pas',
  DelphiFormatter.Syntax.Kinds in '..\..\src\DelphiFormatter.Syntax\DelphiFormatter.Syntax.Kinds.pas',
  DelphiFormatter.Syntax.Nodes in '..\..\src\DelphiFormatter.Syntax\DelphiFormatter.Syntax.Nodes.pas',
  DelphiFormatter.Syntax.Tree in '..\..\src\DelphiFormatter.Syntax\DelphiFormatter.Syntax.Tree.pas',
  DelphiFormatter.Syntax.Query in '..\..\src\DelphiFormatter.Syntax\DelphiFormatter.Syntax.Query.pas',
  DelphiFormatter.Parser.Reader in '..\..\src\DelphiFormatter.Parser\DelphiFormatter.Parser.Reader.pas',
  DelphiFormatter.Parser.Delphi in '..\..\src\DelphiFormatter.Parser\DelphiFormatter.Parser.Delphi.pas',
  DelphiFormatter.Formatting.Options in '..\..\src\DelphiFormatter.Formatting\DelphiFormatter.Formatting.Options.pas',
  DelphiFormatter.Formatting.Safety in '..\..\src\DelphiFormatter.Formatting\DelphiFormatter.Formatting.Safety.pas',
  DelphiFormatter.Formatting.Verification in '..\..\src\DelphiFormatter.Formatting\DelphiFormatter.Formatting.Verification.pas',
  DelphiFormatter.Formatting.Engine in '..\..\src\DelphiFormatter.Formatting\DelphiFormatter.Formatting.Engine.pas';

var
  Runner: ITestRunner;
  Results: IRunResults;
begin
  ReportMemoryLeaksOnShutdown := True;
  try
    TDUnitX.CheckCommandLine;
    Runner := TDUnitX.CreateRunner;
    Runner.UseRTTI := True;
    Runner.FailsOnNoAsserts := True;
    Runner.AddLogger(TDUnitXConsoleLogger.Create(True));
    Results := Runner.Execute;
    if (Results.TestCount = 0) or (Results.PassCount = 0) or
      not Results.AllPassed then
      ExitCode := 1;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := 2;
    end;
  end;
end.
