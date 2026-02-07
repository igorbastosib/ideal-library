unit IdeaL.Lib.SuperObject.Helper;

interface

uses
  XSuperObject,
  XSuperJSON,

{$IF defined(FMX)}
  FMX.Edit,
  FMX.Memo,
  FMX.Controls,
{$ELSEIF defined(VCL)}
  Vcl.StdCtrls,
  Vcl.Controls,
{$IFEND}

  System.Generics.Collections,
  System.SysUtils,
  System.StrUtils,
  System.Variants,
  System.JSON,

  REST.JSON
    ;

type
  TVarTypeArray = System.TArray<TVarType>;


type

  TSuperObjectHelper = class
  private
    class var
    FIndexTJSONDateManagerFormat: Integer;
    { Private declarations }
  public
    type
    ISuperObject = XSuperObject.ISuperObject;
    TSuperObject = XSuperObject.TSuperObject;
    ISuperArray = XSuperObject.ISuperArray;
    TSuperArray = XSuperObject.TSuperArray;
    IMember = XSuperObject.IMember;
    TMemberStatus = XSuperObject.TMemberStatus;
    ICast = XSuperObject.ICast;
    TSuperJsonConfig = XSuperJSON.TSuperJsonConfig;
    TDataType = XSuperJSON.TDataType;

    const
    varIntegerArray: TVarTypeArray = [varInteger, varUInt32, varInt64, varUInt64, varSingle];
    varCurrencyArray: TVarTypeArray = [varInteger, varUInt32, varInt64, varUInt64, varSingle, varDouble, varCurrency];

    class function SA(AJson: string = ''): ISuperArray;
    class function SO(const AJson: string = ''): ISuperObject;
    class function SOFromFile(const AFilePath: string): ISuperObject;
    class procedure SetNull(AObj: ISuperObject; AKey: string);

{$IF defined(FMX) or defined(VCL)}
    class procedure DataToScreen(ASObj: ISuperObject; ADic: TDictionary<TControl, string>); overload;
    class procedure DataToScreen(ASObj, AMetadata: ISuperObject; ADic: TDictionary<TControl, string>); overload;
    class function DataFromScreen(ASObjOrigem: ISuperObject; ADic: TDictionary<TControl, string>): ISuperObject;
{$ENDIF}

    class function SuperArrayGetItem(AJson: string; const AIndex: Integer): ISuperObject; overload;
    class function SuperArrayGetItem(ASAry: ISuperArray; const AIndex: Integer): ISuperObject; overload;

    /// <summary> Copy 1->2, Object2 should be the copied result one
    /// </summary>
    class procedure CopyA(AAry1, AAry2: ISuperArray; AForceField: Boolean = True);
    class procedure CopyO(AObj1: ISuperObject; AObj2: ISuperObject; AForceField: Boolean = True); overload;
    class procedure CopyO(AJson: string; AObj2: ISuperObject; AForceField: Boolean = True); overload;

    class function Contains(ASObj: ISuperObject; AKey: string): Boolean; overload;
    class function Contains(ASObj: ISuperObject; AKey: string; const ARaiseException: Boolean): Boolean; overload;
    class function Locate(ASObj: ISuperObject; AKey: string; AValue: Variant): Boolean; overload;
    class function Locate(ASObj: ISuperObject; AKey: string; AValue: Variant; const ARaiseException: Boolean): Boolean; overload;
    class function Locate(ASAry: ISuperArray; AKey: string; AValue: Variant): Boolean; overload;
    class function Locate(ASAry: ISuperArray; AKey: string; AValue: Variant; const ARaiseException: Boolean): Boolean; overload;

    /// <summary> Format to a pretty JSON format
    /// </summary>
    class function Formater(AJson: string): string;

    class procedure RemoveDateTimeFormater;
    { Public declarations }
  protected
    class procedure OnInitialization;
    { protected declarations }
  end;

implementation

uses
  IdeaL.Lib.Utils,
{$IF defined(FMX) or defined(VCL)}
  FMX.StdCtrls,
{$ENDIF}
  Data.DB;

{ TSuperObjectHelper }

class function TSuperObjectHelper.Contains(ASObj: ISuperObject; AKey: string;
  const ARaiseException: Boolean): Boolean;
begin
  Result := (ASObj.Contains(AKey)) and not(ASObj.Null[AKey] = jNull);
  if not Result and ARaiseException then
    TUtils.ThrowExceptionParamIsRequired(AKey);
end;

class function TSuperObjectHelper.Contains(ASObj: ISuperObject;
  AKey: string): Boolean;
begin
  Result := Contains(ASObj, AKey, True);
end;

class procedure TSuperObjectHelper.CopyA(AAry1, AAry2: ISuperArray;
  AForceField: Boolean);
var
  i: Integer;
begin
  for var LMember1 in AAry1 do
  begin
    case LMember1.DataType of
      dtObject:
        AAry2.Add(LMember1.AsObject);
      dtArray:
        AAry2.Add(LMember1.AsArray);
    else
      AAry2.Add(LMember1.AsVariant);
    end;

  end;
end;

class procedure TSuperObjectHelper.CopyO(AObj1: ISuperObject;
  AObj2: ISuperObject; AForceField: Boolean);

  procedure GetValue(var AItem1, AItem2: ISuperObject; ACurrentKey: string; AVarType: TVarType);
  begin
    case AVarType of
      varDate:
        AItem2.D[ACurrentKey] := AItem1.D[ACurrentKey];
      varString:
        AItem2.S[ACurrentKey] := AItem1.S[ACurrentKey];
      varInteger, varInt64, varUInt32:
        begin
          if not(AItem1.Null[ACurrentKey] = jNull) and
            (AItem1.GetType(ACurrentKey) = varBoolean)
          then
            AItem2.I[ACurrentKey] := AItem1.B[ACurrentKey].ToInteger
          else
          begin
            AItem2.I[ACurrentKey] := AItem1.I[ACurrentKey];
          end;
        end;
      varCurrency, varDouble:
        AItem2.F[ACurrentKey] := AItem1.F[ACurrentKey];
      varObject:
        begin
          StrToInt('1');
        end
    else
      AItem2.V[ACurrentKey] := AItem1.CurrentValue.AsVariant;
    end;
  end;

var
  LCurrentKey: string;
begin
  AObj1.First;
  while not AObj1.EoF do
  begin
    LCurrentKey := AObj1.CurrentKey;
    if LCurrentKey.Equals('HappensOn') then
      StrToInt('1');
    if AObj2.Contains(LCurrentKey) or
      (AForceField)
    then
    begin
      if AForceField then
      begin
        AObj2.Remove(LCurrentKey);
        case AObj1.GetType(LCurrentKey) of
          varObject:
            AObj2.O[LCurrentKey] := SO(AObj1.O[LCurrentKey].AsJSON);
          varArray:
            AObj2.A[LCurrentKey] := SA(AObj1.A[LCurrentKey].AsJSON);
        else
          AObj2.V[LCurrentKey] := AObj1.V[LCurrentKey];
        end;
      end
      else
      if (AObj2.Contains(LCurrentKey)) then
      begin
        if AObj2.Null[LCurrentKey] = jNull then
          GetValue(AObj1, AObj2, LCurrentKey, AObj1.GetType(LCurrentKey))
        else
          GetValue(AObj1, AObj2, LCurrentKey, AObj2.GetType(LCurrentKey));
      end;
    end;
    AObj1.Next;
  end;
end;

class procedure TSuperObjectHelper.CopyO(AJson: string; AObj2: ISuperObject;
  AForceField: Boolean);
var
  LSObj: ISuperObject;
begin
  LSObj := TSuperObjectHelper.SO(AJson);
  CopyO(LSObj, AObj2, AForceField);
end;

{$IF defined(FMX) or defined(VCL)}
class function TSuperObjectHelper.DataFromScreen(ASObjOrigem: ISuperObject;
  ADic: TDictionary<TControl, string>): ISuperObject;
var
  LAddValue: Boolean;
  LKey: TControl;
  LType: string;
  LSValue: string;
  LText: string;
  LInteger: Integer;
  LIndex: Integer;
  LDateTime: TDateTime;
  LTryDateTime: TDateTime;
  LDouble: Double;
  LDouble1: Double;
  LDouble2: Double;
begin
  Result := SO(EmptyStr);

  if not Assigned(ASObjOrigem) or not(Assigned(ADic)) then
    Exit;

  for LKey in ADic.Keys do
  begin
    if (Assigned(LKey)) and
      not(LKey.Hint.Trim.IsEmpty) and
      (ADic.TryGetValue(LKey, LType))
    then
    begin
      LText := EmptyStr;
      LSValue := VarToStr(ASObjOrigem.V[LKey.Hint.Trim]);

      if LKey.InheritsFrom(TEdit) then
        LText := TEdit(LKey).Text
      else if LKey.InheritsFrom(TCustomMemo) then
        LText := TCustomMemo(LKey).Lines.Text
      else if LKey.InheritsFrom(TLabel) then
        LText := TLabel(LKey).Text;

      if not LSValue.Equals(LText) then
      begin
        LAddValue := True;
        LIndex := AnsiIndexText(LType, ['C', 'D', 'DT', 'I', 'S', 'T']);
        case LIndex of
          0:
            begin
              if not LText.Trim.IsEmpty then
              begin
                if (TryStrToFloat(LText, LDouble)) then
                begin
                  LTryDateTime := 0;
                  if (TryStrToFloat(LSValue, LDouble)) then
                  begin
                    LTryDateTime := LDouble;
                  end
                  else
                    TryStrToDateTime(LSValue, LTryDateTime);

                  if LIndex = 1 then
                  begin
                    if Trunc(LDateTime) = Trunc(LTryDateTime) then
                      LAddValue := False;
                  end
                  else
                  begin
                    if LDateTime = LTryDateTime then
                      LAddValue := False;
                  end;
                end
                else
                  LAddValue := False;

                if LAddValue then
                begin
                  Result.F[LKey.Hint.Trim] := LDouble;
                end;
              end
              else
                Result.Null[LKey.Hint.Trim] := jNull;
            end;
          1, 2:
            begin
              if not LText.Trim.IsEmpty then
              begin
                if (TryStrToDateTime(LText, LDateTime)) then
                begin
                  LTryDateTime := 0;
                  if (TryStrToFloat(LSValue, LDouble)) then
                  begin
                    LTryDateTime := LDouble;
                  end
                  else
                    TryStrToDateTime(LSValue, LTryDateTime);

                  if LIndex = 1 then
                  begin
                    if Trunc(LDateTime) = Trunc(LTryDateTime) then
                      LAddValue := False;
                  end
                  else
                  begin
                    if LDateTime = LTryDateTime then
                      LAddValue := False;
                  end;
                end
                else
                  LAddValue := False;

                if LAddValue then
                begin
                  if LIndex = 1 then
                    Result.F[LKey.Hint.Trim] := Trunc(LDateTime)
                  else
                    Result.F[LKey.Hint.Trim] := LDateTime;
                end;
              end
              else
                Result.Null[LKey.Hint.Trim] := jNull;
            end;
          3:
            begin
              if (TryStrToInt(LText, LInteger)) then
              begin
                Result.i[LKey.Hint.Trim] := LInteger
              end;
            end;
          4:
            begin
              Result.S[LKey.Hint.Trim] := LText;
            end;
          5:
            begin
              if not LText.Trim.IsEmpty then
              begin
                if (TryStrToDateTime(LText, LDateTime)) then
                begin
                  LTryDateTime := 0;
                  if (TryStrToFloat(LSValue, LDouble)) then
                  begin
                    LTryDateTime := LDouble;
                  end
                  else
                    TryStrToDateTime(LSValue, LTryDateTime);

                  // Using double comparison was failing even with equal values
                  LDouble1 := (LDateTime - Trunc(LDateTime));
                  LDouble2 := LTryDateTime - Trunc(LTryDateTime);
                  if (FloatToStr(LDouble1) = FloatToStr(LDouble2)) then
                    LAddValue := False;
                end
                else
                  LAddValue := False;

                if LAddValue then
                begin
                  Result.F[LKey.Hint.Trim] := Frac(LDateTime);
                end;
              end
              else
                Result.Null[LKey.Hint.Trim] := jNull;
            end;
        end;
      end;
    end;
  end;
end;

class procedure TSuperObjectHelper.DataToScreen(ASObj: ISuperObject;
  ADic: TDictionary<TControl, string>);
begin
  DataToScreen(ASObj, nil, ADic);
end;

class procedure TSuperObjectHelper.DataToScreen(ASObj, AMetadata: ISuperObject;
  ADic: TDictionary<TControl, string>);

  procedure SetText(AKey: TControl; AValue: string);
  begin
    if AKey.InheritsFrom(TEdit) then
      TEdit(AKey).Text := AValue
    else if AKey.InheritsFrom(TLabel) then
      TLabel(AKey).Text := AValue
    else if AKey.InheritsFrom(TCustomMemo) then
      TCustomMemo(AKey).Lines.Text := AValue;
  end;

  procedure SetMaxLength(AKey: TControl; AMaxLength: Integer);
  begin
    if AKey.InheritsFrom(TEdit) then
      TEdit(AKey).MaxLength := AMaxLength
{$IFDEF FMX}
    else if AKey.InheritsFrom(TCustomMemo) then
      TCustomMemo(AKey).MaxLength := AMaxLength
{$ENDIF};
  end;

var
  LKey: TControl;
  LType: string;
  LSValue: string;
  LDateTime: TDateTime;
  LDouble: Double;
  LFieldTypeI: Integer;
  LVar: Variant;
begin
  if not Assigned(ASObj) or not(Assigned(ADic)) then
    Exit;

  for LKey in ADic.Keys do
  begin
    if (Assigned(LKey)) and not(LKey.Hint.Trim.IsEmpty) then
    begin
      if (ASObj.Contains(LKey.Hint.Trim)) and
        (ADic.TryGetValue(LKey, LType))
      then
      begin
        LVar := ASObj[LKey.Hint.Trim].AsVariant;
        LSValue := VarToStr(LVar);

        case AnsiIndexStr(UpperCase(LType), ['C', 'D', 'DT', 'I', 'S', 'T']) of
          0:
            begin
              if TryStrToFloat(LSValue, LDouble) then
                SetText(LKey, FormatFloat(FormatSettings.CurrencyString, LDouble))
              else
                SetText(LKey, '0');
            end;
          1:
            begin
              if not VarIsNull(LVar) then
              begin
                try
                  LDateTime := VarToDateTime(LVar);
                  SetText(LKey, FormatDateTime(FormatSettings.ShortDateFormat, LDateTime));
                except
                  SetText(LKey, EmptyStr);
                end;
              end
              else
                SetText(LKey, EmptyStr);
              { if TryStrToDateTime(LSValue, LDateTime) then
                LKey.Text := FormatDateTime(FormatSettings.ShortDateFormat, LDateTime)
                else
                LKey.Text := EmptyStr; }
            end;
          2:
            begin
              if not VarIsNull(LVar) then
              begin
                try
                  LDateTime := VarToDateTime(LVar);
                  SetText(LKey, FormatDateTime(FormatSettings.ShortDateFormat + ' ' + FormatSettings.LongTimeFormat, LDateTime));
                except
                  SetText(LKey, EmptyStr);
                end;
              end
              else
                SetText(LKey, EmptyStr);
            end;
          3, 4:
            begin
              SetText(LKey, LSValue);
            end;
          5:
            begin
              if not VarIsNull(LVar) then
              begin
                try
                  LDateTime := VarToDateTime(LVar);
                  SetText(LKey, FormatDateTime(FormatSettings.ShortTimeFormat, LDateTime));
                except
                  SetText(LKey, EmptyStr);
                end;
              end
              else
                SetText(LKey, EmptyStr);
            end;
        else
          SetText(LKey, EmptyStr);
        end;
      end;

      if (Assigned(AMetadata)) and
        (AMetadata.Contains(LKey.Hint.Trim))
      then
      begin
        LFieldTypeI := AMetadata.O[LKey.Hint].i['t'];
        case TFieldType(LFieldTypeI) of
          ftString:
            SetMaxLength(LKey, AMetadata.O[LKey.Hint].i['s']);
          ftInteger:
            SetMaxLength(LKey, 10);
        else
          SetMaxLength(LKey, 0);
        end;
      end;
    end;
  end;
end;
{$ENDIF}

class function TSuperObjectHelper.Formater(AJson: string): string;
var
  LJObj: TJSONObject;
  LJAry: TJSONArray;
begin
  if AJson.StartsWith('{') then
  begin
    LJObj := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
    try
      Result := LJObj.Format;
    finally
      FreeAndNil(LJObj);
    end;
  end
  else if AJson.StartsWith('[') then
  begin
    LJAry := TJSONArray.ParseJSONValue(AJson) as TJSONArray;
    try
      Result := LJAry.Format;
    finally
      FreeAndNil(LJAry);
    end;
  end;
end;

class function TSuperObjectHelper.Locate(ASObj: ISuperObject; AKey: string;
  AValue: Variant; const ARaiseException: Boolean): Boolean;
begin
  Result := False;

  ASObj.First;
  while not ASObj.EoF do
  begin
    if LowerCase(ASObj.CurrentKey).Equals(LowerCase(AKey)) then
    begin
      case ASObj.GetType(AKey) of
        varDate:
          Result := ASObj.D[AKey] = VarToDateTime(AValue);
        varString:
          Result := LowerCase(ASObj.S[AKey]).Equals(LowerCase(VarToStr(AValue)));
        varInteger:
          Result := ASObj.i[AKey] = AValue;
        varCurrency:
          Result := ASObj.F[AKey] = AValue;
      else
        Result := ASObj.V[AKey] = AValue;
      end;

      if Result then
        Break;
      if ASObj.CurrentValue.AsVariant = AValue then
      begin
        Result := True;
        Break;
      end;
    end;

    ASObj.Next;
  end;

  if not Result and ARaiseException then
    TUtils.ThrowExceptionCouldNotFindTheResource(AKey + ' = ' + AValue);
end;

class function TSuperObjectHelper.Locate(ASObj: ISuperObject; AKey: string;
  AValue: Variant): Boolean;
begin
  Result := Locate(ASObj, AKey, AValue, False);
end;

class procedure TSuperObjectHelper.OnInitialization;
begin
  FIndexTJSONDateManagerFormat := TJSONDateManager.Formats.Add(
    function(Str: String; var AValue: TDateTime; var Typ: TDataType): Boolean
    begin
      Result := False;
      AValue := 0;
      Typ := dtNil;

      if
        (Str.CountChar(FormatSettings.DateSeparator) = 2) or
        (Str.CountChar(FormatSettings.TimeSeparator) = 2)
      then
      begin
        // Check the default values first
        if TryStrToTime(Str, AValue) then
          Typ := dtTime
        else if TryStrToDate(Str, AValue) then
          Typ := dtDate
        else if TryStrToDateTime(Str, AValue) then
          Typ := dtDateTime;
        if Typ <> dtNil then
          Exit(True);
      end;

      if not Str.EndsWith(' ') then
      begin
        { there was a case of getting the value '21   ' and was considering as dtTime }
        var
        LFrmtStgs := TFormatSettings.Create('en-US');
        LFrmtStgs.ShortDateFormat := 'yyyy-mm-dd';
        LFrmtStgs.LongDateFormat := 'yyyy-mm-dd';
        LFrmtStgs.ShortTimeFormat := 'hh:nn';
        LFrmtStgs.LongTimeFormat := 'hh:nn:ss';
        LFrmtStgs.DateSeparator := '-';

        if
          (TryStrToDate(Str, AValue)) or
          (TryStrToDate(Str, AValue, LFrmtStgs))
        then
          Typ := dtDate
        else if
          (Str.Contains(LFrmtStgs.TimeSeparator)) and (
          (TryStrToTime(Str, AValue)) or
          (TryStrToTime(Str, AValue, LFrmtStgs))
          )
        then
          Typ := dtTime
        else if
          (Str.Contains(LFrmtStgs.DateSeparator)) and (
          (TryStrToDateTime(Str, AValue)) or
          (TryStrToDateTime(Str, AValue, LFrmtStgs))
          )
        then
          Typ := dtDateTime;
      end;
      Result := (Typ = dtTime) or (Typ = dtDate) or (Typ = dtDateTime);
    end);
end;

class procedure TSuperObjectHelper.RemoveDateTimeFormater;
begin
  if FIndexTJSONDateManagerFormat > -1 then
  begin
    var
    LIndex := FIndexTJSONDateManagerFormat;
    FIndexTJSONDateManagerFormat := -1;
    TJSONDateManager.Formats.Delete(LIndex);
  end;
end;

class function TSuperObjectHelper.SA(AJson: string): ISuperArray;
begin
  if not AJson.StartsWith('[') then // force it to become an array
    AJson := '[' + AJson + ']';
  var
  LJson : string := String(AJson);
  Result := XSuperObject.SA(AJson); //XSuperObject.TSuperArray.Create(LJson);
  // Result := TSuperObjectHelper.SO(AJson).AsArray;
end;

class procedure TSuperObjectHelper.SetNull(AObj: ISuperObject; AKey: string);
begin
  if AObj.Contains(AKey) then
    AObj.Null[AKey] := jNull;
end;

class function TSuperObjectHelper.SO(const AJson: string): ISuperObject;
begin
  Result := nil;
  try
    Result := XSuperObject.SO(AJson);
  except
    on E:Exception do
      TUtils.ThrowExceptionInvalidJsonValue(E.Message + ' - ' + AJson);
  end;
end;

class function TSuperObjectHelper.SOFromFile(
  const AFilePath: string): ISuperObject;
begin
  Result := XSuperObject.TSuperObject.ParseFile(AFilePath);
end;

class function TSuperObjectHelper.SuperArrayGetItem(AJson: string;
const AIndex: Integer): ISuperObject;
var
  LSAry: ISuperArray;
begin
  LSAry := TSuperObjectHelper.SA(AJson);
  Result := SuperArrayGetItem(LSAry, AIndex);
end;

class function TSuperObjectHelper.SuperArrayGetItem(ASAry: ISuperArray;
const AIndex: Integer): ISuperObject;
var
  LCast: ICast;
  i: Integer;
begin
  Result := nil;
  i := 0;
  if (AIndex < 0) or (AIndex > Pred(ASAry.Length)) then
    raise Exception.Create('List index out of bounds [TSuperObjectHelper.SuperArrayGetItem]');
  Result := ASAry.O[AIndex];
end;

{ class function TSuperObjectHelper.SuperIsFieldAssigned(ASObj: ISuperObject;
  AField: string): Boolean;
  begin
  Result := ASObj.Null[AField] = TMemberStatus.jAssigned;
  end; }

class function TSuperObjectHelper.Locate(ASAry: ISuperArray; AKey: string;
AValue: Variant; const ARaiseException: Boolean): Boolean;
begin
  Result := False;
  for var i := 0 to Pred(ASAry.Length) do
  begin
    Result := Locate(SuperArrayGetItem(ASAry, i), AKey, AValue, ARaiseException);
    if Result then
      Break;
  end;
end;

class function TSuperObjectHelper.Locate(ASAry: ISuperArray; AKey: string;
AValue: Variant): Boolean;
begin
  Result := Locate(ASAry, AKey, AValue, False);
end;

initialization

TSuperObjectHelper.OnInitialization;

end.