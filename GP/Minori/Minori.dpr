library Minori;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  Windows,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas',
  StrUtils,
  BlowFish in 'BlowFish.pas',
  Vcl.Dialogs;

{$E GP}
{$R *.res}


Type
  Pack_Head = Packed Record
    indexs_Length: Cardinal;
  End;

  Pack_Entries = packed Record
    filename: AnsiString;
    start_offset: Cardinal;
    unknow: Cardinal;
    decompressed_length: Cardinal;
    org_length: Cardinal;
    padded_length: Cardinal;
    flag: Word;
    reserved: Word;
  End;

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Read(head.indexs_Length, SizeOf(Pack_Head));
    if head.indexs_Length < FileBuffer.Size then
    begin
      Result := dsUnknown;
      Exit;
    end;
  except
    Result := dsError;
  end;
end;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('Minori',
    clGameMaker));
end;

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
  Key3: array [ $0 .. $20 - 1 ] of Byte = (
    $DC, $58, $83, $A7, $B8, $BE, $FD, $63,
    $89, $CF, $9A, $07, $66, $25, $EE, $B0,
    $7A, $CB, $31, $BC, $8F, $A5, $F1, $BA,
    $5A, $85, $F2, $C3, $59, $88, $FC, $17
    );
  Key4: array [ $0 .. $20 - 1 ] of Byte = (
    $CE, $DB, $08, $AC, $C5, $D7, $37, $4D,
    $7B, $65, $0C, $B6, $7D, $E7, $3A, $29,
    $DA, $AB, $6A, $00, $8C, $AD, $E6, $9F,
    $9D, $2A, $E6, $95, $C8, $BF, $33, $A7
    );

  Key5: array [ $0 .. $20 - 1 ] of Byte = (
    $8B, $71, $06, $F7, $84, $65, $26, $CC,
    $E3, $43, $FF, $D8, $31, $4A, $33, $0F,
    $12, $1E, $29, $3E, $0A, $74, $06, $32,
    $0D, $5F, $C7, $57, $9E, $F3, $51, $99

    );

  Key6: array [ $0 .. $20 - 1 ] of Byte = (
    $51, $B4, $92, $0A, $F1, $C0, $78, $DB,
    $26, $AA, $AC, $C5, $C1, $08, $4A, $D8,
    $6B, $60, $55, $5F, $49, $28, $A5, $14,
    $65, $9C, $74, $7F, $8F, $1E, $41, $42
    );

var
  file_type: Integer = 1;

procedure InitKeyTable(var rawkey: array of Byte;
  i_f: Integer = 1);
var
  i: Integer;
begin
  case file_type of
    1:
      begin
        case i_f of
          1:
            begin
              for i         := 0 to $20 - 1 do
                rawkey[ i ] := not Key1[ i ] + 1;
            end;
          2:
            begin
              for i         := 0 to $20 - 1 do
                rawkey[ i ] := not Key2[ i ] + 1;
            end;
        end;
      end;
    2:
      case i_f of
        1:
          begin
            for i         := 0 to $20 - 1 do
              rawkey[ i ] := not Key3[ i ] + 1;
          end;
        2:
          begin
            for i         := 0 to $20 - 1 do
              rawkey[ i ] := not Key4[ i ] + 1;
          end;
      end;
    3:
      case i_f of
        1:
          begin
            for i         := 0 to $20 - 1 do
              rawkey[ i ] := not Key5[ i ] + 1;
          end;
        2:
          begin
            for i         := 0 to $20 - 1 do
              rawkey[ i ] := not Key6[ i ] + 1;
          end;
      end;
  end;

end;

procedure IndexDecode(Buf: TStream);
var
  s     : Int64;
  rawkey: array [ $0 .. $20 - 1 ] of Byte;
  xL, xR: LongWord;
begin
  if file_type = 0 then
  begin
    Exit;
  end;
  InitKeyTable(rawkey, 1);
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

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  head      : Pack_Head;
  indexs    : Pack_Entries;
  i         : Integer;
  Rlentry   : TRlEntry;
  indexs_raw: TMemoryStream;
  index     : Cardinal;
begin
  Result := True;
  try
    if SameText(ExtractFileName(FileBuffer.filename), 'SCR.PAZ') then
      file_type := 1
    else if SameText(ExtractFileName(FileBuffer.filename), 'SYS.PAZ') then
      file_type := 2
    else if SameText(ExtractFileName(FileBuffer.filename), 'BG.PAZ') then
      file_type := 3;
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(head.indexs_Length, SizeOf(Pack_Head));
    indexs_raw := TMemoryStream.Create;
    indexs_raw.CopyFrom(FileBuffer, head.indexs_Length);
    indexs_raw.Seek(0, soFromBeginning);
    IndexDecode(indexs_raw);
    indexs_raw.Seek(0, soFromBeginning);
    indexs_raw.Read(index, 4);
    for i := 0 to index - 1 do
    begin
      Rlentry       := TRlEntry.Create;
      Rlentry.AName :=
        Trim(PAnsiChar(@PByte(indexs_raw.Memory)[ indexs_raw.Position ]));
      indexs_raw.Seek(length(Rlentry.AName) + 1, soFromCurrent);
      indexs_raw.Read(indexs.start_offset, 24);
      Rlentry.AOffset      := indexs.start_offset;
      Rlentry.AOrigin      := soFromBeginning;
      Rlentry.AStoreLength := indexs.padded_length;
      Rlentry.ARLength     := indexs.decompressed_length;
      Rlentry.AKey         := indexs.org_length;
      Rlentry.AKey2        := indexs.flag;
      IndexStream.ADD(Rlentry);
    end;
    indexs_raw.Free;
  except
    Result := False;
  end;
end;

procedure Decode(Input, Output: TStream);
var
  s     : Int64;
  rawkey: array [ $0 .. $20 - 1 ] of Byte;
  xL, xR: LongWord;
begin
  if file_type = 0 then
  begin
    Output.CopyFrom(Input, Input.Size);
    Exit;
  end;
  InitKeyTable(rawkey, 2);
  BlowFish_Init(@rawkey[ 0 ], $20);
  while Input.Position < Input.Size do
  begin
    Input.Read(xL, 4);
    Input.Read(xR, 4);
    s  := xL;
    s  := (s shl $20) or xR;
    s  := BlowFish_Decode(s);
    xL := s shr $20;
    xR := s mod $100000000;
    Output.Write(xL, 4);
    Output.Write(xR, 4);
  end;
end;

function ReadData(FileBuffer: TFileBufferStream;
  OutBuffer: TStream): LongInt;
var
  Buffer: TGlCompressBuffer;
begin
  Buffer := TGlCompressBuffer.Create;
  try
    FileBuffer.ReadData(Buffer);
    Buffer.Seek(0, soFromBeginning);
    Decode(Buffer, Buffer.Output);
    Buffer.Output.Seek(0, soFromBeginning);
    if FileBuffer.PrevEntry.AKey2 = 1 then
    begin
      Buffer.Seek(0, soFromBeginning);
      Buffer.CopyFrom(Buffer.Output, FileBuffer.PrevEntry.AKey);
      Buffer.ZlibDecompress(FileBuffer.PrevEntry.ARLength);
      Buffer.Output.Seek(0, soFromBeginning);
    end;
    OutBuffer.CopyFrom(Buffer.Output, Buffer.Output.Size);
  finally
    Buffer.Free;
  end;
end;

procedure IndexEncode(Buf: TStream);
var
  s     : Int64;
  rawkey: array [ $0 .. $20 - 1 ] of Byte;
  xL, xR: LongWord;
begin
  if file_type = 0 then
  begin
    Exit;
  end;
  InitKeyTable(rawkey, 1);
  BlowFish_Init(@rawkey[ 0 ], $20);
  while Buf.Position < Buf.Size do
  begin
    Buf.Read(xL, 4);
    Buf.Read(xR, 4);
    s  := xL;
    s  := (s shl $20) or xR;
    s  := BlowFish_Encode(s);
    xL := s shr $20;
    xR := s mod $100000000;
    Buf.Seek(-8, soFromCurrent);
    Buf.Write(xL, 4);
    Buf.Write(xR, 4);
  end;
end;

procedure Encode(Input, Output: TStream);
var
  s     : Int64;
  rawkey: array [ $0 .. $20 - 1 ] of Byte;
  xL, xR: LongWord;
begin
  if file_type = 0 then
  begin
    Output.CopyFrom(Input, Input.Size);
    Exit;
  end;
  InitKeyTable(rawkey, 2);
  BlowFish_Init(@rawkey[ 0 ], $20);
  while Input.Position < Input.Size do
  begin
    Input.Read(xL, 4);
    Input.Read(xR, 4);
    s  := xL;
    s  := (s shl $20) or xR;
    s  := BlowFish_Encode(s);
    xL := s shr $20;
    xR := s mod $100000000;
    Output.Write(xL, 4);
    Output.Write(xR, 4);
  end;
end;

var
  sel: Boolean = False;

function PackProcessData(Rlentry: TRlEntry;
  InputBuffer, FileOutBuffer: TStream): Boolean;
var
  Compr : TGlCompressBuffer;
  Buffer: TMemoryStream;
  i     : Integer;
  z     : Byte;
  s2    : Integer;
begin
  if not sel then
  begin
    file_type := StrToIntDef(inputbox('Need filetype',
      '0 - nothing 1-scr 2-sys 3 - bg', '1'), 0);
    sel := True;
  end;

  Compr  := TGlCompressBuffer.Create;
  Buffer := TMemoryStream.Create;
  try
    InputBuffer.Seek(0, soFromBeginning);
    Compr.CopyFrom(InputBuffer, InputBuffer.Size);
    Compr.Seek(0, soFromBeginning);
    Compr.ZlibCompress(clMax);
    with Rlentry do
    begin
      Rlentry.ARLength := Compr.Size;
      Rlentry.AOffset  := FileOutBuffer.Position;
      Rlentry.AOrigin  := soFromBeginning;
      Rlentry.ARLength := Compr.Size;
      Rlentry.AKey     := Compr.Output.Size;
      Rlentry.AKey2    := 1;
    end;
    z := 0;
    Compr.Output.Seek(0, soFromEnd);
    s2    := (8 - (Compr.Output.Size mod 8)) - 1;
    for i := 0 to s2 do
    begin
      Compr.Output.Write(z, 1);
    end;
    Rlentry.AStoreLength := Compr.Output.Size;
    Compr.Output.Seek(0, soFromBeginning);
    Buffer.Clear;
    Encode(Compr.Output, Buffer);
    Buffer.Seek(0, soFromBeginning);
    FileOutBuffer.CopyFrom(Buffer, Buffer.Size);
  finally
    Compr.Free;
    Buffer.Clear;
  end;
end;

function PackProcessIndex(IndexStream: TIndexStream;
  IndexOutBuffer: TStream): Boolean;
var
  indexs: TMemoryStream;
  i     : Integer;
  tmp   : Cardinal;
  z     : Byte;
begin
  z      := 0;
  indexs := TMemoryStream.Create;
  tmp    := IndexStream.Count;
  indexs.Write(tmp, 4);
  for i := 0 to IndexStream.Count - 1 do
  begin
    indexs.Write(PByte(AnsiString(IndexStream.Rlentry[ i ].AName))^,
      length(IndexStream.Rlentry[ i ].AName));
    indexs.Write(z, 1);
    tmp := IndexStream.Rlentry[ i ].AOffset;
    indexs.Write(tmp, 4);
    tmp := 0;
    indexs.Write(tmp, 4);
    tmp := IndexStream.Rlentry[ i ].ARLength;
    indexs.Write(tmp, 4);
    tmp := IndexStream.Rlentry[ i ].AKey;
    indexs.Write(tmp, 4);
    tmp := IndexStream.Rlentry[ i ].AStoreLength;
    indexs.Write(tmp, 4);
    z := 1;
    indexs.Write(z, 1);
    z := 0;
    indexs.Write(z, 1);
    indexs.Write(z, 1);
    indexs.Write(z, 1);
  end;
  IndexEncode(indexs);
  tmp := IndexStream.Count;
  IndexOutBuffer.Write(tmp, 4);
  for i := 0 to IndexStream.Count - 1 do
  begin
    IndexOutBuffer.Write(PByte(AnsiString(IndexStream.Rlentry[ i ].AName))^,
      length(IndexStream.Rlentry[ i ].AName));
    IndexOutBuffer.Write(z, 1);
    tmp := IndexStream.Rlentry[ i ].AOffset + indexs.Size + 4;
    IndexOutBuffer.Write(tmp, 4);
    tmp := 0;
    IndexOutBuffer.Write(tmp, 4);
    tmp := IndexStream.Rlentry[ i ].ARLength;
    IndexOutBuffer.Write(tmp, 4);
    tmp := IndexStream.Rlentry[ i ].AKey;
    IndexOutBuffer.Write(tmp, 4);
    tmp := IndexStream.Rlentry[ i ].AStoreLength;
    IndexOutBuffer.Write(tmp, 4);
    z := 1;
    IndexOutBuffer.Write(z, 1);
    z := 0;
    IndexOutBuffer.Write(z, 1);
    z := 0;
    IndexOutBuffer.Write(z, 1);
    z := 0;
    IndexOutBuffer.Write(z, 1);
  end;
  IndexOutBuffer.Seek(0, soFromBeginning);
  IndexEncode(IndexOutBuffer);
  IndexOutBuffer.Seek(0, soFromBeginning);
end;

function MakePackage(IndexStream: TIndexStream;
  IndexOutBuffer, FileOutBuffer: TStream;
  Package: TFileBufferStream): Boolean;
var
  head: Pack_Head;
begin
  head.indexs_Length := IndexOutBuffer.Size;
Package.Write(head.indexs_Length, SizeOf(Pack_Head));
IndexOutBuffer.Seek(0, soFromBeginning);
Package.CopyFrom(IndexOutBuffer, IndexOutBuffer.Size);
FileOutBuffer.Seek(0, soFromBeginning);
Package.CopyFrom(FileOutBuffer, FileOutBuffer.Size);
end;

exports
  AutoDetect;

exports
  GetPluginName;

exports
  GenerateEntries;

exports
  ReadData;

exports
  PackProcessData;

exports
  PackProcessIndex;

exports
  MakePackage;

begin

end.
