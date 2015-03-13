library SCE;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  Windows,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas';

{$E GP}
{$R *.res}

Type
  Pack_Head = Packed Record
    Magic: Array [0 .. 3] of AnsiChar;
    Entries_Offset: Cardinal;
  End;

  Pack_Entries = packed Record
    Start_Offset: Cardinal;
    Length: Cardinal;
    FileName: ARRAY [1 .. $80] OF AnsiChar;
  End;

  Head_Rec = Packed Record
    Magic: Array [0 .. 3] of AnsiChar;
    Reserved: dword;
    Compress_Flag: dword;
    Compressed_Length: dword;
    Decompressed_Length: dword;
    Head_Length: dword;
    biSize: dword;
    biWidth: dword;
    biHeight: dword;
    biPlanes: WORD;
    biBitCount: WORD;
    biCompression: dword;
    biSizeImage: dword;
    biXPelsPerMeter: dword;
    biYPelsPerMeter: dword;
    biClrUsed: dword;
    biClrImportant: dword;
  End;

  Head_Scr = Packed Record
    Magic: Array [0 .. 3] of AnsiChar; // GLPK
    Decompressed_Length: dword;
    Compress_Flag: dword;
  End;

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], sizeof(Pack_Head));
    if (SameText(Trim(Head.Magic), 'GPK2') or
      SameText(Trim(Head.Magic), 'GLPK')) and
      (Head.Entries_Offset < FileBuffer.Size) then
    begin
      Result := dsTrue;
    end;
  except
    Result := dsError;
  end;
end;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('SCE', clEngine));
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  Head: Pack_Head;
  indexs: Pack_Entries;
  i: Integer;
  Rlentry: TRlEntry;
  indexNum: Cardinal;
begin
  Result := True;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], sizeof(Pack_Head));
    if not SameText(Trim(Head.Magic), 'GPK2') then
      if SameText(Trim(Head.Magic), 'GLPK') then
      begin
        Rlentry := TRlEntry.Create;
        Rlentry.AName := ExtractFileName(FileBuffer.FileName);
        Rlentry.AOffset := 0;
        Rlentry.AOrigin := soFromBeginning;
        Rlentry.AStoreLength := FileBuffer.Size;
        Rlentry.ARLength := 0;
        IndexStream.Add(Rlentry);
        Exit;
      end
      else
        raise Exception.Create('Magic Error.');
    FileBuffer.Seek(Head.Entries_Offset, soFromBeginning);
    FileBuffer.Read(indexNum, 4);
    if (indexNum * sizeof(Pack_Entries)) > FileBuffer.Size then
      raise Exception.Create('OVERFLOW');
    for i := 0 to indexNum - 1 do
    begin
      FileBuffer.Read(indexs.Start_Offset, sizeof(Pack_Entries));
      Rlentry := TRlEntry.Create;
      Rlentry.AName := Trim(indexs.FileName);
      Rlentry.AOffset := indexs.Start_Offset;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs.Length;
      Rlentry.ARLength := 0;
      if (Rlentry.AOffset + Rlentry.AStoreLength) >
        FileBuffer.Size then
        raise Exception.Create('OverFlow');
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

function ReadData(FileBuffer: TFileBufferStream;
  OutBuffer: TStream): LongInt;
var
  decompr: TGlCompressBuffer;
  Head: Head_Rec;
  BitMapHeader: BITMAPFILEHEADER;
  BitMapHeader2: BITMAPINFOHEADER;
  head2: Head_Scr;
  i: Integer;
  tmp: Byte;
begin
  Result := FileBuffer.ReadData(OutBuffer);
  OutBuffer.Seek(0, soFromBeginning);
  OutBuffer.Read(Head.Magic[0], sizeof(Head_Rec));
  if SameText(Trim(Head.Magic), 'GFB') then
  begin
    decompr := TGlCompressBuffer.Create;
    if (Head.Compress_Flag = 1) then
    begin
      decompr.CopyFrom(OutBuffer, OutBuffer.Size -
        sizeof(Head_Rec));
      decompr.Seek(0, soFromBeginning);
      decompr.Output.Seek(0, soFromBeginning);
      decompr.LzssDecompress(decompr.Size, $FEE, $FFF);
      decompr.Output.Seek(0, soFromBeginning);
    end
    else
    begin
      decompr.CopyFrom(OutBuffer, OutBuffer.Size -
        sizeof(Head_Rec));
      decompr.Seek(0, soFromBeginning);
      decompr.Output.Size := 0;
      decompr.Output.Seek(0, soFromBeginning);
      decompr.Output.CopyFrom(decompr, decompr.Size);
    end;
    OutBuffer.Size := 0;
    OutBuffer.Seek(0, soFromBeginning);
    Move(Head.biSize, BitMapHeader2.biSize, $28);
    FillMemory(@BitMapHeader.bfType, 14, 0);
    BitMapHeader.bfType := $4D42;
    BitMapHeader.bfSize := Head.Decompressed_Length;
    BitMapHeader.bfOffBits := 54;
    OutBuffer.Write(BitMapHeader.bfType, 14);
    OutBuffer.Write(BitMapHeader2.biSize, 40);
    OutBuffer.CopyFrom(decompr.Output, decompr.Output.Size);
    decompr.Destroy;
  end
  else
  begin
    OutBuffer.Seek(0, soFromBeginning);
    OutBuffer.Read(head2.Magic[0], sizeof(Head_Scr));
    if SameText(Trim(head2.Magic), 'GLPK') then
    begin
      decompr := TGlCompressBuffer.Create;
      if (head2.Compress_Flag = 1) then
      begin
        decompr.CopyFrom(OutBuffer, OutBuffer.Size -
          sizeof(Head_Scr));
        decompr.Seek(0, soFromBeginning);
        for i := 0 to decompr.Size - 1 do
        begin
          decompr.Read(tmp, 1);
          decompr.Seek(-1, soFromCurrent);
          tmp := not tmp;
          decompr.Write(tmp, 1);
        end;
        decompr.Seek(0, soFromBeginning);
        decompr.Output.Seek(0, soFromBeginning);
        decompr.LzssDecompress(decompr.Size, $FEE, $FFF);
        decompr.Output.Seek(0, soFromBeginning);
      end
      else
      begin
        decompr.CopyFrom(OutBuffer, OutBuffer.Size -
          sizeof(Head_Scr));
        decompr.Seek(0, soFromBeginning);
        decompr.Output.Size := 0;
        decompr.Output.Seek(0, soFromBeginning);
        decompr.Output.CopyFrom(decompr, decompr.Size);
      end;
      OutBuffer.Size := 0;
      OutBuffer.Seek(0, soFromBeginning);
      OutBuffer.CopyFrom(decompr.Output, decompr.Output.Size);
    end;
  end;
end;

exports AutoDetect;

exports GetPluginName;

exports GenerateEntries;

exports Decyption;

exports ReadData;

begin

end.
