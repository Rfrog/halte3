library Noesis;

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
    Magic: ARRAY [0 .. $3] OF ANSICHAR;
    Hash: Cardinal;    //?
    Major_Ver: Cardinal;
    Minor_Ver: Cardinal;
  End;

  Index_Head = record
    IndexLength: Cardinal;
    NameLength: Cardinal;
  end;

  Pack_Entries = Packed Record
    Name_Offset: Cardinal;
    START_OFFSET: Cardinal;
    Length: Cardinal;
  End;

Const
  Magic: Ansistring = 'IGA0';

function GetCode(Buffer: TStream): Cardinal;
var
  tmp: byte;
begin
  Result := 0;
  while (Result and 1) = 0 do
  begin
    Buffer.Read(tmp, 1);
    Result := (Result shl 7) or tmp;
  end;
  Result := Result shr 1;
end;

procedure Decode(Buffer: TStream);
var
  pos: int64;
  tmp: byte;
begin
  pos := Buffer.Position;
  Buffer.Seek(0, soFromBeginning);
  while Buffer.Position < Buffer.Size do
  begin
    Buffer.Read(tmp, 1);
    tmp := tmp xor (Buffer.Position + 1);
    Buffer.Seek(-1, soFromCurrent);
    Buffer.Write(tmp, 1);
  end;
  Buffer.Seek(pos, soFromBeginning);
end;

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], sizeof(Pack_Head));
    if SameText(Trim(Head.Magic), Magic)then
    begin
      Result := dsTrue;
    end;
  except
    Result := dsError;
  end;
end;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName
    ('Noesis', clGameMaker));
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  Head: Pack_Head;
  IndexHead: Index_Head;
  indexs: array of Pack_Entries;
  i, j, z: Integer;
  Rlentry: TRlEntry;
  Name: Ansistring;
begin
  Result := true;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], SizeOf(Pack_Head));
    if not SameText(Trim(Head.Magic), Magic) then
      raise Exception.Create('Magic Error.');
    IndexHead.IndexLength := GetCode(FileBuffer);
    if IndexHead.IndexLength > FileBuffer.Size then
      raise Exception.Create('OVERFLOW');
    z := FileBuffer.Position + IndexHead.IndexLength;
    i := 0;
    while FileBuffer.Position < z do
    begin
      SetLength(indexs, i + 1);
      indexs[i].Name_Offset := GetCode(FileBuffer);
      indexs[i].START_OFFSET := GetCode(FileBuffer);
      indexs[i].Length := GetCode(FileBuffer);
      i := i + 1;
    end;
    indexs[i].Name_Offset := GetCode(FileBuffer);
    z := FileBuffer.Size - (indexs[i - 1].START_OFFSET +
      indexs[i - 1].Length);
    for i := 0 to IndexHead.IndexLength div SizeOf
      (Pack_Entries) - 1 do
    begin
      Rlentry := TRlEntry.Create;
      SetLength(Name, indexs[i + 1].Name_Offset - indexs[i]
        .Name_Offset);
      for j := 0 to indexs[i + 1].Name_Offset - indexs[i]
        .Name_Offset - 1 do
      begin
        PByte(Name)[j] := byte(GetCode(FileBuffer));
      end;
      Rlentry.AName := Trim(Name);
      Rlentry.AOffset := indexs[i].START_OFFSET + z;
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
  Decode(OutBuffer);
end;

exports AutoDetect;

exports GetPluginName;

exports GenerateEntries;

exports Decyption;

exports ReadData;

begin

end.
