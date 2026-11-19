unit IdeaL.Lib.Bitcoin.Bolt11;

{ BOLT 11 Lightning invoice decoder. Pure code: no network, no external
  libraries, same behaviour on Delphi and Free Pascal.

  Spec: https://github.com/lightning/bolts/blob/master/11-payment-encoding.md

  What it does
  - bech32 decoding with checksum (no 90-character limit, BOLT 11 invoices are
    longer); upper case or lower case accepted, mixed case refused;
    whitespace and a leading "lightning:" are removed.
  - Human-readable part: network prefix (lnbc, lntb, lntbs, lnbcrt) and amount
    with the multipliers m, u, n, p, converted to millisatoshi.
  - Data part: timestamp, tagged fields p, s, d, h, n, x, c and 9; unknown
    tags are skipped. The reader rules of the spec are enforced: exactly one p
    and one s, exactly one of d or h, fixed lengths of p/h/s/n, valid UTF-8 in d.

  What it does NOT do
  - It does not verify the signature (that needs secp256k1). Decode is for
    inspecting an invoice before paying it (amount, network, expiry, payment
    hash); the node that pays it (e.g. CoinOS) verifies the signature.
  - It does not recover the payee public key when the invoice has no "n" field.

  Error messages never contain the invoice. }

{$IFDEF FPC}
{$mode objfpc}{$H+}{$modeswitch advancedrecords}
{$ENDIF}

interface

uses
{$IFDEF FPC}
  Classes,
  SysUtils,
  DateUtils
{$ELSE}
  System.Classes,
  System.SysUtils,
  System.DateUtils
{$ENDIF}
  ;

type
  EBolt11Error = class(Exception);

  TBolt11Network = (bnUnknown, bnMainnet, bnTestnet, bnSignet, bnRegtest);

  { TBolt11 }

  TBolt11 = record
  public
    /// <summary> Normalised invoice: lower case, no whitespace, no "lightning:" prefix.
    /// This is the form CoinOS uses as key (POST /payments, GET /payments/:hash). </summary>
    Invoice: string;
    Network: TBolt11Network;
    /// <summary> 'bc', 'tb', 'tbs' or 'bcrt' </summary>
    CurrencyPrefix: string;
    /// <summary> Amount in millisatoshi; -1 when the invoice has no amount. </summary>
    AmountMsat: Int64;
    /// <summary> Creation time, seconds since 1970-01-01 UTC. </summary>
    Timestamp: Int64;
    /// <summary> p: 32-byte payment hash, lower-case hex. </summary>
    PaymentHash: string;
    /// <summary> s: 32-byte payment secret, lower-case hex. </summary>
    PaymentSecret: string;
    /// <summary> d: description (UTF-8). Empty when the invoice uses h instead. </summary>
    Description: string;
    HasDescription: Boolean;
    /// <summary> h: SHA-256 of the long description, lower-case hex ('' if absent). </summary>
    DescriptionHash: string;
    /// <summary> x: seconds after Timestamp when the invoice expires (default 3600). </summary>
    Expiry: Int64;
    /// <summary> c: min_final_cltv_expiry_delta (default 18). </summary>
    MinFinalCltvExpiry: Int64;
    /// <summary> n: 33-byte payee public key, hex; '' when absent (recovery needs secp256k1). </summary>
    PayeePubKey: string;
    /// <summary> 9: numbers of the feature bits that are set, ascending and
    /// comma-separated, e.g. '8,14,99' ('' if the field is absent). </summary>
    FeatureBits: string;
    /// <summary> True when the 9 field sets an even (required) feature bit this
    /// decoder does not know. BOLT 11 tells the payer to refuse such an invoice;
    /// the decoder only reports it, the paying node decides. </summary>
    HasUnknownRequiredFeatures: Boolean;
    /// <summary> 65-byte signature (r || s || recovery id), hex. Not verified. </summary>
    Signature: string;

    function HasAmount: Boolean;
    /// <summary> Amount in satoshi, rounded down; -1 when amountless. </summary>
    function AmountSat: Int64;
    /// <summary> Expiry instant (Timestamp + Expiry) as a UTC TDateTime. </summary>
    function ExpiresAtUtc: TDateTime;
    function ExpiresAtUnix: Int64;
    /// <summary> True when ANowUtc + AMarginSec is at or after the expiry instant. </summary>
    function IsExpired(ANowUtc: TDateTime; AMarginSec: Integer = 0): Boolean;
    /// <summary> LNURL-pay (LUD-06) check: True when h = SHA-256 of the metadata
    /// string exactly as received (UTF-8 bytes). False when the invoice has no h. </summary>
    function MatchesMetadata(const AMetadata: string): Boolean;
  end;

  { TBolt11Decoder }

  TBolt11Decoder = class
  public
    const
    CMaxLength = 10000;
    CDefaultExpiry = 3600;
    CDefaultMinFinalCltvExpiry = 18;
    /// <summary> Removes whitespace and a "lightning:" prefix and lowercases. </summary>
    class function Normalize(const AInvoice: string): string; static;
    /// <summary> Decodes and sanity-checks a BOLT 11 invoice. Raises EBolt11Error. </summary>
    class function Decode(const AInvoice: string): TBolt11; static;
    class function TryDecode(const AInvoice: string; out AResult: TBolt11;
      out AError: string): Boolean; static;
  end;

/// <summary> SHA-256 of a byte array (portable implementation). </summary>
function Bolt11Sha256(const AData: TBytes): TBytes;
/// <summary> Lower-case hex of a byte array. </summary>
function Bolt11BytesToHex(const AData: TBytes): string;
/// <summary> UTF-8 bytes of a string. On Delphi the string is UTF-16 and is
/// encoded; on FPC the string bytes are taken as they are (Lazarus/FPC strings
/// read from HTTP already hold UTF-8). </summary>
function Bolt11Utf8Bytes(const AValue: string): TBytes;

implementation

const
  CCharset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
  CSignatureWords = 104; // 520 bits
  CTimestampWords = 7;   // 35 bits

  // tagged field types (index of the letter in CCharset)
  CTagP = 1;  // p
  CTagS = 16; // s
  CTagD = 13; // d
  CTagH = 23; // h
  CTagN = 19; // n
  CTagX = 6;  // x
  CTagC = 24; // c
  CTag9 = 5;  // 9

type
  TWords = array of Byte;

{ helpers }

procedure RaiseBolt11(const AMessage: string);
begin
  raise EBolt11Error.Create('Invalid BOLT 11 invoice: ' + AMessage);
end;

function Bolt11BytesToHex(const AData: TBytes): string;
const
  CHex = '0123456789abcdef';
var
  I: Integer;
begin
  SetLength(Result, Length(AData) * 2);
  for I := 0 to High(AData) do
  begin
    Result[I * 2 + 1] := CHex[(AData[I] shr 4) + 1];
    Result[I * 2 + 2] := CHex[(AData[I] and $0F) + 1];
  end;
end;

function Bolt11Utf8Bytes(const AValue: string): TBytes;
begin
{$IFDEF FPC}
  Result := nil;
  SetLength(Result, Length(AValue));
  if Length(AValue) > 0 then
    Move(AValue[1], Result[0], Length(AValue));
{$ELSE}
  Result := TEncoding.UTF8.GetBytes(AValue);
{$ENDIF}
end;

function Utf8BytesToString(const AData: TBytes): string;
begin
{$IFDEF FPC}
  SetLength(Result, Length(AData));
  if Length(AData) > 0 then
    Move(AData[0], Result[1], Length(AData));
{$ELSE}
  Result := TEncoding.UTF8.GetString(AData);
{$ENDIF}
end;

function IsValidUtf8(const AData: TBytes): Boolean;
var
  I, LNeed: Integer;
  B: Byte;
  LCode: Cardinal;
  LMin: Cardinal;
begin
  Result := False;
  I := 0;
  while I < Length(AData) do
  begin
    B := AData[I];
    if B < $80 then
    begin
      Inc(I);
      Continue;
    end;
    if (B and $E0) = $C0 then
    begin
      LNeed := 1;
      LCode := B and $1F;
      LMin := $80;
    end
    else if (B and $F0) = $E0 then
    begin
      LNeed := 2;
      LCode := B and $0F;
      LMin := $800;
    end
    else if (B and $F8) = $F0 then
    begin
      LNeed := 3;
      LCode := B and $07;
      LMin := $10000;
    end
    else
      Exit;
    if I + LNeed > High(AData) then
      Exit;
    Inc(I);
    while LNeed > 0 do
    begin
      B := AData[I];
      if (B and $C0) <> $80 then
        Exit;
      LCode := (LCode shl 6) or (B and $3F);
      Inc(I);
      Dec(LNeed);
    end;
    if (LCode < LMin) or (LCode > $10FFFF) or ((LCode >= $D800) and (LCode <= $DFFF)) then
      Exit;
  end;
  Result := True;
end;

{ SHA-256 (FIPS 180-4) }

{$IFOPT Q+}{$DEFINE BOLT11_Q_ON}{$Q-}{$ENDIF}
{$IFOPT R+}{$DEFINE BOLT11_R_ON}{$R-}{$ENDIF}

const
  CSha256K: array[0..63] of Cardinal = (
    $428a2f98, $71374491, $b5c0fbcf, $e9b5dba5, $3956c25b, $59f111f1, $923f82a4, $ab1c5ed5,
    $d807aa98, $12835b01, $243185be, $550c7dc3, $72be5d74, $80deb1fe, $9bdc06a7, $c19bf174,
    $e49b69c1, $efbe4786, $0fc19dc6, $240ca1cc, $2de92c6f, $4a7484aa, $5cb0a9dc, $76f988da,
    $983e5152, $a831c66d, $b00327c8, $bf597fc7, $c6e00bf3, $d5a79147, $06ca6351, $14292967,
    $27b70a85, $2e1b2138, $4d2c6dfc, $53380d13, $650a7354, $766a0abb, $81c2c92e, $92722c85,
    $a2bfe8a1, $a81a664b, $c24b8b70, $c76c51a3, $d192e819, $d6990624, $f40e3585, $106aa070,
    $19a4c116, $1e376c08, $2748774c, $34b0bcb5, $391c0cb3, $4ed8aa4a, $5b9cca4f, $682e6ff3,
    $748f82ee, $78a5636f, $84c87814, $8cc70208, $90befffa, $a4506ceb, $bef9a3f7, $c67178f2);

function RotR(AValue: Cardinal; ABits: Byte): Cardinal; inline;
begin
  Result := (AValue shr ABits) or (AValue shl (32 - ABits));
end;

function Bolt11Sha256(const AData: TBytes): TBytes;
var
  H: array[0..7] of Cardinal;
  W: array[0..63] of Cardinal;
  LMsg: TBytes;
  LLen, LBitLen: UInt64;
  LPadded, LBlock, I: Integer;
  A, B, C, D, E, F, G, HH, S0, S1, Ch, Maj, T1, T2: Cardinal;
begin
  H[0] := $6a09e667; H[1] := $bb67ae85; H[2] := $3c6ef372; H[3] := $a54ff53a;
  H[4] := $510e527f; H[5] := $9b05688c; H[6] := $1f83d9ab; H[7] := $5be0cd19;

  LLen := Length(AData);
  LPadded := ((LLen + 8) div 64 + 1) * 64;
  SetLength(LMsg, LPadded);
  FillChar(LMsg[0], LPadded, 0);
  if LLen > 0 then
    Move(AData[0], LMsg[0], LLen);
  LMsg[LLen] := $80;
  LBitLen := LLen * 8;
  for I := 0 to 7 do
    LMsg[LPadded - 1 - I] := Byte(LBitLen shr (8 * I));

  LBlock := 0;
  while LBlock < LPadded do
  begin
    for I := 0 to 15 do
      W[I] := (Cardinal(LMsg[LBlock + I * 4]) shl 24) or
              (Cardinal(LMsg[LBlock + I * 4 + 1]) shl 16) or
              (Cardinal(LMsg[LBlock + I * 4 + 2]) shl 8) or
              Cardinal(LMsg[LBlock + I * 4 + 3]);
    for I := 16 to 63 do
    begin
      S0 := RotR(W[I - 15], 7) xor RotR(W[I - 15], 18) xor (W[I - 15] shr 3);
      S1 := RotR(W[I - 2], 17) xor RotR(W[I - 2], 19) xor (W[I - 2] shr 10);
      W[I] := W[I - 16] + S0 + W[I - 7] + S1;
    end;
    A := H[0]; B := H[1]; C := H[2]; D := H[3];
    E := H[4]; F := H[5]; G := H[6]; HH := H[7];
    for I := 0 to 63 do
    begin
      S1 := RotR(E, 6) xor RotR(E, 11) xor RotR(E, 25);
      Ch := (E and F) xor ((not E) and G);
      T1 := HH + S1 + Ch + CSha256K[I] + W[I];
      S0 := RotR(A, 2) xor RotR(A, 13) xor RotR(A, 22);
      Maj := (A and B) xor (A and C) xor (B and C);
      T2 := S0 + Maj;
      HH := G; G := F; F := E; E := D + T1;
      D := C; C := B; B := A; A := T1 + T2;
    end;
    H[0] := H[0] + A; H[1] := H[1] + B; H[2] := H[2] + C; H[3] := H[3] + D;
    H[4] := H[4] + E; H[5] := H[5] + F; H[6] := H[6] + G; H[7] := H[7] + HH;
    Inc(LBlock, 64);
  end;

  Result := nil;
  SetLength(Result, 32);
  for I := 0 to 7 do
  begin
    Result[I * 4] := Byte(H[I] shr 24);
    Result[I * 4 + 1] := Byte(H[I] shr 16);
    Result[I * 4 + 2] := Byte(H[I] shr 8);
    Result[I * 4 + 3] := Byte(H[I]);
  end;
end;

{ bech32 }

function Polymod(const AValues: TWords): Cardinal;
const
  CGen: array[0..4] of Cardinal = ($3b6a57b2, $26508e6d, $1ea119fa, $3d4233dd, $2a1462b3);
var
  I, J: Integer;
  LTop: Cardinal;
begin
  Result := 1;
  for I := 0 to High(AValues) do
  begin
    LTop := Result shr 25;
    Result := ((Result and $1FFFFFF) shl 5) xor AValues[I];
    for J := 0 to 4 do
      if ((LTop shr J) and 1) = 1 then
        Result := Result xor CGen[J];
  end;
end;

{$IFDEF BOLT11_Q_ON}{$Q+}{$UNDEF BOLT11_Q_ON}{$ENDIF}
{$IFDEF BOLT11_R_ON}{$R+}{$UNDEF BOLT11_R_ON}{$ENDIF}

function VerifyChecksum(const AHrp: string; const AData: TWords): Boolean;
var
  LValues: TWords;
  I, LHrpLen: Integer;
begin
  LHrpLen := Length(AHrp);
  SetLength(LValues, LHrpLen * 2 + 1 + Length(AData));
  for I := 1 to LHrpLen do
    LValues[I - 1] := Ord(AHrp[I]) shr 5;
  LValues[LHrpLen] := 0;
  for I := 1 to LHrpLen do
    LValues[LHrpLen + I] := Ord(AHrp[I]) and 31;
  for I := 0 to High(AData) do
    LValues[LHrpLen * 2 + 1 + I] := AData[I];
  Result := Polymod(LValues) = 1;
end;

{ Converts 5-bit groups to bytes; trailing bits that do not fill a byte are dropped. }
function WordsToBytes(const AWords: TWords; AStart, ACount: Integer): TBytes;
var
  I, LBits, LOut: Integer;
  LAcc: Cardinal;
begin
  Result := nil;
  SetLength(Result, (ACount * 5) div 8);
  LAcc := 0;
  LBits := 0;
  LOut := 0;
  for I := AStart to AStart + ACount - 1 do
  begin
    LAcc := ((LAcc shl 5) or AWords[I]) and $FFF;
    Inc(LBits, 5);
    if LBits >= 8 then
    begin
      Dec(LBits, 8);
      Result[LOut] := Byte(LAcc shr LBits);
      Inc(LOut);
    end;
  end;
end;

function WordsToInt(const AWords: TWords; AStart, ACount: Integer): Int64;
var
  I: Integer;
begin
  if ACount > 12 then // 60 bits fit in Int64
    RaiseBolt11('integer field too long');
  Result := 0;
  for I := AStart to AStart + ACount - 1 do
    Result := (Result shl 5) or AWords[I];
end;

function HexOfWords(const AWords: TWords; AStart, ACount: Integer): string;
begin
  Result := Bolt11BytesToHex(WordsToBytes(AWords, AStart, ACount));
end;

{ Parses '<digits>[m|u|n|p]' into millisatoshi. }
function ParseAmountMsat(const AAmount: string): Int64;
var
  LDigits: string;
  LMult: Char;
  LValue: Int64;
  I: Integer;
const
  CMaxInt64 = High(Int64);
begin
  LDigits := AAmount;
  LMult := #0;
  if (LDigits <> '') and not CharInSet(LDigits[Length(LDigits)], ['0'..'9']) then
  begin
    LMult := LDigits[Length(LDigits)];
    Delete(LDigits, Length(LDigits), 1);
  end;
  if LDigits = '' then
    RaiseBolt11('amount has no digits');
  LValue := 0;
  for I := 1 to Length(LDigits) do
  begin
    if not CharInSet(LDigits[I], ['0'..'9']) then
      RaiseBolt11('amount contains a non-digit');
    if LValue > (CMaxInt64 - 9) div 10 then
      RaiseBolt11('amount too large');
    LValue := LValue * 10 + (Ord(LDigits[I]) - Ord('0'));
  end;
  case LMult of
    #0:
      begin // whole bitcoin: 1 BTC = 100 000 000 000 msat
        if LValue > CMaxInt64 div 100000000000 then
          RaiseBolt11('amount too large');
        Result := LValue * 100000000000;
      end;
    'm':
      begin
        if LValue > CMaxInt64 div 100000000 then
          RaiseBolt11('amount too large');
        Result := LValue * 100000000;
      end;
    'u':
      begin
        if LValue > CMaxInt64 div 100000 then
          RaiseBolt11('amount too large');
        Result := LValue * 100000;
      end;
    'n':
      begin
        if LValue > CMaxInt64 div 100 then
          RaiseBolt11('amount too large');
        Result := LValue * 100;
      end;
    'p':
      begin
        if (LValue mod 10) <> 0 then
          RaiseBolt11('pico amount is not a whole millisatoshi');
        Result := LValue div 10;
      end;
  else
    RaiseBolt11('unknown amount multiplier');
    Result := 0;
  end;
end;

{ Known even (required) feature bits for invoices, BOLT 9 context "9":
  8 var_onion_optin, 14 payment_secret, 16 basic_mpp, 24 option_route_blinding,
  48 option_payment_metadata. }
function IsKnownEvenFeature(ABit: Integer): Boolean;
begin
  Result := (ABit = 8) or (ABit = 14) or (ABit = 16) or (ABit = 24) or (ABit = 48);
end;

{ The 9 field is a big-endian bit string: bit 0 is the lowest bit of the last word. }
function ReadFeatures(const AWords: TWords; AStart, ACount: Integer;
  out AUnknownRequired: Boolean): string;
var
  I, J, LBit: Integer;
begin
  Result := '';
  AUnknownRequired := False;
  for I := 0 to ACount - 1 do
    for J := 0 to 4 do
      if ((AWords[AStart + ACount - 1 - I] shr J) and 1) = 1 then
      begin
        LBit := I * 5 + J;
        if Result <> '' then
          Result := Result + ',';
        Result := Result + IntToStr(LBit);
        if ((LBit mod 2) = 0) and not IsKnownEvenFeature(LBit) then
          AUnknownRequired := True;
      end;
end;

{ TBolt11 }

function TBolt11.AmountSat: Int64;
begin
  if AmountMsat < 0 then
    Result := -1
  else
    Result := AmountMsat div 1000;
end;

function TBolt11.ExpiresAtUnix: Int64;
begin
  Result := Timestamp + Expiry;
end;

function TBolt11.ExpiresAtUtc: TDateTime;
begin
  Result := UnixToDateTime(ExpiresAtUnix{$IFNDEF FPC}, True{$ENDIF});
end;

function TBolt11.HasAmount: Boolean;
begin
  Result := AmountMsat >= 0;
end;

function TBolt11.IsExpired(ANowUtc: TDateTime; AMarginSec: Integer): Boolean;
begin
  Result := DateTimeToUnix(ANowUtc{$IFNDEF FPC}, True{$ENDIF}) + AMarginSec >= ExpiresAtUnix;
end;

function TBolt11.MatchesMetadata(const AMetadata: string): Boolean;
begin
  Result := (DescriptionHash <> '') and
    SameText(DescriptionHash, Bolt11BytesToHex(Bolt11Sha256(Bolt11Utf8Bytes(AMetadata))));
end;

{ TBolt11Decoder }

class function TBolt11Decoder.Normalize(const AInvoice: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(AInvoice) do
    if not CharInSet(AInvoice[I], [#0..#32]) then
      Result := Result + AInvoice[I];
  if SameText(Copy(Result, 1, 10), 'lightning:') then
    Delete(Result, 1, 10);
  Result := LowerCase(Result);
end;

class function TBolt11Decoder.Decode(const AInvoice: string): TBolt11;
var
  LRaw, LHrp, LAmount: string;
  I, LSep, LDataLen, LEnd, LPos, LType, LLen: Integer;
  LHasLower, LHasUpper: Boolean;
  LWords: TWords;
  LCount: array[0..31] of Integer;
  LBytes: TBytes;
  LIdx: Integer;
  LUnknownRequired: Boolean;
begin
  // strip whitespace and the URI scheme, keep the case to detect mixed case
  LRaw := '';
  for I := 1 to Length(AInvoice) do
    if not CharInSet(AInvoice[I], [#0..#32]) then
      LRaw := LRaw + AInvoice[I];
  if SameText(Copy(LRaw, 1, 10), 'lightning:') then
    Delete(LRaw, 1, 10);

  if LRaw = '' then
    RaiseBolt11('empty string');
  if Length(LRaw) > CMaxLength then
    RaiseBolt11('too long');

  LHasLower := False;
  LHasUpper := False;
  for I := 1 to Length(LRaw) do
  begin
    if (Ord(LRaw[I]) < 33) or (Ord(LRaw[I]) > 126) then
      RaiseBolt11('character out of range');
    if CharInSet(LRaw[I], ['a'..'z']) then
      LHasLower := True;
    if CharInSet(LRaw[I], ['A'..'Z']) then
      LHasUpper := True;
  end;
  if LHasLower and LHasUpper then
    RaiseBolt11('mixed case');
  LRaw := LowerCase(LRaw);

  LSep := 0;
  for I := Length(LRaw) downto 1 do
    if LRaw[I] = '1' then
    begin
      LSep := I;
      Break;
    end;
  if LSep < 2 then
    RaiseBolt11('no separator');
  LHrp := Copy(LRaw, 1, LSep - 1);
  LDataLen := Length(LRaw) - LSep;
  if LDataLen < 6 then
    RaiseBolt11('data part too short');

  SetLength(LWords, LDataLen);
  for I := 0 to LDataLen - 1 do
  begin
    LIdx := Pos(LRaw[LSep + 1 + I], CCharset);
    if LIdx = 0 then
      RaiseBolt11('invalid bech32 character');
    LWords[I] := LIdx - 1;
  end;
  if not VerifyChecksum(LHrp, LWords) then
    RaiseBolt11('bad checksum');
  SetLength(LWords, LDataLen - 6); // drop checksum

  if Length(LWords) < CTimestampWords + CSignatureWords then
    RaiseBolt11('data part too short');

  // human-readable part
  Result.Invoice := LRaw;
  if Copy(LHrp, 1, 2) <> 'ln' then
    RaiseBolt11('prefix is not "ln"');
  if Copy(LHrp, 3, 4) = 'bcrt' then
  begin
    Result.Network := bnRegtest;
    Result.CurrencyPrefix := 'bcrt';
  end
  else if Copy(LHrp, 3, 3) = 'tbs' then
  begin
    Result.Network := bnSignet;
    Result.CurrencyPrefix := 'tbs';
  end
  else if Copy(LHrp, 3, 2) = 'bc' then
  begin
    Result.Network := bnMainnet;
    Result.CurrencyPrefix := 'bc';
  end
  else if Copy(LHrp, 3, 2) = 'tb' then
  begin
    Result.Network := bnTestnet;
    Result.CurrencyPrefix := 'tb';
  end
  else
    RaiseBolt11('unknown network prefix');
  LAmount := Copy(LHrp, 3 + Length(Result.CurrencyPrefix), MaxInt);
  if LAmount = '' then
    Result.AmountMsat := -1
  else
    Result.AmountMsat := ParseAmountMsat(LAmount);

  // data part
  Result.Timestamp := WordsToInt(LWords, 0, CTimestampWords);
  Result.PaymentHash := '';
  Result.PaymentSecret := '';
  Result.Description := '';
  Result.HasDescription := False;
  Result.DescriptionHash := '';
  Result.Expiry := CDefaultExpiry;
  Result.MinFinalCltvExpiry := CDefaultMinFinalCltvExpiry;
  Result.PayeePubKey := '';
  Result.FeatureBits := '';
  Result.HasUnknownRequiredFeatures := False;
  for I := 0 to 31 do
    LCount[I] := 0;

  LEnd := Length(LWords) - CSignatureWords;
  LPos := CTimestampWords;
  while LPos < LEnd do
  begin
    if LPos + 3 > LEnd then
      RaiseBolt11('truncated tagged field');
    LType := LWords[LPos];
    LLen := LWords[LPos + 1] * 32 + LWords[LPos + 2];
    Inc(LPos, 3);
    if LPos + LLen > LEnd then
      RaiseBolt11('truncated tagged field');
    Inc(LCount[LType]);
    case LType of
      CTagP:
        begin
          if LLen <> 52 then
            RaiseBolt11('p field has a wrong length');
          Result.PaymentHash := HexOfWords(LWords, LPos, LLen);
        end;
      CTagS:
        begin
          if LLen <> 52 then
            RaiseBolt11('s field has a wrong length');
          Result.PaymentSecret := HexOfWords(LWords, LPos, LLen);
        end;
      CTagH:
        begin
          if LLen <> 52 then
            RaiseBolt11('h field has a wrong length');
          Result.DescriptionHash := HexOfWords(LWords, LPos, LLen);
        end;
      CTagN:
        begin
          if LLen <> 53 then
            RaiseBolt11('n field has a wrong length');
          Result.PayeePubKey := HexOfWords(LWords, LPos, LLen);
        end;
      CTagD:
        begin
          LBytes := WordsToBytes(LWords, LPos, LLen);
          if not IsValidUtf8(LBytes) then
            RaiseBolt11('d field is not valid UTF-8');
          Result.Description := Utf8BytesToString(LBytes);
          Result.HasDescription := True;
        end;
      CTagX:
        Result.Expiry := WordsToInt(LWords, LPos, LLen);
      CTagC:
        Result.MinFinalCltvExpiry := WordsToInt(LWords, LPos, LLen);
      CTag9:
        begin
          Result.FeatureBits := ReadFeatures(LWords, LPos, LLen, LUnknownRequired);
          Result.HasUnknownRequiredFeatures := LUnknownRequired;
        end;
    end; // unknown tags (f, r, m, ...) are skipped
    Inc(LPos, LLen);
  end;

  if LCount[CTagP] <> 1 then
    RaiseBolt11('there must be exactly one p field');
  if LCount[CTagS] <> 1 then
    RaiseBolt11('there must be exactly one s field');
  if (LCount[CTagD] + LCount[CTagH]) <> 1 then
    RaiseBolt11('there must be exactly one d or h field');
  if LCount[CTagN] > 1 then
    RaiseBolt11('more than one n field');

  Result.Signature := HexOfWords(LWords, LEnd, CSignatureWords);
end;

class function TBolt11Decoder.TryDecode(const AInvoice: string;
  out AResult: TBolt11; out AError: string): Boolean;
begin
  AError := '';
  try
    AResult := Decode(AInvoice);
    Result := True;
  except
    on E: EBolt11Error do
    begin
      AError := E.Message;
      Result := False;
    end;
  end;
end;

end.
