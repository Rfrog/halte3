library SakiJyann;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  StrUtils,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas',
  Windows;

{$E gp}
{$R *.res}

Type
  Pack_Head = Packed Record
    Magic: ARRAY [0 .. $7] OF ANSICHAR;
    ENTRIES_COUNT: DWORD;
  End;

  Pack_Entries = Packed Record
    File_name: ARRAY [1 .. $100] OF ANSICHAR;
    START_OFFSET: DWORD;
    decompressed_length: DWORD;
    Length: DWORD;
  End;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName
    ('Saki雀', clGameName));
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
    FileBuffer.Read(Head.Magic[0], SizeOf(Pack_Head));
    if not SameText(Trim(Head.Magic), 'FPAC') then
      raise Exception.Create('Magic Error.');
    for i := 0 to Head.ENTRIES_COUNT - 1 do
    begin
      FileBuffer.Read(indexs.File_name[1], SizeOf(Pack_Entries));
      Rlentry := TRlEntry.Create;
      Rlentry.AOffset := indexs.START_OFFSET;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs.Length;
      Rlentry.ARLength := indexs.decompressed_length;
      Rlentry.AName := Trim(indexs.File_name);
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

function ReadData(FileBuffer: TFileBufferStream; OutBuffer: TStream): LongInt;
var
  Decompr: TGlCompressBuffer;
begin
  if FileBuffer.Rlentry.ARLength <> 0 then
  begin
    Decompr := TGlCompressBuffer.Create;
    FileBuffer.ReadData(Decompr);
    Decompr.Seek(0, soFromBeginning);
    Decompr.LzssDecompress(Decompr.Size, $FEE, $FFF);
    Decompr.Output.Seek(0, soFromBeginning);
    Result := OutBuffer.CopyFrom(Decompr.Output, Decompr.Output.Size);
    Decompr.Free;
  end
  else
    Result := FileBuffer.ReadData(OutBuffer);
end;

const
  Magic: AnsiString = 'FPAC';

function PackData(IndexStream: TIndexStream; FileBuffer: TFileBufferStream;
  var Percent: Word): Boolean;
var
  i: Integer;
  Head: Pack_Head;
  indexs: array of Pack_Entries;
  tmpBuffer: TFileStream;
  Compr: TGlCompressBuffer;
begin
  Result := True;
  try
    Percent := 0;
    FileBuffer.Seek(0, soFromBeginning);
    Head.ENTRIES_COUNT := IndexStream.Count;
    Move(Pbyte(Magic)^, Head.Magic[0], 8);
    FileBuffer.Write(Head.Magic[0], SizeOf(Pack_Head));
    SetLength(indexs, IndexStream.Count);
    FillMemory(@indexs[0].File_name[1], SizeOf(Pack_Entries) *
      IndexStream.Count, 0);
    FileBuffer.Write(indexs[0].File_name[1], SizeOf(Pack_Head) *
      IndexStream.Count);
    Compr := TGlCompressBuffer.Create;
    for i := 0 to IndexStream.Count - 1 do
    begin
      tmpBuffer := TFileStream.Create(IndexStream.ParentPath +
        IndexStream.Rlentry[i].AName, fmOpenRead);
      Compr.Clear;
      Compr.CopyFrom(tmpBuffer,tmpBuffer.Size);
      indexs[i].START_OFFSET := FileBuffer.Position;
      indexs[i].decompressed_length := tmpBuffer.Size;
      Move(Pbyte(AnsiString(IndexStream.Rlentry[i].AName))^,
        indexs[i].File_name[1], Length(indexs[i].File_name));
      Compr.Seek(0, soFromBeginning);
      Compr.LzssCompress;
      Compr.Output.Seek(0,soFromBeginning);
      indexs[i].length := Compr.Output.Size;
      FileBuffer.CopyFrom(Compr.Output, Compr.Output.Size);
      tmpBuffer.Free;
      Percent := 90 * (i + 1) div IndexStream.Count;
    end;
    Compr.Free;
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Write(Head.Magic[0], SizeOf(Pack_Head));
    FileBuffer.Write(indexs[0].File_name[1], SizeOf(Pack_Entries) *
      IndexStream.Count);
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
