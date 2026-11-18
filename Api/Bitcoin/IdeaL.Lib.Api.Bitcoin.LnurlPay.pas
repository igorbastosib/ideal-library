unit IdeaL.Lib.Api.Bitcoin.LnurlPay;

{ LNURL-pay client for Lightning addresses. Not tied to any wallet: use it to get
  an invoice, check it, store it, and then pay it with any wallet API (e.g.
  TAPICoinOS.PostPayment).

  Specs: LUD-06 (payRequest), LUD-12 (comments), LUD-16 (Lightning addresses)
  https://github.com/lnurl/luds

  Flow
    LReq := LLnurl.Resolve('alice@example.com');      // GET https://example.com/.well-known/lnurlp/alice
    LInvoice := LLnurl.FetchInvoice(LReq, 21000);     // GET <callback>?amount=21000 (msat)
  FetchInvoice decodes the returned invoice and refuses it when its amount is
  not exactly the requested amount (LUD-06 step 7).

  Safety (on by default)
  - RequireHttps: the well-known URL and the callback must be https.
  - BlockPrivateHosts: the host of each URL (literal IP or every address the
    name resolves to, IPv4 and IPv6) must be a public address: loopback,
    private (RFC 1918, 100.64/10, fc00::/7), link-local, unspecified,
    multicast, documentation and reserved ranges are refused, including
    IPv4-mapped and NAT64 IPv6 forms. Limitation: the name is resolved again by
    the HTTP client, so a DNS answer that changes between the two lookups
    (rebinding) is not caught; servers that need a hard guarantee should also
    restrict outgoing traffic at the firewall.
  - Redirects are not followed (a 3xx answer is an error), so a server cannot
    bounce the request to another host.
  - The callback may live on another host than the address's domain (allowed
    by LUD-06); it goes through the same checks.
  - Error messages carry the reason sent by the server, never the invoice.

  Platforms: Delphi (Windows, POSIX) and FPC (Windows; Unix through netdb,
  not compiled by the maintainer yet). }

{$IFDEF FPC}
{$mode objfpc}{$H+}{$modeswitch advancedrecords}
{$ENDIF}

interface

uses
  IdeaL.Lib.Api,
{$IFDEF FPC}
  Classes,
  SysUtils
{$ELSE}
  System.Classes,
  System.SysUtils
{$ENDIF}
  ;

type
  /// <summary> Raised for any LNURL-pay failure. Reason is the text sent by the
  /// server ("reason" of a status ERROR answer) when there is one. </summary>
  ELnurlPayError = class(Exception)
  private
    FReason: string;
  public
    constructor Create(const AMessage: string; const AReason: string = '');
    property Reason: string read FReason;
  end;

  /// <summary> One IP address as 4 (IPv4) or 16 (IPv6) bytes. </summary>
  TLnurlIpList = array of TBytes;
  /// <summary> Host name resolver; replaceable (e.g. in tests). </summary>
  TLnurlResolveHostEvent = function(const AHost: string): TLnurlIpList of object;

  { TLnurlPayRequest }

  TLnurlPayRequest = record
  public
    /// <summary> Address as given, normalised (trimmed, lower case). </summary>
    Address: string;
    UserName: string;
    Domain: string;
    Callback: string;
    MinSendableMsat: Int64;
    MaxSendableMsat: Int64;
    /// <summary> Metadata string exactly as received (its SHA-256 may be the invoice's h field). </summary>
    Metadata: string;
    /// <summary> LUD-12: maximum comment length, 0 = comments not accepted. </summary>
    CommentAllowed: Integer;
    Tag: string;
    /// <summary> The whole answer of the well-known URL. </summary>
    RawJson: string;
    /// <summary> The "text/plain" entry of Metadata ('' if absent or unreadable). </summary>
    function Description: string;
    /// <summary> MinSendableMsat rounded up to whole sats. </summary>
    function MinSendableSat: Int64;
    /// <summary> MaxSendableMsat rounded down to whole sats. </summary>
    function MaxSendableSat: Int64;
  end;

  { TLnurlPay }

  TLnurlPay = class(TIdeaLApi)
  private
    FRequireHttps: Boolean;
    FBlockPrivateHosts: Boolean;
    FCheckDescriptionHash: Boolean;
    FConnectTimeout: Integer;
    FResponseTimeout: Integer;
    FOnResolveHost: TLnurlResolveHostEvent;
    function ResolveHost(const AHost: string): TLnurlIpList;
    function SafeGet(const AUrl: string): string;
  protected
    /// <summary> URL of the LUD-16 well-known document. Virtual so tests can point it elsewhere. </summary>
    function WellKnownUrl(const AUserName, ADomain: string): string; virtual;
  public
    const
    CLnurlConnectTimeout = 10000;
    CLnurlResponseTimeout = 20000;

    constructor Create; override;

    /// <summary> Splits a LUD-16 address. '@domain' means '_@domain'. False when invalid. </summary>
    class function ParseAddress(const AAddress: string; out AUserName, ADomain: string): Boolean;
    /// <summary> Parses an IPv4 (a.b.c.d) or IPv6 literal (with or without brackets). </summary>
    class function TryParseIp(const AText: string; out AIp: TBytes): Boolean;
    /// <summary> False for loopback, private, link-local, unspecified, multicast,
    /// documentation and reserved addresses (IPv4 and IPv6, mapped forms included). </summary>
    class function IsPublicIp(const AIp: TBytes): Boolean;
    /// <summary> Raises ELnurlPayError when AUrl breaks RequireHttps or BlockPrivateHosts. </summary>
    procedure CheckUrlIsSafe(const AUrl: string);

    /// <summary> GET https://&lt;domain&gt;/.well-known/lnurlp/&lt;user&gt; and parse the payRequest. </summary>
    function Resolve(const AAddress: string): TLnurlPayRequest;
    /// <summary> GET &lt;callback&gt;?amount=&lt;msat&gt;[&amp;comment=...] and return the invoice ("pr").
    /// Checks min/maxSendable and the comment length before the call, and after it that
    /// the invoice decodes and asks for exactly AAmountMsat (and, with
    /// CheckDescriptionHash, that its h field is SHA-256 of the metadata). </summary>
    function FetchInvoice(const ARequest: TLnurlPayRequest; AAmountMsat: Int64;
      const AComment: string = ''): string;

    property RequireHttps: Boolean read FRequireHttps write FRequireHttps;
    property BlockPrivateHosts: Boolean read FBlockPrivateHosts write FBlockPrivateHosts;
    /// <summary> Off by default: LUD-06 no longer requires it and many services
    /// put a "d" description in the invoice instead of the "h" hash. </summary>
    property CheckDescriptionHash: Boolean read FCheckDescriptionHash write FCheckDescriptionHash;
    property ConnectTimeout: Integer read FConnectTimeout write FConnectTimeout;
    property ResponseTimeout: Integer read FResponseTimeout write FResponseTimeout;
    /// <summary> Replaces the system resolver (getaddrinfo). </summary>
    property OnResolveHost: TLnurlResolveHostEvent read FOnResolveHost write FOnResolveHost;
  end;

/// <summary> Percent-encodes a string as UTF-8 for a URL query (RFC 3986 unreserved kept). </summary>
function LnurlUrlEncode(const AValue: string): string;

implementation

uses
  IdeaL.Lib.Bitcoin.Bolt11,
{$IFDEF FPC}
  fpjson,
  jsonparser
  {$IFDEF MSWINDOWS}
  , winsock2
  {$ELSE}
  , netdb
  {$ENDIF}
  ;
{$ELSE}
  System.JSON,
  System.Generics.Collections
  {$IFDEF MSWINDOWS}
  , Winapi.Windows
  , Winapi.Winsock2
  {$ELSE}
  , Posix.SysSocket
  , Posix.NetDB
  {$ENDIF}
  ;
{$ENDIF}

{ ELnurlPayError }

constructor ELnurlPayError.Create(const AMessage, AReason: string);
begin
  if AReason <> '' then
    inherited Create(AMessage + ': ' + AReason)
  else
    inherited Create(AMessage);
  FReason := AReason;
end;

{ JSON helpers (portable) }

type
  TJsonDoc = {$IFDEF FPC}TJSONData{$ELSE}TJSONValue{$ENDIF};

function ParseJson(const AText: string): TJsonDoc;
begin
  try
{$IFDEF FPC}
    Result := GetJSON(AText);
{$ELSE}
    Result := TJSONObject.ParseJSONValue(AText);
{$ENDIF}
  except
    Result := nil;
  end;
end;

function IsJsonObject(ADoc: TJsonDoc): Boolean;
begin
  Result := ADoc is TJSONObject;
end;

function JsonStr(ADoc: TJsonDoc; const AName: string; out AValue: string): Boolean;
{$IFDEF FPC}
var
  LField: TJSONData;
{$ENDIF}
begin
  AValue := '';
{$IFDEF FPC}
  LField := TJSONObject(ADoc).Find(AName);
  Result := Assigned(LField) and (LField.JSONType = jtString);
  if Result then
    AValue := LField.AsString;
{$ELSE}
  Result := TJSONObject(ADoc).TryGetValue<string>(AName, AValue);
{$ENDIF}
end;

function JsonInt64(ADoc: TJsonDoc; const AName: string; out AValue: Int64): Boolean;
{$IFDEF FPC}
var
  LField: TJSONData;
{$ELSE}
var
  LField: TJSONValue;
{$ENDIF}
begin
  AValue := 0;
{$IFDEF FPC}
  LField := TJSONObject(ADoc).Find(AName);
  Result := Assigned(LField) and (LField.JSONType = jtNumber);
  if Result then
    AValue := LField.AsInt64;
{$ELSE}
  LField := TJSONObject(ADoc).GetValue(AName);
  Result := LField is TJSONNumber;
  if Result then
    AValue := TJSONNumber(LField).AsInt64;
{$ENDIF}
end;

{ Raises ELnurlPayError when the document is a LUD "status": "ERROR" answer. }
procedure RaiseIfLnurlError(ADoc: TJsonDoc; const AContext: string);
var
  LStatus, LReason: string;
begin
  if not IsJsonObject(ADoc) then
    Exit;
  if JsonStr(ADoc, 'status', LStatus) and SameText(LStatus, 'ERROR') then
  begin
    JsonStr(ADoc, 'reason', LReason);
    raise ELnurlPayError.Create(AContext + ' refused by the service', LReason);
  end;
end;

{ URL helpers }

function LnurlUrlEncode(const AValue: string): string;
const
  CHex = '0123456789ABCDEF';
var
  LBytes: TBytes;
  I: Integer;
  B: Byte;
begin
  Result := '';
  LBytes := Bolt11Utf8Bytes(AValue);
  for I := 0 to High(LBytes) do
  begin
    B := LBytes[I];
    if CharInSet(Chr(B), ['A'..'Z', 'a'..'z', '0'..'9', '-', '.', '_', '~']) then
      Result := Result + Chr(B)
    else
      Result := Result + '%' + CHex[(B shr 4) + 1] + CHex[(B and $0F) + 1];
  end;
end;

{ Splits scheme://host[:port]/... ; host keeps IPv6 brackets removed. }
function SplitUrl(const AUrl: string; out AScheme, AHost: string): Boolean;
var
  LPos, LEnd, I: Integer;
  LRest, LAuthority: string;
begin
  AScheme := '';
  AHost := '';
  Result := False;
  LPos := Pos('://', AUrl);
  if LPos < 2 then
    Exit;
  AScheme := LowerCase(Copy(AUrl, 1, LPos - 1));
  LRest := Copy(AUrl, LPos + 3, MaxInt);
  LEnd := Length(LRest) + 1;
  for I := 1 to Length(LRest) do
    if CharInSet(LRest[I], ['/', '?', '#']) then
    begin
      LEnd := I;
      Break;
    end;
  LAuthority := Copy(LRest, 1, LEnd - 1);
  if Pos('@', LAuthority) > 0 then // user info is never legitimate here
    Exit;
  if (LAuthority <> '') and (LAuthority[1] = '[') then
  begin
    LPos := Pos(']', LAuthority);
    if LPos = 0 then
      Exit;
    AHost := Copy(LAuthority, 2, LPos - 2);
  end
  else
  begin
    LPos := Pos(':', LAuthority);
    if LPos > 0 then
      AHost := Copy(LAuthority, 1, LPos - 1)
    else
      AHost := LAuthority;
  end;
  AHost := LowerCase(AHost);
  Result := AHost <> '';
end;

{ IP parsing and classification }

function TryParseIPv4(const AText: string; out AIp: TBytes): Boolean;
var
  LParts: array[0..3] of Integer;
  LIndex, I, LDigits: Integer;
begin
  Result := False;
  AIp := nil;
  LIndex := 0;
  LParts[0] := 0;
  LDigits := 0;
  for I := 1 to Length(AText) do
  begin
    if AText[I] = '.' then
    begin
      if (LDigits = 0) or (LIndex = 3) then
        Exit;
      Inc(LIndex);
      LParts[LIndex] := 0;
      LDigits := 0;
    end
    else if CharInSet(AText[I], ['0'..'9']) then
    begin
      Inc(LDigits);
      if LDigits > 3 then
        Exit;
      LParts[LIndex] := LParts[LIndex] * 10 + Ord(AText[I]) - Ord('0');
      if LParts[LIndex] > 255 then
        Exit;
    end
    else
      Exit;
  end;
  if (LIndex <> 3) or (LDigits = 0) then
    Exit;
  SetLength(AIp, 4);
  for I := 0 to 3 do
    AIp[I] := LParts[I];
  Result := True;
end;

function TryParseIPv6(const AText: string; out AIp: TBytes): Boolean;
var
  LText, LHead, LTail, LV4Text: string;
  LGroups: array[0..7] of Word;
  LV4: TBytes;
  LPos, I, LMissing: Integer;

  function ParseGroups(const AList: string; var AOut: array of Word; out ACount: Integer): Boolean;
  var
    J, LValue, LDigits: Integer;
  begin
    Result := False;
    ACount := 0;
    if AList = '' then
      Exit(True);
    LValue := 0;
    LDigits := 0;
    for J := 1 to Length(AList) + 1 do
    begin
      if (J > Length(AList)) or (AList[J] = ':') then
      begin
        if (LDigits = 0) or (ACount > High(AOut)) then
          Exit;
        AOut[ACount] := LValue;
        Inc(ACount);
        LValue := 0;
        LDigits := 0;
      end
      else if CharInSet(AList[J], ['0'..'9', 'a'..'f', 'A'..'F']) then
      begin
        Inc(LDigits);
        if LDigits > 4 then
          Exit;
        LValue := LValue * 16 + StrToInt('$' + AList[J]);
      end
      else
        Exit;
    end;
    Result := True;
  end;

var
  LHeadArr, LTailArr: array[0..7] of Word;
  LHeadCount, LTailCount, LMax: Integer;
begin
  Result := False;
  AIp := nil;
  LText := AText;
  if (LText <> '') and (LText[1] = '[') and (LText[Length(LText)] = ']') then
    LText := Copy(LText, 2, Length(LText) - 2);
  LPos := Pos('%', LText); // zone id
  if LPos > 0 then
    LText := Copy(LText, 1, LPos - 1);
  if Pos(':', LText) = 0 then
    Exit;

  // embedded IPv4 at the end (::ffff:1.2.3.4)
  LV4 := nil;
  LPos := 0;
  for I := Length(LText) downto 1 do
    if LText[I] = ':' then
    begin
      LPos := I;
      Break;
    end;
  LV4Text := Copy(LText, LPos + 1, MaxInt);
  if Pos('.', LV4Text) > 0 then
  begin
    if not TryParseIPv4(LV4Text, LV4) then
      Exit;
    LText := Copy(LText, 1, LPos);
    if Copy(LText, Length(LText) - 1, 2) <> '::' then
      LText := Copy(LText, 1, Length(LText) - 1);
  end;
  LMax := 8;
  if LV4 <> nil then
    LMax := 6;

  LPos := Pos('::', LText);
  if LPos > 0 then
  begin
    LHead := Copy(LText, 1, LPos - 1);
    LTail := Copy(LText, LPos + 2, MaxInt);
    if Pos('::', LTail) > 0 then
      Exit;
    if not ParseGroups(LHead, LHeadArr, LHeadCount) then
      Exit;
    if not ParseGroups(LTail, LTailArr, LTailCount) then
      Exit;
    LMissing := LMax - LHeadCount - LTailCount;
    if LMissing < 1 then
      Exit;
  end
  else
  begin
    if not ParseGroups(LText, LHeadArr, LHeadCount) then
      Exit;
    LTailCount := 0;
    LMissing := 0;
    if LHeadCount <> LMax then
      Exit;
  end;

  for I := 0 to 7 do
    LGroups[I] := 0;
  for I := 0 to LHeadCount - 1 do
    LGroups[I] := LHeadArr[I];
  for I := 0 to LTailCount - 1 do
    LGroups[LHeadCount + LMissing + I] := LTailArr[I];

  SetLength(AIp, 16);
  for I := 0 to 7 do
  begin
    AIp[I * 2] := Byte(LGroups[I] shr 8);
    AIp[I * 2 + 1] := Byte(LGroups[I]);
  end;
  if LV4 <> nil then
    for I := 0 to 3 do
      AIp[12 + I] := LV4[I];
  Result := True;
end;

function IsPublicIPv4(const AIp: TBytes): Boolean;
var
  A, B, C: Byte;
begin
  A := AIp[0];
  B := AIp[1];
  C := AIp[2];
  Result := not (
    (A = 0) or                                  // 0.0.0.0/8 "this network"
    (A = 10) or                                 // 10/8 private
    ((A = 100) and (B >= 64) and (B <= 127)) or // 100.64/10 shared (CGNAT)
    (A = 127) or                                // loopback
    ((A = 169) and (B = 254)) or                // link-local
    ((A = 172) and (B >= 16) and (B <= 31)) or  // 172.16/12 private
    ((A = 192) and (B = 0) and (C = 0)) or      // 192.0.0/24 protocol assignments
    ((A = 192) and (B = 0) and (C = 2)) or      // TEST-NET-1
    ((A = 192) and (B = 168)) or                // 192.168/16 private
    ((A = 198) and ((B = 18) or (B = 19))) or   // 198.18/15 benchmarking
    ((A = 198) and (B = 51) and (C = 100)) or   // TEST-NET-2
    ((A = 203) and (B = 0) and (C = 113)) or    // TEST-NET-3
    (A >= 224));                                // multicast, reserved, broadcast
end;

function IsPublicIPv6(const AIp: TBytes): Boolean;
var
  I: Integer;
  LAllZeroFirst10, LAllZeroFirst12: Boolean;
  LV4: TBytes;
begin
  Result := False;
  LAllZeroFirst10 := True;
  for I := 0 to 9 do
    if AIp[I] <> 0 then
      LAllZeroFirst10 := False;
  LAllZeroFirst12 := LAllZeroFirst10 and (AIp[10] = 0) and (AIp[11] = 0);

  // ::/96 (unspecified, loopback, deprecated IPv4-compatible)
  if LAllZeroFirst12 then
    Exit;
  // ::ffff:0:0/96 IPv4-mapped, and 64:ff9b::/96 NAT64: judge the embedded IPv4
  if (LAllZeroFirst10 and (AIp[10] = $FF) and (AIp[11] = $FF)) or
     ((AIp[0] = $00) and (AIp[1] = $64) and (AIp[2] = $FF) and (AIp[3] = $9B) and
      (AIp[4] = 0) and (AIp[5] = 0) and (AIp[6] = 0) and (AIp[7] = 0) and
      (AIp[8] = 0) and (AIp[9] = 0) and (AIp[10] = 0) and (AIp[11] = 0)) then
  begin
    SetLength(LV4, 4);
    for I := 0 to 3 do
      LV4[I] := AIp[12 + I];
    Exit(IsPublicIPv4(LV4));
  end;
  if (AIp[0] and $FE) = $FC then // fc00::/7 unique local
    Exit;
  if (AIp[0] = $FE) and ((AIp[1] and $C0) = $80) then // fe80::/10 link-local
    Exit;
  if (AIp[0] = $FE) and ((AIp[1] and $C0) = $C0) then // fec0::/10 site-local (deprecated)
    Exit;
  if AIp[0] = $FF then // multicast
    Exit;
  if (AIp[0] = $20) and (AIp[1] = $01) and (AIp[2] = $0D) and (AIp[3] = $B8) then // 2001:db8::/32 documentation
    Exit;
  if (AIp[0] = $01) and (AIp[1] = $00) and (AIp[2] = 0) and (AIp[3] = 0) and
     (AIp[4] = 0) and (AIp[5] = 0) and (AIp[6] = 0) and (AIp[7] = 0) then // 100::/64 discard
    Exit;
  Result := True;
end;

{ System resolver: every address (IPv4 and IPv6) the name resolves to. }

{$IFDEF FPC}
{$IFDEF MSWINDOWS}
type
  PFpcAddrInfo = ^TFpcAddrInfo;
  TFpcAddrInfo = record
    ai_flags: LongInt;
    ai_family: LongInt;
    ai_socktype: LongInt;
    ai_protocol: LongInt;
    ai_addrlen: PtrUInt;
    ai_canonname: PAnsiChar;
    ai_addr: PByte;
    ai_next: PFpcAddrInfo;
  end;

function fpc_getaddrinfo(ANode, AService: PAnsiChar; AHints: PFpcAddrInfo;
  var AResult: PFpcAddrInfo): LongInt; stdcall; external 'ws2_32.dll' name 'getaddrinfo';
procedure fpc_freeaddrinfo(AInfo: PFpcAddrInfo); stdcall; external 'ws2_32.dll' name 'freeaddrinfo';

function SystemResolve(const AHost: string): TLnurlIpList;
var
  LData: TWSAData;
  LHints: TFpcAddrInfo;
  LInfo, LItem: PFpcAddrInfo;
  LIp: TBytes;
  I: Integer;
begin
  Result := nil;
  if WSAStartup($0202, LData) <> 0 then
    Exit;
  try
    FillChar(LHints, SizeOf(LHints), 0);
    LHints.ai_family := AF_UNSPEC;
    LHints.ai_socktype := SOCK_STREAM;
    LInfo := nil;
    if fpc_getaddrinfo(PAnsiChar(AnsiString(AHost)), nil, @LHints, LInfo) <> 0 then
      Exit;
    try
      LItem := LInfo;
      while LItem <> nil do
      begin
        LIp := nil;
        if LItem^.ai_family = AF_INET then
        begin
          SetLength(LIp, 4);
          for I := 0 to 3 do
            LIp[I] := (LItem^.ai_addr + 4 + I)^;
        end
        else if LItem^.ai_family = AF_INET6 then
        begin
          SetLength(LIp, 16);
          for I := 0 to 15 do
            LIp[I] := (LItem^.ai_addr + 8 + I)^;
        end;
        if LIp <> nil then
        begin
          SetLength(Result, Length(Result) + 1);
          Result[High(Result)] := LIp;
        end;
        LItem := LItem^.ai_next;
      end;
    finally
      fpc_freeaddrinfo(LInfo);
    end;
  finally
    WSACleanup;
  end;
end;
{$ELSE}
function SystemResolve(const AHost: string): TLnurlIpList;
var
  L4: array[0..15] of THostAddr;
  L6: array[0..15] of THostAddr6;
  LCount, I, J: Integer;
  LIp: TBytes;
begin
  Result := nil;
  LCount := ResolveName(AHost, L4);
  for I := 0 to LCount - 1 do
  begin
    SetLength(LIp, 4);
    LIp[0] := L4[I].s_bytes[1];
    LIp[1] := L4[I].s_bytes[2];
    LIp[2] := L4[I].s_bytes[3];
    LIp[3] := L4[I].s_bytes[4];
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := LIp;
  end;
  LCount := ResolveName6(AHost, L6);
  for I := 0 to LCount - 1 do
  begin
    SetLength(LIp, 16);
    for J := 0 to 15 do
      LIp[J] := L6[I].u6_addr8[J];
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := LIp;
  end;
end;
{$ENDIF}
{$ELSE}
function AddrToBytes(AFamily: Integer; AAddr: PByte): TBytes;
var
  I: Integer;
begin
  Result := nil;
  // sockaddr_in: address at offset 4; sockaddr_in6: address at offset 8
  // (same offsets on Windows, Linux and BSD/macOS)
  if AFamily = AF_INET then
  begin
    SetLength(Result, 4);
    for I := 0 to 3 do
      Result[I] := PByte(NativeUInt(AAddr) + 4 + NativeUInt(I))^;
  end
  else if AFamily = AF_INET6 then
  begin
    SetLength(Result, 16);
    for I := 0 to 15 do
      Result[I] := PByte(NativeUInt(AAddr) + 8 + NativeUInt(I))^;
  end;
end;

{$IFDEF MSWINDOWS}
function SystemResolve(const AHost: string): TLnurlIpList;
var
  LData: TWSAData;
  LHints: addrinfoW;
  LInfo, LItem: PaddrinfoW;
  LIp: TBytes;
begin
  Result := nil;
  if WSAStartup($0202, LData) <> 0 then
    Exit;
  try
    FillChar(LHints, SizeOf(LHints), 0);
    LHints.ai_family := AF_UNSPEC;
    LHints.ai_socktype := SOCK_STREAM;
    LInfo := nil;
    if GetAddrInfoW(PChar(AHost), nil, LHints, LInfo) <> 0 then
      Exit;
    try
      LItem := LInfo;
      while LItem <> nil do
      begin
        LIp := AddrToBytes(LItem^.ai_family, PByte(LItem^.ai_addr));
        if LIp <> nil then
        begin
          SetLength(Result, Length(Result) + 1);
          Result[High(Result)] := LIp;
        end;
        LItem := LItem^.ai_next;
      end;
    finally
      FreeAddrInfoW(LInfo^);
    end;
  finally
    WSACleanup;
  end;
end;
{$ELSE}
function SystemResolve(const AHost: string): TLnurlIpList;
var
  LHints: addrinfo;
  LInfo, LItem: Paddrinfo;
  LIp: TBytes;
  LMarshaller: TMarshaller;
begin
  Result := nil;
  FillChar(LHints, SizeOf(LHints), 0);
  LHints.ai_family := AF_UNSPEC;
  LHints.ai_socktype := SOCK_STREAM;
  LInfo := nil;
  if getaddrinfo(LMarshaller.AsUtf8(AHost).ToPointer, nil, LHints, LInfo) <> 0 then
    Exit;
  try
    LItem := LInfo;
    while LItem <> nil do
    begin
      LIp := AddrToBytes(LItem^.ai_family, PByte(LItem^.ai_addr));
      if LIp <> nil then
      begin
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := LIp;
      end;
      LItem := LItem^.ai_next;
    end;
  finally
    freeaddrinfo(LInfo^);
  end;
end;
{$ENDIF}
{$ENDIF}

{ TLnurlPayRequest }

function TLnurlPayRequest.Description: string;
var
  LDoc: TJsonDoc;
  I: Integer;
{$IFDEF FPC}
  LEntry: TJSONData;
{$ELSE}
  LEntry: TJSONValue;
{$ENDIF}
begin
  Result := '';
  LDoc := ParseJson(Metadata);
  try
    if not (LDoc is TJSONArray) then
      Exit;
    for I := 0 to TJSONArray(LDoc).Count - 1 do
    begin
{$IFDEF FPC}
      LEntry := TJSONArray(LDoc).Items[I];
      if (LEntry is TJSONArray) and (TJSONArray(LEntry).Count >= 2) and
        (TJSONArray(LEntry).Items[0].JSONType = jtString) and
        (TJSONArray(LEntry).Items[0].AsString = 'text/plain') and
        (TJSONArray(LEntry).Items[1].JSONType = jtString) then
        Exit(TJSONArray(LEntry).Items[1].AsString);
{$ELSE}
      LEntry := TJSONArray(LDoc).Items[I];
      if (LEntry is TJSONArray) and (TJSONArray(LEntry).Count >= 2) and
        (TJSONArray(LEntry).Items[0] is TJSONString) and
        (TJSONArray(LEntry).Items[0].Value = 'text/plain') and
        (TJSONArray(LEntry).Items[1] is TJSONString) then
        Exit(TJSONArray(LEntry).Items[1].Value);
{$ENDIF}
    end;
  finally
    LDoc.Free;
  end;
end;

function TLnurlPayRequest.MaxSendableSat: Int64;
begin
  Result := MaxSendableMsat div 1000;
end;

function TLnurlPayRequest.MinSendableSat: Int64;
begin
  Result := (MinSendableMsat + 999) div 1000;
end;

{ TLnurlPay }

constructor TLnurlPay.Create;
begin
  inherited;
  FRequireHttps := True;
  FBlockPrivateHosts := True;
  FCheckDescriptionHash := False;
  FConnectTimeout := CLnurlConnectTimeout;
  FResponseTimeout := CLnurlResponseTimeout;
  FollowRedirects := False;
end;

class function TLnurlPay.ParseAddress(const AAddress: string; out AUserName,
  ADomain: string): Boolean;
var
  LAddress: string;
  LPos, I: Integer;
begin
  Result := False;
  AUserName := '';
  ADomain := '';
  LAddress := LowerCase(Trim(AAddress));
  if SameText(Copy(LAddress, 1, 10), 'lightning:') then
    Delete(LAddress, 1, 10);
  LPos := Pos('@', LAddress);
  if (LPos = 0) or (Pos('@', Copy(LAddress, LPos + 1, MaxInt)) > 0) then
    Exit;
  AUserName := Copy(LAddress, 1, LPos - 1);
  ADomain := Copy(LAddress, LPos + 1, MaxInt);
  if AUserName = '' then
    AUserName := '_'; // LUD-16 default identifier
  for I := 1 to Length(AUserName) do
    if not CharInSet(AUserName[I], ['a'..'z', '0'..'9', '-', '_', '.', '+']) then
      Exit;
  if (ADomain = '') or (Pos('.', ADomain) = 0) then
    Exit;
  for I := 1 to Length(ADomain) do
    if not CharInSet(ADomain[I], ['a'..'z', '0'..'9', '-', '.', ':']) then
      Exit;
  Result := True;
end;

class function TLnurlPay.TryParseIp(const AText: string; out AIp: TBytes): Boolean;
begin
  Result := TryParseIPv4(AText, AIp) or TryParseIPv6(AText, AIp);
end;

class function TLnurlPay.IsPublicIp(const AIp: TBytes): Boolean;
begin
  case Length(AIp) of
    4: Result := IsPublicIPv4(AIp);
    16: Result := IsPublicIPv6(AIp);
  else
    Result := False;
  end;
end;

function TLnurlPay.ResolveHost(const AHost: string): TLnurlIpList;
begin
  if Assigned(FOnResolveHost) then
    Result := FOnResolveHost(AHost)
  else
    Result := SystemResolve(AHost);
end;

procedure TLnurlPay.CheckUrlIsSafe(const AUrl: string);
var
  LScheme, LHost: string;
  LIp: TBytes;
  LList: TLnurlIpList;
  I: Integer;
begin
  if not SplitUrl(AUrl, LScheme, LHost) then
    raise ELnurlPayError.Create('Invalid URL');
  if (LScheme <> 'https') and (FRequireHttps or (LScheme <> 'http')) then
    raise ELnurlPayError.Create('Only https URLs are accepted');
  if not FBlockPrivateHosts then
    Exit;
  if TryParseIp(LHost, LIp) then
  begin
    if not IsPublicIp(LIp) then
      raise ELnurlPayError.Create('Host is not a public address');
    Exit;
  end;
  if (LHost = 'localhost') or (Copy(LHost, Length(LHost) - 9, 10) = '.localhost') then
    raise ELnurlPayError.Create('Host is not a public address');
  LList := ResolveHost(LHost);
  if Length(LList) = 0 then
    raise ELnurlPayError.Create('Host name could not be resolved');
  for I := 0 to High(LList) do
    if not IsPublicIp(LList[I]) then
      raise ELnurlPayError.Create('Host resolves to an address that is not public');
end;

function TLnurlPay.SafeGet(const AUrl: string): string;
var
  LDoc: TJsonDoc;
begin
  CheckUrlIsSafe(AUrl);
  try
    Result := Get(AUrl, nil, FConnectTimeout, FResponseTimeout);
  except
    on E: EIdeaLApiError do
    begin
      // services often send {"status":"ERROR","reason":...} with a 4xx/5xx status
      LDoc := ParseJson(E.ResponseBody);
      try
        RaiseIfLnurlError(LDoc, 'Request');
      finally
        LDoc.Free;
      end;
      raise ELnurlPayError.Create('Service answered HTTP ' + IntToStr(E.StatusCode));
    end;
  end;
end;

function TLnurlPay.WellKnownUrl(const AUserName, ADomain: string): string;
begin
  Result := 'https://' + ADomain + '/.well-known/lnurlp/' + AUserName;
end;

function TLnurlPay.Resolve(const AAddress: string): TLnurlPayRequest;
var
  LUser, LDomain, LBody: string;
  LDoc: TJsonDoc;
  LValue: Int64;
begin
  if not ParseAddress(AAddress, LUser, LDomain) then
    raise ELnurlPayError.Create('Invalid Lightning address');
  LBody := SafeGet(WellKnownUrl(LUser, LDomain));

  Result.Address := LUser + '@' + LDomain;
  Result.UserName := LUser;
  Result.Domain := LDomain;
  Result.RawJson := LBody;
  Result.Callback := '';
  Result.Metadata := '';
  Result.Tag := '';
  Result.CommentAllowed := 0;
  Result.MinSendableMsat := 0;
  Result.MaxSendableMsat := 0;

  LDoc := ParseJson(LBody);
  try
    if not IsJsonObject(LDoc) then
      raise ELnurlPayError.Create('Answer of the Lightning address is not a JSON object');
    RaiseIfLnurlError(LDoc, 'Lightning address');
    JsonStr(LDoc, 'tag', Result.Tag);
    if Result.Tag <> 'payRequest' then
      raise ELnurlPayError.Create('Lightning address is not a payRequest');
    if not JsonStr(LDoc, 'callback', Result.Callback) or (Result.Callback = '') then
      raise ELnurlPayError.Create('payRequest has no callback');
    if not JsonInt64(LDoc, 'minSendable', Result.MinSendableMsat) or
       not JsonInt64(LDoc, 'maxSendable', Result.MaxSendableMsat) then
      raise ELnurlPayError.Create('payRequest has no minSendable/maxSendable');
    if (Result.MinSendableMsat < 1) or (Result.MinSendableMsat > Result.MaxSendableMsat) then
      raise ELnurlPayError.Create('payRequest has an invalid minSendable/maxSendable range');
    if not JsonStr(LDoc, 'metadata', Result.Metadata) then
      raise ELnurlPayError.Create('payRequest has no metadata');
    if JsonInt64(LDoc, 'commentAllowed', LValue) and (LValue > 0) then
      Result.CommentAllowed := LValue;
  finally
    LDoc.Free;
  end;
end;

function TLnurlPay.FetchInvoice(const ARequest: TLnurlPayRequest;
  AAmountMsat: Int64; const AComment: string): string;
var
  LUrl, LBody: string;
  LDoc: TJsonDoc;
  LInvoice: TBolt11;
  LError: string;
begin
  if (AAmountMsat < ARequest.MinSendableMsat) or (AAmountMsat > ARequest.MaxSendableMsat) then
    raise ELnurlPayError.Create(Format('Amount out of range (%d..%d msat)',
      [ARequest.MinSendableMsat, ARequest.MaxSendableMsat]));
  if (AComment <> '') and (Length(AComment) > ARequest.CommentAllowed) then
    raise ELnurlPayError.Create(Format('Comment too long (max %d characters)', [ARequest.CommentAllowed]));

  LUrl := ARequest.Callback;
  if Pos('?', LUrl) > 0 then
    LUrl := LUrl + '&'
  else
    LUrl := LUrl + '?';
  LUrl := LUrl + 'amount=' + IntToStr(AAmountMsat);
  if AComment <> '' then
    LUrl := LUrl + '&comment=' + LnurlUrlEncode(AComment);

  LBody := SafeGet(LUrl);
  LDoc := ParseJson(LBody);
  try
    if not IsJsonObject(LDoc) then
      raise ELnurlPayError.Create('Answer of the callback is not a JSON object');
    RaiseIfLnurlError(LDoc, 'Invoice request');
    if not JsonStr(LDoc, 'pr', Result) or (Result = '') then
      raise ELnurlPayError.Create('Callback answer has no invoice ("pr")');
  finally
    LDoc.Free;
  end;

  if not TBolt11Decoder.TryDecode(Result, LInvoice, LError) then
    raise ELnurlPayError.Create('Callback returned an invalid invoice', LError);
  if LInvoice.AmountMsat <> AAmountMsat then
    raise ELnurlPayError.Create(Format('Invoice amount (%d msat) differs from the requested amount (%d msat)',
      [LInvoice.AmountMsat, AAmountMsat]));
  if FCheckDescriptionHash and not LInvoice.MatchesMetadata(ARequest.Metadata) then
    raise ELnurlPayError.Create('Invoice description hash does not match the metadata');
  Result := LInvoice.Invoice;
end;

end.
