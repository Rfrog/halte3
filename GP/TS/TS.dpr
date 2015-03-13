library TS;

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

Type
  Pack_Head = Packed Record
    DataOffset: Cardinal;
  End;

  Indexs_Head = packed record
    Indexs_Hash: Cardinal;
  end;

  Pack_Entries = Record
    filename: AnsiString;
    length: Cardinal;
    decompress_length: Cardinal;
    start_offset: Cardinal;
    Flag: Byte;
    // this flag points out that if this file's seed is
    // Hash value of data.   1  - no  0  - yes
    // also can be treated as User-define-seed flag
    Seed: Cardinal;
  End;

var
  Table: array [0 .. $272] of Cardinal;
  HashTable: array [0 .. $FF] of Cardinal;
  DecodeTable: array [0 .. 15] of Cardinal;

procedure TableCreate(Seed: Cardinal);
var
  i: Integer;
begin
  Table[1] := Seed;
  For i := 1 to $270 do
  Begin
    Table[i + 1] := (((Table[i] shr $1E) xor Table[i]) *
      $6C078965) + i;
  End;
  Table[$271] := 1;
  // this is a sym show that if this table need refresh;
  // 0 – don’t ; >0 - need
end;

procedure TableRefresh;
var
  i: Integer;
  tmp: Cardinal;
begin
  Table[$271] := $270;
  For i := 1 to $E3 Do
  Begin
    Asm
      Push ecx
      push eax
      mov eax,i
      imul eax,eax,4
      add eax,4
      lea ecx,Table
      add ecx,eax
      mov ecx, DWORD PTR [ecx]
      And cl,1
      Neg cl
      Sbb ecx,ecx
      And ecx,$9908b0df
      Mov tmp,ecx
      pop eax
      Pop ecx
    End;
    Table[i] :=
      (((((Table[i] xor Table[i + 1]) and $7FFFFFFE) xor Table[i]
      ) shr 1) xor tmp) xor Table[i + $18D];
  End;
  For i := $E4 to $18C + $E4 - 1 Do
  Begin
    Asm
      Push ecx
      push eax
      mov eax,i
      imul eax,eax,4
      add eax,4
      lea ecx,Table
      add ecx,eax
      mov ecx, DWORD PTR [ecx]
      And cl,1
      Neg cl
      Sbb ecx,ecx
      And ecx,$9908b0df
      Mov tmp,ecx
      pop eax
      Pop ecx
    End;
    Table[i] :=
      (((((Table[i] xor Table[i + 1]) and $7FFFFFFE) xor Table[i]
      ) shr 1) xor tmp) xor Table[i - $E3];
  End;
  Asm
    Push ecx
    push eax
    mov eax,i
    lea ecx,Table
    add ecx,4
    mov ecx, DWORD PTR [ecx]
    And cl,1
    Neg cl
    Sbb ecx,ecx
    And ecx,$9908b0df
    Mov tmp,ecx
    pop eax
    Pop ecx
  End;
  Table[$18C + $E4] :=
    (((((Table[1] xor Table[$18C + $E4]) and $7FFFFFFE) xor Table
    [$18C + $E4]) shr 1) xor tmp) xor Table[$18C + $E4 - $E3];
end;

procedure Decode(Buffer: Pbyte; DataLength: Cardinal);
var
  i: Integer;
  tmp: Cardinal;
begin
  for i := 0 to DataLength - 1 do
  begin
    Table[$271] := Table[$271] - 1;
    if Table[$271] = 0 then
      TableRefresh;
    tmp := (((((Table[$270 - Table[$271] + 1] shr $0B) xor Table
      [$270 - Table[$271] + 1]) and $FF3A58AD) shl 7)
      xor ((Table[$270 - Table[$271] + 1] shr $0B xor Table[$270
      - Table[$271] + 1])));
    tmp := (tmp and $FFFFDF8C shl $F) xor tmp;
    tmp := tmp shr $12 xor tmp;
    Buffer[i] := Buffer[i] xor Byte(tmp);
  end;
end;

procedure DecodeTableGen;
var
  i: Integer;
  tmp: Cardinal;
begin
  for i := 0 to $10 - 1 do
  begin
    Table[$271] := Table[$271] - 1;
    if Table[$271] = 0 then
      TableRefresh;
    tmp := (((((Table[$270 - Table[$271] + 1] shr $0B) xor Table
      [$270 - Table[$271] + 1]) and $FF3A58AD) shl 7)
      xor ((Table[$270 - Table[$271] + 1] shr $0B xor Table[$270
      - Table[$271] + 1])));
    tmp := (tmp and $FFFFDF8C shl $F) xor tmp;
    tmp := tmp shr $12 xor tmp;
    DecodeTable[i] := tmp;
  end;
end;

procedure Decode2(Buffer: TStream);
var
  i: Integer;
  tmp, j: Cardinal;
begin
  j := 0;
  for i := 0 to Buffer.Size div 4 do
  begin
    Buffer.read(tmp, 4);
    tmp := tmp xor DecodeTable[j];
    Buffer.Seek(-4, soFromCurrent);
    Buffer.Write(tmp, 4);
    j := j + 1;
    j := j and $0F
  end;
end;

procedure Hash1(DataLength: Cardinal);
var
  i, j: Integer;
  tmp: LongInt;
begin
  for j := 0 to $FF do
  begin
    tmp := j shl $18;
    for i := 0 to 7 do
    begin
      if tmp >= 0 then
        tmp := tmp * 2
      else
      begin
        tmp := tmp * 2;
        tmp := tmp xor $4C11DB7;
      end;
    end;
    HashTable[j] := tmp;
  end;
end;

function Hash2(Buffer: Pbyte; DataSize: Cardinal): Cardinal;
var
  i, l: Integer;
begin
  l := $FFFFFFFF;
  for i := 0 to DataSize - 1 do
  begin
    l := (l shl $8) xor HashTable
      [l shr $18 xor Ord(Pbyte(Buffer)[i])];
  end;
  Result := not l;
end;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('東方サッカー　猛蹴伝', clgamename));
end;

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
  Buffer: TMemoryStream;
  IndexHead: Indexs_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.read(Head.DataOffset, sizeof(Pack_Head));
    if (Head.DataOffset < FileBuffer.Size) then
    begin
      Buffer := TMemoryStream.Create;
      try
        if IndexHead.Indexs_Hash <> 0 then
        begin
          Buffer.Seek(0, soFromBeginning);
          Buffer.CopyFrom(FileBuffer, Head.DataOffset -
            sizeof(Pack_Head));
          TableCreate(Head.DataOffset);
          Decode(Buffer.Memory, Buffer.Size);
          Buffer.Seek(0, soFromBeginning);
          Buffer.read(IndexHead.Indexs_Hash, 4);
          Hash1(Head.DataOffset);
          if IndexHead.Indexs_Hash = Hash2(@Pbyte(Buffer.Memory)
            [4], Head.DataOffset - 8) then
            Result := dsTrue;
        end else
        Result := dsUnknown;
      finally
        Buffer.Free;
      end;
    end;
  except
    Result := dsError;
  end;
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  Head: Pack_Head;
  indexs: Pack_Entries;
  IndexHead: Indexs_Head;
  Buffer: TMemoryStream;
  i, j: Integer;
  tmp: Byte;
  Rlentry: TRlEntry;
begin
  Result := True;
  try
    Buffer := TMemoryStream.Create;
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.read(Head.DataOffset, sizeof(Pack_Head));
    if Head.DataOffset > FileBuffer.Size then
      raise Exception.Create('Package Error.');
    Buffer.Seek(0, soFromBeginning);
    Buffer.CopyFrom(FileBuffer, Head.DataOffset -
      sizeof(Pack_Head));
    TableCreate(Head.DataOffset);
    Decode(Buffer.Memory, Buffer.Size);
    Buffer.Seek(0, soFromBeginning);
    Buffer.read(IndexHead.Indexs_Hash, 4);
    Hash1(Head.DataOffset);
    if IndexHead.Indexs_Hash <> Hash2(@Pbyte(Buffer.Memory)[4],
      Head.DataOffset - 8) then
      raise Exception.Create('Data check error.');
    i := 0;
    while i < Head.DataOffset - 8 do
    begin
      tmp := 1;
      j := 0;
      while tmp <> 0 do
      begin
        Buffer.read(tmp, 1);
        j := j + 1;
      end;
      SetLength(indexs.filename, j);
      Buffer.Seek(-j, soFromCurrent);
      Buffer.read(Pbyte(indexs.filename)^, j);
      Buffer.read(indexs.length, 4);
      Buffer.read(indexs.decompress_length, 4);
      Buffer.read(indexs.start_offset, 4);
      Buffer.read(indexs.Flag, 1);
      Buffer.read(indexs.Seed, 4);
      i := i + j + 17;
      Rlentry := TRlEntry.Create;
      Rlentry.AName := Trim(indexs.filename);
      Rlentry.AOffset := indexs.start_offset + Head.DataOffset;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs.length;
      Rlentry.ARLength := indexs.decompress_length;
      Rlentry.AKey2 := indexs.Seed;
      Rlentry.AKey := indexs.Flag;
      IndexStream.add(Rlentry);
    end;
    Buffer.Free;
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
  Buffer: TGlCompressBuffer;
  Decompr_Len: Cardinal;
begin
  Buffer := TGlCompressBuffer.Create;
  Decompr_Len := FileBuffer.Rlentry.ARLength;
  TableCreate(FileBuffer.Rlentry.AKey2);
  FileBuffer.Seek(FileBuffer.Rlentry.AOffset, soFromBeginning);
  Buffer.CopyFrom(FileBuffer, FileBuffer.Rlentry.AStoreLength);
  Buffer.Size := FileBuffer.Rlentry.AStoreLength or $F;
  DecodeTableGen;
  Buffer.Seek(0, soFromBeginning);
  Decode2(Buffer);
  Buffer.Size := FileBuffer.Rlentry.AStoreLength;
  Buffer.Seek(0, soFromBeginning);
  Buffer.ZlibDecompress(Decompr_Len);
  Buffer.Output.Seek(0, soFromBeginning);
  Hash1(Buffer.Output.Size);
  if (Hash2(Buffer.Output.Memory, Buffer.Output.Size) <>
    FileBuffer.Rlentry.AKey2) and
    (FileBuffer.Rlentry.AKey = 0) then
    raise Exception.Create('Hash Cal Result: ' +
      IntToHex(Hash2(Buffer.Output.Memory, Buffer.Output.Size),
      8) + #10#13 + 'Key Detected: ' +
      IntToHex(FileBuffer.Rlentry.AKey2, 8));
  Result := OutBuffer.CopyFrom(Buffer.Output,
    Buffer.Output.Size);
  Buffer.Free;
  FileBuffer.EntrySelected := FileBuffer.EntrySelected + 1;
end;

function PackData(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream; var Percent: Word): Boolean;
var
  Buffer: TGlCompressBuffer;
  i: Integer;
  Head: Pack_Head;
  IndexsHead: Indexs_Head;
  indexs: array of Pack_Entries;
  Zero: Byte;
begin
  Result := True;
  try
    Buffer := TGlCompressBuffer.Create;
    Percent := 0;
    Head.DataOffset := sizeof(Pack_Head) + sizeof(IndexsHead);
    SetLength(indexs, IndexStream.Count);
    for i := 0 to IndexStream.Count - 1 do
    begin
      indexs[i].filename := IndexStream.Rlentry[i].AName;
      Head.DataOffset := Head.DataOffset +
        length(indexs[i].filename) + 17 + 1;
      Percent := Trunc((i / IndexStream.Count) * 30);
    end;
    FileBuffer.Write(Head.DataOffset, 4);
    FileBuffer.Write(IndexsHead.Indexs_Hash, 4);
    FileBuffer.Size := Head.DataOffset;
    FileBuffer.Seek(Head.DataOffset, soFromBeginning);
    for i := 0 to IndexStream.Count - 1 do
    begin
      Buffer.Clear;
      Buffer.LoadFromFile(IndexStream.ParentPath +
        IndexStream.Rlentry[i].AName);
      Buffer.Seek(0, soFromBeginning);
      Buffer.ZlibCompress(clDefault);
      indexs[i].length := Buffer.Output.Size;
      indexs[i].decompress_length := Buffer.Size;
      indexs[i].start_offset := FileBuffer.Position -
        Head.DataOffset;
      indexs[i].Flag := 0;
      Hash1(Buffer.Size);
      indexs[i].Seed := Hash2(Buffer.Memory, Buffer.Size);
      Buffer.Output.Size := indexs[i].length or $F;
      Buffer.Output.Seek(0, soFromBeginning);
      TableCreate(indexs[i].Seed);
      DecodeTableGen;
      Decode2(Buffer.Output);
      Buffer.Output.Size := indexs[i].length;
      Buffer.Output.Seek(0, soFromBeginning);
      FileBuffer.CopyFrom(Buffer.Output, Buffer.Output.Size);
      Percent := 30 + Trunc((i / IndexStream.Count) * 50);
    end;
    Buffer.Clear;
    Buffer.Size := 8;
    Zero := 0;
    Buffer.Seek(0, soFromEnd);
    for i := 0 to IndexStream.Count - 1 do
    begin
      Buffer.Write(Pbyte(indexs[i].filename)^,
        length(indexs[i].filename));
      Buffer.Write(Zero, 1);
      Buffer.Write(indexs[i].length, 4);
      Buffer.Write(indexs[i].decompress_length, 4);
      Buffer.Write(indexs[i].start_offset, 4);
      Buffer.Write(indexs[i].Flag, 1);
      Buffer.Write(indexs[i].Seed, 4);
      Percent := 80 + Trunc((i / IndexStream.Count) * 15);
    end;
    Hash1(Head.DataOffset);
    IndexsHead.Indexs_Hash := Hash2(@Pbyte(Buffer.Memory)[8],
      Head.DataOffset - 8);
    Buffer.Seek(0, soFromBeginning);
    Buffer.Write(Head.DataOffset, 4);
    Buffer.Write(IndexsHead.Indexs_Hash, 4);
    TableCreate(Head.DataOffset);
    Decode(@Pbyte(Buffer.Memory)[4], Head.DataOffset - 4);
    Buffer.Seek(0, soFromBeginning);
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.CopyFrom(Buffer, Head.DataOffset);
    SetLength(indexs, 0);
    Buffer.Free;
    Percent := 100;
  except
    Result := False;
  end;
end;

function GetPluginInfo: TGpInfo;
begin
  Result.ACopyRight := 'HatsuneTakumi';
  Result.AVersion := '0.0.1';
  Result.AGameEngine := 'Unknown Engine';
  Result.ACompany := 'unknow';
  Result.AExtension := 'Pak';
  Result.AMagicList := 'No Magic.';
  Result.AMoreInfo := '(C)2011 HatsuneTakumi @ Kdays';
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
