unit Test.IdeaL.Lib.Api.Bitcoin.Exchange;

{ TAPIExchange on Delphi. The unit never compiled on Delphi before 0.0.7
  (Post referred to an undeclared FAuthToken), so there is no Delphi behaviour
  to characterise: these tests pin the requests of the public methods as read
  from the source, and that no Authorization header is sent (see the comment
  in Post). A spy descendant records the URL and sends the request to the
  in-process server instead of the real hosts. No network. }

interface

uses
  DUnitX.TestFramework,
  Test.LocalHttpServer,
  IdeaL.Lib.Api.Bitcoin.Exchange;

type
  [TestFixture]
  TExchangeTests = class
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
    procedure Gets_UseTheirUrls_NoAuthorization;
    [Test]
    procedure Post_SendsBody_NoAuthorization;
    [Test]
    procedure OnlyTwoHundred_IsSuccess;
    [Test]
    procedure ErrorMessages;
  end;

implementation

uses
  System.SysUtils;

type
  TSpyExchange = class(TAPIExchange)
  public
    Server: TLocalHttpServer;
    LastUrl: string;
    function Get(AUrl: string): string; override;
    function Post(AUrl, ABody: string): string; override;
  end;

function TSpyExchange.Get(AUrl: string): string;
begin
  LastUrl := AUrl;
  Result := inherited Get(Server.Rebase(AUrl));
end;

function TSpyExchange.Post(AUrl, ABody: string): string;
begin
  LastUrl := AUrl;
  Result := inherited Post(Server.Rebase(AUrl), ABody);
end;

function NewApi(AServer: TLocalHttpServer): TSpyExchange;
begin
  Result := TSpyExchange.Create;
  Result.Server := AServer;
end;

{ TExchangeTests }

procedure TExchangeTests.SetupFixture;
begin
  FServer := TLocalHttpServer.Create;
end;

procedure TExchangeTests.TearDownFixture;
begin
  FServer.Free;
end;

procedure TExchangeTests.Setup;
begin
  FServer.Reset;
  Answer(200, '', 'ok');
end;

procedure TExchangeTests.Answer(AStatus: Integer; const AText, ABody: string);
begin
  FServer.Handler :=
    procedure(const ARequest: TTestRequest; AResponse: TTestResponse)
    begin
      AResponse.StatusCode := AStatus;
      AResponse.StatusText := AText;
      AResponse.Body := ABody;
    end;
end;

procedure TExchangeTests.Gets_UseTheirUrls_NoAuthorization;
var
  LApi: TSpyExchange;
begin
  Answer(200, '', '{"USD":1}');
  LApi := NewApi(FServer);
  try
    Assert.AreEqual('{"USD":1}', LApi.GetMemPoolSpacePrices);
    Assert.AreEqual('https://mempool.space/api/v1/prices', LApi.LastUrl);
    Assert.AreEqual('GET', FServer.LastRequest.Method);
    Assert.AreEqual('/api/v1/prices', FServer.LastRequest.Path);
    Assert.AreEqual('', FServer.LastRequest.Header('Authorization'));
    Assert.AreEqual('application/json; charset=utf-8', FServer.LastRequest.Header('Content-Type'));
    Assert.AreEqual('*/*', FServer.LastRequest.Header('Accept'));
    LApi.GetCoinbasePricesBuy('BTC-BRL');
    Assert.AreEqual('https://api.coinbase.com/v2/prices/BTC-BRL/buy', LApi.LastUrl);
    LApi.GetCoinOSRates;
    Assert.AreEqual('https://coinos.io/api/rates', LApi.LastUrl);
    LApi.GetBinanceTicketPrice('BTCUSDT');
    Assert.AreEqual('https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT', LApi.LastUrl);
    Assert.AreEqual('symbol=BTCUSDT', FServer.LastRequest.Query);
  finally
    LApi.Free;
  end;
end;

procedure TExchangeTests.Post_SendsBody_NoAuthorization;
var
  LApi: TSpyExchange;
begin
  Answer(200, '', '{"r":1}');
  LApi := NewApi(FServer);
  try
    Assert.AreEqual('{"r":1}', LApi.Post('https://example.com/p', '{"a":"caf'#$00E9'"}'));
    Assert.AreEqual('POST', FServer.LastRequest.Method);
    Assert.AreEqual('/p', FServer.LastRequest.Path);
    Assert.AreEqual('{"a":"caf'#$00E9'"}', FServer.LastRequest.Body, 'sent as UTF-8');
    Assert.AreEqual('', FServer.LastRequest.Header('Authorization'));
    Assert.AreEqual('application/json; charset=utf-8', FServer.LastRequest.Header('Content-Type'));
  finally
    LApi.Free;
  end;
end;

procedure TExchangeTests.OnlyTwoHundred_IsSuccess;
var
  LApi: TSpyExchange;
begin
  LApi := NewApi(FServer);
  try
    Answer(201, 'Created', 'x');
    Assert.AreEqual('201 Created', RaisedMessage(procedure begin LApi.GetCoinOSRates; end), 'GET');
    Assert.AreEqual('201 Created - x', RaisedMessage(procedure begin LApi.Post('https://example.com/p', '{}'); end), 'POST');
  finally
    LApi.Free;
  end;
end;

procedure TExchangeTests.ErrorMessages;
var
  LApi: TSpyExchange;
begin
  LApi := NewApi(FServer);
  try
    Answer(429, 'Slow down', '{"code":-1003}');
    Assert.AreEqual('429 Slow down', RaisedMessage(procedure begin LApi.GetBinanceTicketPrice('BTCUSDT'); end),
      'GET: no body in the message');
    Assert.AreEqual('429 Slow down - {"code":-1003}', RaisedMessage(procedure begin LApi.Post('https://example.com/p', '{}'); end),
      'POST: body in the message');
  finally
    LApi.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TExchangeTests);

end.
