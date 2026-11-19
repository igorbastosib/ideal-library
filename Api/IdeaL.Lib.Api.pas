unit IdeaL.Lib.Api;

{$IFDEF FPC}
{$mode objfpc}{$H+}{$modeswitch advancedrecords}
{$ENDIF}

interface

uses
{$IFDEF FPC}
  Classes,
  SysUtils,

  fphttpclient
{$ELSE}
  System.Classes,
  System.SysUtils,
  System.IOUtils,
  System.JSON,

  System.Net.URLClient,
  System.Net.HttpClient,
  System.Net.HttpClientComponent,
  System.Net.Mime
{$ENDIF}
  ;

type
{$IFDEF FPC}
  /// <summary> FPC stand-in for Delphi's System.Net.URLClient.TNameValuePair,
  /// so that code shared by both compilers can build header lists the same way. </summary>
  TNameValuePair = record
    Name: string;
    Value: string;
    class function Create(const AName, AValue: string): TNameValuePair; static;
  end;
  /// <summary> FPC stand-in for Delphi's TNetHeaders. </summary>
  TNetHeaders = array of TNameValuePair;
{$ENDIF}

  /// <summary> Raised when the server ANSWERED with a status outside 2xx.
  /// Descends from Exception, so existing "except on E: Exception" code keeps working.
  /// The message keeps the 0.0.6 format ("&lt;code&gt; &lt;text&gt;" for GET,
  /// "&lt;code&gt; &lt;text&gt; - &lt;body&gt;" for POST) and never contains the request URL.
  /// </summary>
  EIdeaLApiError = class(Exception)
  private
    FStatusCode: Integer;
    FStatusText: string;
    FResponseBody: string;
  public
    constructor Create(AStatusCode: Integer; const AStatusText, AResponseBody: string;
      AIncludeBodyInMessage: Boolean);
    property StatusCode: Integer read FStatusCode;
    property StatusText: string read FStatusText;
    /// <summary> Full response body as received. </summary>
    property ResponseBody: string read FResponseBody;
  end;

  { TIdeaLApi }

  TIdeaLApi = class
  private
    FNoRedirects: Boolean;
    function GetFollowRedirects: Boolean;
    procedure SetFollowRedirects(const AValue: Boolean);
    { private declarations }
  protected
    { protected declarations }
  public
    const
    /// <summary> Timeouts used by the overloads without timeout parameters
    /// (milliseconds). Equal to Delphi 12's own THTTPClient defaults, so calls
    /// written for 0.0.6 behave as before. </summary>
    CDefaultConnectTimeout = 60000;
    CDefaultResponseTimeout = 60000;

    constructor Create; virtual;
{$IFDEF FPC}
    class procedure GetHttpRequest(
          out AHttpClient: TFPHttpClient;
          AOnData: TDataEvent = nil); virtual;
{$ELSE}
    class procedure GetNetHttpRequest(
      out ANetHttpClient: TNetHTTPClient;
      out ANetHttpRequest: TNetHTTPRequest;
      AOnSendDataEvent: TSendDataEvent = nil;
      AOnReceiveData: TReceiveDataEvent = nil); virtual;
{$ENDIF}
    /// <summary> True when AException means "the server did not answer"
    /// (timeout, DNS, TLS, connection reset...), as opposed to EIdeaLApiError,
    /// which means the server answered with an error status. The platform
    /// exception classes are kept as they were, so existing handlers still work. </summary>
    class function IsTransportError(AException: Exception): Boolean;

    /// <summary> POST with the default timeouts (CDefaultConnectTimeout / CDefaultResponseTimeout). </summary>
    function Post(AUrl, ABody: string; AHeaders: TNetHeaders): string; overload; virtual;
    /// <summary> POST; ABody is sent as UTF-8. Any 2xx is success, anything else raises EIdeaLApiError.
    /// </summary>
    /// <param name="AConnectTimeout"> milliseconds to establish the connection </param>
    /// <param name="AResponseTimeout"> milliseconds to wait for the answer. Delphi: total
    /// response timeout; FPC: per-read socket timeout (TFPHttpClient.IOTimeout). </param>
    function Post(AUrl, ABody: string; AHeaders: TNetHeaders;
      AConnectTimeout, AResponseTimeout: Integer): string; overload; virtual;
    /// <summary> GET with the default timeouts (CDefaultConnectTimeout / CDefaultResponseTimeout). </summary>
    function Get(AUrl: string; AHeaders: TNetHeaders): string; overload; virtual;
    /// <summary> GET. Any 2xx is success, anything else raises EIdeaLApiError. </summary>
    function Get(AUrl: string; AHeaders: TNetHeaders;
      AConnectTimeout, AResponseTimeout: Integer): string; overload; virtual;

    /// <summary> Follow HTTP redirects (default True, as in 0.0.6 on Delphi).
    /// Set False for calls to untrusted hosts (e.g. LNURL), so a redirect cannot
    /// send the request to another host; a 3xx answer then raises EIdeaLApiError. </summary>
    property FollowRedirects: Boolean read GetFollowRedirects write SetFollowRedirects;
    { public declarations }
  end;

implementation

uses
{$IFDEF FPC}
  ssockets,
  openssl, { This implements the procedure InitSSLInterface }
  opensslsockets;
{$ELSE}
  System.Types,
  System.SyncObjs;
{$ENDIF}

{$IFDEF FPC}

{ TNameValuePair }

class function TNameValuePair.Create(const AName, AValue: string): TNameValuePair;
begin
  Result.Name := AName;
  Result.Value := AValue;
end;
{$ENDIF}

{ EIdeaLApiError }

constructor EIdeaLApiError.Create(AStatusCode: Integer; const AStatusText,
  AResponseBody: string; AIncludeBodyInMessage: Boolean);
var
  LMessage: string;
begin
  LMessage := IntToStr(AStatusCode) + ' ' + AStatusText;
  if AIncludeBodyInMessage and (Trim(AResponseBody) <> '') then
    LMessage := LMessage + ' - ' + AResponseBody;
  inherited Create(LMessage);
  FStatusCode := AStatusCode;
  FStatusText := AStatusText;
  FResponseBody := AResponseBody;
end;

{ TIdeaLApi }

constructor TIdeaLApi.Create;
begin

end;

function TIdeaLApi.GetFollowRedirects: Boolean;
begin
  Result := not FNoRedirects;
end;

procedure TIdeaLApi.SetFollowRedirects(const AValue: Boolean);
begin
  FNoRedirects := not AValue;
end;

class function TIdeaLApi.IsTransportError(AException: Exception): Boolean;
begin
  if (AException = nil) or (AException is EIdeaLApiError) then
    Exit(False);
{$IFDEF FPC}
  Result := (AException is ESocketError) or (AException is EHTTPClient) or
    (AException is EInOutError);
{$ELSE}
  Result := AException is ENetException;
{$ENDIF}
end;

{ Drops headers whose value is empty. Why: WinHTTP treats "Name:" with an
  empty value as "remove the header Name" and, when the request does not have
  it, fails with 12150 (ERROR_WINHTTP_HEADER_NOT_FOUND, "Error adding header").
  Up to 0.0.6 this made e.g. TAPICoinOS.PostLogin fail whenever an optional
  header such as x-api-key was left empty. An empty header carries no
  information, so it is simply not sent, on every platform. }
function WithoutEmptyHeaders(const AHeaders: TNetHeaders): TNetHeaders;
var
  I, LCount: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AHeaders));
  LCount := 0;
  for I := 0 to High(AHeaders) do
    if AHeaders[I].Value <> '' then
    begin
      Result[LCount] := AHeaders[I];
      Inc(LCount);
    end;
  SetLength(Result, LCount);
end;

{$IFDEF FPC}
class procedure TIdeaLApi.GetHttpRequest(
  out AHttpClient: TFPHttpClient;
  AOnData: TDataEvent = nil);
begin
  AHttpClient := TFPHttpClient.Create(Nil);
  AHttpClient.OnDataReceived := AOnData;
  AHttpClient.AddHeader('Accept', '*/*');
  AHttpClient.AddHeader('Accept-Charset', 'utf-8');
  //AHttpClient.AddHeader('Content-Type', 'multipart/form-data');
  AHttpClient.AddHeader('User-Agent',
    'Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.0; Acoo Browser; ' +
    'GTB5; Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1) ; ' +
    'Maxthon; InfoPath.1; .NET CLR 3.5.30729; .NET CLR 3.0.30618)');
end;

{ One implementation for both verbs on FPC. HTTPMethod with an empty list of
  allowed codes never raises on the status, so the 2xx check below is ours. }
function FpcRequest(AApi: TIdeaLApi; const AMethod, AUrl, ABody: string;
  const AHeaders: TNetHeaders; AConnectTimeout, AResponseTimeout: Integer;
  AIncludeBodyInMessage: Boolean): string;
var
  LHttpClient: TFPHttpClient;
  LResponse: TStringStream;
  LPair: TNameValuePair;
  LStatus: Integer;
begin
  InitSSLInterface;
  TIdeaLApi.GetHttpRequest(LHttpClient);
  try
    LResponse := TStringStream.Create('');
    try
      for LPair in WithoutEmptyHeaders(AHeaders) do
        LHttpClient.AddHeader(LPair.Name, LPair.Value);
      LHttpClient.ConnectTimeout := AConnectTimeout;
      LHttpClient.IOTimeout := AResponseTimeout;
      LHttpClient.AllowRedirect := AApi.FollowRedirects;
      if AMethod = 'POST' then
        LHttpClient.RequestBody := TStringStream.Create(ABody);
      try
        LHttpClient.HTTPMethod(AMethod, AUrl, LResponse, []);
      finally
        if Assigned(LHttpClient.RequestBody) then
        begin
          LHttpClient.RequestBody.Free;
          LHttpClient.RequestBody := nil;
        end;
      end;
      LStatus := LHttpClient.ResponseStatusCode;
      if (LStatus < 200) or (LStatus > 299) then
        raise EIdeaLApiError.Create(LStatus, LHttpClient.ResponseStatusText,
          LResponse.DataString, AIncludeBodyInMessage);
      Result := LResponse.DataString;
    finally
      LResponse.Free;
    end;
  finally
    LHttpClient.Free;
  end;
end;
{$ELSE}
class procedure TIdeaLApi.GetNetHttpRequest(out ANetHttpClient: TNetHTTPClient;
  out ANetHttpRequest: TNetHTTPRequest; AOnSendDataEvent: TSendDataEvent;
  AOnReceiveData: TReceiveDataEvent);
begin
  ANetHttpClient := TNetHTTPClient.Create(nil);
  ANetHttpClient.Accept := '*/*';
  ANetHttpClient.AcceptCharSet := 'utf-8';
  ANetHttpClient.AcceptEncoding := 'gzip, deflate, br';
  //ANetHttpClient.ContentType := 'multipart/form-data';
  ANetHttpClient.UserAgent :=
    'Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.0; Acoo Browser; ' +
    'GTB5; Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1) ; ' +
    'Maxthon; InfoPath.1; .NET CLR 3.5.30729; .NET CLR 3.0.30618)';

  ANetHttpRequest := TNetHTTPRequest.Create(nil);
  ANetHttpRequest.OnSendData := AOnSendDataEvent;
  ANetHttpRequest.OnReceiveData := AOnReceiveData;
  ANetHttpRequest.Client := ANetHttpClient;
end;

{ Runs the request started by AStart and waits at most ADeadlineMs (wall clock).
  Why: on Windows, THTTPClient.ResponseTimeout is not always honoured while the
  server has not sent the response headers yet (seen with Delphi 12 / WinHTTP:
  the first request of a process waited for the full server delay). A payment
  call must never hang longer than the caller asked, so the wait is enforced
  here. On timeout the request is cancelled and ENetHTTPClientException is
  raised (a transport error, see TIdeaLApi.IsTransportError). Exceptions raised
  by the request itself are re-raised unchanged by EndAsyncHTTP. }
function ExecuteWithDeadline(AClient: THTTPClient; ADeadlineMs: Integer;
  const AStart: TFunc<IAsyncResult>; out AKeepAlive: Boolean): IHTTPResponse;
var
  LAsync: IAsyncResult;
begin
  AKeepAlive := False;
  LAsync := AStart();
  if LAsync.AsyncWaitEvent.WaitFor(Cardinal(ADeadlineMs)) <> wrSignaled then
  begin
    LAsync.Cancel;
    // The worker uses AClient and the request stream: they may only be freed
    // after it has finished. Cancel closes the connection, so this is quick;
    // if it is not, leak them instead of freeing objects still in use.
    if LAsync.AsyncWaitEvent.WaitFor(30000) <> wrSignaled then
      AKeepAlive := True;
    raise ENetHTTPClientException.CreateFmt('Request timed out after %d ms', [ADeadlineMs]);
  end;
  Result := THTTPClient.EndAsyncHTTP(LAsync);
end;

function ResponseBodyOf(const AResponse: IHTTPResponse): string;
begin
  Result := EmptyStr;
  try
    Result := AResponse.ContentAsString(TEncoding.UTF8);
  except
    // unreadable body: keep the status only, as in 0.0.6
  end;
end;
{$ENDIF}

function TIdeaLApi.Post(AUrl, ABody: string; AHeaders: TNetHeaders): string;
begin
  Result := Post(AUrl, ABody, AHeaders, CDefaultConnectTimeout, CDefaultResponseTimeout);
end;

function TIdeaLApi.Post(AUrl, ABody: string; AHeaders: TNetHeaders;
  AConnectTimeout, AResponseTimeout: Integer): string;
{$IFNDEF FPC}
var
  LHttp: THTTPClient;
  LResponse: IHTTPResponse;
  LStrm: TStringStream;
  LKeepAlive: Boolean;
{$ENDIF}
begin
{$IFDEF FPC}
  Result := FpcRequest(Self, 'POST', AUrl, ABody, AHeaders, AConnectTimeout,
    AResponseTimeout, True);
{$ELSE}
  LHttp := THTTPClient.Create;
  LStrm := TStringStream.Create(ABody, TEncoding.UTF8, False);
  LKeepAlive := False;
  try
    LHttp.ConnectionTimeout := AConnectTimeout;
    LHttp.ResponseTimeout := AResponseTimeout;
    LHttp.HandleRedirects := FollowRedirects;
    LStrm.Position := 0;
    LResponse := ExecuteWithDeadline(LHttp, AConnectTimeout + AResponseTimeout,
      function: IAsyncResult
      begin
        Result := LHttp.BeginPost(AUrl, LStrm, nil, WithoutEmptyHeaders(AHeaders));
      end, LKeepAlive);
  finally
    if not LKeepAlive then
    begin
      LStrm.Free;
      FreeAndNil(LHttp);
    end;
  end;

  if (LResponse.StatusCode < 200) or (LResponse.StatusCode > 299) then
    raise EIdeaLApiError.Create(LResponse.StatusCode, LResponse.StatusText,
      ResponseBodyOf(LResponse), True);
  Result := LResponse.ContentAsString(TEncoding.UTF8);
{$ENDIF}
end;

function TIdeaLApi.Get(AUrl: string; AHeaders: TNetHeaders): string;
begin
  Result := Get(AUrl, AHeaders, CDefaultConnectTimeout, CDefaultResponseTimeout);
end;

function TIdeaLApi.Get(AUrl: string; AHeaders: TNetHeaders;
  AConnectTimeout, AResponseTimeout: Integer): string;
{$IFNDEF FPC}
var
  LHttp: THTTPClient;
  LResponse: IHTTPResponse;
  LKeepAlive: Boolean;
{$ENDIF}
begin
{$IFDEF FPC}
  Result := FpcRequest(Self, 'GET', AUrl, '', AHeaders, AConnectTimeout,
    AResponseTimeout, False);
{$ELSE}
  LHttp := THTTPClient.Create;
  LKeepAlive := False;
  try
    LHttp.ConnectionTimeout := AConnectTimeout;
    LHttp.ResponseTimeout := AResponseTimeout;
    LHttp.HandleRedirects := FollowRedirects;
    LResponse := ExecuteWithDeadline(LHttp, AConnectTimeout + AResponseTimeout,
      function: IAsyncResult
      begin
        Result := LHttp.BeginGet(AUrl, nil, WithoutEmptyHeaders(AHeaders));
      end, LKeepAlive);
  finally
    if not LKeepAlive then
      FreeAndNil(LHttp);
  end;

  if (LResponse.StatusCode < 200) or (LResponse.StatusCode > 299) then
    raise EIdeaLApiError.Create(LResponse.StatusCode, LResponse.StatusText,
      ResponseBodyOf(LResponse), False);
  Result := LResponse.ContentAsString(TEncoding.UTF8);
{$ENDIF}
end;

end.
