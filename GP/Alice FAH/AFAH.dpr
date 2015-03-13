library AFAH;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  StrUtils,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas';

{$E gp}
{$R *.res}
// procedure DecodePointer(P:Pointer);stdcall;external 'NutriaCompressionLibrary.dll';

{ FuncName : AnsistringÅG end with 0
  Resetved? : cardinal;
  ???: cardinal;(may be description of type?) if result is void set it to ffffffff

  Unknow: cardinal;  // this is also seem as the paranum

  FuncParaNÅFcardinalÅG
  UnknowÅFCardinal // equal with funcparaN but what dose this doÅH  This may be readl num
  {//para has the similar structure as func.
  ParaÅFAnsistring
  ???: cardinal;(may be description of type?)
  Unknow: cardinal;  // this is also seem as the paranum
  Unknow: cardinal;   //just 0?
  Åp
  OffsetÅF cardinalÅG   this is offsetÅCwhen call this func may jmpto this offset }

Type
  Pack_Head = Packed Record
    Magic: ARRAY [0 .. 3] OF ANSICHAR;
    HeadLength: Cardinal;
    InfoPad: array [0 .. 7] of ANSICHAR;
    indexcompressFlag: Cardinal;
    DataCompressFlag: Cardinal;
    mINOR_vER: Word;
    Major_Ver: Word;
  End;

  Pack_Info = packed record
    Magic: ARRAY [0 .. 3] OF ANSICHAR;
    IndexEndOffset: Cardinal;
    DecompressedLength: Cardinal;
    Indexs: Cardinal;
  end;

  Pack_Entries = packed Record
    ReadStrLength: Cardinal;
    StoreStrLength: Cardinal;
    FileName: AnsiString;
    FileCount: Cardinal;
    Time: Cardinal; // also may be seed
    Time2: Cardinal;
    StartOffset: Cardinal;
    Length: Cardinal;
  End;

  Ain_Head = packed record
    Magic: array [0 .. 3] of ANSICHAR;
    Reserved: Cardinal;
    DecompressLength: Cardinal;
    StoreLength: Cardinal;
  end;

const
  EntryLength2: Cardinal = 7 * 4;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('Alice Soft', clGameMaker));
end;

const
  Magic: AnsiString = 'AFAH';
  AinMagic: AnsiString = 'AI2';
  asdmagic: AnsiString = 'PSR';

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], SizeOf(Pack_Head));
    if SameText(Trim(Head.Magic), Magic) or
      SameText(Trim(Head.Magic), AinMagic) or
      SameText(Trim(Head.Magic), asdmagic) then
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
  info: Pack_Info;
  AinHead: Ain_Head;
  Compress: TGlCompressBuffer;
  i: Integer;
  Rlentry: TRlEntry;
begin
  Result := True;
  try
    if SameText(ExtractFileExt(FileBuffer.FileName), '.afa') then
    begin
      Compress := TGlCompressBuffer.Create;
      FileBuffer.Seek(0, soFromBeginning);
      FileBuffer.Read(Head.Magic[0], SizeOf(Pack_Head));
      if not SameStr(Magic, Trim(Head.Magic)) then
        raise Exception.Create('Magic Error');
      FileBuffer.Seek(Head.HeadLength, soFromBeginning);
      FileBuffer.Read(info.Magic[0], SizeOf(Pack_Info));
      Compress.Seek(0, soFromBeginning);
      Compress.CopyFrom(FileBuffer, info.IndexEndOffset);
      Compress.Seek(0, soFromBeginning);
      Compress.ZlibDecompress(info.DecompressedLength);
      Compress.Output.Seek(0, soFromBeginning);
      if info.DecompressedLength <> Compress.Output.Size then
        raise Exception.Create('Decompress Error.');
      i := 0;
      while i < info.DecompressedLength do
      begin
        Rlentry := TRlEntry.Create;
        Compress.Output.Read(Indexs.ReadStrLength, 8);
        SetLength(Indexs.FileName, Indexs.StoreStrLength);
        Compress.Output.Read(Pbyte(Indexs.FileName)^,
          Indexs.StoreStrLength);
        Compress.Output.Read(Indexs.FileCount, 20);
        Rlentry.AOffset := Indexs.StartOffset +
          info.DecompressedLength + Head.HeadLength +
          SizeOf(Pack_Info);
        Rlentry.AOrigin := soFromBeginning;
        Rlentry.AStoreLength := Indexs.Length;
        Rlentry.AName := Trim(Indexs.FileName);
        IndexStream.Add(Rlentry);
        i := i + Indexs.StoreStrLength + EntryLength2;
      end;
      Compress.Destroy;
    end
    else if SameText(ExtractFileExt(FileBuffer.FileName),
      '.ain') then
    begin
      FileBuffer.Seek(0, soFromBeginning);
      FileBuffer.Read(AinHead.Magic[0], SizeOf(Ain_Head));
      if not SameStr(AinMagic, Trim(AinHead.Magic)) then
        raise Exception.Create('Magic Error');
      Rlentry := TRlEntry.Create;
      Rlentry.AName := ExtractFileName(FileBuffer.FileName);
      Rlentry.AOffset := FileBuffer.Position;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := AinHead.StoreLength;
      Rlentry.ARLength := AinHead.DecompressLength;
      Rlentry.AKey := 1;
      IndexStream.Add(Rlentry);
    end
    else if SameText(ExtractFileExt(FileBuffer.FileName),
      '.asd') then
    begin
      FileBuffer.Seek(0, soFromBeginning);
      FileBuffer.Read(AinHead.Magic[0], SizeOf(Ain_Head));
      if not SameStr(asdmagic, Trim(AinHead.Magic)) then
        raise Exception.Create('Magic Error');
      Rlentry := TRlEntry.Create;
      Rlentry.AName := ExtractFileName(FileBuffer.FileName);
      Rlentry.AOffset := FileBuffer.Position;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := AinHead.StoreLength;
      Rlentry.ARLength := AinHead.DecompressLength;
      Rlentry.AKey := 1;
      IndexStream.Add(Rlentry);
    end
    else
    begin
      raise Exception.Create('Unsupported.');
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
  Compress: TGlCompressBuffer;
  RlLength: Cardinal;
begin
  if FileBuffer.Rlentry.AKey = 1 then
  begin
    RlLength := FileBuffer.Rlentry.ARLength;
    FileBuffer.ReadData(OutBuffer);
    Compress := TGlCompressBuffer.Create;
    OutBuffer.Seek(0, soFromBeginning);
    Compress.CopyFrom(OutBuffer, OutBuffer.Size);
    Compress.Seek(0, soFromBeginning);
    Compress.ZlibDecompress(RlLength);
    Compress.Output.Seek(0, soFromBeginning);
    OutBuffer.Size := 0;
    Result := OutBuffer.CopyFrom(Compress.Output,
      Compress.Output.Size);
    Compress.Free;
  end
  else
  begin
    Result := FileBuffer.ReadData(OutBuffer);
  end;

end;

function PackData(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream; var Percent: Word): Boolean;
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
  Result.AVersion := '0.0.1Beta';
  Result.AGameEngine := 'AliceSoft Unknown Engine';
  Result.ACompany := 'AliceSoft';
  Result.AExtension := 'Ain/AFA/ASD';
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
