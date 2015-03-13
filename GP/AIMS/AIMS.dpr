library AIMS;

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
    Magic: array [0 .. 3] of AnsiChar;
    entriesNum: Cardinal;
  End;

  Pack_Entries = packed Record
    filename: array [1 .. $40] of AnsiChar;
    hash: Cardinal;
    unknow: Cardinal;
    start_offset: Cardinal;
    length: Cardinal;
  End;

  Lzss_Head = packed record
    Magic: array [0 .. 3] of AnsiChar;
    decompress: Cardinal;
  end;

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], SizeOf(Pack_Head));
    if SameText(Trim(Head.Magic),'PACK') and
      (Head.entriesNum * SizeOf(Pack_Entries) <
      (FileBuffer.Size - FileBuffer.Position)) then
    begin
      Result := dsTrue;
    end;
  except
    Result := dsError;
  end;
end;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('AIMS', clEngine));
end;

function NameHash(const Name: AnsiString): Cardinal;
var
  eax, edi: Cardinal;
  i, j: Integer;
  tmp: AnsiString;
begin
  eax := $FFFFFFFF;
  tmp := Name;
  for i := 0 to length(tmp) - 1 do
  begin
    edi := Integer(Pbyte(tmp)[i]);
    eax := eax xor edi;
    for j := 0 to 7 do
    begin
      if Byte(eax) and $1 <> 0 then
      begin
        eax := (eax shr 1) xor $EDB88320;
      end
      else
        eax := (eax shr 1);
    end;
  end;
  Result := not eax;
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
    if (Head.entriesNum * SizeOf(Pack_Entries)) > FileBuffer.Size then
      raise Exception.Create('OVERFLOW');
    for i := 0 to Head.entriesNum - 1 do
    begin
      FileBuffer.Read(indexs.filename[1], SizeOf(Pack_Entries));
      Rlentry := TRlEntry.Create;
      Rlentry.AName := Trim(indexs.filename);
      Rlentry.AOffset := indexs.start_offset;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs.length;
      Rlentry.AHash[0] := indexs.unknow;
      Rlentry.ARLength := 0;
      if NameHash(Rlentry.AName) <> indexs.hash then
        Rlentry.AKey := 0
      else
        Rlentry.AKey := 1;
      if (Rlentry.AOffset + Rlentry.AStoreLength) > FileBuffer.Size then
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

function ReadData(FileBuffer: TFileBufferStream; OutBuffer: TStream): LongInt;
var
  decompr: TGlCompressBuffer;
  Head: Lzss_Head;
begin
  Result := FileBuffer.ReadData(OutBuffer);
  OutBuffer.Seek(0, soFromBeginning);
  OutBuffer.Read(Head.Magic[0], SizeOf(Lzss_Head));
  if SameText(Trim(Head.Magic), 'LZSS') then
  begin
    decompr := TGlCompressBuffer.Create;
    decompr.CopyFrom(OutBuffer, OutBuffer.Size - SizeOf(Lzss_Head));
    decompr.Seek(0, soFromBeginning);
    decompr.Output.Seek(0, soFromBeginning);
    decompr.LzssDecompress(decompr.Size, $FF0, $FFF);
    decompr.Output.Seek(0, soFromBeginning);
    OutBuffer.Size := 0;
    OutBuffer.Seek(0, soFromBeginning);
    OutBuffer.CopyFrom(decompr.Output, decompr.Output.Size);
    decompr.Destroy;
  end;
end;

exports AutoDetect;

exports GetPluginName;

exports GenerateEntries;

exports Decyption;

exports ReadData;

begin

end.
