unit sqlite3obj;

{$l libsqlite3.a}
{$linklib libkernel32.a}
{$linklib libmsvcrt.a}
{$linklib libgcc.a}

interface

uses
  SysUtils,
  Classes;

type
  TSQLiteDB   = Pointer;
  TSQLiteStmt = Pointer;

type
  TDestroyPtr = procedure(p: pointer);cdecl;

type
  TSQLCollateFunc = function(CollateParam: pointer; s1Len: integer; s1: pointer;
    s2Len: integer; s2: pointer) : integer; cdecl;

const
  SQLITE_INTEGER = 1;
  SQLITE_FLOAT = 2;
  SQLITE_TEXT = 3;
  SQLITE_BLOB = 4;
  SQLITE_NULL = 5;

  SQLITE_UTF8     = 1;
  SQLITE_UTF16LE  = 2;
  SQLITE_UTF16BE  = 3;
  SQLITE_UTF16    = 4;
  SQLITE_UTF16_ALIGNED = 8;

  SQLITE_OK = 0;
  SQLITE_ERROR = 1;
  SQLITE_INTERNAL = 2;
  SQLITE_PERM = 3;
  SQLITE_ABORT = 4;
  SQLITE_BUSY = 5;
  SQLITE_LOCKED = 6;
  SQLITE_NOMEM = 7;
  SQLITE_READONLY = 8;
  SQLITE_INTERRUPT = 9;
  SQLITE_IOERR = 10;
  SQLITE_CORRUPT = 11;
  SQLITE_NOTFOUND = 12;
  SQLITE_FULL = 13;
  SQLITE_CANTOPEN = 14;
  SQLITE_PROTOCOL = 15;
  SQLITE_EMPTY = 16;
  SQLITE_SCHEMA = 17;
  SQLITE_TOOBIG = 18;
  SQLITE_CONSTRAINT = 19;
  SQLITE_MISMATCH = 20;
  SQLITE_MISUSE = 21;
  SQLITE_NOLFS = 22;
  SQLITE_AUTH = 23;
  SQLITE_FORMAT = 24;
  SQLITE_RANGE = 25;
  SQLITE_NOTADB = 26;
  SQLITE_ROW = 100;
  SQLITE_DONE = 101;

  SQLITE_STATIC    = pointer(0);
  SQLITE_TRANSIENT = pointer(-1);

  SQLITE_IOERR_READ       = $010A;
  SQLITE_IOERR_SHORT_READ = $020A;

function sqlite3_initialize: integer; cdecl; external;
function sqlite3_shutdown: integer; cdecl; external;
function sqlite3_open(filename: PAnsiChar; var DB: TSQLiteDB): integer; cdecl; external;
function sqlite3_create_collation(DB: TSQLiteDB; CollationName: PAnsiChar;
  StringEncoding: integer; CollateParam: pointer; cmp: TSQLCollateFunc): integer; cdecl;external;
function sqlite3_close(DB: TSQLiteDB): integer;cdecl;external;
function sqlite3_libversion: PAnsiChar;cdecl;external;
function sqlite3_errmsg(DB: TSQLiteDB): PAnsiChar;cdecl;external;
function sqlite3_last_insert_rowid(DB: TSQLiteDB): Int64;cdecl;external;
function sqlite3_exec(DB: TSQLiteDB; SQL: PAnsiChar; CallBack, Args: pointer; Error: PAnsiChar): integer; cdecl;external;
function sqlite3_prepare_v2(DB: TSQLiteDB; SQL: PAnsiChar; SQL_bytes: integer;
  var S: TSQLiteDB; var SQLtail: PAnsiChar): integer;cdecl;external; 
function sqlite3_finalize(S: TSQLiteDB): integer;cdecl;external;
function sqlite3_next_stmt(DB: TSQLiteDB; S: TSQLiteDB): TSQLiteDB;cdecl;external;
function sqlite3_reset(S: TSQLiteDB): integer;cdecl;external;
function sqlite3_step(S: TSQLiteDB): integer;cdecl;external;
function sqlite3_column_count(S: TSQLiteDB): integer;cdecl;external;
function sqlite3_column_type(S: TSQLiteDB; Col: integer): integer;cdecl;external;
function sqlite3_column_decltype(S: TSQLiteDB; Col: integer): PAnsiChar;cdecl;external;
function sqlite3_column_name(S: TSQLiteDB; Col: integer): PAnsiChar;cdecl;external;
function sqlite3_column_bytes(S: TSQLiteDB; Col: integer): integer;cdecl;external;
function sqlite3_column_value(S: TSQLiteDB; Col: integer): TSQLiteDB;cdecl;external;
function sqlite3_column_double(S: TSQLiteDB; Col: integer): double;cdecl;external;
function sqlite3_column_int(S: TSQLiteDB; Col: integer): integer;cdecl;external;
function sqlite3_column_int64(S: TSQLiteDB; Col: integer): int64;cdecl;external;
function sqlite3_column_text(S: TSQLiteDB; Col: integer): PAnsiChar;cdecl;external;
function sqlite3_column_blob(S: TSQLiteDB; Col: integer): PAnsiChar;cdecl;external;
function sqlite3_value_type(V: TSQLiteDB): integer;cdecl;external;
function sqlite3_value_bytes(V: TSQLiteDB): integer;cdecl;external;
function sqlite3_value_double(V: TSQLiteDB): double;cdecl;external;
function sqlite3_value_int64(V: TSQLiteDB): Int64;cdecl;external;
function sqlite3_value_text(V: TSQLiteDB): PAnsiChar;cdecl;external;
function sqlite3_value_blob(V: TSQLiteDB): PAnsiChar;cdecl;external;
function sqlite3_bind_parameter_count(S: TSQLiteDB): integer;cdecl;external;
procedure sqlite3_free(P: PAnsiChar);cdecl;external;
function sqlite3_errcode(db: TSQLiteDB): integer;cdecl;external;  
function sqlite3_bind_text(S: TSQLiteDB; Param: integer; Text: PAnsiChar; Text_bytes: integer = -1;
  DestroyPtr: TDestroyPtr=nil): integer; cdecl;external;
function sqlite3_bind_blob(S: TSQLiteDB; Param: integer; Buf: pointer; Buf_bytes: integer;
  DestroyPtr: TDestroyPtr=nil): integer; cdecl;external;
function sqlite3_bind_zeroblob(S: TSQLiteDB; Param: integer; Size: integer): integer;cdecl;external;
function sqlite3_bind_double(S: TSQLiteDB; Param: integer; Value: double): integer;cdecl;external;
function sqlite3_bind_int(S: TSQLiteDB; Param: integer; Value: integer): integer;cdecl;external;
function sqlite3_bind_Int64(S: TSQLiteDB; Param: integer; Value: Int64): integer;cdecl;external;
function sqlite3_clear_bindings(S: TSQLiteDB): integer;cdecl;external;
function sqlite3_blob_open(DB: TSQLiteDB; DBName, TableName, ColumnName: PAnsiChar;
  RowID: Int64; Flags: Integer; var Blob: TSQLiteDB): Integer;cdecl;external;
function sqlite3_blob_close(Blob: TSQLiteDB): Integer;cdecl;external;
function sqlite3_blob_read(Blob: TSQLiteDB; const Data; Count, Offset: Integer): Integer;cdecl;external;
function sqlite3_blob_write(Blob: TSQLiteDB; const Data; Count, Offset: Integer): Integer;cdecl;external;
function sqlite3_blob_bytes(Blob: TSQLiteDB): Integer;cdecl;external;

function SQLiteErrorStr(SQLiteErrorCode: Integer): AnsiString;

implementation

function SQLiteErrorStr(SQLiteErrorCode: Integer): AnsiString;
begin
  case SQLiteErrorCode of
    SQLITE_OK: Result := 'Successful result';
    SQLITE_ERROR: Result := 'SQL error or missing database';
    SQLITE_INTERNAL: Result := 'An internal logic error in SQLite';
    SQLITE_PERM: Result := 'Access permission denied';
    SQLITE_ABORT: Result := 'Callback routine requested an abort';
    SQLITE_BUSY: Result := 'The database file is locked';
    SQLITE_LOCKED: Result := 'A table in the database is locked';
    SQLITE_NOMEM: Result := 'A malloc() failed';
    SQLITE_READONLY: Result := 'Attempt to write a readonly database';
    SQLITE_INTERRUPT: Result := 'Operation terminated by sqlite3_interrupt()';
    SQLITE_IOERR: Result := 'Some kind of disk I/O error occurred';
    SQLITE_CORRUPT: Result := 'The database disk image is malformed';
    SQLITE_NOTFOUND: Result := '(Internal Only) Table or record not found';
    SQLITE_FULL: Result := 'Insertion failed because database is full';
    SQLITE_CANTOPEN: Result := 'Unable to open the database file';
    SQLITE_PROTOCOL: Result := 'Database lock protocol error';
    SQLITE_EMPTY: Result := 'Database is empty';
    SQLITE_SCHEMA: Result := 'The database schema changed';
    SQLITE_TOOBIG: Result := 'Too much data for one row of a table';
    SQLITE_CONSTRAINT: Result := 'Abort due to contraint violation';
    SQLITE_MISMATCH: Result := 'Data type mismatch';
    SQLITE_MISUSE: Result := 'Library used incorrectly';
    SQLITE_NOLFS: Result := 'Uses OS features not supported on host';
    SQLITE_AUTH: Result := 'Authorization denied';
    SQLITE_FORMAT: Result := 'Auxiliary database format error';
    SQLITE_RANGE: Result := '2nd parameter to sqlite3_bind out of range';
    SQLITE_NOTADB: Result := 'File opened that is not a database file';
    SQLITE_ROW: Result := 'sqlite3_step() has another row ready';
    SQLITE_DONE: Result := 'sqlite3_step() has finished executing';
  else
    Result := 'Unknown SQLite Error Code "' + IntToStr(SQLiteErrorCode) + '"';
  end;
end;

end.














