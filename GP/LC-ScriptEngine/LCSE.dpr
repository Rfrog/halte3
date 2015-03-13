library LCSE;

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
    start_offset: Cardinal;
    length: Cardinal;
    filename: array [1 .. $44] of AnsiChar;
  End;

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
  Key: Cardinal;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.indexs, sizeof(Pack_Head));
    FileBuffer.Read(Key, 4);
    FileBuffer.Seek(-4, soFromCurrent);
    Head.indexs := Head.indexs xor Key;
    if SameText(ExtractFileExt(FileBuffer.filename), '.lst') and
      (Head.indexs * sizeof(Pack_Entries) < FileBuffer.Size) then
    begin
      Result := dsUnknown;
    end;
  except
    Result := dsError;
  end;
end;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('LC-ScriptEngine', clEngine));
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  Head: Pack_Head;
  indexs: Pack_Entries;
  i, j: Integer;
  Rlentry: TRlEntry;
  Key: Cardinal;
begin
  Result := True;
  try
    if not SameText(ExtractFileExt(FileBuffer.filename),
      '.lst') then
      raise Exception.Create('Error');
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.indexs, sizeof(Pack_Head));
    FileBuffer.Read(Key, 4);
    FileBuffer.Seek(-4, soFromCurrent);
    Head.indexs := Head.indexs xor Key;
    for i := 0 to Head.indexs - 1 do
    begin
      FileBuffer.Read(indexs.start_offset, sizeof(Pack_Entries));
      Rlentry := TRlEntry.Create;
      j := 1;
      while indexs.filename[j] <> #0 do
      begin
        if Byte(indexs.filename[j]) <> Byte(Key) then
          Byte(indexs.filename[j]) := Byte(indexs.filename[j])
            xor Byte(Key);
        j := j + 1;
      end;
      Rlentry.AName := Trim(indexs.filename);
      Rlentry.AOffset := indexs.start_offset xor Key;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs.length xor Key;
      Rlentry.ARLength := 0;
      Rlentry.AKey := Key;
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

const
  WAVHEADER: AnsiString = 'RIFF';
  oggheader: AnsiString = 'OggS';

const
  PNGHeader: array [0 .. 3] of Byte = ($89, $50, $4E, $47);
  bmpHeader: AnsiString = 'BM';

function ReadData(FileBuffer: TFileBufferStream;
  OutBuffer: TStream): LongInt;
var
  tmpbuffer: TMemoryStream;
  readhandle: TFileStream;
  i: Integer;
begin
  tmpbuffer := TMemoryStream.Create;
  readhandle := TFileStream.Create
    (ChangeFileExt(FileBuffer.filename, ''), fmOpenRead);
  readhandle.Seek(FileBuffer.Rlentry.AOffset,
    FileBuffer.Rlentry.AOrigin);
  OutBuffer.Seek(0, soFromBeginning);
  tmpbuffer.CopyFrom(readhandle,
    FileBuffer.Rlentry.AStoreLength);
  if not(CompareMem(tmpbuffer.Memory, Pbyte(WAVHEADER), 4) or
    CompareMem(tmpbuffer.Memory, Pbyte(oggheader), 4) or
    CompareMem(tmpbuffer.Memory, @PNGHeader[0], 4) or
    CompareMem(tmpbuffer.Memory, Pbyte(bmpHeader), 2)) then
    for i := 0 to tmpbuffer.Size - 1 do
      Pbyte(tmpbuffer.Memory)[i] := Pbyte(tmpbuffer.Memory)
        [i] xor (Byte(FileBuffer.Rlentry.AKey) + 1);
  tmpbuffer.Seek(0, soFromBeginning);
  Result := OutBuffer.CopyFrom(tmpbuffer, tmpbuffer.Size);
  tmpbuffer.Clear;
  tmpbuffer.Free;
  readhandle.Free;
  FileBuffer.EntrySelected := FileBuffer.EntrySelected + 1;
end;

function PackData(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream; var Percent: Word): Boolean;
var
  indexs: array of Pack_Entries;
  Head: Pack_Head;
  i, j: Integer;
  tmpbuffer: TStream;
  mrstr: AnsiString;
  Key: Cardinal;
begin
  Result := True;
  try
    Percent := 0;
    Key := StrToInt(InputBox('Need key',
      'Please input encypt key(example:Liquid= $02020202,Tactics= $01010101)',
      '$02020202'));
    SetLength(indexs, IndexStream.Count);
    FileBuffer.Seek(0, soFromBeginning);
    Head.indexs := IndexStream.Count;
    Head.indexs := Head.indexs xor Key;
    tmpbuffer := TMemoryStream.Create;
    for i := 0 to IndexStream.Count - 1 do
    begin
      FillMemory(@indexs[i].filename[1], $44, 0);
      mrstr := IndexStream.Rlentry[i].AName;
      if length(mrstr) > $44 then
        raise Exception.Create('Name too long.');
      Move(Pbyte(mrstr)^, indexs[i].filename[1], length(mrstr));
      j := 1;
      while indexs[i].filename[j] <> #0 do
      begin
        if Byte(indexs[i].filename[j]) <> Byte(Key) then
          Byte(indexs[i].filename[j]) :=
            Byte(indexs[i].filename[j]) xor Byte(Key);
        j := j + 1;
      end;
      indexs[i].length := IndexStream.Rlentry[i]
        .ARLength xor Key;
      indexs[i].start_offset := FileBuffer.Position;
      indexs[i].start_offset := indexs[i].start_offset xor Key;
      (tmpbuffer as TMemoryStream)
        .LoadFromFile(IndexStream.ParentPath +
        IndexStream.Rlentry[i].AName);
      tmpbuffer.Seek(0, soFromBeginning);
      if not(CompareMem((tmpbuffer as TMemoryStream).Memory,
        Pbyte(WAVHEADER), 4) or
        CompareMem((tmpbuffer as TMemoryStream).Memory,
        Pbyte(oggheader), 4) or
        CompareMem((tmpbuffer as TMemoryStream).Memory,
        @PNGHeader[0], 4) or
        CompareMem((tmpbuffer as TMemoryStream).Memory,
        Pbyte(bmpHeader), 2)) then
        for j := 0 to tmpbuffer.Size - 1 do
          Pbyte((tmpbuffer as TMemoryStream).Memory)[j] :=
            Pbyte((tmpbuffer as TMemoryStream).Memory)
            [j] xor (Byte(Key) + 1);
      FileBuffer.CopyFrom(tmpbuffer, tmpbuffer.Size);
      (tmpbuffer as TMemoryStream).Clear;
      Percent := 100 * (i + 1) div IndexStream.Count;
    end;
    tmpbuffer.Free;
    tmpbuffer := TFileStream.Create(FileBuffer.filename + '.lst',
      fmCreate);
    tmpbuffer.Write(Head.indexs, sizeof(Pack_Head));
    tmpbuffer.Write(indexs[0].start_offset, IndexStream.Count *
      sizeof(Pack_Entries));
    tmpbuffer.Free;
    SetLength(indexs, 0);
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
