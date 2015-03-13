library NUGSystem;

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
    Length: DWORD;
    RESERVED: DWORD;
    ENTRIES_COUNT: DWORD;
    ENTRIES_OFFSET: DWORD;
    Pad: Array [0 .. 10] of DWORD;
  End;

  Pack_Entries = Record
    Length: DWORD;
    FILE_OFFSET: DWORD;
    FILE_LENGTH: DWORD;
    HASH: DWORD;
    FILE_NAME: array [1 .. $30] of AnsiChar;
  End;

  Head_Scr = Packed Record
    Magic: ARRAY [0 .. 3] OF AnsiChar;
    HEADER_LENGTH: DWORD;
    flag: DWORD;
    Compressed_Length: DWORD;
    DECOMPR_LENGTH: DWORD;
    Pad: ARRAY [0 .. 2] OF DWORD;
  End;

  Const
Magic:Ansistring='1AWF';

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName
    ('NUG System', clEngine));
end;

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], sizeof(Pack_Head));
    if SameText(Trim(Head.Magic), Magic) and
      (Head.ENTRIES_OFFSET < FileBuffer.Size) and
      (Head.ENTRIES_COUNT < FileBuffer.Size) and
      (Head.Length < FileBuffer.Size) and
      (Head.RESERVED = 0) then
    begin
      Result := dsTrue;
    end;
  except
    Result := dsError;
  end;
end;

//哈希要求：第一个字符不能是 '\'或#0，还有一个 地址 and 3，意义不明
//并且总是从第二位开始
function Hash(const Buffer: PByte;const size: Cardinal):Cardinal;
var Mypointer: PByte;
    ecx,edi,eax,esi,ebx: Cardinal;
    i: Integer;
begin
  Mypointer := Buffer;
  ebx := $5c5c5c5c;
  i := 0;
  while true do
  begin
    ecx := Pdword(@Mypointer[i])^;
    edi := $7efefeff;
    eax := ecx;
    esi := edi;
    ecx := ecx xor ebx;
    esi := esi + eax;
    edi := edi + ecx;
    ecx := ecx xor $ffffffff;
    eax := eax xor $ffffffff;
    ecx := ecx xor edi;
    eax := eax xor esi;
    i := i + 4;
    ecx := ecx and $81010100;
    if ecx <> 0 then
    begin
     //exception
     Break;
    end;
    eax := eax and $81010100;
    if eax = 0 then
      Continue;
    eax := eax and $1010100;
    if eax <> 0 then
    Break;
    esi := esi and $80000000;
    if esi = 0 then
    Break;
  end;
end;


function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  Head: Pack_Head;
  indexs: Pack_Entries;
  i: Integer;
  Rlentry: TRlEntry;
  Hash2: array of Cardinal;
begin
  Result := True;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], SizeOf(Pack_Head));
    if not SameText(Trim(Head.Magic), Magic) then
        raise Exception.Create('Magic Error.');
    FileBuffer.Seek(Head.ENTRIES_OFFSET, soFromBeginning);
    if (Head.ENTRIES_COUNT * SizeOf(Pack_Entries)) > FileBuffer.Size then
      raise Exception.Create('OVERFLOW');
    SetLength(Hash2,head.ENTRIES_COUNT);
    FileBuffer.Read(hash2[0],head.ENTRIES_COUNT * $4);
    for i := 0 to Head.ENTRIES_COUNT - 1 do
    begin
      FileBuffer.Read(indexs.Length, SizeOf(Pack_Entries));
      Rlentry := TRlEntry.Create;
      Rlentry.AName := Trim(indexs.FILE_NAME);
      Rlentry.AOffset := indexs.FILE_OFFSET;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs.FILE_LENGTH;
      Rlentry.ARLength := 0;
      Rlentry.AHash[0] := indexs.HASH;
      Rlentry.AHash[1] := Hash2[i];
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
  head2: Head_Scr;
begin
  Result := FileBuffer.ReadData(OutBuffer);
  OutBuffer.Seek(0, soFromBeginning);
  OutBuffer.Read(head2.Magic[0], SizeOf(Head_Scr));
  if SameText(Trim(Head2.Magic), 'SCWF') then
  begin
      decompr := TGlCompressBuffer.Create;
      if (head2.DECOMPR_LENGTH <> 0) then
      begin
        decompr.CopyFrom(OutBuffer, OutBuffer.Size - SizeOf(Head_Scr));
        decompr.Seek(0, soFromBeginning);
        decompr.Seek(0, soFromBeginning);
        decompr.Output.Seek(0, soFromBeginning);
        decompr.LzssDecompress(decompr.Size, $FEE, $FFF);
        decompr.Output.Seek(0, soFromBeginning);
      end
      else
      begin
        decompr.CopyFrom(OutBuffer, OutBuffer.Size - SizeOf(Head_Scr));
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

exports Autodetect;

exports GetPluginName;

exports GenerateEntries;

exports Decyption;

exports ReadData;

begin

end.
