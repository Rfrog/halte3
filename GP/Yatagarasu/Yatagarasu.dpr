library Yatagarasu;

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
    PackageSize: Cardinal;
    Indexs: Cardinal;
  End;

  Pack_Entries = Packed Record
    Name: array [1 .. $80] of AnsiChar;
    Length: Cardinal;
    START_OFFSET: Cardinal;
  End;

const
  Xor_Pad: array [0 .. 3] of Byte = ($C5, $F7, $A5, $91);

procedure Decode(Buffer: TStream; Rlength: Cardinal); overload;
var
  pos: int64;
  tmp2: Byte;
  i: Integer;
begin
  pos := Buffer.Position;
  Buffer.Seek(0, soFromBeginning);
  while Buffer.Position < Rlength do
  begin
    Buffer.Read(tmp2, 1);
    Buffer.Seek(-1, soFromCurrent);
    tmp2 := tmp2 xor Xor_Pad[Buffer.Position mod 4];
    Buffer.Write(tmp2, 1);
  end;
  for i := 0 to Buffer.Size - Rlength do
  begin
    Buffer.Read(tmp2, 1);
    Buffer.Seek(-1, soFromCurrent);
    tmp2 := tmp2 xor Xor_Pad[Buffer.Position mod 4];
    Buffer.Write(tmp2, 1);
  end;

  Buffer.Seek(pos, soFromBeginning);
end;

procedure Decode(Buffer: PByte; Size: Cardinal); overload;
var
  i: Integer;
begin
  for i := 0 to Size - 1 do
  begin
    Buffer[i] := Buffer[i] xor Xor_Pad[i mod 4];
  end;
end;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('Yatagarasu', clGameMaker));
end;

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.PackageSize, sizeof(Pack_Head));
    if ((Head.PackageSize xor $91A5F7C5) = FileBuffer.Size) and
      ((Head.Indexs xor $91A5F7C5) < FileBuffer.Size) then
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
  Indexs: Pack_Entries;
  i: Integer;
  Rlentry: TRlEntry;
begin
  Result := true;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.PackageSize, sizeof(Pack_Head));
    Head.PackageSize := Head.PackageSize xor $91A5F7C5;
    Head.Indexs := Head.Indexs xor $91A5F7C5;
    if Head.PackageSize > FileBuffer.Size then
      raise Exception.Create('OVERFLOW');
    for i := 0 to Head.Indexs - 1 do
    begin
      FileBuffer.Read(Indexs.Name[1], sizeof(Pack_Entries));
      Decode(@Indexs.Name[1], sizeof(Pack_Entries));
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

// 004E7327   .^\7C E7         JL SHORT 004E7310

function ReadData(FileBuffer: TFileBufferStream;
  OutBuffer: TStream): LongInt;
begin
  FileBuffer.Seek(FileBuffer.Rlentry.AOffset,
    FileBuffer.Rlentry.AOrigin);
  if (FileBuffer.Rlentry.AStoreLength mod 4) = 0 then
    Result := OutBuffer.CopyFrom(FileBuffer,
      FileBuffer.Rlentry.AStoreLength)
  else
    Result := OutBuffer.CopyFrom(FileBuffer,
      FileBuffer.Rlentry.AStoreLength + 4 -
      (FileBuffer.Rlentry.AStoreLength mod 4));
  Decode(OutBuffer, FileBuffer.Rlentry.AStoreLength);
  OutBuffer.Size := FileBuffer.Rlentry.AStoreLength;
  FileBuffer.EntrySelected := FileBuffer.EntrySelected + 1;
end;

function PackData(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream; var Percent: word): Boolean;
var
  Head: Pack_Head;
  Indexs: array of Pack_Entries;
  i: Integer;
  tmpStream: TmemoryStream;
  tmpsize: Cardinal;
  zero: Byte;
begin
  Result := true;
  try
    Percent := 0;
    Head.Indexs := IndexStream.Count;
    SetLength(Indexs, Head.Indexs);
    ZeroMemory(@Indexs[0].Name[1],
      Head.Indexs * sizeof(Pack_Entries));
    tmpsize := sizeof(Pack_Head) + Head.Indexs *
      sizeof(Pack_Entries);
    for i := 0 to Head.Indexs - 1 do
    begin
      if Length(IndexStream.Rlentry[i].AName) > 80 then
        raise Exception.Create('Name too long.');
      Move(PByte(AnsiString(IndexStream.Rlentry[i].AName))^,
        Indexs[i].Name[1], Length(IndexStream.Rlentry[i].AName));
      Indexs[i].START_OFFSET := tmpsize;
      Indexs[i].Length := IndexStream.Rlentry[i].ARLength;
      if Indexs[i].Length mod 4 <> 0 then
        tmpsize := tmpsize + Indexs[i].Length + 4 -
          (Indexs[i].Length mod 4)
      else
        tmpsize := tmpsize + Indexs[i].Length;
      Percent := 10 * (i + 1) div Head.Indexs;
    end;
    Head.PackageSize := tmpsize;
    Decode(@Indexs[0].Name[1], Head.Indexs *
      sizeof(Pack_Entries));
    Decode(@Head.PackageSize, sizeof(Pack_Head));
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Write(Head.PackageSize, sizeof(Pack_Head));
    Decode(@Head.PackageSize, sizeof(Pack_Head));
    FileBuffer.Write(Indexs[0].Name[1],
      Head.Indexs * sizeof(Pack_Entries));
    Decode(@Indexs[0].Name[1], Head.Indexs *
      sizeof(Pack_Entries));
    tmpStream := TmemoryStream.Create;
    zero := 0;
    for i := 0 to Head.Indexs - 1 do
    begin
      tmpStream.LoadFromFile(IndexStream.ParentPath +
        IndexStream.Rlentry[i].AName);
      tmpStream.Seek(0, soFromEnd);
      while tmpStream.Size mod 4 <> 0 do
        tmpStream.Write(zero, 1);
      Decode(tmpStream, Indexs[i].Length);
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

exports PackData;

begin

end.
