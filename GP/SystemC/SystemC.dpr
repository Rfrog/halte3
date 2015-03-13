library SystemC;

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
    Indexs: Cardinal;
    Xor_Key: Cardinal;
    indexsOffset: Cardinal;
  End;

  Pack_Entries = packed Record
    start_offset: Cardinal;
    length: Cardinal;
    filename: array [ 1 .. $18 ] of AnsiChar;
    Hash: Word;
    flag: Word;
  End;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('SystemC',
    clGameMaker));
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  head: Pack_Head;
  Indexs: Pack_Entries;
  i, j: integer;
  Rlentry: TRlEntry;
begin
  Result := True;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(head.Indexs, 4);
    if integer(head.Indexs) < 0 then
    begin
      FileBuffer.Seek(-8, soFromEnd);
      FileBuffer.Read(head.Xor_Key, 8);
      FileBuffer.Seek(head.indexsOffset, soFromBeginning);
    end;
    head.Indexs := head.Indexs and $00FFFFFF;
    for i := 0 to head.Indexs - 1 do
    begin
      FileBuffer.Read(Indexs.start_offset, SizeOf(Pack_Entries));
      for j := 0 to SizeOf(Pack_Entries) div 4 - 1 do
        PCardinal(@PByte(@Indexs.start_offset)[ j * 4 ])^ :=
          PCardinal(@PByte(@Indexs.start_offset)[ j * 4 ])^ xor head.Xor_Key;
      Rlentry := TRlEntry.Create;
      Rlentry.AName := Trim(Indexs.filename);
      Rlentry.AOffset := Indexs.start_offset;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := Indexs.length;
      Rlentry.ARLength := Indexs.length;
      Rlentry.AKey := indexs.flag;
      Rlentry.AKey2 := indexs.Hash;
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
begin
  while Input.Position < Input.Size do
  begin
    Input.Read(tmp, 1);
    tmp := not tmp;
    Input.Seek(-1, soFromCurrent);
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
    Buffer.Output.CopyFrom(Buffer, Buffer.Size);
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
  Indexs: array of Pack_Entries;
  i: integer;
begin
  SetLength(Indexs, IndexStream.Count);
  ZeroMemory(@Indexs[ 0 ].filename[ 1 ], IndexStream.Count *
    SizeOf(Pack_Entries));
  for i := 0 to IndexStream.Count - 1 do
  begin
    if length(IndexStream.Rlentry[ i ].AName) > 32 then
      raise Exception.Create('Filename too long.');
    Move(PByte(AnsiString(IndexStream.Rlentry[ i ].AName))^,
      Indexs[ i ].filename[ 1 ],
      length(IndexStream.Rlentry[ i ].AName));
    Indexs[ i ].start_offset := IndexStream.Rlentry[ i ].AOffset +
      IndexStream.Count * SizeOf(Pack_Entries) + SizeOf(Pack_Head);
    Indexs[ i ].length := IndexStream.Rlentry[ i ].AStoreLength;
  end;
  IndexOutBuffer.Write(Indexs[ 0 ].filename[ 1 ], IndexStream.Count *
    SizeOf(Pack_Entries));
end;

function MakePackage(IndexStream: TIndexStream;
  IndexOutBuffer, FileOutBuffer: TStream;
  Package: TFileBufferStream): Boolean;
var
  head: Pack_Head;
begin
  head.Indexs := IndexStream.Count;
Package.Write(head.Indexs, SizeOf(Pack_Head));
IndexOutBuffer.Seek(0, soFromBeginning);
Package.CopyFrom(IndexOutBuffer, IndexOutBuffer.Size);
FileOutBuffer.Seek(0, soFromBeginning);
Package.CopyFrom(FileOutBuffer, FileOutBuffer.Size);
end;

exports
  GetPluginName;

exports
  GenerateEntries;

exports
  ReadData;

exports
  PackProcessData;

exports
  PackProcessIndex;

exports
  MakePackage;

begin

end.
