program Project13;

{$APPTYPE CONSOLE}

{$R *.res}


uses
  System.SysUtils,
  classes,
  BlowFish in 'BlowFish.pas';

const
  Key1: array [ $0 .. $20 - 1 ] of Byte = (
    $FA, $07, $B4, $39, $F8, $01, $8D, $8A,
    $EC, $F9, $86, $E6, $41, $0B, $30, $F2,
    $01, $31, $73, $7A, $32, $0E, $25, $B2,
    $12, $5D, $CA, $FB, $CD, $B6, $3C, $DB
    );

  Key2: array [ $0 .. $20 - 1 ] of Byte = (
    $27, $1C, $36, $A7, $22, $3E, $6D, $CC,
    $7F, $3C, $BE, $50, $7A, $F0, $00, $91,
    $4F, $A1, $6A, $BB, $03, $AB, $A4, $9A,
    $E7, $F4, $71, $9B, $9E, $E4, $B3, $B7
    );

procedure IndexDecode(Buf: TMemoryStream);
var
  s     : Int64;
  rawkey: array [ $0 .. $20 - 1 ] of Byte;
  i     : Integer;
  xL, xR: LongWord;
begin
  for i         := 0 to $20 - 1 do
    rawkey[ i ] := not Key2[ i ] + 1;
  BlowFish_Init(@rawkey[ 0 ], $20);
  while Buf.Position < Buf.Size do
  begin
    Buf.Read(xL, 4);
    Buf.Read(xR, 4);
    s  := xL;
    s  := (s shl $20) or xR;
    s  := BlowFish_Decode(s);
    xL := s shr $20;
    xR := s mod $100000000;
    Buf.Seek(-8, soFromCurrent);
    Buf.Write(xL, 4);
    Buf.Write(xR, 4);
  end;
end;

Type
  Pack_Head = Packed Record
    indexs_Length: Cardinal;
  End;

  Pack_Entries = packed Record
    filename: AnsiString;
    start_offset: Cardinal;
    Unknow: Cardinal; // 0
    length: Cardinal;
    org_length: Cardinal;
    padded_length: Cardinal;
    flag: Cardinal;
  End;

var
  b, filebuffer: TMemoryStream;

var
  head      : Pack_Head;
  indexs    : Pack_Entries;
  i         : Integer;
  indexs_raw: TMemoryStream;
  index     : Cardinal;

begin
  try
    filebuffer := TMemoryStream.Create;
    b          := TMemoryStream.Create;
    indexs_raw := TMemoryStream.Create;
    filebuffer.LoadFromFile
      ('E:\Downloads\[050325][minori]ANGEL_TYPE\ANGEL TYPE\SCR.PAZ');
    filebuffer.Seek($63C, soFromBeginning);;
    indexs_raw.CopyFrom(filebuffer, $910);
    indexs_raw.Seek(0, soFromBeginning);
    IndexDecode(indexs_raw);
    indexs_raw.Seek(0, soFromBeginning);
    indexs_raw.SaveToFile('2');
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

end.
