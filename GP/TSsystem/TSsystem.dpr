library TSsystem;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  StrUtils,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas',
  Windows, Vcl.Dialogs;

{$E gp}
{$R *.res}

Type
  Pack_Head = Packed Record
    MAGIC: ARRAY [0 .. 3] OF ANSICHAR; // DATA
    DATA_OFFSET: Cardinal;
    DIR_COUNT: Cardinal;
  End;

  DIR_ENTRIES = packed Record
    DIR_NAME: ARRAY [1 .. $20] OF ANSICHAR;
    FILE_ENTRIES_OFFSET: Cardinal;
    DATA_START_OFFSET: Cardinal;
  End;

  FILE_ENTRIES_HEADER = packed Record
    DIR_COUNT: Cardinal;
    FILE_COUNT: Cardinal;
  End;

  Pack_Entries = packed Record
    FILE_NAME: ARRAY [1 .. $20] OF ANSICHAR;
    Start_Offset: Cardinal;
    Length: Cardinal;
  End;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName
    ('TSsystem', clEngine));
end;

procedure Seek_Data(IndexStream: TIndexStream; FileBuffer: TFileBufferStream;
  DIR: DIR_ENTRIES);
var
  DIR_Array: ARRAY OF DIR_ENTRIES;
  entries: Array of Pack_Entries;
  i: Integer;
  File_Counter, Dir_Counter: DWORD;
  Rlentry: TRlEntry;
begin
  FileBuffer.Seek(DIR.FILE_ENTRIES_OFFSET, 0);
  FileBuffer.Read(Dir_Counter, $4);
  if Dir_Counter = 0 then
  begin
    FileBuffer.Read(File_Counter, $4);
    Setlength(entries, File_Counter);
    FileBuffer.Read(entries[0].FILE_NAME[1],
      File_Counter * SizeOf(Pack_Entries));
    for i := 0 to File_Counter do
    begin
      Rlentry := TRlEntry.Create;
      Rlentry.AOffset := entries[i].Start_Offset + DIR.DATA_START_OFFSET;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := entries[i].Length;
      Rlentry.AName := Trim(entries[i].FILE_NAME);
      IndexStream.Add(Rlentry);
    end;
  end
  else
  begin
    Setlength(DIR_Array, Dir_Counter);
    FileBuffer.Read(DIR_Array[0].DIR_NAME[1], SizeOf(Pack_Entries) *
      Dir_Counter);
    for i := 0 to Dir_Counter - 1 do
      Seek_Data(IndexStream, FileBuffer, DIR_Array[i]);
  end;
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  Head: Pack_Head;
  indexs: Pack_Entries;
  i: Integer;
  Rlentry: TRlEntry;
  File_Counter: DWORD;
  DIR_Array: Array of DIR_ENTRIES;
begin
  Result := True;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.MAGIC[0], SizeOf(Pack_Head));
    if not SameText(Trim(Head.MAGIC), 'DATA') then
    begin
      Rlentry := TRlEntry.Create;
      Rlentry.AOffset := 0;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := FileBuffer.Size;
      Rlentry.AName := ExtractFileName(FileBuffer.FileName);
      IndexStream.Add(Rlentry);
      Exit;
    end;
    if Head.DIR_COUNT = 0 then
    begin
      FileBuffer.Read(File_Counter, $4);
      for i := 0 to File_Counter - 1 do
      begin
        FileBuffer.Read(indexs, SizeOf(Pack_Entries));
        Rlentry := TRlEntry.Create;
        Rlentry.AOffset := indexs.Start_Offset + Head.DATA_OFFSET;
        Rlentry.AOrigin := soFromBeginning;
        Rlentry.AStoreLength := indexs.Length;
        Rlentry.AName := Trim(indexs.FILE_NAME);
        IndexStream.Add(Rlentry);
      end;
    end
    else
    begin
      Setlength(DIR_Array, Head.DIR_COUNT);
      FileBuffer.Read(DIR_Array[0].DIR_NAME[1], $28 * Head.DIR_COUNT);
      for i := 0 to Head.DIR_COUNT - 1 do
        Seek_Data(IndexStream, FileBuffer, DIR_Array[i]);
    end;
  except
    Result := False;
  end;
end;

procedure Decyption();
begin
  { do nothing }
end;

var
  XOR_TABLE: ARRAY [0 .. $6 * $68 + 1] OF Cardinal;
  XOR_TABLE_New: ARRAY [0 .. $6 * $68 + 1] OF Cardinal;

Procedure XOR_TABLE_CREATE(KEY: Integer);
VAR
  Edi: DWORD;
  COUNTER: Integer;
BEGIN
  for COUNTER := 0 to $6 * $68 do
  begin
    Edi := KEY;
    KEY := KEY * $10DCD;
    Edi := Edi AND $FFFF0000;
    INC(KEY);
    XOR_TABLE[COUNTER] := Edi;
    Edi := KEY;
    KEY := KEY * $10DCD;
    Edi := Edi SHR $10;
    XOR_TABLE[COUNTER] := XOR_TABLE[COUNTER] or Edi;
    INC(KEY);
  end;
END;

Procedure XOR_TABLE_Update1();
var
  EAX, EDX, EBX: DWORD;
  count: Integer;
begin
  for count := 0 to $E3 - 1 do
  begin
    EAX := XOR_TABLE[count];
    EBX := XOR_TABLE[count + 1];
    EAX := EAX AND $80000000;
    EBX := EBX AND $7FFFFFFF;
    EDX := XOR_TABLE[$18D + count];
    EAX := EAX OR EBX;
    EAX := EAX SHR 1;
    EBX := EBX OR $FFFFFFFE;
    EAX := EAX XOR EDX;
    EBX := EBX + 1;
    EAX := EAX XOR $9908B0DF;
    EBX := EBX AND $9908B0DF;
    EBX := EBX XOR EAX;
    XOR_TABLE[count] := EBX;
  end;
end;

Procedure XOR_TABLE_Update2();
var
  EAX, EDX, EBX: DWORD;
  count: Integer;
begin
  XOR_TABLE[$6 * $68] := XOR_TABLE[0];
  for count := 0 to $18D - 1 do
  begin
    EAX := XOR_TABLE[$E3 + count];
    EBX := XOR_TABLE[$E3 + count + 1];
    EAX := EAX AND $80000000;
    EBX := EBX AND $7FFFFFFF;
    EDX := XOR_TABLE[count];
    EAX := EAX OR EBX;
    EAX := EAX SHR 1;
    EBX := EBX OR $FFFFFFFE;
    EAX := EAX XOR EDX;
    EBX := EBX + 1;
    EAX := EAX XOR $9908B0DF;
    EBX := EBX AND $9908B0DF;
    EBX := EBX XOR EAX;
    XOR_TABLE[$E3 + count] := EBX;
  end;
end;

Procedure XOR_TABLE_Update3();
var
  EAX, EDX, EBP, EBX: DWORD;
  count: Integer;
begin
  for count := 0 to $138 do
  begin
    EAX := XOR_TABLE[count * 2];
    EDX := XOR_TABLE[count * 2 + 1];
    EBX := EAX;
    EAX := EAX SHR $B;
    EBP := EDX;
    EDX := EDX SHR $B;
    EAX := EAX XOR EBX;
    EDX := EDX XOR EBP;
    EBX := EAX;
    EAX := EAX SHL $7;
    EBP := EDX;
    EDX := EDX SHL $7;
    EAX := EAX AND $9D2C5680;
    EDX := EDX AND $9D2C5680;
    EAX := EAX XOR EBX;
    EDX := EDX XOR EBP;
    EBX := EAX;
    EAX := EAX SHL $F;
    EBP := EDX;
    EDX := EDX SHL $F;
    EAX := EAX AND $EFC60000;
    EDX := EDX AND $EFC60000;
    EAX := EAX XOR EBX;
    EDX := EDX XOR EBP;
    EBX := EAX;
    EAX := EAX SHR $12;
    EBP := EDX;
    EDX := EDX SHR $12;
    EAX := EAX XOR EBX;
    EDX := EDX XOR EBP;
    XOR_TABLE_New[count * 2] := EAX;
    XOR_TABLE_New[count * 2 + 1] := EDX;
  end;
end;

Procedure XOR_TABLE_Update();
begin
  XOR_TABLE_Update1();
  XOR_TABLE_Update2();
  XOR_TABLE_Update3();
end;

type
  File_Entries = record
    Start_Offset: DWORD;
    count: DWORD;
    NAME_LENGTH: DWORD;
    NAME: Ansistring;
    STRING_COUNT: DWORD;
    Jump_Table: Array of DWORD;
  end;

function ReadData(FileBuffer: TFileBufferStream; OutBuffer: TStream): LongInt;
var
  Head: Pack_Head;
  KEY: Cardinal;
  FILE_COUNT, Length, M270: DWORD;
  entries: Array of File_Entries;
  stringlist: Ansistring;
  Table: TStringList;
  tmpbuffer: TMemoryStream;
  buf: Byte;
  i: Integer;
begin
  FileBuffer.Seek(0, soFromBeginning);
  FileBuffer.Read(Head.MAGIC[0], SizeOf(Pack_Head));
  FileBuffer.Seek(FileBuffer.Rlentry.AOffset, FileBuffer.Rlentry.AOrigin);
  if not SameText(Trim(Head.MAGIC), 'DATA') then
  begin
    FileBuffer.Read(FILE_COUNT, 4);
    Setlength(stringlist, FILE_COUNT);
    Table := TStringList.Create;
    for i := 0 to FILE_COUNT - 1 do
    begin
      FileBuffer.Read(Length, 4);
      Setlength(stringlist, Length);
      FileBuffer.Read(pbyte(stringlist)^, Length);
      Table.Add(stringlist);
    end;
    Table.Clear;
    FileBuffer.Read(FILE_COUNT, 4);
    Setlength(entries, FILE_COUNT);
    for i := 0 to FILE_COUNT - 1 do
    begin
      FileBuffer.Read(entries[i].Start_Offset, $C);
      Setlength(entries[i].NAME, entries[i].NAME_LENGTH);
      FileBuffer.Read(pbyte(entries[i].NAME)^, entries[i].NAME_LENGTH);
      Table.Add(entries[i].NAME);
      FileBuffer.Read(entries[i].STRING_COUNT, 4);
      Setlength(entries[i].Jump_Table, entries[i].STRING_COUNT);
      FileBuffer.Read(entries[i].Jump_Table[0], 4 * entries[i].STRING_COUNT);
    end;
    Table.Clear;
    Table.Free;
    KEY := StrToInt64(Vcl.Dialogs.InputBox('Need Key', 'Enter Decyption Key:',
      '$DDCBACBA'));
    XOR_TABLE_CREATE(KEY);
    tmpbuffer := TMemoryStream.Create;
    FileBuffer.Read(FILE_COUNT, 4);
    tmpbuffer.CopyFrom(FileBuffer, FILE_COUNT);
    tmpbuffer.Seek(0, soFromBeginning);
    M270 := 0;
    for i := 0 to FILE_COUNT - 1 do
    begin
      if (M270 mod $270) = 0 then
        XOR_TABLE_Update;
      tmpbuffer.Read(buf, 1);
      buf := buf xor Byte(XOR_TABLE_New[(M270 mod $270)] and $FF);
      tmpbuffer.Seek(-1, soFromCurrent);
      tmpbuffer.Write(buf, 1);
      INC(M270);
    end;
    tmpbuffer.Seek(0, soFromBeginning);
    OutBuffer.Seek(0, soFromBeginning);
    Result := OutBuffer.CopyFrom(tmpbuffer, tmpbuffer.Size);
    tmpbuffer.Free;
  end
  else
  begin
    tmpbuffer := TMemoryStream.Create;
    tmpbuffer.CopyFrom(FileBuffer, FileBuffer.Rlentry.AStoreLength);
    tmpbuffer.Seek(0,soFromBeginning);
    for i := 0 to FileBuffer.Rlentry.AStoreLength - 1 do
    begin
      tmpbuffer.Read(buf, 1);
      buf := not buf;
      tmpbuffer.Seek(-1, soFromCurrent);
      tmpbuffer.Write(buf, 1);
    end;
    tmpbuffer.Seek(0, soFromBeginning);
    OutBuffer.Seek(0, soFromBeginning);
    Result := OutBuffer.CopyFrom(tmpbuffer, tmpbuffer.Size);
    tmpbuffer.Free;
  end;
  FileBuffer.EntrySelected := FileBuffer.EntrySelected + 1;
end;

exports GetPluginName;

exports GenerateEntries;

exports Decyption;

exports ReadData;

begin

end.
