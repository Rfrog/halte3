library Malie;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  StrUtils,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas',
  Windows,
  SBUtils in '..\..\..\..\Dies irae(Light)\Inc\SBUtils.pas',
  SBSHA in '..\..\..\..\Dies irae(Light)\Inc\SBSHA.pas',
  SBRandom in '..\..\..\..\Dies irae(Light)\Inc\SBRandom.pas',
  SBMD in '..\..\..\..\Dies irae(Light)\Inc\SBMD.pas',
  SBMath in '..\..\..\..\Dies irae(Light)\Inc\SBMath.pas',
  SBConstants
    in '..\..\..\..\Dies irae(Light)\Inc\SBConstants.pas',
  SBCamellia
    in '..\..\..\..\Dies irae(Light)\Inc\SBCamellia.pas',
  SBASN1Tree
    in '..\..\..\..\Dies irae(Light)\Inc\SBASN1Tree.pas',
  SBASN1 in '..\..\..\..\Dies irae(Light)\Inc\SBASN1.pas',
  camellia in 'camellia.pas';

{$E gp}
{$R *.res}

Type

  Pbyte = SYSTEM.Pbyte;

  Pack_Head = Packed Record
    Magic: array [0 .. 3] of AnsiChar;
    Version: DWORD;
    Entries_Count: DWORD;
    Reserved: DWORD;
  End;

  Lib_Pack_Entries = Record
    File_name: Array [0 .. 35] of AnsiChar;
    Length: DWORD;
    START_OFFSET: DWORD;
    Reserved: DWORD;
  End;

  Lib_Unicode_Pack_Entries = Record
    File_name: Array [0 .. 33] of WideCHAR;
    Length: DWORD;
    START_OFFSET: DWORD;
    Reserved: DWORD;
  End;

  Scr_Pack_Head = Packed Record
    Magic: array [0 .. 12] of AnsiChar;
  End;

procedure empty_key(key: array of Byte);
begin
  FillMemory(@key[0], 16, 0);
end;

const
  orig_key1: array [0 .. 15] of Byte = ($FD, $FE, $FF, $00, $F9,
    $FA, $FB, $FC, $F5, $F6, $F7, $F8, $F1, $F2, $F3, $F4);
  orig_key2: array [0 .. 15] of Byte = ($AC, $CA, $8B, $96, $9A,
    $8F, $C7, $99, $AA, $AE, $88, $AF, $9D, $A9, $A8, $B6);
  orig_key3: array [0 .. 15] of Byte = ($AF, $B3, $CA, $CB, $8A,
    $92, $B9, $8B, $BE, $B5, $91, $9D, $BA, $AB, $B4, $B8);
  orig_key4: array [0 .. 15] of Byte = ($B2, $95, $CC, $AA, $BD,
    $BB, $C9, $86, $A8, $AC, $CD, $D0, $8A, $B1, $A6, $B4);
  orig_key5: array [0 .. 15] of Byte = ($AF, $B3, $CA, $CB, $8A,
    $92, $B9, $8B, $BE, $B5, $91, $9D, $BA, $AB, $B4, $B8);
  orig_key6: array [0 .. 15] of Byte = ($8F, $9D, $B9, $9E, $94,
    $AF, $AD, $BB, $9C, $A8, $8B, $92, $9F, $B3, $97, $BA);

procedure mbs_tolower(key: Pbyte);
var
  i: Integer;
begin
  for i := 0 to 16 - 1 do
    key[i] := Byte(-orig_key1[i]);
end;

procedure mbs_tolower2(key: Pbyte);
var
  i: Integer;
begin
  for i := 0 to 16 - 1 do
    key[i] := Byte(-orig_key2[i]);
end;

procedure mbs_tolower3(key: Pbyte);
var
  i: Integer;
begin
  for i := 0 to 16 - 1 do
    key[i] := Byte(-orig_key3[i]);
end;

procedure mbs_tolower4(key: Pbyte);
var
  i: Integer;
begin
  for i := 0 to 16 - 1 do
    key[i] := Byte(-orig_key4[i]);
end;

procedure mbs_tolower5(key: Pbyte);
var
  i: Integer;
begin
  for i := 0 to 16 - 1 do
    key[i] := Byte(-orig_key5[i]);
end;

procedure mbs_tolower6(key: Pbyte);
var
  i: Integer;
begin
  for i := 0 to 16 - 1 do
    key[i] := Byte(-orig_key6[i]);
end;

procedure EmptyKey(key: Pbyte);
var
  i: Integer;
begin
  for i := 0 to 16 - 1 do
    key[i] := Byte($00);
end;

Procedure Decode(RawKey: Pbyte; Num: Integer);
begin
  if Num = 1 then
    mbs_tolower(RawKey)
  else if Num = 2 then
    mbs_tolower2(RawKey)
  else if Num = 3 then
    mbs_tolower3(RawKey)
  else if Num = 4 then
    mbs_tolower4(RawKey)
  else if Num = 5 then
    mbs_tolower5(RawKey)
  else if Num = 6 then
    mbs_tolower6(RawKey)
  else if Num = 7 then
    EmptyKey(RawKey);
end;

procedure rotate16bytes(offset: DWORD; var cipher1);
var
  shifts: Byte;
  cipher: Pbyte;
begin
  cipher := @cipher1;
  shifts := ((offset shr 4) and $0F) + 16;
  PDWORD(@cipher[0])^ := LeftRotate(PDWORD(@cipher[0])^, shifts);
  PDWORD(@cipher[4])^ := RightRotate(PDWORD(@cipher[4])
    ^, shifts);
  PDWORD(@cipher[8])^ := LeftRotate(PDWORD(@cipher[8])^, shifts);
  PDWORD(@cipher[12])^ :=
    RightRotate(PDWORD(@cipher[12])^, shifts);
end;

procedure Read_Cipher(const Buffer: Pbyte; const cipher: Pbyte;
  const offset: DWORD);
begin
  Move(Buffer[offset], cipher[0], 16);
end;

procedure Write_Plain_Buffer(const Plain_Buffer: Pbyte;
  const Plain: Pbyte; const offset: DWORD);
begin
  Move(Plain[0], Plain_Buffer[offset], 16);
end;

function Decode_Data_Block(Data_Buffer: Pbyte; offset: DWORD;
  Data_Length: DWORD; RawKey: SBCamellia.TSBCamelliaKey): Pbyte;
var
  cipher, Plain: Pbyte;
  Al_Key, key, i: DWORD;
  Tmp, Act_Length, cipher_length: DWORD;
  Plain_Buffer: Pbyte;
  offset0: DWORD;
  Key_Context: TCamelliaContext;
  Iv: TSBCamelliaBuffer;
begin
  Move(RawKey[0], Iv[0], 16); // 初始化IV
  cipher := SysGetMem(32);
  Plain := SysGetMem(32);
  Plain_Buffer := SysGetMem(Data_Length);
  Result := Plain_Buffer;
  Al_Key := offset and $0F;
  offset0 := offset - Al_Key;
  key := (16 - Al_Key) and $0F; // 这个是真实的数据地址
  offset := 0; // 注意 这里置0 ,加上offset0就是绝对偏移
  if Al_Key <> 0 then
  begin
    Read_Cipher(Data_Buffer, cipher, offset);
    // 将数据读入临时场所 每次解密前均使用这个函数,这样保证数据仅受offset控制
    InitializeDecryptionCBC(RawKey, Iv, Key_Context);
    rotate16bytes(Integer(offset + offset0), cipher[0]);
    // 这里使用的是绝对偏移
    Tmp := 16;
    DecryptCBC(Key_Context, Pointer(@cipher[0]), 16,
      Pointer(@Plain^), Tmp);
    FinalizeDecryptionCBC(Key_Context, Pointer(@Plain^), Tmp);
    if Data_Length > key then
      Act_Length := key
    else
      Act_Length := Data_Length;
    Move(Plain[Al_Key], Plain_Buffer[0], Act_Length);
    Data_Length := Data_Length - Act_Length;
    Inc(offset, 16);
  end;
  cipher_length := (Data_Length and not $0F) div 16; // 数据解密次数
  for i := 0 to cipher_length - 1 do
  begin
    Read_Cipher(Data_Buffer, cipher, offset);
    rotate16bytes(Integer(offset + offset0), cipher[0]);
    Tmp := 16;
    InitializeDecryptionCBC(RawKey, Iv, Key_Context);
    DecryptCBC(Key_Context, Pointer(@cipher[0]), 16,
      Pointer(@Plain_Buffer[key + i * 16]), Tmp);
    FinalizeDecryptionCBC(Key_Context,
      Pointer(@Plain_Buffer[key + i * 16]), Tmp);
    // 数据被直接写入plainbuffer
    Inc(offset, 16);
  end;
  Al_Key := Data_Length and $0F;
  if Al_Key <> 0 then
  begin
    Read_Cipher(Data_Buffer, cipher, offset);
    rotate16bytes(Integer(offset + offset0), cipher[0]);
    Tmp := 16;
    InitializeDecryptionCBC(RawKey, Iv, Key_Context);
    DecryptCBC(Key_Context, Pointer(@cipher[0]), 16,
      @Plain_Buffer[key + cipher_length * 16], Tmp);
    FinalizeDecryptionCBC(Key_Context,
      Pointer(@Plain_Buffer[key + cipher_length * 16]), Tmp);
  end;
  SysFreeMem(Plain);
  SysFreeMem(cipher);
end;

function MemStr(src, dst: Pbyte; Data_Length: Integer): Pointer;
var
  i, k: Integer;
begin
  for i := 0 to Data_Length - 1 do
  begin
    k := 0;
    while src[k] <> 0 do
    begin
      if dst[i + k] <> src[k] then
        Break;
      Inc(k);
    end;
    if src[k] = 0 then
      Break;
  end;
  if i = Data_Length then
    Result := nil
  else
    Result := @dst[i];
end;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName
    ('Malie', clEngine));
end;

const
  Pack_Magic: AnsiString = 'LIBU';

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  Head: Pack_Head;
  indexs: array of Lib_Unicode_Pack_Entries;
  i: Integer;
  Rlentry: TRlEntry;
  RawKey: SBCamellia.TSBCamelliaKey;
  Iv: TSBCamelliaBuffer;
  Key_Context: TCamelliaContext;
  TempBuffer, Plain: Pbyte;
  Tmp, base_offset, rs_offset: DWORD;
begin
  Result := True;
  try
    FileBuffer.Seek(0, soFromBeginning);
    TempBuffer := GetMemory(32);
    Plain := GetMemory(32);
    FileBuffer.Read(TempBuffer^, SizeOf(Pack_Head));
    SetLength(RawKey, 16);
    for i := 0 to 6 do
    begin
      Move(TempBuffer^, Head.Magic[0], 16);
      FillMemory(@KeyTable[0], SizeOf(KeyTable), 0);
      Decode(@RawKey[0], i + 1);
      rotate16bytes(0, Head.Magic[0]);
      Move(RawKey[0], Iv[0], 16);
      InitializeDecryptionCBC(RawKey, Iv, Key_Context);
      Tmp := 16;
      DecryptCBC(Key_Context, @Head.Magic[0], 16, Plain, Tmp);
      FinalizeDecryptionCBC(Key_Context, Plain, Tmp);
      Move(Plain^, Head.Magic[0], 16);
      if SameText(Head.Magic, 'LIBU') then
      begin
        Encoded_Type := i + 1;
        Break;
      end;
      if i = 6 then
        raise Exception.Create('Unsupported Package.');
    end;
    FreeMem(TempBuffer);
    FreeMem(Plain);
    SetLength(indexs, Head.Entries_Count);
    base_offset := 0;
    rs_offset := base_offset + SizeOf(Pack_Head);
    FileBuffer.Read(indexs[0].File_name[0], Head.Entries_Count *
      SizeOf(Lib_Unicode_Pack_Entries));
    TempBuffer := Decode_Data_Block(@indexs[0].File_name[0],
      rs_offset, Head.Entries_Count *
      SizeOf(Lib_Unicode_Pack_Entries), RawKey);
    Move(TempBuffer[0], indexs[0].File_name[0],
      Head.Entries_Count * SizeOf(Lib_Unicode_Pack_Entries));
    FreeMemory(TempBuffer);
    for i := 0 to Head.Entries_Count - 1 do
    begin
      Rlentry := TRlEntry.Create;
      Rlentry.AOffset := indexs[i].START_OFFSET;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs[i].Length;
      Rlentry.ARLength := 0;
      Rlentry.AName := Trim(indexs[i].File_name);
      Move(rawkey[0],Rlentry.AHash[0],16);
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

function ReadData(FileBuffer: TFileBufferStream;
  OutBuffer: TStream): LongInt;
var
  rs_offset, rs_length: Cardinal;
  Buffer,Plain: Pbyte;
  Rawkey: SBCamellia.TSBCamelliaKey;
begin
  rs_offset := FileBuffer.Rlentry.AOffset and $0F;
  FileBuffer.Rlentry.AOffset := FileBuffer.Rlentry.AOffset -
    rs_offset;
  rs_length := FileBuffer.Rlentry.AStoreLength;
  FileBuffer.Rlentry.AStoreLength :=
    ((FileBuffer.Rlentry.AStoreLength + rs_offset) + 15) and
    (Not $0F);
  FileBuffer.Seek(FileBuffer.Rlentry.AOffset,
    soFromBeginning);
  Buffer := GetMemory(FileBuffer.Rlentry.AStoreLength);
  FileBuffer.Read(buffer[0],FileBuffer.Rlentry.AStoreLength);
  SetLength(Rawkey,16);
  Move(FileBuffer.RlEntry.AHash[0],rawkey[0],16);
  Plain := Decode_Data_Block(Buffer,
    FileBuffer.Rlentry.AOffset,
    FileBuffer.Rlentry.AStoreLength, RawKey);
  OutBuffer.Write(Plain[rs_offset],
    FileBuffer.Rlentry.AStoreLength);
  FreeMem(Plain);
  FreeMem(Buffer);
  Result := FileBuffer.Rlentry.AStoreLength;
  FileBuffer.EntrySelected := FileBuffer.EntrySelected + 1;
end;

function PackData(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream; var Percent: Word): Boolean;
var
  i: Integer;
  Head: Pack_Head;
  indexs: array of Lib_Unicode_Pack_Entries;
  tmpbuffer: TFileStream;
  zero: Byte;
begin
  try

  except
    Result := False;
  end;
end;

exports GetPluginName;

exports GenerateEntries;

exports Decyption;

exports ReadData;

{exports PackData; }

begin

end.
