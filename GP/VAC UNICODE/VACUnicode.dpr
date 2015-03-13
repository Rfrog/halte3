library VACUnicode;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  StrUtils,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas',
  CRC in 'CRC.pas', Vcl.Dialogs;

{$E gp}
{$R *.res}

Type
  Pack_Head = Packed Record
    Magic: ARRAY [0 .. 3] OF ANSICHAR;
    Head_length: Cardinal;
    entries_length: Cardinal;
    entries_count: Cardinal;
    Hash_Code: Cardinal;
    reserved: Cardinal; // 0
    Pack_Name: array [1 .. $100] of ANSICHAR;
  End;

  Pack_Entries = packed Record
    name_hash: Cardinal;
    start_offset: Cardinal;
    length: Cardinal;
    decompress_length: Cardinal;
    compress_flag: Cardinal;
    name_length: Cardinal;
    filename: AnsiString;
  End;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('Kiss 3D Game Engine',
    clGameMaker));
end;

const
  key: WideString = 'OREGAOREGASURUWAKATEGEININ';

procedure Decode(Buffer: PByte; Buflength: Cardinal);
var
  i, j: Integer;
  ecx: Cardinal;
begin
  j := 0;
  ecx := 0;
  for i := 0 to Buflength - 1 do
  begin
    Buffer[i] := Buffer[i] xor (PByte(key)[j] + Byte(ecx));
    j := j + 2;
    ecx := ecx + $4D;
    if j >= length(key) * 2 then
      j := 0;
  end;
end;

function name_hash(sName: string; dwHashCode: Cardinal)
  : Cardinal;
label _jmp;
var
  eax, ecx: Cardinal;
  i: Integer;
  ADDR: Pointer;
begin
  ADDR := PByte(sName);
  asm
    push ebx
    push eax
    push ecx
    push edi
    push esi
    mov esi,addr
    movzx ECX,WORD PTR [esi]
    xor ebx,ebx
    mov edi,dwHashCode
    _jmp:
    mov eax,ebx
    shl eax,8
    movzx ecx,cx
    add eax,ecx
    cdq
    idiv edi
    movzx ecx,word ptr [esi+2]
    add esi,2
    test cx,cx
    mov ebx,edx
    jnz _jmp
    mov result,ebx
    pop esi
    pop edi
    pop ecx
    pop eax
    pop ebx
  end;
  { ecx := Integer(Pword(@PByte(sName)[0])^);
    Result := 0;
    for i := 1 to length(sName) - 1 do
    begin
    eax := Result shl 8;
    ecx := word(ecx);
    eax := eax + ecx;
    ecx := Integer(Pword(@PByte(sName)[i*2])^);
    Result := eax mod dwHashCode;
    end; }
end;

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], sizeof(Pack_Head));
    if (Head.Head_length < FileBuffer.Size) and
      (Head.entries_length < FileBuffer.Size) and
      (Head.entries_count < FileBuffer.Size) and
      (Head.reserved = 0) and
      ((Head.entries_length + Head.Head_length) <
      FileBuffer.Size) and
      SameText(Trim(Head.Magic),'VARC') then
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
  indexs: Pack_Entries;
  Compress: TMemoryStream;
  i: Integer;
  Rlentry: TRlEntry;
begin
  Result := True;
  try
    Compress := TGlCompressBuffer.Create;
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[0], sizeof(Pack_Head));
    Compress.Seek(0, soFromBeginning);
    Compress.CopyFrom(FileBuffer, Head.entries_length);
    Decode(Compress.Memory, Compress.Size);
    Compress.Seek(0, soFromBeginning);
    for i := 0 to Head.entries_count - 1 do
    begin
      Rlentry := TRlEntry.Create;
      Compress.Read(indexs.name_hash, 24);
      SetLength(indexs.filename, indexs.name_length + 1);
      Compress.Read(Pointer(indexs.filename)^,
        indexs.name_length + 1);
      Rlentry.AName := Trim(indexs.filename);
      Rlentry.AOffset := indexs.start_offset;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs.length;
      Rlentry.ARLength := indexs.decompress_length;
      Rlentry.AKey := indexs.compress_flag;
      Rlentry.AHash[0] := indexs.name_hash;
    end;
    Compress.Destroy;
  except
    Result := False;
  end;
end;

procedure Decyption();
begin
  { do nothing }
end;

const
  decode_table: array [0 .. 3] of Byte = ($0E, $05, $09, $0B);

function ReadData(FileBuffer: TFileBufferStream;
  OutBuffer: TStream): LongInt;
var
  Buffer: TGlCompressBuffer;
  dec_flag: Boolean;
  i: Integer;
  tmpbyte: Byte;
begin
  OutBuffer.Seek(0, soFromBeginning);
  if SameText(ExtractFileExt(FileBuffer.Rlentry.AName),
    '.nei') then
    dec_flag := True
  else
    dec_flag := False;
  if FileBuffer.Rlentry.AKey = 1 then
  begin
    Buffer := TGlCompressBuffer.Create;
    Result := FileBuffer.ReadData(Buffer);
    Buffer.Seek(0, soFromBeginning);
    Buffer.LzssDecompress(Buffer.Size, $FEE, $FFF);
    Buffer.Output.Seek(0, soFromBeginning);
    OutBuffer.CopyFrom(Buffer.Output, Buffer.Output.Size);
    if dec_flag then
    begin
      OutBuffer.Seek(0, soFromBeginning);
      for i := 0 to OutBuffer.Size - 1 do
      begin
        OutBuffer.Read(tmpbyte, 1);
        tmpbyte := tmpbyte xor decode_table[i and 3];
        OutBuffer.Seek(-1, soFromCurrent);
        OutBuffer.Write(tmpbyte, 1);
      end;
    end;
    Buffer.Free;
  end
  else
  begin
    Result := FileBuffer.ReadData(OutBuffer);
    if dec_flag then
    begin
      OutBuffer.Seek(0, soFromBeginning);
      for i := 0 to OutBuffer.Size - 1 do
      begin
        OutBuffer.Read(tmpbyte, 1);
        tmpbyte := tmpbyte xor decode_table[i and 3];
        OutBuffer.Seek(-1, soFromCurrent);
        OutBuffer.Write(tmpbyte, 1);
      end;
    end;
  end;
end;

const
  Magic: AnsiString = 'VARC';

function PackData(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream; var Percent: WORD): Boolean;
var
  i: Integer;
  Head: Pack_Head;
  indexs: array of Pack_Entries;
  tmpBuffer: TFileStream;
  compr: TGlCompressBuffer;
  Pkname: AnsiString;
  zero: Byte;
  tmpBuffer1: TMemoryStream;
begin
  Result := True;
  try
    Percent := 0;
    zero := 0;
    FileBuffer.Seek(0, soFromBeginning);
    Head.Hash_Code :=
      StrToInt64(Vcl.Dialogs.InputBox('Input Hash_Code',
      'Input Hash_Code', '$A47'));
    Head.entries_count := IndexStream.Count;
    Head.reserved := 0;
    Head.Head_length := sizeof(Pack_Head);
    FillChar(Head.Pack_Name[1], sizeof(Head.Pack_Name), 0);
    Pkname := Vcl.Dialogs.InputBox('Input Package Name',
      'Input Package Name within 255 Byte', 'Script');
    Move(PByte(Pkname)^, Head.Pack_Name[1], length(Pkname));
    Move(PByte(Magic)^, Head.Magic[0], 4);
    Head.entries_length := 0;
    SetLength(indexs, IndexStream.Count);
    FileBuffer.Write(Head.Magic[0], sizeof(Pack_Head));
    for i := 0 to IndexStream.Count - 1 do
    begin
      indexs[i].name_hash :=
        name_hash(IndexStream.Rlentry[i].AName, Head.Hash_Code);
      indexs[i].compress_flag := 1;
      indexs[i].name_length :=
        length(IndexStream.Rlentry[i].AName);
      SetLength(indexs[i].filename, indexs[i].name_length);
      indexs[i].filename := IndexStream.Rlentry[i].AName;
      Head.entries_length := Head.entries_length + indexs[i]
        .name_length + 24 + 1;
      FileBuffer.Write(indexs[i].name_hash, 24);
      FileBuffer.Write(PByte(indexs[i].filename)^,
        indexs[i].name_length);
      FileBuffer.Write(zero, 1);
    end;
    compr := TGlCompressBuffer.Create;
    for i := 0 to IndexStream.Count - 1 do
    begin
      compr.Clear;
      compr.Output.Clear;
      tmpBuffer := TFileStream.Create(IndexStream.ParentPath +
        IndexStream.Rlentry[i].AName, fmOpenRead);
      indexs[i].start_offset := FileBuffer.Position;
      indexs[i].decompress_length := tmpBuffer.Size;
      tmpBuffer.Seek(0, soFromBeginning);
      compr.CopyFrom(tmpBuffer, tmpBuffer.Size);
      compr.Seek(0, soFromBeginning);
      compr.LzssCompress;
      compr.Output.Seek(0, soFromBeginning);
      FileBuffer.CopyFrom(compr.Output, compr.Output.Size);
      indexs[i].length := compr.Output.Size;
      tmpBuffer.Free;
      Percent := 90 * (i + 1) div IndexStream.Count;
    end;
    compr.Destroy;
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Write(Head.Magic[0], sizeof(Pack_Head));
    tmpBuffer1 := TMemoryStream.Create;
    { for i := 0 to IndexStream.Count - 1 do
      begin
      FileBuffer.Write(indexs[i].name_hash, 24);
      FileBuffer.Write(PByte(indexs[i].filename)^, indexs[i].name_length);
      FileBuffer.Write(zero, 1);
      Percent := 90 + 10 * (i + 1) div IndexStream.Count;
      end; }
    for i := 0 to IndexStream.Count - 1 do
    begin
      tmpBuffer1.Write(indexs[i].name_hash, 24);
      tmpBuffer1.Write(PByte(indexs[i].filename)^,
        indexs[i].name_length);
      tmpBuffer1.Write(zero, 1);
    end;
    Decode(tmpBuffer1.Memory, tmpBuffer1.Size);
    tmpBuffer1.Seek(0, soFromBeginning);
    FileBuffer.CopyFrom(tmpBuffer1, tmpBuffer1.Size);
    tmpBuffer1.Free;
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
