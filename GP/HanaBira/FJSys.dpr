library FJSys;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  Windows,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas',
  StrUtils,
  md5,
  Vcl.Dialogs;

{$E GP}
{$R *.res}


Type
  Pack_Head = Packed Record
    Magic: array [ 0 .. 7 ] of ansichar;
    Data_Offset: cardinal;
    Name_Table_Length: cardinal;
    indexs: cardinal;
    pad: array [ 0 .. 15 ] of cardinal;
  End;

  Pack_Entries = packed Record
    Name_offset: cardinal;
    length: cardinal;
    start_offset: cardinal;
    Reserved: cardinal;
  End;

const
  Magic: AnsiString = 'FJSYS';

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Read(head.Magic[ 0 ], SizeOf(Pack_Head));
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
  Result := PChar(FormatPluginName('FJSystem',
    clEngine));
end;

var
  Key: AnsiString = '‚»‚Ì‰Ô‚Ñ‚ç‚É‚­‚¿‚Ã‚¯‚ð';

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  head: Pack_Head;
  indexs: array of Pack_Entries;
  i: integer;
  Rlentry: TRlEntry;
  FileName: PAnsiChar;
begin
  Result := True;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(head.Magic[ 0 ], SizeOf(Pack_Head));
    if not SameText(Trim(head.Magic), Magic) then
      raise Exception.Create('Magic Error.');
    if SameText(ExtractFileName(FileBuffer.FileName), 'MSD') then
      Key := InputBox('Key', 'Input key', Key);
    FileName := SysGetMem(head.Name_Table_Length);
    SetLength(indexs, head.indexs);
    FileBuffer.Read(indexs[ 0 ].Name_offset, SizeOf(Pack_Entries) *
      head.indexs);
    FileBuffer.Read(PByte(FileName)[ 0 ], head.Name_Table_Length);
    try
      for i := 0 to head.indexs - 1 do
      begin
        Rlentry := TRlEntry.Create;
        Rlentry.AName :=
          Trim(PAnsiChar(@FileName[ indexs[ i ].Name_offset ]));
        Rlentry.AOffset := indexs[ i ].start_offset;
        Rlentry.AOrigin := soFromBeginning;
        Rlentry.AStoreLength := indexs[ i ].length;
        Rlentry.ARLength := indexs[ i ].length;
        IndexStream.ADD(Rlentry);
      end;
    finally
      SysFreeMem(FileName);
    end;
  except
    Result := False;
  end;
end;

function GetStr(Buf: TStream): AnsiString;
var
  B: Byte;
  _pos, _size: integer;
begin
  B := 1;
  _pos := Buf.Position;
  while B <> $0 do
    Buf.Read(B, 1);
  _size := Buf.Position - _pos;
  Buf.Seek(_pos, soFromBeginning);
  SetLength(Result, _size);
  Buf.Read(PByte(Result)^, _size);
end;

function ReadData(FileBuffer: TFileBufferStream;
  OutBuffer: TStream): LongInt;
var
  Buffer: TGlCompressBuffer;
  MD5Buffer, MD5Result: AnsiString;
  i, j: integer;
begin
  Buffer := TGlCompressBuffer.Create;
  try
    if SameText(ExtractFileExt(FileBuffer.Rlentry.AName), '.msd') then
    begin
      Buffer.Output.Clear;
      FileBuffer.ReadData(Buffer);
      Buffer.Seek(0, soFromBeginning);
      SetLength(MD5Buffer, $20);
      for i := 0 to (Buffer.Size div $20) - 1 do
      begin
        Buffer.Read(PByte(MD5Buffer)^, $20);
        MD5Result := MD5S(format('%s%d', [ Key, i ]));
        for j := 0 to $20 - 1 do
        begin
          PByte(MD5Buffer)[ j ] := PByte(MD5Buffer)
            [ j ] xor PByte(MD5Result)[ j ];
        end;
        Buffer.Output.Write(PByte(MD5Buffer)^, $20);
      end;
      MD5Result := MD5S(format('%s%d', [ Key, i ]));
      i := Buffer.Size - Buffer.Position;
      Buffer.Read(PByte(MD5Buffer)^, i);
      for j := 0 to i - 1 do
      begin
        PByte(MD5Buffer)[ j ] := PByte(MD5Buffer)
          [ j ] xor PByte(MD5Result)[ j ];
      end;
      Buffer.Output.Write(PByte(MD5Buffer)^, i);
      Buffer.Output.Seek(0, soFromBeginning);
      OutBuffer.CopyFrom(Buffer.Output, Buffer.Output.Size);
    end else
      if SameText(ExtractFileExt(FileBuffer.Rlentry.AName), '.mgd') then
    begin
      FileBuffer.ReadData(Buffer);
      Buffer.Seek($60, soFromBeginning);
      Buffer.Output.Seek(0, soFromBeginning);
      Buffer.Output.CopyFrom(Buffer, Buffer.Size - Buffer.Position);
      Buffer.Output.Seek(0, soFromBeginning);
      OutBuffer.CopyFrom(Buffer.Output, Buffer.Output.Size);
    end
    else
      FileBuffer.ReadData(OutBuffer);
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
  ZeroMemory(@indexs[ 0 ].Name_offset, IndexStream.Count *
    SizeOf(Pack_Entries));
  for i := 0 to IndexStream.Count - 1 do
  begin
    if length(IndexStream.Rlentry[ i ].AName) > 32 then
      raise Exception.Create('Filename too long.');
    Move(PByte(AnsiString(IndexStream.Rlentry[ i ].AName))^,
      indexs[ i ].Name_offset,
      length(IndexStream.Rlentry[ i ].AName));
    indexs[ i ].start_offset := IndexStream.Rlentry[ i ].AOffset +
      IndexStream.Count * SizeOf(Pack_Entries) + SizeOf(Pack_Head);
    indexs[ i ].length := IndexStream.Rlentry[ i ].AStoreLength;
  end;
  IndexOutBuffer.Write(indexs[ 0 ].Name_offset, IndexStream.Count *
    SizeOf(Pack_Entries));
end;

function MakePackage(IndexStream: TIndexStream;
  IndexOutBuffer, FileOutBuffer: TStream;
  Package: TFileBufferStream): Boolean;
var
  head: Pack_Head;
begin
  Move(PByte(Magic)^, head.Magic[ 0 ], length(Magic));
  head.indexs := IndexStream.Count;
Package.Write(head.Magic[ 0 ], SizeOf(Pack_Head));
IndexOutBuffer.Seek(0, soFromBeginning);
Package.CopyFrom(IndexOutBuffer, IndexOutBuffer.Size);
FileOutBuffer.Seek(0, soFromBeginning);
Package.CopyFrom(FileOutBuffer, FileOutBuffer.Size);
end;

exports
  AutoDetect;

exports
  GetPluginName;

exports
  GenerateEntries;

exports
  ReadData;

begin

end.
