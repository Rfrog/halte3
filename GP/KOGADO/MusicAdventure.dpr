library MusicAdventure;

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
    Magic: array [0 .. 5] of AnsiChar;
    version: Word;
    Index_Offset: Cardinal;
    Indexs: Cardinal;
  End;

  Pack_Entries = Packed Record
    Name: array [1 .. $15] of AnsiChar;
    Extension: array [1 .. 3] of AnsiChar;
    START_OFFSET: Cardinal;
    Length: Cardinal;
    StoreLen: Cardinal;
    flag: Byte;
    hash_flag: Byte;
    hash: Word;
    Time: FILETIME;
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
  Result := PChar(FormatPluginName
    ('HyPack', clEngine));
end;

const
  Magic = 'HyPack';

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], sizeof(Pack_Head));
    if SameText(Trim(Head.Magic), Magic) and
      (Head.Index_Offset < FileBuffer.Size) and
      (Head.indexs < FileBuffer.Size) then
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
    FileBuffer.Read(Head.Magic[0], SizeOf(Pack_Head));
    if not SameText(Trim(Head.Magic), Magic) then
      raise Exception.Create('Magic Error.');
    FileBuffer.Seek(Head.Index_Offset + SizeOf(Pack_Head),
      soFromBeginning);
    for i := 0 to Head.Indexs - 1 do
    begin
      FileBuffer.Read(Indexs.Name[1], SizeOf(Pack_Entries));
      Rlentry := TRlEntry.Create;
      Rlentry.AName := Trim(Indexs.Name)+'.'+Trim(indexs.Extension);
      Rlentry.AOffset := Indexs.START_OFFSET + SizeOf(pack_head);
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := Indexs.StoreLen;
      Rlentry.ARLength := Indexs.Length;
      Rlentry.AHash[0] := Indexs.hash;
      Rlentry.AKey := Indexs.flag;
      Rlentry.AKey2 := Indexs.hash_flag;
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
  FileBuffer: TFileBufferStream; var Percent: Word): Boolean;
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

{exports PackData;}

begin

end.
