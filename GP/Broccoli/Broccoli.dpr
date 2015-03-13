library Broccoli;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  StrUtils,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas',
  Vcl.Dialogs;

{$E gp}
{$R *.res}

Type
  Pack_Head = Packed Record
    decompress_length: Cardinal;
    entries_length: Cardinal; // if this=0 -> uncompressed
    Hash: Cardinal; // after compress,if hash=0 -> unencoded
  End;

  Pack_Entries = packed Record
    Name_Length: Cardinal;
    Hash: Cardinal;
    start_offset: Cardinal;
    filename: AnsiString;
  End;

procedure Decode1(Data: TStream; Key: Cardinal);
var
  tmpKey: Byte;
  tmpKey2: Cardinal;
  buffer: Byte;
begin
  tmpKey := Byte(Key) + Byte(Key shr 8);
  tmpKey2 := Key shr $10;
  tmpKey := tmpKey + Byte(tmpKey2) + Byte(tmpKey2 shr 8);
  if tmpKey = 0 then
    tmpKey := $AA;
  while Data.Position < Data.Size do
  begin
    Data.Read(buffer, 1);
    buffer := buffer xor tmpKey;
    Data.Seek(-1, soFromCurrent);
    Data.Write(buffer, 1);
  end;
end;

function Hash(Data: TStream): Cardinal;
var
  tmpKey, tmpKey2, tmpkey3, tmpkey4: Cardinal;
  buffer: Byte;
begin
  Result := $23456789;
  Data.Seek(0, soFromBeginning);
  while Data.Position < Data.Size do
  begin
    Data.Read(buffer, 1);
    tmpKey := Result + Integer(buffer);
    tmpKey2 := ((tmpKey + Data.Position - 1) and $1F);
    tmpkey3 := tmpKey shr Byte($20 - tmpKey2);
    tmpkey4 := tmpKey shl Byte(tmpKey2);
    Result := Result + (tmpkey3 or tmpkey4);
  end;
end;

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.decompress_length, sizeof(Pack_Head));
    if ((Head.decompress_length xor $1F84C9AF) < FileBuffer.Size) and
      ((Head.entries_length XOR $9ED835AB) < FileBuffer.Size) then
    begin
      Result := dsTrue;
    end;
  except
    Result := dsError;
  end;
end;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('Broccoli', clGameMaker));
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  Head: Pack_Head;
  indexs: Pack_Entries;
  Compress: TGlCompressBuffer;
  NameBuf: TMemoryStream;
  tmpLength: Cardinal;
  i: Integer;
  Rlentry: TRlEntry;
begin
  Result := True;
  try
    Compress := TGlCompressBuffer.Create;
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.decompress_length, sizeof(Pack_Head));
    Head.decompress_length :=
      Head.decompress_length xor $1F84C9AF;
    Head.entries_length := Head.entries_length XOR $9ED835AB;
    Compress.Seek(0, soFromBeginning);
    Compress.CopyFrom(FileBuffer, Head.entries_length);
    if Head.Hash <> 0 then
    begin
      Compress.Seek(0, soFromBeginning);
      Decode1(Compress, Head.Hash);
      Compress.Seek(0, soFromBeginning);
      if Hash(Compress) <> Head.Hash then
        raise Exception.Create('Hash Check Error.' + #13#10 + '$'
          + inttohex(Hash(Compress), 8) + ' VS $' +
          inttohex(Head.Hash, 8));
    end;
    if Head.entries_length <> 0 then
    begin
      Compress.Seek(0, soFromBeginning);
      Compress.LzssDecompress(Compress.Size, $FEE, $FFF);
      if Compress.Output.Size <> Head.decompress_length then
        raise Exception.Create('Decompress Error.' + #13#10 + '$'
          + inttohex(Compress.Output.Size, 8) + ' VS $' +
          inttohex(Head.decompress_length, 8));
    end
    else
    begin
      Compress.Output.CopyFrom(Compress, Compress.Size);
    end;
    Compress.Output.Seek(0, soFromBeginning);
    i := 0;
    tmpLength := Head.entries_length + sizeof(Pack_Head);
    NameBuf := TMemoryStream.Create;
    while i < Head.decompress_length - 2 do
    begin
      NameBuf.Clear;
      Compress.Output.Read(indexs.Name_Length, $C);
      SetLength(indexs.filename, indexs.Name_Length + 1);
      Compress.Output.Read(Pbyte(indexs.filename)^,
        indexs.Name_Length + 1);
      NameBuf.Seek(0, soFromBeginning);
      NameBuf.Write(Pbyte(indexs.filename)^, indexs.Name_Length);
      NameBuf.Seek(0, soFromBeginning);
      if Hash(NameBuf) <> indexs.Hash then
        raise Exception.Create('Name Hash Error.');
      Rlentry := TRlEntry.Create;
      Rlentry.AName := Trim(indexs.filename);
      Rlentry.AOffset := indexs.start_offset + tmpLength;
      Rlentry.AHash[0] := indexs.Hash;
      IndexStream.Add(Rlentry);
      i := i + indexs.Name_Length + $C + 1;
    end;
    NameBuf.Free;
    Compress.Destroy;
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
  Head: Pack_Head;
begin
  Compress := TGlCompressBuffer.Create;
  OutBuffer.Seek(0, soFromBeginning);
  FileBuffer.Seek(FileBuffer.Rlentry.AOffset, soFromBeginning);
  FileBuffer.Read(Head.decompress_length, sizeof(Pack_Head));
  Head.decompress_length := Head.decompress_length xor $1F84C9AF;
  Head.entries_length := Head.entries_length XOR $9ED835AB;
  if Head.entries_length <> 0 then
  begin
    Compress.CopyFrom(FileBuffer, Head.entries_length);
    Compress.Seek(0, soFromBeginning);
    if Head.Hash <> 0 then
    begin
      Decode1(Compress, Head.Hash);
      Compress.Seek(0, soFromBeginning);
      if Hash(Compress) <> Head.Hash then
        raise Exception.Create('Hash Check Error.' + #13#10 + '$'
          + inttohex(Hash(Compress), 8) + ' VS $' +
          inttohex(Head.Hash, 8));
    end;
    Compress.Seek(0, soFromBeginning);
    Compress.LzssDecompress(Compress.Size, $FEE, $FFF);
    if Compress.Output.Size <> Head.decompress_length then
      raise Exception.Create('Decompress Error.' + #13#10 + '$' +
        inttohex(Compress.Output.Size, 8) + ' VS $' +
        inttohex(Head.decompress_length, 8));
    Compress.Output.Seek(0, soFromBeginning);
    OutBuffer.CopyFrom(Compress.Output, Compress.Output.Size);
  end
  else
  begin
    if Head.Hash <> 0 then
    begin
      Compress.CopyFrom(FileBuffer, Head.decompress_length);
      Compress.Seek(0, soFromBeginning);
      Decode1(Compress, Head.Hash);
      Compress.Seek(0, soFromBeginning);
      if Hash(Compress) <> Head.Hash then
        raise Exception.Create('Hash Check Error.' + #13#10 + '$'
          + inttohex(Hash(Compress), 8) + ' VS $' +
          inttohex(Head.Hash, 8));
      OutBuffer.CopyFrom(Compress, Compress.Size);
    end
    else
    begin
      OutBuffer.CopyFrom(FileBuffer, Head.decompress_length);
    end;
  end;
  Compress.Free;
  Result := OutBuffer.Size;
  FileBuffer.EntrySelected := FileBuffer.EntrySelected + 1;
end;

function PackData(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream; var Percent: Word): Boolean;
var
  Head: Pack_Head;
  indexs: array of Pack_Entries;
  i: Integer;
  tmpFile: string;
  tmpstream, filestream: TFileStream;
  NameBuf: TMemoryStream;
  zero: Byte;
  compr: TGlCompressBuffer;
begin
  Result := True;
  try
    zero := 0;
    Percent := 0;
    SetLength(indexs, IndexStream.Count);
    tmpFile := FileBuffer.filename + inttohex(Random($FFFFFFFF),
      8) + 'dump';
    tmpstream := TFileStream.Create(tmpFile, fmCreate);
    NameBuf := TMemoryStream.Create;
    compr := TGlCompressBuffer.Create;
    if InputBox('Choose Mode', 'Need Compress?' + #13#10 +
      '0-no;1-yes', '0') = '0' then
    begin
      for i := 0 to IndexStream.Count - 1 do
      begin
        filestream := TFileStream.Create(IndexStream.ParentPath +
          IndexStream.Rlentry[i].AName, fmOpenRead);
        indexs[i].start_offset := tmpstream.Position;
        indexs[i].Name_Length :=
          Length(IndexStream.Rlentry[i].AName);
        SetLength(indexs[i].filename, indexs[i].Name_Length);
        Move(Pbyte(AnsiString(IndexStream.Rlentry[i].AName))^,
          Pbyte(indexs[i].filename)^, indexs[i].Name_Length);
        NameBuf.Clear;
        NameBuf.Seek(0, soFromBeginning);
        NameBuf.Write(Pbyte(indexs[i].filename)^,
          indexs[i].Name_Length);
        NameBuf.Seek(0, soFromBeginning);
        indexs[i].Hash := Hash(NameBuf);
        Head.decompress_length := filestream.Size;
        Head.entries_length := 0;
        Head.Hash := 0;
        Head.decompress_length :=
          Head.decompress_length xor $1F84C9AF;
        Head.entries_length := Head.entries_length XOR $9ED835AB;
        tmpstream.Write(Head.decompress_length,
          sizeof(Pack_Head));
        tmpstream.CopyFrom(filestream, filestream.Size);
        filestream.Free;
        Percent := Trunc(60 * (i / IndexStream.Count));
      end;
    end
    else
    begin
      for i := 0 to IndexStream.Count - 1 do
      begin
        indexs[i].start_offset := tmpstream.Position;
        indexs[i].Name_Length :=
          Length(IndexStream.Rlentry[i].AName);
        SetLength(indexs[i].filename, indexs[i].Name_Length);
        Move(Pbyte(AnsiString(IndexStream.Rlentry[i].AName))^,
          Pbyte(indexs[i].filename)^, indexs[i].Name_Length);
        NameBuf.Clear;
        NameBuf.Seek(0, soFromBeginning);
        NameBuf.Write(Pbyte(indexs[i].filename)^,
          indexs[i].Name_Length);
        NameBuf.Seek(0, soFromBeginning);
        indexs[i].Hash := Hash(NameBuf);
        compr.Clear;
        compr.Seek(0, soFromBeginning);
        compr.Output.Seek(0, soFromBeginning);
        compr.LoadFromFile(IndexStream.ParentPath +
          IndexStream.Rlentry[i].AName);
        compr.Seek(0, soFromBeginning);
        compr.LzssCompress;
        Head.decompress_length := compr.Size;
        Head.entries_length := compr.Output.Size;
        compr.Output.Seek(0, soFromBeginning);
        Head.Hash := Hash(compr.Output);
        compr.Output.Seek(0, soFromBeginning);
        Decode1(compr.Output, Head.Hash);
        compr.Output.Seek(0, soFromBeginning);
        Head.decompress_length :=
          Head.decompress_length xor $1F84C9AF;
        Head.entries_length := Head.entries_length XOR $9ED835AB;
        tmpstream.Write(Head.decompress_length,
          sizeof(Pack_Head));
        tmpstream.CopyFrom(compr.Output, compr.Output.Size);
        Percent := 60 + Trunc(20 * (i / IndexStream.Count));
      end;
    end;
    NameBuf.Free;
    compr.Clear;
    compr.Seek(0, soFromBeginning);
    compr.Output.Seek(0, soFromBeginning);
    for i := 0 to IndexStream.Count - 1 do
    begin
      compr.Write(indexs[i].Name_Length, 4);
      compr.Write(indexs[i].Hash, 4);
      compr.Write(indexs[i].start_offset, 4);
      compr.Write(Pbyte(indexs[i].filename)^,
        indexs[i].Name_Length);
      compr.Write(zero, 1);
      Percent := 80 + Trunc(10 * (i / IndexStream.Count));
    end;
    compr.Seek(0, soFromBeginning);
    compr.LzssCompress;
    Head.decompress_length := compr.Size;
    Head.entries_length := compr.Output.Size;
    compr.Output.Seek(0, soFromBeginning);
    Head.Hash := Hash(compr.Output);
    compr.Output.Seek(0, soFromBeginning);
    Decode1(compr.Output, Head.Hash);
    compr.Output.Seek(0, soFromBeginning);
    Head.decompress_length :=
      Head.decompress_length xor $1F84C9AF;
    Head.entries_length := Head.entries_length XOR $9ED835AB;
    FileBuffer.Write(Head.decompress_length, sizeof(Pack_Head));
    FileBuffer.CopyFrom(compr.Output, compr.Output.Size);
    tmpstream.Seek(0, soFromBeginning);
    FileBuffer.CopyFrom(tmpstream, tmpstream.Size);
    tmpstream.Free;
    DeleteFile(tmpFile);
    compr.Free;
    Percent := 100;
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
