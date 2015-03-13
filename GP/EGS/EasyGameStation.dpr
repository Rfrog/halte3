library EasyGameStation;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  Windows,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas',
  StrUtils,Vcl.Dialogs, CodeSiteLogging;

{$E GP}
{$R *.res}
{$DEFINE COMPR}

Type
  Pack_Head = Packed Record
    indexs: Cardinal;
  End;

  Pack_Entries = packed Record
    filename: array [1 .. $80] of AnsiChar;
    DecompressLen: Cardinal;
    start_offset: Cardinal;
    length: Cardinal;
  End;

const
  flen = 10 * 1024 * 1024;
  sformat = '\data%.3d.bin';

function EndianSwap(const a: integer): integer;
asm
  bswap eax
end;

Procedure Lz77Compress(Input, output: TStream);
var
  C: Byte;
begin
  C := 00;
  Input.Position := 0;
  output.Position := 0;
  while Input.Position + 8 <= Input.Size do
  begin
    output.Write(C, 1);
    output.CopyFrom(Input, 8);
  end;
  if Input.Size - Input.Position > 0 then
  begin
    C := $80 shr (Input.Size - Input.Position);
    output.Write(C, 1);
    output.CopyFrom(Input, Input.Size - Input.Position);
  end
  else
  begin
    C := $80;
    output.Write(C, 1);
  end;
  C := $01;
  output.Write(C, 1);
  C := $00;
  output.Write(C, 1);
end;

procedure Lz77Decompress2(Input, output: TStream);
var
  Runflag: Boolean;
  CurDW, TmpDW, TmpCurDw: Cardinal;
  CurByte: PByte;
  SeekPosition, NowPosition: Cardinal;
label Start, Start2, Aend;
begin
  Runflag := True;
  CurByte := @Byte(CurDW);
Start:
  while Runflag do
  begin
    CurDW := 0;
    Input.Read(CurByte^, 1);
    if CurDW = 0 then
    begin
      output.CopyFrom(Input, 8);
      goto Start;
    end;
    CurDW := (CurDW shl $18) or $800000;
    TmpDW := CurDW;
  Start2:
    while True do
    begin
      if TmpDW < $80000000 then
      begin
        while (TmpDW < $80000000) do
        begin
          output.CopyFrom(Input, 1);
          TmpDW := TmpDW shl $1;
        end;
      end;
      TmpDW := TmpDW shl $1;
      if TmpDW = 0 then
        goto Start;
      CurDW := 0;
      Input.Read(CurByte^, 1);
      TmpCurDw := CurDW;
      NowPosition := output.Position;
      CurDW := ((CurDW and $0F0) shl $4);
      SeekPosition := NowPosition - CurDW;
      CurDW := 0;
      Input.Read(CurByte^, 1);
      SeekPosition := SeekPosition - CurDW;
      if SeekPosition <> NowPosition then
      begin
        TmpCurDw := TmpCurDw and $0F;
        if TmpCurDw = 0 then
        begin
          CurDW := 0;
          Input.Read(CurByte^, 1);
          TmpCurDw := CurDW + NowPosition + $11; // output pos?
        end
        else if TmpCurDw = 1 then
        begin
          output.Seek(SeekPosition, soFromBeginning);
          output.Read(CurByte^, 1);
          output.Seek(NowPosition, soFromBeginning);
          output.Write(CurByte^, 1);
          output.Seek(SeekPosition + 1, soFromBeginning);
          output.Read(CurByte^, 1);
          output.Seek(NowPosition + 1, soFromBeginning);
          output.Write(CurByte^, 1);
          Continue;
        end
        else
          TmpCurDw := TmpCurDw + NowPosition + $1;
        output.Seek(SeekPosition, soFromBeginning);
        output.Read(CurByte^, 1);
        output.Seek(NowPosition, soFromBeginning);
        output.Write(CurByte^, 1);
        NowPosition := NowPosition + 1;
        SeekPosition := SeekPosition + 1;
        repeat
          output.Seek(SeekPosition, soFromBeginning);
          output.Read(CurByte^, 1);
          output.Seek(NowPosition, soFromBeginning);
          output.Write(CurByte^, 1);
          NowPosition := NowPosition + 1;
          SeekPosition := SeekPosition + 1;
        until NowPosition = TmpCurDw;
      end
      else
        goto Aend;
    end;
  Aend:
    Runflag := False;
  end;
end;

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  head: Pack_Head;
begin
  Result := dsFalse;
  try
    if SameText(ExtractFileName(FileBuffer.filename),
      'lnkdatas.bin') then
    begin
      FileBuffer.Read(head.indexs, SizeOf(Pack_Head));
      if EndianSwap(head.indexs) < FileBuffer.Size then
      begin
        Result := dsTrue;
        Exit;
      end;
    end;
    if CompareExt(FileBuffer.filename, '.bin') and
      SameText(LeftStr(ExtractFileName(FileBuffer.filename), 4),
      'data') then
    begin
      Result := dsUnknown;
      Exit;
    end;
  except
    Result := dsError;
  end;
end;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('Easy Game Station',
    clGameMaker));
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  head: Pack_Head;
  indexs: Pack_Entries;
  i, j: integer;
  Rlentry: TRlEntry;
begin
  Result := True;
  try
    if not SameText(ExtractFileName(FileBuffer.filename),
      'lnkdatas.bin') then
      raise Exception.Create('FileName Error.');
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(head.indexs, SizeOf(Pack_Head));
    head.indexs := EndianSwap(head.indexs);
    for i := 0 to head.indexs - 1 do
    begin
      FileBuffer.Read(indexs.filename[1], SizeOf(Pack_Entries));
      Rlentry := TRlEntry.Create;
      for j := 1 to $80 do
      begin
        if indexs.filename[j] = '/' then
          indexs.filename[j] := '\';
      end;
      Rlentry.AName := Trim(indexs.filename);
      Rlentry.AOffset := EndianSwap(indexs.start_offset)
        mod flen;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := EndianSwap(indexs.length);
      Rlentry.ARLength := EndianSwap(indexs.DecompressLen);
      Rlentry.AKey := EndianSwap(indexs.start_offset)
        div (flen - 1);
      IndexStream.ADD(Rlentry);
    end;
  except
    Result := False;
  end;
end;

procedure Decyption();
begin
  { do nothing }
end;

// ‰äèÏ‘S•¶Œ™ûŠó,‘¾—º—¹ $420fef /$4210f6
function IndexHash(Buffer: TStream): Cardinal;
var
  tmp: Cardinal;
  btmp: Byte;
  i: integer;
begin
  Result := $FFFF;
  while Buffer.Position < Buffer.Size do
  begin
    Buffer.Read(btmp, 1);
    tmp := Cardinal(btmp) shl $8;
    Result := Result xor tmp;
    for i := 0 to 7 do
    begin
      if Byte(Result shr $8) = 0 then
        Result := Result shl 1
      else
        Result := Result * 2 - $1021;
    end;
  end;
  Result := not Result;
end;

function ReadData(FileBuffer: TFileBufferStream;
  OutBuffer: TStream): LongInt;
var
  Buffer: TGlCompressBuffer;
  DecompressLen: Cardinal;
  myBuffer: TFileStream;
  i, j: int64;
begin
{$IFDEF DEBUG}
  CodeSite.Send(Format(ExtractFilePath(FileBuffer.filename) +
    sformat, [FileBuffer.Rlentry.AKey]));
  CodeSite.Send(FileBuffer.Rlentry.AName);
{$ENDIF}
  Buffer := TGlCompressBuffer.Create;

  begin
{$IFDEF DEBUG}
    CodeSite.Send('start.');
{$ENDIF}
    myBuffer := TFileStream.Create
      (Format(ExtractFilePath(FileBuffer.filename) + sformat,
      [FileBuffer.Rlentry.AKey]), fmOpenRead);
    try
      DecompressLen := FileBuffer.Rlentry.ARLength;
      myBuffer.Seek(FileBuffer.Rlentry.AOffset,
        FileBuffer.Rlentry.AOrigin);
      j := FileBuffer.Rlentry.AStoreLength;
      i := 0;
      while j > 0 do
      begin
        if myBuffer.Position >= myBuffer.Size then
        begin
          myBuffer.Free;
          i := i + 1;
          myBuffer := TFileStream.Create
            (Format(ExtractFilePath(FileBuffer.filename) +
            sformat, [FileBuffer.Rlentry.AKey + i]), fmOpenRead);
          myBuffer.Seek(0, soFromBeginning);
        end;
        if j > (myBuffer.Size - myBuffer.Position) then
          Result := Buffer.CopyFrom(myBuffer,
            myBuffer.Size - myBuffer.Position)
        else
          Result := Buffer.CopyFrom(myBuffer, j);
        j := j - Result;
      end;
{$IFDEF DEBUG}
      CodeSite.Send('read finish.');
{$ENDIF}
      Buffer.Seek(0, soFromBeginning);
      Buffer.output.Seek(0, soFromBeginning);
{$IFDEF COMPR}
      Lz77Decompress2(Buffer, Buffer.output);
      if Buffer.output.Size <> DecompressLen then
        raise Exception.Create('Decompress Error.');
{$ELSE}
      Buffer.output.CopyFrom(Buffer, Buffer.Size);
{$ENDIF}
{$IFDEF DEBUG}
      CodeSite.Send('decompress finish.');
{$ENDIF}
      Buffer.output.Seek(0, soFromBeginning);
      OutBuffer.CopyFrom(Buffer.output, Buffer.output.Size);
    finally
      Buffer.Free;
      myBuffer.Free;
    end;
  end;
  FileBuffer.EntrySelected := FileBuffer.EntrySelected + 1;
end;

function PackData(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream; var Percent: Word): Boolean;
var
  indexs: array of Pack_Entries;
  head: Pack_Head;
  i, j, k: integer;
  tmpbuffer, OutBuffer: TMemoryStream;
  SaveBuffer: TMemoryStream;
begin
  Result := True;
  try
    j := 0;
{$IFDEF DEBUG}
    CodeSite.Send('Pack Start.');
{$ENDIF}
    SetLength(indexs, IndexStream.Count);
    ZeroMemory(@indexs[0].filename[1], IndexStream.Count *
      SizeOf(Pack_Entries));
    tmpbuffer := TMemoryStream.Create;
    OutBuffer := TMemoryStream.Create;
    SaveBuffer := TMemoryStream.Create;
    for i := 0 to IndexStream.Count - 1 do
    begin
      tmpbuffer.Clear;
      OutBuffer.Clear;
      tmpbuffer.Seek(0, soFromBeginning);
      OutBuffer.Seek(0, soFromBeginning);
      if length(IndexStream.Rlentry[i].AName) > $80 then
        raise Exception.Create('Name too long.');
      tmpbuffer.LoadFromFile(IndexStream.ParentPath +
        IndexStream.Rlentry[i].AName);
      Move(PByte(AnsiString(IndexStream.Rlentry[i].AName))^,
        indexs[i].filename[1],
        length(IndexStream.Rlentry[i].AName));
{$IFDEF DEBUG}
      CodeSite.Send(IndexStream.Rlentry[i].AName);
{$ENDIF}
      for k := 1 to $80 do
      begin
        if indexs[i].filename[k] = '\' then
          indexs[i].filename[k] := '/';
      end;
      tmpbuffer.Seek(0, soFromBeginning);
      OutBuffer.Seek(0, soFromBeginning);
      Lz77Compress(tmpbuffer, OutBuffer);
      indexs[i].DecompressLen := EndianSwap(tmpbuffer.Size);
      indexs[i].length := EndianSwap(OutBuffer.Size);
      tmpbuffer.Seek(0, soFromBeginning);
      OutBuffer.Seek(0, soFromBeginning);
      if (SaveBuffer.Position + OutBuffer.Size) >= flen then
      begin
{$IFDEF DEBUG}
        CodeSite.Send('Reach file end.');
        CodeSite.Send('file end', SaveBuffer.Position +
          OutBuffer.Size);
        CodeSite.Send('file count', j);
{$ENDIF}
        SaveBuffer.Seek(0, soFromBeginning);
        SaveBuffer.SaveToFile
          (Format(ExtractFilePath(FileBuffer.filename) +
          sformat, [j]));
        SaveBuffer.Clear;
        SaveBuffer.Seek(0, soFromBeginning);
        j := j + 1;
        indexs[i].start_offset :=
          EndianSwap(SaveBuffer.Position + flen * j);
        while (OutBuffer.Size - OutBuffer.Position) >= flen do
        begin
          SaveBuffer.CopyFrom(OutBuffer, flen);
          SaveBuffer.Seek(0, soFromBeginning);
          SaveBuffer.SaveToFile
            (Format(ExtractFilePath(FileBuffer.filename) +
            sformat, [j]));
          SaveBuffer.Clear;
          SaveBuffer.Seek(0, soFromBeginning);
          j := j + 1;
        end;
        SaveBuffer.CopyFrom(OutBuffer, OutBuffer.Size -
          OutBuffer.Position);
      end
      else
      begin
{$IFDEF DEBUG}
        CodeSite.Send('Normal Packed');
{$ENDIF}
        SaveBuffer.CopyFrom(OutBuffer, OutBuffer.Size);
      end;
      Percent := 95 * (i + 1) div IndexStream.Count;
    end;
    SaveBuffer.Seek(0, soFromBeginning);
    SaveBuffer.SaveToFile
      (Format(ExtractFilePath(FileBuffer.filename) +
      sformat, [j]));
    tmpbuffer.Free;
    OutBuffer.Free;
    SaveBuffer.Free;
    head.indexs := EndianSwap(IndexStream.Count);
    FileBuffer.Write(head.indexs, 4);
    FileBuffer.Write(indexs[0].filename[1], IndexStream.Count *
      SizeOf(Pack_Entries));
  except
    Result := False;
  end;
end;

function PackProcessData(Rlentry: TRlEntry;
  InputBuffer, FileOutBuffer: TStream): Boolean;
var
  Compr: TMemoryStream;
begin
  Compr := TMemoryStream.Create;
  Lz77Compress(InputBuffer, Compr);
  Compr.Seek(0, soFromBeginning);
  with Rlentry do
  begin
    Rlentry.ARLength := InputBuffer.Size;
    Rlentry.AStoreLength := Compr.Size;
    Rlentry.AOffset := FileOutBuffer.Position;
  end;
  FileOutBuffer.CopyFrom(Compr, Compr.Size);
  Compr.Free;
end;

function PackProcessIndex(IndexStream: TIndexStream;
  IndexOutBuffer: TStream): Boolean;
var
  indexs: array of Pack_Entries;
  i, k: integer;
begin
  SetLength(indexs, IndexStream.Count);
  ZeroMemory(@indexs[0].filename[1], IndexStream.Count *
    SizeOf(Pack_Entries));
  for i := 0 to IndexStream.Count - 1 do
  begin
    if length(IndexStream.Rlentry[i].AName) > 128 then
      raise Exception.Create('Filename too long.');
    Move(PByte(AnsiString(IndexStream.Rlentry[i].AName))^,
      indexs[i].filename[1],
      length(IndexStream.Rlentry[i].AName));
    for k := 1 to $80 do
    begin
      if indexs[i].filename[k] = '\' then
        indexs[i].filename[k] := '/';
    end;
    indexs[i].DecompressLen :=
      EndianSwap(IndexStream.Rlentry[i].ARLength);
    indexs[i].start_offset :=
      EndianSwap(IndexStream.Rlentry[i].AOffset);
    indexs[i].length :=
      EndianSwap(IndexStream.Rlentry[i].AStoreLength);
  end;
  IndexOutBuffer.Write(indexs[0].filename[1], IndexStream.Count *
    SizeOf(Pack_Entries));
end;

function MakePackage(IndexStream: TIndexStream;
  IndexOutBuffer, FileOutBuffer: TStream;
  Package: TFileBufferStream): Boolean;
var
  head: Pack_Head;
  i: integer;
begin
  head.indexs := EndianSwap(IndexStream.Count);
  Package.Write(head.indexs, 4);
  IndexOutBuffer.Seek(0, soFromBeginning);
  Package.CopyFrom(IndexOutBuffer, IndexOutBuffer.Size);
  FileOutBuffer.Seek(0, soFromBeginning);
  i := 0;
  while FileOutBuffer.Position < FileOutBuffer.Size do
  begin
    DivStream(FileOutBuffer, flen,
      Format(ExtractFilePath(Package.filename) + sformat, [i]));
    i := i + 1;
  end;
end;

exports AutoDetect;

exports GetPluginName;

exports GenerateEntries;

exports Decyption;

exports ReadData;

exports PackData;

exports PackProcessData;

exports PackProcessIndex;

exports MakePackage;

begin

end.
