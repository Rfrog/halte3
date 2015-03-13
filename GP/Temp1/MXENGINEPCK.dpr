library MXENGINEPCK;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  Windows,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas',
  StrUtils, Vcl.Dialogs, CodeSiteLogging;

{$E GP}
{$R *.res}
{$DEFINE DECOMPRESS}

Type
  Pack_Head = Packed Record
    Magic: array [0 .. $F] of AnsiChar;
    Unknow1: Cardinal;
    Unknow2: Cardinal;
    indexs_Len: Cardinal;
  End;

  Voice_Head = packed record
    UNKNOW: array [0 .. 39] of Byte;
  end;

  Voice_Entries = packed record
    Flag: Cardinal;
    NameLen1: Cardinal;
    Name1: AnsiString;
    Flag0: Byte;
    Sym1: Cardinal;
    Sym2: Cardinal;
    Flag1: Byte;
    NameLen2: Cardinal;
    Name2: AnsiString;
    Meta: array [0 .. 32] of Byte;
    DataLen: Cardinal;
    Meta1: array [0 .. 6] of Byte;
  end;

  WAVHead = packed record
    Magic: array [0 .. 3] of AnsiChar;
    fileSize: Cardinal;
    WAV: array [0 .. 3] of AnsiChar;
    FMT: array [0 .. 3] of AnsiChar;
    FB: Cardinal;
    PCMType: Word;
    Chns: Word;
    BI: Cardinal;
    BPS: Cardinal;
    Adapt: Word;
    SampleData: Word;
  end;

function EndianSwap(const a: integer): integer;
asm
  bswap eax
end;

const
  Magic: AnsiString = 'MXENGINEPCK';
  WAVEHead: array [0 .. $2D] of Byte = (82, 73, 70, 70, 4, 181,
    206, 2, 87, 65, 86, 69, 102, 109, 116, 32, 16, 0, 0, 0, 1, 0,
    1, 0, $22, $56, 0, 0, $44, $ac, 0, 0, 2, 0, 16, 0, 100, 97,
    116, 97, 224, 180, 206, 2, $0, $0);

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(head.Magic[0], SizeOf(Pack_Head));
    if SameText(Magic, Trim(head.Magic)) then
    begin
      Result := dsTrue;
      Exit;
    end;
  except
    Result := dsError;
  end;
end;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('MXENGINEPCK', clEngine));
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  head: Voice_Head;
  Entry: Voice_Entries;
  i: integer;
  Rlentry: TRlEntry;
begin
  Result := True;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(head.UNKNOW[0], SizeOf(Voice_Head));
    while FileBuffer.Position < (FileBuffer.Size - $50) do
    begin
      FileBuffer.Read(Entry.Flag, 8);
      CodeSite.Send('Len1', Entry.NameLen1);
      if Entry.NameLen1 = 0 then
        Exit;
      SetLength(Entry.Name1, Entry.NameLen1);
      FileBuffer.Read(Pbyte(Entry.Name1)^, Entry.NameLen1);
      FileBuffer.Read(Entry.Flag0, 14);
      CodeSite.Send('Len2', Entry.NameLen2);
      if Entry.NameLen2 = 0 then
        Exit;
      SetLength(Entry.Name2, Entry.NameLen2);
      FileBuffer.Read(Pbyte(Entry.Name2)^, Entry.NameLen2);
      FileBuffer.Read(Entry.Meta[0], $2B);
      CodeSite.Send('DataLen', Entry.DataLen);
      if Entry.DataLen = 0 then
        Exit;
      Rlentry := TRlEntry.Create;
      Rlentry.AName := Entry.Name2;
      Rlentry.AOffset := FileBuffer.Position;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := Entry.DataLen - 2;
      IndexStream.ADD(Rlentry);
      FileBuffer.Seek(Entry.DataLen, soFromCurrent);
    end;
  except
    Result := False;
  end;
end;

{$DEFINE USERLE}

function ReadData(FileBuffer: TFileBufferStream;
  OutBuffer: TStream): LongInt;
var
  head: WAVHead;
  Size: Cardinal;
begin
  OutBuffer.Write(WAVEHead[0], $2E);
  Result := FileBuffer.ReadData(OutBuffer);
  OutBuffer.Seek(4, soFromBeginning);
  Size := OutBuffer.Size;
  OutBuffer.Write(Size, 4);
  OutBuffer.Seek($28, soFromBeginning);
  Size := Size - $20;
  OutBuffer.Write(Size, 4);
end;

exports AutoDetect;

exports GetPluginName;

exports GenerateEntries;

exports ReadData;

begin

end.
