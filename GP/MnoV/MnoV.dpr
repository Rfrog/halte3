library MnoV;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  Windows,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas',
  StrUtils
{$IFDEF debug}
    , codesitelogging
{$ENDIF};

{$E GP}

Type
  Pack_Head = Packed Record
    indexs: Cardinal;
  End;

  Pack_Entries = packed Record
    filename: array [1 .. $44] of AnsiChar;
    length: Cardinal;
    start_offset: Cardinal;
  End;

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Read(head.indexs, SizeOf(Pack_Head));
    if head.indexs < FileBuffer.Size then
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
  Result := PChar(FormatPluginName('M no Violet', clGameMaker));
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

{$IFDEF debug}
    CodeSite.Send('Indexs: ', head.indexs);
{$ENDIF}
    for i := 0 to head.indexs - 1 do
    begin
      FileBuffer.Read(indexs.filename[1], SizeOf(Pack_Entries));
      Rlentry := TRlEntry.Create;
      Rlentry.AName := Trim(indexs.filename);
      Rlentry.AOffset := indexs.start_offset;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs.length;
      Rlentry.ARLength := indexs.length;
      IndexStream.ADD(Rlentry);

{$IFDEF debug}
      CodeSite.Send('Entry: ', Rlentry);
{$ENDIF}
    end;
  except
    Result := False;
  end;
end;

type
  GRP_Head = packed record
    FileType: Cardinal;
    Width: Cardinal;
    Height: Cardinal;
    Depth: Cardinal;
  end;

function ReadData(FileBuffer: TFileBufferStream; OutBuffer: TStream): LongInt;
var
  Buffer: TGlCompressBuffer;
  head: GRP_Head;
  Pic_Header_Info: BITMAPFILEHEADER;
  Bit_Header_Info: BITMAPINFOHEADER;
begin
  Buffer := TGlCompressBuffer.Create;
  try
    FileBuffer.ReadData(Buffer);
    Buffer.Seek(0, soFromBeginning);
    Buffer.Read(head.FileType, SizeOf(GRP_Head));
{$IFDEF debug}
    CodeSite.Send('head.FileType: ', head.FileType);
    CodeSite.Send('Buffer.Size: ', Buffer.Size);
    CodeSite.Send('RlSize: ', head.Width * head.Height * head.Depth div 8);
{$ENDIF}
    case head.FileType of
      1:
        begin
          Pic_Header_Info.bfType := $4D42;
          Pic_Header_Info.bfSize := Buffer.Size - Buffer.Position + 54;
          Pic_Header_Info.bfReserved1 := 0;
          Pic_Header_Info.bfReserved2 := 0;
          Pic_Header_Info.bfOffBits := 54;
          FillMemory(@Bit_Header_Info.biSize, SizeOf(Bit_Header_Info), 0);
          Bit_Header_Info.biSize := 40;
          Bit_Header_Info.biWidth := head.Width;
          Bit_Header_Info.biHeight := head.Height;
          Bit_Header_Info.biPlanes := 1;
          Bit_Header_Info.biBitCount := head.Depth;
          OutBuffer.Write(Pic_Header_Info.bfType, 14);
          OutBuffer.Write(Bit_Header_Info.biSize, 40);
        end
    else
      Buffer.Seek(0, soFromBeginning);
    end;
    Buffer.Output.Seek(0, soFromBeginning);
    OutBuffer.CopyFrom(Buffer, Buffer.Size - Buffer.Position);
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
  ZeroMemory(@indexs[0].filename[1], IndexStream.Count * SizeOf(Pack_Entries));
  for i := 0 to IndexStream.Count - 1 do
  begin
    if length(IndexStream.Rlentry[i].AName) > 32 then
      raise Exception.Create('Filename too long.');
    Move(PByte(AnsiString(IndexStream.Rlentry[i].AName))^,
      indexs[i].filename[1], length(IndexStream.Rlentry[i].AName));
    indexs[i].start_offset := IndexStream.Rlentry[i].AOffset + IndexStream.Count
      * SizeOf(Pack_Entries) + SizeOf(Pack_Head);
    indexs[i].length := IndexStream.Rlentry[i].AStoreLength;
  end;
  IndexOutBuffer.Write(indexs[0].filename[1], IndexStream.Count *
    SizeOf(Pack_Entries));
end;

function MakePackage(IndexStream: TIndexStream;
  IndexOutBuffer, FileOutBuffer: TStream; Package: TFileBufferStream): Boolean;
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

exports AutoDetect;

exports GetPluginName;

exports GenerateEntries;

exports ReadData;

exports PackProcessData;

exports PackProcessIndex;

exports MakePackage;

begin

end.
