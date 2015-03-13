program Project13;

{$APPTYPE CONSOLE}

{$R *.res}


uses
  System.SysUtils,
  System.Classes;

Type
  Pack_Head = Packed Record
    Magic: array [ 0 .. 3 ] of AnsiChar;
    Version: Cardinal;
    count: Cardinal;
    Table_size: Cardinal;
    Dummy: array [ 1 .. 16 ] of byte;
  End;

  Pack_Entries = packed Record
    FNHash: longword;
    EncFNLen: byte;
    filename: AnsiString;
    filetype: byte;
    flag: byte;
    File_Size: Cardinal;
    Compressed_Size: Cardinal;
    Offset: Cardinal;
    Hash: Cardinal;
  End;

var
  DecodeTable: array [ 0 .. 255 ] of byte;

procedure Exchange(A, b: Integer);
var
  tmp: byte;
begin
  tmp              := DecodeTable[ A ];
  DecodeTable[ A ] := DecodeTable[ b ];
  DecodeTable[ b ] := tmp;
end;

procedure DecodeTableInit(m: Boolean);
var
  i: Integer;
begin
  for i              := 0 to 255 do
    DecodeTable[ i ] := i;
  Exchange(3, 72);
  Exchange(6, 53);
  Exchange(9, 11);
  Exchange(12, 16);
  Exchange(13, 19);
  Exchange(17, 25);
  Exchange(21, 27);
  Exchange(28, 30);
  Exchange(32, 35);
  Exchange(38, 41);
  Exchange(44, 47);
  Exchange(46, 50);
end;

function CryptLen(Version: Cardinal; CurValue: byte): byte;
const
  LenTable: array [ 0 .. 23 ] of byte = (
    $03, $48, $06, $35,           // $122
    $0C, $10, $11, $19, $1C, $1E, // $000..$0FF
    $09, $0B, $0D, $13, $15, $1B, // $12C
    $20, $23, $26, $29,
    $2C, $2F, $2E, $32);
var
  i, j: Integer;
begin

  case Version of
    $122 .. $12B:
      j := 0;
    $12C:
      j := 5;
  else
    j := 2; // $00..$FF
  end;

  Result := CurValue;

  for i := j to 11 do
  begin
    if CurValue = LenTable[ i * 2 ] then
    begin
      Result := LenTable[ i * 2 + 1 ];
      Break;
    end else if CurValue = LenTable[ i * 2 + 1 ] then
    begin
      Result := LenTable[ i * 2 ];
      Break;
    end;
  end;

end;

var
  f      : TFileStream;
  head   : Pack_Head;
  entry  : array of Pack_Entries;
  A, i, j: Integer;
  b      : TMemoryStream;
  o      : Cardinal;

begin
  try
    f := TFileStream.Create('E:\SherbetSoft\êßïûìVég\pac\bgm.ypf', fmopenread);
    f.Read(head.Magic[ 0 ], SizeOf(Pack_Head));
    DecodeTableInit(True);
    SetLength(entry, head.count);
    for j := 0 to head.count - 1 do
    begin
      f.Read(entry[ j ].FNHash, 5);
      A := DecodeTable[ $FF - entry[ j ].EncFNLen ];
      // A := CryptLen(head.Version, entry[ j ].EncFNLen xor $FF);
      SetLength(entry[ j ].filename, A);
      f.Read(PByte(entry[ j ].filename)^, A);
      for i                             := 0 to A - 1 do
        PByte(entry[ j ].filename)[ i ] := not PByte(entry[ j ].filename)[ i ];
      f.Read(entry[ j ].filetype, 18);
    end;
    b     := TMemoryStream.Create;
    for j := 0 to head.count - 1 do
    begin
      f.Seek(entry[ j ].Offset + head.Table_size - head.count, soFromBeginning);
      b.Clear;
      b.CopyFrom(f, entry[ j ].Compressed_Size);
      b.SaveToFile('1');
    end;
    f.Free;
    b.Free;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

end.
