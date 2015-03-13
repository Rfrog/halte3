unit MD5;

interface

uses
  Windows, Messages, SysUtils, Variants;

type
  MD5Count = array [0 .. 1] of DWORD;
  MD5State = array [0 .. 3] of DWORD;
  MD5Block = array [0 .. 15] of DWORD;
  MD5CBits = array [0 .. 7] of Byte;
  MD5Digest = array [0 .. 15] of Byte;
  MD5Buffer = array [0 .. 63] of Byte;

  MD5Context = record
    State: MD5State;
    Count: MD5Count;
    Buffer: MD5Buffer;
  end;

procedure MD5Init(var Context: MD5Context);
procedure MD5Update(var Context: MD5Context; Input: PAnsiChar;
  Length: longword);
procedure MD5Final(var Context: MD5Context; var Digest: MD5Digest);
function MD5File(N: String): MD5Digest;
function MD5Print(D: MD5Digest): AnsiString;
function MD5F(FileName: AnsiString): AnsiString;
function MD5S(Str: AnsiString): AnsiString;

// MD5F为计算文件的MD5值,MD5S为计算字符串的MD5值!
var
  PADDING: MD5Buffer = ($80, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
    $00, $00, $00, $00, $00, $00, $00, $00);

implementation

function F(x, y, z: DWORD): DWORD;
begin
  Result := (x and y) or ((not x) and z);
end;

function G(x, y, z: DWORD): DWORD;
begin
  Result := (x and z) or (y and (not z));
end;

function H(x, y, z: DWORD): DWORD;
begin
  Result := x xor y xor z;
end;

function I(x, y, z: DWORD): DWORD;
begin
  Result := y xor (x or (not z));
end;

procedure rot(var x: DWORD; N: Byte);
begin
  x := (x shl N) or (x shr (32 - N));
end;

procedure FF(var a: DWORD; b, c, D, x: DWORD; s: Byte; ac: DWORD);
begin
  inc(a, F(b, c, D) + x + ac);
  rot(a, s);
  inc(a, b);
end;

procedure GG(var a: DWORD; b, c, D, x: DWORD; s: Byte; ac: DWORD);
begin
  inc(a, G(b, c, D) + x + ac);
  rot(a, s);
  inc(a, b);
end;

procedure HH(var a: DWORD; b, c, D, x: DWORD; s: Byte; ac: DWORD);
begin
  inc(a, H(b, c, D) + x + ac);
  rot(a, s);
  inc(a, b);
end;

procedure II(var a: DWORD; b, c, D, x: DWORD; s: Byte; ac: DWORD);
begin
  inc(a, I(b, c, D) + x + ac);
  rot(a, s);
  inc(a, b);
end;

procedure Encode(Source, Target: pointer; Count: longword);
var
  s: PByte;
  T: PDWORD;
  I: longword;
begin
  s := Source;
  T := Target;
  for I := 1 to Count div 4 do
  begin
    T^ := s^;
    inc(s);
    T^ := T^ or (s^ shl 8);
    inc(s);
    T^ := T^ or (s^ shl 16);
    inc(s);
    T^ := T^ or (s^ shl 24);
    inc(s);
    inc(T);
  end;
end;

procedure Decode(Source, Target: pointer; Count: longword);
var
  s: PDWORD;
  T: PByte;
  I: longword;
begin
  s := Source;
  T := Target;
  for I := 1 to Count do
  begin
    T^ := s^ and $FF;
    inc(T);
    T^ := (s^ shr 8) and $FF;
    inc(T);
    T^ := (s^ shr 16) and $FF;
    inc(T);
    T^ := (s^ shr 24) and $FF;
    inc(T);
    inc(s);
  end;
end;

procedure Transform(Buffer: pointer; var State: MD5State);
var
  a, b, c, D: DWORD;
  Block: MD5Block;
begin
  Encode(Buffer, @Block, 64);
  a := State[0];
  b := State[1];
  c := State[2];
  D := State[3];
  FF(a, b, c, D, Block[0], 7, $D76AA478);
  FF(D, a, b, c, Block[1], 12, $E8C7B756);
  FF(c, D, a, b, Block[2], 17, $242070DB);
  FF(b, c, D, a, Block[3], 22, $C1BDCEEE);
  FF(a, b, c, D, Block[4], 7, $F57C0FAF);
  FF(D, a, b, c, Block[5], 12, $4787C62A);
  FF(c, D, a, b, Block[6], 17, $A8304613);
  FF(b, c, D, a, Block[7], 22, $FD469501);
  FF(a, b, c, D, Block[8], 7, $698098D8);
  FF(D, a, b, c, Block[9], 12, $8B44F7AF);
  FF(c, D, a, b, Block[10], 17, $FFFF5BB1);
  FF(b, c, D, a, Block[11], 22, $895CD7BE);
  FF(a, b, c, D, Block[12], 7, $6B901122);
  FF(D, a, b, c, Block[13], 12, $FD987193);
  FF(c, D, a, b, Block[14], 17, $A679438E);
  FF(b, c, D, a, Block[15], 22, $49B40821);
  GG(a, b, c, D, Block[1], 5, $F61E2562);
  GG(D, a, b, c, Block[6], 9, $C040B340);
  GG(c, D, a, b, Block[11], 14, $265E5A51);
  GG(b, c, D, a, Block[0], 20, $E9B6C7AA);
  GG(a, b, c, D, Block[5], 5, $D62F105D);
  GG(D, a, b, c, Block[10], 9, $2441453);
  GG(c, D, a, b, Block[15], 14, $D8A1E681);
  GG(b, c, D, a, Block[4], 20, $E7D3FBC8);
  GG(a, b, c, D, Block[9], 5, $21E1CDE6);
  GG(D, a, b, c, Block[14], 9, $C33707D6);
  GG(c, D, a, b, Block[3], 14, $F4D50D87);
  GG(b, c, D, a, Block[8], 20, $455A14ED);
  GG(a, b, c, D, Block[13], 5, $A9E3E905);
  GG(D, a, b, c, Block[2], 9, $FCEFA3F8);
  GG(c, D, a, b, Block[7], 14, $676F02D9);
  GG(b, c, D, a, Block[12], 20, $8D2A4C8A);
  HH(a, b, c, D, Block[5], 4, $FFFA3942);
  HH(D, a, b, c, Block[8], 11, $8771F681);
  HH(c, D, a, b, Block[11], 16, $6D9D6122);
  HH(b, c, D, a, Block[14], 23, $FDE5380C);
  HH(a, b, c, D, Block[1], 4, $A4BEEA44);
  HH(D, a, b, c, Block[4], 11, $4BDECFA9);
  HH(c, D, a, b, Block[7], 16, $F6BB4B60);
  HH(b, c, D, a, Block[10], 23, $BEBFBC70);
  HH(a, b, c, D, Block[13], 4, $289B7EC6);
  HH(D, a, b, c, Block[0], 11, $EAA127FA);
  HH(c, D, a, b, Block[3], 16, $D4EF3085);
  HH(b, c, D, a, Block[6], 23, $4881D05);
  HH(a, b, c, D, Block[9], 4, $D9D4D039);
  HH(D, a, b, c, Block[12], 11, $E6DB99E5);
  HH(c, D, a, b, Block[15], 16, $1FA27CF8);
  HH(b, c, D, a, Block[2], 23, $C4AC5665);
  II(a, b, c, D, Block[0], 6, $F4292244);
  II(D, a, b, c, Block[7], 10, $432AFF97);
  II(c, D, a, b, Block[14], 15, $AB9423A7);
  II(b, c, D, a, Block[5], 21, $FC93A039);
  II(a, b, c, D, Block[12], 6, $655B59C3);
  II(D, a, b, c, Block[3], 10, $8F0CCC92);
  II(c, D, a, b, Block[10], 15, $FFEFF47D);
  II(b, c, D, a, Block[1], 21, $85845DD1);
  II(a, b, c, D, Block[8], 6, $6FA87E4F);
  II(D, a, b, c, Block[15], 10, $FE2CE6E0);
  II(c, D, a, b, Block[6], 15, $A3014314);
  II(b, c, D, a, Block[13], 21, $4E0811A1);
  II(a, b, c, D, Block[4], 6, $F7537E82);
  II(D, a, b, c, Block[11], 10, $BD3AF235);
  II(c, D, a, b, Block[2], 15, $2AD7D2BB);
  II(b, c, D, a, Block[9], 21, $EB86D391);
  inc(State[0], a);
  inc(State[1], b);
  inc(State[2], c);
  inc(State[3], D);
end;

procedure MD5Init(var Context: MD5Context);
begin
  with Context do
  begin
    State[0] := $67452301;
    State[1] := $EFCDAB89;
    State[2] := $98BADCFE;
    State[3] := $10325476;
    Count[0] := 0;
    Count[1] := 0;
    ZeroMemory(@Buffer, SizeOf(MD5Buffer));
  end;
end;

procedure MD5Update(var Context: MD5Context; Input: PAnsiChar;
  Length: longword);
var
  Index: longword;
  PartLen: longword;
  I: longword;
begin
  with Context do
  begin
    Index := (Count[0] shr 3) and $3F;
    inc(Count[0], Length shl 3);
    if Count[0] < (Length shl 3) then
      inc(Count[1]);
    inc(Count[1], Length shr 29);
  end;
  PartLen := 64 - Index;
  if Length >= PartLen then
  begin
    CopyMemory(@Context.Buffer[Index], Input, PartLen);
    Transform(@Context.Buffer, Context.State);
    I := PartLen;
    while I + 63 < Length do
    begin
      Transform(@Input[I], Context.State);
      inc(I, 64);
    end;
    Index := 0;
  end
  else
    I := 0;
  CopyMemory(@Context.Buffer[Index], @Input[I], Length - I);
end;

procedure MD5Final(var Context: MD5Context; var Digest: MD5Digest);
var
  Bits: MD5CBits;
  Index: longword;
  PadLen: longword;
begin
  Decode(@Context.Count, @Bits, 2);
  Index := (Context.Count[0] shr 3) and $3F;
  if Index < 56 then
    PadLen := 56 - Index
  else
    PadLen := 120 - Index;
  MD5Update(Context, @PADDING, PadLen);
  MD5Update(Context, @Bits, 8);
  Decode(@Context.State, @Digest, 4);
  ZeroMemory(@Context, SizeOf(MD5Context));
end;

function MD5String(M: AnsiString): MD5Digest;
var
  Context: MD5Context;
begin
  MD5Init(Context);
  MD5Update(Context, PAnsiChar(M), Length(M));
  MD5Final(Context, Result);
end;

function MD5File(N: String): MD5Digest;
var
  FileHandle: THandle;
  MapHandle: THandle;
  ViewPointer: pointer;
  Context: MD5Context;
begin
  MD5Init(Context);
  FileHandle := CreateFile(PWideChar(WideString(N)), GENERIC_READ,
    FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL or FILE_FLAG_SEQUENTIAL_SCAN, 0);
  if FileHandle <> INVALID_HANDLE_VALUE then
    try
      MapHandle := CreateFileMapping(FileHandle, nil, PAGE_READONLY, 0, 0, nil);
      if MapHandle <> 0 then
        try
          ViewPointer := MapViewOfFile(MapHandle, FILE_MAP_READ, 0, 0, 0);
          if ViewPointer <> nil then
            try
              MD5Update(Context, ViewPointer, GetFileSize(FileHandle, nil));
            finally
              UnmapViewOfFile(ViewPointer);
            end;
        finally
          CloseHandle(MapHandle);
        end;
    finally
      CloseHandle(FileHandle);
    end;
  MD5Final(Context, Result);
end;

function MD5Print(D: MD5Digest): AnsiString;
var
  I: Byte;
const
  Digits: array [0 .. 15] of Ansichar = ('0', '1', '2', '3', '4', '5', '6', '7',
    '8', '9', 'a', 'b', 'c', 'd', 'e', 'f');
begin
  Result := '';
  for I := 0 to 15 do
    Result := Result + Digits[(D[I] shr 4) and $0F] + Digits[D[I] and $0F];
end;

function MD5Match(D1, D2: MD5Digest): boolean;
var
  I: Byte;
begin
  I := 0;
  Result := TRUE;
  while Result and (I < 16) do
  begin
    Result := D1[I] = D2[I];
    inc(I);
  end;
end;

function MD5S(Str: AnsiString): AnsiString;
begin
  Result := MD5Print(MD5String(Str));
end;

function MD5F(FileName: AnsiString): AnsiString;
begin
  Result := MD5Print(MD5File(string(FileName)));
end;

end.
