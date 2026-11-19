unit IdeaL.Lib.Api.Bitcoin.DIGPIX;

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
  /// <see cref="https://vempradig.com/merchant/api/docs"/>
  /// </remarks>
  TAPIDigPix = class(TIdeaLApi)
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
    function Get(AUrl: string): string; virtual;
    function Post(AUrl, ABody: string): string; virtual;
    { protected declarations }
  public
    const
    CUrlApi = 'https://vempradig.com/api/v1/pos/';
  public
    function AuthToken(AValue: string): TAPIDigPix; overload;
    function AuthToken: string; overload;

    /// <summary> To get all data from specific created QRCode
    /// </summary>
    /// <param name="AOrderId"> order_id, returned from PostQrCode
    /// </param>
    function GetQrCode(AOrderId: string): string;

    /// <summary> Creates the PIX to be paied in DePIX environment
    /// </summary>
    /// <param name="AAmount"> amount_cents, Valor em centavos (ex.: 1050 para R$ 10,50). Mínimo 500.
    /// </param>
    /// <param name="ADocument"> document,	CPF ou CNPJ do pagador (apenas números, 11 ou 14 dígitos).
    /// O QR Code gerado estará vinculado a este documento — apenas o titular conseguirá efetuar o pagamento.
    /// </param>
    /// <param name="APaymentMethod"> payment_method, Método de pagamento. Atualmente apenas "pix" (padrão).
    /// </param>
    /// <param name="AObservation"> observation, Observação do pedido (até 255 caracteres).
    /// </param>
    /// <param name="AWebHook"> webhook, URL para notificação de pagamento.
    /// </param>
    /// <param name="ASecret"> secret, Chave para assinar webhooks. Obrigatório se webhook informado (máx. 64 caracteres).
    /// </param>
    /// <returns> Returns a JSON Object with:
    /// id (from DePIX environment)
    /// qrCopyPaste: the copy paste PIX QRCode
    /// qrImageUrl: URL of the QRCode
    /// </returns>
    function PostQrCode(
      AAmount: Currency;
      const ADocument: string): string; overload;
    function PostQrCode(
      AAmount: Currency;
      const ADocument, APaymentMethod, AObservation, AWebHook, ASecret: string): string; overload;
    { public declarations }
  end;

implementation

{ TAPIDigPix }

function TAPIDigPix.AuthToken(AValue: string): TAPIDigPix;
begin
  Result := Self;
  FAuthToken := AValue;
end;

function TAPIDigPix.AuthToken: string;
begin
  Result := FAuthToken;
end;

{$IFDEF FPC}
procedure TAPIDigPix.GetNetHttpRequestLocal(
  out AHttpClient: TFPHttpClient;
  AOnData: TDataEvent = nil);
begin
  GetHttpRequest(AHttpClient, AOnData);
  AHttpClient.AddHeader('Content-Type', 'application/json');
  AHttpClient.AddHeader('Authorization', 'Bearer ' + FAuthToken);
end;
{$ELSE}

procedure TAPIDigPix.GetNetHttpRequestLocal(out ANetHttpClient: TNetHTTPClient;
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

function TAPIDigPix.Get(AUrl: string): string;
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
      LHttpClient.ConnectTimeout := 30000;
      LHttpClient.Get(AUrl, LResponse);
      if LHttpClient.ResponseStatusCode <> 200 then
        raise exception.create(LHttpClient.ResponseStatusText);
      Result := LResponse.Text;
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
      TNameValuePair.Create('X-API-Key', FAuthToken),
      TNameValuePair.Create('Content-Type', 'application/json; charset=utf-8'),
      TNameValuePair.Create('Accept', '*/*')
    ];

  LHttp := THTTPClient.Create;
  try
    LResponse := LHttp.Get(AUrl, nil, LHeader);
  finally
    FreeAndNil(LHttp);
  end;

  if LResponse.StatusCode <> 200 then
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

function TAPIDigPix.Post(AUrl, ABody: string): string;
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
  var
  LHeader: TNetHeaders;
  LHeader :=
    [
      TNameValuePair.Create('X-API-Key', FAuthToken),
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

  if LResponse.StatusCode <> 200 then
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

function TAPIDigPix.GetQrCode(AOrderId: string): string;
begin
  if (Trim(AOrderId).IsEmpty) then
    raise Exception.Create('Invalid value [qr_id]');

  var
  LUrl := Format('%s%s/%s', [CUrlApi, 'qrcode', AOrderId]);
  Result := Get(LUrl);
end;

function TAPIDigPix.PostQrCode(AAmount: Currency;
  const ADocument: string): string;
begin
  Result := PostQrCode(AAmount, ADocument, EmptyStr, EmptyStr, EmptyStr, EmptyStr);
end;

function TAPIDigPix.PostQrCode(AAmount: Currency;
  const ADocument, APaymentMethod, AObservation, AWebHook, ASecret: string): string;
var
  LUrl: string;
  LBody: string;
{$IFDEF FPC}
  LJsonData: TJSONData;
  LJsonObject: TJSONObject;
{$ENDIF}
begin
  (*
    All rules bellow were implemented based on official doc at 2026-07-01
    The PIX has 20min expiration time, this is not negotiable


    All rules bellow were implemented based on official doc at 2025-08-11

    The PIX has 10min expiration time, this is not negotiable
	
	2025-09-11
	WehBook will be requested when the PIX is paid and the BTC are sent properly.
	If some error happens, the PIX payment will be refunded automatically.
	
	WebHook specs:
	Secret comes in header
	BODY should be JSON Object as follow:
	{
    	"status": "PAID", # status of the PIX payment
    	"payment_id": "019885eefdd97fa190ec3e0821920844", # DePIX internal ID
    	"amount_brl": 10.50, # original BRL amount
    	"amount_btc": "0.00001234", # BTC amount sent to registered Address
    	"amount_sats": 1234 # BTC amount sent to registered Address
	}
  *)


  if (AAmount < 10) or (AAmount > 5000) then
    raise Exception.Create('Invalid value [amount]');
  AAmount := AAmount * 100;
  if (Trim(ADocument) = EmptyStr) or (
    (Length(ADocument) < 11) or (Length(ADocument) > 14)
  ) then
    raise Exception.Create('Invalid value [document]');
  if
    (Trim(AObservation) <> EmptyStr) and
    (Length(AObservation) > 255)
  then
    raise Exception.Create('Invalid value [observation]');
  if
    (Trim(AWebHook) <> EmptyStr) and
    ((not LowerCase(AWebHook).StartsWith('http')) or
    (Length(AWebHook) > 255))
  then
    raise Exception.Create('Invalid value [webhook]');
  if
    ((Trim(AWebHook) <> EmptyStr) and (Trim(ASecret) = EmptyStr)) or // Secret is mandatory when WebHook is present
    ((Trim(ASecret) <> EmptyStr) and
    (Length(ASecret) > 64))
  then
    raise Exception.Create('Invalid value [webhook]');

  LUrl := Format('%s%s', [CUrlApi, 'qrcode']);
  LBody := EmptyStr;
{$IFDEF FPC}
  LJsonData :=  GetJSON('{}');
  try
    LJsonObject := LJsonData as TJSONObject;
    LJsonObject.Add('amount_cents', Trunc(AAmount));
    LJsonObject.Add('document', ADocument);
    if Trim(APaymentMethod) <> EmtpyStr then
      LJSONObj.Add('payment_method', APaymentMethod);
    if Trim(AObservation) <> EmtpyStr then
      LJSONObj.Add('observation', AObservation);
    if Trim(AWebHook) <> EmtpyStr then
      LJSONObj.Add('webhook', AWebHook);
    if Trim(ASecret) <> EmtpyStr then
      LJSONObj.Add('secret', ASecret);
    LBody := TJSONObject(LJsonData).AsJSON;
  finally
    LJsonData.Free;
  end;
{$ELSE}
  var
  LJSONObj := TJSONObject.Create;
  try
    LJSONObj.AddPair('amount_cents', Trunc(AAmount));
    LJSONObj.AddPair('document', ADocument);
    if not APaymentMethod.Trim.IsEmpty then
      LJSONObj.AddPair('payment_method', APaymentMethod);
    if not AObservation.Trim.IsEmpty then
      LJSONObj.AddPair('observation', AObservation);
    if not AWebHook.Trim.IsEmpty then
      LJSONObj.AddPair('webhook', AWebHook);
    if not ASecret.Trim.IsEmpty then
      LJSONObj.AddPair('secret', ASecret);
    LBody := LJSONObj.ToString
  finally
    LJSONObj.Free;
  end;
{$ENDIF}
  Result := Post(LUrl, LBody);
end;

end.
