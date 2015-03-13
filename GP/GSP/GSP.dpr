library GSP;

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
    indexs: Cardinal;
  End;

  Pack_Entries = packed Record
    start_offset: Cardinal;
    length: Cardinal;
    filename: array [ 1 .. $38 ] of AnsiChar;
  End;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('Unknow.GSP',
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
    FileBuffer.Read(head.indexs, SizeOf(Pack_Head));

    for i := 0 to head.indexs - 1 do
    begin
      FileBuffer.Read(indexs.start_offset, SizeOf(Pack_Entries));
      Rlentry := TRlEntry.Create;
      Rlentry.AName := Trim(indexs.filename);
      Rlentry.AOffset := indexs.start_offset;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs.length;
      Rlentry.ARLength := indexs.length;
      IndexStream.ADD(Rlentry);
    end;
  except
    Result := False;
  end;
end;

procedure Decode(Buf: TStream);
var
  b: Byte;
begin
  while Buf.Position < Buf.Size do
  begin
    Buf.Read(b, 1);
    b := b xor $FF;
    Buf.Seek(-1, soFromCurrent);
    Buf.Write(b, 1);
  end;
end;

function ReadData(FileBuffer: TFileBufferStream;
  OutBuffer: TStream): LongInt;
var
  Buffer: TGlCompressBuffer;
  magic: array [ 0 .. 3 ] of AnsiChar;
  decompr: Cardinal;
begin
  Buffer := TGlCompressBuffer.Create;
  try
    FileBuffer.ReadData(Buffer);
    Buffer.Seek(0, soFromBeginning);
    Buffer.Output.CopyFrom(Buffer, Buffer.Size);
    if CompareExt(FileBuffer.PrevEntry.AName, '.bmz') then
    begin
      Buffer.Output.Seek(0, soFromBeginning);
      Buffer.Output.Read(magic[ 0 ], 4);
      Buffer.Output.Read(decompr, 4);
      Buffer.Size := 0;
      Buffer.CopyFrom(Buffer.Output, Buffer.Output.Size -
        Buffer.Output.Position);
      Buffer.Output.Clear;
      Buffer.ZlibDecompress(decompr);
      Buffer.Output.Seek(0, soFromBeginning);
    end else
      if CompareExt(FileBuffer.PrevEntry.AName, '.spt') then
    begin
      Buffer.Output.Seek(0, soFromBeginning);
      Decode(Buffer.Output);
      Buffer.Output.Seek(0, soFromBeginning);
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
  magic: array [ 0 .. 3 ] of AnsiChar;
  decompr: Cardinal;
begin
  Compr := TGlCompressBuffer.Create;
  try
    InputBuffer.Seek(0, soFromBeginning);
    Compr.CopyFrom(InputBuffer, InputBuffer.Size);
    if CompareExt(Rlentry.AName, '.bmz') then
    begin
      Compr.Seek(0, soFromBeginning);

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
  ZeroMemory(@indexs[ 0 ].filename[ 1 ], IndexStream.Count *
    SizeOf(Pack_Entries));
  for i := 0 to IndexStream.Count - 1 do
  begin
    if length(IndexStream.Rlentry[ i ].AName) > 32 then
      raise Exception.Create('Filename too long.');
    Move(PByte(AnsiString(IndexStream.Rlentry[ i ].AName))^,
      indexs[ i ].filename[ 1 ],
      length(IndexStream.Rlentry[ i ].AName));
    indexs[ i ].start_offset := IndexStream.Rlentry[ i ].AOffset +
      IndexStream.Count * SizeOf(Pack_Entries) + SizeOf(Pack_Head);
    indexs[ i ].length := IndexStream.Rlentry[ i ].AStoreLength;
  end;
  IndexOutBuffer.Write(indexs[ 0 ].filename[ 1 ], IndexStream.Count *
    SizeOf(Pack_Entries));
end;

function MakePackage(IndexStream: TIndexStream;
  IndexOutBuffer, FileOutBuffer: TStream;
  Package: TFileBufferStream): Boolean;
var
  head: Pack_Head;
begin
  head.indexs := IndexStream.Count;
Package.Write(head.indexs, SizeOf(Pack_Head));
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
