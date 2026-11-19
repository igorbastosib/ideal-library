unit Test.IdeaL.Lib.Api.Bitcoin.Alby;

{ Characterisation of TAPIAlby on Delphi: the request every public method
  builds (URL, method, headers, body) and how answers are handled, read from
  the 0.0.6 source. A spy descendant records the URL the unit built and sends
  the request to the in-process server instead of api.getalby.com. No network. }

interface

uses
  DUnitX.TestFramework,
  Test.LocalHttpServer,
  IdeaL.Lib.Api.Bitcoin.Alby;

type
  [TestFixture]
  TAlbyTests = class
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
    procedure GetMe_SendsBearerAndJsonHeaders;
    [Test]
    procedure SimpleGets_UseTheirUrls;
    [Test]
    procedure GetInvoiceInOut_DateFilters;
    [Test]
    procedure DelWebHook_UsesDelete;
    [Test]
    procedure PostInvoice_Bodies;
    [Test]
    procedure PostPaymentBolt11_Body;
    [Test]
    procedure PostWebWebHook_Body;
    [Test]
    procedure PostWebWebHook_RequiresUrlAndFilterTypes;
    [Test]
    procedure AnyTwoHundred_IsSuccess;
    [Test]
    procedure ErrorMessages;
    [Test]
    procedure AuthToken_ReturnsSelf;
  end;

implementation

uses
  System.SysUtils,
  System.DateUtils;

type
  TSpyAlby = class(TAPIAlby)
  public
    Server: TLocalHttpServer;
    LastUrl: string;
    function Del(AUrl: string): string; override;
    function Get(AUrl: string): string; override;
    function Post(AUrl, ABody: string): string; override;
  end;

function TSpyAlby.Del(AUrl: string): string;
begin
  LastUrl := AUrl;
  Result := inherited Del(Server.Rebase(AUrl));
end;

function TSpyAlby.Get(AUrl: string): string;
begin
  LastUrl := AUrl;
  Result := inherited Get(Server.Rebase(AUrl));
end;

function TSpyAlby.Post(AUrl, ABody: string): string;
begin
  LastUrl := AUrl;
  Result := inherited Post(Server.Rebase(AUrl), ABody);
end;

function NewApi(AServer: TLocalHttpServer): TSpyAlby;
begin
  Result := TSpyAlby.Create;
  Result.Server := AServer;
  Result.AuthToken('tok');
end;

{ TAlbyTests }

procedure TAlbyTests.SetupFixture;
begin
  FServer := TLocalHttpServer.Create;
end;

procedure TAlbyTests.TearDownFixture;
begin
  FServer.Free;
end;

procedure TAlbyTests.Setup;
begin
  FServer.Reset;
  Answer(200, '', 'ok');
end;

procedure TAlbyTests.Answer(AStatus: Integer; const AText, ABody: string);
begin
  FServer.Handler :=
    procedure(const ARequest: TTestRequest; AResponse: TTestResponse)
    begin
      AResponse.StatusCode := AStatus;
      AResponse.StatusText := AText;
      AResponse.Body := ABody;
    end;
end;

procedure TAlbyTests.GetMe_SendsBearerAndJsonHeaders;
var
  LApi: TSpyAlby;
begin
  Answer(200, '', '{"email":"a@b"}');
  LApi := NewApi(FServer);
  try
    Assert.AreEqual('{"email":"a@b"}', LApi.GetMe);
    Assert.AreEqual('https://api.getalby.com/user/me', LApi.LastUrl);
    Assert.AreEqual('GET', FServer.LastRequest.Method);
    Assert.AreEqual('/user/me', FServer.LastRequest.Path);
    Assert.AreEqual('Bearer tok', FServer.LastRequest.Header('Authorization'));
    Assert.AreEqual('application/json; charset=utf-8', FServer.LastRequest.Header('Content-Type'));
    Assert.AreEqual('*/*', FServer.LastRequest.Header('Accept'));
  finally
    LApi.Free;
  end;
end;

procedure TAlbyTests.SimpleGets_UseTheirUrls;
var
  LApi: TSpyAlby;
begin
  LApi := NewApi(FServer);
  try
    LApi.GetBalance;
    Assert.AreEqual('https://api.getalby.com/balance', LApi.LastUrl);
    LApi.GetValue4Value;
    Assert.AreEqual('https://api.getalby.com/user/value4value', LApi.LastUrl);
    LApi.GetInvoice('h1');
    Assert.AreEqual('https://api.getalby.com/invoices/h1', LApi.LastUrl);
    LApi.GetWebWebHookById('w1');
    Assert.AreEqual('https://api.getalby.com/webhook_endpoints/w1', LApi.LastUrl);
    Assert.AreEqual('GET', FServer.LastRequest.Method);
    Assert.AreEqual('/webhook_endpoints/w1', FServer.LastRequest.Path);
  finally
    LApi.Free;
  end;
end;

procedure TAlbyTests.GetInvoiceInOut_DateFilters;
var
  LApi: TSpyAlby;
  LStart, LEnd: TDateTime;
begin
  // 2026-01-02 03:04:05 UTC = 1767323045, 2026-02-03 04:05:06 UTC = 1770091506
  LStart := EncodeDateTime(2026, 1, 2, 3, 4, 5, 0);
  LEnd := EncodeDateTime(2026, 2, 3, 4, 5, 6, 0);
  LApi := NewApi(FServer);
  try
    LApi.GetInvoiceIn;
    Assert.AreEqual('https://api.getalby.com/invoices/incoming', LApi.LastUrl);
    LApi.GetInvoiceIn(LStart, LEnd, True);
    Assert.AreEqual('https://api.getalby.com/invoices/incoming?q[created_at_gt]=1767323045&q[created_at_lt]=1770091506', LApi.LastUrl);
    LApi.GetInvoiceIn(0, LEnd, True);
    Assert.AreEqual('https://api.getalby.com/invoices/incoming?q[created_at_lt]=1770091506', LApi.LastUrl);
    LApi.GetInvoiceOut;
    Assert.AreEqual('https://api.getalby.com/invoices/outgoing', LApi.LastUrl);
    LApi.GetInvoiceOut(LStart, 0, True);
    Assert.AreEqual('https://api.getalby.com/invoices/outgoing?q[created_at_gt]=1767323045', LApi.LastUrl);
    Assert.AreEqual('/invoices/outgoing', FServer.LastRequest.Path);
  finally
    LApi.Free;
  end;
end;

procedure TAlbyTests.DelWebHook_UsesDelete;
var
  LApi: TSpyAlby;
begin
  LApi := NewApi(FServer);
  try
    Assert.AreEqual('ok', LApi.DelWebWebHookById('w1'));
    Assert.AreEqual('https://api.getalby.com/webhook_endpoints/w1', LApi.LastUrl);
    Assert.AreEqual('DELETE', FServer.LastRequest.Method);
    Assert.AreEqual('Bearer tok', FServer.LastRequest.Header('Authorization'));
  finally
    LApi.Free;
  end;
end;

procedure TAlbyTests.PostInvoice_Bodies;
var
  LApi: TSpyAlby;
begin
  LApi := NewApi(FServer);
  try
    LApi.PostInvoice(10);
    Assert.AreEqual('https://api.getalby.com/invoices', LApi.LastUrl);
    Assert.AreEqual('POST', FServer.LastRequest.Method);
    Assert.AreEqual('{"amount":10}', FServer.LastRequest.Body);
    Assert.AreEqual('Bearer tok', FServer.LastRequest.Header('Authorization'));
    Assert.AreEqual('application/json; charset=utf-8', FServer.LastRequest.Header('Content-Type'));
    LApi.PostInvoice(21, 'coffee');
    Assert.AreEqual('{"amount":21,"description":"coffee"}', FServer.LastRequest.Body);
    LApi.PostInvoice(21, '  ');
    Assert.AreEqual('{"amount":21}', FServer.LastRequest.Body, 'blank description is left out');
    LApi.PostInvoice('{"amount":5,"memo":"x"}');
    Assert.AreEqual('{"amount":5,"memo":"x"}', FServer.LastRequest.Body, 'JSON overload sends the text as is');
  finally
    LApi.Free;
  end;
end;

procedure TAlbyTests.PostPaymentBolt11_Body;
var
  LApi: TSpyAlby;
begin
  LApi := NewApi(FServer);
  try
    LApi.PostPaymentBolt11('lnbc1abc');
    Assert.AreEqual('https://api.getalby.com/payments/bolt11', LApi.LastUrl);
    Assert.AreEqual('POST', FServer.LastRequest.Method);
    Assert.AreEqual('{"invoice":"lnbc1abc"}', FServer.LastRequest.Body);
  finally
    LApi.Free;
  end;
end;

procedure TAlbyTests.PostWebWebHook_Body;
var
  LApi: TSpyAlby;
begin
  LApi := NewApi(FServer);
  try
    LApi.PostWebWebHook('mine', 'https://example.com/hook', ['invoice.incoming.settled', 'invoice.outgoing.settled']);
    Assert.AreEqual('https://api.getalby.com/webhook_endpoints', LApi.LastUrl);
    Assert.AreEqual('POST', FServer.LastRequest.Method);
    Assert.AreEqual('{"description":"mine","url":"https://example.com/hook",' +
      '"filter_types":["invoice.incoming.settled","invoice.outgoing.settled"]}', FServer.LastRequest.Body);
    LApi.PostWebWebHook('', 'https://example.com/hook', ['invoice.incoming.settled']);
    Assert.AreEqual('{"url":"https://example.com/hook","filter_types":["invoice.incoming.settled"]}',
      FServer.LastRequest.Body, 'blank description is left out');
  finally
    LApi.Free;
  end;
end;

procedure TAlbyTests.PostWebWebHook_RequiresUrlAndFilterTypes;
var
  LApi: TSpyAlby;
begin
  LApi := NewApi(FServer);
  try
    Assert.AreEqual('Parameters AUrl and AFilterTypes are mandatory',
      RaisedMessage(procedure begin LApi.PostWebWebHook('d', ' ', ['a']); end));
    Assert.AreEqual('Parameters AUrl and AFilterTypes are mandatory',
      RaisedMessage(procedure begin LApi.PostWebWebHook('d', 'https://example.com', []); end));
    Assert.AreEqual(0, FServer.RequestCount, 'nothing sent');
  finally
    LApi.Free;
  end;
end;

procedure TAlbyTests.AnyTwoHundred_IsSuccess;
var
  LApi: TSpyAlby;
begin
  LApi := NewApi(FServer);
  try
    Answer(201, '', '{"id":1}');
    Assert.AreEqual('{"id":1}', LApi.PostInvoice(1));
    Answer(202, '', 'g');
    Assert.AreEqual('g', LApi.GetBalance);
    Answer(204, '', '');
    Assert.AreEqual('', LApi.DelWebWebHookById('w'));
  finally
    LApi.Free;
  end;
end;

procedure TAlbyTests.ErrorMessages;
var
  LApi: TSpyAlby;
begin
  LApi := NewApi(FServer);
  try
    Answer(404, 'Nope', 'missing');
    Assert.AreEqual('404 Nope', RaisedMessage(procedure begin LApi.GetBalance; end), 'GET: no body in the message');
    Assert.AreEqual('404 Nope', RaisedMessage(procedure begin LApi.DelWebWebHookById('w'); end), 'DELETE: no body in the message');
    Answer(400, 'Oops', '{"error":"bad"}');
    Assert.AreEqual('400 Oops - {"error":"bad"}', RaisedMessage(procedure begin LApi.PostInvoice(1); end), 'POST: body in the message');
  finally
    LApi.Free;
  end;
end;

procedure TAlbyTests.AuthToken_ReturnsSelf;
var
  LApi: TAPIAlby;
begin
  // 0.0.6 left Result unassigned, so chained calls used an undefined reference
  LApi := TAPIAlby.Create;
  try
    Assert.AreSame(LApi, LApi.AuthToken('x'));
    Assert.AreEqual('x', LApi.AuthToken);
  finally
    LApi.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TAlbyTests);

end.
