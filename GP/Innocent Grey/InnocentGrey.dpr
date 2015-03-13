library InnocentGrey;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  Windows,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas',
  StrUtils;

{$E GP}
{$R *.res}

Type
  Pack_Head = Packed Record
    Magic: array [0 .. 7] of AnsiChar;
    Dummy_Indexs: Cardinal;
    indexs: Cardinal;
  End;

  Pack_Entries = packed Record
    filename: array [1 .. 32] of AnsiChar;
    start_offset: Cardinal;
    EncodeFlag: Cardinal; // always $20000000?
    DecompressLen: Cardinal;
    length: Cardinal;
  End;

const
  Magic: AnsiString = 'PACKDAT.';

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Read(head.Magic[0], SizeOf(Pack_Head));
    if SameText(Trim(head.Magic), Magic) then
    begin
      if head.indexs < FileBuffer.Size then
      begin
        Result := dsTrue;
        Exit;
      end;
    end;
  except
    Result := dsError;
  end;
end;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('Innocent Grey',
    clGameMaker));
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  head: Pack_Head;
  indexs: Pack_Entries;
  i: integer;
  Rlentry: TRlEntry;
begin
  Result := True;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(head.Magic[0], SizeOf(Pack_Head));
    if not SameText(Trim(head.Magic), Magic) then
      raise Exception.Create('Magic Error.');

    for i := 0 to head.indexs - 1 do
    begin
      FileBuffer.Read(indexs.filename[1], SizeOf(Pack_Entries));
      Rlentry := TRlEntry.Create;
      Rlentry.AName := Trim(indexs.filename);
      Rlentry.AOffset := indexs.start_offset;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs.length;
      Rlentry.ARLength := indexs.DecompressLen;
      Rlentry.AKey := indexs.EncodeFlag;
      IndexStream.ADD(Rlentry);
    end;
  except
    Result := False;
  end;
end;

procedure Decode(Input, Output: TStream);
var
  key, tmp: Cardinal;
  shifts: Byte;
  i: integer;
begin
  key := Input.Size div 4;
  key := (key shl ((key and 7) + 8)) xor key;
  while Input.Position < Input.Size do
  begin
    Input.Read(tmp, 4);
    tmp := tmp xor key;
    shifts := Byte(tmp mod 24);
    key := (key shl shifts) or (key shr (32 - shifts));
    Output.Write(tmp, 4);
  end;
end;

procedure Decode2(Input: TStream);
var
  tmp: Byte;
  i: integer;
begin
  while Input.Position < Input.Size do
  begin
    Input.Read(tmp, 1);
    tmp := not tmp;
    Input.Seek(-1,soFromCurrent);
    Input.Write(tmp, 1);
  end;
end;

function ReadData(FileBuffer: TFileBufferStream;
  OutBuffer: TStream): LongInt;
var
  Buffer: TGlCompressBuffer;
begin
  Buffer := TGlCompressBuffer.Create;
  try
    FileBuffer.ReadData(Buffer);
    Buffer.Seek(0, soFromBeginning);
    if (FileBuffer.PrevEntry.AKey and $FFFFFF) <> 0 then
    begin
      if (FileBuffer.PrevEntry.AKey and $10000) <> 0 then
      begin
        Decode(Buffer, Buffer.Output);
      end;
    end
    else
      Buffer.Output.CopyFrom(Buffer, Buffer.Size);
    if CompareExt(FileBuffer.PrevEntry.AName, '.s') then
    begin
      Buffer.Output.Seek(0, soFromBeginning);
      Decode2(Buffer.Output);
    end;
    Buffer.Output.Seek(0, soFromBeginning);
    OutBuffer.CopyFrom(Buffer.Output, Buffer.Output.Size);
  finally
    Buffer.Free;
  end;
end;

function PackProcessData(Rlentry: TRlEntry;
  InputBuffer, FileOutBuffer: TStream): Boolean;
var
  Compr: TGlCompressBuffer;
begin
  Compr := TGlCompressBuffer.Create;
  try
    InputBuffer.Seek(0, soFromBeginning);
    Compr.CopyFrom(InputBuffer, InputBuffer.Size);
    if CompareExt(Rlentry.AName, '.s') then
    begin
      Compr.Seek(0, soFromBeginning);
      Decode2(Compr);
    end;
    Compr.Seek(0, soFromBeginning);
    with Rlentry do
    begin
      Rlentry.ARLength := Compr.Size;
      Rlentry.AStoreLength := Rlentry.ARLength;
      Rlentry.AOffset := FileOutBuffer.Position;
    end;
    FileOutBuffer.CopyFrom(Compr, Compr.Size);
  finally
    Compr.Free;
  end;
end;

function PackProcessIndex(IndexStream: TIndexStream;
  IndexOutBuffer: TStream): Boolean;
var
  indexs: array of Pack_Entries;
  i: integer;
begin
  SetLength(indexs, IndexStream.Count);
  ZeroMemory(@indexs[0].filename[1], IndexStream.Count *
    SizeOf(Pack_Entries));
  for i := 0 to IndexStream.Count - 1 do
  begin
    if length(IndexStream.Rlentry[i].AName) > 32 then
      raise Exception.Create('Filename too long.');
    Move(PByte(AnsiString(IndexStream.Rlentry[i].AName))^,
      indexs[i].filename[1],
      length(IndexStream.Rlentry[i].AName));
    indexs[i].DecompressLen := IndexStream.Rlentry[i].ARLength;
    indexs[i].start_offset := IndexStream.Rlentry[i].AOffset +
      IndexStream.Count * SizeOf(Pack_Entries) + SizeOf(Pack_head);
    indexs[i].length := IndexStream.Rlentry[i].AStoreLength;
    indexs[i].EncodeFlag := $20000000;
  end;
  IndexOutBuffer.Write(indexs[0].filename[1], IndexStream.Count *
    SizeOf(Pack_Entries));
end;

function MakePackage(IndexStream: TIndexStream;
  IndexOutBuffer, FileOutBuffer: TStream;
  Package: TFileBufferStream): Boolean;
var
  head: Pack_Head;
begin
  Move(PByte(Magic)^, head.Magic[0], length(Magic));
  head.indexs := IndexStream.Count;
  head.Dummy_Indexs := head.indexs;
  Package.Write(head.Magic[0], SizeOf(Pack_Head));
  IndexOutBuffer.Seek(0, soFromBeginning);
  Package.CopyFrom(IndexOutBuffer, IndexOutBuffer.Size);
  FileOutBuffer.Seek(0, soFromBeginning);
  Package.CopyFrom(FileOutBuffer, FileOutBuffer.Size);
end;

exports AutoDetect;

exports GetPluginName;

exports GenerateEntries;

exports ReadData;

exports PackProcessData;

exports PackProcessIndex;

exports MakePackage;

begin

end.
