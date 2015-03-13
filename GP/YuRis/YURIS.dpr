library YURIS;

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
    indexs: Cardinal;
    Table_size: Cardinal;
    Dummy: array [ 1 .. 16 ] of byte;
  End;

  Pack_Entries = packed Record
    FNHash: longword;
    EncFNLen: byte;
    filename: AnsiString;
    filetype: byte;
    Encodeflag: byte;
    decompresslen: Cardinal;
    length: Cardinal;
    start_Offset: Cardinal;
    Hash: Cardinal;
  End;

  TYSTBHeader = packed record
    Magic: array [ 0 .. 3 ] of AnsiChar;
    Version: Cardinal;
    OPCount: Cardinal;
    data1_length: Cardinal;
    data2_length: Cardinal;
    data3_length: Cardinal;
    data4_length: Cardinal;
    reserved: Cardinal;
  end;

const
  Magic: AnsiString = 'YPF';

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

var
  DecodeTable: array [ 0 .. 255 ] of byte;

procedure Exchange(A, b: Integer);
var
  tmp: byte;
begin
  tmp              := DecodeTable[ A ];
  DecodeTable[ A ] := DecodeTable[ b ];
  DecodeTable[ b ] := tmp;
end;

procedure DecodeTableInit(m: Boolean);
var
  i: Integer;
begin
  for i              := 0 to 255 do
    DecodeTable[ i ] := i;
  Exchange(3, 72);
  Exchange(6, 53);
  Exchange(9, 11);
  Exchange(12, 16);
  Exchange(13, 19);
  Exchange(17, 25);
  Exchange(21, 27);
  Exchange(28, 30);
  Exchange(32, 35);
  Exchange(38, 41);
  Exchange(44, 47);
  Exchange(46, 50);
end;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('Yu-Ris',
    clGameMaker));
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  head   : Pack_Head;
  indexs : Pack_Entries;
  i, j   : Integer;
  Rlentry: TRlEntry;
begin
  Result := True;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(head.Magic[ 0 ], SizeOf(Pack_Head));
    if not SameText(Trim(head.Magic), Magic) then
      raise Exception.Create('Magic Error.');
    DecodeTableInit(True);
    for i := 0 to head.indexs - 1 do
    begin
      FileBuffer.Read(indexs.FNHash, 5);
      SetLength(indexs.filename, DecodeTable[ $FF - indexs.EncFNLen ]);
      FileBuffer.Read(PByte(indexs.filename)^,
        DecodeTable[ $FF - indexs.EncFNLen ]);
      for j := 0 to DecodeTable[ $FF - indexs.EncFNLen ] - 1 do
        PByte(indexs.filename)[ j ] := not PByte(indexs.filename)[ j ];
      FileBuffer.Read(indexs.filetype, 18);
      Rlentry              := TRlEntry.Create;
      Rlentry.AName        := Trim(indexs.filename);
      Rlentry.AOffset      := indexs.start_Offset;
      Rlentry.AOrigin      := soFromBeginning;
      Rlentry.AStoreLength := indexs.length;
      Rlentry.ARLength     := indexs.decompresslen;
      Rlentry.AKey         := indexs.Encodeflag;
      IndexStream.ADD(Rlentry);
    end;
  except
    Result := False;
  end;
end;

procedure Decode2(Input: TStream; L: Cardinal);
var
  tmp: byte;
  i  : Integer;
const
  Table: array [ 0 .. 3 ] of byte = ($D3, $6F, $AC, $96);
begin
  i := 0;
  while i < L do
  begin
    Input.Read(tmp, 1);
    tmp := tmp xor Table[ i and 3 ];
    Input.Seek(-1, soFromCurrent);
    Input.Write(tmp, 1);
    Inc(i);
  end;
end;

function ReadData(FileBuffer: TFileBufferStream;
  OutBuffer: TStream): LongInt;
var
  Buffer: TGlCompressBuffer;
  magic2: TYSTBHeader;
begin
  Buffer := TGlCompressBuffer.Create;
  try
    FileBuffer.ReadData(Buffer);
    Buffer.Seek(0, soFromBeginning);
    if FileBuffer.PrevEntry.AKey = 1 then
    begin
      Buffer.ZlibDecompress(FileBuffer.PrevEntry.ARLength);
    end
    else
      Buffer.Output.CopyFrom(Buffer, Buffer.Size);
    Buffer.Output.Seek(0, soFromBeginning);
    Buffer.Output.Read(magic2.Magic[ 0 ], SizeOf(TYSTBHeader));
    if SameText(Trim(magic2.Magic), 'YSTB') then
    begin
      Decode2(Buffer.Output, magic2.data1_length);
      Decode2(Buffer.Output, magic2.data2_length);
      Decode2(Buffer.Output, magic2.data3_length);
      Decode2(Buffer.Output, magic2.data4_length);
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
    Compr.Seek(0, soFromBeginning);
    with Rlentry do
    begin
      Rlentry.ARLength     := Compr.Size;
      Rlentry.AStoreLength := Rlentry.ARLength;
      Rlentry.AOffset      := FileOutBuffer.Position;
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
  i     : Integer;
begin
  SetLength(indexs, IndexStream.count);
  ZeroMemory(@indexs[ 0 ].filename[ 1 ], IndexStream.count *
    SizeOf(Pack_Entries));
  for i := 0 to IndexStream.count - 1 do
  begin
    if length(IndexStream.Rlentry[ i ].AName) > 32 then
      raise Exception.Create('Filename too long.');
    Move(PByte(AnsiString(IndexStream.Rlentry[ i ].AName))^,
      indexs[ i ].filename[ 1 ],
      length(IndexStream.Rlentry[ i ].AName));
    indexs[ i ].decompresslen := IndexStream.Rlentry[ i ].ARLength;
    indexs[ i ].start_Offset  := IndexStream.Rlentry[ i ].AOffset +
      IndexStream.count * SizeOf(Pack_Entries) + SizeOf(Pack_Head);
    indexs[ i ].length     := IndexStream.Rlentry[ i ].AStoreLength;
    indexs[ i ].Encodeflag := 1;
  end;
  IndexOutBuffer.Write(indexs[ 0 ].filename[ 1 ], IndexStream.count *
    SizeOf(Pack_Entries));
end;

function MakePackage(IndexStream: TIndexStream;
  IndexOutBuffer, FileOutBuffer: TStream;
  Package: TFileBufferStream): Boolean;
var
  head: Pack_Head;
begin
  Move(PByte(Magic)^, head.Magic[ 0 ], length(Magic));
  head.indexs := IndexStream.count;
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
