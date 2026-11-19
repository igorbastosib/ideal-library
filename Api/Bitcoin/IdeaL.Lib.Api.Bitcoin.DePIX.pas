unit IdeaL.Lib.Api.Bitcoin.DePIX;

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
  /// <remarks>
  /// Check the official documentation
  /// <see cref="https://docs.eulen.app/"/>
  /// </remarks>
  /// <remarks>
  /// 2026-06-01 Webhook (receipt of settlement events):
  ///   - Register a WebHook: only via Eulen's Telegram Bot,
  ///     command /registerwebhook <deposit|withdraw|med> <url> <secret>
  ///     (there is not REST endpoint to register a WebHook)
  ///   - Authentication: Eulen will send 'Authorization: Basic base64(:<secret>)'
  ///     in every request to your WebHook. Your APP must read this value.
  ///   - SLA: your APP must reply 200 OK in maximum 15. Eulen runs automatic re-tries.
  ///   - Idempotence: use bankTxId as deduplication key.
  ///   - Fallback: If the endpoint was unreachable, use GetDeposits(start, end)
  ///     to refresh Deposit status
  /// <see cref="https://docs.eulen.app/-webhook-849106m0"/>
  /// </remarks>
  TAPIDePix = class(TIdeaLApi)
  private
    FAuthToken: string;
    FXAsync: string;
    FXNonce: string;
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

    // Virtual since 0.0.7 so that descendants and the tests under Tests/ can intercept requests.
    function Post(AUrl, ABody: string): string; virtual;
    function Get(AUrl: string): string; virtual;
    { protected declarations }
  public
    const
    CUrlApi = 'https://depix.eulen.app/api';
  public
    constructor Create;

    function AuthToken(AValue: string): TAPIDePix; overload;
    function AuthToken: string; overload;
    function XAsync(AValue: string): TAPIDePix; overload;
    function XAsync: string; overload;
    function XNonce(AValue: string): TAPIDePix; overload;
    function XNonce: string; overload;

    function GetDepositStatus(AId: string): string;
    function GetPing: string;
    function GetUserInfo(AEuid: string): string;

    /// <summary> The system generates a dynamic QR code designed for deposits
    /// in Reais (BRL) through the PIX banking system
    /// <see cref="https://docs.eulen.app/deposit-pix-depix-12532107e0"/>
    /// </summary>
    /// <param name="AStart"> Start date in YYYY-MM-DD format or RFC3339.
    /// </param>
    /// <param name="AEnd"> End date in YYYY-MM-DD format or RFC3339.
    /// </param>
    /// <param name="AStatus"> A status to filter by.
    // Allowed values: pending, depix_sent, under_review, canceled, error, refunded, expired
    /// </param>
    function GetDeposits(AStart, AEnd, AStatus: string): string; overload;
    function GetDeposits(AStart, AEnd: TDate; AStatus: string): string; overload;

    /// <summary> The system generates a dynamic QR code designed for deposits
    /// in Reais (BRL) through the PIX banking system
    /// <see cref="https://docs.eulen.app/deposit-pix-depix-12532107e0"/>
    /// </summary>
    /// <param name="AAmountInCents"> Required - Integer value in cents of reais.
    /// For R$ 1,00 for example: the number passed must be 100. >= 1 <= 10000000
    /// </param>
    /// <param name="ADepixAddress"> Optional DePix Address
    /// </param>
    /// <param name="ADepixSplitAddress"> Optional DePix Split Address
    /// </param>
    /// <param name="ASplitFee"> Optional Split Fee (the percentage of
    /// amountInCents that will be splitted and sent to depixSplitAddress)
    /// </param>
    /// <param name="AEndUserTaxNumber"> Required End user tax number
    /// Required since 2026-07-01
    /// </param>
    function PostDeposit(AAmountInCents: Integer; AEndUserTaxNumber: string): string; overload;
    function PostDeposit(
      AAmountInCents: Integer;
      ADepixAddress: string;
      ADepixSplitAddress: string;
      ASplitFee: string;
      AEndUserTaxNumber: string): string; overload;
    { public declarations }
  end;

implementation

{ TAPIDePix }

function TAPIDePix.AuthToken(AValue: string): TAPIDePix;
begin
  Result := Self;
  FAuthToken := AValue;
end;

function TAPIDePix.AuthToken: string;
begin
  Result := FAuthToken;
end;

constructor TAPIDePix.Create;
begin
  FAuthToken := EmptyStr;
  FXAsync := 'false';
  FXNonce := EmptyStr;
end;

{$IFDEF FPC}
procedure TAPIDePix.GetNetHttpRequestLocal(
  out AHttpClient: TFPHttpClient;
  AOnData: TDataEvent = nil);
begin
  GetHttpRequest(AHttpClient, AOnData);
  AHttpClient.AddHeader('Content-Type', 'application/json');
  AHttpClient.AddHeader('Authorization', 'Bearer ' + FAuthToken);
  if not FXAsync.Trim.IsEmpty then
    AHttpClient.AddHeader('X-Async', FXAsync);
  if not FXNonce.Trim.IsEmpty then
    AHttpClient.AddHeader('X-Nonce', FXNonce);
end;
{$ELSE}
procedure TAPIDePix.GetNetHttpRequestLocal(out ANetHttpClient: TNetHTTPClient;
  out ANetHttpRequest: TNetHTTPRequest; AOnSendDataEvent: TSendDataEvent;
  AOnReceiveData: TReceiveDataEvent);
begin
  GetNetHttpRequest(ANetHttpClient, ANetHttpRequest, AOnSendDataEvent, AOnReceiveData);
  ANetHttpClient.ContentType := 'application/json; charset=utf-8';
  ANetHttpClient.AcceptEncoding :='';

  ANetHttpClient.CustomHeaders['Content-Type'] := ANetHttpClient.ContentType;
  ANetHttpClient.CustomHeaders['Accept'] := ANetHttpClient.Accept;
  ANetHttpClient.CustomHeaders['Authorization'] := 'Bearer ' + FAuthToken;
  if not FXAsync.Trim.IsEmpty then
    ANetHttpClient.CustomHeaders['X-Async'] := FXAsync;
  if not FXNonce.Trim.IsEmpty then
    ANetHttpClient.CustomHeaders['X-Nonce'] := FXNonce;
end;

{$ENDIF}

function TAPIDePix.Get(AUrl: string): string;
{$IFDEF FPC}
var
  LHttpClient: TFPHttpClient;
  LResponse : TStringList;
{$ELSE}
var
  LHttp: THTTPClient;
  LResponse: IHTTPResponse;
{$ENDIF}
begin
{$IFDEF FPC}
  InitSSLInterface;
  GetNetHttpRequestLocal(LHttpClient);
  try
    LResponse := TStringList.Create;
    try
      LHttpClient.Get(AUrl, LResponse);
      if (LHttpClient.ResponseStatusCode < 200) or (LHttpClient.ResponseStatusCode > 299) then
        raise exception.create(LHttpClient.ResponseStatusText);
      Result := LResponse.Text;
    finally
      LResponse.Free;
    end;
  finally
    LHttpClient.Free;
  end;
{$ELSE}
  {var
  LHeader: TNetHeaders;
  LHeader :=
    [
      TNameValuePair.Create('Authorization', 'Bearer ' + FAuthToken),
      TNameValuePair.Create('Content-Type', 'application/json; charset=utf-8'),
      TNameValuePair.Create('Accept', '*/*')
    ];

  LHttp := THTTPClient.Create;}
  var
  LNetHttpClient: TNetHTTPClient := nil;
  var
  LNetHttpRequest: TNetHTTPRequest := nil;
  try
    GetNetHttpRequestLocal(LNetHttpClient, LNetHttpRequest, nil, nil);
    // LResponse := LHttp.Get(AUrl, nil, LHeader);
    LResponse := LNetHttpRequest.Get(AUrl);
  finally
    // FreeAndNil(LHttp);
    LNetHttpClient.Free;
    LNetHttpRequest.Free;
  end;

  if (LResponse.StatusCode < 200) or (LResponse.StatusCode > 299) then
  begin
    var
    LMsg := EmptyStr;
    try
      LMsg := LResponse.ContentAsString(TEncoding.UTF8);
      if not LMsg.Trim.IsEmpty then
        LMsg := ' - ' + LMsg;
    except

    end;
    raise Exception.Create(LResponse.StatusCode.ToString + ' ' + LResponse.StatusText + LMsg);
  end;
  Result := LResponse.ContentAsString(TEncoding.UTF8);
{$ENDIF}
end;

function TAPIDePix.GetDeposits(AStart, AEnd, AStatus: string): string;
var
  LUrl: string;
begin
(*
  Expected response on 2026-07-05
{
  "response": {
      "expiration": "2026-07-05T06:29:06-03:00",
      "payerEUID": "EU013206491353926",
      "payerName": "",
      "payerTaxNumber": "***.186.140-**",
      "pixKey": "compra.depix.sem.estorno@plebank.com.br",
      "qrId": "019f3189de7c7bd8936f0bee33a8c8cb",
      "status": "pending",
      "valueInCents": 5000
  },
  "async": false
}
*)
  LUrl := Format('%s/deposits?start=%s&end=%s', [CUrlApi, AStart, AEnd]);
  if not AStatus.Trim.IsEmpty then
    LUrl := LUrl + '&status=' + AStatus;
  Result := Get(LUrl);
end;

function TAPIDePix.GetDeposits(AStart, AEnd: TDate; AStatus: string): string;
begin
  var
  LStart := FormatDateTime('yyyy-mm-dd', AStart);
  var
  LEnd := FormatDateTime('yyyy-mm-dd', AEnd);
  Result := GetDeposits(LStart, LEnd, AStatus);
end;

function TAPIDePix.GetDepositStatus(AId: string): string;
var
  LUrl: string;
begin
  LUrl := Format('%s/deposit-status?id=%s', [CUrlApi, AId]);
  Result := Get(LUrl);
end;

function TAPIDePix.GetPing: string;
var
  LUrl: string;
begin
  LUrl := Format('%s/ping', [CUrlApi]);
  Result := Get(LUrl);
end;

function TAPIDePix.GetUserInfo(AEuid: string): string;
var
  LUrl: string;
begin
  LUrl := Format('%s/user-info?euid=%s', [CUrlApi, AEuid]);
  Result := Get(LUrl);
end;

function TAPIDePix.Post(AUrl, ABody: string): string;
{$IFDEF FPC}
var
  LHttpClient: TFPHttpClient;
  LResponse : TStringList;
{$ELSE}
var
  LHttp: THTTPClient;
  LResponse: IHTTPResponse;
{$ENDIF}
begin
{$IFDEF FPC}
  InitSSLInterface;
  GetNetHttpRequestLocal(LHttpClient);
  try
    LResponse := TStringList.Create;
    LHttpClient.RequestBody := TRawByteStringStream.Create(ABody);
    try
      LHttpClient.ConnectTimeout := 30000;
      LHttpClient.Post(AUrl, LResponse);
      if LHttpClient.ResponseStatusCode <> 200 then
        raise exception.create(LHttpClient.ResponseStatusText);
      Result := LResponse.Text;
    finally
      LHttpClient.RequestBody.Free;
      LResponse.Free;
    end;
  finally
    LHttpClient.Free;
  end;
{$ELSE}
  {var
  LHeader: TNetHeaders;
  LHeader :=
    [
      TNameValuePair.Create('Authorization', 'Bearer ' + FAuthToken),
      TNameValuePair.Create('Content-Type', 'application/json; charset=utf-8'),
      TNameValuePair.Create('Accept', '*/*')
    ];

  LHttp := THTTPClient.Create;}
  var
  LStrm := TStringStream.Create(ABody, TEncoding.UTF8, False);
  var
  LNetHttpClient: TNetHTTPClient := nil;
  var
  LNetHttpRequest: TNetHTTPRequest := nil;
  try
    GetNetHttpRequestLocal(LNetHttpClient, LNetHttpRequest, nil, nil);

    LStrm.Position := 0;
    // LResponse := LHttp.Post(AUrl, LStrm, nil, LHeader);
    LResponse := LNetHttpRequest.Post(AUrl, LStrm);
  finally
    LStrm.Free;
    // FreeAndNil(LHttp);
    LNetHttpClient.Free;
    LNetHttpRequest.Free;
  end;

  if (LResponse.StatusCode < 200) or (LResponse.StatusCode > 299) then
  begin
    var
    LMsg := EmptyStr;
    try
      LMsg := LResponse.ContentAsString(TEncoding.UTF8);
      if not LMsg.Trim.IsEmpty then
        LMsg := ' - ' + LMsg;
    except

    end;
    raise Exception.Create(LResponse.StatusCode.ToString + ' ' + LResponse.StatusText + LMsg);
  end;
  Result := LResponse.ContentAsString(TEncoding.UTF8);
{$ENDIF}
end;

function TAPIDePix.PostDeposit(AAmountInCents: Integer; AEndUserTaxNumber: string): string;
begin
  Result := PostDeposit(AAmountInCents, EmptyStr, EmptyStr, EmptyStr, AEndUserTaxNumber);
end;

function TAPIDePix.PostDeposit(AAmountInCents: Integer; ADepixAddress,
  ADepixSplitAddress, ASplitFee, AEndUserTaxNumber: string): string;
var
  LUrl: string;
  LBody: string;
{$IFDEF FPC}
  LJsonData: TJSONData;
  LJsonObject: TJSONObject;
{$ENDIF}
begin
(*
Example from API Doc (2026-06-01):
{
    "amountInCents": 100,
    "depixAddress": "ex1qhuq5u7udzwskhaz45fy80kdaxjytqd99ju5yfn",
    "endUserFullName": "Jasmine Lubowitz",
    "endUserTaxNumber": "22078522238",
    "depixSplitAddress": "ex1k981pd4bnsqph05gqwuk8kjsk56volzlqzmtnzwn",
    "splitFee": "2.99%",
    "delayDepixInHours": 24
}

amountInCents: integer - Amount in cents - write-only - required - Integer value in cents of reais. For R$ 1,00 for example: the number passed must be 100. >= 1 <= 10000000
depixAddress: string - write-only - optional - Optional DePix Address
depixSplitAddress: string - write-only - optional - Optional DePix Split Address
splitFee: string - write-only - optional - Optional Split Fee (the percentage of amountInCents that will be splitted and sent to depixSplitAddress)
euid: string - write-only - optional - End user EUID
endUserFullName: string - write-only - optional - End user full name
endUserTaxNumber: string - write-only - optional - End user tax number
whitelist: boolean - write-only - optional - Optional whitelist flag Default: false
delayDepixInHours: integer - write-only - optional - Optional number of hours to delay the DePix payment (min 1, max 720). If omitted, the payment is processed immediately.
merchantId: string - optional - EUID of the merchant.

Expected response on 2026-07-05
{
    "response": {
        "id": "019f3189de7c7bd8936f0bee33a8c8cb",
        "qrCopyPaste": "00020101021226790014br.gov.bcb.pix2557brcode.starkinfra.com/v2/49bca9d7179d4fa8970ea11b2c3e73395204000053039865802BR5909Transfero6014Rio de Janeiro62070503***630455D5",
        "qrImageUrl": "https://response.eulen.app/api-response/068db4cc-8847-48bc-bacc-20b1d481cae2-qr.png"
    },
    "async": false
}
*)

  // Differ from official Doc, personal decision to limit it from R$1,00+
  if (AAmountInCents < 100) or (AAmountInCents > 10000000) then
    raise Exception.Create('Invalid value [amount]');
  AEndUserTaxNumber := AEndUserTaxNumber.Trim;
  if
    (AEndUserTaxNumber.IsEmpty) or
    (AEndUserTaxNumber.Length < 11) or
    (AEndUserTaxNumber.Length > 14)
  then
    raise Exception.Create('Invalid value [endUserTaxNumber]');

  LUrl := Format('%s/%s', [CUrlApi, 'deposit']);
  LBody := EmptyStr;
{$IFDEF FPC}
  LJsonData :=  GetJSON('{}');
  try
    LJsonObject := LJsonData as TJSONObject;
    LJsonObject.Add('amountInCents', AAmountInCents);
    LJsonObject.Add('endUserTaxNumber', AEndUserTaxNumber);
    if not ADepixAddress.Trim.IsEmpty then
      LJsonObject.Add('depixAddress', ADepixAddress);
    if (not ADepixSplitAddress.Trim.IsEmpty) and (not ASplitFee.Trim.IsEmpty) then
    begin
      LJsonObject.Add('depixSplitAddress', ADepixSplitAddress);
      LJsonObject.Add('splitFee', FormatFloat('0.00', StrToFloat(ASplitFee)) + '%');
    end;
    if ALightning then
      LJsonObject.Add('lightning', ALightning);
    LBody := TJSONObject(LJsonData).AsJSON;
  finally
    LJsonData.Free;
  end;
{$ELSE}
  var
  LJSONObj := TJSONObject.Create;
  try
    LJSONObj.AddPair('amountInCents', AAmountInCents);
    LJSONObj.AddPair('endUserTaxNumber', AEndUserTaxNumber);
    if not ADepixAddress.Trim.IsEmpty then
      LJSONObj.AddPair('depixAddress', ADepixAddress);

    if (not ADepixSplitAddress.Trim.IsEmpty) and (not ASplitFee.Trim.IsEmpty) then
    begin
      LJSONObj.AddPair('depixSplitAddress', ADepixSplitAddress);
      LJSONObj.AddPair('splitFee', FormatFloat('0.00', ASplitFee.ToDouble) + '%');
    end;
    LBody := LJSONObj.ToString
  finally
    LJSONObj.Free;
  end;
{$ENDIF}
  Result := Post(LUrl, LBody);
end;

function TAPIDePix.XAsync: string;
begin
  Result := FXAsync;
end;

function TAPIDePix.XAsync(AValue: string): TAPIDePix;
begin
  Result := Self;
  FXAsync := AValue;
end;

function TAPIDePix.XNonce: string;
begin
  Result := FXNonce;
end;

function TAPIDePix.XNonce(AValue: string): TAPIDePix;
begin
  Result := Self;
  FXNonce := AValue;
end;

end.
