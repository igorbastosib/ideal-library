unit IdeaL.Lib.Api.Bitcoin.CoinOS;

{$IFDEF FPC}
{$mode objfpc}{$H+}{$modeswitch advancedrecords}
{$ENDIF}

interface

uses
  IdeaL.Lib.Api,
{$IFDEF FPC}
  Classes,
  SysUtils,
  fpJson,

  fphttpclient
{$ELSE}
  System.Classes,
  System.SysUtils,
  System.IOUtils,
  System.JSON,

  System.Net.URLClient,
  System.Net.HttpClient,
  System.Net.HttpClientComponent,
  System.Net.Mime
{$ENDIF}
  ;

type
  /// <summary> State of a payment as reported by GET /payments/:hash (see TAPICoinOS.GetPaymentState). </summary>
  TCoinOSPaymentState = (
    /// <summary> No record: never debited, rejected before the debit (PIN, fee cap,
    /// balance), reversed, or the request has not reached the debit yet. </summary>
    psNone,
    /// <summary> Record with confirmed = false: Lightning payment in flight. Can last
    /// long (hold invoices). Never pay the invoice again while pending. </summary>
    psPending,
    /// <summary> Record with confirmed = true: paid. </summary>
    psPaid);

  /// <remarks>
  /// Check the official documentation
  /// <see cref="https://coinos.io/docs"/>
  /// Server source (the live https://coinos.io/api), full list of end points in index.ts:
  /// <see cref="https://git.coinos.io/coinos-server.git"/>
  /// (GitHub copy, unreachable when last checked on 2026-11-18:
  /// <see cref="https://github.com/coinos/coinos-server/blob/master/index.ts"/>)
  /// Facts documented on the methods below were read in coinos-server master at
  /// commit c0a0f5c and checked against the live API on 2026-11-18.
  /// </remarks>

  { TAPICoinOS }

  TAPICoinOS = class(TIdeaLApi)
  public
    type
    THeaderPair = record
      Key: string;
      Value: string;
      class function Create(AKey, AValue: string): THeaderPair; static;
    end;

    THeaderArray = array of THeaderPair;
    { public declarations }
  private
    FAuthToken: string;
    FHeaderArray: THeaderArray;
    FBaseUrl: string;
    FPaymentTimeout: Integer;
    /// <summary> Default headers (Authorization, Content-Type, Accept), then
    /// HeaderArray, then the per-call headers. </summary>
    function BuildHeaders(const AExtra: TNetHeaders): TNetHeaders;
    function Url(const APath: string): string;
    { private declarations }
  protected
{$IFDEF FPC}
    procedure GetNetHttpRequestLocal(
      out AHttpClient: TFPHttpClient;
      AOnData: TDataEvent = nil);
{$ELSE}
    procedure GetNetHttpRequestLocal(
      out ANetHttpClient: TNetHTTPClient;
      out ANetHttpRequest: TNetHTTPRequest;
      AOnSendDataEvent: TSendDataEvent = nil;
      AOnReceiveData: TReceiveDataEvent = nil);
{$ENDIF}

    /// <summary> POST with the CoinOS headers (see BuildHeaders) and the default timeouts. </summary>
    function Post(AUrl, ABody: string): string; reintroduce; overload;
    function Post(AUrl, ABody: string; AHeaders: TNetHeaders): string; reintroduce; overload;
    /// <summary> GET with the CoinOS headers (see BuildHeaders) and the default timeouts. </summary>
    function Get(AUrl: string): string; reintroduce; overload;
    function Get(AUrl: string; AHeaders: TNetHeaders): string; reintroduce; overload;
    { protected declarations }
  public
    const
    CUrlApi = 'https://coinos.io/api';
    /// <summary> Response timeout of payment calls, in ms. CoinOS pays Lightning
    /// invoices with xpay retry_for: 60 after a route quote, so a payment call can
    /// legitimately take more than 60 s; 90 s leaves room for that. </summary>
    CDefaultPaymentTimeout = 90000;
    CPaymentConnectTimeout = 15000;
    { public declarations }
  public
    constructor Create; override;

    /// <summary> Every request made by this instance carries these CoinOS headers, so
    /// calls made through a TIdeaLApi reference are consistent with the methods below. </summary>
    function Post(AUrl, ABody: string; AHeaders: TNetHeaders;
      AConnectTimeout, AResponseTimeout: Integer): string; overload; override;
    function Get(AUrl: string; AHeaders: TNetHeaders;
      AConnectTimeout, AResponseTimeout: Integer): string; overload; override;

    function AuthToken(AValue: string): TAPICoinOS; overload;
    function AuthToken: string; overload;

    /// <summary> API root, default CUrlApi. Change it for a self-hosted CoinOS or for tests. </summary>
    function BaseUrl(AValue: string): TAPICoinOS; overload;
    function BaseUrl: string; overload;

    /// <summary> Response timeout (ms) used by PostPayment and PostPaymentLnAddress.
    /// Default CDefaultPaymentTimeout (90 s). </summary>
    function PaymentTimeout(AValue: Integer): TAPICoinOS; overload;
    function PaymentTimeout: Integer; overload;

    /// <summary> To add extra headers in case of necessary, e.g.: x-api-key
    /// x-api-key is used on POST LOGIN and, is a Captcha Skip Value you must ask CoinOS team your self for it.
    /// Sent on every GET and POST of this instance.
    /// </summary>
    function HeaderArray(AValue: THeaderArray): TAPICoinOS; overload;
    function HeaderArray: THeaderArray; overload;

    function GetMe: string;
    function GetCredits: string;
    /// <summary> Get CoinOS BTC prices on several FIAT currencies
    /// </summary>
    /// <remarks> This is a public method, no need Authentication
    /// </remarks>
    function GetRates: string;

    function PostRegister(AUsername, APassword: string): string;
    function PostLogin(AUsername, APassword: string): string;
    function PostUser(AJson: string): string;

    /// <summary> Register/Create a Lightning or Bitcoin invoice
    /// </summary>
    /// <param name="AType">lightning or bitcoin</param>
    /// <param name="AAmount">Price in satoshis</param>
    /// <param name="AWebHook">(optional) endpoint to hit when the invoice is paid</param>
    /// <param name="ASecret">(optional, mandatory with WebHook) shared secret sent to the webhook, so it can check the call came from CoinOS</param>
    /// <param name="AExpiration">(optional) Expiration time in seconds</param>
    /// <remarks> Amount must be in SATOSHIS, integer value
    /// </remarks>
    function PostInvoice(AType: string; AAmount: Integer; AWebHook: string = ''; ASecret: string = ''; AExpiration: Integer = 0): string;
    function PostInvoiceBitcoin(AAmount: Integer; AWebHook: string = ''; ASecret: string = ''; AExpiration: Integer = 0): string;
    function PostInvoiceLightning(AAmount: Integer; AWebHook: string = ''; ASecret: string = ''; AExpiration: Integer = 0): string;

    /// <summary> Fetch an invoice you RECEIVE (GET /invoice/:id) by bitcoin address or
    /// lightning payment hash. This is the receive side; to know what happened to an
    /// invoice you PAID use GetPayment / GetPaymentState.
    /// </summary>
    /// <param name="AValue">Lightning invoice hash OR bitcoin address
    /// </param>
    function GetInvoice(AValue: string): string;
    /// <summary> Get all payments sent or received by the current user
    /// </summary>
    /// <param name="AStart"> only payments after this unix time
    /// </param>
    /// <param name="AEnd"> only payments before this unix time
    /// </param>
    /// <param name="ALimit"> limit to this integer number of results
    /// </param>
    /// <param name="AOffset"> start limiting from this integer offset
    /// </param>
    function GetPayments(
      AStart: TDateTime = 0;
      AEnd: TDateTime = 0;
      ALimit: Integer = 0;
      AOffset: Integer = 0
      ): string;

    /// <summary> Pay a BOLT 11 invoice: POST /payments. Returns the payment record (JSON).
    /// </summary>
    /// <param name="AInvoice"> BOLT 11 invoice. Normalised before sending (whitespace and a
    /// "lightning:" prefix removed, lower case), as CoinOS keys invoices in lower case. </param>
    /// <param name="AFee"> Cap for the Lightning routing fee, in sats; sent as "fee" only when
    /// greater than 0. Omitted: CoinOS uses its own route quote. A cap below the quote fails
    /// before any debit ("Routing fee of X required, max fee is Y"); a cap above
    /// max(1000, 5% of the amount) is refused too. (Up to 0.0.6 this was sent as "maxfee",
    /// which CoinOS ignores.) </param>
    /// <param name="AMemo"> Optional memo stored with the payment. </param>
    /// <param name="APin"> Required when the account has a PIN ("Invalid pin" otherwise). </param>
    /// <remarks>
    /// - Uses PaymentTimeout (default 90 s): CoinOS may hold the call about 60 s while paying.
    /// - An invoice issued by another CoinOS user is paid internally; any other goes out over Lightning.
    /// - CoinOS refuses to pay the same invoice twice ("Invoice has already been paid",
    ///   "Payment is already underway", "Previous attempt is still settling", "Invoice already paid"),
    ///   so retrying with the SAME invoice is the safe retry. The check is not atomic: never run two
    ///   calls for the same invoice at the same time.
    /// - EIdeaLApiError = CoinOS answered with an error (nothing debited by that attempt).
    ///   Any other exception (TIdeaLApi.IsTransportError) = no answer: wait, then GetPaymentState
    ///   before retrying. See Api/Bitcoin/README.md, "Paying a Lightning address safely".
    /// </remarks>
    function PostPayment(AInvoice: string; AFee: Integer = 0; AMemo: string = ''; APin: string = ''): string;
    /// <summary> Payment record of an invoice: GET /payments/:hash with the BOLT 11 invoice as :hash.
    /// Returns '' when CoinOS has no record (it answers HTTP 200 with the body "null"),
    /// the record JSON otherwise. Raises EIdeaLApiError on a non-2xx answer.
    /// </summary>
    /// <remarks>
    /// - Public end point (no authentication); anyone holding the invoice can read the record.
    /// - The invoice is normalised (lower case) because CoinOS does not lowercase this route.
    /// - For an INTERNAL invoice (payee is another CoinOS user) the answer is the RECIPIENT's
    ///   record (positive amount, type "internal", confirmed true, with "with" = the other
    ///   user's public fields); it still proves the payment happened.
    /// - States: no record = never debited, refused before the debit or reversed (a reversal
    ///   deletes the record); "confirmed": false = in flight; "confirmed": true = paid.
    /// </remarks>
    function GetPayment(AInvoice: string): string;
    /// <summary> GetPayment interpreted: psNone / psPending / psPaid. ARecord receives the JSON ('' for psNone).
    /// Raises an exception when the answer is not a payment record of this invoice.
    /// </summary>
    function GetPaymentState(AInvoice: string; out ARecord: string): TCoinOSPaymentState;
    /// <summary> Removes whitespace and a "lightning:" prefix and lowercases a BOLT 11 invoice. </summary>
    class function NormalizeInvoice(const AInvoice: string): string; static;

    /// <summary> Routing + platform fee quote for an invoice: POST /lightning/quote.
    /// Useful to choose AFee for PostPayment. AAmount only for amountless invoices.
    /// </summary>
    function PostLightningQuote(AInvoice: string; AAmount: Integer = 0): string;
    /// <summary> Server-side decode of a BOLT 11 invoice: GET /decode/:bolt11 (public).
    /// The library also decodes invoices locally with TBolt11Decoder (IdeaL.Lib.Bitcoin.Bolt11).
    /// </summary>
    function GetDecode(AInvoice: string): string;

    /// <summary> Creates an invoice FOR another CoinOS user (POST /invoice with the user's
    /// username); it does not move money by itself. Pay the returned invoice with PostPayment.
    /// </summary>
    function PostPaymentToUser(AAmount: Integer; AUserName: string): string;
    /// <summary> Send a bitcoin payment
    /// </summary>
    function PostBitcoinSend(AAmount: Integer; AAddress: string): string;
    /// <summary> Pay a Lightning address in ONE call: POST /send/:lnaddress/:amount.
    /// </summary>
    /// <param name="AAddress"> LN Address, LNURL-Pay (LUD-16) username@domain.tld
    /// </param>
    /// <param name="AAmount"> Amount sent in satoshis
    /// </param>
    /// <param name="AMaxFee"> Routing fee cap in sats, sent as "fee" only when greater than 0
    /// (up to 0.0.6 a 0 was sent and CoinOS treated it as a cap of 0). </param>
    /// <param name="APin"> Required when the account has a PIN. </param>
    /// <remarks> CoinOS resolves the address, fetches the invoice and pays it inside this one
    /// call. The invoice is never returned before money moves, the invoice amount is not
    /// checked against AAmount, and the memo cannot be set. If the call fails without an
    /// answer you cannot find out whether it paid. When the payment must be tracked or
    /// retried safely, use the three-step path instead: TLnurlPay.Resolve and FetchInvoice
    /// (IdeaL.Lib.Api.Bitcoin.LnurlPay), TBolt11Decoder.Decode, PostPayment, GetPaymentState.
    /// </remarks>
    function PostPaymentLnAddress(AAddress: string; AAmount: Integer; AMaxFee: Integer = 0; APin: string = ''): string;

    /// <summary> Request Token to access ONLY "Create Invoice" and "Payment History"
    /// </summary>
    function GetRo(): string;
    { public declarations }
  end;

implementation

uses
{$IFDEF FPC}
  jsonparser,
  DateUtils;
{$ELSE}
  System.DateUtils;
{$ENDIF}

{ helpers }

function JsonObjectToString(AObject: TJSONObject): string;
begin
{$IFDEF FPC}
  Result := AObject.AsJSON;
{$ELSE}
  Result := AObject.ToString;
{$ENDIF}
end;

procedure JsonAddStr(AObject: TJSONObject; const AName, AValue: string);
begin
{$IFDEF FPC}
  AObject.Add(AName, AValue);
{$ELSE}
  AObject.AddPair(AName, AValue);
{$ENDIF}
end;

procedure JsonAddInt(AObject: TJSONObject; const AName: string; AValue: Integer);
begin
{$IFDEF FPC}
  AObject.Add(AName, AValue);
{$ELSE}
  AObject.AddPair(AName, TJSONNumber.Create(AValue));
{$ENDIF}
end;

procedure JsonAddObj(AObject: TJSONObject; const AName: string; AValue: TJSONObject);
begin
{$IFDEF FPC}
  AObject.Add(AName, AValue);
{$ELSE}
  AObject.AddPair(AName, AValue);
{$ENDIF}
end;

{ TAPICoinOS }

function TAPICoinOS.AuthToken: string;
begin
  Result := FAuthToken;
end;

function TAPICoinOS.AuthToken(AValue: string): TAPICoinOS;
begin
  Result := Self;
  FAuthToken := AValue;
end;

function TAPICoinOS.BaseUrl: string;
begin
  Result := FBaseUrl;
end;

function TAPICoinOS.BaseUrl(AValue: string): TAPICoinOS;
begin
  Result := Self;
  FBaseUrl := AValue;
  while (FBaseUrl <> '') and (FBaseUrl[Length(FBaseUrl)] = '/') do
    Delete(FBaseUrl, Length(FBaseUrl), 1);
end;

function TAPICoinOS.PaymentTimeout: Integer;
begin
  Result := FPaymentTimeout;
end;

function TAPICoinOS.PaymentTimeout(AValue: Integer): TAPICoinOS;
begin
  Result := Self;
  FPaymentTimeout := AValue;
end;

constructor TAPICoinOS.Create;
begin
  inherited;
  SetLength(FHeaderArray, 0);
  FBaseUrl := CUrlApi;
  FPaymentTimeout := CDefaultPaymentTimeout;
end;

function TAPICoinOS.Url(const APath: string): string;
begin
  Result := FBaseUrl + '/' + APath;
end;

function TAPICoinOS.BuildHeaders(const AExtra: TNetHeaders): TNetHeaders;
var
  I, LCount: Integer;
  LHeaderPair: THeaderPair;
begin
  Result := nil;
  SetLength(Result, 3 + Length(FHeaderArray) + Length(AExtra));
  Result[0] := TNameValuePair.Create('Authorization', 'Bearer ' + FAuthToken);
  Result[1] := TNameValuePair.Create('Content-Type', 'application/json; charset=utf-8');
  Result[2] := TNameValuePair.Create('Accept', '*/*');
  LCount := 3;
  for LHeaderPair in FHeaderArray do
  begin
    Result[LCount] := TNameValuePair.Create(LHeaderPair.Key, LHeaderPair.Value);
    Inc(LCount);
  end;
  for I := 0 to High(AExtra) do
  begin
    Result[LCount] := AExtra[I];
    Inc(LCount);
  end;
end;

function TAPICoinOS.Get(AUrl: string; AHeaders: TNetHeaders; AConnectTimeout,
  AResponseTimeout: Integer): string;
begin
  Result := inherited Get(AUrl, BuildHeaders(AHeaders), AConnectTimeout, AResponseTimeout);
end;

function TAPICoinOS.Post(AUrl, ABody: string; AHeaders: TNetHeaders;
  AConnectTimeout, AResponseTimeout: Integer): string;
begin
  Result := inherited Post(AUrl, ABody, BuildHeaders(AHeaders), AConnectTimeout, AResponseTimeout);
end;

function TAPICoinOS.Get(AUrl: string): string;
begin
  Result := Get(AUrl, nil, CDefaultConnectTimeout, CDefaultResponseTimeout);
end;

function TAPICoinOS.Get(AUrl: string; AHeaders: TNetHeaders): string;
begin
  Result := Get(AUrl, AHeaders, CDefaultConnectTimeout, CDefaultResponseTimeout);
end;

function TAPICoinOS.Post(AUrl, ABody: string): string;
begin
  Result := Post(AUrl, ABody, nil, CDefaultConnectTimeout, CDefaultResponseTimeout);
end;

function TAPICoinOS.Post(AUrl, ABody: string; AHeaders: TNetHeaders): string;
begin
  Result := Post(AUrl, ABody, AHeaders, CDefaultConnectTimeout, CDefaultResponseTimeout);
end;

function TAPICoinOS.GetRates: string;
begin
  Result := Get(Url('rates'));
end;

function TAPICoinOS.GetRo: string;
begin
  Result := Get(Url('ro'));
end;

function TAPICoinOS.HeaderArray: THeaderArray;
begin
  Result := FHeaderArray;
end;

function TAPICoinOS.HeaderArray(AValue: THeaderArray): TAPICoinOS;
begin
  Result := Self;
  FHeaderArray := AValue;
end;

function TAPICoinOS.GetCredits: string;
begin
  Result := Get(Url('credits'));
end;

function TAPICoinOS.GetInvoice(AValue: string): string;
begin
  Result := Get(Url('invoice/' + AValue));
end;

function TAPICoinOS.GetMe: string;
begin
  Result := Get(Url('me'));
end;

{$IFDEF FPC}
procedure TAPICoinOS.GetNetHttpRequestLocal(
  out AHttpClient: TFPHttpClient;
  AOnData: TDataEvent = nil);
begin
  GetHttpRequest(AHttpClient, AOnData);
  AHttpClient.AddHeader('Content-Type', 'application/json');
  AHttpClient.AddHeader('Authorization', 'Bearer ' + FAuthToken);
end;
{$ELSE}
procedure TAPICoinOS.GetNetHttpRequestLocal(out ANetHttpClient: TNetHTTPClient;
  out ANetHttpRequest: TNetHTTPRequest; AOnSendDataEvent: TSendDataEvent;
  AOnReceiveData: TReceiveDataEvent);
begin
  GetNetHttpRequest(ANetHttpClient, ANetHttpRequest, AOnSendDataEvent, AOnReceiveData);
  ANetHttpClient.ContentType := 'application/json; charset=utf-8';
  ANetHttpClient.AcceptEncoding :='';

  ANetHttpClient.CustomHeaders['Content-Type'] := ANetHttpClient.ContentType;
  ANetHttpClient.CustomHeaders['Accept'] := ANetHttpClient.Accept;
  ANetHttpClient.CustomHeaders['Authorization'] := 'Bearer ' + FAuthToken;
end;
{$ENDIF}

function TAPICoinOS.GetPayments(AStart: TDateTime; AEnd: TDateTime;
  ALimit: Integer; AOffset: Integer): string;
var
  LParams: string;
  LInt64: Int64;
begin
  LParams := EmptyStr;
  if AStart > 0 then
  begin
    LInt64 := DateTimeToUnix(AStart) * 1000;
    LParams := LParams + '&start=' + IntToStr(LInt64);
  end;
  if AEnd > 0 then
  begin
    LInt64 := DateTimeToUnix(AEnd) * 1000;
    LParams := LParams + '&end=' + IntToStr(LInt64);
  end;
  if ALimit > 0 then
    LParams := LParams + '&limit=' + IntToStr(ALimit);
  if AOffset > 0 then
    LParams := LParams + '&offset=' + IntToStr(AOffset);
  if LParams <> '' then
    LParams := '?' + Copy(LParams, 2, MaxInt);
  Result := Get(Url('payments' + LParams));
end;

function TAPICoinOS.PostBitcoinSend(AAmount: Integer; AAddress: string): string;
var
  LJSONObj: TJSONObject;
  LBody: string;
begin
  LJSONObj := TJSONObject.Create;
  try
    JsonAddInt(LJSONObj, 'amount', AAmount);
    JsonAddStr(LJSONObj, 'address', AAddress);
    LBody := JsonObjectToString(LJSONObj);
  finally
    LJSONObj.Free;
  end;
  Result := Post(Url('bitcoin/send'), LBody);
end;

function TAPICoinOS.PostInvoice(AType: string; AAmount: Integer;
  AWebHook: string; ASecret: string; AExpiration: Integer): string;
var
  LJSONObj, LInvoice: TJSONObject;
  LBody: string;
begin
  LJSONObj := TJSONObject.Create;
  try
    LInvoice := TJSONObject.Create;
    JsonAddInt(LInvoice, 'amount', AAmount);
    JsonAddStr(LInvoice, 'type', AType);
    if Trim(AWebHook) <> '' then
      JsonAddStr(LInvoice, 'webhook', AWebHook);
    if Trim(ASecret) <> '' then
      JsonAddStr(LInvoice, 'secret', ASecret);
    if AExpiration > 0 then
      JsonAddInt(LInvoice, 'expiry', AExpiration);
    JsonAddObj(LJSONObj, 'invoice', LInvoice);
    LBody := JsonObjectToString(LJSONObj);
  finally
    LJSONObj.Free;
  end;
  Result := Post(Url('invoice'), LBody);
end;

function TAPICoinOS.PostInvoiceBitcoin(AAmount: Integer; AWebHook: string;
  ASecret: string; AExpiration: Integer): string;
begin
  Result := PostInvoice('bitcoin', AAmount, AWebHook, ASecret, AExpiration);
end;

function TAPICoinOS.PostInvoiceLightning(AAmount: Integer; AWebHook: string;
  ASecret: string; AExpiration: Integer): string;
begin
  Result := PostInvoice('lightning', AAmount, AWebHook, ASecret, AExpiration);
end;

function TAPICoinOS.PostLogin(AUsername, APassword: string): string;
var
  LJSONObj: TJSONObject;
  LBody: string;
begin
  LJSONObj := TJSONObject.Create;
  try
    JsonAddStr(LJSONObj, 'username', AUsername);
    JsonAddStr(LJSONObj, 'password', APassword);
    LBody := JsonObjectToString(LJSONObj);
  finally
    LJSONObj.Free;
  end;
  Result := Post(Url('login'), LBody);
end;

class function TAPICoinOS.NormalizeInvoice(const AInvoice: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(AInvoice) do
    if Ord(AInvoice[I]) > 32 then
      Result := Result + AInvoice[I];
  if SameText(Copy(Result, 1, 10), 'lightning:') then
    Delete(Result, 1, 10);
  Result := LowerCase(Result);
end;

{ Raises when the normalised invoice could put anything else than bech32
  characters into a URL path. The message never contains the invoice. }
procedure CheckInvoiceForPath(const AInvoice: string);
var
  I: Integer;
begin
  if AInvoice = '' then
    raise EArgumentException.Create('Invoice is empty');
  for I := 1 to Length(AInvoice) do
    if not CharInSet(AInvoice[I], ['a'..'z', '0'..'9']) then
      raise EArgumentException.Create('Invoice contains characters that are not bech32');
end;

function TAPICoinOS.PostPayment(AInvoice: string; AFee: Integer; AMemo: string;
  APin: string): string;
var
  LJSONObj: TJSONObject;
  LBody: string;
begin
  LJSONObj := TJSONObject.Create;
  try
    JsonAddStr(LJSONObj, 'payreq', NormalizeInvoice(AInvoice));
    if AFee > 0 then
      JsonAddInt(LJSONObj, 'fee', AFee);
    if AMemo <> '' then
      JsonAddStr(LJSONObj, 'memo', AMemo);
    if APin <> '' then
      JsonAddStr(LJSONObj, 'pin', APin);
    LBody := JsonObjectToString(LJSONObj);
  finally
    LJSONObj.Free;
  end;
  Result := Post(Url('payments'), LBody, nil, CPaymentConnectTimeout, FPaymentTimeout);
end;

function TAPICoinOS.GetPayment(AInvoice: string): string;
var
  LInvoice: string;
begin
  LInvoice := NormalizeInvoice(AInvoice);
  CheckInvoiceForPath(LInvoice);
  Result := Trim(Get(Url('payments/' + LInvoice)));
  if (Result = 'null') or (Result = '""') then
    Result := '';
end;

function TAPICoinOS.GetPaymentState(AInvoice: string;
  out ARecord: string): TCoinOSPaymentState;
var
  LConfirmed: Boolean;
  LHash: string;
{$IFDEF FPC}
  LData: TJSONData;
  LField: TJSONData;
{$ELSE}
  LValue: TJSONValue;
{$ENDIF}
begin
  ARecord := GetPayment(AInvoice);
  if ARecord = '' then
    Exit(psNone);

  LConfirmed := False;
  LHash := '';
{$IFDEF FPC}
  try
    LData := GetJSON(ARecord);
  except
    LData := nil;
  end;
  try
    if not (LData is TJSONObject) then
      raise Exception.Create('CoinOS GET /payments/:hash returned something that is not a payment record');
    LField := TJSONObject(LData).Find('confirmed');
    if not Assigned(LField) or (LField.JSONType <> jtBoolean) then
      raise Exception.Create('CoinOS payment record has no "confirmed" field');
    LConfirmed := LField.AsBoolean;
    LField := TJSONObject(LData).Find('hash');
    if Assigned(LField) and (LField.JSONType = jtString) then
      LHash := LField.AsString;
  finally
    LData.Free;
  end;
{$ELSE}
  LValue := TJSONObject.ParseJSONValue(ARecord);
  try
    if not (LValue is TJSONObject) then
      raise Exception.Create('CoinOS GET /payments/:hash returned something that is not a payment record');
    if not TJSONObject(LValue).TryGetValue<Boolean>('confirmed', LConfirmed) then
      raise Exception.Create('CoinOS payment record has no "confirmed" field');
    TJSONObject(LValue).TryGetValue<string>('hash', LHash);
  finally
    LValue.Free;
  end;
{$ENDIF}
  if (LHash <> '') and (LowerCase(LHash) <> NormalizeInvoice(AInvoice)) then
    raise Exception.Create('CoinOS payment record belongs to another invoice');

  if LConfirmed then
    Result := psPaid
  else
    Result := psPending;
end;

function TAPICoinOS.PostLightningQuote(AInvoice: string; AAmount: Integer): string;
var
  LJSONObj: TJSONObject;
  LBody: string;
begin
  LJSONObj := TJSONObject.Create;
  try
    JsonAddStr(LJSONObj, 'payreq', NormalizeInvoice(AInvoice));
    if AAmount > 0 then
      JsonAddInt(LJSONObj, 'amount', AAmount);
    LBody := JsonObjectToString(LJSONObj);
  finally
    LJSONObj.Free;
  end;
  Result := Post(Url('lightning/quote'), LBody);
end;

function TAPICoinOS.GetDecode(AInvoice: string): string;
var
  LInvoice: string;
begin
  LInvoice := NormalizeInvoice(AInvoice);
  CheckInvoiceForPath(LInvoice);
  Result := Get(Url('decode/' + LInvoice));
end;

function TAPICoinOS.PostPaymentLnAddress(AAddress: string;
  AAmount, AMaxFee: Integer; APin: string): string;
var
  LJSONObj: TJSONObject;
  LBody: string;
begin
  LJSONObj := TJSONObject.Create;
  try
    if AMaxFee > 0 then
      JsonAddInt(LJSONObj, 'fee', AMaxFee);
    if APin <> '' then
      JsonAddStr(LJSONObj, 'pin', APin);
    LBody := JsonObjectToString(LJSONObj);
  finally
    LJSONObj.Free;
  end;
  Result := Post(Url('send/' + AAddress + '/' + IntToStr(AAmount)), LBody, nil,
    CPaymentConnectTimeout, FPaymentTimeout);
end;

function TAPICoinOS.PostPaymentToUser(AAmount: Integer;
  AUserName: string): string;
var
  LJSONObj, LInner: TJSONObject;
  LBody: string;
begin
  LJSONObj := TJSONObject.Create;
  try
    LInner := TJSONObject.Create;
    JsonAddInt(LInner, 'amount', AAmount);
    JsonAddStr(LInner, 'type', 'lightning');
    JsonAddObj(LJSONObj, 'invoice', LInner);
    LInner := TJSONObject.Create;
    JsonAddStr(LInner, 'username', AUserName);
    JsonAddObj(LJSONObj, 'user', LInner);
    LBody := JsonObjectToString(LJSONObj);
  finally
    LJSONObj.Free;
  end;
  Result := Post(Url('invoice'), LBody);
end;

function TAPICoinOS.PostRegister(AUsername, APassword: string): string;
var
  LJSONObj, LUser: TJSONObject;
  LBody: string;
begin
  LJSONObj := TJSONObject.Create;
  try
    LUser := TJSONObject.Create;
    JsonAddStr(LUser, 'username', AUsername);
    JsonAddStr(LUser, 'password', APassword);
    JsonAddObj(LJSONObj, 'user', LUser);
    LBody := JsonObjectToString(LJSONObj);
  finally
    LJSONObj.Free;
  end;
  Result := Post(Url('register'), LBody);
end;

function TAPICoinOS.PostUser(AJson: string): string;
begin
  Result := Post(Url('user'), AJson);
end;

{ TAPICoinOS.THeaderPair }

class function TAPICoinOS.THeaderPair.Create(AKey, AValue: string): THeaderPair;
begin
  Result.Key := AKey;
  Result.Value := AValue;
end;

end.
