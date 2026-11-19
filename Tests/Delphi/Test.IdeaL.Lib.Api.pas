unit Test.IdeaL.Lib.Api;

{ Tests for what 0.0.7 adds to TIdeaLApi: 2xx on POST, EIdeaLApiError,
  timeout overloads, FollowRedirects, IsTransportError. The 0.0.6 behaviour is
  pinned separately in Test.IdeaL.Lib.Api.Compat. }

interface

uses
  DUnitX.TestFramework,
  Test.LocalHttpServer;

type
  [TestFixture]
  TIdeaLApiTests = class
  private
    FServer: TLocalHttpServer;
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;
    [Setup]
    procedure Setup;

    [Test]
    procedure Defaults_AreSixtySeconds_AndRedirectsFollowed;
    [Test]
    procedure Post_201_IsAccepted;
    [Test]
    procedure Post_202_EmptyBody_ReturnsEmpty;
    [Test]
    procedure Get_Error_IsEIdeaLApiError_WithStatusAndFullBody;
    [Test]
    procedure Post_Error_IsEIdeaLApiError_WithStatusAndFullBody;
    [Test]
    procedure Error_MessageNeverContainsTheUrl;
    [Test]
    procedure Get_ResponseTimeout_RaisesTransportError;
    [Test]
    procedure Post_ResponseTimeout_RaisesTransportError;
    [Test]
    procedure Get_ConnectionRefused_IsTransportError;
    [Test]
    procedure FollowRedirectsFalse_3xxRaises;
    [Test]
    procedure IsTransportError_FalseForApiErrorsAndPlainExceptions;
    [Test]
    procedure OldOverloads_DelegateToTimeoutOverloads;
    [Test]
    procedure EmptyHeaderValues_AreNotSent_AndDoNotRaise;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Diagnostics,
  System.Net.URLClient,
  IdeaL.Lib.Api;

type
  TSpyApi = class(TIdeaLApi)
  public
    LastConnect, LastResponse: Integer;
    function Get(AUrl: string; AHeaders: TNetHeaders;
      AConnectTimeout, AResponseTimeout: Integer): string; override;
    function Post(AUrl, ABody: string; AHeaders: TNetHeaders;
      AConnectTimeout, AResponseTimeout: Integer): string; override;
  end;

function TSpyApi.Get(AUrl: string; AHeaders: TNetHeaders; AConnectTimeout,
  AResponseTimeout: Integer): string;
begin
  LastConnect := AConnectTimeout;
  LastResponse := AResponseTimeout;
  Result := 'spy-get';
end;

function TSpyApi.Post(AUrl, ABody: string; AHeaders: TNetHeaders;
  AConnectTimeout, AResponseTimeout: Integer): string;
begin
  LastConnect := AConnectTimeout;
  LastResponse := AResponseTimeout;
  Result := 'spy-post';
end;

{ TIdeaLApiTests }

procedure TIdeaLApiTests.SetupFixture;
begin
  FServer := TLocalHttpServer.Create;
end;

procedure TIdeaLApiTests.TearDownFixture;
begin
  FServer.Free;
end;

procedure TIdeaLApiTests.Setup;
begin
  FServer.Reset;
end;

procedure TIdeaLApiTests.Defaults_AreSixtySeconds_AndRedirectsFollowed;
var
  LApi: TIdeaLApi;
begin
  Assert.AreEqual(60000, TIdeaLApi.CDefaultConnectTimeout);
  Assert.AreEqual(60000, TIdeaLApi.CDefaultResponseTimeout);
  LApi := TIdeaLApi.Create;
  try
    Assert.IsTrue(LApi.FollowRedirects);
  finally
    LApi.Free;
  end;
end;

procedure TIdeaLApiTests.Post_201_IsAccepted;
var
  LApi: TIdeaLApi;
begin
  FServer.Handler :=
    procedure(const ARequest: TTestRequest; AResponse: TTestResponse)
    begin
      AResponse.StatusCode := 201;
      AResponse.Body := '{"id":1}';
    end;
  LApi := TIdeaLApi.Create;
  try
    Assert.AreEqual('{"id":1}', LApi.Post(FServer.Url('/new'), '{}', []));
  finally
    LApi.Free;
  end;
end;

procedure TIdeaLApiTests.Post_202_EmptyBody_ReturnsEmpty;
var
  LApi: TIdeaLApi;
begin
  FServer.Handler :=
    procedure(const ARequest: TTestRequest; AResponse: TTestResponse)
    begin
      AResponse.StatusCode := 202;
    end;
  LApi := TIdeaLApi.Create;
  try
    Assert.AreEqual('', LApi.Post(FServer.Url('/later'), '{}', []));
  finally
    LApi.Free;
  end;
end;

procedure TIdeaLApiTests.Get_Error_IsEIdeaLApiError_WithStatusAndFullBody;
var
  LApi: TIdeaLApi;
  LError: EIdeaLApiError;
begin
  FServer.Handler :=
    procedure(const ARequest: TTestRequest; AResponse: TTestResponse)
    begin
      AResponse.StatusCode := 404;
      AResponse.StatusText := 'Not Found';
      AResponse.Body := '{"error":"nothing here"}';
    end;
  LApi := TIdeaLApi.Create;
  try
    LError := nil;
    try
      LApi.Get(FServer.Url('/missing'), []);
    except
      on E: EIdeaLApiError do
      begin
        Assert.AreEqual(404, E.StatusCode);
        Assert.AreEqual('Not Found', E.StatusText);
        Assert.AreEqual('{"error":"nothing here"}', E.ResponseBody);
        Assert.AreEqual('404 Not Found', E.Message, 'GET message unchanged from 0.0.6');
        LError := E;
      end;
    end;
    Assert.IsNotNull(LError, 'EIdeaLApiError expected');
  finally
    LApi.Free;
  end;
end;

procedure TIdeaLApiTests.Post_Error_IsEIdeaLApiError_WithStatusAndFullBody;
var
  LApi: TIdeaLApi;
  LRaised: Boolean;
begin
  FServer.Handler :=
    procedure(const ARequest: TTestRequest; AResponse: TTestResponse)
    begin
      AResponse.StatusCode := 500;
      AResponse.StatusText := 'Internal Server Error';
      AResponse.ContentType := 'text/plain; charset=utf-8';
      AResponse.Body := 'Invalid pin';
    end;
  LApi := TIdeaLApi.Create;
  try
    LRaised := False;
    try
      LApi.Post(FServer.Url('/payments'), '{}', []);
    except
      on E: EIdeaLApiError do
      begin
        LRaised := True;
        Assert.AreEqual(500, E.StatusCode);
        Assert.AreEqual('Invalid pin', E.ResponseBody);
        Assert.AreEqual('500 Internal Server Error - Invalid pin', E.Message);
        Assert.IsFalse(TIdeaLApi.IsTransportError(E));
      end;
    end;
    Assert.IsTrue(LRaised);
  finally
    LApi.Free;
  end;
end;

procedure TIdeaLApiTests.Error_MessageNeverContainsTheUrl;
var
  LApi: TIdeaLApi;
  LMessage: string;
begin
  FServer.Handler :=
    procedure(const ARequest: TTestRequest; AResponse: TTestResponse)
    begin
      AResponse.StatusCode := 500;
      AResponse.Body := 'boom';
    end;
  LApi := TIdeaLApi.Create;
  try
    LMessage := '';
    try
      LApi.Get(FServer.Url('/payments/lnbc1secretinvoice'), []);
    except
      on E: Exception do
        LMessage := E.Message;
    end;
    Assert.IsFalse(LMessage.Contains('lnbc1secretinvoice'));
    Assert.IsFalse(LMessage.Contains('127.0.0.1'));
    LMessage := '';
    try
      LApi.Post(FServer.Url('/payments/lnbc1secretinvoice'), '{}', []);
    except
      on E: Exception do
        LMessage := E.Message;
    end;
    Assert.IsFalse(LMessage.Contains('lnbc1secretinvoice'));
  finally
    LApi.Free;
  end;
end;

procedure TIdeaLApiTests.Get_ResponseTimeout_RaisesTransportError;
var
  LApi: TIdeaLApi;
  LWatch: TStopwatch;
  LTransport: Boolean;
begin
  FServer.Handler :=
    procedure(const ARequest: TTestRequest; AResponse: TTestResponse)
    begin
      AResponse.DelayMs := 3000;
      AResponse.Body := 'late';
    end;
  LApi := TIdeaLApi.Create;
  try
    LTransport := False;
    LWatch := TStopwatch.StartNew;
    try
      LApi.Get(FServer.Url('/slow'), [], 2000, 500);
    except
      on E: Exception do
        LTransport := TIdeaLApi.IsTransportError(E) and not (E is EIdeaLApiError);
    end;
    LWatch.Stop;
    Assert.IsTrue(LTransport, 'a timeout must be a transport error');
    // deadline = connect + response timeout = 2500 ms, server answers after 3000 ms
    Assert.IsTrue(LWatch.ElapsedMilliseconds < 2900, 'deadline honoured: ' + LWatch.ElapsedMilliseconds.ToString + ' ms');
  finally
    LApi.Free;
  end;
  Sleep(2700); // let the delayed server thread finish before the next test
end;

procedure TIdeaLApiTests.Post_ResponseTimeout_RaisesTransportError;
var
  LApi: TIdeaLApi;
  LTransport: Boolean;
begin
  FServer.Handler :=
    procedure(const ARequest: TTestRequest; AResponse: TTestResponse)
    begin
      AResponse.DelayMs := 3000;
    end;
  LApi := TIdeaLApi.Create;
  try
    LTransport := False;
    try
      LApi.Post(FServer.Url('/slow'), '{}', [], 2000, 500);
    except
      on E: Exception do
        LTransport := TIdeaLApi.IsTransportError(E);
    end;
    Assert.IsTrue(LTransport);
  finally
    LApi.Free;
  end;
  Sleep(2700);
end;

procedure TIdeaLApiTests.Get_ConnectionRefused_IsTransportError;
var
  LApi: TIdeaLApi;
  LTransport: Boolean;
begin
  LApi := TIdeaLApi.Create;
  try
    LTransport := False;
    try
      // port 1 on loopback: nothing listens there
      LApi.Get('http://127.0.0.1:1/x', [], 2000, 2000);
    except
      on E: Exception do
        LTransport := TIdeaLApi.IsTransportError(E);
    end;
    Assert.IsTrue(LTransport);
  finally
    LApi.Free;
  end;
end;

procedure TIdeaLApiTests.FollowRedirectsFalse_3xxRaises;
var
  LApi: TIdeaLApi;
  LStatus: Integer;
begin
  FServer.Handler :=
    procedure(const ARequest: TTestRequest; AResponse: TTestResponse)
    begin
      if ARequest.Path = '/from' then
      begin
        AResponse.StatusCode := 302;
        AResponse.Location := '/to';
      end
      else
        AResponse.Body := 'arrived';
    end;
  LApi := TIdeaLApi.Create;
  try
    LApi.FollowRedirects := False;
    LStatus := 0;
    try
      LApi.Get(FServer.Url('/from'), []);
    except
      on E: EIdeaLApiError do
        LStatus := E.StatusCode;
    end;
    Assert.AreEqual(302, LStatus);
    Assert.AreEqual(1, FServer.RequestCount, 'the redirect target must not be requested');
  finally
    LApi.Free;
  end;
end;

procedure TIdeaLApiTests.IsTransportError_FalseForApiErrorsAndPlainExceptions;
var
  LApiError: EIdeaLApiError;
  LPlain: Exception;
begin
  Assert.IsFalse(TIdeaLApi.IsTransportError(nil));
  LApiError := EIdeaLApiError.Create(500, 'x', 'y', True);
  LPlain := Exception.Create('x');
  try
    Assert.IsFalse(TIdeaLApi.IsTransportError(LApiError));
    Assert.IsFalse(TIdeaLApi.IsTransportError(LPlain));
  finally
    LApiError.Free;
    LPlain.Free;
  end;
end;

procedure TIdeaLApiTests.OldOverloads_DelegateToTimeoutOverloads;
var
  LSpy: TSpyApi;
begin
  LSpy := TSpyApi.Create;
  try
    Assert.AreEqual('spy-get', LSpy.Get('http://unused', []));
    Assert.AreEqual(60000, LSpy.LastConnect);
    Assert.AreEqual(60000, LSpy.LastResponse);
    LSpy.LastConnect := 0;
    Assert.AreEqual('spy-post', LSpy.Post('http://unused', '{}', []));
    Assert.AreEqual(60000, LSpy.LastConnect);
    Assert.AreEqual(60000, LSpy.LastResponse);
  finally
    LSpy.Free;
  end;
end;

procedure TIdeaLApiTests.EmptyHeaderValues_AreNotSent_AndDoNotRaise;
var
  LApi: TIdeaLApi;
begin
  // Up to 0.0.6 an empty header value made WinHTTP fail with 12150
  // ("Error adding header"), e.g. CoinOS login with an empty x-api-key.
  FServer.Handler :=
    procedure(const ARequest: TTestRequest; AResponse: TTestResponse)
    begin
      AResponse.Body := 'ok';
    end;
  LApi := TIdeaLApi.Create;
  try
    Assert.AreEqual('ok', LApi.Get(FServer.Url('/g'), [TNameValuePair.Create('x-api-key', ''),
      TNameValuePair.Create('X-Test', 'kept')]));
    Assert.AreEqual('kept', FServer.LastRequest.Header('X-Test'));
    Assert.AreEqual(-1, FServer.LastRequest.Headers.IndexOfName('x-api-key'), 'empty header not sent');
    Assert.AreEqual('ok', LApi.Post(FServer.Url('/p'), '{}', [TNameValuePair.Create('x-api-key', '')]));
    Assert.AreEqual(-1, FServer.LastRequest.Headers.IndexOfName('x-api-key'));
  finally
    LApi.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TIdeaLApiTests);

end.
