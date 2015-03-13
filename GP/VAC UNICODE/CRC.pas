unit CRC;

interface

uses Classes;

Function crc32_func(Buffer: TStream; Length: Cardinal; l: Cardinal = $0): Cardinal;

implementation

var
  crc32tbl: array [0 .. 256] of LongWord;

procedure crc32_Init;
var
  CRC, i, j: LongWord;
begin
  for i := 0 to 256 do
  begin
    CRC := i;
    for j := 0 to 7 do
    begin
      if CRC and 1 = 1 then
        CRC := (CRC shr 1) xor $EDB88320
      else
        CRC := CRC shr 1;
    end;
    crc32tbl[i] := CRC;
  end;
end;

// CRC32
Function crc32_func(Buffer: TStream; Length: Cardinal; l: Cardinal = $0): Cardinal;
var
  i, j: Integer;
  t: LongWord;
  s:Byte;
begin
  // l := $FFFFFFFF;
  l := not(l);
  crc32_Init;
  if (Buffer <> nil) and (Length <> 0) then
  begin
    for i := 1 to Length do
    begin
      Buffer.Read(s,1);
      j := byte(l xor Ord(S));
      t := crc32tbl[j];
      l := t xor (l shr 8) and $00FFFFFF;
    end;
    Result := not(l);
  end
  else
    Result := 0;
end;

end.
