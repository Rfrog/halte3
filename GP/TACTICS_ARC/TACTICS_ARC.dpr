library TACTICS_ARC;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  StrUtils,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas';

{$E gp}
{$R *.res}


Type
  Pack_Head = Packed Record
    Magic: ARRAY [ 0 .. 15 ] OF ANSICHAR;
    entries_length: Cardinal;
    decompressed_length: Cardinal;
    indexs: Cardinal;
    reserved: Cardinal;
  End;

  Pack_Entries = packed Record
    START_OFFSET: Cardinal;
    Length: Cardinal;
    decompressed_length: Cardinal;
    name_Length: Cardinal;
    TimeStamp: TTimeStamp;
    File_name: AnsiString;
  End;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('TACTICS_ARCHIVE', clEngine));
end;

const
  Magic: AnsiString = 'TACTICS_ARC_FILE';

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[ 0 ], sizeof(Pack_Head));
    if SameText(Trim(Head.Magic), Magic) and
      (Head.entries_length < FileBuffer.Size) and
      (Head.reserved = 0) then
    begin
      Result := dsTrue;
    end;
  except
    Result := dsError;
  end;
end;

procedure Decode(Buffer: TStream);
var
  c: Byte;
begin
  while Buffer.Position < Buffer.Size do
  begin
    Buffer.Read(c, 1);
    c := not c;
    Buffer.Seek(-1, soFromCurrent);
    Buffer.Write(c, 1);
  end;
end;

var
  Key: AnsiString = '';

procedure Decode2(Buffer: TStream);
var
  c: Byte;
  i: integer;
begin
  i := 0;
  while Buffer.Position < Buffer.Size do
  begin
    Buffer.Read(c, 1);
    c := c xor Pbyte(Key)[ i mod Length(Key) ];
    Buffer.Seek(-1, soFromCurrent);
    Buffer.Write(c, 1);
    Inc(i);
  end;
end;

procedure ReadKey(Buffer: TStream);
var
  c: Byte;
  idx: integer;
begin
  idx := 0;
  repeat
    Buffer.Read(c, 1);
    idx := idx + 1;
  until c = 0;
  Buffer.Seek(-idx, soFromCurrent);
  SetLength(Key, idx);
  Buffer.Read(Pbyte(Key)^, idx);
  Key := Trim(Key)
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  Head: Pack_Head;
  indexs: Pack_Entries;
  Compress: TGlCompressBuffer;
  i: integer;
  Rlentry: TRlEntry;
begin
  Result := True;
  try
    Compress := TGlCompressBuffer.Create;
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[ 0 ], sizeof(Pack_Head));
    if not SameStr(Magic, Trim(Head.Magic)) then
      raise Exception.Create('Magic Error');
    Compress.Seek(0, soFromBeginning);
    Compress.CopyFrom(FileBuffer, Head.entries_length);
    Compress.Seek(0, soFromBeginning);
    Decode(Compress);
    Compress.Seek(0, soFromBeginning);
    Compress.LzssDecompress(Compress.Size, $FEE, $FFF);
    Compress.Output.Seek(0, soFromBeginning);
    if Head.decompressed_length <> Compress.Output.Size then
      raise Exception.Create('Decompress Error.');
    ReadKey(Compress.Output);
    for i := 0 to Head.indexs - 1 do
    begin
      Compress.Output.Read(indexs.START_OFFSET, 24);
      SetLength(indexs.File_name, indexs.name_Length);
      Compress.Output.Read(Pbyte(indexs.File_name)^, indexs.name_Length);
      Rlentry := TRlEntry.Create;
      with Rlentry do
      begin
        AName := Trim(indexs.File_name);
        ANameLength := indexs.name_Length;
        AOffset := indexs.START_OFFSET + Head.entries_length +
          sizeof(Pack_Head);
        AOrigin := soFromBeginning;
        AStoreLength := indexs.Length;
        ARLength := indexs.decompressed_length;
      end;
      IndexStream.Add(Rlentry);
    end;
    Compress.Destroy;
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
  Compress: TGlCompressBuffer;
  Buffer: TFileStream;
begin
  Result := FileBuffer.ReadData(OutBuffer);
  if Key <> '' then
  begin
    OutBuffer.Seek(0, soFromBeginning);
    Decode2(OutBuffer);
  end;
  if FileBuffer.PrevEntry.ARLength > 0 then
  begin
    Compress := TGlCompressBuffer.Create;
    OutBuffer.Seek(0, soFromBeginning);
    Compress.CopyFrom(OutBuffer, OutBuffer.Size);
    Compress.Seek(0, soFromBeginning);
    Compress.LzssDecompress(Compress.Size, $FEE, $FFF);
    if FileBuffer.PrevEntry.ARLength <> Compress.Output.Size then
      raise Exception.Create('DECOMPRESS Error');
    OutBuffer.Size := 0;
    Compress.Output.Seek(0, soFromBeginning);
    OutBuffer.CopyFrom(Compress.Output, Compress.Output.Size);
    Compress.Destroy;
  end;
end;

exports
  AutoDetect;

exports
  GetPluginName;

exports
  GenerateEntries;

exports
  Decyption;

exports
  ReadData;

begin

end.
