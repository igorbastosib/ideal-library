unit Test.IdeaL.Lib.Bitcoin.Bolt11;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TBolt11Tests = class
  private
    procedure AssertInvalid(const AInvoice, AWhy: string);
  public
    // SHA-256
    [Test]
    procedure Sha256_NistVectors;
    [Test]
    procedure Sha256_MatchesRtlForManyLengths;

    // valid spec vectors
    [Test]
    procedure Donation_AmountlessWithAllFields;
    [Test]
    procedure Coffee_AmountExpiryAndExpiresAt;
    [Test]
    procedure Nonsense_Utf8Description;
    [Test]
    procedure Hashed_DescriptionHashAndMetadataMatch;
    [Test]
    procedure Testnet_PrefixAndNetwork;
    [Test]
    procedure Pico_AmountAndCltv;
    [Test]
    procedure Features_OddUnknownBitIsAccepted;
    [Test]
    procedure UpperCase_DecodesToSameAsLowerCase;
    [Test]
    procedure IgnoredFields_AreSkipped;
    [Test]
    [TestCase('RoutingInfo', 'RoutingInfo')]
    [TestCase('FallbackP2SH', 'FallbackP2SH')]
    [TestCase('FallbackP2WPKH', 'FallbackP2WPKH')]
    [TestCase('FallbackP2WSH', 'FallbackP2WSH')]
    [TestCase('FallbackP2TR', 'FallbackP2TR')]
    [TestCase('Metadata', 'Metadata')]
    [TestCase('HighS', 'HighS')]
    procedure OtherValidVectors_Decode(const AName: string);
    [Test]
    procedure Normalize_StripsPrefixWhitespaceAndCase;

    // invalid spec vectors
    [Test]
    procedure Invalid_SpecVectorsAreRefused;
    [Test]
    procedure Invalid_ExtraMalformedStrings;
    // documented limitations
    [Test]
    procedure Limitation_UnknownRequiredFeatureIsReportedNotRefused;
    [Test]
    procedure Limitation_SignatureIsNotVerified;
    [Test]
    procedure ErrorMessage_NeverContainsTheInvoice;
  end;

implementation

uses
  System.SysUtils,
  System.DateUtils,
  System.Hash,
  IdeaL.Lib.Bitcoin.Bolt11,
  Bolt11Vectors;

function HexOf(const AText: string): string;
begin
  Result := Bolt11BytesToHex(Bolt11Sha256(TEncoding.UTF8.GetBytes(AText)));
end;

function VectorByName(const AName: string): string;
begin
  if AName = 'RoutingInfo' then Exit(CValidRoutingInfo);
  if AName = 'FallbackP2SH' then Exit(CValidFallbackP2SH);
  if AName = 'FallbackP2WPKH' then Exit(CValidFallbackP2WPKH);
  if AName = 'FallbackP2WSH' then Exit(CValidFallbackP2WSH);
  if AName = 'FallbackP2TR' then Exit(CValidFallbackP2TR);
  if AName = 'Metadata' then Exit(CValidMetadata);
  if AName = 'HighS' then Exit(CValidHighS);
  raise Exception.Create('unknown vector ' + AName);
end;

{ TBolt11Tests }

procedure TBolt11Tests.AssertInvalid(const AInvoice, AWhy: string);
begin
  Assert.WillRaise(
    procedure
    begin
      TBolt11Decoder.Decode(AInvoice);
    end, EBolt11Error, AWhy);
end;

procedure TBolt11Tests.Sha256_NistVectors;
begin
  Assert.AreEqual('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', HexOf(''));
  Assert.AreEqual('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad', HexOf('abc'));
  Assert.AreEqual('248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
    HexOf('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'));
end;

procedure TBolt11Tests.Sha256_MatchesRtlForManyLengths;
var
  LData: TBytes;
  LRtl: THashSHA2;
  I, J: Integer;
begin
  // lengths 0..300 cross every padding boundary (55/56/64 bytes)
  for I := 0 to 300 do
  begin
    SetLength(LData, I);
    for J := 0 to I - 1 do
      LData[J] := Byte((J * 31 + I * 7) and $FF);
    LRtl := THashSHA2.Create(THashSHA2.TSHA2Version.SHA256);
    LRtl.Update(LData);
    Assert.AreEqual(Bolt11BytesToHex(LRtl.HashAsBytes), Bolt11BytesToHex(Bolt11Sha256(LData)),
      'length ' + I.ToString);
  end;
end;

procedure TBolt11Tests.Donation_AmountlessWithAllFields;
var
  B: TBolt11;
begin
  B := TBolt11Decoder.Decode(CValidDonation);
  Assert.AreEqual(Ord(bnMainnet), Ord(B.Network));
  Assert.AreEqual('bc', B.CurrencyPrefix);
  Assert.IsFalse(B.HasAmount);
  Assert.AreEqual(Int64(-1), B.AmountMsat);
  Assert.AreEqual(Int64(-1), B.AmountSat);
  Assert.AreEqual(Int64(1496314658), B.Timestamp);
  Assert.AreEqual('0001020304050607080900010203040506070809000102030405060708090102', B.PaymentHash);
  Assert.AreEqual('1111111111111111111111111111111111111111111111111111111111111111', B.PaymentSecret);
  Assert.IsTrue(B.HasDescription);
  Assert.AreEqual('Please consider supporting this project', B.Description);
  Assert.AreEqual('', B.DescriptionHash);
  Assert.AreEqual(Int64(3600), B.Expiry, 'default expiry');
  Assert.AreEqual(Int64(18), B.MinFinalCltvExpiry, 'default cltv');
  Assert.AreEqual('', B.PayeePubKey);
  Assert.AreEqual('8,14', B.FeatureBits);
  Assert.IsFalse(B.HasUnknownRequiredFeatures);
  Assert.AreEqual('8d3ce9e28357337f62da0162d9454df827f83cfe499aeb1c1db349d4d81127425e434ca29929406c23bba1ae8ac6ca32880b38d4bf6ff874024cac34ba9625f1' + '01',
    B.Signature);
  Assert.AreEqual(CValidDonation, B.Invoice);
end;

procedure TBolt11Tests.Coffee_AmountExpiryAndExpiresAt;
var
  B: TBolt11;
begin
  B := TBolt11Decoder.Decode(CValidCoffee);
  Assert.AreEqual(Int64(250000000), B.AmountMsat, '2500u = 250 000 sat');
  Assert.AreEqual(Int64(250000), B.AmountSat);
  Assert.AreEqual('1 cup coffee', B.Description);
  Assert.AreEqual(Int64(60), B.Expiry);
  Assert.AreEqual(Int64(1496314658 + 60), B.ExpiresAtUnix);
  Assert.AreEqual(UnixToDateTime(1496314658 + 60, True), B.ExpiresAtUtc);
  Assert.IsFalse(B.IsExpired(UnixToDateTime(1496314658, True)));
  Assert.IsTrue(B.IsExpired(UnixToDateTime(1496314658, True), 60), 'margin reaches expiry');
  Assert.IsTrue(B.IsExpired(TTimeZone.Local.ToUniversalTime(Now)));
end;

procedure TBolt11Tests.Nonsense_Utf8Description;
var
  B: TBolt11;
begin
  B := TBolt11Decoder.Decode(CValidNonsense);
  Assert.AreEqual(#$30CA#$30F3#$30BB#$30F3#$30B9' 1'#$676F, B.Description);
end;

procedure TBolt11Tests.Hashed_DescriptionHashAndMetadataMatch;
const
  CLongDescription = 'One piece of chocolate cake, one icecream cone, one pickle, one slice of swiss cheese, ' +
    'one slice of salami, one lollypop, one piece of cherry pie, one sausage, one cupcake, and one slice of watermelon';
var
  B: TBolt11;
begin
  B := TBolt11Decoder.Decode(CValidHashed);
  Assert.AreEqual(Int64(2000000000), B.AmountMsat, '20m');
  Assert.IsFalse(B.HasDescription);
  Assert.AreEqual('3925b6f67e2c340036ed12093dd44e0368df1b6ea26c53dbe4811f58fd5db8c1', B.DescriptionHash);
  Assert.IsTrue(B.MatchesMetadata(CLongDescription));
  Assert.IsFalse(B.MatchesMetadata(CLongDescription + ' '));
  Assert.IsFalse(TBolt11Decoder.Decode(CValidCoffee).MatchesMetadata('1 cup coffee'), 'no h field');
end;

procedure TBolt11Tests.Testnet_PrefixAndNetwork;
var
  B: TBolt11;
begin
  B := TBolt11Decoder.Decode(CValidTestnetFallback);
  Assert.AreEqual(Ord(bnTestnet), Ord(B.Network));
  Assert.AreEqual('tb', B.CurrencyPrefix);
  Assert.AreEqual(Int64(2000000000), B.AmountMsat);
end;

procedure TBolt11Tests.Pico_AmountAndCltv;
var
  B: TBolt11;
begin
  B := TBolt11Decoder.Decode(CValidPico);
  Assert.AreEqual(Int64(967878534), B.AmountMsat);
  Assert.AreEqual(Int64(1572468703), B.Timestamp);
  Assert.AreEqual(Int64(10), B.MinFinalCltvExpiry);
  Assert.AreEqual(Int64(604800), B.Expiry, 'one week');
end;

procedure TBolt11Tests.Features_OddUnknownBitIsAccepted;
var
  B: TBolt11;
begin
  B := TBolt11Decoder.Decode(CValidFeatures);
  Assert.AreEqual(Int64(2500000000), B.AmountMsat, '25m');
  Assert.AreEqual('coffee beans', B.Description);
  Assert.AreEqual('8,14,99', B.FeatureBits);
  Assert.IsFalse(B.HasUnknownRequiredFeatures);
end;

procedure TBolt11Tests.UpperCase_DecodesToSameAsLowerCase;
var
  LLower, LUpper: TBolt11;
begin
  LLower := TBolt11Decoder.Decode(CValidFeatures);
  LUpper := TBolt11Decoder.Decode(CValidUpperCase);
  Assert.AreEqual(LLower.Invoice, LUpper.Invoice);
  Assert.AreEqual(LowerCase(CValidUpperCase), LUpper.Invoice);
  Assert.AreEqual(LLower.PaymentHash, LUpper.PaymentHash);
  Assert.AreEqual(LLower.AmountMsat, LUpper.AmountMsat);
end;

procedure TBolt11Tests.IgnoredFields_AreSkipped;
var
  B: TBolt11;
begin
  B := TBolt11Decoder.Decode(CValidIgnoredFields);
  Assert.AreEqual('coffee beans', B.Description);
  Assert.AreEqual('0001020304050607080900010203040506070809000102030405060708090102', B.PaymentHash);
end;

procedure TBolt11Tests.OtherValidVectors_Decode(const AName: string);
var
  B: TBolt11;
begin
  B := TBolt11Decoder.Decode(VectorByName(AName));
  Assert.AreEqual(Ord(bnMainnet), Ord(B.Network));
  Assert.AreEqual(64, Length(B.PaymentHash));
  Assert.AreEqual(64, Length(B.PaymentSecret));
  Assert.AreEqual(130, Length(B.Signature));
end;

procedure TBolt11Tests.Normalize_StripsPrefixWhitespaceAndCase;
var
  LInput: string;
begin
  LInput := '  LIGHTNING:' + Copy(CValidUpperCase, 1, 40) + sLineBreak + #9 + Copy(CValidUpperCase, 41, MaxInt) + ' ';
  Assert.AreEqual(LowerCase(CValidUpperCase), TBolt11Decoder.Normalize(LInput));
  Assert.AreEqual(LowerCase(CValidUpperCase), TBolt11Decoder.Decode(LInput).Invoice);
end;

procedure TBolt11Tests.Invalid_SpecVectorsAreRefused;
begin
  AssertInvalid(CInvalidNWrongLength, 'n field of invalid length');
  AssertInvalid(CInvalidMissingP, 'missing p');
  AssertInvalid(CInvalidTwoDistinctP, 'two distinct p');
  AssertInvalid(CInvalidSamePTwice, 'same p twice');
  AssertInvalid(CInvalidTwoDistinctS, 'two distinct s');
  AssertInvalid(CInvalidBadChecksum, 'bad checksum');
  AssertInvalid(CInvalidNoSeparator, 'no separator');
  AssertInvalid(CInvalidMixedCase, 'mixed case');
  AssertInvalid(CInvalidTooShort, 'too short');
  AssertInvalid(CInvalidInvalidMultiplier, 'unknown multiplier');
  AssertInvalid(CInvalidSubMsat, 'sub-millisatoshi');
  AssertInvalid(CInvalidMissingS, 'missing s');
end;

procedure TBolt11Tests.Invalid_ExtraMalformedStrings;
begin
  AssertInvalid('', 'empty');
  AssertInvalid('   ', 'blank');
  AssertInvalid('lnbc1', 'empty data part');
  AssertInvalid('lnbc1qqqqqq', 'data part shorter than timestamp + signature');
  AssertInvalid('lightning:', 'only the prefix');
  AssertInvalid('bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4', 'a bitcoin address, not an invoice');
  AssertInvalid(StringReplace(CValidCoffee, 'lnbc', 'lnxx', []), 'unknown network (checksum also breaks)');
  AssertInvalid(CValidCoffee + 'q', 'extra character breaks the checksum');
  AssertInvalid(Copy(CValidCoffee, 1, 50) + #$00E9 + Copy(CValidCoffee, 52, MaxInt), 'non-ASCII character');
  AssertInvalid(StringOfChar('q', TBolt11Decoder.CMaxLength + 1), 'too long');
end;

procedure TBolt11Tests.Limitation_UnknownRequiredFeatureIsReportedNotRefused;
var
  B: TBolt11;
begin
  // BOLT 11 lists this as invalid for a payer; the decoder reports it and
  // leaves the decision to the paying node (documented in the unit header).
  B := TBolt11Decoder.Decode(CInvalidUnknownFeature100);
  Assert.IsTrue(B.HasUnknownRequiredFeatures);
  Assert.IsTrue(B.FeatureBits.EndsWith(',100'));
end;

procedure TBolt11Tests.Limitation_SignatureIsNotVerified;
begin
  // Invalid only because of the signature: accepted by design (no secp256k1).
  Assert.WillNotRaise(
    procedure
    begin
      TBolt11Decoder.Decode(CInvalidNotRecoverable);
    end);
  // The high-S vector also carries two s fields, so it is refused anyway.
  AssertInvalid(CInvalidHighSWithN, 'two s fields');
end;

procedure TBolt11Tests.ErrorMessage_NeverContainsTheInvoice;
var
  LMessage: string;
begin
  LMessage := '';
  try
    TBolt11Decoder.Decode(CInvalidBadChecksum);
  except
    on E: EBolt11Error do
      LMessage := E.Message;
  end;
  Assert.IsTrue(LMessage <> '');
  Assert.IsFalse(LMessage.Contains(Copy(CInvalidBadChecksum, 1, 20)));
end;

initialization
  TDUnitX.RegisterTestFixture(TBolt11Tests);

end.
