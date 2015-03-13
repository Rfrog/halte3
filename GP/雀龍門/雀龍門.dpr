library êùó¥ñÂ;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  StrUtils,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas',
  CRC in 'CRC.pas';

{$E gp}
{$R *.res}


Type
  Pack_Head = Packed Record
    Magic: ARRAY [ 0 .. 3 ] OF ANSICHAR;
    version: Cardinal; // this means how many hash,05 - 4,04- 3
    encode_flag: Cardinal;
    entries_offset: Cardinal;
    entries_length: Cardinal;
    entries_count: Cardinal;
  End;

  Pack_Entries = packed Record
    filename: array [ 1 .. $100 ] of Char;
    start_offset: Cardinal;
    length: Cardinal;
    decompress_length: Cardinal;
    Time_Sig: TDateTime;
    KeyLen: Cardinal;
    Key: Cardinal;
  End;

const
  Magic = 'RES1';

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[ 0 ], sizeof(Pack_Head));
    if SameText(Trim(Head.Magic), Magic) and
      (Head.encode_flag in [ 0 .. 1 ]) and
      (Head.version in [ 0 .. 5 ]) and
      ((Head.entries_offset + Head.entries_length) <=
      FileBuffer.Size) then
    begin
      Result := dsTrue;
    end;
  except
    Result := dsError;
  end;
end;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName('êùó¥ñÂ', clgamename));
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  Head: Pack_Head;
  indexs: array of Pack_Entries;
  Compress: TGlCompressBuffer;
  i: Integer;
  Rlentry: TRlEntry;
begin
  Result := True;
  try
    Compress := TGlCompressBuffer.Create;
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.Magic[ 0 ], sizeof(Pack_Head));
    SetLength(indexs, Head.entries_count);
    FileBuffer.Seek(Head.entries_offset, soFromBeginning);
    Compress.Seek(0, soFromBeginning);
    Compress.CopyFrom(FileBuffer, Head.entries_length);
    Compress.Seek(0, soFromBeginning);
    Compress.ZlibDecompress(Head.entries_count *
      sizeof(Pack_Entries));
    Compress.Output.Seek(0, soFromBeginning);
    Compress.Output.Read(indexs[ 0 ].filename[ 1 ],
      Head.entries_count * sizeof(Pack_Entries));
    Compress.Destroy;
    for i := 0 to Head.entries_count - 1 do
    begin
      Rlentry := TRlEntry.Create;
      Rlentry.AName := Trim(indexs[ i ].filename);
      Rlentry.AName := ReplaceText(Rlentry.AName,
        '/', '\');
      Rlentry.AOffset := indexs[ i ].start_offset;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs[ i ].length;
      Rlentry.ARLength := indexs[ i ].decompress_length;
      Rlentry.AKey := indexs[ i ].KeyLen;
      Rlentry.AKey2 := indexs[ i ].Key;
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

procedure Decode(Input, Output: TStream; Key: Cardinal);
var
  mKey: PByte;
  c: Byte;
  i: Integer;
begin
  mKey := @Key;
  while Input.Position < Input.Size do
  begin
    Input.Read(c, 1);
    for i := 0 to 3 do
      c := c xor mKey[ (i mod 4) ];
    Output.Write(c, 1);
  end;
end;

function ReadData(FileBuffer: TFileBufferStream;
  OutBuffer: TStream): LongInt;
var
  Key, flag, decompr: Cardinal;
  Buffer: TGlCompressBuffer;
begin
  Key := FileBuffer.Rlentry.AKey2;
  flag := FileBuffer.Rlentry.AKey;
  decompr := FileBuffer.Rlentry.ARLength;
  Buffer := TGlCompressBuffer.Create;
  Result := FileBuffer.ReadData(Buffer);
  Buffer.Seek(0, soFromBeginning);
  if flag = 1 then
    Decode(Buffer, OutBuffer, Key)
  else
    OutBuffer.CopyFrom(Buffer, Buffer.Size);
  OutBuffer.Seek(0, soFromBeginning);
  Buffer.Seek(0, soFromBeginning);
  Buffer.Clear;
  Buffer.CopyFrom(OutBuffer, OutBuffer.Size);
  Buffer.Seek(0, soFromBeginning);
  if decompr <> Buffer.Size then
    Buffer.ZlibDecompress(decompr)
  else
    Buffer.Output.CopyFrom(Buffer, Buffer.Size);
  Buffer.Output.Seek(0, soFromBeginning);
  OutBuffer.Size := 0;
  OutBuffer.CopyFrom(Buffer.Output, Buffer.Output.Size);
  Buffer.Free;
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

begin

end.
