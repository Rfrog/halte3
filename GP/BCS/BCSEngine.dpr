library BCSEngine;

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
    Magic: Array [0 .. 3] of AnsiChar;
    Data_Offset: Cardinal;
    File_Size: Cardinal;
    Entries_Count: Cardinal;
    Encode_Flag: Cardinal;
    File_Name_Length: Cardinal;
    Reserved1: Cardinal;
    Reserved2: Cardinal;
  End;

  Pack_Entries = packed Record
    File_Name: AnsiString;
    File_Counter: Cardinal;
    Start_Offset: Cardinal;
    Length: Cardinal;
    Reserved: Array of Cardinal;
  End;

  Hip_Head = packed record
    Magic: Array [0 .. 3] of AnsiChar;
    Unknown: Cardinal; // $125
    File_Length: Cardinal;
    unknow2: Cardinal;
    Width: Cardinal;
    Height: Cardinal;
    unknown3: Cardinal;
    Reserved: Cardinal;
  end;

  Hip_Block = packed record
    R: Byte;
    G: Byte;
    B: Byte;
    A: Byte;
    L: Byte;
  end;

procedure RleDecode(Input, Output: TStream);
var
  Block: Hip_Block;
  i: Integer;
begin
  while Input.Position < Input.Size do
  begin
    Input.Read(Block.R, SizeOf(Hip_Block));
    for i := 0 to Block.L - 1 do
      Output.Write(Block.R, SizeOf(Hip_Block) - 1);
  end;
end;

procedure RleEncode(Input, Output: TStream);
var
  Block: Hip_Block;
begin
  Block.L := 1;
  while Input.Position < Input.Size do
  begin
    Input.Read(Block.R, SizeOf(Hip_Block) - 1);
    Output.Write(Block.R, SizeOf(Hip_Block));
  end;
end;

const
  HIPMagic: AnsiString = 'HIP';

procedure PackImage(Input, Output: TStream);
var
  Head: Hip_Head;
  Pic_Header_Info: BITMAPFILEHEADER;
  Bit_Header_Info: BITMAPINFOHEADER;
  ipos: int64;
begin
  Input.Read(Pic_Header_Info.bfType, SizeOf(BITMAPFILEHEADER));
  Input.Read(Bit_Header_Info.biSize, SizeOf(BITMAPINFOHEADER));
  ZeroMemory(@Head.Magic[0], SizeOf(Hip_Head));
  Head.Width := Bit_Header_Info.biWidth;
  Head.Height := Bit_Header_Info.biHeight;
  Head.Unknown := $125;
  Head.unknow2 := 0;
  Head.unknown3 := $110;
  ipos := Output.Position;
  Move(Pbyte(HIPMagic)^, Head.Magic[0], Length(HIPMagic));
  Output.Write(Head.Magic[0], SizeOf(Hip_Head));
  RleEncode(Input, Output);
  Head.File_Length := Output.Size;
  Output.Seek(ipos, soFromBeginning);
  Output.Write(Head.Magic[0], SizeOf(Hip_Head));
end;

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], SizeOf(Pack_Head));
    if SameText(Trim(Head.Magic), 'FPAC') then
    begin
      Result := dsTrue;
    end;
  except
    Result := dsError;
  end;
end;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName
    ('*BlazBlue Continuum Shift Game Engine', clGameName));
end;

procedure ReadIndexs(FileBuffer: TFileBufferStream;
  const Head: Pack_Head; var indexs: Pack_Entries);
var
  padNum: Cardinal;
begin
  padNum := (((Head.File_Name_Length + $0C) or $F) -
    (Head.File_Name_Length + $0C) + 1) div 4;
  SetLength(indexs.File_Name, Head.File_Name_Length);
  SetLength(indexs.Reserved, padNum);
  FileBuffer.Read(Pbyte(indexs.File_Name)^,
    Head.File_Name_Length);
  FileBuffer.Read(indexs.File_Counter, 4);
  FileBuffer.Read(indexs.Start_Offset, 4);
  FileBuffer.Read(indexs.Length, 4);
  FileBuffer.Seek(padNum * 4, soFromCurrent);
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  Head: Pack_Head;
  indexs: Pack_Entries;
  i: Integer;
  Rlentry: TRlEntry;
begin
  Result := True;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], SizeOf(Pack_Head));
    if not SameText(Trim(Head.Magic), 'FPAC') then
      raise Exception.Create('Magic Error.');
    for i := 0 to Head.Entries_Count - 1 do
    begin
      ReadIndexs(FileBuffer, Head, indexs);
      Rlentry := TRlEntry.Create;
      Rlentry.AOffset := indexs.Start_Offset + Head.Data_Offset;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs.Length;
      Rlentry.ARLength := 0;
      Rlentry.AName := Trim(indexs.File_Name);
      Rlentry.AKey := Head.Encode_Flag;
      IndexStream.Add(Rlentry);
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
  Img: string = '.hip';

function ReadData(FileBuffer: TFileBufferStream;
  OutBuffer: TStream): LongInt;
var
  tmpBuffer: TGlCompressBuffer;
  Head: Hip_Head;
  Pic_Header_Info: BITMAPFILEHEADER;
  Bit_Header_Info: BITMAPINFOHEADER;
begin
  if SameText(ExtractFileExt(FileBuffer.Rlentry.AName), Img) then
  begin
    tmpBuffer := TGlCompressBuffer.Create;
    Result := FileBuffer.ReadData(tmpBuffer);
    tmpBuffer.Seek(0, soFromBeginning);
    tmpBuffer.Read(Head.Magic[0], SizeOf(Head));
    tmpBuffer.Output.Write(Head.Magic[0], SizeOf(Head));
    RleDecode(tmpBuffer, tmpBuffer.Output);
    tmpBuffer.Output.Seek(0, soFromBeginning);
    // 填充bmp文件头信息
    Pic_Header_Info.bfType := $4D42;
    Pic_Header_Info.bfSize := tmpBuffer.Output.Size + 54 - $20;
    Pic_Header_Info.bfReserved1 := 0;
    Pic_Header_Info.bfReserved2 := 0;
    Pic_Header_Info.bfOffBits := 54;
    // 填充位图信息头
    FillMemory(@Bit_Header_Info.biSize,
      SizeOf(BITMAPINFOHEADER), 0);
    Bit_Header_Info.biSize := 40;
    Bit_Header_Info.biWidth := Head.Width;
    Bit_Header_Info.biHeight := Head.Height;
    Bit_Header_Info.biPlanes := 1;
    Bit_Header_Info.biBitCount := 32;
    OutBuffer.Write(Pic_Header_Info.bfType,
      SizeOf(BITMAPFILEHEADER));
    OutBuffer.Write(Bit_Header_Info.biSize,
      SizeOf(BITMAPINFOHEADER));
    tmpBuffer.Seek($20, soFromBeginning);
    OutBuffer.CopyFrom(tmpBuffer.Output,
      tmpBuffer.Output.Size - $20);
    tmpBuffer.Free;
  end
  else
    Result := FileBuffer.ReadData(OutBuffer);
end;

const
  Magic: AnsiString = 'FPAC';
  MaxNameLength: Cardinal = $58; // choose a length end with $08

function PackData(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream; var Percent: Word): Boolean;
var
  i: Integer;
  Head: Pack_Head;
  indexs: array of Pack_Entries;
  tmpBuffer: TGlCompressBuffer;
begin
  Result := True;
  try
    Percent := 0;
    FileBuffer.Seek(0, soFromBeginning);
    Head.Entries_Count := IndexStream.Count;
    Head.Encode_Flag := 0;
    Head.File_Name_Length := MaxNameLength;
    Move(Pbyte(Magic)^, Head.Magic[0], 4);
    FileBuffer.Write(Head.Magic[0], SizeOf(Pack_Head));
    SetLength(indexs, IndexStream.Count);
    for i := 0 to IndexStream.Count - 1 do
    begin
      SetLength(indexs[i].File_Name, MaxNameLength);
      FileBuffer.Write(Pbyte(indexs[i].File_Name)^,
        MaxNameLength);
      FileBuffer.Write(indexs[i].File_Counter, $C);
    end;
    Head.Data_Offset := FileBuffer.Position;
    tmpBuffer := TGlCompressBuffer.Create;
    for i := 0 to IndexStream.Count - 1 do
    begin
      tmpBuffer.Clear;
      tmpBuffer.LoadFromFile(IndexStream.ParentPath +
        IndexStream.Rlentry[i].AName);
      indexs[i].Start_Offset := FileBuffer.Position;
      indexs[i].Length := tmpBuffer.Size;
      indexs[i].File_Counter := i;
      Move(Pbyte(AnsiString(IndexStream.Rlentry[i].AName))^,
        Pbyte(indexs[i].File_Name)^, MaxNameLength);
      tmpBuffer.Seek(0, soFromBeginning);
      tmpBuffer.Output.Seek(0, soFromBeginning);
      if SameText(ExtractFileExt(IndexStream.Rlentry[i]
        .AName), Img) then
        PackImage(tmpBuffer, tmpBuffer.Output)
      else
        tmpBuffer.Output.CopyFrom(tmpBuffer, tmpBuffer.Size);
      FileBuffer.CopyFrom(tmpBuffer.Output,
        tmpBuffer.Output.Size);
      Percent := 90 * (i + 1) div IndexStream.Count;
    end;
    tmpBuffer.Free;
    Head.File_Size := FileBuffer.Size;
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Write(Head.Magic[0], SizeOf(Pack_Head));
    for i := 0 to IndexStream.Count - 1 do
    begin
      FileBuffer.Write(Pbyte(indexs[i].File_Name)^,
        MaxNameLength);
      FileBuffer.Write(indexs[i].File_Counter, $C);
    end;
  except
    Result := False;
  end;
end;

exports AutoDetect;

exports GetPluginName;

exports GenerateEntries;

exports Decyption;

exports ReadData;

exports PackData;

begin

end.
