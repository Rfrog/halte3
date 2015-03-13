library propeller;

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
    index_offset: Cardinal;
    indexs: Cardinal;
  End;

  Pack_Entries = packed Record
    filename: array [ 1 .. $20 ] of AnsiChar;
    start_offset: Cardinal;
    length: Cardinal;
  End;

  Data_Header = packed record
    flag: Word;
    Decompressed_Length: DWORD;
    Compressed_Length: DWORD;
  end;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('propeller', clGameMaker));
end;

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
  j: Integer;
  indexs: Pack_Entries;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.index_offset, sizeof(Pack_Head));
    if (Head.index_offset < FileBuffer.Size) and
      (Head.indexs < FileBuffer.Size) then
    begin
      FileBuffer.Read(indexs.filename[ 1 ], sizeof(Pack_Entries));
      for j := 0 to sizeof(Pack_Entries) - 1 do
        Pbyte(@indexs.filename[ 1 ])[ j ] :=
          Pbyte(@indexs.filename[ 1 ])[ j ] xor $58;
      if (indexs.start_offset + indexs.length) <
        FileBuffer.Size then
        Result := dsUnknown;
    end;
  except
    Result := dsError;
  end;
end;

procedure MGRCompress(Input, Output: TStream);
var
  flag: Byte;
begin
  flag := 31;
  while Input.Position < Input.Size do
  begin
    Output.Write(flag, 1);
    Output.CopyFrom(Input, flag + 1);
  end;
  Output.Seek(0, soFromBeginning);
end;

procedure MGRDecompress(Input, Output: TStream);
var
  flag: Byte;
  copysize: Integer;
  offset: Cardinal;
  buffer: array of Byte;
begin
  while Input.Position < Input.Size do
  begin
    Input.Read(flag, 1);
    if flag < 32 then
    begin
      Output.CopyFrom(Input, flag + 1);
    end
    else
    begin
      offset := (flag and $1F) shl 8;
      copysize := flag shr 5;
      SetLength(buffer, copysize);
      if copysize = 7 then
      begin
        Input.Read(flag, 1);
        copysize := flag + 7;
      end;
      copysize := copysize + 2;
      Input.Read(flag, 1);
      Output.Seek(-offset, soFromCurrent);
      Output.Seek(-flag, soFromCurrent);
      SetLength(buffer, copysize);
      Output.Read(buffer[ 0 ], copysize);
      Output.Seek(0, soFromEnd);
      Output.Write(buffer[ 0 ], copysize);
    end;
  end;
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  Head: Pack_Head;
  indexs: Pack_Entries;
  i, j: Integer;
  Rlentry: TRlEntry;
begin
  Result := True;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.index_offset, sizeof(Pack_Head));
    if (Head.index_offset + Head.indexs) > FileBuffer.Size then
      raise Exception.Create('OVERFLOW');
    FileBuffer.Seek(Head.index_offset, soFromBeginning);
    for i := 0 to Head.indexs - 1 do
    begin
      FileBuffer.Read(indexs.filename[ 1 ], sizeof(Pack_Entries));
      for j := 0 to sizeof(Pack_Entries) - 1 do
        Pbyte(@indexs.filename[ 1 ])[ j ] :=
          Pbyte(@indexs.filename[ 1 ])[ j ] xor $58;
      Rlentry := TRlEntry.Create;
      Rlentry.AName := Trim(indexs.filename);
      Rlentry.AOffset := indexs.start_offset;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs.length;
      Rlentry.ARLength := 0;
      if (Rlentry.AOffset + Rlentry.AStoreLength) >
        FileBuffer.Size then
        raise Exception.Create('OverFlow');
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
  Head: Data_Header;
  buffer: TMemoryStream;
begin
  Result := FileBuffer.ReadData(OutBuffer);
  OutBuffer.Read(Head.flag, sizeof(Data_Header));
  if Head.Decompressed_Length <> Head.Compressed_Length then
  begin
    buffer := TMemoryStream.Create;
    try
      OutBuffer.Seek(0, soFromBeginning);
      MGRDecompress(OutBuffer, buffer);
      OutBuffer.Size := 0;
      buffer.Seek(0, soFromBeginning);
      OutBuffer.CopyFrom(buffer, buffer.Size);
    finally
      buffer.Free;
    end;
  end;
end;

function PackData(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream; var Percent: Word): Boolean;
var
  Head: Pack_Head;
  indexs: array of Pack_Entries;
  i: Integer;
  tmpstream: TFileStream;
begin
  Result := True;
  try
    Percent := 0;
    Head.indexs := IndexStream.Count;
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Write(Head.index_offset, sizeof(Pack_Head));
    SetLength(indexs, IndexStream.Count);
    Percent := 10;
    for i := 0 to IndexStream.Count - 1 do
    begin
      tmpstream := TFileStream.Create(IndexStream.ParentPath +
        IndexStream.Rlentry[ i ].AName, fmOpenRead);
      indexs[ i ].length := tmpstream.Size;
      indexs[ i ].start_offset := FileBuffer.Position;
      if length(IndexStream.Rlentry[ i ].AName) > $20 then
        raise Exception.Create('Name too long.');
      fillmemory(@indexs[ 0 ].filename[ 1 ], $20, 0);
      Move(Pbyte(AnsiString(IndexStream.Rlentry[ i ].AName))^,
        indexs[ i ].filename[ 1 ],
        length(IndexStream.Rlentry[ i ].AName));
      FileBuffer.CopyFrom(tmpstream, indexs[ i ].length);
      tmpstream.Free;
      Percent := (((i + 1) * 100) div IndexStream.Count);
    end;
    Head.index_offset := FileBuffer.Position;
    for i := 0 to Head.indexs * sizeof(Pack_Entries) - 1 do
      Pbyte(@indexs[ 0 ].filename[ 1 ])[ i ] :=
        Pbyte(@indexs[ 0 ].filename[ 1 ])[ i ] xor $58;
    FileBuffer.Write(indexs[ 0 ].filename[ 1 ],
      Head.indexs * sizeof(Pack_Entries));
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Write(Head.index_offset, sizeof(Pack_Head));
    SetLength(indexs, 0);
  except
    Result := False;
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

exports
  PackData;

begin

end.
