unit IdeaL.Lib.Api.Bitcoin.Alby;

{$IFDEF FPC}
{$mode objfpc}{$H+}
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
  System.DateUtils,

  System.Net.URLClient,
  System.Net.HttpClient,
  System.Net.HttpClientComponent,
  System.Net.Mime
{$ENDIF}
  ;

type
  /// <summary> Alby allows 2 kinds of implementations:
  /// 1 - OAuth2.0, normal OAuth2.0 opening the browser and etc
  /// 2 - Fixed token, you create a fixed Token on their WebSite and use it
  ///
  ///  !!!!!!!!!!!!!!!!!! This implementation is for 2nd option: Fixed token
  ///
  /// </summary>
  /// <remarks>
  /// Check the official documentation
  /// <see cref="https://guides.getalby.com/developer-guide/v/alby-wallet-api"/>
  /// </remarks>
  TAPIAlby = class(TIdeaLApi)
  private
    FAuthToken: string;
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
    function Del(AUrl: string): string; virtual;
    function Get(AUrl: string): string; virtual;
    function Post(AUrl, ABody: string): string; virtual;
    { protected declarations }
  public
    const
    CUrlApi = 'https://api.getalby.com';
    { public declarations }
  public
    /// <remarks>
    /// Alby allows you to select several scopes, make sure of doing it right
    /// <see cref="https://guides.getalby.com/developer-guide/v/alby-wallet-api/reference/authorization#scopes"/>
    /// </remarks>
    function AuthToken(AValue: string): TAPIAlby; overload;
    function AuthToken: string; overload;

    /// <summary> Get the user's e-mail address, display name, avatar,
    /// nostr pubkey, and value4value information
    /// </summary>
    function GetMe: string;
    /// <summary> Returns the balance, incoming/outgoing transaction count,
    /// boostagram count
    /// </summary>
    function GetBalance: string;
    /// <summary> Returns the user's Lightning Address and keysend information.
    /// </summary>
    function GetValue4Value: string;

    /// <summary> Register/Create a Lightning or Bitcoin invoice
    /// </summary>
    /// <param name="AType">lightning or bitcoin
    /// </param>
    /// <param name="AAmount">Price in Satothis
    /// </param>
    /// <param name="ADescription"> public description
    /// </param>
    /// <param name="AJson"> JSON Object, use this in case you need any other param
    /// </param>
    /// <remarks> Check the doc for the all params
    /// <see cref="https://guides.getalby.com/developer-guide/v/alby-wallet-api/reference/api-reference/invoices"/>
    /// </remarks>
    function PostInvoice(AAmount: Integer; ADescription: string = ''): string; overload;
    function PostInvoice(AJson: string): string; overload;

    /// <summary> Fetch an invoice by passing the invoice hash
    /// </summary>
    /// <param name="AValue">Lightning invoice hash
    /// </param>
    function GetInvoice(AValue: string): string;
    /// <summary> Lists all settled incoming invoices, including boostagram and LNURL metadata.
    /// </summary>
    /// <remarks>
    /// <see cref="https://guides.getalby.com/developer-guide/alby-wallet-api/reference/api-reference/invoices#get-incoming-invoice-history"/>
    function GetInvoiceIn(
      AStart: TDateTime = 0;
      AEnd: TDateTime = 0;
      AIsDateTimeInputUTC: Boolean = False): string;
    function GetInvoiceOut(
      AStart: TDateTime = 0;
      AEnd: TDateTime = 0;
      AIsDateTimeInputUTC: Boolean = False): string;

    /// <summary> Send a lightning payment
    /// </summary>
    function PostPaymentBolt11(AInvoice: string): string;

    /// <remarks>
    /// <see cref="https://guides.getalby.com/developer-guide/alby-wallet-api/reference/api-reference/webhook-endpoints"/>
    function DelWebWebHookById(AId: string): string;
    function GetWebWebHookById(AId: string): string;
    function PostWebWebHook(ADescription, AUrl: string; AFilterTypes: array of string): string;
    { public declarations }
  end;

implementation

{$IFDEF FPC}
uses
  DateUtils,
  openssl, { This implements the procedure InitSSLInterface }
  opensslsockets;
{$ENDIF}

{$IFDEF FPC}
{ Error message in the format of the Delphi branch: "<code> <text>", plus
  " - <body>" when AWithBody is True and the body is not blank. }
function FpcErrorMessage(AHttpClient: TFPHttpClient; const ABody: string;
  AWithBody: Boolean): string;
begin
  Result := IntToStr(AHttpClient.ResponseStatusCode) + ' ' + AHttpClient.ResponseStatusText;
  if AWithBody and (Trim(ABody) <> '') then
    Result := Result + ' - ' + ABody;
end;
{$ENDIF}

{ TAPIAlby }

function TAPIAlby.AuthToken: string;
begin
  Result := FAuthToken;
end;

function TAPIAlby.Del(AUrl: string): string;
{$IFDEF FPC}
var
  LHttpClient: TFPHttpClient;
  LResponse : TStringStream;
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
    LResponse := TStringStream.Create('');
    try
      // [] = TFPHttpClient does not check the status itself (its Get accepts
      // only 200): the check below decides, as in the Delphi branch
      LHttpClient.HTTPMethod('DELETE', AUrl, LResponse, []);
      if (LHttpClient.ResponseStatusCode < 200) or (LHttpClient.ResponseStatusCode > 299) then
        raise Exception.Create(FpcErrorMessage(LHttpClient, LResponse.DataString, False));
      Result := LResponse.DataString;
    finally
      LResponse.Free;
    end;
  finally
    LHttpClient.Free;
  end;
{$ELSE}
  var
  LHeader: TNetHeaders;
  LHeader :=
    [
      TNameValuePair.Create('Authorization', 'Bearer ' + FAuthToken),
      TNameValuePair.Create('Content-Type', 'application/json; charset=utf-8'),
      TNameValuePair.Create('Accept', '*/*')
    ];

  LHttp := THTTPClient.Create;
  try
    LResponse := LHttp.Delete(AUrl, nil, LHeader);
  finally
    FreeAndNil(LHttp);
  end;

  if (LResponse.StatusCode < 200) or (LResponse.StatusCode > 299) then
    raise Exception.Create(LResponse.StatusCode.ToString + ' ' + LResponse.StatusText);
  Result := LResponse.ContentAsString(TEncoding.UTF8);
{$ENDIF}
end;

function TAPIAlby.DelWebWebHookById(AId: string): string;
var
  LUrl: string;
begin
  LUrl := Format('%s/webhook_endpoints/%s', [CUrlApi, AId]);
  Result := Del(LUrl);
end;

function TAPIAlby.Get(AUrl: string): string;
{$IFDEF FPC}
var
  LHttpClient: TFPHttpClient;
  LResponse : TStringStream;
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
    LResponse := TStringStream.Create('');
    try
      // [] = TFPHttpClient does not check the status itself (its Get accepts
      // only 200): the check below decides, as in the Delphi branch
      LHttpClient.HTTPMethod('GET', AUrl, LResponse, []);
      if (LHttpClient.ResponseStatusCode < 200) or (LHttpClient.ResponseStatusCode > 299) then
        raise Exception.Create(FpcErrorMessage(LHttpClient, LResponse.DataString, False));
      Result := LResponse.DataString;
    finally
      LResponse.Free;
    end;
  finally
    LHttpClient.Free;
  end;
{$ELSE}
  var
  LHeader: TNetHeaders;
  LHeader :=
    [
      TNameValuePair.Create('Authorization', 'Bearer ' + FAuthToken),
      TNameValuePair.Create('Content-Type', 'application/json; charset=utf-8'),
      TNameValuePair.Create('Accept', '*/*')
    ];

  LHttp := THTTPClient.Create;
  try
    LResponse := LHttp.Get(AUrl, nil, LHeader);
  finally
    FreeAndNil(LHttp);
  end;

  if (LResponse.StatusCode < 200) or (LResponse.StatusCode > 299) then
    raise Exception.Create(LResponse.StatusCode.ToString + ' ' + LResponse.StatusText);
  Result := LResponse.ContentAsString(TEncoding.UTF8);
{$ENDIF}
end;

function TAPIAlby.GetBalance: string;
var
  LUrl: string;
begin
  LUrl := Format('%s/balance', [CUrlApi]);
  Result := Get(LUrl);
end;

function TAPIAlby.GetInvoice(AValue: string): string;
var
  LUrl: string;
begin
  LUrl := Format('%s/invoices/%s', [CUrlApi, AValue]);
  Result := Get(LUrl);
end;

function TAPIAlby.GetInvoiceIn(AStart, AEnd: TDateTime;
  AIsDateTimeInputUTC: Boolean): string;
var
  LUrl: string;
  LParams: string;
begin
  LParams := EmptyStr;
  if AStart > 0 then
    LParams := LParams + '&q[created_at_gt]=' + DateTimeToUnix(AStart, AIsDateTimeInputUTC).ToString;
  if AEnd > 0 then
    LParams := LParams + '&q[created_at_lt]=' + DateTimeToUnix(AEnd, AIsDateTimeInputUTC).ToString;
  if not LParams.Trim.IsEmpty then
    LParams := '?' + LParams.Trim(['&']);
  LUrl := Format('%s/invoices/incoming%s', [CUrlApi, LParams]);
  Result := Get(LUrl);
end;

function TAPIAlby.GetInvoiceOut(AStart, AEnd: TDateTime;
  AIsDateTimeInputUTC: Boolean): string;
var
  LUrl: string;
  LParams: string;
begin
  LParams := EmptyStr;
  if AStart > 0 then
    LParams := LParams + '&q[created_at_gt]=' + DateTimeToUnix(AStart, AIsDateTimeInputUTC).ToString;
  if AEnd > 0 then
    LParams := LParams + '&q[created_at_lt]=' + DateTimeToUnix(AEnd, AIsDateTimeInputUTC).ToString;
  if not LParams.Trim.IsEmpty then
    LParams := '?' + LParams.Trim(['&']);
  LUrl := Format('%s/invoices/outgoing%s', [CUrlApi, LParams]);
  Result := Get(LUrl);
end;

function TAPIAlby.GetMe: string;
var
  LUrl: string;
begin
  LUrl := Format('%s/user/me', [CUrlApi]);
  Result := Get(LUrl);
end;

{$IFDEF FPC}
procedure TAPIAlby.GetNetHttpRequestLocal(
  out AHttpClient: TFPHttpClient;
  AOnData: TDataEvent = nil);
begin
  GetHttpRequest(AHttpClient, AOnData);
  AHttpClient.AddHeader('Content-Type', 'application/json');
  AHttpClient.AddHeader('Authorization', 'Bearer ' + FAuthToken);
end;
{$ELSE}
procedure TAPIAlby.GetNetHttpRequestLocal(out ANetHttpClient: TNetHTTPClient;
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

function TAPIAlby.GetValue4Value: string;
var
  LUrl: string;
begin
  LUrl := Format('%s/user/value4value', [CUrlApi]);
  Result := Get(LUrl);
end;

function TAPIAlby.GetWebWebHookById(AId: string): string;
var
  LUrl: string;
begin
  LUrl := Format('%s/webhook_endpoints/%s', [CUrlApi, AId]);
  Result := Get(LUrl);
end;

function TAPIAlby.Post(AUrl, ABody: string): string;
{$IFDEF FPC}
var
  LHttpClient: TFPHttpClient;
  LResponse : TStringStream;
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
    LResponse := TStringStream.Create('');
    LHttpClient.RequestBody := TRawByteStringStream.Create(ABody);
    try
      // [] = TFPHttpClient does not check the status itself (its Get accepts
      // only 200): the check below decides, as in the Delphi branch
      LHttpClient.HTTPMethod('POST', AUrl, LResponse, []);
      if (LHttpClient.ResponseStatusCode < 200) or (LHttpClient.ResponseStatusCode > 299) then
        raise Exception.Create(FpcErrorMessage(LHttpClient, LResponse.DataString, True));
      Result := LResponse.DataString;
    finally
      LHttpClient.RequestBody.Free;
      LResponse.Free;
    end;
  finally
    LHttpClient.Free;
  end;
{$ELSE}
  var
  LHeader: TNetHeaders;
  LHeader :=
    [
      TNameValuePair.Create('Authorization', 'Bearer ' + FAuthToken),
      TNameValuePair.Create('Content-Type', 'application/json; charset=utf-8'),
      TNameValuePair.Create('Accept', '*/*')
    ];

  LHttp := THTTPClient.Create;
  var
  LStrm := TStringStream.Create(ABody, TEncoding.UTF8, False);
  try
    LStrm.Position := 0;
    LResponse := LHttp.Post(AUrl, LStrm, nil, LHeader);
  finally
    LStrm.Free;
    FreeAndNil(LHttp);
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

function TAPIAlby.PostInvoice(AJson: string): string;
var
  LUrl: string;
begin
  LUrl := Format('%s/%s', [CUrlApi, 'invoices']);
  Result := Post(LUrl, AJson);
end;

function TAPIAlby.PostPaymentBolt11(AInvoice: string): string;
var
  LUrl: string;
  LBody: string;
{$IFDEF FPC}
  LJsonData: TJSONData;
{$ENDIF}
begin
{$IFDEF FPC}
  LJsonData :=  GetJSON('{}');
  try
    TJSONObject(LJsonData).Add('invoice', AInvoice);
    LBody := TJSONObject(LJsonData).AsJSON;
  finally
    LJsonData.Free;
  end;
{$ELSE}
  var
  LJSONObj := TJSONObject.Create;
  try
    LJSONObj.AddPair('invoice', AInvoice);
    LBody := LJSONObj.ToString
  finally
    LJSONObj.Free;
  end;
{$ENDIF}
  LUrl := Format('%s/%s', [CUrlApi, 'payments/bolt11']);
  Result := Post(LUrl, LBody);
end;

function TAPIAlby.PostWebWebHook(ADescription, AUrl: string;
  AFilterTypes: array of string ): string;
var
  LUrl: string;
  LBody: string;
{$IFDEF FPC}
  LJsonData: TJSONData;
  LJsonArray: TJSONArray;
  I: Integer;
{$ENDIF}
begin
  if (AUrl.Trim.IsEmpty) or (Length(AFilterTypes) = 0) then
    raise Exception.Create('Parameters AUrl and AFilterTypes are mandatory');

{$IFDEF FPC}
  LJsonData :=  GetJSON('{}');
  try
    LJsonArray := TJSONArray.Create;
    for I := Low(AFilterTypes) to High(AFilterTypes) do
      LJsonArray.Add(AFilterTypes[I]);
    if not ADescription.Trim.IsEmpty then
      TJSONObject(LJsonData).Add('description', ADescription);
    TJSONObject(LJsonData).Add('url', AUrl);
    TJSONObject(LJsonData).Add('filter_types', LJsonArray);
    LBody := TJSONObject(LJsonData).AsJSON;
  finally
    LJsonData.Free;
  end;
{$ELSE}
  var
  LJSONObj := TJSONObject.Create;
  var
  LJSONAry := TJSONArray.Create;
  try
    for var i := Low(AFilterTypes) to High(AFilterTypes) do
    LJSONAry.Add(AFilterTypes[i]);

    if not ADescription.Trim.IsEmpty then
      LJSONObj.AddPair('description', ADescription);
    LJSONObj.AddPair('url', AUrl);
    LJSONObj.AddPair('filter_types', LJSONAry);
    LBody := LJSONObj.ToString
  finally
    LJSONObj.Free;
  end;
{$ENDIF}
  LUrl := Format('%s/%s', [CUrlApi, 'webhook_endpoints']);
  Result := Post(LUrl, LBody);
end;

function TAPIAlby.PostInvoice(AAmount: Integer; ADescription: string): string;

(*
Expected result

{
  "amount": 10,
  "boostagram": null,
  "comment": null,
  "created_at": "2024-08-18T09:50:32.745Z",
  "creation_date": 1723974632,
  "currency": "BTC",
  "custom_records": null,
  "description_hash": null,
  "destination_alias": "",
  "destination_pubkey": "030a58b8653d32b99200a2334cfe913e51dc7d155aa0116c176657a4f1722677a3",
  "expires_at": "2024-08-19T09:50:32.000Z",
  "expiry": 86400,
  "fiat_currency": "EUR",
  "fiat_in_cents": 1,
  "first_route_hint_alias": null,
  "first_route_hint_pubkey": null,
  "identifier": "t1KBeXNyjbMZWCFoaDPUhZMM",
  "keysend_message": null,
  "memo": null,
  "metadata": null,
  "payer_email": null,
  "payer_name": null,
  "payer_pubkey": null,
  "payment_hash": "ff0265427bdb90bd06e6c118d6cdca81d82993fa83db5ad4dafa067c7e2448b9",
  "payment_request": "lnbc100n1pnvrslgpp5lupx2snmmwgt6phxcyvddnw2s8vznyl6s0d444x6lgr8cl3yfzusdqqcqzzsxqyz5vqsp5ep09xpnyn5d2a957kluc5368eax657h98pe7sjtwwat3tzz0zass9qxpqysgqe0n2757fk9vpcsn6h0r0gfj996fvj8stm748atalf8pdw0kn0kg8kd4kvqjlqwyuv6s4tp9nhzkg2kn5xlu68a5swllzy5j38g98zvqpnf2fhp",
  "preimage": "fd9c36a3e5a80f82a10aec4a4231761cc73ad112c4689b707eb462859c77a639",
  "r_hash_str": "ff0265427bdb90bd06e6c118d6cdca81d82993fa83db5ad4dafa067c7e2448b9",
  "settled": true,
  "settled_at": "2024-08-18T09:51:12.000Z",
  "state": "SETTLED",
  "type": "incoming",
  "value": 10
}

*)

var
  LBody: string;
{$IFDEF FPC}
  LJsonData: TJSONData;
{$ENDIF}
begin
{$IFDEF FPC}
  LJsonData :=  GetJSON('{}');
  try
    TJSONObject(LJsonData).Add('amount', AAmount);
    if not ADescription.Trim.IsEmpty then
      TJSONObject(LJsonData).Add('description', ADescription);
    LBody := TJSONObject(LJsonData).AsJSON;
  finally
    LJsonData.Free;
  end;
{$ELSE}
  var
  LJSONObj := TJSONObject.Create;
  try
    LJSONObj.AddPair('amount', AAmount);
    if not ADescription.Trim.IsEmpty then
      LJSONObj.AddPair('description', ADescription);
    LBody := LJSONObj.ToString
  finally
    LJSONObj.Free;
  end;
{$ENDIF}
  Result := PostInvoice(LBody);
end;

function TAPIAlby.AuthToken(AValue: string): TAPIAlby;
begin
  Result := Self;
  FAuthToken := AValue;
end;

end.
