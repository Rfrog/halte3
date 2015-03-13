library SystemAoi;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  StrUtils,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas',
  Windows, Vcl.Dialogs;

{$E gp}
{$R *.res}

Type
  Pack_Head = Packed Record
    Magic: array [0 .. 1] of AnsiChar;
    Version1: Byte;
    Version2: Byte;
    Indexs: Word;
    EntryLength: Word;
    IndexsLength: Cardinal;
    FileSize: Cardinal;
  End;

  Pack_Entries = packed Record
    File_name: ARRAY [1 .. $13] OF AnsiChar;
    START_OFFSET: Cardinal;
    Decompress_Length: Cardinal;
    Length: Cardinal;
    flag: Byte;
  End;

  RiffHead = packed record
    Magic: array [0 .. 3] of AnsiChar;
    HeadLength: Cardinal;
    Ext: array [0 .. 3] of AnsiChar;
    Func: array [0 .. 3] of AnsiChar;
    Unknow: Cardinal; // $24
    Unknow1: Word; // $03
    Unknow2: Word; // $03 version?
    Pad: array [0 .. 7] of Cardinal;
  end;

  BmpHead = packed record
    Magic: array [0 .. 3] of AnsiChar;
    FileSize: Cardinal;
    Width: Word;
    Height: Word;
    PositionX: Cardinal;
    PositionY: Cardinal;
    Reserved: Cardinal;
  end;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('SystemAoi', clEngine));
end;

const
  Magic = 'VF';
  Magic2 = 'VL';

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], sizeof(Pack_Head));
    if (SameText(Trim(Head.Magic), Magic) or
      SameText(Trim(Head.Magic), Magic)) and
      (Head.Indexs < FileBuffer.Size) and
      (Head.EntryLength < FileBuffer.Size) and
      (Head.IndexsLength < FileBuffer.Size) and
      (Head.FileSize = FileBuffer.Size) then
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
    if not(SameText(Trim(Head.Magic), Magic) or
      SameText(Trim(Head.Magic), Magic)) then
      raise Exception.Create('Magic Error.');
    for i := 0 to Head.Indexs - 1 do
    begin
      FileBuffer.Read(Indexs.File_name[1], Head.EntryLength);
      Rlentry := TRlEntry.Create;
      Rlentry.AOffset := Indexs.START_OFFSET;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := Indexs.Length;
      Rlentry.ARLength := Indexs.Decompress_Length;
      Rlentry.AName := Trim(Indexs.File_name);
      Rlentry.AKey := Indexs.flag;
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
  RawHead = 'RIFF';
  IPHImage = 'IPH';

function ReadData(FileBuffer: TFileBufferStream;
  OutBuffer: TStream): LongInt;
var
  compr: TGlCompressBuffer;
  Head: RiffHead;
  Head1: BmpHead;
  BitmapHead: BITMAPFILEHEADER;
  BitmapInfo: BITMAPINFOHEADER;
begin
  compr := TGlCompressBuffer.Create;
  if FileBuffer.Rlentry.AKey = 1 then
  begin
    Result := FileBuffer.ReadData(compr);
    compr.Seek(0, soFromBeginning);
    compr.Output.Seek(0, soFromBeginning);
    compr.LzssDecompress(compr.Size, $FEE, $FFF);
    compr.Output.Seek(0, soFromBeginning);
  end
  else
  begin
    compr.Output.Size := 0;
    compr.Output.Seek(0, soFromBeginning);
    Result := FileBuffer.ReadData(compr.Output);
    compr.Output.Seek(0, soFromBeginning);
  end;
  compr.Output.Read(Head.Magic[0], sizeof(RiffHead));
  if SameText(Trim(Head.Magic), RawHead) then
  begin
    if SameText(Trim(Head.Ext), IPHImage) then
    begin
      compr.Output.Read(Head1.Magic[0], sizeof(BmpHead));
      ZeroMemory(@BitmapHead.bfType, sizeof(BITMAPFILEHEADER));
      ZeroMemory(@BitmapInfo.biSize, sizeof(BITMAPINFOHEADER));
      BitmapHead.bfType := $4D42;
      BitmapHead.bfSize := Head1.FileSize - sizeof(BmpHead) +
        sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER);
      BitmapHead.bfOffBits := 54;
      BitmapInfo.biSize := 40;
      BitmapInfo.biWidth := Head1.Width;
      BitmapInfo.biHeight := Head1.Height;
      BitmapInfo.biPlanes := 1;
      BitmapInfo.biBitCount := 24;
      OutBuffer.Write(BitmapHead.bfType,
        sizeof(BITMAPFILEHEADER));
      OutBuffer.Write(BitmapInfo.biSize,
        sizeof(BITMAPINFOHEADER));
      OutBuffer.CopyFrom(compr.Output, compr.Output.Size -
        compr.Output.Position);
    end
    else
      OutBuffer.CopyFrom(compr.Output, compr.Output.Size -
        compr.Output.Position);
  end
  else
  begin
    compr.Output.Seek(0, soFromBeginning);
    OutBuffer.CopyFrom(compr.Output, compr.Output.Size);
  end;
  compr.Destroy;
end;

function PackData(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream; var Percent: Word): Boolean;
var
  i: Integer;
  Head: Pack_Head;
  Indexs: array of Pack_Entries;
  tmpbuffer: TFileStream;
  tmpsize: Cardinal;
begin
  Result := True;
  try
    Percent := 0;

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
