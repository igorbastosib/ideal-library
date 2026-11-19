unit TestServerFpc;

{ In-process HTTP server for the FPC tests (fcl-web TFPHttpServer on
  127.0.0.1). TFPHttpServer.Active blocks, so it runs in a thread that lives
  until the test program ends. Responses are scripted through the globals
  below; the last request is recorded. No network. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs, fphttpserver, httpdefs;

type
  TScript = record
    Code: Integer;
    CodeText: string;
    Body: string;
    ContentType: string;
    Location: string;
    DelayMs: Integer;
    CallbackBody: string; // answer for paths that do not start with WellKnownPrefix
    WellKnownPrefix: string;
  end;

  TSeen = record
    Method: string;
    Path: string;
    Query: string;
    Body: string;
    Authorization: string;
    XTest: string;
    XApiKey: string;
    ContentType: string;
    XAsync: string;
    XNonce: string;
    Count: Integer;
  end;

procedure StartTestServer;
function TestUrl(const APath: string): string;
{ AUrl with scheme, host and port replaced by the test server's (path and query kept). }
function TestRebase(const AUrl: string): string;
procedure ResetScript;
procedure SetScript(ACode: Integer; const ABody: string);
function Script: TScript;
procedure SetLocation(const ALocation: string);
procedure SetDelay(AMs: Integer);
procedure SetCallback(const AWellKnownPrefix, ACallbackBody: string);
function Seen: TSeen;

implementation

type
  TServerThread = class(TThread)
  protected
    procedure Execute; override;
  end;

  THandlerHost = class
    procedure HandleRequest(Sender: TObject; var ARequest: TFPHTTPConnectionRequest;
      var AResponse: TFPHTTPConnectionResponse);
  end;

var
  GLock: TCriticalSection;
  GScript: TScript;
  GSeen: TSeen;
  GServer: TFPHttpServer;
  GHost: THandlerHost;
  GPort: Integer;
  GStarted: Boolean;

procedure THandlerHost.HandleRequest(Sender: TObject;
  var ARequest: TFPHTTPConnectionRequest; var AResponse: TFPHTTPConnectionResponse);
var
  LScript: TScript;
begin
  GLock.Enter;
  try
    GSeen.Method := ARequest.Method;
    GSeen.Path := ARequest.PathInfo;
    if GSeen.Path = '' then
      GSeen.Path := ARequest.URI;
    if Pos('?', GSeen.Path) > 0 then
      GSeen.Path := Copy(GSeen.Path, 1, Pos('?', GSeen.Path) - 1);
    GSeen.Query := ARequest.QueryString;
    GSeen.Body := ARequest.Content;
    GSeen.Authorization := ARequest.Authorization;
    GSeen.XTest := ARequest.GetCustomHeader('X-Test');
    GSeen.XApiKey := ARequest.GetCustomHeader('x-api-key');
    GSeen.ContentType := ARequest.ContentType;
    GSeen.XAsync := ARequest.GetCustomHeader('X-Async');
    GSeen.XNonce := ARequest.GetCustomHeader('X-Nonce');
    Inc(GSeen.Count);
    LScript := GScript;
  finally
    GLock.Leave;
  end;
  if LScript.DelayMs > 0 then
    Sleep(LScript.DelayMs);
  AResponse.Code := LScript.Code;
  if LScript.CodeText <> '' then
    AResponse.CodeText := LScript.CodeText;
  AResponse.ContentType := LScript.ContentType;
  if LScript.Location <> '' then
    AResponse.Location := LScript.Location;
  // a stream, not AResponse.Content: Content goes through TStrings.Text and
  // would append a line break to the body
  AResponse.FreeContentStream := True;
  if (LScript.WellKnownPrefix <> '') and (Copy(GSeen.Path, 1, Length(LScript.WellKnownPrefix)) <> LScript.WellKnownPrefix) then
    AResponse.ContentStream := TStringStream.Create(LScript.CallbackBody)
  else
    AResponse.ContentStream := TStringStream.Create(LScript.Body);
  AResponse.ContentLength := AResponse.ContentStream.Size;
end;

procedure TServerThread.Execute;
begin
  try
    GServer.Active := True; // blocks until the process ends
  except
    // port in use or stopped: the tests will fail visibly
  end;
end;

procedure StartTestServer;
begin
  if GStarted then
    Exit;
  GHost := THandlerHost.Create;
  GServer := TFPHttpServer.Create(nil);
  GPort := 38000 + Random(2000);
  GServer.Port := GPort;
  GServer.Threaded := True;
  GServer.OnRequest := @GHost.HandleRequest;
  TServerThread.Create(False).FreeOnTerminate := True;
  Sleep(300);
  GStarted := True;
end;

function TestUrl(const APath: string): string;
begin
  Result := Format('http://127.0.0.1:%d%s', [GPort, APath]);
end;

function TestRebase(const AUrl: string): string;
var
  LStart, LSlash: Integer;
begin
  LStart := Pos('://', AUrl);
  if LStart = 0 then
    Exit(TestUrl(AUrl));
  LSlash := Pos('/', Copy(AUrl, LStart + 3, MaxInt));
  if LSlash = 0 then
    Result := TestUrl('/')
  else
    Result := TestUrl(Copy(AUrl, LStart + 2 + LSlash, MaxInt));
end;

procedure ResetScript;
begin
  GLock.Enter;
  try
    GScript.Code := 200;
    GScript.CodeText := '';
    GScript.Body := '';
    GScript.ContentType := 'application/json; charset=utf-8';
    GScript.Location := '';
    GScript.DelayMs := 0;
    GScript.CallbackBody := '';
    GScript.WellKnownPrefix := '';
    GSeen.Method := '';
    GSeen.Path := '';
    GSeen.Query := '';
    GSeen.Body := '';
    GSeen.Authorization := '';
    GSeen.XTest := '';
    GSeen.XApiKey := '';
    GSeen.ContentType := '';
    GSeen.XAsync := '';
    GSeen.XNonce := '';
    GSeen.Count := 0;
  finally
    GLock.Leave;
  end;
end;

procedure SetScript(ACode: Integer; const ABody: string);
begin
  GLock.Enter;
  try
    GScript.Code := ACode;
    GScript.Body := ABody;
  finally
    GLock.Leave;
  end;
end;

function Script: TScript;
begin
  Result := GScript;
end;

procedure SetLocation(const ALocation: string);
begin
  GScript.Location := ALocation;
end;

procedure SetDelay(AMs: Integer);
begin
  GScript.DelayMs := AMs;
end;

procedure SetCallback(const AWellKnownPrefix, ACallbackBody: string);
begin
  GScript.WellKnownPrefix := AWellKnownPrefix;
  GScript.CallbackBody := ACallbackBody;
end;

function Seen: TSeen;
begin
  GLock.Enter;
  try
    Result := GSeen;
  finally
    GLock.Leave;
  end;
end;

initialization
  Randomize;
  GLock := TCriticalSection.Create;

end.
