library St;

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

type
  Pack_Head = packed record
    Count: Cardinal;
  end;

  Pack_Entries = packed record
    Name: array [1 .. $20] of AnsiChar;
    Offset: Cardinal;
    Length: Cardinal;
  end;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('AISystem', clEngine));
end;

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Count, sizeof(Pack_Head));
    if (Head.Count < FileBuffer.Size) and
      (SameText(ExtractFileExt(FileBuffer.FileName), '.awf') or
      SameText(ExtractFileExt(FileBuffer.FileName), '.arc')) then
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
    if not((Head.Count < FileBuffer.Size) and
      (SameText(ExtractFileExt(FileBuffer.FileName), '.awf') or
      SameText(ExtractFileExt(FileBuffer.FileName), '.arc'))) then
      raise Exception.Create('Error magic.');
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Count, sizeof(Pack_Head));
    for i := 0 to Head.Count - 1 do
    begin
      FileBuffer.Read(Indexs.Name[1], sizeof(Indexs));
      Rlentry := TRlEntry.Create;
      Rlentry.AName := Trim(Indexs.Name);
      Rlentry.AOffset := Indexs.Offset;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := Indexs.Length;
      Rlentry.ARLength := Indexs.Length;
      if SameText(ExtractFileExt(Rlentry.AName), '.wav') then
      begin
        FileBuffer.Read(Rlentry.AKey, 4);
        FileBuffer.Read(Rlentry.AKey2, 4);
        FileBuffer.Read(Rlentry.ATime, 4);
      end;
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

type

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

  TImage = packed record
    Reserved: Cardinal;
    Width: Word;
    Height: Word;
  end;

function ReadData(FileBuffer: TFileBufferStream; OutBuffer: TStream): LongInt;
var
  Ext: string;
  tmp: byte;
  Pic_Header_Info: BITMAPFILEHEADER;
  Bit_Header_Info: BITMAPINFOHEADER;
  WaveHeader: TWaveRiffHeader;
  Image: TImage;
  Buffer: TGlCompressBuffer;
begin
  Result := -1;
  OutBuffer.Size := 0;
  OutBuffer.Seek(0, soFromBeginning);
  Ext := Trim(ExtractFileExt(FileBuffer.Rlentry.AName));
  if SameText(Ext, '.mes') then
  begin
    Result := FileBuffer.ReadData(OutBuffer);
    OutBuffer.Seek(0, soFromBeginning);
    while OutBuffer.Position < OutBuffer.Size do
    begin
      OutBuffer.Read(tmp, 1);
      tmp := tmp xor $55;
      OutBuffer.Seek(-1, soFromCurrent);
      OutBuffer.Write(tmp, 1);
    end;
  end
  else if SameText(Ext, '.wav') then
  begin
    WaveHeader.FRiffMagic := 'RIFF';
    WaveHeader.FSize := FileBuffer.Rlentry.AStoreLength +
      sizeof(TWaveRiffHeader);
    WaveHeader.FFormat := 'WAVE';
    WaveHeader.FFMTMagic := 'fmt ';
    WaveHeader.FSubChunkSize := 16;
    WaveHeader.FAudioFormat := 1;
    WaveHeader.FChannels := 2;
    WaveHeader.FSampleRate := 22050;
    WaveHeader.FByteRate := 22050;
    WaveHeader.FBlockAlign := 4;
    WaveHeader.FBitsPerSample := 16;
    WaveHeader.FDataMagic := 'data';
    WaveHeader.FDataSize := FileBuffer.Rlentry.AStoreLength;

    if FileBuffer.Rlentry.AKey <> $FFFFFFFF then
    begin
      OutBuffer.Write(WaveHeader.FRiffMagic[0], sizeof(TWaveRiffHeader));
    end;
    Result := FileBuffer.ReadData(OutBuffer);
  end
  else if SameText(Ext, '.g24') then
  begin
    Result := FileBuffer.ReadData(OutBuffer);
    FileBuffer.Seek(TSeekOrigin.soCurrent, -1);
    OutBuffer.Seek(0, soFromBeginning);
    OutBuffer.Read(Image.Reserved, sizeof(TImage));
    Pic_Header_Info.bfType := $4D42;
    Pic_Header_Info.bfSize := 3 * Image.Width * Image.Height + 54 - 8;
    Pic_Header_Info.bfReserved1 := 0;
    Pic_Header_Info.bfReserved2 := 0;
    Pic_Header_Info.bfOffBits := 54;
    FillMemory(@Bit_Header_Info.biSize, sizeof(Bit_Header_Info), 0);
    Bit_Header_Info.biSize := 40;
    Bit_Header_Info.biWidth := Image.Width;
    Bit_Header_Info.biHeight := Image.Height;
    Bit_Header_Info.biPlanes := 1;
    Bit_Header_Info.biBitCount := 24;

    Buffer := TGlCompressBuffer.Create;
    Buffer.CopyFrom(OutBuffer, OutBuffer.Size - sizeof(TImage));
    Buffer.Seek(0, soFromBeginning);
    Buffer.LzssDecompress(Buffer.Size, $FEE, $FFF);
    if Buffer.Output.Size <> 3 * Image.Width * Image.Height then
      raise Exception.Create('Decompr error.');
    Buffer.Output.Seek(0, soFromBeginning);
    OutBuffer.Size := 0;
    OutBuffer.Seek(0, soFromBeginning);
    Buffer.Seek(0, soFromBeginning);
    OutBuffer.Write(Pic_Header_Info.bfType, 14);
    OutBuffer.Write(Bit_Header_Info.biSize, 40);
    OutBuffer.CopyFrom(Buffer.Output, Buffer.Output.Size);
    Buffer.Free;
  end;
  OutBuffer.Seek(0, soFromBeginning);
end;

function GetPluginInfo: TGpInfo;
begin
  Result.ACopyRight := 'HatsuneTakumi';
  Result.AVersion := '0.0.1';
  Result.AGameEngine := 'AISystem';
  Result.ACompany := 'Silkys';
  Result.AExtension := 'ARC,AWF';
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
