library ClsFileLink;

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
    Magic: ARRAY [0 .. $F] OF ANSICHAR;
    ENTRIES_COUNT: Cardinal;
    UNKNOW: Cardinal;
    ENTRIES_OFFSET: Cardinal;
    data_offset: Cardinal;
    PAD: ARRAY [1 .. 8] OF Cardinal;
  End;

  Pack_Entries = Packed Record
    File_name: ARRAY [0 .. $27] OF ANSICHAR;
    UNKNOW: Cardinal;
    START_OFFSET: Cardinal;
    Length: Cardinal;
    RES: ARRAY [0 .. 2] OF Cardinal;
  End;

Const
  Magic: Ansistring = 'CLS_FILELINK';

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], sizeof(Pack_Head));
    if SameText(Trim(Head.Magic), Magic) and
      (Head.ENTRIES_OFFSET < FileBuffer.Size) and
      (Head.data_offset < FileBuffer.Size) and
      (Head.ENTRIES_COUNT < FileBuffer.Size) then
    begin
      Result := dsTrue;
    end;
  except
    Result := dsError;
  end;
end;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('CLS File-Link', clEngine));
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  Head: Pack_Head;
  indexs: Pack_Entries;
  i: Integer;
  Rlentry: TRlEntry;
begin
  Result := true;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], sizeof(Pack_Head));
    if not SameText(Trim(Head.Magic), Magic) then
      raise Exception.Create('Magic Error.');
    if (Head.ENTRIES_COUNT * sizeof(Pack_Entries)) >
      FileBuffer.Size then
      raise Exception.Create('OVERFLOW');
    FileBuffer.Seek(Head.ENTRIES_OFFSET, soFromBeginning);
    for i := 0 to Head.ENTRIES_COUNT - 1 do
    begin
      Rlentry := TRlEntry.Create;
      FileBuffer.Read(indexs.File_name[0], sizeof(Pack_Entries));
      Rlentry.AName := Trim(indexs.File_name);
      Rlentry.AOffset := indexs.START_OFFSET;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs.Length;
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

exports AutoDetect;

exports GetPluginName;

exports GenerateEntries;

exports Decyption;

exports ReadData;

begin

end.
