unit Test.IdeaL.Lib.Api.Compat;

{ Characterisation tests for TIdeaLApi written against the API of 0.0.6.
  They use only members that existed in 0.0.6 and must stay green after any
  change to the base class: other projects (and Alby, DePIX, DIGPIX, Exchange,
  ImgBB) depend on this behaviour. }

interface

uses
  DUnitX.TestFramework,
  Test.LocalHttpServer;

type
  [TestFixture]
  TIdeaLApiCompatTests = class
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
    procedure GetNetHttpRequest_KeepsDefaults;
    [Test]
    procedure Constructor_And_Free;
    [Test]
    procedure Get_200_ReturnsUtf8Body;
    [Test]
    procedure Get_204_ReturnsEmptyString;
    [Test]
    procedure Get_SendsGivenHeaders;
    [Test]
    procedure Get_404_RaisesWithStatusCodeAndText;
    [Test]
    procedure Get_500_MessageHasNoBody;
    [Test]
    procedure Get_FollowsRedirectByDefault;
    [Test]
    procedure Post_200_SendsUtf8BodyAndReturnsBody;
    [Test]
    procedure Post_SendsGivenHeaders;
    [Test]
    procedure Post_500_RaisesWithBodyInMessage;
    [Test]
    procedure Post_400_EmptyBody_MessageWithoutSeparator;
    [Test]
    procedure Error_IsAnException_CatchableAsException;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Net.URLClient,
  System.Net.HttpClient,
  System.Net.HttpClientComponent,
  IdeaL.Lib.Api;

const
  // "acao check" with Portuguese accents and a check mark, kept as code points
  // so that this source file stays ASCII.
  CUnicodeText = 'a' + #$00E7 + #$00E3 + 'o ' + #$2713;

{ TIdeaLApiCompatTests }

procedure TIdeaLApiCompatTests.SetupFixture;
begin
  FServer := TLocalHttpServer.Create;
end;

procedure TIdeaLApiCompatTests.TearDownFixture;
begin
  FServer.Free;
end;

procedure TIdeaLApiCompatTests.Setup;
begin
  FServer.Reset;
end;

procedure TIdeaLApiCompatTests.GetNetHttpRequest_KeepsDefaults;
var
  LClient: TNetHTTPClient;
  LRequest: TNetHTTPRequest;
begin
  TIdeaLApi.GetNetHttpRequest(LClient, LRequest);
  try
    Assert.AreEqual('*/*', LClient.Accept);
    Assert.AreEqual('utf-8', LClient.AcceptCharSet);
    Assert.AreEqual('gzip, deflate, br', LClient.AcceptEncoding);
    Assert.IsTrue(LClient.UserAgent.StartsWith('Mozilla/4.0 (compatible; MSIE 7.0;'));
    Assert.IsTrue(LRequest.Client = LClient);
  finally
    LRequest.Free;
    LClient.Free;
  end;
end;

procedure TIdeaLApiCompatTests.Constructor_And_Free;
var
  LApi: TIdeaLApi;
begin
  LApi := TIdeaLApi.Create;
  Assert.IsNotNull(LApi);
  LApi.Free;
end;

procedure TIdeaLApiCompatTests.Get_200_ReturnsUtf8Body;
var
  LApi: TIdeaLApi;
begin
  FServer.Handler :=
    procedure(const ARequest: TTestRequest; AResponse: TTestResponse)
    begin
      AResponse.Body := '{"text":"' + CUnicodeText + '"}';
    end;
  LApi := TIdeaLApi.Create;
  try
    Assert.AreEqual('{"text":"' + CUnicodeText + '"}', LApi.Get(FServer.Url('/x'), []));
    Assert.AreEqual('GET', FServer.LastRequest.Method);
    Assert.AreEqual('/x', FServer.LastRequest.Path);
  finally
    LApi.Free;
  end;
end;

procedure TIdeaLApiCompatTests.Get_204_ReturnsEmptyString;
var
  LApi: TIdeaLApi;
begin
  FServer.Handler :=
    procedure(const ARequest: TTestRequest; AResponse: TTestResponse)
    begin
      AResponse.StatusCode := 204;
    end;
  LApi := TIdeaLApi.Create;
  try
    Assert.AreEqual('', LApi.Get(FServer.Url('/empty'), []));
  finally
    LApi.Free;
  end;
end;

procedure TIdeaLApiCompatTests.Get_SendsGivenHeaders;
var
  LApi: TIdeaLApi;
begin
  LApi := TIdeaLApi.Create;
  try
    LApi.Get(FServer.Url('/h'), [TNameValuePair.Create('X-Test', 'abc'),
      TNameValuePair.Create('Authorization', 'Bearer t0k3n')]);
    Assert.AreEqual('abc', FServer.LastRequest.Header('X-Test'));
    Assert.AreEqual('Bearer t0k3n', FServer.LastRequest.Header('Authorization'));
  finally
    LApi.Free;
  end;
end;

procedure TIdeaLApiCompatTests.Get_404_RaisesWithStatusCodeAndText;
var
  LApi: TIdeaLApi;
  LMessage: string;
begin
  FServer.Handler :=
    procedure(const ARequest: TTestRequest; AResponse: TTestResponse)
    begin
      AResponse.StatusCode := 404;
      AResponse.StatusText := 'Not Found';
      AResponse.Body := 'nothing here';
    end;
  LApi := TIdeaLApi.Create;
  try
    LMessage := '';
    try
      LApi.Get(FServer.Url('/missing'), []);
    except
      on E: Exception do
        LMessage := E.Message;
    end;
    Assert.AreEqual('404 Not Found', LMessage);
  finally
    LApi.Free;
  end;
end;

procedure TIdeaLApiCompatTests.Get_500_MessageHasNoBody;
var
  LApi: TIdeaLApi;
  LMessage: string;
begin
  FServer.Handler :=
    procedure(const ARequest: TTestRequest; AResponse: TTestResponse)
    begin
      AResponse.StatusCode := 500;
      AResponse.StatusText := 'Internal Server Error';
      AResponse.Body := 'secret details';
    end;
  LApi := TIdeaLApi.Create;
  try
    LMessage := '';
    try
      LApi.Get(FServer.Url('/boom'), []);
    except
      on E: Exception do
        LMessage := E.Message;
    end;
    Assert.AreEqual('500 Internal Server Error', LMessage);
  finally
    LApi.Free;
  end;
end;

procedure TIdeaLApiCompatTests.Get_FollowsRedirectByDefault;
var
  LApi: TIdeaLApi;
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
    Assert.AreEqual('arrived', LApi.Get(FServer.Url('/from'), []));
  finally
    LApi.Free;
  end;
end;

procedure TIdeaLApiCompatTests.Post_200_SendsUtf8BodyAndReturnsBody;
var
  LApi: TIdeaLApi;
begin
  FServer.Handler :=
    procedure(const ARequest: TTestRequest; AResponse: TTestResponse)
    begin
      AResponse.Body := '{"ok":true}';
    end;
  LApi := TIdeaLApi.Create;
  try
    Assert.AreEqual('{"ok":true}', LApi.Post(FServer.Url('/p'), '{"memo":"' + CUnicodeText + '"}', []));
    Assert.AreEqual('POST', FServer.LastRequest.Method);
    Assert.AreEqual('{"memo":"' + CUnicodeText + '"}', FServer.LastRequest.Body);
  finally
    LApi.Free;
  end;
end;

procedure TIdeaLApiCompatTests.Post_SendsGivenHeaders;
var
  LApi: TIdeaLApi;
begin
  LApi := TIdeaLApi.Create;
  try
    LApi.Post(FServer.Url('/p'), '{}', [TNameValuePair.Create('Content-Type', 'application/json; charset=utf-8'),
      TNameValuePair.Create('x-api-key', 'k')]);
    Assert.AreEqual('k', FServer.LastRequest.Header('x-api-key'));
    Assert.IsTrue(FServer.LastRequest.Header('Content-Type').StartsWith('application/json'));
  finally
    LApi.Free;
  end;
end;

procedure TIdeaLApiCompatTests.Post_500_RaisesWithBodyInMessage;
var
  LApi: TIdeaLApi;
  LMessage: string;
begin
  FServer.Handler :=
    procedure(const ARequest: TTestRequest; AResponse: TTestResponse)
    begin
      AResponse.StatusCode := 500;
      AResponse.StatusText := 'Internal Server Error';
      AResponse.ContentType := 'text/plain; charset=utf-8';
      AResponse.Body := 'Invoice has already been paid';
    end;
  LApi := TIdeaLApi.Create;
  try
    LMessage := '';
    try
      LApi.Post(FServer.Url('/pay'), '{}', []);
    except
      on E: Exception do
        LMessage := E.Message;
    end;
    Assert.AreEqual('500 Internal Server Error - Invoice has already been paid', LMessage);
  finally
    LApi.Free;
  end;
end;

procedure TIdeaLApiCompatTests.Post_400_EmptyBody_MessageWithoutSeparator;
var
  LApi: TIdeaLApi;
  LMessage: string;
begin
  FServer.Handler :=
    procedure(const ARequest: TTestRequest; AResponse: TTestResponse)
    begin
      AResponse.StatusCode := 400;
      AResponse.StatusText := 'Bad Request';
    end;
  LApi := TIdeaLApi.Create;
  try
    LMessage := '';
    try
      LApi.Post(FServer.Url('/bad'), '{}', []);
    except
      on E: Exception do
        LMessage := E.Message;
    end;
    Assert.AreEqual('400 Bad Request', LMessage);
  finally
    LApi.Free;
  end;
end;

procedure TIdeaLApiCompatTests.Error_IsAnException_CatchableAsException;
var
  LApi: TIdeaLApi;
  LCaught: Boolean;
begin
  FServer.Handler :=
    procedure(const ARequest: TTestRequest; AResponse: TTestResponse)
    begin
      AResponse.StatusCode := 503;
    end;
  LApi := TIdeaLApi.Create;
  try
    LCaught := False;
    try
      LApi.Get(FServer.Url('/x'), []);
    except
      on E: Exception do
        LCaught := True;
    end;
    Assert.IsTrue(LCaught);
  finally
    LApi.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TIdeaLApiCompatTests);

end.
