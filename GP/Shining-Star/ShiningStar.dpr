library ShiningStar;

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
    Index_Length: Cardinal;
    Indexs: Cardinal;
    Index_Offset: Cardinal;

  End;

  Pack_Entries = packed Record
    File_name: ARRAY [1 .. $10] OF ANSICHAR;
    Length: Cardinal;
    Decompress_Length: Cardinal;
    Compr_Flag: Cardinal;
    START_OFFSET: Cardinal;
  End;

  Bin_Script = packed record
    OPCode: Byte;
    Text: array [1 .. $90 - 1] of ANSICHAR;
  end;

const
  BinMagic = 'Plain-BIN-Format,By HatsuneTakumi';

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('ShiningStar Lily''s',
    clGameMaker));
end;

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
  Indexs: Pack_Entries;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Index_Length, sizeof(Pack_Head));
    if (Head.Index_Length < FileBuffer.Size) and
      (Head.Indexs < FileBuffer.Size) and
      (Head.Index_Offset < FileBuffer.Size) and
      ((Head.Index_Offset + Head.Index_Length) <
      FileBuffer.Size) then
    begin
      FileBuffer.Read(Indexs.File_name[1], sizeof(Pack_Entries));
      if ((Indexs.Length + Indexs.START_OFFSET) <
        FileBuffer.Size) and (Indexs.Compr_Flag in [0 .. 1]) then
        Result := dsUnknown;
    end;
  except
    Result := dsError;
  end;
end;

procedure ProcBinScript(Buffer: TStream);
var
  Result: TStringList;
  Sect: Bin_Script;
begin
  if Buffer.Size mod $90 <> 0 then
    Exit;
  Result := TStringList.Create;
  Buffer.Seek(0, soFromBeginning);
  Result.Add(BinMagic);
  while Buffer.Position < Buffer.Size do
  begin
    Buffer.Read(Sect.OPCode, $90);
    Result.Add(Format('$%.2x,"%s"', [Sect.OPCode,
      Trim(Sect.Text)]))
  end;
  Buffer.Size := 0;
  Result.SaveToStream(Buffer);
  Result.Free;
end;

procedure CompileBinScript(Buffer: TMemoryStream);
var
  Result: TMemoryStream;
  Sect: Bin_Script;
  Text: TStringList;
  i: Integer;
begin
  Result := TMemoryStream.Create;
  Text := TStringList.Create;
  Text.LoadFromStream(Buffer);
  Buffer.Seek(0, soFromBeginning);
  if not SameText(Text[0], BinMagic) then
    raise Exception.Create('Magic Check Error.');
  for i := 1 to Text.Count - 1 do
  begin
    ZeroMemory(@Sect.OPCode, $90);
    Sect.OPCode := StrToInt(LeftStr(Text[i], 3));
    // Move(Pbyte(),sect.Text[1]);
  end;
  Buffer.Size := 0;
  Result.SaveToStream(Buffer);
  Result.Free;
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  Head: Pack_Head;
  Indexs: Pack_Entries;
  i: Integer;
  Rlentry: TRlEntry;
begin
  Result := True;
  try
    FileBuffer.Seek(-sizeof(Pack_Head), soFromEnd);
    FileBuffer.Read(Head.Index_Length, sizeof(Pack_Head));
    FileBuffer.Seek(Head.Index_Offset, soFromBeginning);
    for i := 0 to Head.Indexs - 1 do
    begin
      FileBuffer.Read(Indexs.File_name[1], sizeof(Pack_Entries));
      Rlentry := TRlEntry.Create;
      Rlentry.AOffset := Indexs.START_OFFSET;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := Indexs.Length;
      Rlentry.ARLength := Indexs.Decompress_Length;
      Rlentry.AName := Trim(Indexs.File_name);
      Rlentry.AKey := Indexs.Compr_Flag;
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
  compr: TGlCompressBuffer;
  decomprSize: Cardinal;
  ext: string;
begin
  ext := ExtractFileExt(FileBuffer.Rlentry.AName);
  if FileBuffer.Rlentry.AKey = 1 then
  begin
    decomprSize := FileBuffer.Rlentry.ARLength;
    Result := FileBuffer.ReadData(OutBuffer);
    OutBuffer.Seek(0, soFromBeginning);
    compr := TGlCompressBuffer.Create;
    compr.CopyFrom(OutBuffer, OutBuffer.Size);
    compr.Seek(0, soFromBeginning);
    compr.Output.Seek(0, soFromBeginning);
    compr.LzssDecompress(compr.Size, $FEE, $FFF);
    if decomprSize <> compr.Output.Size then
      raise Exception.Create('Decompress Error.');
    compr.Output.Seek(0, soFromBeginning);
    OutBuffer.Size := 0;
    OutBuffer.Seek(0, soFromBeginning);
    OutBuffer.CopyFrom(compr.Output, compr.Output.Size);
    compr.Destroy;
  end
  else
    Result := FileBuffer.ReadData(OutBuffer);
  // if SameText(ext, '.bin') then
  // ProcBinScript(OutBuffer);
end;

function PackData(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream; var Percent: Word): Boolean;
var
  i: Integer;
  Head: Pack_Head;
  Indexs: array of Pack_Entries;
  tmpbuffer: TFileStream;
begin
  Result := True;
  try
    Percent := 0;
    FileBuffer.Seek(0, soFromBeginning);
    Head.Indexs := IndexStream.Count;
    Head.Index_Length := sizeof(Pack_Entries) *
      IndexStream.Count;
    setlength(Indexs, IndexStream.Count);
    ZeroMemory(@Indexs[0].File_name[1], sizeof(Pack_Entries) *
      IndexStream.Count);
    for i := 0 to IndexStream.Count - 1 do
    begin
      tmpbuffer := TFileStream.Create(IndexStream.ParentPath +
        IndexStream.Rlentry[i].AName, fmOpenRead);
      if Length(IndexStream.Rlentry[i].AName) > $10 then
        raise Exception.Create('FileName too long.');
      Move(Pbyte(AnsiString(IndexStream.Rlentry[i].AName))^,
        Indexs[i].File_name[1],
        Length(IndexStream.Rlentry[i].AName));
      Indexs[i].Decompress_Length := tmpbuffer.Size;
      Indexs[i].Length := tmpbuffer.Size;
      Indexs[i].Compr_Flag := 0;
      Indexs[i].START_OFFSET := FileBuffer.Position;
      tmpbuffer.Seek(0, soFromBeginning);
      FileBuffer.CopyFrom(tmpbuffer, tmpbuffer.Size);
      tmpbuffer.Free;
      Percent := 90 * (i + 1) div IndexStream.Count;
    end;
    Head.Index_Offset := FileBuffer.Position;
    FileBuffer.Write(Indexs[0].File_name[1], IndexStream.Count *
      sizeof(Pack_Entries));
    FileBuffer.Write(Head.Index_Length, sizeof(Pack_Head))
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
