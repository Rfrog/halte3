library TOPCAT;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  Windows,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas'
{$IFDEF debug}
    , CodeSiteLogging
{$ENDIF};

{$E GP}
{$R *.res}

Type
  TAnsiStrTable = array of AnsiString;
  TCardinalTable = array of Cardinal;

  IndexInfo = packed record
    DataSize: Cardinal;
    EntriesOffset: Cardinal;
    DirNameLenght: Cardinal;
    DirNum: Cardinal;
    Indexs: Cardinal;
    FileNameLength: Cardinal;
    Reserved: Cardinal;
    Reserved1: Cardinal;
  end;

  Pack_Head = packed record
    Magic: array [0 .. 3] of AnsiChar;
    Indexs: Cardinal; // means all files in this package
    ScriptIndex: IndexInfo;
    UnknowIndex: IndexInfo;
    ImageIndex: IndexInfo;
    SoundIndex: IndexInfo;
    OtherIndex: IndexInfo;
  end;

  TDirInfo = packed record
    Indexs: Cardinal; // how many entries in this dir
    Offset: Cardinal; // offset in table
    StartIndex: Cardinal; // Count in all files
    Reserved: Cardinal; // 0
  end;

  TDirsInfo = array of TDirInfo;

  // only ansitring has encoded with +$77
  Pack_Entries = packed Record
    DirList: TAnsiStrTable;
    DirInfo: TDirsInfo;
    NameTable: TAnsiStrTable;
    OffsetTable: TCardinalTable;
  End;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('TOPCAT', clGamemaker));
end;

function Decode(Input, OutPut: TStream): Integer;
var
  i: Integer;
  tmp, Buffer: Byte;
  ecx, pos: Cardinal;
begin
  Result := 0;
  pos := 0;
  ecx := 0;
  Input.Read(Buffer, 1);
  asm
    push eax
    mov al,buffer
    rol al,7
    mov tmp,al
    pop eax
  end;
  if Result = 0 then
  begin
    if tmp <> 0 then
    begin
      Result := 1;
      if tmp <> $A then
      begin
        pos := pos + tmp * $41;
      end
      else

    end
    else
    begin
      Result := Result - 1;
      if Result = 0 then
      begin
        OutPut.Write(tmp, 1);
        ecx := ecx + 1;
        if tmp = 0 then
          Result := 0;
      end;
    end;
  end;
end;

procedure DecodeStr(Table: TAnsiStrTable);
var
  i, j: Integer;
begin
  for i := Low(Table) to High(Table) do
  begin
    for j := 0 to Length(Table[i]) - 1 do
      PByte(Table[i])[j] := PByte(Table[i])[j] - $40;
  end;
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  Indexs: Pack_Entries;
  Head: Pack_Head;
  i, j: Integer;
  Rlentry: TRlEntry;
begin
  Result := True;
  try
    if not SameText(ExtractFileExt(FileBuffer.filename), '.TCD') then
      raise Exception.Create('Error.');
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], SizeOf(Pack_Head));
{$IFDEF debug}
    CodeSite.Send('Indexs: ', Head.Indexs);
    CodeSite.Send('ScriptIndexs: ', Head.ScriptIndex.DataSize);
{$ENDIF}
    if not SameText(Trim(Head.Magic), 'TCD3') then
      raise Exception.Create('Magic Error.');
    if Head.ScriptIndex.Indexs <> 0 then
    begin
      SetLength(Indexs.DirList, Head.ScriptIndex.DirNum);
      SetLength(Indexs.DirInfo, Head.ScriptIndex.DirNum);
      SetLength(Indexs.NameTable, Head.ScriptIndex.Indexs);
      SetLength(Indexs.OffsetTable, Head.ScriptIndex.Indexs + 1);
      for i := 0 to Head.ScriptIndex.DirNum - 1 do
      begin
        FileBuffer.Seek(Head.ScriptIndex.EntriesOffset, soFromBeginning);
        SetLength(Indexs.DirList[i], Head.ScriptIndex.DirNameLenght);
        FileBuffer.Read(PByte(Indexs.DirList[i])^,
          Head.ScriptIndex.DirNameLenght);
      end;
      for i := 0 to Head.ScriptIndex.DirNum - 1 do
      begin
        FileBuffer.Read(Indexs.DirInfo[i].Indexs, 4);
        FileBuffer.Read(Indexs.DirInfo[i].Offset, 4);
        FileBuffer.Read(Indexs.DirInfo[i].StartIndex, 4);
        FileBuffer.Read(Indexs.DirInfo[i].Reserved, 4);
      end;
      FileBuffer.Seek(Head.ScriptIndex.EntriesOffset, soFromBeginning);
      for i := 0 to Head.ScriptIndex.Indexs - 1 do
      begin
        SetLength(Indexs.NameTable[i], Head.ScriptIndex.FileNameLength);
        FileBuffer.Read(PByte(Indexs.NameTable[i])^,
          Head.ScriptIndex.FileNameLength);
      end;
      for i := 0 to Head.ScriptIndex.Indexs do
      begin
        FileBuffer.Read(Indexs.OffsetTable[i], 4);
      end;

      DecodeStr(Indexs.DirList);
      DecodeStr(Indexs.NameTable);

      for j := 0 to Head.ScriptIndex.DirNum - 1 do
      begin
        for i := 0 to Indexs.DirInfo[j].Indexs - 1 do
        begin
          Rlentry := TRlEntry.Create;
          Rlentry.AName := '\Script\' + Indexs.DirList[j] + '\' +
            Indexs.NameTable[i];
          Rlentry.AOrigin := soFromBeginning;
          Rlentry.AOffset := Indexs.OffsetTable
            [Indexs.DirInfo[j].StartIndex + i];
          Rlentry.AStoreLength := Indexs.OffsetTable
            [Indexs.DirInfo[j].StartIndex + i + 1] - Indexs.OffsetTable
            [Indexs.DirInfo[j].StartIndex + i];
          Rlentry.ARLength := 0;
          IndexStream.Add(Rlentry);
        end;
      end;
    end;
  except
    Result := False;
  end;
end;

procedure Decyption();
begin
  { do nothing }
end;

function ReadData(FileBuffer: TFileBufferStream; OutBuffer: TStream): LongInt;
var
  tmpbuffer: TMemoryStream;
  readhandle: TFileStream;
begin
  tmpbuffer := TMemoryStream.Create;
  readhandle := TFileStream.Create(ChangeFileExt(FileBuffer.filename, '.dat'),
    fmOpenRead);
  readhandle.Seek(FileBuffer.Rlentry.AOffset, FileBuffer.Rlentry.AOrigin);
  OutBuffer.Seek(0, soFromBeginning);
  tmpbuffer.CopyFrom(readhandle, FileBuffer.Rlentry.AStoreLength);
  tmpbuffer.Seek(0, soFromBeginning);
  Result := OutBuffer.CopyFrom(tmpbuffer, tmpbuffer.Size);
  tmpbuffer.Free;
  readhandle.Free;
  FileBuffer.EntrySelected := FileBuffer.EntrySelected + 1;
end;

function PackData(IndexStream: TIndexStream; FileBuffer: TFileBufferStream;
  var Percent: Word): Boolean;
var
  Indexs: array of Pack_Entries;
  i: Integer;
  tmpbuffer: TFileStream;
begin
  Result := True;
  try
    Percent := 0;
    SetLength(Indexs, 0);
  except
    Result := False;
  end;
end;

exports GetPluginName;

exports GenerateEntries;

exports Decyption;

exports ReadData;

exports PackData;

begin

end.
