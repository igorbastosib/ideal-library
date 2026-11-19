unit Test.IdeaL.Lib.Api.Bitcoin.DIGPIX;

{ Characterisation of TAPIDigPix on Delphi: the request every public method
  builds (URL, method, headers, body), its input checks and how answers are
  handled, read from the 0.0.6 source. A spy descendant records the URL the
  unit built and sends the request to the in-process server instead of
  vempradig.com. No network. }

interface

uses
  DUnitX.TestFramework,
  Test.LocalHttpServer,
  IdeaL.Lib.Api.Bitcoin.DIGPIX;

type
  [TestFixture]
  TDigPixTests = class
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
    procedure GetQrCode_SendsApiKeyHeader;
    [Test]
    procedure GetQrCode_RequiresOrderId;
    [Test]
    procedure PostQrCode_MinimalBody;
    [Test]
    procedure PostQrCode_FullBody;
    [Test]
    procedure PostQrCode_InputChecks;
    [Test]
    procedure OnlyTwoHundred_IsSuccess;
    [Test]
    procedure ErrorMessages_CarryTheBody;
    [Test]
    procedure AuthToken_ReturnsSelf;
  end;

implementation

uses
  System.SysUtils;

const
  CDoc = '12345678901';

type
  TSpyDigPix = class(TAPIDigPix)
  public
    Server: TLocalHttpServer;
    LastUrl: string;
    function Get(AUrl: string): string; override;
    function Post(AUrl, ABody: string): string; override;
  end;

function TSpyDigPix.Get(AUrl: string): string;
begin
  LastUrl := AUrl;
  Result := inherited Get(Server.Rebase(AUrl));
end;

function TSpyDigPix.Post(AUrl, ABody: string): string;
begin
  LastUrl := AUrl;
  Result := inherited Post(Server.Rebase(AUrl), ABody);
end;

function NewApi(AServer: TLocalHttpServer): TSpyDigPix;
begin
  Result := TSpyDigPix.Create;
  Result.Server := AServer;
  Result.AuthToken('key');
end;

{ TDigPixTests }

procedure TDigPixTests.SetupFixture;
begin
  FServer := TLocalHttpServer.Create;
end;

procedure TDigPixTests.TearDownFixture;
begin
  FServer.Free;
end;

procedure TDigPixTests.Setup;
begin
  FServer.Reset;
  Answer(200, '', 'ok');
end;

procedure TDigPixTests.Answer(AStatus: Integer; const AText, ABody: string);
begin
  FServer.Handler :=
    procedure(const ARequest: TTestRequest; AResponse: TTestResponse)
    begin
      AResponse.StatusCode := AStatus;
      AResponse.StatusText := AText;
      AResponse.Body := ABody;
    end;
end;

procedure TDigPixTests.GetQrCode_SendsApiKeyHeader;
var
  LApi: TSpyDigPix;
begin
  Answer(200, '', '{"order_id":"o1"}');
  LApi := NewApi(FServer);
  try
    Assert.AreEqual('{"order_id":"o1"}', LApi.GetQrCode('o1'));
    Assert.AreEqual('https://vempradig.com/api/v1/pos/qrcode/o1', LApi.LastUrl);
    Assert.AreEqual('GET', FServer.LastRequest.Method);
    Assert.AreEqual('/api/v1/pos/qrcode/o1', FServer.LastRequest.Path);
    Assert.AreEqual('key', FServer.LastRequest.Header('X-API-Key'));
    Assert.AreEqual('', FServer.LastRequest.Header('Authorization'), 'the key goes in X-API-Key only');
    Assert.AreEqual('application/json; charset=utf-8', FServer.LastRequest.Header('Content-Type'));
    Assert.AreEqual('*/*', FServer.LastRequest.Header('Accept'));
  finally
    LApi.Free;
  end;
end;

procedure TDigPixTests.GetQrCode_RequiresOrderId;
var
  LApi: TSpyDigPix;
begin
  LApi := NewApi(FServer);
  try
    Assert.AreEqual('Invalid value [qr_id]', RaisedMessage(procedure begin LApi.GetQrCode(''); end));
    Assert.AreEqual('Invalid value [qr_id]', RaisedMessage(procedure begin LApi.GetQrCode('   '); end));
    Assert.AreEqual(0, FServer.RequestCount, 'nothing sent');
  finally
    LApi.Free;
  end;
end;

procedure TDigPixTests.PostQrCode_MinimalBody;
var
  LApi: TSpyDigPix;
begin
  LApi := NewApi(FServer);
  try
    LApi.PostQrCode(10.5, CDoc);
    Assert.AreEqual('https://vempradig.com/api/v1/pos/qrcode', LApi.LastUrl);
    Assert.AreEqual('POST', FServer.LastRequest.Method);
    Assert.AreEqual('{"amount_cents":1050,"document":"12345678901"}', FServer.LastRequest.Body);
    Assert.AreEqual('key', FServer.LastRequest.Header('X-API-Key'));
    Assert.AreEqual('', FServer.LastRequest.Header('Authorization'));
    Assert.AreEqual('application/json; charset=utf-8', FServer.LastRequest.Header('Content-Type'));
    LApi.PostQrCode(12.345, CDoc);
    Assert.AreEqual('{"amount_cents":1234,"document":"12345678901"}', FServer.LastRequest.Body, 'cents truncated');
  finally
    LApi.Free;
  end;
end;

procedure TDigPixTests.PostQrCode_FullBody;
var
  LApi: TSpyDigPix;
begin
  LApi := NewApi(FServer);
  try
    LApi.PostQrCode(25, '12345678000199', 'pix', 'order 7', 'https://example.com/hook', 's3cr3t');
    Assert.AreEqual('{"amount_cents":2500,"document":"12345678000199","payment_method":"pix",' +
      '"observation":"order 7","webhook":"https://example.com/hook","secret":"s3cr3t"}', FServer.LastRequest.Body);
    LApi.PostQrCode(25, CDoc, ' ', 'note', '', '');
    Assert.AreEqual('{"amount_cents":2500,"document":"12345678901","observation":"note"}', FServer.LastRequest.Body,
      'blank optional fields are left out');
  finally
    LApi.Free;
  end;
end;

procedure TDigPixTests.PostQrCode_InputChecks;
var
  LApi: TSpyDigPix;
begin
  LApi := NewApi(FServer);
  try
    Assert.AreEqual('Invalid value [amount]', RaisedMessage(procedure begin LApi.PostQrCode(9.99, CDoc); end));
    Assert.AreEqual('Invalid value [amount]', RaisedMessage(procedure begin LApi.PostQrCode(5000.01, CDoc); end));
    Assert.AreEqual('Invalid value [document]', RaisedMessage(procedure begin LApi.PostQrCode(10, ''); end));
    Assert.AreEqual('Invalid value [document]', RaisedMessage(procedure begin LApi.PostQrCode(10, '1234567890'); end));
    Assert.AreEqual('Invalid value [document]', RaisedMessage(procedure begin LApi.PostQrCode(10, '123456789012345'); end));
    Assert.AreEqual('Invalid value [observation]', RaisedMessage(
      procedure begin LApi.PostQrCode(10, CDoc, '', StringOfChar('o', 256), '', ''); end));
    Assert.AreEqual('Invalid value [webhook]', RaisedMessage(
      procedure begin LApi.PostQrCode(10, CDoc, '', '', 'ftp://example.com/h', 's'); end), 'not http');
    Assert.AreEqual('Invalid value [webhook]', RaisedMessage(
      procedure begin LApi.PostQrCode(10, CDoc, '', '', 'https://example.com/' + StringOfChar('h', 236), 's'); end), 'longer than 255');
    Assert.AreEqual('Invalid value [webhook]', RaisedMessage(
      procedure begin LApi.PostQrCode(10, CDoc, '', '', 'https://example.com/h', ''); end), 'webhook without secret');
    Assert.AreEqual('Invalid value [webhook]', RaisedMessage(
      procedure begin LApi.PostQrCode(10, CDoc, '', '', '', StringOfChar('s', 65)); end), 'secret longer than 64');
    Assert.AreEqual(0, FServer.RequestCount, 'nothing sent');
    Assert.AreEqual('', RaisedMessage(
      procedure begin LApi.PostQrCode(5000, '12345678901234', '', StringOfChar('o', 255), '', StringOfChar('s', 64)); end),
      'upper bounds accepted');
  finally
    LApi.Free;
  end;
end;

procedure TDigPixTests.OnlyTwoHundred_IsSuccess;
var
  LApi: TSpyDigPix;
begin
  LApi := NewApi(FServer);
  try
    Answer(201, 'Created', '{"id":"q"}');
    Assert.AreEqual('201 Created - {"id":"q"}', RaisedMessage(procedure begin LApi.PostQrCode(10, CDoc); end),
      'POST: 201 is an error for this unit');
    Assert.AreEqual('201 Created - {"id":"q"}', RaisedMessage(procedure begin LApi.GetQrCode('o1'); end),
      'GET: 201 is an error for this unit');
  finally
    LApi.Free;
  end;
end;

procedure TDigPixTests.ErrorMessages_CarryTheBody;
var
  LApi: TSpyDigPix;
begin
  LApi := NewApi(FServer);
  try
    Answer(404, 'Nope', '{"detail":"not found"}');
    Assert.AreEqual('404 Nope - {"detail":"not found"}', RaisedMessage(procedure begin LApi.GetQrCode('o1'); end), 'GET');
    Answer(400, 'Oops', '{"detail":"bad"}');
    Assert.AreEqual('400 Oops - {"detail":"bad"}', RaisedMessage(procedure begin LApi.PostQrCode(10, CDoc); end), 'POST');
  finally
    LApi.Free;
  end;
end;

procedure TDigPixTests.AuthToken_ReturnsSelf;
var
  LApi: TAPIDigPix;
begin
  LApi := TAPIDigPix.Create;
  try
    Assert.AreSame(LApi, LApi.AuthToken('k'));
    Assert.AreEqual('k', LApi.AuthToken);
  finally
    LApi.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDigPixTests);

end.
