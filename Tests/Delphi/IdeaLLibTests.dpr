program IdeaLLibTests;

{ DUnitX console runner for ideal-library.
  Build and run from the command line with Tests\Delphi\run-tests.ps1, or open
  this file in RAD Studio (it creates the .dproj) and run it as a console app.
  Target: Win64 (DUnitX ships for Win64 in RAD Studio 12).
  No test touches the network: HTTP tests use an in-process server on 127.0.0.1. }

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.XML.NUnit,
  Test.LocalHttpServer in 'Test.LocalHttpServer.pas',
  Test.IdeaL.Lib.Api.Compat in 'Test.IdeaL.Lib.Api.Compat.pas',
  IdeaL.Lib.Api in '..\..\Api\IdeaL.Lib.Api.pas';

var
  LRunner: ITestRunner;
  LResults: IRunResults;
begin
  ReportMemoryLeaksOnShutdown := True;
  try
    TDUnitX.CheckCommandLine;
    LRunner := TDUnitX.CreateRunner;
    LRunner.UseRTTI := True;
    LRunner.FailsOnNoAsserts := False;
    LRunner.AddLogger(TDUnitXConsoleLogger.Create(True));
    LRunner.AddLogger(TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile));
    LResults := LRunner.Execute;
    if not LResults.AllPassed then
      System.ExitCode := EXIT_ERRORS;
  except
    on E: Exception do
    begin
      System.Writeln(E.ClassName, ': ', E.Message);
      System.ExitCode := EXIT_ERRORS;
    end;
  end;
end.
