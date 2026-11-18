unit Unit1;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation, FMX.StdCtrls, FMX.Edit, FMX.Layouts,
  FMX.Memo.Types, FMX.ScrollBox, FMX.Memo, FMX.TabControl, FMX.ListBox,
  FMX.Objects, FMX.DateTimeCtrls,

  IdeaL.Lib.Api.Bitcoin.CoinOS,
  IdeaL.Lib.Api.Bitcoin.LnurlPay,
  IdeaL.Lib.Bitcoin.Bolt11;

type
  TForm1 = class(TForm)
    Label1: TLabel;
    gbxLnInvoiceCreate: TGroupBox;
    Label2: TLabel;
    lblAmount: TLabel;
    edtInvoiceLNAmount: TEdit;
    btnInvoiceLNCreate: TButton;
    lytExportedToken: TLayout;
    Label5: TLabel;
    edtExportedToken: TEdit;
    Memo1: TMemo;
    lblGetInvoice: TLabel;
    edtGetInvoice: TEdit;
    btnCheckInvoice: TButton;
    TabControl1: TTabControl;
    tbiDemo: TTabItem;
    tbiInfo: TTabItem;
    Label3: TLabel;
    Label4: TLabel;
    Layout3: TLayout;
    lbxJson: TListBox;
    memBeautyJson: TMemo;
    lytBeutyJson: TLayout;
    Label6: TLabel;
    Splitter1: TSplitter;
    VertScrollBox1: TVertScrollBox;
    Label7: TLabel;
    Label10: TLabel;
    Label11: TLabel;
    gbxPayLnInvoice: TGroupBox;
    Label12: TLabel;
    Label14: TLabel;
    edtPayInvoice: TEdit;
    Label15: TLabel;
    edtMaxFee: TEdit;
    btnPay: TButton;
    edtInvoiceLNWebHook: TEdit;
    edtInvoiceLNSecret: TEdit;
    Label9: TLabel;
    Label13: TLabel;
    Label16: TLabel;
    Label17: TLabel;
    btnQrCodeFromInvoice: TButton;
    lytQrCodePic: TLayout;
    Layout2: TLayout;
    btnQrCodePicClose: TButton;
    rctQrCodePicBackground: TRectangle;
    lytQrCodePicBackground: TLayout;
    imgQrCode: TImage;
    btnRegister: TButton;
    Label18: TLabel;
    Label19: TLabel;
    edtPassword: TEdit;
    edtUsername: TEdit;
    btnLogin: TButton;
    lytAccount: TLayout;
    GroupBox1: TGroupBox;
    btnGetRates: TButton;
    gbxProfile: TGroupBox;
    btnGetMe: TButton;
    Label20: TLabel;
    edtProfileUsername: TEdit;
    Label21: TLabel;
    lblProfileBalanceSatoshi: TLabel;
    Label22: TLabel;
    cbxProfileCurrency: TComboBox;
    Label23: TLabel;
    edtProfilePictureUrl: TEdit;
    lblProfileBalanceFiat: TLabel;
    btnPostUser: TButton;
    HorzScrollBox1: THorzScrollBox;
    gbxGeneral: TGroupBox;
    Label24: TLabel;
    Label26: TLabel;
    dedtPaymentsFrom: TDateEdit;
    dedtPaymentsTo: TDateEdit;
    Label25: TLabel;
    Label27: TLabel;
    edtPaymentsLimit: TEdit;
    edtPaymentsOffset: TEdit;
    Label28: TLabel;
    btnGetPayments: TButton;
    Label8: TLabel;
    lytToken: TLayout;
    Label29: TLabel;
    lytTokenRo: TLayout;
    Label30: TLabel;
    edtTokenRo: TEdit;
    Label31: TLabel;
    btnPrivateDataShowHide: TButton;
    chkTokenRo: TCheckBox;
    lytTokenRoInfo: TLayout;
    gbxPayLnAddress: TGroupBox;
    Label32: TLabel;
    Label33: TLabel;
    edtPayLnAddressAddress: TEdit;
    Label34: TLabel;
    edtPayLnAddressAmount: TEdit;
    btnPayLnAddress: TButton;
    Label35: TLabel;
    edtPayLnAmountMaxFee: TEdit;
    Label36: TLabel;
    Layout1: TLayout;
    Label37: TLabel;
    edtXApiKey: TEdit;
    lblPayMemo: TLabel;
    edtPayMemo: TEdit;
    lblPayPin: TLabel;
    edtPayPin: TEdit;
    btnCheckPayment: TButton;
    lblPayLnAddressPin: TLabel;
    edtPayLnAddressPin: TEdit;
    gbxSafeLnAddress: TGroupBox;
    lblSafeHelp: TLabel;
    lblSafeAddress: TLabel;
    edtSafeAddress: TEdit;
    lblSafeAmount: TLabel;
    edtSafeAmount: TEdit;
    lblSafeComment: TLabel;
    edtSafeComment: TEdit;
    lblSafeFee: TLabel;
    edtSafeFee: TEdit;
    lblSafePin: TLabel;
    edtSafePin: TEdit;
    btnSafeResolve: TButton;
    btnSafeFetch: TButton;
    btnSafePay: TButton;
    btnSafeCheck: TButton;
    chkSafeSimulateTimeout: TCheckBox;
    lblSafeInfo: TLabel;
    procedure Label1Click(Sender: TObject);
    procedure btnInvoiceLNCreateClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure edtExportedTokenTyping(Sender: TObject);
    procedure btnCheckInvoiceClick(Sender: TObject);
    procedure lblAmountClick(Sender: TObject);
    procedure lblGetInvoiceClick(Sender: TObject);
    procedure btnPayClick(Sender: TObject);
    procedure Label4Click(Sender: TObject);
    procedure btnGetMeClick(Sender: TObject);
    procedure lbxJsonItemClick(const Sender: TCustomListBox;
      const Item: TListBoxItem);
    procedure Label17Click(Sender: TObject);
    procedure btnQrCodeFromInvoiceClick(Sender: TObject);
    procedure rctQrCodePicBackgroundClick(Sender: TObject);
    procedure btnGetRatesClick(Sender: TObject);
    procedure btnRegisterClick(Sender: TObject);
    procedure btnLoginClick(Sender: TObject);
    procedure btnPostUserClick(Sender: TObject);
    procedure btnPrivateDataShowHideClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btnGetPaymentsClick(Sender: TObject);
    procedure btnPayLnAddressClick(Sender: TObject);
    procedure btnCheckPaymentClick(Sender: TObject);
    procedure btnSafeResolveClick(Sender: TObject);
    procedure btnSafeFetchClick(Sender: TObject);
    procedure btnSafePayClick(Sender: TObject);
    procedure btnSafeCheckClick(Sender: TObject);
  private
    const
    CConfigFileName = 'config.json';
    // Never pay an invoice that expires within this margin (seconds)
    CExpiryMarginSec = 60;
    var
    // Three-step flow state. The pending invoice is also saved in config.json,
    // so that "4. Check status" still works after a crash or restart.
    FSafeRequest: TLnurlPayRequest;
    FSafeResolvedAddress: string;
    FPendingInvoice: string;

    function NewCoinOS: TAPICoinOS;
    procedure ShowSafeInfo(const AText: string);
    procedure ReportPaymentError(E: Exception);
    function DescribeInvoice(const AInvoice: TBolt11): string;

    procedure SaveData;
    procedure LoadData;

    procedure AddListBox(AJson: string);
    procedure AddLog(ALog: string);

    procedure QrCodePicHide;
    procedure QrCodePicShow;
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

uses
  System.JSON,
  System.IOUtils,
  System.Math,
  System.DateUtils,
  
  REST.JSON,

  System.Net.URLClient,
  System.Net.HttpClient,
  System.Net.HttpClientComponent,

  IdeaL.Lib.Utils,
  IdeaL.Lib.Api;

{$R *.fmx}


procedure TForm1.AddListBox(AJson: string);
begin
  lbxJson.Items.Insert(0, AJson);
end;

procedure TForm1.AddLog(ALog: string);
begin
  ALog := DateTimeToStr(Now) + ' - ' + ALog;
  Memo1.Lines.Insert(0, ALog);
end;

procedure TForm1.btnCheckInvoiceClick(Sender: TObject);
begin
  ShowMessage('Check method only works with CoinOS invoices');

  var
  LApiCoinOS := TAPICoinOS.Create;
  try
    LApiCoinOS.AuthToken(edtExportedToken.Text);
    var
    LResult := LApiCoinOS.GetInvoice(edtGetInvoice.Text);
    AddListBox(LResult);
    AddLog(LResult);
  finally
    LApiCoinOS.Free;
  end;
end;

procedure TForm1.btnGetMeClick(Sender: TObject);
begin
  var
  LResult := EmptyStr;
  var
  LApiCoinOS := TAPICoinOS.Create;
  try
    LApiCoinOS.AuthToken(edtExportedToken.Text);
    LResult := LApiCoinOS.GetMe;
  finally
    LApiCoinOS.Free;
  end;
  edtProfileUsername.TagString := LResult;

  AddListBox(LResult);
  AddLog(LResult);

  begin
    // Reading and showing the User details

    lblProfileBalanceSatoshi.Text := '0 sats';
    lblProfileBalanceFiat.Text := '0';

    var
    LJson := TJSONObject.ParseJSONValue(LResult);
    var
    LBalance : Int64 := 0;
    var
    LValueStr := EmptyStr;
    try
      LJson.TryGetValue<Int64>('balance', LBalance);
      LJson.TryGetValue<string>('username', LValueStr);
      edtProfileUsername.Text := LValueStr;
      LJson.TryGetValue<string>('picture', LValueStr);
      edtProfilePictureUrl.Text := LValueStr;
      LJson.TryGetValue<string>('currency', LValueStr);
      cbxProfileCurrency.ItemIndex := cbxProfileCurrency.Items.IndexOf(LValueStr);    
      if cbxProfileCurrency.ItemIndex = -1 then
      begin // Add currency in case the selected Currency is not in the Combobox
        cbxProfileCurrency.Items.Add(LValueStr);
        cbxProfileCurrency.ItemIndex := Pred(cbxProfileCurrency.Items.Count);
      end;
      if Assigned(cbxProfileCurrency.Selected) then
      begin
        lblProfileBalanceFiat.Text := '0 ' + cbxProfileCurrency.Selected.Text;

        // only convert to fiat if balance>0
        if LBalance > 0 then
        begin // retrive the CoinOS Bitcoin prices to show the fiat amount
          lblProfileBalanceSatoshi.Text := LBalance.ToString + ' sats';
          LApiCoinOS := TAPICoinOS.Create;
          try
            LResult := LApiCoinOS.GetRates;    
          finally
            LApiCoinOS.Free;
          end;

          var
          LJsonRates := TJSONObject.ParseJSONValue(LResult);
          var
          LPrice : Double := 0;
          try
            if LJsonRates.TryGetValue<Double>(cbxProfileCurrency.Selected.Text, LPrice) then
            begin // only if the selected currency was found in the JSON
              var
              LBalanceFiat : Double := 0;
              LBalanceFiat := 
                (LBalance / 100000000) // 1BTC = 100.000.000 satoshis
                * LPrice;
              LBalanceFiat := System.Math.RoundTo(LBalanceFiat, -3);
              lblProfileBalanceFiat.Text := LBalanceFiat.ToString + ' ' + cbxProfileCurrency.Selected.Text;
            end;
          finally
            LJsonRates.Free;
          end;
        end;
      end;
    finally
      FreeAndNil(LJson);
    end;
  end;
end;

procedure TForm1.btnGetPaymentsClick(Sender: TObject);
begin
  var
  LInt := 0;
  if not TryStrToInt(edtPaymentsLimit.Text, LInt) then
    edtPaymentsLimit.Text := '0';
  if not TryStrToInt(edtPaymentsOffset.Text, LInt) then
    edtPaymentsOffset.Text := '0';
  
  var
  LApiCoinOS := TAPICoinOS.Create;
  try
    if chkTokenRo.IsChecked then
      LApiCoinOS.AuthToken(edtTokenRo.Text)
    else
      LApiCoinOS.AuthToken(edtExportedToken.Text);
    var
    LResult := LApiCoinOS.GetPayments(dedtPaymentsFrom.Date, dedtPaymentsTo.Date, edtPaymentsLimit.Text.ToInteger, edtPaymentsOffset.Text.ToInteger);
    AddListBox(LResult);
    AddLog(LResult);
  finally
    LApiCoinOS.Free;
  end;
end;

procedure TForm1.btnGetRatesClick(Sender: TObject);
begin
  var
  LApiCoinOS := TAPICoinOS.Create;
  try
    var
    LResult := LApiCoinOS.GetRates;
    AddListBox(LResult);
    AddLog(LResult);
  finally
    LApiCoinOS.Free;
  end;
end;

function TForm1.NewCoinOS: TAPICoinOS;
begin
  Result := TAPICoinOS.Create;
  Result.AuthToken(edtExportedToken.Text);
end;

procedure TForm1.ReportPaymentError(E: Exception);
begin
  if E is EIdeaLApiError then
    // CoinOS answered: nothing was debited by this attempt
    AddLog('CoinOS refused (HTTP ' + EIdeaLApiError(E).StatusCode.ToString + '): ' +
      EIdeaLApiError(E).ResponseBody)
  else if TIdeaLApi.IsTransportError(E) then
    // no answer: the payment may or may not have happened
    AddLog('No answer from CoinOS (' + E.ClassName + '). The payment MAY have happened: ' +
      'wait a couple of minutes and check its status before trying again.')
  else
    AddLog(E.ClassName + ': ' + E.Message);
end;

procedure TForm1.btnPayClick(Sender: TObject);
begin
  // POST /payments: "fee" caps the routing fee (0 = let CoinOS use its quote),
  // "pin" is needed when the account has a PIN.
  var
  LApiCoinOS := NewCoinOS;
  try
    try
      var
      LResult := LApiCoinOS.PostPayment(edtPayInvoice.Text, StrToIntDef(edtMaxFee.Text, 0),
        edtPayMemo.Text, edtPayPin.Text);
      AddListBox(LResult);
      AddLog(LResult);
    except
      on E: Exception do
      begin
        ReportPaymentError(E);
        raise;
      end;
    end;
  finally
    LApiCoinOS.Free;
  end;
end;

procedure TForm1.btnCheckPaymentClick(Sender: TObject);
begin
  // GET /payments/:invoice is public; CoinOS answers "null" when there is no record
  var
  LApiCoinOS := NewCoinOS;
  try
    var
    LRecord := EmptyStr;
    case LApiCoinOS.GetPaymentState(edtPayInvoice.Text, LRecord) of
      psNone: AddLog('No payment record for this invoice (never paid, refused before the debit, or reversed).');
      psPending: AddLog('Payment in flight (confirmed = false). Check again later; do not pay again.');
      psPaid: AddLog('Paid (confirmed = true).');
    end;
    if not LRecord.IsEmpty then
      AddListBox(LRecord);
  finally
    LApiCoinOS.Free;
  end;
end;

procedure TForm1.btnPayLnAddressClick(Sender: TObject);
begin
  // One call: CoinOS resolves the address, fetches and pays the invoice.
  // The invoice is not known before money moves, so a failed call cannot be
  // checked afterwards. Use the "3 steps" box when the payment must be tracked.
  var
  LMaxFee := StrToIntDef(edtPayLnAmountMaxFee.Text, 0);
  var
  LAmount := StrToInt(edtPayLnAddressAmount.Text);
  var
  LApiCoinOS := NewCoinOS;
  try
    try
      var
      LResult := LApiCoinOS.PostPaymentLnAddress(edtPayLnAddressAddress.Text, LAmount, LMaxFee,
        edtPayLnAddressPin.Text);
      AddListBox(LResult);
      AddLog(LResult);
    except
      on E: Exception do
      begin
        ReportPaymentError(E);
        raise;
      end;
    end;
  finally
    LApiCoinOS.Free;
  end;
end;

{ Three-step payment of a Lightning address }

procedure TForm1.ShowSafeInfo(const AText: string);
begin
  lblSafeInfo.Text := AText;
  AddLog(AText);
end;

function TForm1.DescribeInvoice(const AInvoice: TBolt11): string;
begin
  Result := Format('Invoice: %d sats, expires %s (local time), payment hash %s...',
    [AInvoice.AmountSat,
     DateTimeToStr(TTimeZone.Local.ToLocalTime(AInvoice.ExpiresAtUtc)),
     Copy(AInvoice.PaymentHash, 1, 16)]);
  if AInvoice.HasDescription then
    Result := Result + ' Description: "' + AInvoice.Description + '".'
  else if AInvoice.MatchesMetadata(FSafeRequest.Metadata) then
    Result := Result + ' Description hash matches the address metadata.';
end;

procedure TForm1.btnSafeResolveClick(Sender: TObject);
begin
  // Step 1: GET https://<domain>/.well-known/lnurlp/<user> (LUD-16 / LUD-06)
  var
  LLnurl := TLnurlPay.Create;
  try
    FSafeRequest := LLnurl.Resolve(edtSafeAddress.Text);
    FSafeResolvedAddress := FSafeRequest.Address;
    AddListBox(FSafeRequest.RawJson);
    ShowSafeInfo(Format('%s accepts %d..%d sats. "%s". Comment up to %d characters. Step 2: fetch the invoice.',
      [FSafeRequest.Address, FSafeRequest.MinSendableSat, FSafeRequest.MaxSendableSat,
       FSafeRequest.Description, FSafeRequest.CommentAllowed]));
  finally
    LLnurl.Free;
  end;
end;

procedure TForm1.btnSafeFetchClick(Sender: TObject);
var
  LUser, LDomain: string;
begin
  // Step 2: GET <callback>?amount=<msat>, then decode and check the invoice
  if not TLnurlPay.ParseAddress(edtSafeAddress.Text, LUser, LDomain) or
     (LUser + '@' + LDomain <> FSafeResolvedAddress) then
    raise Exception.Create('Resolve the address first (step 1).');
  if not FPendingInvoice.IsEmpty then
    raise Exception.Create('There is a pending invoice. Check its status (step 4) before fetching a new one.');

  var
  LAmountMsat: Int64 := StrToInt64(edtSafeAmount.Text) * 1000;
  var
  LLnurl := TLnurlPay.Create;
  try
    // FetchInvoice already refuses an invoice whose amount differs from the request
    var
    LInvoiceText := LLnurl.FetchInvoice(FSafeRequest, LAmountMsat, edtSafeComment.Text);
    var
    LInvoice := TBolt11Decoder.Decode(LInvoiceText);
    if LInvoice.Network <> bnMainnet then
      raise Exception.Create('The invoice is not for Bitcoin mainnet; CoinOS cannot pay it.');
    if LInvoice.IsExpired(TTimeZone.Local.ToUniversalTime(Now), CExpiryMarginSec) then
      raise Exception.Create('The invoice expires too soon; fetch it again.');

    // Store the invoice BEFORE paying it
    FPendingInvoice := LInvoice.Invoice;
    SaveData;
    edtPayInvoice.Text := FPendingInvoice;
    ShowSafeInfo(DescribeInvoice(LInvoice) + ' Saved. Step 3: pay.');
  finally
    LLnurl.Free;
  end;
end;

procedure TForm1.btnSafePayClick(Sender: TObject);
begin
  // Step 3: POST /payments with the stored invoice. Paying the SAME invoice
  // again is refused by CoinOS, so retrying this step is safe; never replace
  // the invoice while it may still be paid.
  if FPendingInvoice.IsEmpty then
    raise Exception.Create('No pending invoice. Fetch one first (step 2).');
  var
  LInvoice := TBolt11Decoder.Decode(FPendingInvoice);
  if LInvoice.IsExpired(TTimeZone.Local.ToUniversalTime(Now), 30) then
    raise Exception.Create('The pending invoice has expired. Check its status (step 4) before fetching a new one.');

  var
  LApiCoinOS := NewCoinOS;
  try
    // Before paying again, make sure the previous attempt did not go through
    var
    LRecord := EmptyStr;
    case LApiCoinOS.GetPaymentState(FPendingInvoice, LRecord) of
      psPaid:
        begin
          ShowSafeInfo('Already paid. Nothing to do.');
          Exit;
        end;
      psPending:
        begin
          ShowSafeInfo('A payment of this invoice is in flight. Check its status later (step 4).');
          Exit;
        end;
    end;

    if chkSafeSimulateTimeout.IsChecked then
      LApiCoinOS.PaymentTimeout(1000);
    try
      var
      LResult := LApiCoinOS.PostPayment(FPendingInvoice, StrToIntDef(edtSafeFee.Text, 0),
        'LN address ' + FSafeResolvedAddress, edtSafePin.Text);
      AddListBox(LResult);
      ShowSafeInfo('CoinOS accepted the payment. Step 4 shows when it is confirmed.');
    except
      on E: Exception do
      begin
        ReportPaymentError(E);
        if E is EIdeaLApiError then
          ShowSafeInfo('CoinOS refused this attempt (nothing debited): ' + EIdeaLApiError(E).ResponseBody +
            '. Fix the cause and press 3 again; the same invoice is kept.')
        else
          ShowSafeInfo('No answer. The payment may have happened. Wait a couple of minutes, then press 4.');
      end;
    end;
  finally
    LApiCoinOS.Free;
  end;
end;

procedure TForm1.btnSafeCheckClick(Sender: TObject);
begin
  // Step 4: GET /payments/:invoice
  if FPendingInvoice.IsEmpty then
    raise Exception.Create('No pending invoice.');
  var
  LInvoice := TBolt11Decoder.Decode(FPendingInvoice);
  var
  LApiCoinOS := NewCoinOS;
  try
    var
    LRecord := EmptyStr;
    case LApiCoinOS.GetPaymentState(FPendingInvoice, LRecord) of
      psPaid:
        begin
          AddListBox(LRecord);
          ShowSafeInfo('Paid. The pending invoice was cleared.');
          FPendingInvoice := EmptyStr;
          SaveData;
        end;
      psPending:
        begin
          AddListBox(LRecord);
          ShowSafeInfo('In flight (confirmed = false). Check again later; do not pay again.');
        end;
      psNone:
        if LInvoice.IsExpired(TTimeZone.Local.ToUniversalTime(Now)) then
        begin
          ShowSafeInfo('No record and the invoice has expired: it can no longer be paid. ' +
            'The pending invoice was cleared; you may fetch a new one.');
          FPendingInvoice := EmptyStr;
          SaveData;
        end
        else
          ShowSafeInfo('No record yet. If no payment call is running, press 3 to retry with the SAME invoice. ' +
            DescribeInvoice(LInvoice));
    end;
  finally
    LApiCoinOS.Free;
  end;
end;

procedure TForm1.btnPostUserClick(Sender: TObject);
begin
  // Check changes
  var
  LJsonLogged := TJSONObject.ParseJSONValue(edtProfileUsername.TagString);
  var
  LJsonPost := TJSONObject.Create;
  var
  LJson := EmptyStr;
  try
    var
    LVarStr := EmptyStr;
    LJsonLogged.TryGetValue<string>('username', LVarStr);
    if (not LVarStr.Equals(edtProfileUsername.Text)) then
      LJsonPost.AddPair('username', edtProfileUsername.Text);
    LJsonLogged.TryGetValue<string>('picture', LVarStr);
    if (not LVarStr.Equals(edtProfilePictureUrl.Text)) then
      LJsonPost.AddPair('picture', edtProfilePictureUrl.Text);
    LJsonLogged.TryGetValue<string>('currency', LVarStr);
    if (Assigned(cbxProfileCurrency.Selected)) and (not LVarStr.Equals(cbxProfileCurrency.Selected.Text)) then
      LJsonPost.AddPair('currency', cbxProfileCurrency.Selected.Text);
    if LJsonPost.Count > 0 then
      LJson := LJsonPost.ToJSON;
  finally
    LJsonPost.Free;
    LJsonLogged.Free;
  end;

  // Apply changes
  if not LJson.IsEmpty then
  begin
    var
    LApiCoinOS := TAPICoinOS.Create;
    try
      LApiCoinOS.AuthToken(edtExportedToken.Text);
      var
      LResult := LApiCoinOS.PostUser(LJson);
      AddListBox(LResult);
      AddLog(LResult);
    finally
      LApiCoinOS.Free;
    end;
  end;
end;

procedure TForm1.btnPrivateDataShowHideClick(Sender: TObject);
begin
  var
  LBool := not edtPassword.Password;
  edtPassword.Password := LBool;
  edtExportedToken.Password := LBool;
  edtXApiKey.Password := LBool;
  edtTokenRo.Password := LBool;
end;

procedure TForm1.btnQrCodeFromInvoiceClick(Sender: TObject);
var
  HttpClient: THttpClient;
  HttpResponse: IHttpResponse;
begin

  // It's not related with CoinOS, it's just extra stuff
  // You must be showing an Invoice valid JSON on the Memo
  // Tap the ListBox lbxJson, the correct Invoice result to show it in the memo
  var
  LHashInvoice := EmptyStr;
  var
  LJson := TJSONObject.ParseJSONValue(memBeautyJson.Lines.Text);
  try
    if not LJson.TryGetValue<string>('hash', LHashInvoice) then
      raise Exception.Create('The JSON does not look like an Invoice');
  finally
    FreeAndNil(LJson);
  end;

  var
  LUrl := 'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=' + LHashInvoice;
  HttpClient := THttpClient.Create;
  try
    HttpResponse := HttpClient.Get(LUrl);

    var
    LStrm := HttpResponse.ContentStream;
    imgQrCode.Bitmap.LoadFromStream(LStrm);
    QrCodePicShow;
  finally
    HttpClient.Free;
  end;
end;

procedure TForm1.btnRegisterClick(Sender: TObject);
begin
  var
  LApiCoinOS := TAPICoinOS.Create;
  try    
    var
    LResult := LApiCoinOS.PostRegister(edtUsername.Text, edtPassword.Text);
    AddListBox(LResult);
    AddLog(LResult);
  finally
    LApiCoinOS.Free;
  end;  
end;

procedure TForm1.edtExportedTokenTyping(Sender: TObject);
begin
  SaveData;
end;

procedure TForm1.btnInvoiceLNCreateClick(Sender: TObject);
begin
  var
  LApiCoinOS := TAPICoinOS.Create;
  try
    if chkTokenRo.IsChecked then
      LApiCoinOS.AuthToken(edtTokenRo.Text)
    else
      LApiCoinOS.AuthToken(edtExportedToken.Text);
    var
    LAmount := StrToInt(edtInvoiceLNAmount.Text);
    var
    LResult := LApiCoinOS.PostInvoiceLightning(LAmount, edtInvoiceLNWebHook.Text, edtInvoiceLNSecret.Text);
    AddListBox(LResult);
    AddLog(LResult);
  finally
    LApiCoinOS.Free;
  end;
end;

procedure TForm1.btnLoginClick(Sender: TObject);
begin
  var
  LApiCoinOS := TAPICoinOS.Create;
  try    
    var
    LResult :=
      LApiCoinOS
      .HeaderArray([TAPICoinOS.THeaderPair.Create('x-api-key', edtXApiKey.Text)])
      .PostLogin(edtUsername.Text, edtPassword.Text);
    var
    LJSONObj := TJSONObject.ParseJSONValue(LResult) as TJSONObject;
    // edtExportedToken.OnTyping := False;
    try
      var
      LStr := EmptyStr;
      if LJSONObj.TryGetValue<string>('token', LStr) then
        edtExportedToken.Text := LStr;
    finally
      LJSONObj.Free;
    end;
    // To reset local logged user
    edtProfileUsername.TagString := EmptyStr;

    AddListBox(LResult);
    AddLog(LResult);

    // Token RO
    LApiCoinOS.AuthToken(edtExportedToken.Text);
    LResult := LApiCoinOS.GetRo;
    edtTokenRo.Text := LResult;
  finally
    LApiCoinOS.Free;
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  dedtPaymentsFrom.Date := IncMonth(Now, -1);
  dedtPaymentsTo.Date := Now;
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  LoadData;
  TabControl1.ActiveTab := tbiDemo;
  QrCodePicHide;
end;

procedure TForm1.Label17Click(Sender: TObject);
begin
  ShowMessage(
    'Fee cap = maximum Lightning routing fee in sats (0 = CoinOS uses its own route quote).' + sLineBreak +
    'A cap below the quote is refused before any debit ("Routing fee of X required").' + sLineBreak +
    'A cap above max(1000, 5% of the amount) is refused too.' + sLineBreak +
    'Accounts with a PIN must fill the PIN field.'
    );
end;

procedure TForm1.Label1Click(Sender: TObject);
begin
  TUtils.OpenUrl('https://coinos.io/docs');
end;

procedure TForm1.Label4Click(Sender: TObject);
begin
  TUtils.OpenUrl(TLabel(Sender).Hint);
end;

procedure TForm1.lblAmountClick(Sender: TObject);
begin
  ShowMessage('Use this to create your LN Invoice to be payed');
end;

procedure TForm1.lblGetInvoiceClick(Sender: TObject);
begin
  ShowMessage(
    'Use this check data from an invoice' + sLineBreak +
    'With this you can check if the Invoice was payed or not'
    );
end;

procedure TForm1.lbxJsonItemClick(const Sender: TCustomListBox;
  const Item: TListBoxItem);
begin
  var
  LJson := TJSONObject.ParseJSONValue(Item.Text);
  try
    memBeautyJson.Lines.Text := TJSON.Format(LJson);
  finally
    FreeAndNil(LJson);
  end;
end;

procedure TForm1.LoadData;
begin
  var
  LJson := EmptyStr;
  if FileExists(CConfigFileName) then
    LJson := TFile.ReadAllText(CConfigFileName);

  if LJson.Trim.IsEmpty then
    Exit;

  var
  LJSONObj := TJSONObject.ParseJSONValue(LJson) as TJSONObject;
  // edtExportedToken.OnTyping := False;
  try
    var
    LStr := EmptyStr;
    if LJSONObj.TryGetValue<string>('username', LStr) then
      edtUsername.Text := LStr;
    if LJSONObj.TryGetValue<string>('password', LStr) then
      edtPassword.Text := LStr;
    if LJSONObj.TryGetValue<string>('exportedToken', LStr) then
      edtExportedToken.Text := LStr;
    if LJSONObj.TryGetValue<string>('xapikey', LStr) then
      edtXApiKey.Text := LStr;
    if LJSONObj.TryGetValue<string>('roToken', LStr) then
      edtTokenRo.Text := LStr;
    if LJSONObj.TryGetValue<string>('pendingInvoice', LStr) then
      FPendingInvoice := LStr;
    if LJSONObj.TryGetValue<string>('pendingAddress', LStr) then
      edtSafeAddress.Text := LStr;
    if not FPendingInvoice.IsEmpty then
      lblSafeInfo.Text := 'There is a pending invoice from a previous run: press 4. Check status.';
  finally
    LJSONObj.Free;
  end;
end;

procedure TForm1.QrCodePicHide;
begin
  lytQrCodePicBackground.Visible := False;
end;

procedure TForm1.QrCodePicShow;
begin
  lytQrCodePicBackground.Visible := True;
  lytQrCodePicBackground.BringToFront;
end;

procedure TForm1.rctQrCodePicBackgroundClick(Sender: TObject);
begin
  QrCodePicHide;
end;

procedure TForm1.SaveData;
begin
  var
  LJSONObj := TJSONObject.Create;
  try
    LJSONObj.AddPair('username', edtUsername.Text);
    LJSONObj.AddPair('password', edtPassword.Text);
    LJSONObj.AddPair('exportedToken', edtExportedToken.Text);
    LJSONObj.AddPair('xapikey', edtXApiKey.Text);
    LJSONObj.AddPair('roToken', edtTokenRo.Text);
    // The PIN is never saved. The pending invoice is, so it can be checked after a restart.
    LJSONObj.AddPair('pendingInvoice', FPendingInvoice);
    LJSONObj.AddPair('pendingAddress', edtSafeAddress.Text);
    TFile.WriteAllText(CConfigFileName, LJSONObj.ToString);
  finally
    LJSONObj.Free;
  end;
end;

end.
