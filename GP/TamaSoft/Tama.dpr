library Tama;

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

type
  Pack_Head = packed record
    FMagic: array [0 .. 3] of AnsiChar;
    FIndexs: Cardinal;
  end;

  Pack_Entries = packed record
    FName: array [0 .. $1F] of AnsiChar;
    FOffset: Cardinal;
    FLength: Cardinal;
    FReserved: array [0 .. 1] of Cardinal;
  end;

  TMIFHeader = packed record
    FMagic: array [0 .. 3] of AnsiChar;
    FWidth: Cardinal;
    FHeight: Cardinal;
    FDepth: Cardinal;
    FDataLen: Cardinal;
  end;

  TMPFHeader = packed record
    FMagic: array [0 .. 3] of AnsiChar;
    FFormatTag: Word;
    FChannels: Word;
    FSamplePerSec: Cardinal;
    FBytesPerSec: Cardinal;
    FBlockAlign: Word;
    FBitsPerSample: Word;
    FDataSize: Cardinal;
  end;

  TWaveRiffHeader = packed record
    FRiffMagic: array [0 .. 3] of AnsiChar; // RIFF
    FSize: Cardinal; // ASize - 8
    FFormat: array [0 .. 3] of AnsiChar; // WAVE

    FFMTMagic: array [0 .. 3] of AnsiChar; // 'fmt '
    FSubChunkSize: Cardinal; // PCM = 16
    FAudioFormat: Word; // PCM = 1
    FChannels: Word;
    FSampleRate: Cardinal;
    FByteRate: Cardinal;
    FBlockAlign: Word;
    FBitsPerSample: Word;

    FDataMagic: array [0 .. 3] of AnsiChar; // 'data'
    FDataSize: Cardinal;
  end;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('Tama-Soft', clgamemaker));
end;

const
  Magic = 'ACV ';

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.FMagic[0], sizeof(Pack_Head));
    if (Head.FIndexs < FileBuffer.Size) then
    begin
      Result := dsUnknown;
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
    FileBuffer.Read(Head.FMagic[0], sizeof(Pack_Head));
    if not SameText(Head.FMagic, Magic) then
      raise Exception.Create('Package Error.');
    for i := 0 to Head.FIndexs - 1 do
    begin
      FileBuffer.Read(Indexs.FName[0], sizeof(Indexs));
      Rlentry := TRlEntry.Create;
      Rlentry.AName := Trim(Indexs.FName);
      Rlentry.AOffset := Indexs.FOffset;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := Indexs.FLength;
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
  Pic = 'MIF@';
  Scr = 'MPF ';

function ReadData(FileBuffer: TFileBufferStream; OutBuffer: TStream): LongInt;
var
  Buffer: TGlCompressBuffer;
  Magic: array [0 .. 3] of AnsiChar;
  Image: TMIFHeader;
  Pic_Header_Info: BITMAPFILEHEADER;
  Bit_Header_Info: BITMAPINFOHEADER;
  WaveHeader: TWaveRiffHeader;
  Header: TMPFHeader;
begin
  OutBuffer.Size := 0;
  OutBuffer.Seek(0, soFromBeginning);
  Result := FileBuffer.ReadData(OutBuffer);
  OutBuffer.Seek(0, soFromBeginning);
  OutBuffer.Read(Magic[0], 4);
  if SameText(Magic, Scr) then
  begin
    OutBuffer.Seek(0, soFromBeginning);
    OutBuffer.Read(Header.FMagic[0], sizeof(TMPFHeader));

    WaveHeader.FRiffMagic := 'RIFF';
    WaveHeader.FSize := Header.FDataSize + sizeof(TWaveRiffHeader) - 8;
    WaveHeader.FFormat := 'WAVE';
    WaveHeader.FFMTMagic := 'fmt ';
    WaveHeader.FSubChunkSize := 16;
    WaveHeader.FAudioFormat := Header.FFormatTag;
    WaveHeader.FChannels := Header.FChannels;
    WaveHeader.FSampleRate := Header.FSamplePerSec;
    WaveHeader.FByteRate := Header.FBytesPerSec;
    WaveHeader.FBlockAlign := Header.FBlockAlign;
    WaveHeader.FBitsPerSample := Header.FBitsPerSample;
    WaveHeader.FDataMagic := 'data';
    WaveHeader.FDataSize := Header.FDataSize;

    Buffer := TGlCompressBuffer.Create;
    Buffer.CopyFrom(OutBuffer, OutBuffer.Size - sizeof(TMPFHeader));
    Buffer.Seek(0, soFromBeginning);
    OutBuffer.Size := 0;
    OutBuffer.Write(WaveHeader.FRiffMagic[0], sizeof(TWaveRiffHeader));
    OutBuffer.CopyFrom(Buffer.Output, Buffer.Output.Size);
    Buffer.Free;
  end;
  OutBuffer.Seek(0, soFromBeginning);
  OutBuffer.Read(Magic[0], 4);
  if SameText(Magic, Pic) then
  begin
    OutBuffer.Seek(0, soFromBeginning);
    OutBuffer.Read(Image.FMagic[0], sizeof(TMIFHeader));
    Pic_Header_Info.bfType := $4D42;
    Pic_Header_Info.bfSize := OutBuffer.Size - OutBuffer.Position + 54;
    Pic_Header_Info.bfReserved1 := 0;
    Pic_Header_Info.bfReserved2 := 0;
    Pic_Header_Info.bfOffBits := 54;
    FillMemory(@Bit_Header_Info.biSize, sizeof(Bit_Header_Info), 0);
    Bit_Header_Info.biSize := 40;
    Bit_Header_Info.biWidth := Image.FWidth;
    Bit_Header_Info.biHeight := Image.FHeight;
    Bit_Header_Info.biPlanes := 1;
    Bit_Header_Info.biBitCount := Image.FDepth;
    Buffer := TGlCompressBuffer.Create;
    Buffer.CopyFrom(OutBuffer, Image.FDataLen);
    Buffer.Seek(54, soFromBeginning);
    Buffer.LzssDecompress(Buffer.Size, $FEE, $FFF);
    Buffer.Output.Seek(0, soFromBeginning);
    OutBuffer.Size := 0;
    OutBuffer.Seek(0, soFromBeginning);
    Buffer.Seek(0, soFromBeginning);
    OutBuffer.Write(Pic_Header_Info.bfType, 14);
    OutBuffer.Write(Bit_Header_Info.biSize, 40);
    OutBuffer.CopyFrom(Buffer, Buffer.Size);
    Buffer.Free;
  end;
  OutBuffer.Seek(0, soFromBeginning);
end;

function GetPluginInfo: TGpInfo;
begin
  Result.ACopyRight := 'HatsuneTakumi';
  Result.AVersion := '0.0.1';
  Result.AGameEngine := 'Unknown Engine';
  Result.ACompany := 'Tama Soft';
  Result.AExtension := 'Pak';
  Result.AMoreInfo := '(C)2012 HatsuneTakumi @ Kdays';
end;

exports AutoDetect;

exports GetPluginName;

exports GenerateEntries;

exports Decyption;

exports ReadData;

exports GetPluginInfo;

begin

end.
