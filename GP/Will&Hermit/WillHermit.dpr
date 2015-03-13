library WillHermit;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  StrUtils,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas',
  Windows {$IFDEF DEBUG},
  CodeSiteLogging {$ENDIF};

{$E gp}
{$R *.res}

Type

  Dir_Head = Packed Record
    Dirs: Cardinal;
  End;

  Dir_Entry = packed record
    Dir: array [0 .. 3] of AnsiChar;
    Indexs: Cardinal;
    Offset: Cardinal;
  end;

  Pack_Entries = packed Record
    File_Name: array [0 .. 8] of AnsiChar;
    Length: Cardinal;
    Start_Offset: Cardinal;
  End;

procedure Decode(Buffer: TStream; Pos: Integer;
  dLength: Cardinal); overload;
var
  tmp: Byte;
  procByte: Byte;
  i: Integer;
begin
{$IFDEF DEBUG}
  CodeSite.Send('Decode Data.');
{$ENDIF}
  tmp := 2;
  for i := 0 to dLength - 1 do
  begin
    Buffer.Read(procByte, 1);
    procByte := (procByte shr tmp) + (procByte shl (8 - tmp));
    Buffer.Seek(-1, soFromCurrent);
    Buffer.Write(procByte, 1);
  end;
{$IFDEF DEBUG}
  CodeSite.Send('Decode Data Finish.');
{$ENDIF}
end;


procedure Encode(Buffer: TStream; Pos: Integer;
  dLength: Cardinal); overload;
var
  tmp: Byte;
  procByte: Byte;
  i: Integer;
begin
{$IFDEF DEBUG}
  CodeSite.Send('Decode Data.');
{$ENDIF}
  tmp := 2;
  for i := 0 to dLength - 1 do
  begin
    Buffer.Read(procByte, 1);
    procByte := (procByte shl tmp) + (procByte shr (8 - tmp));
    Buffer.Seek(-1, soFromCurrent);
    Buffer.Write(procByte, 1);
  end;
{$IFDEF DEBUG}
  CodeSite.Send('Decode Data Finish.');
{$ENDIF}
end;

procedure Decode(Buffer: Pbyte; Pos: Integer;
  dLength: Cardinal); overload;
var
  tmp: Cardinal;
  i: Integer;
begin
{$IFDEF DEBUG}
  CodeSite.Send('Decode Data.');
{$ENDIF}
  for i := 0 to dLength - 1 do
  begin
    Buffer[i] := (Buffer[i] shr tmp) + (Buffer[i] shl (32 - tmp));
  end;
{$IFDEF DEBUG}
  CodeSite.Send('Decode Data Finish.');
{$ENDIF}
end;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('Will/Hermit', clGameMaker));
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  Head: Dir_Head;
  Dirs: array of Dir_Entry;
  Indexs: Pack_Entries;
  i, j: Integer;
  Rlentry: TRlEntry;
begin
  Result := True;
{$IFDEF DEBUG}
  CodeSite.AddCheckPoint; // 1
{$ENDIF}
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Dirs, SizeOf(Dir_Head));
{$IFDEF DEBUG}
    CodeSite.Send('Head.dirs', Head.Dirs);
{$ENDIF}
    SetLength(Dirs, Head.Dirs);
    FileBuffer.Read(Dirs[0].Dir[0], SizeOf(Dir_Entry) *
      Head.Dirs);
{$IFDEF DEBUG}
    CodeSite.AddCheckPoint; // 2
    CodeSite.Send('Loop Count: ', Head.Dirs);
{$ENDIF}
    for i := 0 to Head.Dirs - 1 do
    begin
      FileBuffer.Seek(Dirs[i].Offset, soFromBeginning);
      for j := 0 to Dirs[i].Indexs - 1 do
      begin
        FileBuffer.Read(Indexs.File_Name[0],
          SizeOf(Pack_Entries));
        Rlentry := TRlEntry.Create;
        Rlentry.AOffset := Indexs.Start_Offset;
        Rlentry.AOrigin := soFromBeginning;
        Rlentry.AStoreLength := Indexs.Length;
        Rlentry.AName := Trim(Dirs[i].Dir) + '\' +
          Trim(Indexs.File_Name);
        IndexStream.Add(Rlentry);
      end;
    end;
{$IFDEF DEBUG}
    CodeSite.AddCheckPoint; // 3
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
  if SameText(ExtractFileDir(FileBuffer.Rlentry.AName),
    'SCR') then
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

exports GetPluginName;

exports GenerateEntries;

exports Decyption;

exports ReadData;

begin

end.
