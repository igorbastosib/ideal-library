unit TestBitcoinApisFpc;

{ fpcunit tests for the FPC branches of TAPIAlby, TAPIDePix, TAPIDigPix and
  TAPIExchange: same URLs, headers, bodies and input checks as the Delphi
  branches (see Tests/Delphi/Test.IdeaL.Lib.Api.Bitcoin.*.pas). Spy
  descendants record the URL each unit built and send the request to the
  in-process server. fpjson writes JSON with a space around ':' and after ',',
  Delphi without; the content is the same. No network. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry;

type
  TAlbyFpcTests = class(TTestCase)
  protected
    procedure SetUp; override;
  published
    procedure GetMe_Headers;
    procedure Urls;
    procedure Bodies;
    procedure PostWebWebHook_RequiresUrlAndFilterTypes;
    procedure Errors;
    procedure AuthToken_ReturnsSelf;
  end;

  TDePixFpcTests = class(TTestCase)
  protected
    procedure SetUp; override;
  published
    procedure GetPing_Headers;
    procedure XAsyncAndXNonce_Headers;
    procedure Urls;
    procedure PostDeposit_Bodies;
    procedure PostDeposit_InputChecks;
    procedure AnyTwoHundred_IsSuccess;
    procedure Errors;
  end;

  TDigPixFpcTests = class(TTestCase)
  protected
    procedure SetUp; override;
  published
    procedure GetQrCode_SendsApiKeyHeader;
    procedure PostQrCode_Bodies;
    procedure InputChecks;
    procedure OnlyTwoHundred_IsSuccess;
  end;

  TExchangeFpcTests = class(TTestCase)
  protected
    procedure SetUp; override;
  published
    procedure Urls_NoAuthorization;
    procedure Post_Body;
    procedure Errors;
  end;

implementation

uses
  DateUtils,
  TestServerFpc,
  IdeaL.Lib.Api.Bitcoin.Alby,
  IdeaL.Lib.Api.Bitcoin.DePIX,
  IdeaL.Lib.Api.Bitcoin.DIGPIX,
  IdeaL.Lib.Api.Bitcoin.Exchange;

const
  CTax = '12345678901';

type
  TSpyAlby = class(TAPIAlby)
  public
    LastUrl: string;
    function Del(AUrl: string): string; override;
    function Get(AUrl: string): string; override;
    function Post(AUrl, ABody: string): string; override;
  end;

  TSpyDePix = class(TAPIDePix)
  public
    LastUrl: string;
    function Get(AUrl: string): string; override;
    function Post(AUrl, ABody: string): string; override;
  end;

  TSpyDigPix = class(TAPIDigPix)
  public
    LastUrl: string;
    function Get(AUrl: string): string; override;
    function Post(AUrl, ABody: string): string; override;
  end;

  TSpyExchange = class(TAPIExchange)
  public
    LastUrl: string;
    function Get(AUrl: string): string; override;
    function Post(AUrl, ABody: string): string; override;
  end;

function TSpyAlby.Del(AUrl: string): string;
begin
  LastUrl := AUrl;
  Result := inherited Del(TestRebase(AUrl));
end;

function TSpyAlby.Get(AUrl: string): string;
begin
  LastUrl := AUrl;
  Result := inherited Get(TestRebase(AUrl));
end;

function TSpyAlby.Post(AUrl, ABody: string): string;
begin
  LastUrl := AUrl;
  Result := inherited Post(TestRebase(AUrl), ABody);
end;

function TSpyDePix.Get(AUrl: string): string;
begin
  LastUrl := AUrl;
  Result := inherited Get(TestRebase(AUrl));
end;

function TSpyDePix.Post(AUrl, ABody: string): string;
begin
  LastUrl := AUrl;
  Result := inherited Post(TestRebase(AUrl), ABody);
end;

function TSpyDigPix.Get(AUrl: string): string;
begin
  LastUrl := AUrl;
  Result := inherited Get(TestRebase(AUrl));
end;

function TSpyDigPix.Post(AUrl, ABody: string): string;
begin
  LastUrl := AUrl;
  Result := inherited Post(TestRebase(AUrl), ABody);
end;

function TSpyExchange.Get(AUrl: string): string;
begin
  LastUrl := AUrl;
  Result := inherited Get(TestRebase(AUrl));
end;

function TSpyExchange.Post(AUrl, ABody: string): string;
begin
  LastUrl := AUrl;
  Result := inherited Post(TestRebase(AUrl), ABody);
end;

{ TAlbyFpcTests }

procedure TAlbyFpcTests.SetUp;
begin
  StartTestServer;
  ResetScript;
  SetScript(200, 'ok');
end;

function NewAlby: TSpyAlby;
begin
  Result := TSpyAlby.Create;
  Result.AuthToken('tok');
end;

procedure TAlbyFpcTests.GetMe_Headers;
var
  LApi: TSpyAlby;
begin
  SetScript(200, '{"email":"a@b"}');
  LApi := NewAlby;
  try
    AssertEquals('{"email":"a@b"}', LApi.GetMe);
    AssertEquals('https://api.getalby.com/user/me', LApi.LastUrl);
    AssertEquals('GET', Seen.Method);
    AssertEquals('/user/me', Seen.Path);
    AssertEquals('Bearer tok', Seen.Authorization);
    AssertEquals('application/json', Seen.ContentType);
  finally
    LApi.Free;
  end;
end;

procedure TAlbyFpcTests.Urls;
var
  LApi: TSpyAlby;
  LStart, LEnd: TDateTime;
begin
  LStart := EncodeDateTime(2026, 1, 2, 3, 4, 5, 0);
  LEnd := EncodeDateTime(2026, 2, 3, 4, 5, 6, 0);
  LApi := NewAlby;
  try
    LApi.GetBalance;
    AssertEquals('https://api.getalby.com/balance', LApi.LastUrl);
    LApi.GetValue4Value;
    AssertEquals('https://api.getalby.com/user/value4value', LApi.LastUrl);
    LApi.GetInvoice('h1');
    AssertEquals('https://api.getalby.com/invoices/h1', LApi.LastUrl);
    LApi.GetWebWebHookById('w1');
    AssertEquals('https://api.getalby.com/webhook_endpoints/w1', LApi.LastUrl);
    LApi.GetInvoiceIn;
    AssertEquals('https://api.getalby.com/invoices/incoming', LApi.LastUrl);
    LApi.GetInvoiceIn(LStart, LEnd, True);
    AssertEquals('https://api.getalby.com/invoices/incoming?q[created_at_gt]=1767323045&q[created_at_lt]=1770091506', LApi.LastUrl);
    LApi.GetInvoiceOut(LStart, 0, True);
    AssertEquals('https://api.getalby.com/invoices/outgoing?q[created_at_gt]=1767323045', LApi.LastUrl);
    LApi.DelWebWebHookById('w1');
    AssertEquals('https://api.getalby.com/webhook_endpoints/w1', LApi.LastUrl);
    AssertEquals('DELETE', Seen.Method);
    AssertEquals('Bearer tok', Seen.Authorization);
  finally
    LApi.Free;
  end;
end;

procedure TAlbyFpcTests.Bodies;
var
  LApi: TSpyAlby;
  LTypes: array of string;
begin
  LApi := NewAlby;
  try
    LApi.PostInvoice(10);
    AssertEquals('https://api.getalby.com/invoices', LApi.LastUrl);
    AssertEquals('POST', Seen.Method);
    AssertEquals('{ "amount" : 10 }', Seen.Body);
    AssertEquals('Bearer tok', Seen.Authorization);
    LApi.PostInvoice(21, 'coffee');
    AssertEquals('{ "amount" : 21, "description" : "coffee" }', Seen.Body);
    LApi.PostInvoice('{"amount":5,"memo":"x"}');
    AssertEquals('{"amount":5,"memo":"x"}', Seen.Body);
    LApi.PostPaymentBolt11('lnbc1abc');
    AssertEquals('https://api.getalby.com/payments/bolt11', LApi.LastUrl);
    AssertEquals('{ "invoice" : "lnbc1abc" }', Seen.Body);
    SetLength(LTypes, 2);
    LTypes[0] := 'invoice.incoming.settled';
    LTypes[1] := 'invoice.outgoing.settled';
    LApi.PostWebWebHook('mine', 'https://example.com/hook', LTypes);
    AssertEquals('https://api.getalby.com/webhook_endpoints', LApi.LastUrl);
    AssertEquals('{ "description" : "mine", "url" : "https://example.com/hook", ' +
      '"filter_types" : ["invoice.incoming.settled", "invoice.outgoing.settled"] }', Seen.Body);
    LApi.PostWebWebHook('', 'https://example.com/hook', ['invoice.incoming.settled']);
    AssertEquals('{ "url" : "https://example.com/hook", "filter_types" : ["invoice.incoming.settled"] }', Seen.Body);
  finally
    LApi.Free;
  end;
end;

procedure TAlbyFpcTests.PostWebWebHook_RequiresUrlAndFilterTypes;
var
  LApi: TSpyAlby;
  LMsg: string;
begin
  LApi := NewAlby;
  try
    LMsg := '';
    try
      LApi.PostWebWebHook('d', ' ', ['a']);
    except
      on E: Exception do LMsg := E.Message;
    end;
    AssertEquals('Parameters AUrl and AFilterTypes are mandatory', LMsg);
    LMsg := '';
    try
      LApi.PostWebWebHook('d', 'https://example.com', []);
    except
      on E: Exception do LMsg := E.Message;
    end;
    AssertEquals('Parameters AUrl and AFilterTypes are mandatory', LMsg);
    AssertEquals('nothing sent', 0, Seen.Count);
  finally
    LApi.Free;
  end;
end;

procedure TAlbyFpcTests.Errors;
var
  LApi: TSpyAlby;
  LMsg: string;
begin
  LApi := NewAlby;
  try
    SetScript(201, '{"id":1}');
    AssertEquals('{"id":1}', LApi.PostInvoice(1));
    SetScript(204, '');
    AssertEquals('', LApi.DelWebWebHookById('w'));
    SetScript(202, 'g');
    AssertEquals('any 2xx is success, as on Delphi', 'g', LApi.GetBalance);
    SetScript(404, 'missing');
    LMsg := '';
    try
      LApi.GetBalance;
    except
      on E: Exception do LMsg := E.Message;
    end;
    AssertEquals('GET: no body in the message', '404 Not Found', LMsg);
    LMsg := '';
    try
      LApi.DelWebWebHookById('w');
    except
      on E: Exception do LMsg := E.Message;
    end;
    AssertEquals('DELETE: no body in the message', '404 Not Found', LMsg);
    SetScript(400, '{"error":"bad"}');
    LMsg := '';
    try
      LApi.PostInvoice(1);
    except
      on E: Exception do LMsg := E.Message;
    end;
    AssertEquals('POST: body in the message', '400 Bad Request - {"error":"bad"}', LMsg);
  finally
    LApi.Free;
  end;
end;

procedure TAlbyFpcTests.AuthToken_ReturnsSelf;
var
  LApi: TAPIAlby;
begin
  LApi := TAPIAlby.Create;
  try
    AssertSame(LApi, LApi.AuthToken('x'));
    AssertEquals('x', LApi.AuthToken);
  finally
    LApi.Free;
  end;
end;

{ TDePixFpcTests }

procedure TDePixFpcTests.SetUp;
begin
  StartTestServer;
  ResetScript;
  SetScript(200, 'ok');
end;

function NewDePix: TSpyDePix;
begin
  Result := TSpyDePix.Create;
  Result.AuthToken('tok');
end;

procedure TDePixFpcTests.GetPing_Headers;
var
  LApi: TSpyDePix;
begin
  SetScript(200, '{"response":{"msg":"pong"}}');
  LApi := NewDePix;
  try
    AssertEquals('{"response":{"msg":"pong"}}', LApi.GetPing);
    AssertEquals('https://depix.eulen.app/api/ping', LApi.LastUrl);
    AssertEquals('GET', Seen.Method);
    AssertEquals('/api/ping', Seen.Path);
    AssertEquals('Bearer tok', Seen.Authorization);
    AssertEquals('application/json', Seen.ContentType);
    AssertEquals('constructor default', 'false', Seen.XAsync);
    AssertEquals('not sent while empty', '', Seen.XNonce);
  finally
    LApi.Free;
  end;
end;

procedure TDePixFpcTests.XAsyncAndXNonce_Headers;
var
  LApi: TSpyDePix;
begin
  LApi := NewDePix;
  try
    LApi.XAsync('true').XNonce('n-1');
    LApi.PostDeposit(100, CTax);
    AssertEquals('true', Seen.XAsync);
    AssertEquals('n-1', Seen.XNonce);
    LApi.XAsync('').XNonce('');
    LApi.GetPing;
    AssertEquals('', Seen.XAsync);
    AssertEquals('', Seen.XNonce);
  finally
    LApi.Free;
  end;
end;

procedure TDePixFpcTests.Urls;
var
  LApi: TSpyDePix;
begin
  LApi := NewDePix;
  try
    LApi.GetDepositStatus('q1');
    AssertEquals('https://depix.eulen.app/api/deposit-status?id=q1', LApi.LastUrl);
    LApi.GetUserInfo('EU1');
    AssertEquals('https://depix.eulen.app/api/user-info?euid=EU1', LApi.LastUrl);
    LApi.GetDeposits('2026-07-01', '2026-07-05', 'pending');
    AssertEquals('https://depix.eulen.app/api/deposits?start=2026-07-01&end=2026-07-05&status=pending', LApi.LastUrl);
    LApi.GetDeposits(EncodeDate(2026, 7, 1), EncodeDate(2026, 12, 31), '');
    AssertEquals('https://depix.eulen.app/api/deposits?start=2026-07-01&end=2026-12-31', LApi.LastUrl);
    AssertEquals('/api/deposits', Seen.Path);
  finally
    LApi.Free;
  end;
end;

procedure TDePixFpcTests.PostDeposit_Bodies;
var
  LApi: TSpyDePix;
  LOld: TFormatSettings;
begin
  LOld := DefaultFormatSettings;
  DefaultFormatSettings.DecimalSeparator := '.';
  LApi := NewDePix;
  try
    LApi.PostDeposit(100, ' ' + CTax + ' ');
    AssertEquals('https://depix.eulen.app/api/deposit', LApi.LastUrl);
    AssertEquals('POST', Seen.Method);
    AssertEquals('{ "amountInCents" : 100, "endUserTaxNumber" : "12345678901" }', Seen.Body);
    LApi.PostDeposit(250, 'ex1addr', 'ex1split', '2.5', '12345678000199');
    AssertEquals('{ "amountInCents" : 250, "endUserTaxNumber" : "12345678000199", "depixAddress" : "ex1addr", ' +
      '"depixSplitAddress" : "ex1split", "splitFee" : "2.50%" }', Seen.Body);
    LApi.PostDeposit(250, '', 'ex1split', '', CTax);
    AssertEquals('{ "amountInCents" : 250, "endUserTaxNumber" : "12345678901" }', Seen.Body);
  finally
    LApi.Free;
    DefaultFormatSettings := LOld;
  end;
end;

procedure TDePixFpcTests.PostDeposit_InputChecks;
var
  LApi: TSpyDePix;
  LMsg: string;
begin
  LApi := NewDePix;
  try
    LMsg := '';
    try
      LApi.PostDeposit(99, CTax);
    except
      on E: Exception do LMsg := E.Message;
    end;
    AssertEquals('Invalid value [amount]', LMsg);
    LMsg := '';
    try
      LApi.PostDeposit(100, '1234567890');
    except
      on E: Exception do LMsg := E.Message;
    end;
    AssertEquals('Invalid value [endUserTaxNumber]', LMsg);
    AssertEquals('nothing sent', 0, Seen.Count);
  finally
    LApi.Free;
  end;
end;

procedure TDePixFpcTests.AnyTwoHundred_IsSuccess;
var
  LApi: TSpyDePix;
begin
  LApi := NewDePix;
  try
    SetScript(201, '{"id":"q"}');
    AssertEquals('{"id":"q"}', LApi.PostDeposit(100, CTax));
    SetScript(202, 'accepted');
    AssertEquals('accepted', LApi.GetPing);
  finally
    LApi.Free;
  end;
end;

procedure TDePixFpcTests.Errors;
var
  LApi: TSpyDePix;
  LMsg: string;
begin
  LApi := NewDePix;
  try
    SetScript(401, '{"errorMessage":"bad token"}');
    LMsg := '';
    try
      LApi.GetPing;
    except
      on E: Exception do LMsg := E.Message;
    end;
    AssertEquals('GET', '401 Unauthorized - {"errorMessage":"bad token"}', LMsg);
    LMsg := '';
    try
      LApi.PostDeposit(100, CTax);
    except
      on E: Exception do LMsg := E.Message;
    end;
    AssertEquals('POST', '401 Unauthorized - {"errorMessage":"bad token"}', LMsg);
    SetScript(500, '');
    LMsg := '';
    try
      LApi.GetPing;
    except
      on E: Exception do LMsg := E.Message;
    end;
    AssertEquals('empty body', '500 Internal Server Error', LMsg);
  finally
    LApi.Free;
  end;
end;

{ TDigPixFpcTests }

procedure TDigPixFpcTests.SetUp;
begin
  StartTestServer;
  ResetScript;
  SetScript(200, 'ok');
end;

function NewDigPix: TSpyDigPix;
begin
  Result := TSpyDigPix.Create;
  Result.AuthToken('key');
end;

procedure TDigPixFpcTests.GetQrCode_SendsApiKeyHeader;
var
  LApi: TSpyDigPix;
begin
  SetScript(200, '{"order_id":"o1"}');
  LApi := NewDigPix;
  try
    AssertEquals('{"order_id":"o1"}', LApi.GetQrCode('o1'));
    AssertEquals('https://vempradig.com/api/v1/pos/qrcode/o1', LApi.LastUrl);
    AssertEquals('GET', Seen.Method);
    AssertEquals('/api/v1/pos/qrcode/o1', Seen.Path);
    AssertEquals('key', Seen.XApiKey);
    AssertEquals('the key goes in X-API-Key only', '', Seen.Authorization);
    AssertEquals('application/json', Seen.ContentType);
  finally
    LApi.Free;
  end;
end;

procedure TDigPixFpcTests.PostQrCode_Bodies;
var
  LApi: TSpyDigPix;
begin
  LApi := NewDigPix;
  try
    LApi.PostQrCode(10.5, CTax);
    AssertEquals('https://vempradig.com/api/v1/pos/qrcode', LApi.LastUrl);
    AssertEquals('POST', Seen.Method);
    AssertEquals('{ "amount_cents" : 1050, "document" : "12345678901" }', Seen.Body);
    AssertEquals('key', Seen.XApiKey);
    AssertEquals('', Seen.Authorization);
    LApi.PostQrCode(25, '12345678000199', 'pix', 'order 7', 'https://example.com/hook', 's3cr3t');
    AssertEquals('{ "amount_cents" : 2500, "document" : "12345678000199", "payment_method" : "pix", ' +
      '"observation" : "order 7", "webhook" : "https://example.com/hook", "secret" : "s3cr3t" }', Seen.Body);
  finally
    LApi.Free;
  end;
end;

procedure TDigPixFpcTests.InputChecks;
var
  LApi: TSpyDigPix;
  LMsg: string;
begin
  LApi := NewDigPix;
  try
    LMsg := '';
    try
      LApi.GetQrCode('  ');
    except
      on E: Exception do LMsg := E.Message;
    end;
    AssertEquals('Invalid value [qr_id]', LMsg);
    LMsg := '';
    try
      LApi.PostQrCode(9.99, CTax);
    except
      on E: Exception do LMsg := E.Message;
    end;
    AssertEquals('Invalid value [amount]', LMsg);
    LMsg := '';
    try
      LApi.PostQrCode(10, CTax, '', '', 'https://example.com/h', '');
    except
      on E: Exception do LMsg := E.Message;
    end;
    AssertEquals('Invalid value [webhook]', LMsg);
    AssertEquals('nothing sent', 0, Seen.Count);
  finally
    LApi.Free;
  end;
end;

procedure TDigPixFpcTests.OnlyTwoHundred_IsSuccess;
var
  LApi: TSpyDigPix;
  LMsg: string;
begin
  LApi := NewDigPix;
  try
    SetScript(201, '{"id":"q"}');
    LMsg := '';
    try
      LApi.PostQrCode(10, CTax);
    except
      on E: Exception do LMsg := E.Message;
    end;
    AssertEquals('POST: 201 is an error for this unit, as on Delphi', '201 Created - {"id":"q"}', LMsg);
    LMsg := '';
    try
      LApi.GetQrCode('o1');
    except
      on E: Exception do LMsg := E.Message;
    end;
    AssertEquals('GET: 201 is an error for this unit, as on Delphi', '201 Created - {"id":"q"}', LMsg);
    SetScript(404, '{"detail":"not found"}');
    LMsg := '';
    try
      LApi.GetQrCode('o1');
    except
      on E: Exception do LMsg := E.Message;
    end;
    AssertEquals('404 Not Found - {"detail":"not found"}', LMsg);
  finally
    LApi.Free;
  end;
end;

{ TExchangeFpcTests }

procedure TExchangeFpcTests.SetUp;
begin
  StartTestServer;
  ResetScript;
  SetScript(200, 'ok');
end;

procedure TExchangeFpcTests.Urls_NoAuthorization;
var
  LApi: TSpyExchange;
begin
  SetScript(200, '{"USD":1}');
  LApi := TSpyExchange.Create;
  try
    AssertEquals('{"USD":1}', LApi.GetMemPoolSpacePrices);
    AssertEquals('https://mempool.space/api/v1/prices', LApi.LastUrl);
    AssertEquals('/api/v1/prices', Seen.Path);
    AssertEquals('', Seen.Authorization);
    AssertEquals('application/json', Seen.ContentType);
    LApi.GetCoinbasePricesBuy('BTC-BRL');
    AssertEquals('https://api.coinbase.com/v2/prices/BTC-BRL/buy', LApi.LastUrl);
    LApi.GetCoinOSRates;
    AssertEquals('https://coinos.io/api/rates', LApi.LastUrl);
    LApi.GetBinanceTicketPrice('BTCUSDT');
    AssertEquals('https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT', LApi.LastUrl);
    AssertEquals('symbol=BTCUSDT', Seen.Query);
  finally
    LApi.Free;
  end;
end;

procedure TExchangeFpcTests.Post_Body;
var
  LApi: TSpyExchange;
begin
  SetScript(200, '{"r":1}');
  LApi := TSpyExchange.Create;
  try
    AssertEquals('{"r":1}', LApi.Post('https://example.com/p', '{"a":1}'));
    AssertEquals('POST', Seen.Method);
    AssertEquals('/p', Seen.Path);
    AssertEquals('{"a":1}', Seen.Body);
    AssertEquals('', Seen.Authorization);
  finally
    LApi.Free;
  end;
end;

procedure TExchangeFpcTests.Errors;
var
  LApi: TSpyExchange;
  LMsg: string;
begin
  LApi := TSpyExchange.Create;
  try
    SetScript(201, 'x');
    LMsg := '';
    try
      LApi.GetCoinOSRates;
    except
      on E: Exception do LMsg := E.Message;
    end;
    AssertEquals('GET: only 200 is success', '201 Created', LMsg);
    SetScript(429, '{"code":-1003}');
    LMsg := '';
    try
      LApi.GetBinanceTicketPrice('BTCUSDT');
    except
      on E: Exception do LMsg := E.Message;
    end;
    AssertEquals('GET: no body in the message', '429 Too Many Requests', LMsg);
    LMsg := '';
    try
      LApi.Post('https://example.com/p', '{}');
    except
      on E: Exception do LMsg := E.Message;
    end;
    AssertEquals('POST: body in the message', '429 Too Many Requests - {"code":-1003}', LMsg);
  finally
    LApi.Free;
  end;
end;

initialization
  RegisterTest(TAlbyFpcTests);
  RegisterTest(TDePixFpcTests);
  RegisterTest(TDigPixFpcTests);
  RegisterTest(TExchangeFpcTests);

end.
