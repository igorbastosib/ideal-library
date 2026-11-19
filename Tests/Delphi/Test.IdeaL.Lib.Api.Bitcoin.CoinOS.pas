unit Test.IdeaL.Lib.Api.Bitcoin.CoinOS;

{ TAPICoinOS against the in-process server. The "Compat" tests pin the request
  each 0.0.6 method sends (method, path, body, headers), read from the 0.0.6
  source; the others cover what 0.0.7 adds or fixes. No network. }

interface

uses
  DUnitX.TestFramework,
  Test.LocalHttpServer,
  IdeaL.Lib.Api.Bitcoin.CoinOS;

type
  [TestFixture]
  TCoinOSTests = class
  private
    FServer: TLocalHttpServer;
    function NewApi: TAPICoinOS;
    procedure AnswerJson(const AJson: string);
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;
    [Setup]
    procedure Setup;

    // 0.0.6 behaviour
    [Test]
    procedure Compat_GetMe_SendsBearerToken;
    [Test]
    procedure Compat_SimpleGets_UseTheirPaths;
    [Test]
    procedure Compat_GetPayments_Query;
    [Test]
    procedure Compat_PostRegister_Body;
    [Test]
    procedure Compat_PostLogin_BodyAndHeaderArray;
    [Test]
    procedure PostLogin_EmptyXApiKey_DoesNotRaise;
    [Test]
    procedure Compat_PostUser_SendsJsonAsIs;
    [Test]
    procedure Compat_PostInvoice_Bodies;
    [Test]
    procedure Compat_PostPaymentToUser_Body;
    [Test]
    procedure Compat_PostBitcoinSend_Body;
    [Test]
    procedure Compat_DefaultBaseUrl;

    // 0.0.7
    [Test]
    procedure BaseUrl_TrailingSlashIsRemoved;
    [Test]
    procedure HeaderArray_IsSentOnGetToo;
    [Test]
    procedure CallsThroughBaseReference_CarryCoinOSHeaders;
    [Test]
    procedure PostPayment_SendsFeeNotMaxfee_AndOnlyGivenFields;
    [Test]
    procedure PostPayment_NormalisesInvoice;
    [Test]
    procedure PostPayment_UsesPaymentTimeout;
    [Test]
    procedure PostPayment_ErrorAnswer_IsEIdeaLApiError;
    [Test]
    procedure PostPaymentLnAddress_FeeZeroIsOmitted_PinSent;
    [Test]
    procedure GetPayment_NullOrEmptyMeansNoRecord;
    [Test]
    procedure GetPayment_ReturnsRecord_LowercasePath;
    [Test]
    procedure GetPayment_RefusesNonBech32WithoutRequest;
    [Test]
    procedure GetPayment_ServerError_IsEIdeaLApiError;
    [Test]
    procedure GetPaymentState_Mapping;
    [Test]
    procedure GetPaymentState_RefusesUnexpectedAnswers;
    [Test]
    procedure QuoteAndDecode_Paths;
    [Test]
    procedure NormalizeInvoice_Cases;
  end;

implementation

uses
  System.SysUtils,
  System.DateUtils,
  System.Net.URLClient,
  IdeaL.Lib.Api;

const
  CInvoice = 'lnbc2500u1pvjluezsp5zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zygspp5qqqsyqcyq5rqwzqfqqqsyqcyq' +
    '5rqwzqfqqqsyqcyq5rqwzqfqypqdq5xysxxatsyp3k7enxv4jsxqzpu9qrsgquk0rl77nj30yxdy8j9vdx85fkpmdla2087ne0xh8nhedh' +
    '8w27kyke0lp53ut353s06fv3qfegext0eh0ymjpf39tuven09sam30g4vgpfna3rh';

type
  TSpyCoinOS = class(TAPICoinOS)
  public
    LastConnect, LastResponse: Integer;
    function Post(AUrl, ABody: string; AHeaders: TNetHeaders;
      AConnectTimeout, AResponseTimeout: Integer): string; override;
  end;

function TSpyCoinOS.Post(AUrl, ABody: string; AHeaders: TNetHeaders;
  AConnectTimeout, AResponseTimeout: Integer): string;
begin
  LastConnect := AConnectTimeout;
  LastResponse := AResponseTimeout;
  Result := inherited Post(AUrl, ABody, AHeaders, AConnectTimeout, AResponseTimeout);
end;

{ TCoinOSTests }

procedure TCoinOSTests.SetupFixture;
begin
  FServer := TLocalHttpServer.Create;
end;

procedure TCoinOSTests.TearDownFixture;
begin
  FServer.Free;
end;

procedure TCoinOSTests.Setup;
begin
  FServer.Reset;
end;

function TCoinOSTests.NewApi: TAPICoinOS;
begin
  Result := TAPICoinOS.Create;
  Result.BaseUrl(FServer.Url('/api')).AuthToken('tok');
end;

procedure TCoinOSTests.AnswerJson(const AJson: string);
begin
  FServer.Handler :=
    procedure(const ARequest: TTestRequest; AResponse: TTestResponse)
    begin
      AResponse.Body := AJson;
    end;
end;

procedure TCoinOSTests.Compat_GetMe_SendsBearerToken;
var
  LApi: TAPICoinOS;
begin
  AnswerJson('{"username":"alice"}');
  LApi := NewApi;
  try
    Assert.AreEqual('{"username":"alice"}', LApi.GetMe);
    Assert.AreEqual('GET', FServer.LastRequest.Method);
    Assert.AreEqual('/api/me', FServer.LastRequest.Path);
    Assert.AreEqual('Bearer tok', FServer.LastRequest.Header('Authorization'));
    Assert.AreEqual('*/*', FServer.LastRequest.Header('Accept'));
  finally
    LApi.Free;
  end;
end;

procedure TCoinOSTests.Compat_SimpleGets_UseTheirPaths;
var
  LApi: TAPICoinOS;
begin
  AnswerJson('ok');
  LApi := NewApi;
  try
    LApi.GetRates;
    Assert.AreEqual('/api/rates', FServer.LastRequest.Path);
    LApi.GetCredits;
    Assert.AreEqual('/api/credits', FServer.LastRequest.Path);
    LApi.GetInvoice('abc123');
    Assert.AreEqual('/api/invoice/abc123', FServer.LastRequest.Path);
    Assert.AreEqual('ok', LApi.GetRo);
    Assert.AreEqual('/api/ro', FServer.LastRequest.Path);
    Assert.AreEqual('Bearer tok', FServer.LastRequest.Header('Authorization'));
  finally
    LApi.Free;
  end;
end;

procedure TCoinOSTests.Compat_GetPayments_Query;
var
  LApi: TAPICoinOS;
  LStart, LEnd: TDateTime;
begin
  AnswerJson('{"payments":[]}');
  LApi := NewApi;
  try
    LApi.GetPayments;
    Assert.AreEqual('/api/payments', FServer.LastRequest.Path);
    Assert.AreEqual('', FServer.LastRequest.Query);
    LStart := EncodeDateTime(2026, 1, 2, 3, 4, 5, 0);
    LEnd := EncodeDateTime(2026, 2, 2, 3, 4, 5, 0);
    LApi.GetPayments(LStart, LEnd, 5, 10);
    Assert.AreEqual(Format('start=%d&end=%d&limit=5&offset=10',
      [DateTimeToUnix(LStart) * 1000, DateTimeToUnix(LEnd) * 1000]), FServer.LastRequest.Query);
    LApi.GetPayments(0, 0, 3);
    Assert.AreEqual('limit=3', FServer.LastRequest.Query);
  finally
    LApi.Free;
  end;
end;

procedure TCoinOSTests.Compat_PostRegister_Body;
var
  LApi: TAPICoinOS;
begin
  AnswerJson('{}');
  LApi := NewApi;
  try
    LApi.PostRegister('u', 'p');
    Assert.AreEqual('POST', FServer.LastRequest.Method);
    Assert.AreEqual('/api/register', FServer.LastRequest.Path);
    Assert.AreEqual('{"user":{"username":"u","password":"p"}}', FServer.LastRequest.Body);
    Assert.IsTrue(FServer.LastRequest.Header('Content-Type').StartsWith('application/json'));
  finally
    LApi.Free;
  end;
end;

procedure TCoinOSTests.Compat_PostLogin_BodyAndHeaderArray;
var
  LApi: TAPICoinOS;
begin
  AnswerJson('{"token":"t"}');
  LApi := NewApi;
  try
    LApi.HeaderArray([TAPICoinOS.THeaderPair.Create('x-api-key', 'captcha-skip')]).PostLogin('u', 'p');
    Assert.AreEqual('/api/login', FServer.LastRequest.Path);
    Assert.AreEqual('{"username":"u","password":"p"}', FServer.LastRequest.Body);
    Assert.AreEqual('captcha-skip', FServer.LastRequest.Header('x-api-key'));
  finally
    LApi.Free;
  end;
end;

procedure TCoinOSTests.Compat_PostUser_SendsJsonAsIs;
var
  LApi: TAPICoinOS;
begin
  AnswerJson('{}');
  LApi := NewApi;
  try
    LApi.PostUser('{"currency":"BRL"}');
    Assert.AreEqual('/api/user', FServer.LastRequest.Path);
    Assert.AreEqual('{"currency":"BRL"}', FServer.LastRequest.Body);
  finally
    LApi.Free;
  end;
end;

procedure TCoinOSTests.Compat_PostInvoice_Bodies;
var
  LApi: TAPICoinOS;
begin
  AnswerJson('{}');
  LApi := NewApi;
  try
    LApi.PostInvoiceLightning(100);
    Assert.AreEqual('/api/invoice', FServer.LastRequest.Path);
    Assert.AreEqual('{"invoice":{"amount":100,"type":"lightning"}}', FServer.LastRequest.Body);
    LApi.PostInvoice('lightning', 100, 'https://hook.example/x', 's3', 60);
    Assert.AreEqual('{"invoice":{"amount":100,"type":"lightning","webhook":"https://hook.example/x","secret":"s3","expiry":60}}',
      FServer.LastRequest.Body);
    LApi.PostInvoiceBitcoin(5000);
    Assert.AreEqual('{"invoice":{"amount":5000,"type":"bitcoin"}}', FServer.LastRequest.Body);
  finally
    LApi.Free;
  end;
end;

procedure TCoinOSTests.Compat_PostPaymentToUser_Body;
var
  LApi: TAPICoinOS;
begin
  AnswerJson('{}');
  LApi := NewApi;
  try
    LApi.PostPaymentToUser(5, 'bob');
    Assert.AreEqual('/api/invoice', FServer.LastRequest.Path);
    Assert.AreEqual('{"invoice":{"amount":5,"type":"lightning"},"user":{"username":"bob"}}', FServer.LastRequest.Body);
  finally
    LApi.Free;
  end;
end;

procedure TCoinOSTests.Compat_PostBitcoinSend_Body;
var
  LApi: TAPICoinOS;
begin
  AnswerJson('{}');
  LApi := NewApi;
  try
    LApi.PostBitcoinSend(1000, 'bc1qexample');
    Assert.AreEqual('/api/bitcoin/send', FServer.LastRequest.Path);
    Assert.AreEqual('{"amount":1000,"address":"bc1qexample"}', FServer.LastRequest.Body);
  finally
    LApi.Free;
  end;
end;

procedure TCoinOSTests.Compat_DefaultBaseUrl;
var
  LApi: TAPICoinOS;
begin
  LApi := TAPICoinOS.Create;
  try
    Assert.AreEqual('https://coinos.io/api', LApi.BaseUrl);
    Assert.AreEqual(TAPICoinOS.CUrlApi, LApi.BaseUrl);
    Assert.AreEqual(90000, LApi.PaymentTimeout);
  finally
    LApi.Free;
  end;
end;

procedure TCoinOSTests.BaseUrl_TrailingSlashIsRemoved;
var
  LApi: TAPICoinOS;
begin
  AnswerJson('{}');
  LApi := NewApi;
  try
    LApi.BaseUrl(FServer.Url('/api/'));
    LApi.GetMe;
    Assert.AreEqual('/api/me', FServer.LastRequest.Path);
  finally
    LApi.Free;
  end;
end;

procedure TCoinOSTests.HeaderArray_IsSentOnGetToo;
var
  LApi: TAPICoinOS;
begin
  AnswerJson('{}');
  LApi := NewApi;
  try
    LApi.HeaderArray([TAPICoinOS.THeaderPair.Create('x-api-key', 'k1')]).GetMe;
    Assert.AreEqual('k1', FServer.LastRequest.Header('x-api-key'));
  finally
    LApi.Free;
  end;
end;

procedure TCoinOSTests.CallsThroughBaseReference_CarryCoinOSHeaders;
var
  LApi: TAPICoinOS;
  LBase: TIdeaLApi;
begin
  AnswerJson('{}');
  LApi := NewApi;
  try
    LApi.HeaderArray([TAPICoinOS.THeaderPair.Create('x-api-key', 'k2')]);
    LBase := LApi;
    LBase.Get(FServer.Url('/api/me'), [TNameValuePair.Create('X-Extra', 'e')]);
    Assert.AreEqual('Bearer tok', FServer.LastRequest.Header('Authorization'));
    Assert.AreEqual('k2', FServer.LastRequest.Header('x-api-key'));
    Assert.AreEqual('e', FServer.LastRequest.Header('X-Extra'));
    LBase.Post(FServer.Url('/api/x'), '{}', []);
    Assert.AreEqual('Bearer tok', FServer.LastRequest.Header('Authorization'));
  finally
    LApi.Free;
  end;
end;

procedure TCoinOSTests.PostPayment_SendsFeeNotMaxfee_AndOnlyGivenFields;
var
  LApi: TAPICoinOS;
begin
  AnswerJson('{"confirmed":true}');
  LApi := NewApi;
  try
    LApi.PostPayment(CInvoice);
    Assert.AreEqual('/api/payments', FServer.LastRequest.Path);
    Assert.AreEqual('{"payreq":"' + CInvoice + '"}', FServer.LastRequest.Body);
    LApi.PostPayment(CInvoice, 0);
    Assert.AreEqual('{"payreq":"' + CInvoice + '"}', FServer.LastRequest.Body, 'fee 0 is not sent');
    LApi.PostPayment(CInvoice, 12, 'thanks', '1234');
    Assert.AreEqual('{"payreq":"' + CInvoice + '","fee":12,"memo":"thanks","pin":"1234"}', FServer.LastRequest.Body);
    Assert.IsFalse(FServer.LastRequest.Body.Contains('maxfee'));
  finally
    LApi.Free;
  end;
end;

procedure TCoinOSTests.PostPayment_NormalisesInvoice;
var
  LApi: TAPICoinOS;
begin
  AnswerJson('{}');
  LApi := NewApi;
  try
    LApi.PostPayment('  lightning:' + UpperCase(Copy(CInvoice, 1, 30)) + sLineBreak + UpperCase(Copy(CInvoice, 31, MaxInt)));
    Assert.AreEqual('{"payreq":"' + CInvoice + '"}', FServer.LastRequest.Body);
  finally
    LApi.Free;
  end;
end;

procedure TCoinOSTests.PostPayment_UsesPaymentTimeout;
var
  LApi: TSpyCoinOS;
begin
  AnswerJson('{}');
  LApi := TSpyCoinOS.Create;
  try
    LApi.BaseUrl(FServer.Url('/api'));
    LApi.PostPayment(CInvoice);
    Assert.AreEqual(TAPICoinOS.CPaymentConnectTimeout, LApi.LastConnect);
    Assert.AreEqual(90000, LApi.LastResponse);
    LApi.PaymentTimeout(120000).PostPaymentLnAddress('a@b.example', 10);
    Assert.AreEqual(120000, LApi.LastResponse);
    LApi.PostInvoiceLightning(1);
    Assert.AreEqual(TAPICoinOS.CDefaultResponseTimeout, LApi.LastResponse, 'other calls keep the default');
  finally
    LApi.Free;
  end;
end;

procedure TCoinOSTests.PostPayment_ErrorAnswer_IsEIdeaLApiError;
var
  LApi: TAPICoinOS;
  LStatus: Integer;
  LBody: string;
begin
  FServer.Handler :=
    procedure(const ARequest: TTestRequest; AResponse: TTestResponse)
    begin
      AResponse.StatusCode := 500;
      AResponse.ContentType := 'text/plain; charset=utf-8';
      AResponse.Body := 'Invoice has already been paid';
    end;
  LApi := NewApi;
  try
    LStatus := 0;
    try
      LApi.PostPayment(CInvoice);
    except
      on E: EIdeaLApiError do
      begin
        LStatus := E.StatusCode;
        LBody := E.ResponseBody;
      end;
    end;
    Assert.AreEqual(500, LStatus);
    Assert.AreEqual('Invoice has already been paid', LBody);
  finally
    LApi.Free;
  end;
end;

procedure TCoinOSTests.PostPaymentLnAddress_FeeZeroIsOmitted_PinSent;
var
  LApi: TAPICoinOS;
begin
  AnswerJson('{}');
  LApi := NewApi;
  try
    LApi.PostPaymentLnAddress('alice@example.com', 21);
    Assert.AreEqual('/api/send/alice@example.com/21', FServer.LastRequest.Path);
    Assert.AreEqual('{}', FServer.LastRequest.Body, 'fee 0 must not be sent: CoinOS reads it as a cap of 0');
    LApi.PostPaymentLnAddress('alice@example.com', 21, 5, '9999');
    Assert.AreEqual('{"fee":5,"pin":"9999"}', FServer.LastRequest.Body);
  finally
    LApi.Free;
  end;
end;

procedure TCoinOSTests.GetPayment_NullOrEmptyMeansNoRecord;
var
  LApi: TAPICoinOS;
begin
  LApi := NewApi;
  try
    AnswerJson('null');
    Assert.AreEqual('', LApi.GetPayment(CInvoice), 'live API answers 200 "null"');
    AnswerJson('');
    Assert.AreEqual('', LApi.GetPayment(CInvoice), 'empty body');
    AnswerJson(' null' + sLineBreak);
    Assert.AreEqual('', LApi.GetPayment(CInvoice));
  finally
    LApi.Free;
  end;
end;

procedure TCoinOSTests.GetPayment_ReturnsRecord_LowercasePath;
var
  LApi: TAPICoinOS;
begin
  AnswerJson('{"confirmed":true,"hash":"' + CInvoice + '"}');
  LApi := NewApi;
  try
    Assert.AreEqual('{"confirmed":true,"hash":"' + CInvoice + '"}', LApi.GetPayment(UpperCase(CInvoice)));
    Assert.AreEqual('GET', FServer.LastRequest.Method);
    Assert.AreEqual('/api/payments/' + CInvoice, FServer.LastRequest.Path);
  finally
    LApi.Free;
  end;
end;

procedure TCoinOSTests.GetPayment_RefusesNonBech32WithoutRequest;
var
  LApi: TAPICoinOS;
begin
  LApi := NewApi;
  try
    Assert.WillRaise(
      procedure
      begin
        LApi.GetPayment('lnbc1abc/../../me');
      end, EArgumentException);
    Assert.WillRaise(
      procedure
      begin
        LApi.GetPayment('lnbc1abc?x=1');
      end, EArgumentException);
    Assert.WillRaise(
      procedure
      begin
        LApi.GetPayment('   ');
      end, EArgumentException);
    Assert.AreEqual(0, FServer.RequestCount);
  finally
    LApi.Free;
  end;
end;

procedure TCoinOSTests.GetPayment_ServerError_IsEIdeaLApiError;
var
  LApi: TAPICoinOS;
  LMessage: string;
begin
  FServer.Handler :=
    procedure(const ARequest: TTestRequest; AResponse: TTestResponse)
    begin
      AResponse.StatusCode := 500;
      AResponse.Body := 'redis down';
    end;
  LApi := NewApi;
  try
    LMessage := '';
    try
      LApi.GetPayment(CInvoice);
    except
      on E: EIdeaLApiError do
        LMessage := E.Message;
    end;
    Assert.IsTrue(LMessage.StartsWith('500'));
    Assert.IsFalse(LMessage.Contains(CInvoice), 'the invoice must not leak into messages');
  finally
    LApi.Free;
  end;
end;

procedure TCoinOSTests.GetPaymentState_Mapping;
var
  LApi: TAPICoinOS;
  LRecord: string;
begin
  LApi := NewApi;
  try
    AnswerJson('null');
    Assert.AreEqual(Ord(psNone), Ord(LApi.GetPaymentState(CInvoice, LRecord)));
    Assert.AreEqual('', LRecord);

    AnswerJson('{"amount":-250000,"confirmed":false,"type":"lightning","hash":"' + CInvoice + '"}');
    Assert.AreEqual(Ord(psPending), Ord(LApi.GetPaymentState(CInvoice, LRecord)));
    Assert.IsTrue(LRecord.Contains('"confirmed":false'));

    // internal invoice: CoinOS answers with the recipient's record (positive amount)
    AnswerJson('{"amount":250000,"confirmed":true,"type":"internal","hash":"' + CInvoice + '","with":{"username":"bob"}}');
    Assert.AreEqual(Ord(psPaid), Ord(LApi.GetPaymentState(UpperCase(CInvoice), LRecord)));

    AnswerJson('{"confirmed":true}');
    Assert.AreEqual(Ord(psPaid), Ord(LApi.GetPaymentState(CInvoice, LRecord)), 'record without hash');
  finally
    LApi.Free;
  end;
end;

procedure TCoinOSTests.GetPaymentState_RefusesUnexpectedAnswers;
var
  LApi: TAPICoinOS;
  LRecord: string;
begin
  LApi := NewApi;
  try
    AnswerJson('{"confirmed":true,"hash":"lnbc1other"}');
    Assert.WillRaise(procedure begin LApi.GetPaymentState(CInvoice, LRecord); end, Exception, 'other invoice');
    AnswerJson('{"amount":1}');
    Assert.WillRaise(procedure begin LApi.GetPaymentState(CInvoice, LRecord); end, Exception, 'no confirmed');
    AnswerJson('[1,2]');
    Assert.WillRaise(procedure begin LApi.GetPaymentState(CInvoice, LRecord); end, Exception, 'not an object');
    AnswerJson('<html>');
    Assert.WillRaise(procedure begin LApi.GetPaymentState(CInvoice, LRecord); end, Exception, 'not JSON');
  finally
    LApi.Free;
  end;
end;

procedure TCoinOSTests.QuoteAndDecode_Paths;
var
  LApi: TAPICoinOS;
begin
  AnswerJson('{}');
  LApi := NewApi;
  try
    LApi.PostLightningQuote(UpperCase(CInvoice));
    Assert.AreEqual('/api/lightning/quote', FServer.LastRequest.Path);
    Assert.AreEqual('{"payreq":"' + CInvoice + '"}', FServer.LastRequest.Body);
    LApi.PostLightningQuote(CInvoice, 50);
    Assert.AreEqual('{"payreq":"' + CInvoice + '","amount":50}', FServer.LastRequest.Body);
    LApi.GetDecode(CInvoice);
    Assert.AreEqual('/api/decode/' + CInvoice, FServer.LastRequest.Path);
  finally
    LApi.Free;
  end;
end;

procedure TCoinOSTests.NormalizeInvoice_Cases;
begin
  Assert.AreEqual('lnbc1abc', TAPICoinOS.NormalizeInvoice(' LNBC1ABC '));
  Assert.AreEqual('lnbc1abc', TAPICoinOS.NormalizeInvoice('lightning:lnbc1abc'));
  Assert.AreEqual('lnbc1abc', TAPICoinOS.NormalizeInvoice('LIGHTNING:LNBC1' + #13#10#9 + 'ABC'));
  Assert.AreEqual('', TAPICoinOS.NormalizeInvoice(''));
end;

procedure TCoinOSTests.PostLogin_EmptyXApiKey_DoesNotRaise;
var
  LApi: TAPICoinOS;
begin
  // The CoinOS demo always passes the x-api-key edit through HeaderArray; when
  // it is empty, 0.0.6 failed with "Error adding header: (12150)".
  AnswerJson('{"token":"t"}');
  LApi := NewApi;
  try
    Assert.AreEqual('{"token":"t"}',
      LApi.HeaderArray([TAPICoinOS.THeaderPair.Create('x-api-key', '')]).PostLogin('u', 'p'));
    Assert.AreEqual('/api/login', FServer.LastRequest.Path);
    Assert.AreEqual(-1, FServer.LastRequest.Headers.IndexOfName('x-api-key'));
  finally
    LApi.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TCoinOSTests);

end.
