library AGS;

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
    Magic: array [0 .. 3] of AnsiChar;
    Indexs: word;
  End;

  Pack_Entries = Packed Record
    Name: array [1 .. $10] of AnsiChar;
    START_OFFSET: Cardinal;
    Length: Cardinal;
  End;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('AGS', clEngine));
end;

const
  Magic = 'pack';

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
  Indexs: Pack_Entries;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], SizeOf(Pack_Head));
    if SameText(Trim(Head.Magic), Magic) and
      (Head.Indexs < $FFFF) then
    begin
      FileBuffer.Read(Indexs.Name[1], SizeOf(Pack_Entries));
      if (StrLen(PChar(trim(Indexs.Name))) in [1 .. $10]) and
        ((Indexs.START_OFFSET + Indexs.Length) <
        FileBuffer.Size) then
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
  Indexs: Pack_Entries;
  i: Integer;
  Rlentry: TRlEntry;
begin
  Result := true;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], SizeOf(Pack_Head));
    if not SameText(Trim(Head.Magic), Magic) then
      raise Exception.Create('Magic Error.');
    for i := 0 to Head.Indexs - 1 do
    begin
      FileBuffer.Read(Indexs.Name[1], SizeOf(Pack_Entries));
      Rlentry := TRlEntry.Create;
      Rlentry.AName := Trim(Indexs.Name);
      Rlentry.AOffset := Indexs.START_OFFSET;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := Indexs.Length;
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
begin
  Result := FileBuffer.ReadData(OutBuffer);
end;

function PackData(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream; var Percent: word): Boolean;
var
  Head: Pack_Head;
  Indexs: array of Pack_Entries;
  i: Integer;
  tmpStream: TmemoryStream;
  tmpsize: Cardinal;
begin
  Result := true;
  try
    Percent := 0;
    Head.Indexs := IndexStream.Count;
    SetLength(Indexs, Head.Indexs);
    ZeroMemory(@Indexs[0].Name[1],
      Head.Indexs * SizeOf(Pack_Entries));
    tmpsize := SizeOf(Pack_Head) + Head.Indexs *
      SizeOf(Pack_Entries);
    for i := 0 to Head.Indexs - 1 do
    begin
      if Length(IndexStream.Rlentry[i].AName) > 80 then
        raise Exception.Create('Name too long.');
      Move(PByte(AnsiString(IndexStream.Rlentry[i].AName))^,
        Indexs[i].Name[1], Length(IndexStream.Rlentry[i].AName));
      Indexs[i].START_OFFSET := tmpsize;
      Indexs[i].Length := IndexStream.Rlentry[i].ARLength;
      Percent := 10 * (i + 1) div Head.Indexs;
    end;

    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Write(Indexs[0].Name[1],
      Head.Indexs * SizeOf(Pack_Entries));
    tmpStream := TmemoryStream.Create;
    for i := 0 to Head.Indexs - 1 do
    begin
      tmpStream.LoadFromFile(IndexStream.ParentPath +
        IndexStream.Rlentry[i].AName);
      tmpStream.Seek(0, soFromEnd);
      tmpStream.Seek(0, soFromBeginning);
      FileBuffer.CopyFrom(tmpStream, tmpStream.Size);
      Percent := 10 + 90 * (i + 1) div Head.Indexs;
    end;
    tmpStream.Free;
    SetLength(Indexs, 0);
  except
    Result := False;
  end;
end;

exports AutoDetect;

exports GetPluginName;

exports GenerateEntries;

exports Decyption;

exports ReadData;

{ exports PackData; }

begin

end.
