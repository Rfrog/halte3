library SnowFlake;

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
    ENTRIES_COUNT: Cardinal;
    Compress_Flag: Cardinal;
  End;

  Pack_Entries = packed Record
    File_name: ARRAY [1 .. $20] OF ANSICHAR;
    Decompress_Length: Cardinal;
    Length: Cardinal;
    START_OFFSET: Cardinal;
  End;

const
  Key1: Array [0 .. 6] of ANSICHAR = 'KOITATE';

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('SnowFlake', clEngine));
end;

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.ENTRIES_COUNT, sizeof(Pack_Head));
    if (Head.ENTRIES_COUNT < FileBuffer.Size) and
      (Head.Compress_Flag in [0 .. 1]) then
    begin
      Result := dsUnknown;
    end;
  except
    Result := dsError;
  end;
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  Head: Pack_Head;
  indexs: Pack_Entries;
  i: Integer;
  Rlentry: TRlEntry;
  tmpbuffer: TMemoryStream;
  key: AnsiString;
begin
  Result := True;
  try
    FileBuffer.Seek(0, soFromBeginning);
    tmpbuffer := TMemoryStream.Create;
    FileBuffer.Read(Head.ENTRIES_COUNT, sizeof(Pack_Head));
    tmpbuffer.CopyFrom(FileBuffer, Head.ENTRIES_COUNT *
      sizeof(Pack_Entries));
    key := AnsiString(Vcl.Dialogs.InputBox('Need Key',
      'Enter Decyption Key:', 'KOITATE'));
    for i := 0 to tmpbuffer.Size - 1 do
      PByte(tmpbuffer.Memory)[i] := PByte(tmpbuffer.Memory)[i] +
        byte(PByte(key)[i mod Length(key)]);
    tmpbuffer.Seek(0, soFromBeginning);
    for i := 0 to Head.ENTRIES_COUNT - 1 do
    begin
      tmpbuffer.Read(indexs.File_name[1], sizeof(Pack_Entries));
      Rlentry := TRlEntry.Create;
      Rlentry.AOffset := indexs.START_OFFSET;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs.Length;
      Rlentry.ARLength := indexs.Decompress_Length;
      Rlentry.AName := Trim(indexs.File_name);
      Rlentry.AKey := Head.Compress_Flag;
      IndexStream.Add(Rlentry);
    end;
    tmpbuffer.Free;
  except
    Result := False;
  end;
end;

procedure Decyption();
begin
  { do nothing }
end;

function ReadData(FileBuffer: TFileBufferStream;
  OutBuffer: TStream): LongInt;
var
  compr: TGlCompressBuffer;
begin
  if FileBuffer.Rlentry.AKey = 1 then
  begin
    Result := FileBuffer.ReadData(OutBuffer);
    OutBuffer.Seek(0, soFromBeginning);
    compr := TGlCompressBuffer.Create;
    compr.CopyFrom(OutBuffer, OutBuffer.Size);
    compr.Seek(0, soFromBeginning);
    compr.Output.Seek(0, soFromBeginning);
    compr.LzssDecompress(compr.Size, $FEE, $FFF);
    compr.Output.Seek(0, soFromBeginning);
    OutBuffer.Size := 0;
    OutBuffer.Seek(0, soFromBeginning);
    OutBuffer.CopyFrom(compr.Output, compr.Output.Size);
    compr.Destroy;
  end
  else
    Result := FileBuffer.ReadData(OutBuffer);
end;

function PackData(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream; var Percent: Word): Boolean;
var
  i: Integer;
  Head: Pack_Head;
  indexs: array of Pack_Entries;
  tmpbuffer: TFileStream;
  tmpsize: Cardinal;
  key: AnsiString;
begin
  Result := True;
  try
    Percent := 0;
    FileBuffer.Seek(0, soFromBeginning);
    Head.ENTRIES_COUNT := IndexStream.Count;
    setlength(indexs, IndexStream.Count);
    Head.Compress_Flag := 0;
    FileBuffer.Write(Head.ENTRIES_COUNT, sizeof(Pack_Head));
    ZeroMemory(@indexs[0].File_name[1], sizeof(Pack_Entries) *
      IndexStream.Count);
    tmpsize := sizeof(Pack_Head) + sizeof(Pack_Entries) *
      Head.ENTRIES_COUNT;
    for i := 0 to IndexStream.Count - 1 do
    begin
      indexs[i].Length := IndexStream.Rlentry[i].ARLength;
      Move(PByte(AnsiString(IndexStream.Rlentry[i].AName))^,
        indexs[i].File_name[1],
        Length(IndexStream.Rlentry[i].AName));
      indexs[i].Decompress_Length := indexs[i].Length;
      indexs[i].START_OFFSET := tmpsize;
      tmpsize := tmpsize + indexs[i].Length;
      Percent := 10 * (i + 1) div IndexStream.Count;
    end;
    key := AnsiString(Vcl.Dialogs.InputBox('Enter Key',
      'Enter Encyption Key:', 'KOITATE'));
    for i := 0 to sizeof(Pack_Entries) *
      Head.ENTRIES_COUNT - 1 do
    begin
      PByte(@indexs[0].File_name[1])[i] :=
        PByte(@indexs[0].File_name[1])[i] -
        byte(PByte(key)[i mod Length(key)]);
    end;
    FileBuffer.Write(indexs[0].File_name[1], sizeof(Pack_Entries)
      * IndexStream.Count);
    for i := 0 to IndexStream.Count - 1 do
    begin
      tmpbuffer := TFileStream.Create(IndexStream.ParentPath +
        IndexStream.Rlentry[i].AName, fmOpenRead);
      tmpbuffer.Seek(0, soFromBeginning);
      FileBuffer.CopyFrom(tmpbuffer, tmpbuffer.Size);
      tmpbuffer.Free;
      Percent := 10 + 90 * (i + 1) div IndexStream.Count;
    end;
  except
    Result := False;
  end;
end;

exports AutoDetect;

exports GetPluginName;

exports GenerateEntries;

exports Decyption;

exports ReadData;

exports PackData;

begin

end.
