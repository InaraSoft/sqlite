unit sqlite3dac;

{$IFDEF FPC}
  {$MODE DELPHI}
  {$H+}
{$ENDIF}

interface

uses
  Classes, SysUtils, Db, Variants,
  rxmemds,
  sqlite3obj;

type

  { TSQLite3DB }

  TSQLite3DB = class(TComponent)
  private
    Stmt       : TSQLiteStmt;
    NextStmt   : PAnsiChar;
    FDb        : TSQLiteDB;
    FDbFile    : string;
    FInTrans   : Boolean;
    FUser      : string;
    FPwd       : string;
    FConnected : Boolean;
    procedure RaiseError(sMsg: string; sSQL: string);
  public
    property Connected: Boolean read FConnected;
    property DataBase: string read FDbFile write FDbFile;
    property UserName: string read FUser write FUser;
    property Password: string read FPwd write FPwd;
    procedure ExecSQL(const SQL: AnsiString);
    procedure Pragma(const SQL: AnsiString);
    procedure Open;
    procedure Close;
    procedure Connect;
    procedure Disconnect;
    procedure StartTransaction;
    procedure Commit;
    procedure Rollback;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

type

  { TSQLite3Query }

  TSQLite3Query = class(TRxMemoryData)
  private
    fDataBase     : TSQLite3DB;
    Stmt          : TSQLiteStmt;
    NextStmt      : PAnsiChar;
    fSQL          : string;
    fParams       : TParams;
    procedure Set_SQL(Value: string);
    procedure RaiseError(sMsg: string; sSQL: string);
  public
    property DataBase: TSQLite3DB read fDataBase write fDataBase;
    property Params: TParams read fParams write fParams;
    property SQL: string read fSQL write Set_SQL;
    procedure Open;
    procedure FetchParams;
    procedure Execute;
    procedure ExecSQL;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation

const
  ftDataTypes : array [0..22] of TFieldType =
     (ftString,  ftString, ftInteger, ftFloat, ftBoolean, ftDateTime,
      ftBlob, ftMemo, ftMemo, ftFloat, ftFloat, ftMemo,
      ftDateTime, ftDateTime, ftInteger, ftBoolean, ftCurrency, ftBlob,
      ftBoolean, ftBlob, ftCurrency, ftFloat, ftBoolean);

  ftDataNames : array [0..22] of string =
     ('VARCHAR', 'CHAR',  'INTEGER', 'FLOAT', 'BOOLEAN', 'DATETIME',
      'BLOB', 'MEMO', 'TEXT', 'NUMERIC', 'REAL', 'CLOB',
      'DATE', 'TIME', 'INT', 'LOGICAL', 'MONEY', 'IMAGE',
      'BOOL', 'GRAPHIC', 'CURRENCY', 'DEC', 'BOOLEAN');

const
  ftTypesOrdinals : array [0..22] of TFieldType =
     (ftString,  ftInteger, ftSmallInt, ftWord,       ftDateTime,
      ftDate,    ftTime,    ftFloat,    ftCurrency,   ftBoolean,
      ftBlob,    ftMemo,    ftGraphic,  ftWideString, ftBCD,
      ftAutoInc, ftOraBlob, ftOraClob,  ftVariant,    ftGuid,
      ftTypedBinary, ftLargeint, ftFixedChar);

  ftTypesNames : array [0..22] of String =
     ('String',    'Integer', 'SmallInt', 'Word',     'DateTime',
      'Date',      'Time',    'Float',    'Currency', 'Boolean',
      'Blob',      'Memo',    'Graphic',  'String',   'Float',
      'AutoInc',   'OraBlob', 'OraClob',  'Variant',  'Guid',
      'TypedBinary', 'Integer', 'String');

const
  SecPerDay   =  86400;
  Offset1970  =  25569;

//----------------------------------------------------------
function  FieldTypeToString(FieldType : TFieldType) : string;
var
  I : Integer;
begin
  for I := Low(ftTypesNames) to High(ftTypesNames) do begin
    if ftTypesOrdinals[I] = FieldType then begin
      if FieldType = ftAutoinc then
        Result := 'Integer'
      else
        Result := ftTypesNames[I];
      Exit;
    end;
  end;
  raise Exception.Create('Unsupported field type');
end;
//------------------------------------------------------------
function StringToFieldType(Token : string) : TFieldType;
var
  I : Integer;
begin
  Result := ftUnknown;
  for I := Low(ftTypesNames) to High(ftTypesNames) do begin
    if StrIComp(PChar(Token), PChar(ftTypesNames[I])) = 0 then begin
      Result := ftTypesOrdinals[I];
      Exit;
    end;
  end;
end;
//----------------------------------------------------------
function NameToFieldType(Token : string; var FieldSize: Integer) : TFieldType;
var
  i, k : Integer;
begin
  Result    := ftUnknown;
  Token     := TRIM(Token);
  FieldSize := 0;
  for I := Low(ftDataNames) to High(ftDataNames) do begin

    k := Pos('(', Token);
    if k > 0 then begin
      FieldSize := StrToInt(TRIM(Copy(Token, k + 1, Length(Token) - k - 1)));
      Token := TRIM(Copy(Token, 1, k -1));
    end; // if Pos('(', Token) > 0

    if StrIComp(PChar(Token), PChar(ftDataNames[I])) = 0 then begin
      Result := ftDataTypes[I];
      Exit;
    end; // if StrIComp(PChar(Token)

  end; // for I := Low(ftDataNames)

end;
//-----------------------------------------------------------
function UnixTimeToDateTime(UnixTime :  LongInt): TDateTime;
begin
  Result:= UnixTime / SecPerDay + Offset1970;
end;
//-----------------------------------------------------------
function DateTimeToUnixTime(DelphiDate: TDateTime): LongInt;
begin
  Result:= Trunc((DelphiDate - Offset1970) * SecPerDay);
end;
//-----------------------------------------------------------

{ TSQLite3Query }

procedure TSQLite3Query.Set_SQL(Value: string);
begin
  Self.Close;
  fSQL := Value;
  FetchParams;
end;

procedure TSQLite3Query.RaiseError(sMsg: string; sSQL: string);
var
  s       : string;
  iResult : Integer;
  Msg     : PAnsiChar;
begin
  iResult := sqlite3_errcode(fDataBase.fDB);
  if iResult <> SQLITE_OK then Msg := sqlite3_errmsg(fDataBase.fDB);

  if Msg <> nil then
    s := Format('Database response: ' + #13#10 + '%s' + #13#10 +
                'Command: ' + #13#10 + '%s' + #13#10 +
                'Details: ' + #13#10 + '%s',
                [SQLiteErrorStr(iResult), Trim(sSQL), Msg])
  else
    s := Format(sMsg + #13#10 + '%s' + #13#10 + '%s', [Trim(sSQL), 'No data available']);

  raise Exception.Create((s));
end;

procedure TSQLite3Query.Open;
var
  i           : Integer;
  iResult     : Integer;
  fParam      : TParam;

  iSize       : Integer;
  ptr         : Pointer;

  iNumBytes        : Integer;
  ThisBlobValue    : TMemoryStream;
  ActualColType    : Integer;

  fRowCount : Integer;
  fColCount : Integer;

  Field        : TField;
  FieldName    : string;
  FieldType    : TFieldType;
  DataTypeName : string;
  FieldSize    : Integer;
begin

  if fSQL = '' then begin
    inherited Open;
    Exit;
  end; // if FSQL = ''

  if not Assigned(Self.FDataBase) then begin
    RaiseError('Database not assigned', FSQL);
  end;

  if not Self.FDataBase.Connected then Self.FDataBase.Connect;
  DisableControls;
  inherited Close;
  Self.FieldDefs.Clear;
  Self.Tag := 1;

  try
    iResult := Sqlite3_Prepare_v2(FDataBase.FDB, PAnsiChar(FSQL), -1, Stmt, NextStmt);

    if iResult <> SQLITE_OK then begin
      sqlite3_reset(stmt);
      RaiseError('Query preparing error', FSQL);
    end; // if (iResult <> SQLITE_DONE)

    if (Stmt = nil) then begin
      RaiseError('SQL compilation error', FSQL);
    end; // if (Stmt = nil)

    iResult := sqlite3_clear_bindings(Stmt);

    if iResult <> SQLITE_OK then begin
      RaiseError('Parameters clearing error', FSQL);
    end; // if (Stmt = nil)

//----------------------------------------------
//Параметры
    for i := 0 to FParams.Count - 1 do begin
      fParam := FParams.Items[i];
      case fParam.DataType of
        ftTime,
        ftDate,
        ftDateTime: iResult := sqlite3_bind_int(Stmt, i + 1, DateTimeToUnixTime(fParam.AsDateTime));
        ftBoolean:  iResult := sqlite3_bind_int(Stmt, i + 1, StrToInt(BoolToStr(fParam.AsBoolean)));
        ftWord,
        ftInteger: begin
          iResult := sqlite3_bind_int(Stmt, i + 1, fParam.AsInteger);
        end; // ftInteger
        ftBCD,
        ftCurrency,
        ftFloat: begin
          iResult := sqlite3_bind_double(Stmt, i + 1, fParam.AsFloat);
        end; // ftFloat
        ftBlob: begin
          iSize := fParam.GetDataSize;
          GetMem(ptr, iSize);
          if (ptr = nil) then
            raise Exception.Create('Out of memory!');
          fParam.GetData(ptr);
          iResult := sqlite3_bind_blob(Stmt, i + 1, ptr, iSize, SQLITE_STATIC);
        end; // ftBlob
        ftMemo,
        ftOraClob,
        ftString: begin
          iResult := sqlite3_bind_text(Stmt, i + 1,
                     PAnsiChar(fParam.AsString), Length(fParam.AsString),
                     SQLITE_STATIC);
        end;
      end; // case fParam.DataType

      if iResult <> SQLITE_OK then
        RaiseError('Ошибка установки параметров', FSQL);

    end; // for i := 0 to FParams.Count
//----------------------------------------------

    fRowCount := 0;

    iResult := Sqlite3_step(Stmt);

    repeat // until iResult = SQLITE_DONE;
      case iResult of
        SQLITE_ROW,
        SQLITE_DONE: begin
          Inc(fRowCount);
          if (fRowCount = 1) then begin // получить структуру
            fColCount := sqlite3_column_count(stmt);
            for i := 0 to Pred(fColCount) do begin
              FieldName     := AnsiUpperCase(sqlite3_column_name(stmt, i));
              ActualColType := sqlite3_column_type(stmt, i);
              DataTypeName  := AnsiUpperCase(sqlite3_column_decltype(stmt, i));
              if DataTypeName = '' then begin
                case ActualColType of
                  1: begin
                    DataTypeName := 'INTEGER';
                  end;
                  2: begin
                    DataTypeName := 'FLOAT';
                  end;
                  3: begin
                    DataTypeName := 'TEXT';
                  end;
                  4: begin
                    DataTypeName := 'BLOB';
                  end;
                  5: begin
                    DataTypeName := 'VARCHAR(250)';
                  end;
                end; // case ActualColType
              end; // if DataTypeName = ''
              FieldSize     := 0;
              FieldType     := NameToFieldType(DataTypeName, FieldSize);
              FieldDefs.Add(FieldName, FieldType, FieldSize, FALSE);
            end; // for i := 0 to Pred(fColCount)
            inherited Open;
          end; // if (fRowCount = 1)

          //Если есть записи
          if iResult = SQLITE_ROW then begin
            inherited Append;
            for i := 0 to Fields.Count - 1 do begin
              Field := Fields[i];
              ActualColType := sqlite3_column_type(stmt, i);
              if ActualColType <> SQLITE_NULL then begin
                case Fields[i].DataType of
                  ftInteger: begin
                      Field.AsInteger := sqlite3_column_int64(stmt, i);
                  end; // ftInteger

                  ftFloat: begin
                      Field.AsFloat := sqlite3_column_double(stmt, i);
                  end; // ftFloat

                  ftBoolean: begin
                      Field.AsBoolean := StrToBool(IntToStr(sqlite3_column_int64(stmt, i)));
                  end; // ftBoolean

                  ftDateTime: begin
                      Field.AsDateTime := UnixTimeToDateTime(sqlite3_column_int64(stmt, i));
                  end; // ftDateTime

                  ftBlob: begin
                      ThisBlobValue    := TMemoryStream.Create;
                      iNumBytes        := sqlite3_column_bytes(stmt, i);
                      ptr              := sqlite3_column_blob(stmt, i);
                      ThisBlobValue.WriteBuffer(ptr^, iNumBytes);
                      ThisBlobValue.Position  := 0;
                      TBlobField(Field).LoadFromStream(ThisBlobValue);
                      ThisBlobValue.Free;
                  end; // ftBlob

                  ftMemo,
                  ftString: begin
                      Field.AsString := sqlite3_column_text(stmt, i);
                  end; // ftString
                end; // case Fields[i].DataType
              end; // if ActualColType <> SQLITE_NULL
            end; // for i := 0 to Fields.Count
            inherited Post;
          end; // if iResult = SQLITE_ROW

        end; // SQLITE_ROW

        SQLITE_BUSY: begin
          RaiseError('Database locked', FSQL);
        end; // SQLITE_BUSY
        else begin
          SQLite3_reset(stmt);
          RaiseError('Ошибка извлечения данных запроса', FSQL);
        end; // else
      end; // case iResult

      iResult := sqlite3_step(Stmt);

    until iResult = SQLITE_DONE;

    Self.First;

  finally
    if Assigned(Stmt) then sqlite3_finalize(stmt);
    Self.Tag := 0;
    EnableControls;
  end; // try
end;

procedure TSQLite3Query.FetchParams;
begin
  fParams.Clear;
  fParams.ParseSQL(Copy(TRIM(fSQL), 1, Length(TRIM(fSQL))), TRUE);
end;

procedure TSQLite3Query.Execute;
var
  s       : string;
  i       : Integer;
  iResult : Integer;
  MyParam : TParam;
  iSize   : Integer;
  ptr     : Pointer;
begin
  if not Assigned(Self.FDataBase) then begin
    RaiseError('Database not assigned', FSQL);
  end;
  if not FDataBase.Connected then FDataBase.Connect;

  try
    iResult := Sqlite3_Prepare_v2(FDataBase.FDB, PAnsiChar(FSQL), -1, Stmt, NextStmt);

    if iResult <> SQLITE_OK then begin
      sqlite3_reset(stmt);
      RaiseError('Ошибка подготовки запроса', FSQL);
    end; // if (iResult <> SQLITE_DONE)

    if (Stmt = nil) then begin
      RaiseError('Ошибка компиляции SQL', FSQL);
    end; // if (Stmt = nil)

    iResult := sqlite3_clear_bindings(Stmt);

    if iResult <> SQLITE_OK then begin
      RaiseError('Ошибка очистки параметров', FSQL);
    end; // if (Stmt = nil)

//Параметры
    for i := 0 to fParams.Count - 1 do begin
      MyParam := fParams.Items[i];
      case MyParam.DataType of
        ftBoolean: iResult := sqlite3_bind_int(Stmt, i + 1, StrToInt(BoolToStr(MyParam.AsBoolean)));
        ftWord,
        ftInteger: begin
          iResult := sqlite3_bind_int(Stmt, i + 1, MyParam.AsInteger);
        end; // ftInteger
        ftDate,
        ftTime,
        ftDateTime: begin
          iResult := sqlite3_bind_int(Stmt, i + 1, DateTimeToUnixTime(MyParam.AsDateTime));
        end;
        ftBCD,
        ftCurrency,
        ftFloat: begin
          iResult := sqlite3_bind_double(Stmt, i + 1, MyParam.AsFloat);
        end; // ftFloat
        ftBlob: begin
          iSize := MyParam.GetDataSize;
          GetMem(ptr, iSize);
          if (ptr = nil) then
            RaiseError('Недостаточно памяти для завершения операции!', FSQL);
          MyParam.GetData(ptr);
          iResult := sqlite3_bind_blob(Stmt, i + 1, ptr, iSize, SQLITE_STATIC);
        end; // ftBlob
        ftMemo,
        ftOraClob,
        ftString: begin
          iResult := sqlite3_bind_text(Stmt, i + 1,
                     PAnsiChar(MyParam.AsString), Length(MyParam.AsString),
                     SQLITE_STATIC);
        end;
      end; // case MyParam.DataType

      if iResult <> SQLITE_OK then begin
        RaiseError('Ошибка установки параметров', FSQL);
      end; // if iResult <> SQLITE_OK

    end; // for i := 0 to AParams.Count

    iResult := sqlite3_step(Stmt);

    if (iResult <> SQLITE_DONE) then begin
      sqlite3_reset(stmt);
      RaiseError('Ошибка выполнения запроса', FSQL);
    end; // if (iResult <> SQLITE_DONE)

  finally
    if Assigned(Stmt) then sqlite3_finalize(stmt);
  end;
end;

procedure TSQLite3Query.ExecSQL;
begin
  Execute;
end;

constructor TSQLite3Query.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  fParams := TParams.Create;
end;

destructor TSQLite3Query.Destroy;
begin
  fParams.Free;
  inherited Destroy;
end;

//-----------------------------------------------------------

{ TSQLite3DB }

procedure TSQLite3DB.Disconnect;
var
  s : string;
  iResult : Integer;
begin

  iResult := SQLite3_Close(Fdb);

  if iResult <> SQLITE_OK then begin
    if Assigned(Fdb) then begin
      s := 'Ошибка закрытия подключения к базе данных';
      RaiseError(s, FDbFile);
    end else
      s := 'Неустановленная ошибка закрытия подключения к базе данных';
      RaiseError(s, FDbFile);
  end; // if iResult <> SQLITE_OK

  FConnected := FALSE;
  FDbFile    := '';
  FPwd       := '';

end;

constructor TSQLite3DB.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDbFile    := '';
  FUser      := 'admin';
  FPwd       := '';
  FConnected := FALSE;
  FInTrans   := FALSE;
end;

destructor TSQLite3DB.Destroy;
begin
  FDb := nil;
  inherited Destroy;
end;

procedure TSQLite3DB.ExecSQL(const SQL: AnsiString);
var
  iResult  : integer;
begin
  try
    if sqlite3_prepare_v2(FDB, PAnsiChar(SQL), -1, Stmt, NextStmt) <>
      SQLITE_OK then RaiseError('Ошибка выполнения SQL', SQL);
      
    if (Stmt = nil) then RaiseError('Ошибка компиляции SQL', SQL);

    iResult := sqlite3_step(Stmt);

    if (iResult <> SQLITE_DONE) then begin
      sqlite3_reset(stmt);
      RaiseError('Ошибка выполнения команды SQL', SQL);
    end;

  finally
    if Assigned(Stmt) then sqlite3_finalize(stmt);
  end; // try
  
end;

procedure TSQLite3DB.Pragma(const SQL: AnsiString);
begin
   sqlite3_prepare_v2(FDB, PAnsiChar(SQL), -1, Stmt, NextStmt);
end;

procedure TSQLite3DB.Open;
begin
  Connect;
end;

procedure TSQLite3DB.Close;
begin
  Disconnect;
end;

procedure TSQLite3DB.Connect;
var
  s : string;
  iResult : Integer;
begin
  iResult := sqlite3_open(PAnsiChar(FDbFile), Fdb);

  if iResult <> SQLITE_OK then begin
    if Assigned(Fdb) then begin
      s := 'Ошибка подключения к базе данных';
      RaiseError(s, FDbFile);
    end else
      s := 'Неустановленная ошибка подключения к базе данных';
      RaiseError(s, FDbFile);
  end; // if iResult <> SQLITE_OK

  if TRIM(FPwd) <> '' then Self.ExecSQL('PRAGMA key=' + FPwd);
  Self.ExecSQL('PRAGMA foreign_keys=ON');
  Self.ExecSQL('PRAGMA encoding = "UTF-8"');
  Self.Pragma('PRAGMA journal_mode=MEMORY');
  //Self.Pragma('PRAGMA locking_mode=EXCLUSIVE');

  try
    Self.ExecSQL('select [name] from sqlite_master where 1<>1');
    FConnected := TRUE;
  except
    on E:Exception do begin
      FConnected := FALSE;
      s := 'Файл базы данных поврежден или зашифрован!';
      RaiseError(s, FDbFile);
    end;
  end; // try

end;

procedure TSQLite3DB.RaiseError(sMsg: string; sSQL: string);
var
  s       : string;
  Msg     : PAnsiChar;
  iResult : Integer;
begin
  Msg := nil;
  iResult := sqlite3_errcode(fDB);
  if iResult <> SQLITE_OK then Msg := sqlite3_errmsg(fDB);
  if Msg <> nil then
    s := Format('Database response: ' + #13#10 + '%s' + #13#10 +
                'Command: ' + #13#10 + '%s' + #13#10 +
                'Details: ' + #13#10 + '%s',
                [SQLiteErrorStr(iResult), Trim(sSQL), Msg])
  else
    s := Format(sMsg + #13#10 + '%s' + #13#10 + '%s', [Trim(sSQL), 'No data available']);
  raise Exception.Create((s));
end;

procedure TSQLite3DB.StartTransaction;
begin
  if not FInTrans then begin
    ExecSQL('BEGIN TRANSACTION');
    FInTrans := TRUE;
  end; 
end;

procedure TSQLite3DB.Commit;
begin
  if FInTrans then begin
    ExecSQL('COMMIT');
    FInTrans := FALSE;
  end;
end;

procedure TSQLite3DB.Rollback;
begin
  if FInTrans then begin
    ExecSQL('ROLLBACK');
    FInTrans := FALSE;
  end;
end;

end.
