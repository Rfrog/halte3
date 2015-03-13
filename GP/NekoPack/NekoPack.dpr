library NekoPack;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  Windows,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas',
  StrUtils {$IFDEF debug},
  codesitelogging {$ENDIF};

{$E GP}

Type
  Pack_Head = Packed Record
    Magic: array [0 .. 9] of AnsiChar;
    indexs: Cardinal;
  End;

  Pack_Entries = packed Record
    NameLen: Cardinal;
    filename: AnsiString;
    start_offset: Cardinal;
    length: Cardinal;
  End;

const
  Magic: AnsiString = 'NEKOPACK4A';

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Read(head.Magic[0], SizeOf(Pack_Head));
    if (head.indexs < FileBuffer.Size) and (SameText(Trim(head.Magic), Magic))
    then
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
  Result := PChar(FormatPluginName('NekoPack', clGameMaker));
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  head: Pack_Head;
  indexs: Pack_Entries;
  i, j: integer;
  Rlentry: TRlEntry;
  key: Cardinal;
begin
  Result := True;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(head.Magic[0], SizeOf(Pack_Head));

    if not((head.indexs < FileBuffer.Size) and (SameText(Trim(head.Magic),
      Magic))) then
      raise Exception.Create('Magic error.');

    i := 1;
    while i < head.indexs do
    begin
      FileBuffer.Read(indexs.NameLen, $4);
      if indexs.NameLen = 0 then
        Break;
      SetLength(indexs.filename, indexs.NameLen);
      FileBuffer.Read(PByte(indexs.filename)^, indexs.NameLen);
      FileBuffer.Read(indexs.start_offset, $8);
      i := i + $4 + indexs.NameLen + $8;
      key := 0;
      for j := 0 to indexs.NameLen - 1 do
        key := key + PByte(indexs.filename)[j];
      Rlentry := TRlEntry.Create;
      Rlentry.AName := Trim(indexs.filename);
      Rlentry.AOffset := indexs.start_offset xor key;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs.length xor key;
      Rlentry.ARLength := indexs.length xor key;
      Rlentry.AKey := indexs.length xor key;
      IndexStream.ADD(Rlentry);

{$IFDEF debug}
      codesite.Send('Rlentry.AOffset', Rlentry.AOffset);
      codesite.Send('Rlentry.AStoreLength', Rlentry.AStoreLength);
{$ENDIF}
    end;
  except
    Result := False;
  end;
end;

function ReadData(FileBuffer: TFileBufferStream; OutBuffer: TStream): LongInt;
var
  Buffer: TGlCompressBuffer;
  key, tmp: Byte;
  i: integer;
  len: Cardinal;
begin
  Buffer := TGlCompressBuffer.Create;
  try
    key := Byte(FileBuffer.Rlentry.AStoreLength shr 3) + $22;
    Result := FileBuffer.ReadData(OutBuffer);
    OutBuffer.Seek(0, soFromBeginning);
    for i := 0 to $20 - 1 do
    begin
      OutBuffer.Read(tmp, 1);
      tmp := tmp xor key;
      key := key shl 3;
      OutBuffer.Seek(-1, soFromCurrent);
      OutBuffer.Write(tmp, 1);
      if OutBuffer.Position >= OutBuffer.Size then
        Break;
    end;
    OutBuffer.Seek(-4, soFromEnd);
    Buffer.Seek(0, soFromBeginning);
    OutBuffer.Read(len, 4);
    OutBuffer.Seek(0, soFromBeginning);
    Buffer.CopyFrom(OutBuffer, OutBuffer.Size - 4);
    Buffer.Seek(0, soFromBeginning);
    Buffer.ZlibDecompress(len);
    Buffer.Seek(0, soFromBeginning);
    Buffer.Output.Seek(0, soFromBeginning);
    OutBuffer.Size := 0;
    OutBuffer.Seek(0, soFromBeginning);
    OutBuffer.CopyFrom(Buffer.Output, Buffer.Output.Size -
      Buffer.Output.Position);
  finally
    Buffer.Free;
  end;
end;

function PackProcessData(Rlentry: TRlEntry;
  InputBuffer, FileOutBuffer: TStream): Boolean;
var
  Compr: TGlCompressBuffer;
  comlen: Cardinal;
  key, tmp: Byte;
  key1: Cardinal;
  i: integer;
begin
  Compr := TGlCompressBuffer.Create;
  try
    InputBuffer.Seek(0, soFromBeginning);
    Compr.CopyFrom(InputBuffer, InputBuffer.Size);
    Compr.Seek(0, soFromBeginning);
    Compr.ZlibCompress(clDefault);
    Compr.Output.Seek(0, soFromBeginning);

    key1 := 0;
    for i := 0 to length(Rlentry.AName) - 1 do
      key1 := key1 + PByte(AnsiString(Rlentry.AName))[i];
    key := Byte((Cardinal(Compr.Output.Size + 4) xor key1) shr 3) + $22;
    for i := 0 to $20 - 1 do
    begin
      Compr.Output.Read(tmp, 1);
      tmp := tmp xor key;
      key := key shl 3;
      Compr.Output.Seek(-1, soFromCurrent);
      Compr.Output.Write(tmp, 1);
      if Compr.Output.Position >= Compr.Output.Size then
        Break;
    end;

    Rlentry.ARLength := Compr.Size;
    Rlentry.AStoreLength := Compr.Output.Size + 4;
    Rlentry.AOffset := FileOutBuffer.Position;

    comlen := Compr.Size;
    Compr.Output.Seek(0, soFromBeginning);
    FileOutBuffer.CopyFrom(Compr.Output, Compr.Output.Size);
    FileOutBuffer.Write(comlen, 4);
{$IFDEF debug}
    codesite.Send('File Pack: ', Rlentry.AName);
{$ENDIF}
  finally
    Compr.Free;
  end;
end;

function PackProcessIndex(IndexStream: TIndexStream;
  IndexOutBuffer: TStream): Boolean;
var
  indexs: Pack_Entries;
  i, j: integer;
  key, zero: Cardinal;
begin
  zero := 0;
  IndexOutBuffer.Seek(0, soFromBeginning);
  for i := 0 to IndexStream.Count - 1 do
  begin
    indexs.NameLen := length(IndexStream.Rlentry[i].AName);
    SetLength(indexs.filename, indexs.NameLen);
    Move(PByte(AnsiString(IndexStream.Rlentry[i].AName))^,
      PByte(indexs.filename)^, indexs.NameLen);
    key := 0;
    for j := 0 to indexs.NameLen - 1 do
      key := key + PByte(indexs.filename)[j];
    indexs.start_offset := IndexStream.Rlentry[i].AOffset + SizeOf(Pack_Head);
    indexs.start_offset := indexs.start_offset xor key;
    indexs.length := Cardinal(IndexStream.Rlentry[i].AStoreLength) xor key;
    indexs.NameLen := indexs.NameLen + 1;
    IndexOutBuffer.Write(indexs.NameLen, 4);
    IndexOutBuffer.Write(PByte(indexs.filename)^, indexs.NameLen);
    IndexOutBuffer.Write(indexs.start_offset, 4);
    IndexOutBuffer.Write(indexs.length, 4);
  end;

  IndexOutBuffer.Write(zero, 4);
  zero := IndexOutBuffer.Size;

  IndexOutBuffer.Seek(0, soFromBeginning);
  for i := 0 to IndexStream.Count - 1 do
  begin
    indexs.NameLen := length(IndexStream.Rlentry[i].AName);
    SetLength(indexs.filename, indexs.NameLen);
    Move(PByte(AnsiString(IndexStream.Rlentry[i].AName))^,
      PByte(indexs.filename)^, indexs.NameLen);
    key := 0;
    for j := 0 to indexs.NameLen - 1 do
      key := key + PByte(indexs.filename)[j];
    indexs.start_offset := IndexStream.Rlentry[i].AOffset + zero +
      SizeOf(Pack_Head);
    indexs.start_offset := indexs.start_offset xor key;
    indexs.length := Cardinal(IndexStream.Rlentry[i].AStoreLength) xor key;
    indexs.NameLen := indexs.NameLen + 1;
    IndexOutBuffer.Write(indexs.NameLen, 4);
    IndexOutBuffer.Write(PByte(indexs.filename)^, indexs.NameLen);
    IndexOutBuffer.Write(indexs.start_offset, 4);
    IndexOutBuffer.Write(indexs.length, 4);
  end;

{$IFDEF debug}
  codesite.Send('Index pack finish.');
{$ENDIF}
end;

function MakePackage(IndexStream: TIndexStream;
  IndexOutBuffer, FileOutBuffer: TStream; Package: TFileBufferStream): Boolean;
var
  head: Pack_Head;
begin
  Move(PByte(Magic)^, head.Magic[0], length(Magic));
  head.indexs := IndexOutBuffer.Size;
Package.Write(head.Magic[0], SizeOf(Pack_Head));
IndexOutBuffer.Seek(0, soFromBeginning);
Package.CopyFrom(IndexOutBuffer, IndexOutBuffer.Size);
FileOutBuffer.Seek(0, soFromBeginning);
Package.CopyFrom(FileOutBuffer, FileOutBuffer.Size);
{$IFDEF debug}
codesite.Send('Make package finish.');
{$ENDIF}
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
