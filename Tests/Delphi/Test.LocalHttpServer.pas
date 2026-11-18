unit Test.LocalHttpServer;

{ In-process HTTP server bound to 127.0.0.1 on a free port, used by the
  DUnitX tests so that no test ever touches the network.
  Each test sets Handler to script the answer and reads LastRequest to check
  what the client sent. }

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  IdContext,
  IdCustomHTTPServer,
  IdHTTPServer;

type
  TTestRequest = record
    Method: string;
    Path: string;        // document part, e.g. /api/payments/abc
    Query: string;       // raw query string without '?'
    Headers: TStringList;
    Body: string;        // decoded as UTF-8
    function Header(const AName: string): string;
  end;

  TTestResponse = class
  public
    StatusCode: Integer;
    StatusText: string;
    ContentType: string;
    Body: string;
    Location: string;
    DelayMs: Integer;
    ExtraHeaders: TStringList;
    constructor Create;
    destructor Destroy; override;
  end;

  TTestHandler = reference to procedure(const ARequest: TTestRequest; AResponse: TTestResponse);

  TLocalHttpServer = class
  private
    FServer: TIdHTTPServer;
    FLock: TCriticalSection;
    FHandler: TTestHandler;
    FLast: TTestRequest;
    FRequestCount: Integer;
    procedure DoCommand(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo;
      AResponseInfo: TIdHTTPResponseInfo);
    procedure DoParseAuthentication(AContext: TIdContext; const AAuthType,
      AAuthData: String; var VUsername, VPassword: String; var VHandled: Boolean);
    function GetLastRequest: TTestRequest;
    function GetPort: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    function Url(const APath: string = ''): string;
    property Port: Integer read GetPort;
    property Handler: TTestHandler read FHandler write FHandler;
    property LastRequest: TTestRequest read GetLastRequest;
    property RequestCount: Integer read FRequestCount;
    procedure Reset;
  end;

implementation

uses
  IdGlobal;

{ TTestRequest }

function TTestRequest.Header(const AName: string): string;
begin
  Result := '';
  if Assigned(Headers) then
    Result := Headers.Values[AName];
end;

{ TTestResponse }

constructor TTestResponse.Create;
begin
  inherited;
  StatusCode := 200;
  StatusText := '';
  ContentType := 'application/json; charset=utf-8';
  Body := '';
  ExtraHeaders := TStringList.Create;
end;

destructor TTestResponse.Destroy;
begin
  ExtraHeaders.Free;
  inherited;
end;

{ TLocalHttpServer }

constructor TLocalHttpServer.Create;
begin
  inherited;
  FLock := TCriticalSection.Create;
  FLast.Headers := TStringList.Create;
  FServer := TIdHTTPServer.Create(nil);
  FServer.Bindings.Clear;
  with FServer.Bindings.Add do
  begin
    IP := '127.0.0.1';
    Port := 0;
  end;
  FServer.ParseParams := False;
  FServer.KeepAlive := False;
  FServer.OnCommandGet := DoCommand;
  FServer.OnCommandOther := DoCommand;
  FServer.OnParseAuthentication := DoParseAuthentication;
  FServer.Active := True;
end;

procedure TLocalHttpServer.DoParseAuthentication(AContext: TIdContext;
  const AAuthType, AAuthData: String; var VUsername, VPassword: String;
  var VHandled: Boolean);
begin
  // Accept any scheme (e.g. Bearer); tests read the raw header instead.
  VHandled := True;
end;

destructor TLocalHttpServer.Destroy;
begin
  FServer.Active := False;
  FServer.Free;
  FLast.Headers.Free;
  FLock.Free;
  inherited;
end;

procedure TLocalHttpServer.DoCommand(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
  LReq: TTestRequest;
  LResp: TTestResponse;
  LBytes: TBytes;
  I: Integer;
  LLine: string;
  LPos: Integer;
begin
  LReq.Method := ARequestInfo.Command;
  LReq.Path := ARequestInfo.Document;
  LReq.Query := ARequestInfo.QueryParams;
  LReq.Headers := TStringList.Create;
  try
    LReq.Headers.NameValueSeparator := '=';
    for I := 0 to ARequestInfo.RawHeaders.Count - 1 do
    begin
      LLine := ARequestInfo.RawHeaders[I];
      LPos := Pos(':', LLine);
      if LPos > 0 then
        LReq.Headers.Add(Trim(Copy(LLine, 1, LPos - 1)) + '=' +
          Trim(Copy(LLine, LPos + 1, MaxInt)));
    end;
    LReq.Body := '';
    if Assigned(ARequestInfo.PostStream) and (ARequestInfo.PostStream.Size > 0) then
    begin
      ARequestInfo.PostStream.Position := 0;
      SetLength(LBytes, ARequestInfo.PostStream.Size);
      ARequestInfo.PostStream.ReadBuffer(LBytes[0], Length(LBytes));
      LReq.Body := TEncoding.UTF8.GetString(LBytes);
    end;

    FLock.Enter;
    try
      FLast.Method := LReq.Method;
      FLast.Path := LReq.Path;
      FLast.Query := LReq.Query;
      FLast.Body := LReq.Body;
      FLast.Headers.Assign(LReq.Headers);
      Inc(FRequestCount);
    finally
      FLock.Leave;
    end;

    LResp := TTestResponse.Create;
    try
      if Assigned(FHandler) then
        FHandler(LReq, LResp);
      if LResp.DelayMs > 0 then
        Sleep(LResp.DelayMs);
      AResponseInfo.ResponseNo := LResp.StatusCode;
      if LResp.StatusText <> '' then
        AResponseInfo.ResponseText := LResp.StatusText;
      AResponseInfo.ContentType := LResp.ContentType;
      if LResp.Location <> '' then
        AResponseInfo.Location := LResp.Location;
      for I := 0 to LResp.ExtraHeaders.Count - 1 do
        AResponseInfo.CustomHeaders.Values[LResp.ExtraHeaders.Names[I]] :=
          LResp.ExtraHeaders.ValueFromIndex[I];
      // Always send our own stream (possibly empty) so Indy never generates
      // its default HTML error page.
      AResponseInfo.ContentStream := TBytesStream.Create(TEncoding.UTF8.GetBytes(LResp.Body));
      AResponseInfo.FreeContentStream := True;
      AResponseInfo.ContentLength := AResponseInfo.ContentStream.Size;
    finally
      LResp.Free;
    end;
  finally
    LReq.Headers.Free;
  end;
end;

function TLocalHttpServer.GetLastRequest: TTestRequest;
begin
  // Returns a snapshot; the Headers list is shared and owned by the server.
  FLock.Enter;
  try
    Result := FLast;
  finally
    FLock.Leave;
  end;
end;

function TLocalHttpServer.GetPort: Integer;
begin
  Result := FServer.Bindings[0].Port;
end;

procedure TLocalHttpServer.Reset;
begin
  FLock.Enter;
  try
    FHandler := nil;
    FLast.Method := '';
    FLast.Path := '';
    FLast.Query := '';
    FLast.Body := '';
    FLast.Headers.Clear;
    FRequestCount := 0;
  finally
    FLock.Leave;
  end;
end;

function TLocalHttpServer.Url(const APath: string): string;
begin
  Result := Format('http://127.0.0.1:%d%s', [Port, APath]);
end;

end.
