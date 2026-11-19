program IdeaLLibTestsFpc;

{ fpcunit console runner for the FPC branches of ideal-library.
  Build and run with Tests\FPC\run-tests-fpc.ps1 (needs only the FPC compiler,
  no Lazarus). No test touches the network. }

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, consoletestrunner,
  TestServerFpc, TestIdeaLLibFpc, TestBitcoinApisFpc;

var
  LApp: TTestRunner;
begin
  DefaultFormat := fPlain;
  DefaultRunAllTests := True;
  LApp := TTestRunner.Create(nil);
  LApp.Initialize;
  LApp.Title := 'ideal-library FPC tests';
  LApp.Run;
  LApp.Free;
  Halt(ExitCode); // the test HTTP server thread is still blocked in accept()
end.
