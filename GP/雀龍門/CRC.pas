unit CRC;

interface

Function crc32_func(S:PByte; Length : Cardinal;l : Cardinal = $0):Cardinal;

implementation

var crc32tbl:array[0..256] of LongWord;

procedure crc32_Init;
var
    crc,i,j:LongWord;
begin
    for i := 0 to 256 do
    begin
        crc := i;
        for j := 0 to 7 do
        begin
            if crc and 1 = 1 then
                crc := (crc shr 1) xor $EDB88320
            else
                crc := crc shr 1;
        end;
        crc32tbl[i] := crc;
    end;
end;

//CRC32
Function crc32_func(S:PByte; Length : Cardinal;l : Cardinal = $0):Cardinal;
var i,j:Integer;
    t:longWord;
begin
    //l := $FFFFFFFF;
    l := not(l);
    crc32_Init;
    if (S <> nil)and(Length <> 0) then
    begin
        for i := 1 to Length do
        begin
            j := byte(l xor Ord(s[i]));
            t := crc32tbl[j];
            l := t xor (l shr 8) and $00FFFFFF;
        end;
        Result := not(l);
    end
    else
        Result := 0;
end;

end.
