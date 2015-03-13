library A15WIN;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  Windows,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas',
  StrUtils, Vcl.Dialogs;

{$E GP}
{$R *.res}

Type
  Pack_Head = Packed Record
    indexs: Cardinal;
  End;

  Pack_Entries = packed Record
    filename: AnsiString;
    length: Cardinal;
    start_offset: Cardinal;
  End;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('A15WIN', clEngine));
end;

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
  indexs: Pack_Entries;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.indexs, SizeOf(Pack_Head));
    if SameText(ExtractFileExt(FileBuffer.filename), '.arc') and
      (Head.indexs * SizeOf(Pack_Entries) <
      (FileBuffer.Size - FileBuffer.Position)) then
    begin
      FileBuffer.Read(indexs.filename[1], SizeOf(Pack_Entries));
      if (((indexs.start_offset xor $68820811) + (indexs.length xor $33656775))
        < FileBuffer.Size) then
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
  i, j: Integer;
  Rlentry: TRlEntry;
  namelen: Integer;
  Key1, Key2: Cardinal;
begin
  Result := True;
  try
    if not SameText(ExtractFileExt(FileBuffer.filename), '.arc') then
      raise Exception.Create('Extension Error');
    namelen := StrToIntdef(inputbox('Need name length',
      'Name length differ in every game,pls input one', '$14'), $14);
    Key1 := StrToIntdef(inputbox('Need Key1', 'Need the key for offset',
      '$68820811'), $68820811);
    Key2 := StrToIntdef(inputbox('Need Key1', 'Need the key for offset',
      '$33656775'), $33656775);
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.indexs, SizeOf(Pack_Head));
    for i := 0 to Head.indexs - 1 do
    begin
      SetLength(indexs.filename, namelen);
      FileBuffer.Read(PByte(indexs.filename)^, namelen);
      FileBuffer.Read(indexs.length, 4);
      FileBuffer.Read(indexs.start_offset, 4);
      Rlentry := TRlEntry.Create;
      j := 0;
      while j < namelen do
      begin
        PByte(indexs.filename)[j] := PByte(indexs.filename)[j] xor $03;
        j := j + 1;
      end;
      Rlentry.AName := Trim(indexs.filename);
      Rlentry.AOffset := indexs.start_offset xor Key1;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs.length xor Key2;
      Rlentry.ARLength := 0;
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
  if SameText(ExtractFileExt(FileBuffer.Rlentry.AName), '.wav') or
    SameText(ExtractFileExt(FileBuffer.Rlentry.AName), '.ogg') or
    SameText(ExtractFileExt(FileBuffer.Rlentry.AName), '.gp8') then
    Result := FileBuffer.ReadData(OutBuffer)
  else
  begin
    Decompr := TGlCompressBuffer.Create;
    FileBuffer.ReadData(Decompr);
    Decompr.Seek(0, soFromBeginning);
    Decompr.LzssDecompress(Decompr.Size, $FEE, $FFF);
    Decompr.Output.Seek(0, soFromBeginning);
    Result := OutBuffer.CopyFrom(Decompr.Output, Decompr.Output.Size);
  end;
end;

function PackData(IndexStream: TIndexStream; FileBuffer: TFileBufferStream;
  var Percent: Word): Boolean;
var
  i, j, namelen: Integer;
  Head: Pack_Head;
  indexs: array of Pack_Entries;
  Compr: TGlCompressBuffer;
  tmpbuffer: TFileStream;
  Key1, Key2: Cardinal;
begin
  Result := True;
  try
    Percent := 0;
    FileBuffer.Seek(0, soFromBeginning);
    Head.indexs := IndexStream.Count;
    SetLength(indexs, IndexStream.Count);
    FileBuffer.Write(Head.indexs, SizeOf(Pack_Head));
    ZeroMemory(@indexs[0].filename[1], SizeOf(Pack_Entries) *
      IndexStream.Count);
    namelen := StrToIntdef(inputbox('Need name length',
      'Name length differ in every game,pls input one', '$14'), $14);
    Key1 := StrToIntdef(inputbox('Need Key1', 'Need the key for offset',
      '$68820811'), $68820811);
    Key2 := StrToIntdef(inputbox('Need Key1', 'Need the key for offset',
      '$33656775'), $33656775);
    for i := 0 to IndexStream.Count - 1 do
    begin
      if length(IndexStream.Rlentry[i].AName) > namelen then
        raise Exception.Create('NAME TOO LONG.');
      Move(PByte(AnsiString(IndexStream.Rlentry[i].AName))^,
        PByte(indexs[i].filename)^, length(IndexStream.Rlentry[i].AName));
      j := 0;
      while j < namelen do
      begin
        PByte(indexs[i].filename)[j] := PByte(indexs[i].filename)[j] xor $03;
        j := j + 1;
      end;
      Percent := 10 * (i + 1) div IndexStream.Count;
    end;
    for i := 0 to IndexStream.Count - 1 do
    begin
      FileBuffer.Write(PByte(indexs[i].filename)^, namelen);
      FileBuffer.Write(indexs[i].length, 4);
      FileBuffer.Write(indexs[i].start_offset, 4);
    end;
    Compr := TGlCompressBuffer.Create;
    for i := 0 to IndexStream.Count - 1 do
    begin
      tmpbuffer := TFileStream.Create(IndexStream.ParentPath +
        IndexStream.Rlentry[i].AName, fmOpenRead);
      tmpbuffer.Seek(0, soFromBeginning);
      if SameText(ExtractFileExt(FileBuffer.Rlentry.AName), '.wav') or
        SameText(ExtractFileExt(FileBuffer.Rlentry.AName), '.ogg') or
        SameText(ExtractFileExt(FileBuffer.Rlentry.AName), '.gp8') then
      begin
        FileBuffer.CopyFrom(tmpbuffer, tmpbuffer.Size);
      end
      else
      begin
        Compr.Clear;
        indexs[i].start_offset := Cardinal(FileBuffer.Position) xor Key1;
        Compr.CopyFrom(tmpbuffer, tmpbuffer.Size);
        Compr.Seek(0, soFromBeginning);
        Compr.LzssCompress;
        Compr.Output.Seek(0, soFromBeginning);
        FileBuffer.CopyFrom(Compr.Output, Compr.Output.Size);
        indexs[i].length := Cardinal(Compr.Output.Size) xor Key2;
      end;
      tmpbuffer.Free;
      Percent := 10 + 90 * (i + 1) div IndexStream.Count;
    end;
    FileBuffer.Seek(SizeOf(Pack_Head), soFromBeginning);
    for i := 0 to IndexStream.Count - 1 do
    begin
      FileBuffer.Write(PByte(indexs[i].filename)^, namelen);
      FileBuffer.Write(indexs[i].length, 4);
      FileBuffer.Write(indexs[i].start_offset, 4);
    end;
    Compr.Free;
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
