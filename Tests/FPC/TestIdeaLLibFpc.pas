unit TestIdeaLLibFpc;

{ fpcunit tests: the FPC branches of TIdeaLApi, TAPICoinOS, TBolt11Decoder and
  TLnurlPay must behave like the Delphi ones (see Tests/Delphi). No network. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry;

type
  TApiFpcTests = class(TTestCase)
  protected
    procedure SetUp; override;
  published
    procedure Get_200_ReturnsBody;
    procedure Get_204_ReturnsEmpty;
    procedure Get_SendsHeaders;
    procedure Get_404_EIdeaLApiError_MessageWithoutBody;
    procedure Post_201_Accepted_BodySent;
    procedure Post_500_MessageWithBody;
    procedure Error_MessageNeverContainsUrl;
    procedure Timeout_IsTransportError;
    procedure FollowRedirectsFalse_3xxRaises;
  end;

  TBolt11FpcTests = class(TTestCase)
  published
    procedure Sha256_Nist;
    procedure Valid_Vectors;
    procedure Invalid_Vectors;
    procedure Utf8_Description;
  end;

  TCoinOSFpcTests = class(TTestCase)
  protected
    procedure SetUp; override;
  published
    procedure PostPayment_Body;
    procedure PostPaymentLnAddress_Body;
    procedure GetPayment_NullMeansNoRecord;
    procedure GetPaymentState_Mapping;
    procedure Compat_Bodies;
    procedure HeaderArray_OnGet;
  end;

  TLnurlFpcTests = class(TTestCase)
  protected
    procedure SetUp; override;
  published
    procedure IpTable;
    procedure ParseAddress;
    procedure CheckUrlIsSafe;
    procedure ResolveAndFetch;
    procedure AmountMismatch;
  end;

implementation

uses
  TestServerFpc,
  Bolt11Vectors,
  IdeaL.Lib.Api,
  IdeaL.Lib.Bitcoin.Bolt11,
  IdeaL.Lib.Api.Bitcoin.CoinOS,
  IdeaL.Lib.Api.Bitcoin.LnurlPay;

{ TApiFpcTests }

procedure TApiFpcTests.SetUp;
begin
  StartTestServer;
  ResetScript;
end;

procedure TApiFpcTests.Get_200_ReturnsBody;
var
  LApi: TIdeaLApi;
begin
  SetScript(200, '{"a":1}');
  LApi := TIdeaLApi.Create;
  try
    AssertEquals('{"a":1}', LApi.Get(TestUrl('/x'), nil));
    AssertEquals('GET', Seen.Method);
    AssertEquals('/x', Seen.Path);
  finally
    LApi.Free;
  end;
end;

procedure TApiFpcTests.Get_204_ReturnsEmpty;
var
  LApi: TIdeaLApi;
begin
  SetScript(204, '');
  LApi := TIdeaLApi.Create;
  try
    AssertEquals('', LApi.Get(TestUrl('/x'), nil));
  finally
    LApi.Free;
  end;
end;

procedure TApiFpcTests.Get_SendsHeaders;
var
  LApi: TIdeaLApi;
  LHeaders: TNetHeaders;
begin
  SetScript(200, 'ok');
  LApi := TIdeaLApi.Create;
  try
    SetLength(LHeaders, 2);
    LHeaders[0] := TNameValuePair.Create('X-Test', 'abc');
    LHeaders[1] := TNameValuePair.Create('Authorization', 'Bearer t0k3n');
    LApi.Get(TestUrl('/h'), LHeaders);
    AssertEquals('abc', Seen.XTest);
    AssertEquals('Bearer t0k3n', Seen.Authorization);
  finally
    LApi.Free;
  end;
end;

procedure TApiFpcTests.Get_404_EIdeaLApiError_MessageWithoutBody;
var
  LApi: TIdeaLApi;
  LOk: Boolean;
begin
  SetScript(404, 'nothing here');
  LApi := TIdeaLApi.Create;
  try
    LOk := False;
    try
      LApi.Get(TestUrl('/missing'), nil);
    except
      on E: EIdeaLApiError do
      begin
        LOk := True;
        AssertEquals(404, E.StatusCode);
        AssertEquals('nothing here', E.ResponseBody);
        AssertEquals('404 ' + E.StatusText, E.Message);
      end;
    end;
    AssertTrue('EIdeaLApiError expected', LOk);
  finally
    LApi.Free;
  end;
end;

procedure TApiFpcTests.Post_201_Accepted_BodySent;
var
  LApi: TIdeaLApi;
begin
  SetScript(201, '{"id":1}');
  LApi := TIdeaLApi.Create;
  try
    AssertEquals('{"id":1}', LApi.Post(TestUrl('/p'), '{"memo":"x"}', nil));
    AssertEquals('POST', Seen.Method);
    AssertEquals('{"memo":"x"}', Seen.Body);
  finally
    LApi.Free;
  end;
end;

procedure TApiFpcTests.Post_500_MessageWithBody;
var
  LApi: TIdeaLApi;
  LMessage: string;
begin
  SetScript(500, 'Invalid pin');
  LApi := TIdeaLApi.Create;
  try
    LMessage := '';
    try
      LApi.Post(TestUrl('/pay'), '{}', nil);
    except
      on E: EIdeaLApiError do
        LMessage := E.Message;
    end;
    AssertTrue(LMessage, Pos('500 ', LMessage) = 1);
    AssertTrue(LMessage, Pos(' - Invalid pin', LMessage) > 0);
  finally
    LApi.Free;
  end;
end;

procedure TApiFpcTests.Error_MessageNeverContainsUrl;
var
  LApi: TIdeaLApi;
  LMessage: string;
begin
  SetScript(500, 'boom');
  LApi := TIdeaLApi.Create;
  try
    LMessage := '';
    try
      LApi.Get(TestUrl('/payments/lnbc1secretinvoice'), nil);
    except
      on E: Exception do
        LMessage := E.Message;
    end;
    AssertTrue(Pos('lnbc1secretinvoice', LMessage) = 0);
  finally
    LApi.Free;
  end;
end;

procedure TApiFpcTests.Timeout_IsTransportError;
var
  LApi: TIdeaLApi;
  LTransport: Boolean;
begin
  SetScript(200, 'late');
  SetDelay(3000);
  LApi := TIdeaLApi.Create;
  try
    LTransport := False;
    try
      LApi.Get(TestUrl('/slow'), nil, 2000, 500);
    except
      on E: Exception do
        LTransport := TIdeaLApi.IsTransportError(E);
    end;
    AssertTrue('timeout must be a transport error', LTransport);
  finally
    LApi.Free;
  end;
  Sleep(2700);
end;

procedure TApiFpcTests.FollowRedirectsFalse_3xxRaises;
var
  LApi: TIdeaLApi;
  LStatus: Integer;
begin
  SetScript(302, '');
  SetLocation('/to');
  LApi := TIdeaLApi.Create;
  try
    LApi.FollowRedirects := False;
    LStatus := 0;
    try
      LApi.Get(TestUrl('/from'), nil);
    except
      on E: EIdeaLApiError do
        LStatus := E.StatusCode;
    end;
    AssertEquals(302, LStatus);
    AssertEquals(1, Seen.Count);
  finally
    LApi.Free;
  end;
end;

{ TBolt11FpcTests }

procedure TBolt11FpcTests.Sha256_Nist;
begin
  AssertEquals('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    Bolt11BytesToHex(Bolt11Sha256(Bolt11Utf8Bytes(''))));
  AssertEquals('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    Bolt11BytesToHex(Bolt11Sha256(Bolt11Utf8Bytes('abc'))));
  AssertEquals('248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
    Bolt11BytesToHex(Bolt11Sha256(Bolt11Utf8Bytes('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'))));
end;

procedure TBolt11FpcTests.Valid_Vectors;
var
  B: TBolt11;
begin
  B := TBolt11Decoder.Decode(CValidDonation);
  AssertEquals(-1, B.AmountMsat);
  AssertEquals(1496314658, B.Timestamp);
  AssertEquals('0001020304050607080900010203040506070809000102030405060708090102', B.PaymentHash);
  AssertEquals('Please consider supporting this project', B.Description);
  AssertEquals('8,14', B.FeatureBits);
  B := TBolt11Decoder.Decode(CValidCoffee);
  AssertEquals(250000000, B.AmountMsat);
  AssertEquals(60, B.Expiry);
  B := TBolt11Decoder.Decode(CValidHashed);
  AssertEquals('3925b6f67e2c340036ed12093dd44e0368df1b6ea26c53dbe4811f58fd5db8c1', B.DescriptionHash);
  B := TBolt11Decoder.Decode(CValidPico);
  AssertEquals(967878534, B.AmountMsat);
  AssertEquals(10, B.MinFinalCltvExpiry);
  B := TBolt11Decoder.Decode(CValidUpperCase);
  AssertEquals(LowerCase(CValidUpperCase), B.Invoice);
  AssertEquals('8,14,99', B.FeatureBits);
  AssertTrue(TBolt11Decoder.Decode(CValidTestnetFallback).Network = bnTestnet);
  TBolt11Decoder.Decode(CValidRoutingInfo);
  TBolt11Decoder.Decode(CValidIgnoredFields);
  TBolt11Decoder.Decode(CValidMetadata);
  AssertTrue(TBolt11Decoder.Decode(CInvalidUnknownFeature100).HasUnknownRequiredFeatures);
end;

procedure TBolt11FpcTests.Invalid_Vectors;
const
  CList: array[0..12] of string = (
    CInvalidNWrongLength, CInvalidMissingP, CInvalidTwoDistinctP, CInvalidSamePTwice,
    CInvalidTwoDistinctS, CInvalidBadChecksum, CInvalidNoSeparator, CInvalidMixedCase,
    CInvalidTooShort, CInvalidInvalidMultiplier, CInvalidSubMsat, CInvalidMissingS,
    CInvalidHighSWithN);
var
  I: Integer;
  LResult: TBolt11;
  LError: string;
begin
  for I := Low(CList) to High(CList) do
    AssertFalse('vector ' + IntToStr(I), TBolt11Decoder.TryDecode(CList[I], LResult, LError));
  AssertFalse(TBolt11Decoder.TryDecode('', LResult, LError));
  AssertFalse(TBolt11Decoder.TryDecode('lnbc1', LResult, LError));
end;

procedure TBolt11FpcTests.Utf8_Description;
var
  B: TBolt11;
begin
  // FPC strings carry the UTF-8 bytes as they are
  B := TBolt11Decoder.Decode(CValidNonsense);
  AssertEquals(#$E3#$83#$8A#$E3#$83#$B3#$E3#$82#$BB#$E3#$83#$B3#$E3#$82#$B9' 1'#$E6#$9D#$AF,
    B.Description);
end;

{ TCoinOSFpcTests }

procedure TCoinOSFpcTests.SetUp;
begin
  StartTestServer;
  ResetScript;
end;

function NewCoinOS: TAPICoinOS;
begin
  Result := TAPICoinOS.Create;
  Result.BaseUrl(TestUrl('/api')).AuthToken('tok');
end;

procedure TCoinOSFpcTests.PostPayment_Body;
var
  LApi: TAPICoinOS;
begin
  SetScript(200, '{}');
  LApi := NewCoinOS;
  try
    LApi.PostPayment(' LIGHTNING:' + UpperCase(CValidCoffee));
    AssertEquals('/api/payments', Seen.Path);
    AssertEquals('Bearer tok', Seen.Authorization);
    AssertEquals('{ "payreq" : "' + CValidCoffee + '" }', Seen.Body);
    LApi.PostPayment(CValidCoffee, 12, 'thanks', '1234');
    AssertEquals('{ "payreq" : "' + CValidCoffee + '", "fee" : 12, "memo" : "thanks", "pin" : "1234" }', Seen.Body);
  finally
    LApi.Free;
  end;
end;

procedure TCoinOSFpcTests.PostPaymentLnAddress_Body;
var
  LApi: TAPICoinOS;
begin
  SetScript(200, '{}');
  LApi := NewCoinOS;
  try
    LApi.PostPaymentLnAddress('alice@example.com', 21);
    AssertEquals('/api/send/alice@example.com/21', Seen.Path);
    AssertEquals('{}', Seen.Body);
    LApi.PostPaymentLnAddress('alice@example.com', 21, 5, '9999');
    AssertEquals('{ "fee" : 5, "pin" : "9999" }', Seen.Body);
  finally
    LApi.Free;
  end;
end;

procedure TCoinOSFpcTests.GetPayment_NullMeansNoRecord;
var
  LApi: TAPICoinOS;
begin
  SetScript(200, 'null');
  LApi := NewCoinOS;
  try
    AssertEquals('', LApi.GetPayment(UpperCase(CValidCoffee)));
    AssertEquals('/api/payments/' + CValidCoffee, Seen.Path);
    SetScript(200, '');
    AssertEquals('', LApi.GetPayment(CValidCoffee));
  finally
    LApi.Free;
  end;
end;

procedure TCoinOSFpcTests.GetPaymentState_Mapping;
var
  LApi: TAPICoinOS;
  LRecord: string;
begin
  LApi := NewCoinOS;
  try
    SetScript(200, 'null');
    AssertTrue(LApi.GetPaymentState(CValidCoffee, LRecord) = psNone);
    SetScript(200, '{"confirmed":false,"hash":"' + CValidCoffee + '"}');
    AssertTrue(LApi.GetPaymentState(CValidCoffee, LRecord) = psPending);
    SetScript(200, '{"confirmed":true,"type":"internal","amount":250000}');
    AssertTrue(LApi.GetPaymentState(CValidCoffee, LRecord) = psPaid);
    SetScript(200, '{"confirmed":true,"hash":"lnbc1other"}');
    try
      LApi.GetPaymentState(CValidCoffee, LRecord);
      Fail('record of another invoice must be refused');
    except
      on E: EAssertionFailedError do raise;
      on E: Exception do ;
    end;
  finally
    LApi.Free;
  end;
end;

procedure TCoinOSFpcTests.Compat_Bodies;
var
  LApi: TAPICoinOS;
begin
  SetScript(200, '{}');
  LApi := NewCoinOS;
  try
    LApi.PostRegister('u', 'p');
    AssertEquals('/api/register', Seen.Path);
    AssertEquals('{ "user" : { "username" : "u", "password" : "p" } }', Seen.Body);
    LApi.PostInvoiceLightning(100);
    AssertEquals('{ "invoice" : { "amount" : 100, "type" : "lightning" } }', Seen.Body);
    LApi.PostLogin('u', 'p');
    AssertEquals('{ "username" : "u", "password" : "p" }', Seen.Body);
    LApi.GetPayments(0, 0, 3);
    AssertEquals('/api/payments', Seen.Path);
    AssertEquals('limit=3', Seen.Query);
  finally
    LApi.Free;
  end;
end;

procedure TCoinOSFpcTests.HeaderArray_OnGet;
var
  LApi: TAPICoinOS;
  LPairs: TAPICoinOS.THeaderArray;
begin
  SetScript(200, '{}');
  LApi := NewCoinOS;
  try
    SetLength(LPairs, 1);
    LPairs[0] := TAPICoinOS.THeaderPair.Create('x-api-key', 'k1');
    LApi.HeaderArray(LPairs).GetMe;
    AssertEquals('k1', Seen.XApiKey);
    AssertEquals('/api/me', Seen.Path);
  finally
    LApi.Free;
  end;
end;

{ TLnurlFpcTests }

type
  TLocalLnurl = class(TLnurlPay)
  protected
    function WellKnownUrl(const AUserName, ADomain: string): string; override;
  end;

function TLocalLnurl.WellKnownUrl(const AUserName, ADomain: string): string;
begin
  Result := TestUrl('/.well-known/lnurlp/' + AUserName);
end;

procedure TLnurlFpcTests.SetUp;
begin
  StartTestServer;
  ResetScript;
end;

procedure TLnurlFpcTests.IpTable;
const
  CPublic: array[0..3] of string = ('8.8.8.8', '172.32.0.1', '::ffff:8.8.8.8', '2606:4700:4700::1111');
  CPrivate: array[0..11] of string = ('127.0.0.1', '10.1.2.3', '172.16.0.1', '192.168.1.1', '169.254.1.1',
    '100.64.0.1', '0.0.0.0', '::1', 'fd00::1', 'fe80::1', '::ffff:127.0.0.1', '64:ff9b::10.0.0.1');
var
  I: Integer;
  LIp: TBytes;
begin
  for I := Low(CPublic) to High(CPublic) do
  begin
    AssertTrue(CPublic[I], TLnurlPay.TryParseIp(CPublic[I], LIp));
    AssertTrue(CPublic[I], TLnurlPay.IsPublicIp(LIp));
  end;
  for I := Low(CPrivate) to High(CPrivate) do
  begin
    AssertTrue(CPrivate[I], TLnurlPay.TryParseIp(CPrivate[I], LIp));
    AssertFalse(CPrivate[I], TLnurlPay.IsPublicIp(LIp));
  end;
  AssertFalse(TLnurlPay.TryParseIp('256.1.1.1', LIp));
  AssertFalse(TLnurlPay.TryParseIp('1::2::3', LIp));
end;

procedure TLnurlFpcTests.ParseAddress;
var
  LUser, LDomain: string;
begin
  AssertTrue(TLnurlPay.ParseAddress(' Alice@Example.COM ', LUser, LDomain));
  AssertEquals('alice', LUser);
  AssertEquals('example.com', LDomain);
  AssertTrue(TLnurlPay.ParseAddress('@example.com', LUser, LDomain));
  AssertEquals('_', LUser);
  AssertFalse(TLnurlPay.ParseAddress('a/b@example.com', LUser, LDomain));
  AssertFalse(TLnurlPay.ParseAddress('alice@example.com/x', LUser, LDomain));
end;

procedure TLnurlFpcTests.CheckUrlIsSafe;
var
  LClient: TLnurlPay;
  LRaised: Boolean;
begin
  LClient := TLnurlPay.Create;
  try
    LRaised := False;
    try
      LClient.CheckUrlIsSafe('http://example.com/x');
    except
      on E: ELnurlPayError do LRaised := True;
    end;
    AssertTrue('http refused', LRaised);
    LRaised := False;
    try
      LClient.CheckUrlIsSafe('https://127.0.0.1/x');
    except
      on E: ELnurlPayError do LRaised := True;
    end;
    AssertTrue('loopback refused', LRaised);
    LRaised := False;
    try
      LClient.CheckUrlIsSafe('https://[::1]/x');
    except
      on E: ELnurlPayError do LRaised := True;
    end;
    AssertTrue('v6 loopback refused', LRaised);
  finally
    LClient.Free;
  end;
end;

procedure TLnurlFpcTests.ResolveAndFetch;
var
  LClient: TLnurlPay;
  LReq: TLnurlPayRequest;
begin
  SetScript(200, '{"callback":"' + TestUrl('/cb?u=alice') + '","minSendable":1000,"maxSendable":1000000000,' +
    '"metadata":"[[\"text/plain\",\"Pay to alice\"]]","commentAllowed":20,"tag":"payRequest"}');
  SetCallback('/.well-known/', '{"pr":"' + CValidCoffee + '","routes":[]}');
  LClient := TLocalLnurl.Create;
  try
    LClient.RequireHttps := False;
    LClient.BlockPrivateHosts := False;
    LReq := LClient.Resolve('alice@example.com');
    AssertEquals('/.well-known/lnurlp/alice', Seen.Path);
    AssertEquals('Pay to alice', LReq.Description);
    AssertEquals(20, LReq.CommentAllowed);
    AssertEquals(CValidCoffee, LClient.FetchInvoice(LReq, 250000000, 'a b'));
    AssertEquals('/cb', Seen.Path);
    AssertEquals('u=alice&amount=250000000&comment=a%20b', Seen.Query);
  finally
    LClient.Free;
  end;
end;

procedure TLnurlFpcTests.AmountMismatch;
var
  LClient: TLnurlPay;
  LReq: TLnurlPayRequest;
  LRaised: Boolean;
begin
  SetScript(200, '{"callback":"' + TestUrl('/cb') + '","minSendable":1000,"maxSendable":1000000000,' +
    '"metadata":"[]","tag":"payRequest"}');
  SetCallback('/.well-known/', '{"pr":"' + CValidCoffee + '"}');
  LClient := TLocalLnurl.Create;
  try
    LClient.RequireHttps := False;
    LClient.BlockPrivateHosts := False;
    LReq := LClient.Resolve('alice@example.com');
    LRaised := False;
    try
      LClient.FetchInvoice(LReq, 21000);
    except
      on E: ELnurlPayError do LRaised := True;
    end;
    AssertTrue(LRaised);
  finally
    LClient.Free;
  end;
end;

initialization
  RegisterTest(TApiFpcTests);
  RegisterTest(TBolt11FpcTests);
  RegisterTest(TCoinOSFpcTests);
  RegisterTest(TLnurlFpcTests);

end.
