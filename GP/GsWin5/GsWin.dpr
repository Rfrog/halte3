library GsWin;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  Windows,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas';

{$E GP}
{$R *.res}

Type
  Pack_Head = Packed Record
    Magic: Array [0 .. $F] of AnsiChar;
    Description: Array [0 .. $1F] of AnsiChar;
    minor_version: Word;
    major_version: Word;
    index_length: Cardinal;
    key: Cardinal;
    indexs: Cardinal;
    data_offset: Cardinal;
    index_offset: Cardinal;
  End;

  Pack_Entries = packed Record
    FileName: ARRAY [1 .. 64] OF AnsiChar;
    Start_Offset: Cardinal;
    Length: Cardinal;
    Unknow: Cardinal;
    unknow1: Cardinal;
    pad: array [1 .. 24] of Byte;
  End;

  Head_Rec = Packed Record
    Magic: Array [0 .. 3] of AnsiChar;
    Compressed_Length: Cardinal;
    Decompressed_Length: Cardinal;
    unknow1: Cardinal;
    data_offset: Cardinal;
    biWidth: Cardinal;
    biHeight: Cardinal;
    biBitCount: Cardinal;
    reserved: array [1 .. 84] of Byte;
  End;

procedure Decode(Buffer: TStream; key: Cardinal);
var
  buf: Byte;
begin
  if key <> 0 then
  begin
    while Buffer.Position < Buffer.Size do
    begin
      Buffer.Read(buf, 1);
      buf := buf XOR Byte(Buffer.Position - 1);
      Buffer.Seek(-1, soFromCurrent);
      Buffer.Write(buf, 1);
    end;
  end;
end;

// e405f0
function KeyGenerate(key: AnsiString): Cardinal;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to Length(key) - 1 do
    Result := Result * $25 + (Integer(PByte(key)[i]) or $20);
end;

procedure Decode2(Buffer: TStream; key: Cardinal);
var
  buf: Cardinal;
begin
  while Buffer.Position < Buffer.Size - 1 do
  begin
    Buffer.Read(buf, 4);
    buf := buf XOR key;
    Buffer.Seek(-4, soFromCurrent);
    Buffer.Write(buf, 4);
  end;
end;

procedure Decode3(Buffer: TStream; key: Cardinal);
var
  buf: Byte;
begin
  while Buffer.Position < Buffer.Size do
  begin
    Buffer.Read(buf, 1);
    buf := buf XOR Byte(key shr ((Buffer.Position mod 4) * 8));
    Buffer.Seek(-1, soFromCurrent);
    Buffer.Write(buf, 1);
  end;
end;

const
  Magicv5: AnsiString = 'DataPack5';

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], sizeof(Pack_Head));
    if SameText(Trim(Head.Magic), Magicv5) and
      (Head.index_length < FileBuffer.Size) and
      (Head.indexs < FileBuffer.Size) and
      (Head.data_offset < FileBuffer.Size) and
      (Head.index_offset < FileBuffer.Size) then
    begin
      Result := dsTrue;
    end;
  except
    Result := dsError;
  end;
end;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('GsWin', clEngine));
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  Head: Pack_Head;
  indexs: Pack_Entries;
  i: Integer;
  Rlentry: TRlEntry;
  Buffer: TGlCompressBuffer;
begin
  Result := True;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], sizeof(Pack_Head));
    FileBuffer.Seek(Head.index_offset, soFromBeginning);
    if (Head.indexs * sizeof(Pack_Entries)) >
      FileBuffer.Size then
      raise Exception.Create('OVERFLOW');
    Buffer := TGlCompressBuffer.Create;
    Buffer.CopyFrom(FileBuffer, Head.index_length);
    Buffer.Seek(0, soFromBeginning);
    Decode(Buffer, Head.key);
    Buffer.Seek(0, soFromBeginning);
    Buffer.LzssDecompress(Buffer.Size, $FEE, $FFF);
    if Buffer.Output.Size <>
      (Head.indexs * sizeof(Pack_Entries)) then
      raise Exception.Create('Decompress Error.');
    Buffer.Output.Seek(0, soFromBeginning);
    for i := 0 to Head.indexs - 1 do
    begin
      Buffer.Output.Read(indexs.FileName[1],
        sizeof(Pack_Entries));
      Rlentry := TRlEntry.Create;
      Rlentry.AName := Trim(indexs.FileName);
      Rlentry.AOffset := indexs.Start_Offset + Head.data_offset;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs.Length;
      Rlentry.ARLength := 0;
      if (Rlentry.AOffset + Rlentry.AStoreLength) >
        FileBuffer.Size then
        raise Exception.Create('OverFlow');
      IndexStream.Add(Rlentry);
    end;
    Buffer.Free;
  except
    Result := False;
  end;
end;

procedure Decyption();
begin
  { do nothing }
end;

const
  PNGHeader: array [0 .. 3] of Byte = ($89, $50, $4E, $47);

function ReadData(FileBuffer: TFileBufferStream;
  OutBuffer: TStream): LongInt;
var
  key: Cardinal;
  Head: array [0 .. 3] of Byte;
  Buffer: TMemoryStream;
begin
  Buffer := TMemoryStream.Create;
  key := KeyGenerate(AnsiString(FileBuffer.Rlentry.AName));
  FileBuffer.Seek(FileBuffer.Rlentry.AOffset,
    FileBuffer.Rlentry.AOrigin);
  Result := Buffer.CopyFrom(FileBuffer,
    FileBuffer.Rlentry.AStoreLength);
  if FileBuffer.Rlentry.AStoreLength mod 4 <> 0 then
    Buffer.Write(key, 4 - FileBuffer.Rlentry.AStoreLength mod 4);
  Buffer.Seek(0, soFromBeginning);
  Decode2(Buffer, key);
  Buffer.Seek(0, soFromBeginning);
  Buffer.Read(Head[0], 4);
  if not CompareMem(@Head[0], @PNGHeader[0], 4) then
  begin
    Buffer.Seek(0, soFromBeginning);
    Decode2(OutBuffer, key);
  end;
  Buffer.Seek(0, soFromBeginning);
  OutBuffer.CopyFrom(Buffer, FileBuffer.Rlentry.AStoreLength);
  Buffer.Free;
  FileBuffer.EntrySelected := FileBuffer.EntrySelected + 1;
end;

function PackData(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream; var Percent: Word): Boolean;
var
  i: Integer;
  Head: Pack_Head;
  indexs: array of Pack_Entries;
  tmpbuffer: TMemoryStream;
  Compr: TGlCompressBuffer;
  Head1: array [0 .. 3] of Byte;
  key: Cardinal;
begin
  Result := True;
  try
    Percent := 0;
    FileBuffer.Seek(0, soFromBeginning);
    ZeroMemory(@Head.Magic[0], sizeof(Pack_Head));
    Move(PByte(AnsiString(Magicv5))^, Head.Magic[0],
      Length(Magicv5));
    Head.indexs := IndexStream.Count;
    Head.index_length := sizeof(Pack_Entries) *
      IndexStream.Count;
    FileBuffer.Write(Head.Magic[0], sizeof(Pack_Head));
    setlength(indexs, IndexStream.Count);
    ZeroMemory(@indexs[0].FileName[1], sizeof(Pack_Entries) *
      IndexStream.Count);
    Head.data_offset := FileBuffer.Position;
    for i := 0 to IndexStream.Count - 1 do
    begin
      tmpbuffer := TMemoryStream.Create;
      tmpbuffer.LoadFromFile(IndexStream.ParentPath +
        IndexStream.Rlentry[i].AName);
      if Length(IndexStream.Rlentry[i].AName) > 64 then
        raise Exception.Create('FileName too long.');
      Move(PByte(AnsiString(IndexStream.Rlentry[i].AName))^,
        indexs[i].FileName[1],
        Length(IndexStream.Rlentry[i].AName));
      indexs[i].Length := tmpbuffer.Size;
      indexs[i].Start_Offset := FileBuffer.Position -
        Head.data_offset;
      tmpbuffer.Seek(0, soFromBeginning);
      tmpbuffer.Read(Head1[0], 4);
      if CompareMem(@Head1[0], @PNGHeader[0], 4) then
      begin
        key := KeyGenerate
          (AnsiString(IndexStream.Rlentry[i].AName));
        tmpbuffer.Seek(0, soFromBeginning);
        Decode2(tmpbuffer, key);
      end;
      tmpbuffer.Seek(0, soFromBeginning);
      FileBuffer.CopyFrom(tmpbuffer, tmpbuffer.Size);
      tmpbuffer.Free;
      Percent := 90 * (i + 1) div IndexStream.Count;
    end;
    Head.index_offset := FileBuffer.Position;
    Head.key := 1;
    Compr := TGlCompressBuffer.Create;
    Compr.Write(indexs[0].FileName[1], IndexStream.Count *
      sizeof(Pack_Entries));
    Compr.Seek(0, soFromBeginning);
    Compr.LzssCompress;
    Compr.Output.Seek(0, soFromBeginning);
    Decode(Compr.Output, Head.key);
    Head.index_length := Compr.Output.Size;
    Compr.Output.Seek(0, soFromBeginning);
    FileBuffer.CopyFrom(Compr.Output, Compr.Output.Size);
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Write(Head.Magic[0], sizeof(Pack_Head));
  except
    Result := False;
  end;
end;

exports Autodetect;

exports GetPluginName;

exports GenerateEntries;

exports Decyption;

exports ReadData;

exports PackData;

begin

end.
