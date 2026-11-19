unit IdeaL.Lib.Api.Bitcoin.Exchange;
{******************************************************************************

******************************************************************************}
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
  /// <summary> General unit for general Exchange API requests
  /// create the specific unit if something changes
  /// </summary>
  { TAPIExchange }

  TAPIExchange = class(TIdeaLApi)
  private
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
    { public declarations }
  public
    function GetMemPoolSpacePrices: string;
    /// <param name="ACurrencyPair">Coinbase currency pair
    /// Possible values: BTC-USD, BTC-BRL, BTC-EUR
    /// </param>
    /// <remarks>
    /// Check the official documentation
    /// <see cref="https://docs.cdp.coinbase.com/coinbase-app/docs/api-prices#get-buy-price"/>
    /// </remarks>
    function GetCoinbasePricesBuy(ACurrencyPair: string): string;
    function GetCoinOSRates: string;
    function GetBinanceTicketPrice(ASymbol: string): string;
    { public declarations }
  end;

implementation

{$IFDEF FPC}
uses
  fpweb,
  openssl, { This implements the procedure InitSSLInterface }
  opensslsockets;
{$ENDIF}

{ TAPIExchange }

function TAPIExchange.Get(AUrl: string): string;
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
      // TNameValuePair.Create('Authorization', 'Bearer ' + FAuthToken),
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
    raise Exception.Create(LResponse.StatusCode.ToString + ' ' + LResponse.StatusText);
  Result := LResponse.ContentAsString(TEncoding.UTF8);
{$ENDIF}
end;

function TAPIExchange.GetMemPoolSpacePrices: string;
var
  LUrl: string;
begin
  LUrl := 'https://mempool.space/api/v1/prices';
  Result := Get(LUrl);
end;

function TAPIExchange.GetCoinbasePricesBuy(ACurrencyPair: string): string;
var
  LUrl: string;
begin
  LUrl := Format('https://api.coinbase.com/v2/prices/%s/buy', [ACurrencyPair]);
  Result := Get(LUrl);
end;

function TAPIExchange.GetCoinOSRates: string;
begin
  Result := Get('https://coinos.io/api/rates');
end;

function TAPIExchange.GetBinanceTicketPrice(ASymbol: string): string;
var
  LUrl: string;
begin
  LUrl := Format('https://api.binance.com/api/v3/ticker/price?symbol=%s', [ASymbol]);
  Result := Get(LUrl);
end;

{$IFDEF FPC}
procedure TAPIExchange.GetNetHttpRequestLocal(
  out AHttpClient: TFPHttpClient;
  AOnData: TDataEvent = nil);
begin
  GetHttpRequest(AHttpClient, AOnData);
  AHttpClient.AddHeader('Content-Type', 'application/json');
end;
{$ELSE}
procedure TAPIExchange.GetNetHttpRequestLocal(out ANetHttpClient: TNetHTTPClient;
  out ANetHttpRequest: TNetHTTPRequest; AOnSendDataEvent: TSendDataEvent;
  AOnReceiveData: TReceiveDataEvent);
begin
  GetNetHttpRequest(ANetHttpClient, ANetHttpRequest, AOnSendDataEvent, AOnReceiveData);
  ANetHttpClient.ContentType := 'application/json; charset=utf-8';
  ANetHttpClient.AcceptEncoding :='';

  ANetHttpClient.CustomHeaders['Content-Type'] := ANetHttpClient.ContentType;
  ANetHttpClient.CustomHeaders['Accept'] := ANetHttpClient.Accept;
end;
{$ENDIF}

function TAPIExchange.Post(AUrl, ABody: string): string;
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

end.
