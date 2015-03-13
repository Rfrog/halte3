library FrontWing;

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
    ENTRIES_COUNT: DWORD;
  End;

  Pack_Entries = packed Record
    file_name: array [1 .. $40] of ansichar;
    start_offset: DWORD;
    Decompressed_Length: DWORD;
    Length: DWORD;
    reserved: DWORD;
  End;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('Front Wing 3D ADV Engine1',
    clGameMaker));
end;

Procedure Decode(Buffer: Pbyte; Length: DWORD;
  decode_type: byte);
VAR
  AX, CX: byte;
  i: Integer;
  TEMP: DWORD;
begin
  for i := 0 to Length - 1 do
  BEGIN
    if Buffer[i] = $00 then
      Break;
    TEMP := $CCCCCCCC; // Pdword;
    AX := Buffer[i]; // byte
    AX := AX and $F0;
    AX := AX shr 4;
    Move(AX, TEMP, 1);
    CX := Buffer[i]; // byte
    CX := AX and $F;
    CX := AX shr 4;
    Move(CX, Pbyte(@TEMP)[1], 1);
    AX := AX xor CX;
    Buffer[i] := AX;
  END;
end;

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
  indexs: Pack_Entries;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.ENTRIES_COUNT, sizeof(Pack_Head));
    if (Head.ENTRIES_COUNT < FileBuffer.Size) then
    begin
      FileBuffer.Read(indexs.file_name[1], sizeof(Pack_Entries));
      Decode(@indexs.file_name[1], $40, 0);
      if ((indexs.start_offset + indexs.Length) <
        FileBuffer.Size) and (indexs.reserved = 0) then
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
  Result := true;
  try
    FileBuffer.Seek(-sizeof(Pack_Head), soFromEnd);
    FileBuffer.Read(Head.ENTRIES_COUNT, sizeof(Pack_Head));
    if (Head.ENTRIES_COUNT * sizeof(Pack_Entries)) >
      FileBuffer.Size then
      raise Exception.Create('OVERFLOW');
    FileBuffer.Seek(-(sizeof(Pack_Head) + (Head.ENTRIES_COUNT *
      sizeof(Pack_Entries))), soFromEnd);
    for i := 0 to Head.ENTRIES_COUNT - 1 do
    begin
      FileBuffer.Read(indexs.file_name[1], sizeof(Pack_Entries));
      Decode(@indexs.file_name[1], $40, 0);
      Rlentry := TRlEntry.Create;
      Rlentry.AName := Trim(indexs.file_name);
      Rlentry.AOffset := indexs.start_offset;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs.Length;
      Rlentry.ARLength := indexs.Decompressed_Length;
      if (Rlentry.AOffset + Rlentry.AStoreLength) >
        FileBuffer.Size then
        raise Exception.Create('OverFlow');
      IndexStream.add(Rlentry);
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
  Tmp: array [0 .. $18] of byte;
begin
  Result := FileBuffer.ReadData(OutBuffer);
  FileBuffer.EntrySelected := FileBuffer.EntrySelected - 1;
  if FileBuffer.Rlentry.ARLength <> 0 then
  begin
    OutBuffer.Seek(0, soFromBeginning);
    OutBuffer.Read(Tmp[0], $19);
    Decode(@Tmp[0], $19, 0);
    OutBuffer.Seek(0, soFromBeginning);
    OutBuffer.Write(Tmp[0], $19);
    OutBuffer.Seek(0, soFromBeginning);
    decompr := TGlCompressBuffer.Create;
    decompr.CopyFrom(OutBuffer, OutBuffer.Size);
    decompr.Seek(0, soFromBeginning);
    decompr.Seek(0, soFromBeginning);
    decompr.Output.Seek(0, soFromBeginning);
    decompr.ZlibDecompress(FileBuffer.Rlentry.ARLength);
    decompr.Output.Seek(0, soFromBeginning);
    OutBuffer.Size := 0;
    OutBuffer.Seek(0, soFromBeginning);
    OutBuffer.CopyFrom(decompr.Output, decompr.Output.Size);
  end;
  FileBuffer.EntrySelected := FileBuffer.EntrySelected + 1;
end;

exports AutoDetect;

exports GetPluginName;

exports GenerateEntries;

exports Decyption;

exports ReadData;

begin

end.
