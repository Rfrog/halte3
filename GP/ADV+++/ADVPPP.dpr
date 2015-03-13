library ADVPPP;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\Core\CustomStream.pas',
  PluginFunc in '..\..\..\Core\PluginFunc.pas',
  StrUtils,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas',
  Windows;

{$E gp}
{$R *.res}

Type
  Pack_Head = Packed Record
    MAGIC: array [0 .. 3] of AnsiChar;
    RESERVED: Cardinal;
    ENTRIES_OFFSET: Cardinal;
    ENTRIES_COUNT: Cardinal;
    TIME: TSystemTime;
  End;

  Pack_Entries = packed Record
    START_OFFSET: Cardinal;
    Length: Cardinal;
  End;

  data_head = packed record
    MAGIC: array [0 .. 3] of AnsiChar;
    flag: Cardinal;
    uncomprlen: Cardinal;
    RESERVED: Cardinal;
  end;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName
    ('ADV+++(Professional Adventure-Game System)', clEngine));
end;

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.MAGIC[0], SizeOf(Pack_Head));
    if SameText(Trim(Head.MAGIC), 'YOX') then
      if (Head.RESERVED = 0) then
        Result := dsTrue
      else
        Result := dsUnknown;
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
begin
  Result := True;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.MAGIC[0], SizeOf(Pack_Head));
    FileBuffer.Seek(Head.ENTRIES_OFFSET, soFromBeginning);
    if not SameText(Trim(Head.MAGIC), 'YOX') then
      raise Exception.Create('Magic Error.');
    for i := 0 to Head.ENTRIES_COUNT - 1 do
    begin
      FileBuffer.Read(indexs.START_OFFSET, SizeOf(Pack_Entries));
      Rlentry := TRlEntry.Create;
      Rlentry.AOffset := indexs.START_OFFSET;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs.Length;
      Rlentry.ARLength := 0;
      Rlentry.AName := '$' + IntToHex(i, 8);
      IndexStream.Add(Rlentry);
    end;
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
  tmpbuffer: TGlCompressBuffer;
  Head: data_head;
begin
  Result := FileBuffer.ReadData(OutBuffer);
  OutBuffer.Seek(0, soFromBeginning);
  OutBuffer.Read(Head.MAGIC[0], SizeOf(data_head));
  if SameText(Trim(Head.MAGIC), 'YOX') and
    (Head.flag and 2 <> 0) then
  begin
    tmpbuffer := TGlCompressBuffer.Create;
    tmpbuffer.CopyFrom(OutBuffer, OutBuffer.Size -
      SizeOf(data_head));
    tmpbuffer.Seek(0, soFromBeginning);
    tmpbuffer.Output.Seek(0, soFromBeginning);
    tmpbuffer.ZlibDecompress(Head.uncomprlen);
    tmpbuffer.Output.Seek(0, soFromBeginning);
    OutBuffer.Size := 0;
    OutBuffer.Seek(0, soFromBeginning);
    Head.flag := 0;
    OutBuffer.Write(Head.MAGIC[0], SizeOf(data_head));
    OutBuffer.CopyFrom(tmpbuffer.Output, Head.uncomprlen);
    tmpbuffer.Destroy;
  end;
end;

const
  MAGIC: AnsiString = 'YOX'#0;

function PackData(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream; var Percent: Word): Boolean;
var
  i: Integer;
  Head: Pack_Head;
  indexs: array of Pack_Entries;
  tmpbuffer: TFileStream;
  zero: Byte;
begin
  Result := True;
  try
    Percent := 0;
    FileBuffer.Seek(0, soFromBeginning);
    Head.ENTRIES_COUNT := IndexStream.Count;
    Head.ENTRIES_OFFSET := $800;
    Head.RESERVED := 0;
    DateTimeToSystemTime(gettime, Head.TIME);
    Move(Pbyte(MAGIC)^, Head.MAGIC[0], 4);
    FileBuffer.Write(Head.MAGIC[0], SizeOf(Pack_Head));
    zero := 0;
    SetLength(indexs, IndexStream.Count);
    while FileBuffer.Size < $800 do
      FileBuffer.Write(zero, 1);
    for i := 0 to IndexStream.Count - 1 do
    begin
      tmpbuffer := TFileStream.Create(IndexStream.ParentPath +
        IndexStream.Rlentry[i].AName, fmOpenRead);
      indexs[i].START_OFFSET := FileBuffer.Position;
      indexs[i].Length := tmpbuffer.Size;
      tmpbuffer.Seek(0, soFromBeginning);
      FileBuffer.CopyFrom(tmpbuffer, tmpbuffer.Size);
      tmpbuffer.Free;
      Percent := 90 * (i + 1) div IndexStream.Count;
    end;
    Head.ENTRIES_OFFSET := FileBuffer.Position;
    for i := 0 to IndexStream.Count - 1 do
    begin
      FileBuffer.Write(indexs[i].START_OFFSET, 8);
      Percent := 90 + 10 * (i + 1) div IndexStream.Count;
    end;
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Write(Head.MAGIC[0], SizeOf(Pack_Head));
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
