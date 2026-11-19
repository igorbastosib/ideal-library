unit Test.IdeaL.Lib.Api.Bitcoin.DePIX;

{ Characterisation of TAPIDePix on Delphi: the request every public method
  builds (URL, method, headers, body), its input checks and how answers are
  handled, read from the 0.0.6 source. A spy descendant records the URL the
  unit built and sends the request to the in-process server instead of
  depix.eulen.app. No network. }

interface

uses
  DUnitX.TestFramework,
  Test.LocalHttpServer,
  IdeaL.Lib.Api.Bitcoin.DePIX;

type
  [TestFixture]
  TDePixTests = class
  private
    FServer: TLocalHttpServer;
    procedure Answer(AStatus: Integer; const AText, ABody: string);
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;
    [Setup]
    procedure Setup;

    [Test]
    procedure GetPing_SendsBearerJsonAndDefaultXAsync;
    [Test]
    procedure XAsyncAndXNonce_Headers;
    [Test]
    procedure Gets_UseTheirUrls;
    [Test]
    procedure GetDeposits_DateOverload_FormatsYyyyMmDd;
    [Test]
    procedure PostDeposit_MinimalBody;
    [Test]
    procedure PostDeposit_FullBody;
    [Test]
    procedure PostDeposit_InputChecks;
    [Test]
    procedure AnyTwoHundred_IsSuccess;
    [Test]
    procedure ErrorMessages_CarryTheBody;
    [Test]
    procedure FluentSetters_ReturnSelf;
  end;

implementation

uses
  System.SysUtils,
  System.DateUtils;

const
  CTax = '12345678901';

type
  TSpyDePix = class(TAPIDePix)
  public
    Server: TLocalHttpServer;
    LastUrl: string;
    function Get(AUrl: string): string; override;
    function Post(AUrl, ABody: string): string; override;
  end;

function TSpyDePix.Get(AUrl: string): string;
begin
  LastUrl := AUrl;
  Result := inherited Get(Server.Rebase(AUrl));
end;

function TSpyDePix.Post(AUrl, ABody: string): string;
begin
  LastUrl := AUrl;
  Result := inherited Post(Server.Rebase(AUrl), ABody);
end;

function NewApi(AServer: TLocalHttpServer): TSpyDePix;
begin
  Result := TSpyDePix.Create;
  Result.Server := AServer;
  Result.AuthToken('tok');
end;

{ TDePixTests }

procedure TDePixTests.SetupFixture;
begin
  FServer := TLocalHttpServer.Create;
end;

procedure TDePixTests.TearDownFixture;
begin
  FServer.Free;
end;

procedure TDePixTests.Setup;
begin
  FServer.Reset;
  Answer(200, '', 'ok');
end;

procedure TDePixTests.Answer(AStatus: Integer; const AText, ABody: string);
begin
  FServer.Handler :=
    procedure(const ARequest: TTestRequest; AResponse: TTestResponse)
    begin
      AResponse.StatusCode := AStatus;
      AResponse.StatusText := AText;
      AResponse.Body := ABody;
    end;
end;

procedure TDePixTests.GetPing_SendsBearerJsonAndDefaultXAsync;
var
  LApi: TSpyDePix;
begin
  Answer(200, '', '{"response":{"msg":"pong"}}');
  LApi := NewApi(FServer);
  try
    Assert.AreEqual('{"response":{"msg":"pong"}}', LApi.GetPing);
    Assert.AreEqual('https://depix.eulen.app/api/ping', LApi.LastUrl);
    Assert.AreEqual('GET', FServer.LastRequest.Method);
    Assert.AreEqual('/api/ping', FServer.LastRequest.Path);
    Assert.AreEqual('Bearer tok', FServer.LastRequest.Header('Authorization'));
    Assert.AreEqual('application/json; charset=utf-8', FServer.LastRequest.Header('Content-Type'));
    Assert.AreEqual('*/*', FServer.LastRequest.Header('Accept'));
    Assert.AreEqual('false', FServer.LastRequest.Header('X-Async'), 'constructor default');
    Assert.AreEqual('', FServer.LastRequest.Header('X-Nonce'), 'not sent while empty');
  finally
    LApi.Free;
  end;
end;

procedure TDePixTests.XAsyncAndXNonce_Headers;
var
  LApi: TSpyDePix;
begin
  LApi := NewApi(FServer);
  try
    LApi.XAsync('true').XNonce('n-1');
    LApi.PostDeposit(100, CTax);
    Assert.AreEqual('true', FServer.LastRequest.Header('X-Async'));
    Assert.AreEqual('n-1', FServer.LastRequest.Header('X-Nonce'));
    Assert.AreEqual('Bearer tok', FServer.LastRequest.Header('Authorization'));
    LApi.XAsync('').XNonce('');
    LApi.GetPing;
    Assert.AreEqual('', FServer.LastRequest.Header('X-Async'), 'blank X-Async is not sent');
    Assert.AreEqual('', FServer.LastRequest.Header('X-Nonce'));
  finally
    LApi.Free;
  end;
end;

procedure TDePixTests.Gets_UseTheirUrls;
var
  LApi: TSpyDePix;
begin
  LApi := NewApi(FServer);
  try
    LApi.GetDepositStatus('q1');
    Assert.AreEqual('https://depix.eulen.app/api/deposit-status?id=q1', LApi.LastUrl);
    LApi.GetUserInfo('EU1');
    Assert.AreEqual('https://depix.eulen.app/api/user-info?euid=EU1', LApi.LastUrl);
    LApi.GetDeposits('2026-07-01', '2026-07-05', '');
    Assert.AreEqual('https://depix.eulen.app/api/deposits?start=2026-07-01&end=2026-07-05', LApi.LastUrl);
    LApi.GetDeposits('2026-07-01', '2026-07-05', 'pending');
    Assert.AreEqual('https://depix.eulen.app/api/deposits?start=2026-07-01&end=2026-07-05&status=pending', LApi.LastUrl);
    Assert.AreEqual('/api/deposits', FServer.LastRequest.Path);
    Assert.AreEqual('GET', FServer.LastRequest.Method);
  finally
    LApi.Free;
  end;
end;

procedure TDePixTests.GetDeposits_DateOverload_FormatsYyyyMmDd;
var
  LApi: TSpyDePix;
begin
  LApi := NewApi(FServer);
  try
    LApi.GetDeposits(EncodeDate(2026, 7, 1), EncodeDate(2026, 12, 31), 'expired');
    Assert.AreEqual('https://depix.eulen.app/api/deposits?start=2026-07-01&end=2026-12-31&status=expired', LApi.LastUrl);
    LApi.GetDeposits(EncodeDateTime(2026, 1, 9, 23, 59, 0, 0), EncodeDate(2026, 1, 10), '');
    Assert.AreEqual('https://depix.eulen.app/api/deposits?start=2026-01-09&end=2026-01-10', LApi.LastUrl, 'time part is dropped');
  finally
    LApi.Free;
  end;
end;

procedure TDePixTests.PostDeposit_MinimalBody;
var
  LApi: TSpyDePix;
begin
  LApi := NewApi(FServer);
  try
    LApi.PostDeposit(100, ' ' + CTax + ' ');
    Assert.AreEqual('https://depix.eulen.app/api/deposit', LApi.LastUrl);
    Assert.AreEqual('POST', FServer.LastRequest.Method);
    Assert.AreEqual('{"amountInCents":100,"endUserTaxNumber":"12345678901"}', FServer.LastRequest.Body, 'tax number trimmed');
    Assert.AreEqual('application/json; charset=utf-8', FServer.LastRequest.Header('Content-Type'));
  finally
    LApi.Free;
  end;
end;

procedure TDePixTests.PostDeposit_FullBody;
var
  LApi: TSpyDePix;
  LOld: TFormatSettings;
begin
  // splitFee goes through StrToFloat/FormatFloat with the global FormatSettings:
  // pin the decimal separator so the test does not depend on the machine locale.
  LOld := FormatSettings;
  FormatSettings.DecimalSeparator := '.';
  LApi := NewApi(FServer);
  try
    LApi.PostDeposit(250, 'ex1addr', 'ex1split', '2.5', '12345678000199');
    Assert.AreEqual('{"amountInCents":250,"endUserTaxNumber":"12345678000199","depixAddress":"ex1addr",' +
      '"depixSplitAddress":"ex1split","splitFee":"2.50%"}', FServer.LastRequest.Body);
    LApi.PostDeposit(250, '', 'ex1split', '', CTax);
    Assert.AreEqual('{"amountInCents":250,"endUserTaxNumber":"12345678901"}', FServer.LastRequest.Body,
      'split address without fee is left out');
    LApi.PostDeposit(250, '', '', '3', CTax);
    Assert.AreEqual('{"amountInCents":250,"endUserTaxNumber":"12345678901"}', FServer.LastRequest.Body,
      'fee without split address is left out');
  finally
    LApi.Free;
    FormatSettings := LOld;
  end;
end;

procedure TDePixTests.PostDeposit_InputChecks;
var
  LApi: TSpyDePix;
begin
  LApi := NewApi(FServer);
  try
    Assert.AreEqual('Invalid value [amount]', RaisedMessage(procedure begin LApi.PostDeposit(99, CTax); end));
    Assert.AreEqual('Invalid value [amount]', RaisedMessage(procedure begin LApi.PostDeposit(10000001, CTax); end));
    Assert.AreEqual('Invalid value [endUserTaxNumber]', RaisedMessage(procedure begin LApi.PostDeposit(100, ''); end));
    Assert.AreEqual('Invalid value [endUserTaxNumber]', RaisedMessage(procedure begin LApi.PostDeposit(100, '1234567890'); end));
    Assert.AreEqual('Invalid value [endUserTaxNumber]', RaisedMessage(procedure begin LApi.PostDeposit(100, '123456789012345'); end));
    Assert.AreEqual(0, FServer.RequestCount, 'nothing sent');
    Assert.AreEqual('', RaisedMessage(procedure begin LApi.PostDeposit(10000000, '12345678901234'); end), 'upper bounds accepted');
  finally
    LApi.Free;
  end;
end;

procedure TDePixTests.AnyTwoHundred_IsSuccess;
var
  LApi: TSpyDePix;
begin
  LApi := NewApi(FServer);
  try
    Answer(201, '', '{"id":"q"}');
    Assert.AreEqual('{"id":"q"}', LApi.PostDeposit(100, CTax));
    Answer(202, '', 'accepted');
    Assert.AreEqual('accepted', LApi.GetPing);
  finally
    LApi.Free;
  end;
end;

procedure TDePixTests.ErrorMessages_CarryTheBody;
var
  LApi: TSpyDePix;
begin
  LApi := NewApi(FServer);
  try
    Answer(401, 'Nope', '{"errorMessage":"bad token"}');
    Assert.AreEqual('401 Nope - {"errorMessage":"bad token"}', RaisedMessage(procedure begin LApi.GetPing; end), 'GET');
    Assert.AreEqual('401 Nope - {"errorMessage":"bad token"}', RaisedMessage(procedure begin LApi.PostDeposit(100, CTax); end), 'POST');
    Answer(500, 'Oops', '');
    Assert.AreEqual('500 Oops', RaisedMessage(procedure begin LApi.GetPing; end), 'empty body');
  finally
    LApi.Free;
  end;
end;

procedure TDePixTests.FluentSetters_ReturnSelf;
var
  LApi: TAPIDePix;
begin
  LApi := TAPIDePix.Create;
  try
    Assert.AreEqual('false', LApi.XAsync, 'default');
    Assert.AreEqual('', LApi.XNonce, 'default');
    Assert.AreSame(LApi, LApi.AuthToken('a'));
    Assert.AreSame(LApi, LApi.XAsync('true'));
    Assert.AreSame(LApi, LApi.XNonce('n'));
    Assert.AreEqual('a', LApi.AuthToken);
    Assert.AreEqual('true', LApi.XAsync);
    Assert.AreEqual('n', LApi.XNonce);
  finally
    LApi.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDePixTests);

end.
