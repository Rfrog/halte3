library Chariot;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  StrUtils,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas',
  Windows
{$IFDEF DEBUG}
    , CodeSiteLogging
{$ENDIF};

{$E gp}
{$R *.res}
{ .$DEFINE SP }

Type
  Pack_Head = Packed Record
    Magic: array [0 .. 3] of ansichar;
    Version: cardinal;
    Unknow: cardinal;
    DataEncoded: cardinal;
    Unknow1: cardinal;
    IndexEncoded: cardinal;
    Entries_Count: cardinal;
    IndexLen: cardinal;
    DataLen: cardinal;
    Unknow3: cardinal;
    DataOffset: cardinal;
    Unknow4: cardinal;
  End;

  Pack_Entries = packed Record
    EntryLen: cardinal;
    Length: cardinal;
    Unknow: cardinal; // 0
    FileNameLen: cardinal;
    Hash: cardinal;
    Hash1: cardinal;
    Start_Offset: cardinal;
    Unknow1: cardinal; // 0
    File_name: array of Char;
  End;

const
  XorTable: array [0 .. $16] of Byte = ($40, $21, $28, $38, $A6,
    $6E, $43, $A5, $40, $21, $28, $38, $A6, $43, $A5, $64, $3E,
    $65, $24, $20, $46, $6E, $74);

procedure Decode(Buffer: TStream; Pos: Integer;
  dLength: cardinal); overload;
var
  tmp: cardinal;
  procByte: Byte;
  i: Integer;
begin
  for i := 0 to dLength - 1 do
  begin
    tmp := Pos + i;
    tmp := (Pos + i) xor (XorTable[tmp mod $17]);
    Buffer.Read(procByte, 1);
    procByte := tmp xor procByte;
    Buffer.Seek(-1, soFromCurrent);
    Buffer.Write(procByte, 1);
  end;
end;

procedure Decode(Buffer: Pbyte; Pos: Integer;
  dLength: cardinal); overload;
var
  tmp: cardinal;
  i: Integer;
begin
{$IFDEF DEBUG}
  CodeSite.Send('Decode Data.');
{$ENDIF}
  for i := 0 to dLength - 1 do
  begin
    tmp := Pos + i;
    tmp := (Pos + i) xor (XorTable[tmp mod $17]);
    Buffer[i] := Byte(tmp) xor Buffer[i];
  end;
{$IFDEF DEBUG}
  CodeSite.Send('Decode Data Finish.');
{$ENDIF}
end;

procedure DecodeIndex(Buffer: Pbyte; Indexs: cardinal);
var
  i: Integer;
  Pos: Integer;
begin
  Pos := 0;
{$IFDEF DEBUG}
  CodeSite.Send('Decode Index');
  CodeSite.Send('Loop count :', Indexs);
{$ENDIF}
  for i := 0 to Indexs - 1 do
  begin
    Decode(@Buffer[Pos], 0, 4);
    Decode(@Buffer[Pos + 4], 4, PDword(@Buffer[Pos])^ - 4);
    Pos := Pos + PDword(@Buffer[Pos])^;
  end;
{$IFDEF DEBUG}
  CodeSite.Send('Decode Index Finish.');
{$ENDIF}
end;

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], sizeof(Pack_Head));
    if (Head.IndexLen < FileBuffer.Size) and
      (Head.DataLen < FileBuffer.Size) and
      (Head.DataOffset < FileBuffer.Size) and
      (Head.Entries_Count < FileBuffer.Size) and
      (Head.DataEncoded in [0 .. 1]) and
      (Head.IndexEncoded in [0 .. 1]) then
    begin
      Result := dsTrue;
    end;
  except
    Result := dsError;
  end;
end;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('Chariot', clGameMaker));
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  Head: Pack_Head;
  Indexs: Pack_Entries;
  i: Integer;
  Rlentry: TRlEntry;
  myBuffer: TMemoryStream;
begin
  Result := True;
{$IFDEF DEBUG}
  CodeSite.AddCheckPoint; // 1
{$ENDIF}
  try
    FileBuffer.Seek(0, soFromBeginning);
    myBuffer := TMemoryStream.Create;
    FileBuffer.Read(Head.Magic[0], sizeof(Pack_Head));
{$IFDEF DEBUG}
    CodeSite.Send('Head.Magic', Head.Magic);
    CodeSite.Send('Head.Version', Head.Version);
    CodeSite.Send('Head.Unknow', Head.Unknow);
    CodeSite.Send('Head.IndexEncoded', Head.IndexEncoded);
    CodeSite.Send('Head.Unknow1', Head.Unknow1);
    CodeSite.Send('Head.DataEncoded', Head.DataEncoded);
    CodeSite.Send('Head.Entries_Count', Head.Entries_Count);
    CodeSite.Send('Head.IndexLen', Head.IndexLen);
    CodeSite.Send('Head.DataLen', Head.DataLen);
    CodeSite.Send('Head.Unknow3', Head.Unknow3);
    CodeSite.Send('Head.DataOffset', Head.DataOffset);
    CodeSite.Send('Head.Unknow4', Head.Unknow4);
{$ENDIF}
    myBuffer.CopyFrom(FileBuffer, Head.IndexLen);
{$IFDEF DEBUG}
    CodeSite.AddCheckPoint; // 2
{$ENDIF}
    if Head.IndexEncoded = 1 then
      DecodeIndex(myBuffer.Memory, Head.Entries_Count);
{$IFDEF DEBUG}
    CodeSite.AddCheckPoint; // 3
    myBuffer.SaveToFile('IndexDump.tmp');
    CodeSite.Send('Loop Count: ', Head.Entries_Count);
{$ENDIF}
    myBuffer.Seek(0, soFromBeginning);
    for i := 0 to Head.Entries_Count - 1 do
    begin
      with myBuffer do
      begin
        Read(Indexs.EntryLen, 4);
        Read(Indexs.Length, 4);
        Read(Indexs.Unknow, 4);
        Read(Indexs.FileNameLen, 4);
        Read(Indexs.Hash, 4);
        Read(Indexs.Hash1, 4);
        Read(Indexs.Start_Offset, 4);
        Read(Indexs.Unknow1, 4);
      end;
      SetLength(Indexs.File_name, (Indexs.EntryLen - $20) div 2);
      myBuffer.Read(Indexs.File_name[0], Indexs.EntryLen - $20);
      Rlentry := TRlEntry.Create;
      Rlentry.AOffset := Indexs.Start_Offset + Head.DataOffset;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := Indexs.Length;
      Rlentry.AKey := Head.DataEncoded;
      SetLength(Rlentry.AName, Indexs.FileNameLen);
      MoveChars(Indexs.File_name[0], Pbyte(Rlentry.AName)^,
        Indexs.FileNameLen);
      IndexStream.Add(Rlentry);
    end;
    myBuffer.Free;
{$IFDEF DEBUG}
    CodeSite.AddCheckPoint; // 4
{$ENDIF}
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
  compr: TGlCompressBuffer;
begin
{$IFDEF DEBUG}
  CodeSite.Send('Process File. Num: ', FileBuffer.EntrySelected);
  CodeSite.Send('AName ', FileBuffer.Rlentry.AName);
{$ENDIF}
  if FileBuffer.Rlentry.AKey = 1 then
  begin
    compr := TGlCompressBuffer.Create;
    try
      Result := FileBuffer.ReadData(OutBuffer);
{$IFDEF DEBUG}
      CodeSite.Send('Read Success ');
{$ENDIF}
      OutBuffer.Seek(0, soFromBeginning);
      compr.CopyFrom(OutBuffer, OutBuffer.Size);
      compr.Seek(0, soFromBeginning);
      Decode(compr, 0, compr.Size);
{$IFDEF DEBUG}
      CodeSite.Send('Decode Success ');
{$ENDIF}
      OutBuffer.Size := 0;
      OutBuffer.Seek(0, soFromBeginning);
      compr.Seek(0, soFromBeginning);
      OutBuffer.CopyFrom(compr, compr.Size);
{$IFDEF DEBUG}
      CodeSite.Send('Copy Success ');
{$ENDIF}
    finally
      compr.Free;
    end;
  end
  else
    Result := FileBuffer.ReadData(OutBuffer);
{$IFDEF DEBUG}
  CodeSite.Send('Process File Finish.');
{$ENDIF}
end;

function PackData(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream; var Percent: Word): Boolean;
var
  i: Integer;
  Head: Pack_Head;
  Indexs: array of Pack_Entries;
  tmpbuffer: TFileStream;
begin
  Result := True;
  try
  except
    Result := False;
  end;
end;

exports AutoDetect;

exports GetPluginName;

exports GenerateEntries;

exports Decyption;

exports ReadData;

{$IFDEF SP}

exports PackData;
{$ENDIF}

begin

end.
