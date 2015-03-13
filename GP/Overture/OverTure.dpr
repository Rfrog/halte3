library OverTure;

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
    Magic: ARRAY [0 .. $7] OF ANSICHAR;
    Entries_Length: Dword;
    ENTRIES_COUNT: Dword;
  End;

  Pack_Entries = packed Record
    File_name: ARRAY [1 .. 36] OF ANSICHAR;
    START_OFFSET: Dword;
    Length: Dword;
    Resverd: Dword;
  End;

Const
  Magic: Ansistring = '';

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('OverTure Advanced System',
    clengine));
end;

procedure IndexDecode(const Buffer: Pbyte; const Length: Dword);
var
  tempBuffer: Pbyte;
  Count: Integer;
begin
  tempBuffer := Buffer;
  for Count := 0 to Length div 4 - 1 do
  begin
    PDword(tempBuffer)^ := PDword(tempBuffer)
      ^ xor Dword(not(((Length div 4) - Count) + Length));
    inc(tempBuffer, 4);
  end;
end;

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
  indexs: Pack_Entries;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], sizeof(Pack_Head));
    if (Head.Entries_Length < FileBuffer.Size) and
      (Head.ENTRIES_COUNT < FileBuffer.Size) and
      (Head.ENTRIES_COUNT < Head.Entries_Length) then
    begin
      FileBuffer.Read(indexs.File_name[1], sizeof(Pack_Entries));
      IndexDecode(@indexs.File_name[1], sizeof(Pack_Entries));
      if ((indexs.START_OFFSET + indexs.Length) <
        FileBuffer.Size) and (indexs.Resverd = 0) then
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
  indexs: array of Pack_Entries;
  i: Integer;
  Rlentry: TRlEntry;
begin
  Result := true;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], sizeof(Pack_Head));
    // if not SameText(Trim(Head.Magic), Magic) then
    // raise Exception.Create('Magic Error.');
    if (Head.ENTRIES_COUNT * sizeof(Pack_Entries)) >
      FileBuffer.Size then
      raise Exception.Create('OVERFLOW');
    FileBuffer.Read(indexs[0].File_name[1], Head.Entries_Length);
    IndexDecode(@indexs[0].File_name[1], Head.Entries_Length);
    for i := 0 to Head.ENTRIES_COUNT - 1 do
    begin
      Rlentry := TRlEntry.Create;
      Rlentry.AName := Trim(indexs[i].File_name);
      Rlentry.AOffset := indexs[i].START_OFFSET;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs[i].Length;
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
