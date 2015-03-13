library SugarPotPlus;

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
    Head_offset: Cardinal;
    data_offset: Cardinal;
    entries_length: Cardinal;
    name: array [1 .. $105] of AnsiChar;
  End;

  Pack_Entries = Record
    filename: array [1 .. $20] of AnsiChar;
    start_offset: Cardinal;
    length: Cardinal;
  End;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('SUGAR POT +', clGameMaker));
end;

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
  indexs: Pack_Entries;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Head_offset, sizeof(Pack_Head));
    if (Head.Head_offset < FileBuffer.Size) and
      (Head.data_offset < FileBuffer.Size) and
      (Head.entries_length < FileBuffer.Size) then
    begin
      FileBuffer.Read(indexs.filename[1], sizeof(Pack_Entries));
      if (indexs.start_offset + indexs.length)< FileBuffer.Size then
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
begin
  Result := True;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Head_offset, sizeof(Pack_Head));
    if (Head.data_offset + Head.entries_length) >
      FileBuffer.Size then
      raise Exception.Create('OVERFLOW');
    for i := 0 to (Head.data_offset - sizeof(Pack_Head))
      div sizeof(Pack_Entries) - 1 do
    begin
      FileBuffer.Read(indexs.filename[1], sizeof(Pack_Entries));
      Rlentry := TRlEntry.Create;
      Rlentry.AName := Trim(indexs.filename);
      Rlentry.AOffset := indexs.start_offset + Head.data_offset;
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
  decompr: TGlCompressBuffer;
  decomsize: dword;
begin
  Result := FileBuffer.ReadData(OutBuffer);
end;

function PackData(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream; var Percent: Word): Boolean;
var
  Head: Pack_Head;
  indexs: array of Pack_Entries;
  i: Integer;
  filename: AnsiString;
  tmpstream: TFileStream;
begin
  Result := True;
  try
    Head.Head_offset := 0;
    Percent := 0;
    Head.data_offset := sizeof(Pack_Head) + IndexStream.Count *
      sizeof(Pack_Entries);
    Head.entries_length := IndexStream.Count *
      sizeof(Pack_Entries);
    filename := ExtractFileName(FileBuffer.filename);
    Move(pbyte(filename)^, Head.name[1], length(filename));
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Write(Head.Head_offset, sizeof(Pack_Head));
    SetLength(indexs, IndexStream.Count);
    indexs[0].start_offset := 0;
    indexs[0].length := IndexStream.Rlentry[0].ARLength;
    fillmemory(@indexs[0].filename[1], 32, 0);
    Move(pbyte(AnsiString(IndexStream.Rlentry[0].AName))^,
      indexs[0].filename[1],
      length(IndexStream.Rlentry[0].AName));
    Percent := 10;
    for i := 1 to IndexStream.Count - 1 do
    begin
      indexs[i].start_offset := indexs[i - 1].start_offset +
        indexs[i - 1].length;
      indexs[i].length := IndexStream.Rlentry[i].ARLength;
      fillmemory(@indexs[i].filename[1], 32, 0);
      Move(pbyte(AnsiString(IndexStream.Rlentry[i].AName))^,
        indexs[i].filename[1],
        length(IndexStream.Rlentry[i].AName));
      Percent := (((i + 1) * 55) div IndexStream.Count);
    end;
    FileBuffer.Write(indexs[0].filename[1], Head.entries_length);
    for i := 0 to IndexStream.Count - 1 do
    begin
      tmpstream := TFileStream.Create(IndexStream.ParentPath +
        IndexStream.Rlentry[i].AName, fmOpenRead);
      FileBuffer.CopyFrom(tmpstream, indexs[i].length);
      tmpstream.Free;
      Percent := (((i + 1) * 100) div IndexStream.Count);
    end;
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
