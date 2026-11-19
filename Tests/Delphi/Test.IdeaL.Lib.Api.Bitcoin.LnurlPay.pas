unit Test.IdeaL.Lib.Api.Bitcoin.LnurlPay;

{ TLnurlPay against the in-process server (http on 127.0.0.1, so the HTTP-flow
  tests switch RequireHttps/BlockPrivateHosts off) and the SSRF guard with a
  fake resolver. No network, no DNS. }

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  Test.LocalHttpServer,
  IdeaL.Lib.Api.Bitcoin.LnurlPay;

type
  [TestFixture]
  TLnurlPayTests = class
  private
    FServer: TLocalHttpServer;
    FFakeIps: TLnurlIpList;
    FResolvedHost: string;
    function FakeResolve(const AHost: string): TLnurlIpList;
    procedure SetFakeIps(const AIps: array of string);
    function NewLocalClient: TLnurlPay;
    procedure ServeWellKnown(const AJson: string; const ACallbackJson: string = '');
    function WellKnownJson(const ACallback: string; AMin, AMax: Int64;
      const AMetadata: string; ACommentAllowed: Integer = 0): string;
  public
    [SetupFixture]
    procedure SetupFixture;
    [TearDownFixture]
    procedure TearDownFixture;
    [Setup]
    procedure Setup;

    [Test]
    procedure ParseAddress_Valid;
    [Test]
    procedure ParseAddress_Invalid;
    [Test]
    [TestCase('v4 loopback', '127.0.0.1,False')]
    [TestCase('v4 private 10', '10.1.2.3,False')]
    [TestCase('v4 private 172.16', '172.16.0.1,False')]
    [TestCase('v4 public 172.32', '172.32.0.1,True')]
    [TestCase('v4 private 192.168', '192.168.1.1,False')]
    [TestCase('v4 link-local', '169.254.1.1,False')]
    [TestCase('v4 cgnat', '100.64.0.1,False')]
    [TestCase('v4 unspecified', '0.0.0.0,False')]
    [TestCase('v4 multicast', '224.0.0.1,False')]
    [TestCase('v4 broadcast', '255.255.255.255,False')]
    [TestCase('v4 doc', '203.0.113.5,False')]
    [TestCase('v4 public 8.8.8.8', '8.8.8.8,True')]
    [TestCase('v4 public 1.1.1.1', '1.1.1.1,True')]
    [TestCase('v6 loopback', '::1,False')]
    [TestCase('v6 unspecified', '::,False')]
    [TestCase('v6 bracket loopback', '[::1],False')]
    [TestCase('v6 ula', 'fd00::1,False')]
    [TestCase('v6 link-local', 'fe80::1,False')]
    [TestCase('v6 multicast', 'ff02::1,False')]
    [TestCase('v6 doc', '2001:db8::1,False')]
    [TestCase('v6 mapped loopback', '::ffff:127.0.0.1,False')]
    [TestCase('v6 mapped public', '::ffff:8.8.8.8,True')]
    [TestCase('v6 nat64 private', '64:ff9b::10.0.0.1,False')]
    [TestCase('v6 public', '2606:4700:4700::1111,True')]
    [TestCase('v6 full form public', '2a00:1450:4001:0828:0000:0000:0000:200e,True')]
    procedure IsPublicIp_Table(const AIp: string; AExpected: Boolean);
    [Test]
    procedure TryParseIp_RejectsMalformed;
    [Test]
    procedure CheckUrlIsSafe_Rules;
    [Test]
    procedure CheckUrlIsSafe_UsesResolver;

    [Test]
    procedure Resolve_ParsesPayRequest;
    [Test]
    procedure Resolve_StatusErrorCarriesReason;
    [Test]
    procedure Resolve_StatusErrorWithHttpError;
    [Test]
    procedure Resolve_RefusesInvalidAnswers;
    [Test]
    procedure Resolve_DoesNotFollowRedirects;
    [Test]
    procedure Resolve_PrivateHostIsRefusedBeforeAnyRequest;

    [Test]
    procedure FetchInvoice_BuildsQueryAndReturnsInvoice;
    [Test]
    procedure FetchInvoice_CallbackWithQueryUsesAmpersand;
    [Test]
    procedure FetchInvoice_ChecksBeforeCalling;
    [Test]
    procedure FetchInvoice_StatusErrorAndMissingPr;
    [Test]
    procedure FetchInvoice_RefusesAmountMismatch;
    [Test]
    procedure FetchInvoice_RefusesInvalidInvoice;
    [Test]
    procedure FetchInvoice_DescriptionHashCheckIsOptIn;
    [Test]
    procedure FetchInvoice_PrivateCallbackIsRefused;
    [Test]
    procedure UrlEncode_Utf8;
  end;

implementation

uses
  Bolt11Vectors;

type
  TLocalLnurlPay = class(TLnurlPay)
  public
    BaseUrl: string;
  protected
    function WellKnownUrl(const AUserName, ADomain: string): string; override;
  end;

function TLocalLnurlPay.WellKnownUrl(const AUserName, ADomain: string): string;
begin
  Result := BaseUrl + '/.well-known/lnurlp/' + AUserName;
end;

const
  CMetadata = '[["text/plain","Pay to alice"],["text/identifier","alice@example.com"]]';
  CHashedDescription = 'One piece of chocolate cake, one icecream cone, one pickle, one slice of swiss cheese, ' +
    'one slice of salami, one lollypop, one piece of cherry pie, one sausage, one cupcake, and one slice of watermelon';

function JsonEscape(const AText: string): string;
begin
  Result := StringReplace(AText, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '\"', [rfReplaceAll]);
end;

{ TLnurlPayTests }

procedure TLnurlPayTests.SetupFixture;
begin
  FServer := TLocalHttpServer.Create;
end;

procedure TLnurlPayTests.TearDownFixture;
begin
  FServer.Free;
end;

procedure TLnurlPayTests.Setup;
begin
  FServer.Reset;
  FFakeIps := nil;
  FResolvedHost := '';
end;

function TLnurlPayTests.FakeResolve(const AHost: string): TLnurlIpList;
begin
  FResolvedHost := AHost;
  Result := FFakeIps;
end;

procedure TLnurlPayTests.SetFakeIps(const AIps: array of string);
var
  I: Integer;
  LIp: TBytes;
begin
  SetLength(FFakeIps, Length(AIps));
  for I := 0 to High(AIps) do
  begin
    Assert.IsTrue(TLnurlPay.TryParseIp(AIps[I], LIp), AIps[I]);
    FFakeIps[I] := LIp;
  end;
end;

function TLnurlPayTests.NewLocalClient: TLnurlPay;
var
  LClient: TLocalLnurlPay;
begin
  LClient := TLocalLnurlPay.Create;
  LClient.BaseUrl := FServer.Url('');
  LClient.RequireHttps := False;
  LClient.BlockPrivateHosts := False;
  Result := LClient;
end;

function TLnurlPayTests.WellKnownJson(const ACallback: string; AMin,
  AMax: Int64; const AMetadata: string; ACommentAllowed: Integer): string;
begin
  Result := Format('{"callback":"%s","minSendable":%d,"maxSendable":%d,"metadata":"%s","tag":"payRequest"',
    [ACallback, AMin, AMax, JsonEscape(AMetadata)]);
  if ACommentAllowed > 0 then
    Result := Result + Format(',"commentAllowed":%d', [ACommentAllowed]);
  Result := Result + '}';
end;

procedure TLnurlPayTests.ServeWellKnown(const AJson, ACallbackJson: string);
begin
  FServer.Handler :=
    procedure(const ARequest: TTestRequest; AResponse: TTestResponse)
    begin
      if ARequest.Path.StartsWith('/.well-known/lnurlp/') then
        AResponse.Body := AJson
      else
        AResponse.Body := ACallbackJson;
    end;
end;

procedure TLnurlPayTests.ParseAddress_Valid;
var
  LUser, LDomain: string;
begin
  Assert.IsTrue(TLnurlPay.ParseAddress('alice@example.com', LUser, LDomain));
  Assert.AreEqual('alice', LUser);
  Assert.AreEqual('example.com', LDomain);
  Assert.IsTrue(TLnurlPay.ParseAddress('  Alice@Example.COM ', LUser, LDomain));
  Assert.AreEqual('alice', LUser);
  Assert.AreEqual('example.com', LDomain);
  Assert.IsTrue(TLnurlPay.ParseAddress('bob+tips@pay.example.org', LUser, LDomain));
  Assert.AreEqual('bob+tips', LUser);
  Assert.IsTrue(TLnurlPay.ParseAddress('@example.com', LUser, LDomain));
  Assert.AreEqual('_', LUser, 'LUD-16 default identifier');
  Assert.IsTrue(TLnurlPay.ParseAddress('lightning:carol_1.x-y@example.com', LUser, LDomain));
  Assert.AreEqual('carol_1.x-y', LUser);
end;

procedure TLnurlPayTests.ParseAddress_Invalid;
var
  LUser, LDomain: string;
begin
  Assert.IsFalse(TLnurlPay.ParseAddress('', LUser, LDomain));
  Assert.IsFalse(TLnurlPay.ParseAddress('alice', LUser, LDomain));
  Assert.IsFalse(TLnurlPay.ParseAddress('alice@', LUser, LDomain));
  Assert.IsFalse(TLnurlPay.ParseAddress('alice@localhost', LUser, LDomain), 'no dot');
  Assert.IsFalse(TLnurlPay.ParseAddress('a@b@example.com', LUser, LDomain));
  Assert.IsFalse(TLnurlPay.ParseAddress('al ice@example.com', LUser, LDomain));
  Assert.IsFalse(TLnurlPay.ParseAddress('alice/../x@example.com', LUser, LDomain));
  Assert.IsFalse(TLnurlPay.ParseAddress('alice@example.com/evil', LUser, LDomain));
  Assert.IsFalse(TLnurlPay.ParseAddress('alice@example.com?x', LUser, LDomain));
end;

procedure TLnurlPayTests.IsPublicIp_Table(const AIp: string; AExpected: Boolean);
var
  LIp: TBytes;
begin
  Assert.IsTrue(TLnurlPay.TryParseIp(AIp, LIp), 'parse ' + AIp);
  Assert.AreEqual(AExpected, TLnurlPay.IsPublicIp(LIp), AIp);
end;

procedure TLnurlPayTests.TryParseIp_RejectsMalformed;
var
  LIp: TBytes;
begin
  Assert.IsFalse(TLnurlPay.TryParseIp('1.2.3', LIp));
  Assert.IsFalse(TLnurlPay.TryParseIp('256.1.1.1', LIp));
  Assert.IsFalse(TLnurlPay.TryParseIp('1.2.3.4.5', LIp));
  Assert.IsFalse(TLnurlPay.TryParseIp('1::2::3', LIp));
  Assert.IsFalse(TLnurlPay.TryParseIp('12345::1', LIp));
  Assert.IsFalse(TLnurlPay.TryParseIp('example.com', LIp));
  Assert.IsFalse(TLnurlPay.TryParseIp('', LIp));
  Assert.IsFalse(TLnurlPay.IsPublicIp(nil));
end;

procedure TLnurlPayTests.CheckUrlIsSafe_Rules;
var
  LClient: TLnurlPay;
begin
  LClient := TLnurlPay.Create;
  try
    LClient.OnResolveHost := FakeResolve;
    SetFakeIps(['93.184.216.34']);
    Assert.WillNotRaise(procedure begin LClient.CheckUrlIsSafe('https://example.com/.well-known/lnurlp/a'); end);
    Assert.WillRaise(procedure begin LClient.CheckUrlIsSafe('http://example.com/x'); end, ELnurlPayError, 'http');
    Assert.WillRaise(procedure begin LClient.CheckUrlIsSafe('ftp://example.com/x'); end, ELnurlPayError, 'ftp');
    Assert.WillRaise(procedure begin LClient.CheckUrlIsSafe('https://127.0.0.1/x'); end, ELnurlPayError, 'loopback literal');
    Assert.WillRaise(procedure begin LClient.CheckUrlIsSafe('https://[::1]:8443/x'); end, ELnurlPayError, 'v6 loopback literal');
    Assert.WillRaise(procedure begin LClient.CheckUrlIsSafe('https://10.0.0.5:443/x'); end, ELnurlPayError, 'private literal');
    Assert.WillRaise(procedure begin LClient.CheckUrlIsSafe('https://localhost/x'); end, ELnurlPayError, 'localhost');
    Assert.WillRaise(procedure begin LClient.CheckUrlIsSafe('https://user@example.com/x'); end, ELnurlPayError, 'userinfo');
    Assert.WillRaise(procedure begin LClient.CheckUrlIsSafe('not a url'); end, ELnurlPayError, 'garbage');
    LClient.RequireHttps := False;
    Assert.WillNotRaise(procedure begin LClient.CheckUrlIsSafe('http://example.com/x'); end);
    Assert.WillRaise(procedure begin LClient.CheckUrlIsSafe('http://127.0.0.1/x'); end, ELnurlPayError, 'still blocks private');
    LClient.BlockPrivateHosts := False;
    Assert.WillNotRaise(procedure begin LClient.CheckUrlIsSafe('http://127.0.0.1/x'); end);
  finally
    LClient.Free;
  end;
end;

procedure TLnurlPayTests.CheckUrlIsSafe_UsesResolver;
var
  LClient: TLnurlPay;
begin
  LClient := TLnurlPay.Create;
  try
    LClient.OnResolveHost := FakeResolve;
    SetFakeIps(['10.0.0.7']);
    Assert.WillRaise(procedure begin LClient.CheckUrlIsSafe('https://evil.example/x'); end, ELnurlPayError, 'private');
    Assert.AreEqual('evil.example', FResolvedHost);
    SetFakeIps(['93.184.216.34', '::1']);
    Assert.WillRaise(procedure begin LClient.CheckUrlIsSafe('https://mixed.example/x'); end, ELnurlPayError, 'one private address is enough');
    SetFakeIps([]);
    Assert.WillRaise(procedure begin LClient.CheckUrlIsSafe('https://nowhere.example/x'); end, ELnurlPayError, 'unresolvable');
    SetFakeIps(['2606:4700:4700::1111', '1.1.1.1']);
    Assert.WillNotRaise(procedure begin LClient.CheckUrlIsSafe('https://good.example:8443/x?y=1'); end);
    Assert.AreEqual('good.example', FResolvedHost);
  finally
    LClient.Free;
  end;
end;

procedure TLnurlPayTests.Resolve_ParsesPayRequest;
var
  LClient: TLnurlPay;
  LReq: TLnurlPayRequest;
begin
  ServeWellKnown(WellKnownJson('https://pay.example.com/cb/alice', 1000, 100000000000, CMetadata, 140));
  LClient := NewLocalClient;
  try
    LReq := LClient.Resolve('Alice@Example.com');
    Assert.AreEqual('/.well-known/lnurlp/alice', FServer.LastRequest.Path);
    Assert.AreEqual('alice@example.com', LReq.Address);
    Assert.AreEqual('https://pay.example.com/cb/alice', LReq.Callback);
    Assert.AreEqual(Int64(1000), LReq.MinSendableMsat);
    Assert.AreEqual(Int64(100000000000), LReq.MaxSendableMsat);
    Assert.AreEqual(Int64(1), LReq.MinSendableSat);
    Assert.AreEqual(Int64(100000000), LReq.MaxSendableSat);
    Assert.AreEqual(CMetadata, LReq.Metadata, 'metadata kept exactly as received');
    Assert.AreEqual('Pay to alice', LReq.Description);
    Assert.AreEqual(140, LReq.CommentAllowed);
    Assert.AreEqual('payRequest', LReq.Tag);
  finally
    LClient.Free;
  end;
end;

procedure TLnurlPayTests.Resolve_StatusErrorCarriesReason;
var
  LClient: TLnurlPay;
  LReason: string;
begin
  ServeWellKnown('{"status":"ERROR","reason":"User not found"}');
  LClient := NewLocalClient;
  try
    LReason := '';
    try
      LClient.Resolve('nobody@example.com');
    except
      on E: ELnurlPayError do
        LReason := E.Reason;
    end;
    Assert.AreEqual('User not found', LReason);
  finally
    LClient.Free;
  end;
end;

procedure TLnurlPayTests.Resolve_StatusErrorWithHttpError;
var
  LClient: TLnurlPay;
  LReason: string;
begin
  FServer.Handler :=
    procedure(const ARequest: TTestRequest; AResponse: TTestResponse)
    begin
      AResponse.StatusCode := 404;
      AResponse.Body := '{"status":"ERROR","reason":"Unable to find user"}';
    end;
  LClient := NewLocalClient;
  try
    LReason := '';
    try
      LClient.Resolve('nobody@example.com');
    except
      on E: ELnurlPayError do
        LReason := E.Reason;
    end;
    Assert.AreEqual('Unable to find user', LReason);
  finally
    LClient.Free;
  end;
end;

procedure TLnurlPayTests.Resolve_RefusesInvalidAnswers;
var
  LClient: TLnurlPay;
begin
  LClient := NewLocalClient;
  try
    Assert.WillRaise(procedure begin LClient.Resolve('not-an-address'); end, ELnurlPayError, 'bad address');
    Assert.AreEqual(0, FServer.RequestCount, 'no request for an invalid address');
    ServeWellKnown('{"callback":"https://x.example/cb","minSendable":1000,"maxSendable":2000,"metadata":"[]","tag":"withdrawRequest"}');
    Assert.WillRaise(procedure begin LClient.Resolve('a@example.com'); end, ELnurlPayError, 'wrong tag');
    ServeWellKnown('{"minSendable":1000,"maxSendable":2000,"metadata":"[]","tag":"payRequest"}');
    Assert.WillRaise(procedure begin LClient.Resolve('a@example.com'); end, ELnurlPayError, 'no callback');
    ServeWellKnown(WellKnownJson('https://x.example/cb', 5000, 1000, '[]'));
    Assert.WillRaise(procedure begin LClient.Resolve('a@example.com'); end, ELnurlPayError, 'min > max');
    ServeWellKnown(WellKnownJson('https://x.example/cb', 0, 1000, '[]'));
    Assert.WillRaise(procedure begin LClient.Resolve('a@example.com'); end, ELnurlPayError, 'min < 1');
    ServeWellKnown('<html>not json</html>');
    Assert.WillRaise(procedure begin LClient.Resolve('a@example.com'); end, ELnurlPayError, 'not JSON');
  finally
    LClient.Free;
  end;
end;

procedure TLnurlPayTests.Resolve_DoesNotFollowRedirects;
var
  LClient: TLnurlPay;
begin
  FServer.Handler :=
    procedure(const ARequest: TTestRequest; AResponse: TTestResponse)
    begin
      AResponse.StatusCode := 302;
      AResponse.Location := '/somewhere-else';
    end;
  LClient := NewLocalClient;
  try
    Assert.WillRaise(procedure begin LClient.Resolve('a@example.com'); end, ELnurlPayError);
    Assert.AreEqual(1, FServer.RequestCount);
  finally
    LClient.Free;
  end;
end;

procedure TLnurlPayTests.Resolve_PrivateHostIsRefusedBeforeAnyRequest;
var
  LClient: TLnurlPay;
begin
  ServeWellKnown(WellKnownJson('https://x.example/cb', 1000, 2000, '[]'));
  LClient := NewLocalClient;
  try
    LClient.BlockPrivateHosts := True; // the local server is on 127.0.0.1
    Assert.WillRaise(procedure begin LClient.Resolve('a@example.com'); end, ELnurlPayError);
    Assert.AreEqual(0, FServer.RequestCount);
  finally
    LClient.Free;
  end;
end;

procedure TLnurlPayTests.FetchInvoice_BuildsQueryAndReturnsInvoice;
var
  LClient: TLnurlPay;
  LReq: TLnurlPayRequest;
  LInvoice: string;
begin
  ServeWellKnown(WellKnownJson(FServer.Url('/cb/alice'), 1000, 1000000000, CMetadata, 50),
    '{"pr":"' + UpperCase(CValidCoffee) + '","routes":[]}');
  LClient := NewLocalClient;
  try
    LReq := LClient.Resolve('alice@example.com');
    LInvoice := LClient.FetchInvoice(LReq, 250000000, 'obrigado & ' + #$00E7);
    Assert.AreEqual(CValidCoffee, LInvoice, 'normalised (lower case)');
    Assert.AreEqual('/cb/alice', FServer.LastRequest.Path);
    Assert.AreEqual('amount=250000000&comment=obrigado%20%26%20%C3%A7', FServer.LastRequest.Query);
  finally
    LClient.Free;
  end;
end;

procedure TLnurlPayTests.FetchInvoice_CallbackWithQueryUsesAmpersand;
var
  LClient: TLnurlPay;
  LReq: TLnurlPayRequest;
begin
  ServeWellKnown(WellKnownJson(FServer.Url('/cb?user=alice'), 1000, 1000000000, CMetadata),
    '{"pr":"' + CValidCoffee + '"}');
  LClient := NewLocalClient;
  try
    LReq := LClient.Resolve('alice@example.com');
    LClient.FetchInvoice(LReq, 250000000);
    Assert.AreEqual('/cb', FServer.LastRequest.Path);
    Assert.AreEqual('user=alice&amount=250000000', FServer.LastRequest.Query);
  finally
    LClient.Free;
  end;
end;

procedure TLnurlPayTests.FetchInvoice_ChecksBeforeCalling;
var
  LClient: TLnurlPay;
  LReq: TLnurlPayRequest;
begin
  ServeWellKnown(WellKnownJson(FServer.Url('/cb'), 1000, 2000000, CMetadata, 5), '{"pr":"' + CValidCoffee + '"}');
  LClient := NewLocalClient;
  try
    LReq := LClient.Resolve('alice@example.com');
    FServer.Reset;
    Assert.WillRaise(procedure begin LClient.FetchInvoice(LReq, 999); end, ELnurlPayError, 'below min');
    Assert.WillRaise(procedure begin LClient.FetchInvoice(LReq, 2000001); end, ELnurlPayError, 'above max');
    Assert.WillRaise(procedure begin LClient.FetchInvoice(LReq, 1000, 'too long comment'); end, ELnurlPayError, 'comment');
    LReq.CommentAllowed := 0;
    Assert.WillRaise(procedure begin LClient.FetchInvoice(LReq, 1000, 'x'); end, ELnurlPayError, 'comments not allowed');
    Assert.AreEqual(0, FServer.RequestCount, 'nothing is requested when a check fails');
  finally
    LClient.Free;
  end;
end;

procedure TLnurlPayTests.FetchInvoice_StatusErrorAndMissingPr;
var
  LClient: TLnurlPay;
  LReq: TLnurlPayRequest;
  LReason: string;
begin
  ServeWellKnown(WellKnownJson(FServer.Url('/cb'), 1000, 1000000000, CMetadata),
    '{"status":"ERROR","reason":"Amount too small"}');
  LClient := NewLocalClient;
  try
    LReq := LClient.Resolve('alice@example.com');
    LReason := '';
    try
      LClient.FetchInvoice(LReq, 250000000);
    except
      on E: ELnurlPayError do
        LReason := E.Reason;
    end;
    Assert.AreEqual('Amount too small', LReason);
    ServeWellKnown(WellKnownJson(FServer.Url('/cb'), 1000, 1000000000, CMetadata), '{"routes":[]}');
    Assert.WillRaise(procedure begin LClient.FetchInvoice(LReq, 250000000); end, ELnurlPayError, 'no pr');
  finally
    LClient.Free;
  end;
end;

procedure TLnurlPayTests.FetchInvoice_RefusesAmountMismatch;
var
  LClient: TLnurlPay;
  LReq: TLnurlPayRequest;
  LMessage: string;
begin
  // the service answers with a 250 000 sat invoice whatever we ask
  ServeWellKnown(WellKnownJson(FServer.Url('/cb'), 1000, 1000000000, CMetadata), '{"pr":"' + CValidCoffee + '"}');
  LClient := NewLocalClient;
  try
    LReq := LClient.Resolve('alice@example.com');
    LMessage := '';
    try
      LClient.FetchInvoice(LReq, 21000);
    except
      on E: ELnurlPayError do
        LMessage := E.Message;
    end;
    Assert.IsTrue(LMessage.Contains('differs'), LMessage);
    Assert.IsFalse(LMessage.Contains(Copy(CValidCoffee, 1, 20)), 'never the invoice in the message');
    // amountless invoice is refused too
    ServeWellKnown(WellKnownJson(FServer.Url('/cb'), 1000, 1000000000, CMetadata), '{"pr":"' + CValidDonation + '"}');
    Assert.WillRaise(procedure begin LClient.FetchInvoice(LReq, 21000); end, ELnurlPayError, 'amountless');
  finally
    LClient.Free;
  end;
end;

procedure TLnurlPayTests.FetchInvoice_RefusesInvalidInvoice;
var
  LClient: TLnurlPay;
  LReq: TLnurlPayRequest;
begin
  ServeWellKnown(WellKnownJson(FServer.Url('/cb'), 1000, 1000000000, CMetadata), '{"pr":"' + CInvalidBadChecksum + '"}');
  LClient := NewLocalClient;
  try
    LReq := LClient.Resolve('alice@example.com');
    Assert.WillRaise(procedure begin LClient.FetchInvoice(LReq, 250000000); end, ELnurlPayError);
  finally
    LClient.Free;
  end;
end;

procedure TLnurlPayTests.FetchInvoice_DescriptionHashCheckIsOptIn;
var
  LClient: TLnurlPay;
  LReq: TLnurlPayRequest;
begin
  // CValidHashed: 20m (2 000 000 000 msat), h = sha256(CHashedDescription)
  ServeWellKnown(WellKnownJson(FServer.Url('/cb'), 1000, 3000000000, CHashedDescription), '{"pr":"' + CValidHashed + '"}');
  LClient := NewLocalClient;
  try
    LReq := LClient.Resolve('alice@example.com');
    LClient.CheckDescriptionHash := True;
    Assert.AreEqual(CValidHashed, LClient.FetchInvoice(LReq, 2000000000));
    LReq.Metadata := CMetadata;
    Assert.WillRaise(procedure begin LClient.FetchInvoice(LReq, 2000000000); end, ELnurlPayError, 'hash mismatch');
    LClient.CheckDescriptionHash := False;
    Assert.AreEqual(CValidHashed, LClient.FetchInvoice(LReq, 2000000000), 'off by default');
  finally
    LClient.Free;
  end;
end;

procedure TLnurlPayTests.FetchInvoice_PrivateCallbackIsRefused;
var
  LClient: TLnurlPay;
  LReq: TLnurlPayRequest;
begin
  ServeWellKnown(WellKnownJson(FServer.Url('/cb'), 1000, 1000000000, CMetadata), '{"pr":"' + CValidCoffee + '"}');
  LClient := NewLocalClient;
  try
    LReq := LClient.Resolve('alice@example.com');
    FServer.Reset;
    LClient.BlockPrivateHosts := True;
    Assert.WillRaise(procedure begin LClient.FetchInvoice(LReq, 250000000); end, ELnurlPayError);
    Assert.AreEqual(0, FServer.RequestCount);
    LReq.Callback := 'http://pay.example.com/cb';
    LClient.RequireHttps := True;
    LClient.BlockPrivateHosts := False;
    Assert.WillRaise(procedure begin LClient.FetchInvoice(LReq, 250000000); end, ELnurlPayError, 'http callback');
  finally
    LClient.Free;
  end;
end;

procedure TLnurlPayTests.UrlEncode_Utf8;
begin
  Assert.AreEqual('abc-._~XYZ09', LnurlUrlEncode('abc-._~XYZ09'));
  Assert.AreEqual('a%20b%2Fc%3F%26%3D', LnurlUrlEncode('a b/c?&='));
  Assert.AreEqual('%C3%A7%E2%9C%93', LnurlUrlEncode(#$00E7#$2713));
end;

initialization
  TDUnitX.RegisterTestFixture(TLnurlPayTests);

end.
