library R8WIN;

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
  Pack_Entries = packed Record
    filename: array [1 .. $E] of AnsiChar;
    start_offset: Cardinal;
    length: Cardinal;
  End;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName
    ('R8WIN', clEngine));
end;

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Entries;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.filename[1], sizeof(Pack_Entries));
    if SameText(ExtractFileExt(FileBuffer.filename), '.lst') and
      (Head.start_offset < FileBuffer.Size) and
      (Head.length < FileBuffer.Size) and
      (Head.Length < FileBuffer.Size) then
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
  indexs: Pack_Entries;
  i: Integer;
  Rlentry: TRlEntry;
begin
  Result := True;
  try
    if not SameText(ExtractFileExt(FileBuffer.filename), '.lst') then
      raise Exception.Create('Error');
    FileBuffer.Seek(0, soFromBeginning);
    i := 0;
    while i < FileBuffer.Size do
    begin
      FileBuffer.Read(indexs.filename[1], SizeOf(Pack_Entries));
      Rlentry := TRlEntry.Create;
      Rlentry.AName := Trim(indexs.filename);
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs.length;
      Rlentry.ARLength := 0;
      IndexStream.Add(Rlentry);
      i := i + SizeOf(Pack_Entries);
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
  tmpbuffer: TMemoryStream;
  readhandle: TFileStream;
begin
  tmpbuffer := TMemoryStream.Create;
  readhandle := TFileStream.Create(ChangeFileExt(FileBuffer.filename, '.dat'),
    fmOpenRead);
  readhandle.Seek(FileBuffer.Rlentry.AOffset, FileBuffer.Rlentry.AOrigin);
  OutBuffer.Seek(0, soFromBeginning);
  tmpbuffer.CopyFrom(readhandle, FileBuffer.Rlentry.AStoreLength);
  tmpbuffer.Seek(0, soFromBeginning);
  Result := OutBuffer.CopyFrom(tmpbuffer, tmpbuffer.Size);
  tmpbuffer.Free;
  readhandle.Free;
  FileBuffer.EntrySelected := FileBuffer.EntrySelected + 1;
end;

function PackData(IndexStream: TIndexStream; FileBuffer: TFileBufferStream;
  var Percent: Word): Boolean;
var
  indexs: array of Pack_Entries;
  i: Integer;
  tmpbuffer: TFileStream;
begin
  Result := True;
  try
    Percent := 0;
    SetLength(indexs, IndexStream.Count);
    FileBuffer.Seek(0, soFromBeginning);
    for i := 0 to IndexStream.Count - 1 do
    begin
      FillMemory(@indexs[i].filename[1], $e,0);
      if length(IndexStream.Rlentry[i].AName) > $E then
        raise Exception.Create('Name too long.');
      Move(Pbyte(AnsiString(IndexStream.Rlentry[i].AName))^,
        indexs[i].filename[1], length(IndexStream.Rlentry[i].AName));
      indexs[i].length := IndexStream.Rlentry[i].ARLength;
      indexs[i].start_offset := FileBuffer.Position;
      tmpbuffer := TFileStream.Create(IndexStream.ParentPath +
        IndexStream.Rlentry[i].AName, fmOpenRead);
      FileBuffer.CopyFrom(tmpbuffer, tmpbuffer.Size);
      tmpbuffer.Free;
      Percent := 100 * (i+1) div IndexStream.Count;
    end;
    tmpbuffer := TFileStream.Create(FileBuffer.filename + '.lst', fmCreate);
    tmpbuffer.Write(indexs[0].filename[1], IndexStream.Count *
      SizeOf(Pack_Entries));
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
