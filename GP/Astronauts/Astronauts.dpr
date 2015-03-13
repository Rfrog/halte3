library Astronauts;

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
    Magic: array [ 0 .. 3 ] of AnsiChar;
    Version: Cardinal;
    Magic2: Cardinal;
    Flag: Cardinal;
    Unknow1: Cardinal;
    Index_Flag: Cardinal;
    indexs: Cardinal;
    Index_Length: Cardinal;
    Data_Length: Cardinal;
    Reserved: Cardinal;
    Data_Offset: Cardinal;
    Reserved1: Cardinal;
  End;

  Pack_Entries = packed Record
    dwSize: Cardinal;
    length: Cardinal;
    Flag: Cardinal;
    FileName_Length: Cardinal; // *2
    Time_Sig: Cardinal;
    Time_Sig2: Cardinal;
    start_offset: Cardinal;
    reserved2: Cardinal;
  End;

const
  Magic: AnsiString = 'GXP';

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
  Result := PChar(FormatPluginName('Astronauts',
    clGameMaker));
end;

const
  DecodeTable: array [ 0 .. $16 ] of byte
    = ($40, $21, $28, $38, $A6, $6E, $43, $A5, $40, $21, $28, $38, $A6, $43,
    $A5, $64, $3E, $65, $24, $20, $46, $6E, $74);

procedure Decode(Input, Output: PByte; Len: Integer; Key: Integer = 0);
var
  i: Integer;
begin
  for i := 0 to Len - 1 do
  begin
    Output[ i ] := (DecodeTable[ (i + Key) mod $17 ] xor (Key + byte(i)))
      xor Input[ i ];
  end;
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  head: Pack_Head;
  indexs: Pack_Entries;
  i: Integer;
  Rlentry: TRlEntry;
  tmp_Buffer: PByte;
begin
  Result := True;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(head.Magic[ 0 ], SizeOf(Pack_Head));
    if not SameText(Trim(head.Magic), Magic) then
      raise Exception.Create('Magic Error.');
    for i := 0 to head.indexs - 1 do
    begin
      FileBuffer.Read(indexs.dwSize, 4);
      Decode(@indexs.dwSize, @indexs.dwSize, 4);
      tmp_Buffer := GetMemory(indexs.dwSize);
      FileBuffer.Read(tmp_Buffer^, indexs.dwSize - 4);
      Decode(tmp_Buffer, tmp_Buffer, indexs.dwSize - 4, 4);
      Move(tmp_Buffer^, indexs.length, $1C);

      Rlentry := TRlEntry.Create;
      Rlentry.AName := Trim(PChar(@tmp_Buffer[ $1C ]));
      Rlentry.AName := ReplaceStr(Rlentry.AName, '/', '\');
      Rlentry.AOffset := indexs.start_offset + head.Data_Offset;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs.length;
      Rlentry.ARLength := indexs.length;
      Rlentry.AKey := head.Flag;
      IndexStream.ADD(Rlentry);
      FreeMem(tmp_Buffer);
    end;
  except
    Result := False;
  end;
end;

procedure DecodeBuffer(Input, Output: TStream);
var
  i: Integer;
  tmp: byte;
begin
  for i := 0 to Input.Size - Input.Position - 1 do
  begin
    Input.Read(tmp, 1);
    tmp := (DecodeTable[ i mod $17 ] xor byte(i))
      xor tmp;
    Output.Write(tmp, 1);
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
      DecodeBuffer(Buffer, Buffer.Output)
    end
    else
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
  indexs: array of Pack_Entries;
  i: Integer;
begin
  SetLength(indexs, IndexStream.Count);
  ZeroMemory(@indexs[ 0 ].dwSize, IndexStream.Count *
    SizeOf(Pack_Entries));
  for i := 0 to IndexStream.Count - 1 do
  begin

    indexs[ i ].start_offset := IndexStream.Rlentry[ i ].AOffset +
      IndexStream.Count * SizeOf(Pack_Entries) + SizeOf(Pack_Head);
    indexs[ i ].length := IndexStream.Rlentry[ i ].AStoreLength;
  end;
  IndexOutBuffer.Write(indexs[ 0 ].dwSize, IndexStream.Count *
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

exports
  PackProcessData;

exports
  PackProcessIndex;

exports
  MakePackage;

begin

end.
