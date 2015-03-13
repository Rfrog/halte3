library DigitalSystem;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  Windows,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas',
  StrUtils,
  Vcl.Dialogs
{$IFDEF debug}
    ,
  CodeSiteLogging
{$ENDIF};

{$E GP}
{$R *.res}


Type
  Pack_Head = Packed Record
    TableOffset: Cardinal;
    TableLength: Cardinal;
    Unknown_Flag: Word;
  End;

  Pack_Entries = packed Record
    Hash: Word; // 0 means end
    start_offset: Cardinal;
    length: Cardinal;
    EncodeFlag: Word;
  End;

  TPackageType = (ptSE, ptStr, ptTAK, ptVCE, ptVIS);

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('Digital System',
    clEngine));
end;

function GetFileName(PackageType: TPackageType; Hash: Word): string;
begin
  case PackageType of
    ptSE:
      Result := Format('_SE\_SE%.5d.OGG', [ Hash ]);
    ptStr:
      Result := Format('STR\STR%.5d.OGG', [ Hash ]);
    ptTAK:
      Result := Format('TAK\TAK%.5d.BIN', [ Hash ]);
    ptVCE:
      Result := Format('VCE\VCE%.5d.OGG', [ Hash ]);
    ptVIS:
      Result := Format('VIS\VIS%.5d.TMX', [ Hash ]);
  end;
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  head: Pack_Head;
  indexs: Pack_Entries;
  i: integer;
  Rlentry: TRlEntry;
  PackageType: TPackageType;
  ExeOffset: Cardinal;
  ExePath: string;
  FileOpenDialog: TFileOpenDialog;
  MyBuffer: TFileStream;
begin
  Result := True;
  try
    FileBuffer.Seek(0, soFromBeginning);
    if SameText(ExtractFileName(FileBuffer.FileName), '_SE.BIN') then
      PackageType := ptSE
    else
      if SameText(ExtractFileName(FileBuffer.FileName), 'STR.BIN') then
      PackageType := ptStr
    else
      if SameText(ExtractFileName(FileBuffer.FileName), 'TAK.BIN') then
      PackageType := ptTAK
    else
      if SameText(ExtractFileName(FileBuffer.FileName), 'VCE.BIN') then
      PackageType := ptVCE
    else
      if SameText(ExtractFileName(FileBuffer.FileName), 'VIS.BIN') then
      PackageType := ptVIS
    else
      raise Exception.Create('No pattern found.');

    case PackageType of
      ptSE:
        ExeOffset := $30970;
      ptStr:
        ExeOffset := $30870;
      ptTAK:
        ExeOffset := $2ECA0;
      ptVCE:
        ExeOffset := $30B68;
      ptVIS:
        ExeOffset := $2EED8;
    else
      ExeOffset := 0;
    end;

    FileOpenDialog := TFileOpenDialog.Create(nil);
    try
      ExeOffset := StrToIntDef(inputbox('Need offset',
        'Table offset stored in exe,u should point it out.',
        '$' + IntTohex(ExeOffset, 8)), ExeOffset);
      if FileOpenDialog.Execute then
        ExePath := FileOpenDialog.FileName
      else
        raise Exception.Create('Exe path missed.');
    finally
      FileOpenDialog.Free;
    end;

{$IFDEF debug}
    CodeSite.Send('ExeOffset: ', IntTohex(ExeOffset, 8));
    CodeSite.Send('ExePath: ', ExePath);
{$ENDIF}
    MyBuffer := TFileStream.Create(ExePath, fmOpenRead);
    try
      i := SizeOf(Pack_Head);
      MyBuffer.Seek(ExeOffset, soFromBeginning);
      MyBuffer.Read(head.TableOffset, SizeOf(Pack_Head));
      indexs.Hash := 1;

{$IFDEF debug}
      CodeSite.Send('TableOffset: ', head.TableOffset);
      CodeSite.Send('TableLength: ', head.TableLength);
      CodeSite.Send('Unknown_Flag: ', head.Unknown_Flag);
{$ENDIF}
      while (indexs.Hash <> 0) and (i < head.TableLength) do
      begin
        MyBuffer.Read(indexs.Hash, SizeOf(Pack_Entries));
        if indexs.Hash = 0 then
          break;
        Rlentry := TRlEntry.Create;
        Rlentry.AName := Trim(GetFileName(PackageType, indexs.Hash));
        Rlentry.AOffset := indexs.start_offset;
        Rlentry.AOrigin := soFromBeginning;
        Rlentry.AStoreLength := indexs.length;
        Rlentry.AKey := indexs.EncodeFlag;
        IndexStream.ADD(Rlentry);
        i := i + SizeOf(Pack_Entries);

{$IFDEF debug}
        CodeSite.Send('Name: ', Rlentry.AName);
        CodeSite.Send('Flag: ', indexs.EncodeFlag);
{$ENDIF}
      end;
    finally
      MyBuffer.Free;
    end;
  except
    Result := False;
  end;
end;

type
  LZS_Head = packed record
    Magic: array [ 0 .. 3 ] of AnsiChar; // LZS
    length: Cardinal;
  end;

  RAW_Head = packed record
    Magic: array [ 0 .. 1 ] of AnsiChar;
    Width: Word;
    Height: Word;
    Flag: Word;
    Reserved: Cardinal;
    Reserved2: Cardinal;
  end;

  ARGB = packed record
    case Byte of
      1:
        (ARGB: Cardinal);
      2:
        (A: Byte;
          R: Byte;
          G: Byte;
          B: Byte;);
  end;

procedure SwapBuffer(input, output: TStream; length: Cardinal);
var
  Sect: ARGB;
  i: integer;
begin
  i := 0;
  while i < length do
  begin
    input.Read(Sect.ARGB, SizeOf(ARGB));
    output.Write(Sect.B, 1);
    output.Write(Sect.G, 1);
    output.Write(Sect.R, 1);
    output.Write(Sect.A, 1);
    i := i + 4;
  end;
end;

{$DEFINE Down}


procedure MixPicture(input, output: TStream; Width, Height: Cardinal);
var
  ipos: Int64;
  i, j, k: integer;
begin
  ipos := input.Position;
{$IFDEF Down}
  for i := Height - 1 downto 0 do
  begin
    for k := $100 - 1 downto 0 do
    begin
      for j := 0 to Width - 1 do
      begin
        input.Seek(ipos + (i * Width + j) * $100 * $100 + k * Width * $100,
          soFromBeginning);
        SwapBuffer(input, output, $100);
      end;
    end;
  end;
{$ELSE}
  for i := 0 to Height - 1 do
  begin
    for k := 0 to $100 - 1 do
    begin
      for j := 0 to Width - 1 do
      begin
        input.Seek(ipos + (i * Width + j) * $100 * $100 + k * Width * $100,
          soFromBeginning);
        SwapBuffer(input, output, $100);
      end;
    end;
  end;
{$ENDIF}
end;

function ReadData(FileBuffer: TFileBufferStream;
  OutBuffer: TStream): LongInt;
var
  Buffer: TGlCompressBuffer;
  head: LZS_Head;
  Head2: RAW_Head;
  Pic_Header_Info: BITMAPFILEHEADER;
  Bit_Header_Info: BITMAPINFOHEADER;
begin
  Buffer := TGlCompressBuffer.Create;
  try
    FileBuffer.ReadData(OutBuffer);
    OutBuffer.Seek(0, soFromBeginning);
    OutBuffer.Read(head.Magic[ 0 ], SizeOf(LZS_Head));
    if SameText(Trim(head.Magic), 'LZS') then
    begin
      Buffer.Seek(0, soFromBeginning);
      Buffer.CopyFrom(OutBuffer, OutBuffer.Size - SizeOf(LZS_Head));
      Buffer.Seek(0, soFromBeginning);
      Buffer.LzssDecompress(Buffer.Size, $FEE, $FFF);

      Buffer.output.Seek(0, soFromBeginning);
      OutBuffer.Size := 0;

      Buffer.output.Read(Head2.Magic[ 0 ], SizeOf(RAW_Head));
      if {$IFDEF Picture}Head2.Flag = 1{$ELSE} False {$ENDIF} then
      begin
        Pic_Header_Info.bfType := $4D42;
        Pic_Header_Info.bfSize := Head2.Width * Head2.Height * $10000 + 54;
        Pic_Header_Info.bfReserved1 := 0;
        Pic_Header_Info.bfReserved2 := 0;
        Pic_Header_Info.bfOffBits := 54;
        FillMemory(@Bit_Header_Info.biSize, SizeOf(Bit_Header_Info), 0);
        Bit_Header_Info.biSize := 40;
        Bit_Header_Info.biWidth := Head2.Width * $100 div 2;
        Bit_Header_Info.biHeight := Head2.Height * $100 div 2;
        Bit_Header_Info.biPlanes := 1;
        Bit_Header_Info.biBitCount := 32;
        OutBuffer.Write(Pic_Header_Info.bfType, 14);
        OutBuffer.Write(Bit_Header_Info.biSize, 40);
        MixPicture(Buffer.output, OutBuffer, Head2.Width, Head2.Height);
        // SwapBuffer(Buffer.output, OutBuffer, Pic_Header_Info.bfSize - 54);
      end
      else
      begin
        Buffer.output.Seek(0, soFromBeginning);
        OutBuffer.CopyFrom(Buffer.output, Buffer.output.Size -
          Buffer.output.Position);
      end;
{$IFDEF debug}
      CodeSite.Send('Len2: ', Buffer.output.Size);
      CodeSite.Send('Size: ', Pic_Header_Info.bfSize - 54);
      CodeSite.Send('Width: ', Head2.Width);
      CodeSite.Send('Height: ', Head2.Height);
      CodeSite.Send('calced Width: ', Bit_Header_Info.biWidth);
      CodeSite.Send('calced Height: ', Bit_Header_Info.biHeight);
{$ENDIF}
    end;
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
  ZeroMemory(@indexs[ 0 ].Hash, IndexStream.Count *
    SizeOf(Pack_Entries));
  for i := 0 to IndexStream.Count - 1 do
  begin
    indexs[ i ].start_offset := IndexStream.Rlentry[ i ].AOffset +
      IndexStream.Count * SizeOf(Pack_Entries) + SizeOf(Pack_Head);
    indexs[ i ].length := IndexStream.Rlentry[ i ].AStoreLength;
  end;
  IndexOutBuffer.Write(indexs[ 0 ].Hash, IndexStream.Count *
    SizeOf(Pack_Entries));
end;

function MakePackage(IndexStream: TIndexStream;
  IndexOutBuffer, FileOutBuffer: TStream;
  Package: TFileBufferStream): Boolean;
var
  head: Pack_Head;
begin
  IndexOutBuffer.Seek(0, soFromBeginning);
  FileOutBuffer.Seek(0, soFromBeginning);
Package.CopyFrom(FileOutBuffer, FileOutBuffer.Size);
end;

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
