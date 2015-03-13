library 蛇ノ道ハ蛇ソフト;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  StrUtils,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas',
  Windows;

{$E gp}
{$R *.res}

Type
  Pack_Head = Packed Record
    Magic: array [0 .. 3] of AnsiChar;
    Indexs: Word;
    Flag: Word;
  End;

  Pack_Entries = packed Record
    filename: array [1 .. $24] of AnsiChar;
    start_offset: Cardinal;
    length: Cardinal;
  End;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('蛇ノ道ハ蛇ソフト', clgamemaker));
end;

const
  Magic = 'IPAC';

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], sizeof(Pack_Head));
    if (Head.Indexs < FileBuffer.Size) and
      SameText(Trim(Head.Magic), Magic) then
    begin
      Result := dsTrue;
    end;
  except
    Result := dsError;
  end;
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  Head: Pack_Head;
  Indexs: Pack_Entries;
  i: Integer;
  Rlentry: TRlEntry;
begin
  Result := True;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], sizeof(Pack_Head));
    if not SameText(Head.Magic, Magic) then
      raise Exception.Create('Package Error.');
    for i := 0 to Head.Indexs - 1 do
    begin
      FileBuffer.Read(Indexs.filename[1], sizeof(Indexs));
      Rlentry := TRlEntry.Create;
      Rlentry.AName := Trim(Indexs.filename);
      Rlentry.AOffset := Indexs.start_offset;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := Indexs.length;
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

const
  Scr = 'IEL1';
  Pic = 'IES2';

type
  TImage = packed record
    Magic: array [0 .. 3] of AnsiChar;
    width: Cardinal;
    height: Cardinal;
    Depth: Cardinal;
    reserved: Cardinal;
    reserved1: Cardinal;
    reserved2: Cardinal;
  end;

function ReadData(FileBuffer: TFileBufferStream;
  OutBuffer: TStream): LongInt;
var
  Buffer: TGlCompressBuffer;
  Alpha, RGB: TMemoryStream;
  Magic: array [0 .. 3] of AnsiChar;
  Decompress: Cardinal;
  Image: TImage;
  Pic_Header_Info: BITMAPFILEHEADER;
  Bit_Header_Info: BITMAPINFOHEADER;
  tmp, tmpa: Byte;
begin
  OutBuffer.Size := 0;
  OutBuffer.Seek(0, soFromBeginning);
  Result := FileBuffer.ReadData(OutBuffer);
  OutBuffer.Seek(0, soFromBeginning);
  OutBuffer.Read(Magic[0], 4);
  if SameText(Magic, Scr) then
  begin
    OutBuffer.Read(Decompress, 4);
    Buffer := TGlCompressBuffer.Create;
    Buffer.CopyFrom(OutBuffer, OutBuffer.Size - 8);
    Buffer.Seek(0, soFromBeginning);
    Buffer.LzssDecompress(Buffer.Size, $FEE, $FFF);
    if Buffer.Output.Size <> Decompress then
    begin
      Buffer.Free;
      raise Exception.Create('Decompress Error.');
    end;
    Buffer.Output.Seek(0, soFromBeginning);
    OutBuffer.Size := 0;
    OutBuffer.CopyFrom(Buffer.Output, Buffer.Output.Size);
    Buffer.Free;
  end;
  OutBuffer.Seek(0, soFromBeginning);
  OutBuffer.Read(Magic[0], 4);
  if SameText(Magic, Pic) then
  begin
    OutBuffer.Read(Image.Magic[0], sizeof(TImage));
    Pic_Header_Info.bfType := $4D42;
    Pic_Header_Info.bfSize := OutBuffer.Size -
      OutBuffer.Position + 54;
    Pic_Header_Info.bfReserved1 := 0;
    Pic_Header_Info.bfReserved2 := 0;
    Pic_Header_Info.bfOffBits := 54;
    FillMemory(@Bit_Header_Info.biSize,
      sizeof(Bit_Header_Info), 0);
    Bit_Header_Info.biSize := 40;
    Bit_Header_Info.biWidth := Image.width;
    Bit_Header_Info.biHeight := Image.height;
    Bit_Header_Info.biPlanes := 1;
    Bit_Header_Info.biBitCount := Image.Depth;
    Buffer := TGlCompressBuffer.Create;
    Buffer.Write(Pic_Header_Info.bfType, 14);
    Buffer.Write(Bit_Header_Info.biSize, 40);
    { if Image.Depth <> 24 then
      Buffer.CopyFrom(OutBuffer, OutBuffer.Size -
      OutBuffer.Position)
      else
      begin
      RGB := TMemoryStream.Create;
      Alpha := TMemoryStream.Create;
      OutBuffer.Seek($420, soFromBeginning);
      RGB.CopyFrom(OutBuffer, Image.height * Image.width * 3);
      Alpha.CopyFrom(OutBuffer,Image.height * Image.width);
      RGB.Seek(0, soFromBeginning);
      Alpha.Seek(0,soFromBeginning);;
      while RGB.Position < RGB.Size do
      begin
      Alpha.Read(tmpa,1);
      RGB.Read(tmp,1);
      tmp := (tmp * tmpa + $ff * (not tmpa)) div 255;
      Buffer.Write(tmp,1);
      RGB.Read(tmp,1);
      tmp := (tmp * tmpa + $ff * (not tmpa)) div 255;
      Buffer.Write(tmp,1);
      RGB.Read(tmp,1);
      tmp := (tmp * tmpa + $ff * (not tmpa)) div 255;
      Buffer.Write(tmp,1);
      Buffer.Write(tmpa,1);
      end;
      RGB.Free;
      Alpha.Free;
      end; }
    OutBuffer.Seek($420, soFromBeginning);
    Buffer.CopyFrom(OutBuffer, OutBuffer.Size -
      OutBuffer.Position);
    OutBuffer.Size := 0;
    OutBuffer.Seek(0, soFromBeginning);
    Buffer.Seek(0, soFromBeginning);
    OutBuffer.CopyFrom(Buffer, Buffer.Size);
    Buffer.Free;
  end;
  OutBuffer.Seek(0, soFromBeginning);
end;

function PackData(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream; var Percent: Word): Boolean;
var
  Buffer: TGlCompressBuffer;
  i: Integer;
  Head: Pack_Head;
  Indexs: array of Pack_Entries;
begin
  Result := True;
  try

  except
    Result := False;
  end;
end;

function GetPluginInfo: TGpInfo;
begin
  Result.ACopyRight := 'HatsuneTakumi';
  Result.AVersion := '0.0.1';
  Result.AGameEngine := 'Unknown Engine';
  Result.ACompany := '蛇ノ道ハ蛇ソフト';
  Result.AExtension := 'Pak';
  Result.AMoreInfo := '(C)2011 HatsuneTakumi @ Kdays';
end;

exports AutoDetect;

exports GetPluginName;

exports GenerateEntries;

exports Decyption;

exports ReadData;

exports PackData;

exports GetPluginInfo;

begin

end.
