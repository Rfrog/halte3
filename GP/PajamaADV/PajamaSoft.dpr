library PajamaSoft;

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
    Magic: array [ 0 .. $B ] of AnsiChar;
    indexs: Cardinal;
  End;

  Pack_Entries = packed Record
    start_offset: Cardinal;
    length: Cardinal;
  End;

const
  Magic: AnsiString = 'GAMEDAT PAC2';

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
  Result := PChar(FormatPluginName('PajamaADV', clEngine));
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  head: Pack_Head;
  indexs: Pack_Entries;
  i: integer;
  Rlentry: TRlEntry;
  FileName: array of array [ 1 .. 32 ] of AnsiChar;
begin
  Result := True;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(head.Magic[ 0 ], SizeOf(Pack_Head));
    if not SameText(Trim(head.Magic), Magic) then
      raise Exception.Create('Magic Error.');
    SetLength(FileName, head.indexs);
    FileBuffer.Read(FileName[ 0, 1 ], head.indexs * $20);
    for i := 0 to head.indexs - 1 do
    begin
      FileBuffer.Read(indexs.start_offset, SizeOf(Pack_Entries));
      Rlentry := TRlEntry.Create;
      Rlentry.AName := Trim(FileName[ i ]);
      Rlentry.AOffset := indexs.start_offset + head.indexs * $28 +
        SizeOf(Pack_Head);
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs.length;
      IndexStream.ADD(Rlentry);
    end;
    SetLength(FileName, 0);
  except
    Result := False;
  end;
end;

type
  TImage = packed record
    Magic: array [ 0 .. 2 ] of AnsiChar;
    ver_min: Byte;
    ver_maj: Byte;
    Unknow: Cardinal;
    Width: Cardinal;
    Height: Cardinal;
  end;

const
  MagicText = 'PJADV_TF0001';

function ReadData(FileBuffer: TFileBufferStream; OutBuffer: TStream): LongInt;
var
  Buffer: TGlCompressBuffer;
  Pic_Header_Info: BITMAPFILEHEADER;
  Bit_Header_Info: BITMAPINFOHEADER;
  Image: TImage;
  Magic: array [ 0 .. 11 ] of AnsiChar;
  tmp,tmp1: Byte;
begin
  Buffer := TGlCompressBuffer.Create;
  try
    FileBuffer.ReadData(Buffer);
    Buffer.Seek(0, soFromBeginning);
    Buffer.Read(Magic[ 0 ], 12);
    Buffer.Seek(0, soFromBeginning);
    if SameText('EP', Trim(Image.Magic)) then
    begin
      Buffer.Read(Image.Magic[ 0 ], SizeOf(TImage));
      Pic_Header_Info.bfType := $4D42;
      Pic_Header_Info.bfSize := OutBuffer.Size - OutBuffer.Position + 54;
      Pic_Header_Info.bfReserved1 := 0;
      Pic_Header_Info.bfReserved2 := 0;
      Pic_Header_Info.bfOffBits := 54;
      FillMemory(@Bit_Header_Info.biSize, SizeOf(Bit_Header_Info), 0);
      Bit_Header_Info.biSize := 40;
      Bit_Header_Info.biWidth := Image.Width;
      Bit_Header_Info.biHeight := Image.Height;
      Bit_Header_Info.biPlanes := 1;
      Bit_Header_Info.biBitCount := 32;
    end else if SameText(MagicText, Trim(Image.Magic)) then
    begin
      tmp := $C5;

    end;
    Buffer.Output.CopyFrom(Buffer, Buffer.Size);
    Buffer.Output.Seek(0, soFromBeginning);
    OutBuffer.CopyFrom(Buffer, Buffer.Size);
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
  i: integer;
begin
  SetLength(indexs, IndexStream.Count);
  ZeroMemory(@indexs[ 0 ].start_offset, IndexStream.Count *
    SizeOf(Pack_Entries));
  for i := 0 to IndexStream.Count - 1 do
  begin
    if length(IndexStream.Rlentry[ i ].AName) > 32 then
      raise Exception.Create('Filename too long.');
    indexs[ i ].start_offset := IndexStream.Rlentry[ i ].AOffset + IndexStream.Count
      * SizeOf(Pack_Entries) + SizeOf(Pack_Head);
    indexs[ i ].length := IndexStream.Rlentry[ i ].AStoreLength;
  end;
  IndexOutBuffer.Write(indexs[ 0 ].start_offset, IndexStream.Count *
    SizeOf(Pack_Entries));
  IndexOutBuffer.Write(indexs[ 0 ].start_offset, IndexStream.Count *
    SizeOf(Pack_Entries));
end;

function MakePackage(IndexStream: TIndexStream;
  IndexOutBuffer, FileOutBuffer: TStream; Package: TFileBufferStream): Boolean;
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
