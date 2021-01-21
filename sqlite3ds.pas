unit sqlite3ds;

{$MODE DELPHI}
{$H+}

interface

uses
  classes, sysutils, db, variants,
  sqlite3dac,
  un_functions,
  un_sql,
  un_memds;

type

  TSQLiteDB    = class(TSQLite3DB);
  TSQLiteQuery = class(TSQLite3Query);

  { TSQLiteDS }

  TSQLiteDS = class(TMemTable)
  private
    fTable    : string;
    fKeyField : string;
    fSQL      : TStringList;
    fParams   : TParams;
    fQuery    : TSQLite3Query;
    fBuffer   : TMemTable;
    fDb       : TSQLiteDB;
    procedure DoPost(DataSet: TDataSet);
    procedure DoDelete(DataSet: TDataSet);
    procedure DoBeforeEdit(DataSet: TDataSet);
    procedure CopyStructure(DataSet: TDataSet);
    procedure SetDataBase(Value: TSQLiteDB);
  public
    property DataBase: TSQLiteDB read fDb write SetDataBase;
    property Table: string read fTable write fTable;
    property KeyField: string read fKeyField write fKeyField;
    property SQL: TStringList read fSQL write fSQL;
    property Params: TParams read fParams write fParams;
    procedure FetchParams;
    procedure Open;
    procedure Execute;
    constructor Create(AOwner: TComponent);
    destructor Destroy;
  end;

implementation

{ TSQLiteDS }

procedure TSQLiteDS.DoPost(DataSet: TDataSet);
var
  s     : string;
  i     : integer;
  fParam : TParam;
  fField : TField;
begin
  if Tag <> 0 then Exit;
  if fTable = '' then Exit;
  if fKeyField = '' then Exit;
  if not (DataSet.State in [dsInsert, dsEdit]) then Exit;
  try
    case DataSet.State of
      dsInsert: s := BuildInsert(DataSet, fTable);
      dsEdit:   s := BuildUpdate(DataSet, fBuffer, fTable, fKeyField);
    end;
    if s = '' then Exit;
    fQuery.Close;
    fQuery.SQL.Text := s;
    fQuery.FetchParams;
    for i := 0 to fQuery.Params.Count - 1 do begin
      fParam := fQuery.Params[i];
      fField := DataSet.FindField(fParam.Name);
      case fField.DataType of
        ftBoolean    : fParam.AsBoolean  := fField.AsBoolean;
        ftWord,
        ftSmallInt,
        ftLargeInt,
        ftInteger    : fParam.AsInteger  := fField.AsInteger;
        ftTime,
        ftDate,
        ftDateTime   : fParam.AsDateTime := fField.AsDateTime;
        ftMemo,
        ftWideString,
        ftString     : fParam.AsString   := fField.AsString;
        else           fParam.Value      := fField.Value;
      end; // case fParams[i].DataType
    end;
    fQuery.Execute;
    fQuery.DataBase.Commit;
    fBuffer.EmptyTable;
  except
    on E:Exception do begin
      s := E.Message;
      ShowError(s);
      Abort;
    end;
  end;
end;

procedure TSQLiteDS.DoDelete(DataSet: TDataSet);
var
  s : string;
  i : integer;
  fParam : TParam;
  fField : TField;
begin
  if Tag <> 0 then Exit;
  if fTable = '' then Exit;
  if fKeyField = '' then Exit;
  try
    s := 'delete from ' + fTable + ' where ' + fKeyField + '=:' + fKeyField;
    fQuery.Close;
    fQuery.SQL.Text := s;
    fQuery.FetchParams;
    for i := 0 to fQuery.Params.Count - 1 do begin
      fParam := fQuery.Params[i];
      fField := DataSet.FindField(fParam.Name);
      case fField.DataType of
        ftBoolean    : fParam.AsBoolean  := fField.AsBoolean;
        ftWord,
        ftSmallInt,
        ftLargeInt,
        ftInteger    : fParam.AsInteger  := fField.AsInteger;
        ftTime,
        ftDate,
        ftDateTime   : fParam.AsDateTime := fField.AsDateTime;
        ftMemo,
        ftWideString,
        ftString     : fParam.AsString   := fField.AsString;
        else           fParam.Value      := fField.Value;
      end; // case fParams[i].DataType
    end;
    try
      fQuery.Execute;
      fDb.Commit;
    except
      fDb.Rollback;
      raise;
    end;
  except
    Abort;
  end;
end;

procedure TSQLiteDS.DoBeforeEdit(DataSet: TDataSet);
var
  i     : Integer;
  Field     : TField;
  FieldName : string;
begin
  if Tag <> 0 then Exit;
  fBuffer.Tag := 1;
  fBuffer.EmptyTable;
  fBuffer.Append;
  for i := 0 to DataSet.Fields.Count -1 do begin
    Field := DataSet.Fields[i];
    if Field.FieldKind = fkData then begin
      FieldName := Field.FieldName;
      fBuffer.FindField(FieldName).Value:= Field.Value;
    end;
  end;
  fBuffer.Post;
  fBuffer.Tag := 0;
end;

procedure TSQLiteDS.CopyStructure(DataSet: TDataSet);
var
  i     : Integer;
  Field : TField;
begin
  fBuffer.Tag := 1;
  fBuffer.Close;
  fBuffer.FieldDefs.Clear;
  for i := 0 to DataSet.FieldCount -1 do begin
    Field := DataSet.Fields[i];
    if Field.FieldKind = fkData then begin
      fBuffer.FieldDefs.Add(Field.FieldName, Field.DataType, Field.Size, FALSE);
    end; // if Field.FieldKind
  end; // for i := 0 to DataSet.FieldCount
  fBuffer.Open;
  fBuffer.Tag := 0;
end;

procedure TSQLiteDS.SetDataBase(Value: TSQLiteDB);
begin
  fDb := Value;
  fQuery.DataBase := fDb;
end;

procedure TSQLiteDS.FetchParams;
begin
  fParams.Clear;
  fParams.ParseSQL(Copy(TRIM(fSQL.Text), 1, Length(TRIM(fSQL.Text))), TRUE);
end;

procedure TSQLiteDS.Open;
var
  s : string;
  i : integer;
  fParam1 : TParam;
  fParam2 : TParam;
begin
  Tag := 1;
  fQuery.Close;
  fQuery.SQL.Text := fSQL.Text;
  fQuery.FetchParams;
  for i := 0 to fParams.Count -1 do begin
    fParam1 := fParams[i];
    fParam2 := fQuery.Params[i];
    case fParams[i].DataType of
      ftBoolean  : fParam2.AsBoolean  := fParam1.AsBoolean;
      ftWord,
      ftSmallInt,
      ftLargeInt,
      ftInteger  : fParam2.AsInteger  := fParam1.AsInteger;
      ftTime,
      ftDate,
      ftDateTime : fParam2.AsDateTime := fParam1.AsDateTime;
      ftMemo,
      ftWideString,
      ftString   : fParam2.AsString   := fParam1.AsString;
      else         fParam2.Value      := fParam1.Value;
    end; // case fParams[i].DataType
  end; // for i := 0 to fParams.Count
  fQuery.Open;
  LoadFromDataSet(fQuery);
  CopyStructure(fQuery);
  fQuery.Close;
  Tag := 0;
end;

procedure TSQLiteDS.Execute;
var
  s : string;
  i : integer;
  fParam1 : TParam;
  fParam2 : TParam;
begin
  Tag := 1;
  fQuery.Close;
  fQuery.SQL.Text := fSQL.Text;
  fQuery.FetchParams;
  for i := 0 to fParams.Count -1 do begin
    fParam1 := fParams[i];
    fParam2 := fQuery.Params[i];
    case fParams[i].DataType of
      ftBoolean  : fParam2.AsBoolean  := fParam1.AsBoolean;
      ftWord,
      ftSmallInt,
      ftLargeInt,
      ftInteger  : fParam2.AsInteger  := fParam1.AsInteger;
      ftTime,
      ftDate,
      ftDateTime : fParam2.AsDateTime := fParam1.AsDateTime;
      ftMemo,
      ftWideString,
      ftString   : fParam2.AsString   := fParam1.AsString;
      else         fParam2.Value      := fParam1.Value;
    end; // case fParams[i].DataType
  end; // for i := 0 to fParams.Count
  fQuery.Execute;
  Tag := 0;
end;

constructor TSQLiteDS.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  fTable       := '';
  fKeyField    := '';
  fSQL         := TStringList.Create;
  fParams      := TParams.Create;
  BeforePost   := DoPost;
  BeforeDelete := DoDelete;
  BeforeEdit   := DoBeforeEdit;
  fQuery       := TSQLiteQuery.Create(Self);
  fBuffer      := TMemTable.Create(Self);
end;

destructor TSQLiteDS.Destroy;
begin
  fSQL.Free;
  fParams.Free;
end;

end.

