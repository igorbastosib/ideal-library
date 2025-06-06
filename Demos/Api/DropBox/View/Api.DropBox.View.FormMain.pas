unit Api.DropBox.View.FormMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.TabControl,
  FMX.StdCtrls, FMX.Controls.Presentation,

  // Necessary uses
  System.Math, // to be used on DownloadUploadStatusUpdate  and validate the division by zero
  System.Net.HttpClient, // To create the CallBack procedure DownloadUploadRequestCompletedEvent
  System.Permissions, FMX.Memo.Types, FMX.ScrollBox, FMX.Memo, FMX.Edit //
    ;

type
  TFormMain = class(TForm)
    TabControl1: TTabControl;
    TabItem1: TTabItem;
    TabItem2: TTabItem;
    btnCreateFolder: TButton;
    btnDelete: TButton;
    btnDownload: TButton;
    btnDownloadRange: TButton;
    btnListFolder: TButton;
    btnUpload: TButton;
    Memo1: TMemo;
    btnV2ListFolder: TButton;
    memoResult: TMemo;
    btnV2Download: TButton;
    ProgressBar1: TProgressBar;
    AniIndicator1: TAniIndicator;
    Label1: TLabel;
    edtAccessToken: TEdit;
    Label2: TLabel;
    edtFolderPath: TEdit;
    Label3: TLabel;
    edtFileName: TEdit;
    procedure btnUploadClick(Sender: TObject);
    procedure btnDownloadClick(Sender: TObject);
    procedure btnV2ListFolderClick(Sender: TObject);
    procedure edtAccessTokenTyping(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
  var
    FUpdationProgressbar: Boolean;
    FSenderTapped: TObject;

    function GetLocalFilePath: string;

    procedure DisplayRationale(Sender: TObject; const APermissions: TArray<string>; const APostRationaleProc: TProc); overload;
    procedure GrantedPermissionRequestResult(Sender: TObject; const APermissions: TArray<string>; const AGrantResults: TArray<TPermissionStatus>); overload;
    // D11
{$IF CompilerVersion >= 35.0}
    procedure DisplayRationale(Sender: TObject; const APermissions: TClassicStringDynArray; const APostRationaleProc: TProc); overload;
    procedure GrantedPermissionRequestResult(Sender: TObject; const APermissions: TClassicStringDynArray; const AGrantResults: TClassicPermissionStatusDynArray); overload;
{$IFEND}

    procedure DownloadUploadStatusUpdate(const ALength, ACount: Int64);
    procedure DownloadUploadRequestCompletedEvent(const Sender: TObject; const AResponse: IHTTPResponse);

    procedure ThreadShowMessage(const AMsg: string);
    procedure ThreadEnableButton(ABtn: TButton);

    procedure LoadingShow;
    procedure LoadingHide;

    procedure ProgressBarInitialize;

    procedure Download(Sender: TObject);

    procedure ConfigLoad;
    procedure ConfigSave;
    { Private declarations }
  public
    { Public declarations }
  end;

var
  FormMain: TFormMain;

implementation

uses
  IdeaL.Lib.Api.DropBox,
  IdeaL.Lib.Utils,

  System.JSON,
  System.IOUtils,

  {
    Uses to request permission, PLEASE do that in your own way
  }
{$IFDEF ANDROID}
  Androidapi.Helpers,
  Androidapi.JNI.JavaTypes,
  Androidapi.JNI.Os,
{$ENDIF}
  FMX.DialogService,
  System.Generics.Collections;
{$R *.fmx}

{ TFormMain }

procedure TFormMain.btnDownloadClick(Sender: TObject);
var
  LReadExternalStorage: string;
  LWriteExternalStorage: string;
begin
  FSenderTapped := Sender;
{$IFDEF ANDROID}
  LReadExternalStorage := JStringToString(TJManifest_permission.JavaClass.READ_EXTERNAL_STORAGE);
  LWriteExternalStorage := JStringToString(TJManifest_permission.JavaClass.WRITE_EXTERNAL_STORAGE);
{$ENDIF}
  PermissionsService.RequestPermissions([
    LReadExternalStorage,
    LWriteExternalStorage
    ],
    GrantedPermissionRequestResult,
    DisplayRationale
    );
end;

procedure TFormMain.btnUploadClick(Sender: TObject);
var
  LPathLocal: string;
  LPathRemote: string;
  LDb: TDropBoxApi;
  LJson: string;
begin
  FSenderTapped := Sender;
  ProgressBarInitialize;
  LPathLocal := GetLocalFilePath;
  LPathLocal := TUtils.Combine(LPathLocal, [edtFileName.Text]);
  LPathRemote := '/' + edtFileName.Text.Trim(['/', '\']);
  LDb := TDropBoxApi.Create;
  try
    LDb.AccessToken := edtAccessToken.Text;

    if Sender = btnUpload then
    begin
      if not(FileExists(LPathLocal)) then
        raise Exception.Create('File doesn''t exist');

      LDb.Upload(LPathLocal, LPathRemote)
    end
    else if Sender = btnDelete then
    begin
      {
        You can delete files or paths;

        If the file doesn't exists or can't be deleted, it will return Conflict
      }

      LPathRemote := '/' + 'FolderHasBeenCreated';
      LDb.Delete(LPathRemote);
    end
    else if Sender = btnListFolder then
    begin
      {
        There is many params, look on the documentation to understand why they are for;

        The result is a JSON, so good luck
      }
      LPathRemote := '';
      LJson := LDb.ListFolder(LPathRemote);
    end
    else if Sender = btnCreateFolder then
    begin
      {
        If the path already exists, it will return Conflict
      }

      LPathRemote := '/' + 'FolderHasBeenCreated';
      LDb.CreateFolder(LPathRemote)
    end
      ;
  finally
    FreeAndNil(LDb);
  end;
end;

procedure TFormMain.btnV2ListFolderClick(Sender: TObject);
begin
  var
  LDv2 := TDropBoxApiV2.Create;
  try
    var
    LJson := LDv2.
      SetAccessToken(edtAccessToken.Text).
      ListFiles(edtFolderPath.Text);
    var
    JsonValue := TJSONObject.ParseJSONValue(LJson) as TJSONObject;
    if Assigned(JsonValue) then
    try
      memoResult.Lines.Text := JsonValue.Format(4);
    finally
      JsonValue.Free;
    end

  finally
    LDv2.Free;
  end;
end;

procedure TFormMain.ConfigLoad;
begin
  if not FileExists('config.json') then
    Exit;
  var
  LStrLst := TStringList.Create;
  try
    var
    LStrValue := EmptyStr;
    LStrLst.LoadFromFile('config.json');
    var
    LJsonValue := TJSONObject.ParseJSONValue(LStrLst.Text);
    try
      if LJsonValue.TryGetValue<string>('AccessToken', LStrValue) then
        edtAccessToken.Text := LStrValue;
      if LJsonValue.TryGetValue<string>('FlderPath', LStrValue) then
        edtFolderPath.Text := LStrValue;
      if LJsonValue.TryGetValue<string>('FileName', LStrValue) then
        edtFileName.Text := LStrValue;
    finally
      LJsonValue.Free;
    end
  finally
    LStrLst.Free;
  end;
end;

procedure TFormMain.ConfigSave;
begin
  var
  LStrLst := TStringList.Create;
  try
    var
    LJsonValue := TJSONObject.ParseJSONValue('{}') as TJSONObject;
    try
      LJsonValue.AddPair('AccessToken', edtAccessToken.Text );
      LJsonValue.AddPair('FlderPath', edtFolderPath.Text );
      LJsonValue.AddPair('FileName', edtFileName.Text );
      LStrLst.Text := LJsonValue.ToString;
    finally
      LJsonValue.Free;
    end;
    LStrLst.SaveToFile('config.json');
  finally
    LStrLst.Free;
  end;
end;

procedure TFormMain.DisplayRationale(Sender: TObject;
  const APermissions: TArray<string>; const APostRationaleProc: TProc);
begin
  // Show an explanation to the user *asynchronously* - don't block this thread waiting for the user's response!
  // After the user sees the explanation, invoke the post-rationale routine to request the permissions
  TDialogService.ShowMessage('Your Message Here',
    procedure(const AResult: TModalResult)
    begin
      APostRationaleProc;
    end);
end;

{$IF CompilerVersion >= 35.0}
procedure TFormMain.DisplayRationale(Sender: TObject;
const APermissions: TClassicStringDynArray; const APostRationaleProc: TProc);
begin
  // Show an explanation to the user *asynchronously* - don't block this thread waiting for the user's response!
  // After the user sees the explanation, invoke the post-rationale routine to request the permissions
  TDialogService.ShowMessage('Your Message Here',
    procedure(const AResult: TModalResult)
    begin
      APostRationaleProc;
    end);
end;

procedure TFormMain.GrantedPermissionRequestResult(Sender: TObject;
const APermissions: TClassicStringDynArray;
const AGrantResults: TClassicPermissionStatusDynArray);
begin
  Download(FSenderTapped);
end;
{$IFEND}

procedure TFormMain.Download(Sender: TObject);
begin
  // Thread is not exactly necessary
  ProgressBarInitialize;
  TControl(Sender).Enabled := False;
  LoadingShow;
  TThread.CreateAnonymousThread(
    procedure
    var
      LPathLocal: string;
      LPathRemote: string;
      LDb: TDropBoxApi;
    begin
      LPathLocal := GetLocalFilePath;
      LPathLocal := TUtils.Combine(LPathLocal, [edtFileName.Text]);

      if FileExists(LPathLocal) then
        DeleteFile(LPathLocal);

      LPathRemote := edtFolderPath.Text + edtFileName.Text;
      try
        try  if Trim(TControl(Sender).Name).Contains('V2') then
          begin
            var
            LDb2 := TDropBoxApiV2.Create;
            try
              LDb2.
                SetAccessToken(edtAccessToken.Text).
                SetOnDownloadStatusUpdate(DownloadUploadStatusUpdate).
                SetOnRequestCompletedEvent(DownloadUploadRequestCompletedEvent).
                Download(LPathLocal, LPathRemote);
            finally
              LDb2.Free;
            end;
          end
          else
          begin
            LDb := TDropBoxApi.Create;
            try
              try
                LDb.AccessToken := edtAccessToken.Text;

                // This will work just with Thread
                LDb.OnDownloadStatusUpdate := DownloadUploadStatusUpdate;
                LDb.OnRequestCompletedEvent := DownloadUploadRequestCompletedEvent;
                if Sender = btnDownloadRange then
                  LDb.DownloadRange(LPathLocal, LPathRemote)
                else
                  LDb.Download(LPathLocal, LPathRemote);
              except
                on E: Exception do
                  ThreadShowMessage(E.Message);
              end;
            finally
              FreeAndNil(LDb);
            end;
          end;
        except
          on E:Exception do
          begin
            var
            LErrorMsg := E.Message;
            TThread.ForceQueue(nil,
              procedure
              begin
                ShowMessage(LErrorMsg);
              end)
          end;
        end;
      finally
        ThreadEnableButton(Sender as TButton);
        LoadingHide;
      end;
    end).Start;
end;

procedure TFormMain.DownloadUploadRequestCompletedEvent(const Sender: TObject;
const AResponse: IHTTPResponse);
begin
  // Synchronize is necessary just if you are using Threads
  TThread.Synchronize(nil,
    procedure
    begin
      {
        Do whatever you want.
        You can do something here or you can just wait for the exception, please, make sure to use TryExcept
      }
      if (AResponse.StatusCode < 200) or (AResponse.StatusCode > 299) then
        ShowMessage(AResponse.StatusText)
      else
        ShowMessage('Well done ;)');
    end);
end;

procedure TFormMain.DownloadUploadStatusUpdate(const ALength, ACount: Int64);
begin
  if not FUpdationProgressbar then
  begin
    FUpdationProgressbar := True;
    try
      // Synchronize is necessary just if you are using Threads
      TThread.ForceQueue(nil,
        procedure
        begin
          {
            Unfortunately, Upload has no Lenght, to fix it, you can do it manually, do your way to get the file length use it here
          }
          ProgressBar1.Value := (ACount / System.Math.IfThen(ALength = 0, 1, ALength)) * 100;
        end);
    finally
      FUpdationProgressbar := False;
    end;
  end;
end;

procedure TFormMain.edtAccessTokenTyping(Sender: TObject);
begin
  ConfigSave;
end;

procedure TFormMain.FormShow(Sender: TObject);
begin
  ConfigLoad;
  LoadingHide;
end;

function TFormMain.GetLocalFilePath: string;
begin
  {
    Doesn't matter how you'll do that, it's not my problem
  }
  Result := TUtils.GetApplicationPath;
{$IFDEF MSWINDOWS}
  Result := TUtils.RemovePathFromDir(Result, 3);
  Result := TUtils.Combine(Result, ['File']);
{$ENDIF}
end;

procedure TFormMain.GrantedPermissionRequestResult(Sender: TObject;
const APermissions: TArray<string>;
const AGrantResults: TArray<TPermissionStatus>);
begin
  TButton(Sender).OnClick(Sender);
end;

procedure TFormMain.LoadingHide;
begin
  TThread.Synchronize(nil,
    procedure
    begin
      AniIndicator1.Enabled := False;
      AniIndicator1.Visible := False;
    end);
end;

procedure TFormMain.LoadingShow;
begin
  TThread.Synchronize(nil,
    procedure
    begin
      AniIndicator1.Visible := True;
      AniIndicator1.Enabled := True;
    end);
end;

procedure TFormMain.ProgressBarInitialize;
begin
  FUpdationProgressbar := False;
  ProgressBar1.Value := 0;
end;

procedure TFormMain.ThreadEnableButton(ABtn: TButton);
begin
  TThread.Synchronize(nil,
    procedure
    begin
      ABtn.Enabled := True;
    end);
end;

procedure TFormMain.ThreadShowMessage(const AMsg: string);
begin
  TThread.Synchronize(nil,
    procedure
    begin
      ShowMessage(AMsg);
    end);
end;

end.
