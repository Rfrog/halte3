library TDManiac;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  StrUtils,
  Windows,
  CustomStream in '..\..\..\Core\CustomStream.pas',
  PluginFunc in '..\..\..\Core\PluginFunc.pas',
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas';

{$E gp}
{$R *.res}

Type
  Pack_Head = Packed Record
    Magic: Dword;
    Entries_Count: Dword;
    Entries_End_Offset: Dword;
  End;

  Pack_Entries = Record
    file_name: string;
    length: Dword;
    start_offset: Dword;
  End;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('2D Maniac', clGameMaker));
end;

function GetRealName(const Buffer: TMemoryStream): Ansistring;
var
  I: LongInt;
  tmp: Byte;
begin
  I := Buffer.Position;
  Result := '';
  Buffer.Read(tmp, 1);
  while tmp <> $2F do
    Buffer.Read(tmp, 1);
  I := Buffer.Position - I;
  SetLength(Result, I);
  Buffer.Seek(-I, soFromCurrent);
  Buffer.Read(PByte(Result)^, I);
end;

const Magic: Cardinal = 0;

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic, SizeOf(Pack_Head));
    if (Head.Magic = MAGIC) and
      (Head.Entries_Count < FileBuffer.Size) and
      (Head.Entries_End_Offset < FileBuffer.Size) then
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
  Head: Pack_Head;
  indexs: Pack_Entries;
  I: Integer;
  Rlentry: TRlEntry;
  TmpBuffer: TMemoryStream;
begin
  Result := True;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic, SizeOf(Pack_Head));
    TmpBuffer := TMemoryStream.Create;
    TmpBuffer.CopyFrom(FileBuffer, Head.Entries_End_Offset -
      SizeOf(Pack_Head));
    for I := 0 to Head.Entries_Count - 1 do
    begin
      indexs.file_name := GetRealName(TmpBuffer);
      TmpBuffer.Read(indexs.length, 4);
      TmpBuffer.Read(indexs.start_offset, 4);
      Rlentry := TRlEntry.Create;
      Rlentry.AOffset := indexs.start_offset;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs.length;
      Rlentry.ARLength := 0;
      Rlentry.AName := indexs.file_name;
      IndexStream.Add(Rlentry);
    end;
    TmpBuffer.Free;
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
  I: Integer;
  Head: Pack_Head;
  indexs: array of Pack_Entries;
  TmpBuffer: TFileStream;
  zero: Byte;
begin
  Result := True;
  try
    Percent := 0;
    FileBuffer.Seek(0, soFromBeginning);
    Head.Entries_Count := IndexStream.Count;
    Move(PByte(Magic)^, Head.Magic, 4);
    FileBuffer.Write(Head.Magic, SizeOf(Pack_Head));
    zero := 0;
    SetLength(indexs, IndexStream.Count);
    while FileBuffer.Size < $800 do
      FileBuffer.Write(zero, 1);
    for I := 0 to IndexStream.Count - 1 do
    begin
      TmpBuffer := TFileStream.Create(IndexStream.ParentPath +
        IndexStream.Rlentry[I].AName, fmOpenRead);
      indexs[I].start_offset := FileBuffer.Position;
      indexs[I].length := TmpBuffer.Size;
      TmpBuffer.Seek(0, soFromBeginning);
      FileBuffer.CopyFrom(TmpBuffer, TmpBuffer.Size);
      TmpBuffer.Free;
      Percent := 90 * (I + 1) div IndexStream.Count;
    end;
    for I := 0 to IndexStream.Count - 1 do
    begin
      FileBuffer.Write(indexs[I].start_offset, 8);
      Percent := 90 + 10 * (I + 1) div IndexStream.Count;
    end;
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Write(Head.Magic, SizeOf(Pack_Head));
  except
    Result := False;
  end;
end;

exports GetPluginName;

exports GenerateEntries;

exports Decyption;

exports ReadData;

begin

end.
