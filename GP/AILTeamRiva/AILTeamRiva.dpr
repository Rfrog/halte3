library AILTeamRiva;

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
    indexs: Cardinal;
  End;

  Pack_Entries = packed Record
    Length: Cardinal;
  End;

  data_head = packed record
    fileType: Word;
    decompressedLength: Cardinal;
  end;

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
  indexs: array [0 .. 1] of Pack_Entries;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.indexs, SizeOf(Pack_Head));
    if Head.indexs * SizeOf(Pack_Entries) <
      (FileBuffer.Size - FileBuffer.Position) then
    begin
      FileBuffer.Read(indexs[0].Length, 8);
      if (indexs[0].Length < (FileBuffer.Size - Head.indexs *
        SizeOf(Pack_Entries))) and
        (indexs[1].Length < (FileBuffer.Size - Head.indexs *
        SizeOf(Pack_Entries))) then
        Result := dsUnknown;
    end;
  except
    Result := dsError;
  end;
end;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('AIL Team·Riva',
    clGameMaker));
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  Head: Pack_Head;
  indexs: Pack_Entries;
  i: Integer;
  Rlentry: TRlEntry;
  lstLng: Cardinal;
begin
  Result := True;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.indexs, SizeOf(Pack_Head));
    lstLng := Head.indexs * 4 + 4;
    for i := 0 to Head.indexs - 1 do
    begin
      FileBuffer.Read(indexs.Length, 4);
      Rlentry := TRlEntry.Create;
      Rlentry.AOffset := lstLng;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs.Length;
      Rlentry.ARLength := 0;
      Rlentry.AName := '$' + IntToHex(i, 8);
      IndexStream.Add(Rlentry);
      lstLng := lstLng + indexs.Length;
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
  FileBuffer: TFileBufferStream; var Percent: Word): Boolean;
var
  i: Integer;
  Head: Pack_Head;
  indexs: Pack_Entries;
  tmpBuffer: TFileStream;
begin
  Result := True;
  try
    Percent := 0;
    FileBuffer.Seek(0, soFromBeginning);
    Head.indexs := IndexStream.Count;
    FileBuffer.Write(Head.indexs, 4);
    for i := 0 to IndexStream.Count - 1 do
    begin
      indexs.Length := IndexStream.Rlentry[i].ARLength;
      FileBuffer.Write(indexs.Length, 4);
      Percent := 50 * (i + 1) div IndexStream.Count;
    end;
    for i := 0 to IndexStream.Count - 1 do
    begin
      tmpBuffer := TFileStream.Create(IndexStream.ParentPath +
        IndexStream.Rlentry[i].AName, fmOpenRead);
      tmpBuffer.Seek(0, soFromBeginning);
      FileBuffer.CopyFrom(tmpBuffer, tmpBuffer.Size);
      tmpBuffer.Free;
      Percent := 100 * (i + 1) div IndexStream.Count;
    end;
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
