library MPF2;

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
    Magic: ARRAY [0 .. 3] OF ANSICHAR;
    version: Cardinal;
    entries_length: Cardinal;
    decompressed_length: Cardinal;
    DATA_OFFSET: Cardinal;
    reserved: Cardinal;
    Major_Ver: Cardinal;
    mINOR_vER: Cardinal;
  End;

  Pack_Entries = packed Record
    TOTALENGTH: Cardinal;
    ZERO: Cardinal;
    START_OFFSET: Cardinal;
    ZERO1: Cardinal;
    COMPRESS_FLAG: Cardinal;
    Length: Cardinal;
    decompressed_length: Cardinal;
    File_name: STRING;
  End;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('MPF2.0', clEngine));
end;

const
  Magic: AnsiString = 'MPF2';
  flen = $40000000;

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], sizeof(Pack_Head));
    if SameText(Trim(Head.Magic), Magic) and
      (Head.entries_length < FileBuffer.Size) and
      (Head.DATA_OFFSET < FileBuffer.Size) and
      (Head.reserved = 0) then
    begin
      Result := dsTrue;
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
  Compress: TGlCompressBuffer;
  i: Integer;
  Rlentry: TRlEntry;
begin
  Result := True;
  try
    Compress := TGlCompressBuffer.Create;
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], sizeof(Pack_Head));
    if not SameStr(Magic, Trim(Head.Magic)) then
      raise Exception.Create('Magic Error');
    Compress.Seek(0, soFromBeginning);
    Compress.CopyFrom(FileBuffer, Head.entries_length);
    Compress.Seek(0, soFromBeginning);
    Compress.ZlibDecompress(Head.decompressed_length);
    Compress.Output.Seek(0, soFromBeginning);
    if Head.decompressed_length <> Compress.Output.Size then
      raise Exception.Create('Decompress Error.');
    i := 0;
    while i < Head.decompressed_length do
    begin
      Rlentry := TRlEntry.Create;
      Compress.Output.Read(indexs.TOTALENGTH, 28);
      Rlentry.AOffset :=
        (indexs.START_OFFSET + Head.DATA_OFFSET) mod flen;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs.Length;
      Rlentry.ARLength := indexs.decompressed_length;
      Rlentry.AKey := indexs.COMPRESS_FLAG;
      Rlentry.AKey2 :=
        (indexs.START_OFFSET + Head.DATA_OFFSET) div flen;
      SetLength(Rlentry.AName, (indexs.TOTALENGTH - 28) div 2);
      Compress.Output.Read(Pbyte(Rlentry.AName)^,
        indexs.TOTALENGTH - 28);
      if Pbyte(Rlentry.AName)^ = $0 then
        Rlentry.AName := '$' + IntToHex(i, 8);
      IndexStream.Add(Rlentry);
      i := i + indexs.TOTALENGTH;
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

const
  ArchiveName = 'arc.a%.2d';

function ReadData(FileBuffer: TFileBufferStream;
  OutBuffer: TStream): LongInt;
var
  Compress: TGlCompressBuffer;
  Buffer: TFileStream;
begin
  if FileBuffer.Rlentry.AKey2 = 0 then
  begin
    if (FileBuffer.Rlentry.AOffset +
      FileBuffer.Rlentry.AStoreLength) <= $40000000 then
      Result := FileBuffer.ReadData(OutBuffer)
    else
    begin
      FileBuffer.Seek(FileBuffer.Rlentry.AOffset,
        FileBuffer.Rlentry.AOrigin);
      OutBuffer.CopyFrom(FileBuffer,
        $40000000 - FileBuffer.Rlentry.AOffset);
      Buffer := TFileStream.Create
        (Format(ExtractFilePath(FileBuffer.FileName) + '\' +
        ArchiveName, [FileBuffer.Rlentry.AKey2 + 1]),
        fmOpenRead);
      try
        OutBuffer.CopyFrom(Buffer,
          (FileBuffer.Rlentry.AOffset +
          FileBuffer.Rlentry.AStoreLength) - $40000000);
      finally
        Buffer.Free;
      end;
      FileBuffer.EntrySelected := FileBuffer.EntrySelected + 1;
    end;
  end
  else
  begin
    if (FileBuffer.Rlentry.AOffset +
      FileBuffer.Rlentry.AStoreLength) <= $40000000 then
    begin
      Buffer := TFileStream.Create
        (Format(ExtractFilePath(FileBuffer.FileName) + '\' +
        ArchiveName, [FileBuffer.Rlentry.AKey2]), fmOpenRead);
      try
        OutBuffer.CopyFrom(Buffer,
          FileBuffer.Rlentry.AStoreLength);
      finally
        Buffer.Free;
      end;
    end
    else
    begin
      FileBuffer.Seek(FileBuffer.Rlentry.AOffset,
        FileBuffer.Rlentry.AOrigin);
      OutBuffer.CopyFrom(FileBuffer,
        $40000000 - FileBuffer.Rlentry.AOffset);
      Buffer := TFileStream.Create
        (Format(ExtractFilePath(FileBuffer.FileName) + '\' +
        ArchiveName, [FileBuffer.Rlentry.AKey2 + 1]),
        fmOpenRead);
      try
        OutBuffer.CopyFrom(Buffer,
          (FileBuffer.Rlentry.AOffset +
          FileBuffer.Rlentry.AStoreLength) - $40000000);
      finally
        Buffer.Free;
      end;
      FileBuffer.EntrySelected := FileBuffer.EntrySelected + 1;
    end
  end;
  if FileBuffer.PrevEntry.AKey = 1 then
  begin
    Compress := TGlCompressBuffer.Create;
    OutBuffer.Seek(0, soFromBeginning);
    Compress.CopyFrom(OutBuffer, OutBuffer.Size);
    Compress.ZlibDecompress(FileBuffer.Rlentry.ARLength);
    OutBuffer.Size := 0;
    OutBuffer.CopyFrom(Compress.Output, Compress.Output.Size);
    Compress.Destroy;
  end;
end;

exports AutoDetect;

exports GetPluginName;

exports GenerateEntries;

exports Decyption;

exports ReadData;

begin

end.
