library ESCARC;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  StrUtils,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas',
  Windows;

{$E gp}
{$R *.res}


Type
  Pack_Head = Packed Record
    Magic: ARRAY [ 0 .. 7 ] OF ANSICHAR;
    KEY: Cardinal;
    entries_count: Cardinal;
    name_table_length: Cardinal;
  End;

  Pack_Entries = packed Record
    filename: array [ 1 .. 127 ] of ANSICHAR;
    start_offset: Cardinal;
    length: Cardinal;
  End;

  Pack_Entries2 = packed Record
    filename_offset: Cardinal;
    start_offset: Cardinal;
    length: Cardinal;
  End;

  Res_Head = packed record
    Magic: array [ 0 .. 3 ] of ANSICHAR;
    decompress_length: Cardinal;
  end;

procedure UpdateKey(var KEY: Cardinal);
begin
  KEY := KEY xor $65AC9365;
  KEY := (((KEY shr 1) xor KEY) shr 3)
    xor (((KEY shl 1) xor KEY) shl 3) xor KEY;
end;

procedure SWAP16(var v: Cardinal);
begin
  v := ((((v) and $FF) shl 8) or (((v) shr 8) and $FF));
end;

procedure SWAP32(var v: Cardinal);
begin
  v := ((((v) and $FF) shl 24) or (((v) and $FF00) shl 8) or
    (((v) and $FF0000) shr 8) or (((v) and $FF000000) shr 24));
end;

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[ 0 ], sizeof(Pack_Head));
    UpdateKey(Head.KEY);
    Head.entries_count := Head.entries_count xor Head.KEY;
    UpdateKey(Head.KEY);
    Head.name_table_length :=
      Head.name_table_length xor Head.KEY;
    if SameText(Trim(Head.Magic), 'ESC-ARC2') and
      (Head.entries_count < FileBuffer.Size) and
      (Head.name_table_length < FileBuffer.Size) then
    begin
      Result := dsTrue;
    end;
  except
    Result := dsError;
  end;
end;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('ESCARC', clEngine));
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  Head   : Pack_Head;
  indexs : array of Pack_Entries2;
  i      : Integer;
  Rlentry: TRlEntry;
  RlName : PAnsiChar;
  Buffer : TMemoryStream;
begin
  Result := True;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[ 0 ], sizeof(Pack_Head));
    if not SameText('ESC-ARC2', Trim(Head.Magic)) then
      raise Exception.Create('Magic Error.');
    UpdateKey(Head.KEY);
    Head.entries_count := Head.entries_count xor Head.KEY;
    UpdateKey(Head.KEY);
    Head.name_table_length :=
      Head.name_table_length xor Head.KEY;
    SetLength(indexs, Head.entries_count);
    FileBuffer.Read(indexs[ 0 ].filename_offset,
      sizeof(Pack_Entries2) * Head.entries_count);
    Buffer := TMemoryStream.Create;
    Buffer.CopyFrom(FileBuffer, Head.name_table_length);
    for i := 0 to Head.entries_count - 1 do
    begin
      UpdateKey(Head.KEY);
      indexs[ i ].filename_offset :=
        indexs[ i ].filename_offset xor Head.KEY;
      UpdateKey(Head.KEY);
      indexs[ i ].start_offset :=
        indexs[ i ].start_offset xor Head.KEY;
      UpdateKey(Head.KEY);
      indexs[ i ].length := indexs[ i ].length xor Head.KEY;
      RlName := @Pbyte(Buffer.Memory)[ indexs[ i ].filename_offset ];
      Rlentry              := TRlEntry.Create;
      Rlentry.AName        := Trim(RlName);
      Rlentry.AOffset      := indexs[ i ].start_offset;
      Rlentry.AOrigin      := soFromBeginning;
      Rlentry.AStoreLength := indexs[ i ].length;
      Rlentry.ARLength     := 0;
      IndexStream.Add(Rlentry);
    end;
    Buffer.Destroy;
    SetLength(indexs, 0);
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
  Head  : Res_Head;
  Tmpbuf: TMemoryStream;
  Decode: TGlCompressBuffer;
begin
  OutBuffer.Seek(0, soFromBeginning);
  Tmpbuf := TMemoryStream.Create;
  Result := FileBuffer.ReadData(Tmpbuf);
  Tmpbuf.Seek(0, soFromBeginning);
  Tmpbuf.Read(Head.Magic[ 0 ], sizeof(Res_Head));
  if SameText(Trim(Head.Magic), 'acp') then
  begin
    SWAP32(Head.decompress_length);
    Decode := TGlCompressBuffer.Create;
    Decode.CopyFrom(Tmpbuf, Tmpbuf.Size - sizeof(Res_Head));
    Decode.Seek(0, soFromBeginning);
    Decode.LZWDecompress(Head.decompress_length);
    if Decode.Output.Size <> Head.decompress_length then
      raise Exception.Create('Decompress Error.');
    Tmpbuf.Clear;
    Decode.Output.Seek(0, soFromBeginning);
    Tmpbuf.CopyFrom(Decode.Output, Decode.Output.Size);
    Decode.Free;
  end;
  Tmpbuf.Seek(0, soFromBeginning);
  OutBuffer.Size := 0;
  OutBuffer.Seek(0, soFromBeginning);
  OutBuffer.CopyFrom(Tmpbuf, Tmpbuf.Size);
  Tmpbuf.Free;
end;

function PackData(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream; var Percent: Word): Boolean;
var
  i        : Integer;
  Head     : Pack_Head;
  indexs   : array of Pack_Entries2;
  tmpbuffer: TFileStream;
  NameTable: TMemoryStream;
  tmpKey   : Cardinal;
  zero     : Byte;
  tmpsize  : Cardinal;
begin
  Result := True;
  try
    Percent := 0;
    FileBuffer.Seek(0, soFromBeginning);
    NameTable          := TMemoryStream.Create;
    Head.Magic         := 'ESC-ARC2';
    Head.entries_count := IndexStream.Count;
    Head.KEY           := Random($FFFFFFFF);
    tmpKey             := Head.KEY;
    SetLength(indexs, IndexStream.Count);
    ZeroMemory(@indexs[ 0 ].filename_offset, sizeof(Pack_Entries2)
      * IndexStream.Count);
    zero  := 0;
    for i := 0 to IndexStream.Count - 1 do
    begin
      indexs[ i ].length          := IndexStream.Rlentry[ i ].ARLength;
      indexs[ i ].filename_offset := NameTable.Position;
      NameTable.
        Write(Pbyte(AnsiString(IndexStream.Rlentry[ i ].AName))^,
        length(IndexStream.Rlentry[ i ].AName));
      NameTable.Write(zero, 1);
      Percent := 10 * (i + 1) div IndexStream.Count;
    end;
    Head.name_table_length := NameTable.Size;
    UpdateKey(tmpKey);
    Head.entries_count := Head.entries_count xor tmpKey;
    UpdateKey(tmpKey);
    Head.name_table_length := Head.name_table_length xor tmpKey;
    FileBuffer.Write(Head.Magic[ 0 ], sizeof(Pack_Head));
    tmpsize := NameTable.Size + sizeof(Pack_Head) +
      sizeof(Pack_Entries2) * IndexStream.Count;;
    for i := 0 to IndexStream.Count - 1 do
    begin
      UpdateKey(tmpKey);
      indexs[ i ].filename_offset :=
        indexs[ i ].filename_offset xor tmpKey;
      UpdateKey(tmpKey);
      indexs[ i ].start_offset := tmpsize xor tmpKey;
      tmpsize                  := tmpsize + indexs[ i ].length;
      UpdateKey(tmpKey);
      indexs[ i ].length := indexs[ i ].length xor tmpKey;
    end;
    FileBuffer.Write(indexs[ 0 ].filename_offset,
      sizeof(Pack_Entries2) * IndexStream.Count);
    NameTable.Seek(0, soFromBeginning);
    FileBuffer.CopyFrom(NameTable, NameTable.Size);
    for i := 0 to IndexStream.Count - 1 do
    begin
      tmpbuffer := TFileStream.Create(IndexStream.ParentPath +
        IndexStream.Rlentry[ i ].AName, fmOpenRead);
      NameTable.
        Write(Pbyte(AnsiString(IndexStream.Rlentry[ i ].AName))^,
        length(IndexStream.Rlentry[ i ].AName));
      indexs[ i ].length       := tmpbuffer.Size;
      indexs[ i ].start_offset := FileBuffer.Position;
      tmpbuffer.Seek(0, soFromBeginning);
      FileBuffer.CopyFrom(tmpbuffer, tmpbuffer.Size);
      tmpbuffer.Free;
      Percent := 10 + 90 * (i + 1) div IndexStream.Count;
    end;
    NameTable.Free;
  except
    Result := False;
  end;
end;

exports
  AutoDetect;

exports
  GetPluginName;

exports
  GenerateEntries;

exports
  Decyption;

exports
  ReadData;

exports
  PackData;

begin

end.
