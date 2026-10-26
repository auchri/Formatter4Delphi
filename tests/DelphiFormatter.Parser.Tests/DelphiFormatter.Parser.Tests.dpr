program DelphiFormatter.Parser.Tests;

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  DeclarationCorpus in '..\Fixtures\DeclarationCorpus.pas',
  Tests.Parser.Basics in 'Tests.Parser.Basics.pas',
  DelphiFormatter.Core.Spans in '..\..\src\DelphiFormatter.Core\DelphiFormatter.Core.Spans.pas',
  DelphiFormatter.Core.Diagnostics in '..\..\src\DelphiFormatter.Core\DelphiFormatter.Core.Diagnostics.pas',
  DelphiFormatter.Lexer.Tokens in '..\..\src\DelphiFormatter.Lexer\DelphiFormatter.Lexer.Tokens.pas',
  DelphiFormatter.Lexer.Keywords in '..\..\src\DelphiFormatter.Lexer\DelphiFormatter.Lexer.Keywords.pas',
  DelphiFormatter.Lexer.Scanner in '..\..\src\DelphiFormatter.Lexer\DelphiFormatter.Lexer.Scanner.pas',
  DelphiFormatter.Syntax.Kinds,
  DelphiFormatter.Syntax.Nodes,
  DelphiFormatter.Syntax.Tree,
  DelphiFormatter.Parser.Reader,
  DelphiFormatter.Parser.Delphi,
  PostfixCorpus in '..\Fixtures\PostfixCorpus.pas',
  ClassRecordCorpus in '..\Fixtures\ClassRecordCorpus.pas',
  PropertyCorpus in '..\Fixtures\PropertyCorpus.pas',
  ControlFlowCorpus in '..\Fixtures\ControlFlowCorpus.pas';

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
