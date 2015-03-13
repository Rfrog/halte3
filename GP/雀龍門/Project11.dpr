program Project11;

{$APPTYPE CONSOLE}

{$R *.res}


uses
  System.SysUtils,
  System.Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  System.Types,
  System.IOUtils,
  Winapi.Windows;

Type
  Pack_Head = Packed Record
    Magic: ARRAY [ 0 .. 3 ] OF ANSICHAR;
    version: Cardinal;
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

procedure Extract;
var
  Head: Pack_Head;
  indexs: array of Pack_Entries;
  Compress: TGlCompressBuffer;
  FB: tfilestream;
  i: Integer;
  tmp: string;
begin
  FB := tfilestream.Create
    ('C:\Users\SakuraTomo\PlayNC\JanRyuMon\data\scripts.rom', fmOpenRead);
  Compress := TGlCompressBuffer.Create;
  FB.Read(Head.Magic[ 0 ], SizeOf(Pack_Head));
  if Head.encode_flag = 1 then
  begin
    FB.Seek(Head.entries_offset, soFromBeginning);
    Compress.CopyFrom(FB, Head.entries_length);
    Compress.Seek(0, soFromBeginning);
    Compress.ZlibDecompress(Head.entries_count * SizeOf(Pack_Entries));
    SetLength(indexs, Head.entries_count);
    Compress.Output.Seek(0, soFromBeginning);
    Compress.Output.Read(indexs[ 0 ].filename[ 1 ], Compress.Output.Size);
    for i := 0 to Head.entries_count - 1 do
    begin
      Writeln(FormatDateTime('yyyy/mmm/dd hh:nn:ss',
        indexs[ i ].Time_Sig));
      FB.Seek(indexs[ i ].start_offset, soFromBeginning);
      Compress.Clear;
      Compress.CopyFrom(FB, indexs[ i ].length);
      Compress.Seek(0, soFromBeginning);
      if indexs[ i ].KeyLen = 1 then
      begin
        Decode(Compress, Compress.Output, indexs[ i ].Key);
        Compress.Seek(0, soFromBeginning);
        Compress.Output.Seek(0, soFromBeginning);
        Compress.CopyFrom(Compress.Output, Compress.Output.Size);
        Compress.Output.Clear;
      end;
      Compress.ZlibDecompress(indexs[ i ].decompress_length);
      tmp := ExtractFilePath(GetCurrentDir + '\' +
        StringReplace(Trim(indexs[ i ].filename), '/',
        '\',
        [ rfReplaceAll ]));
      ForceDirectories
        (tmp);
      Compress.Output.SaveToFile(StringReplace(Trim(indexs[ i ].filename),
        '/', '\', [ rfReplaceAll ]));
    end;
  end;
  readln;
  FB.Free;
  Compress.Free;
end;

const
  path = 'E:\程序\Halte3\Debug\GP\雀龍門\Win32\Debug\scripts\';

procedure Pack;
var
  Head: Pack_Head;
  indexs: Pack_Entries;
  Compress, fb2: TGlCompressBuffer;
  FB: TMemoryStream;
  i: Integer;
  tmp: string;

  _List: TStringDynArray;
begin
  _List := TDirectory.GetFiles(path,
    '*.*', TSearchoption.soAllDirectories);
  FB := TMemoryStream.Create;
  fb2 := TGlCompressBuffer.Create;
  Compress := TGlCompressBuffer.Create;
  FB.Write(Head.Magic[ 0 ], SizeOf(Pack_Head));
  Head.Magic := 'RES1';
  for i := Low(_List) to High(_List) do
  begin
    Compress.Clear;
    Compress.LoadFromFile(_List[ i ]);
    Compress.Seek(0, soFromBeginning);
    Compress.ZlibCompress;
    ZeroMemory(@indexs.filename[ 1 ], SizeOf(Pack_Entries));
    tmp := Copy(_List[ i ], length(path) + 1, length(_List[ i ]) -
      length(path));
    tmp := StringReplace(tmp, '\', '/', [ rfReplaceAll ]);
    MoveChars(PByte(tmp)^, indexs.filename[ 1 ], length(tmp));
    indexs.start_offset := FB.Position;
    indexs.length := Compress.Output.Size;
    indexs.decompress_length := Compress.Size;
    indexs.Time_Sig := Now;
    indexs.KeyLen := 1;
    indexs.Key := Random(High(Integer));
    Compress.Seek(0, soFromBeginning);
    Compress.Size := 0;
    Compress.Output.Seek(0, soFromBeginning);
    Decode(Compress.Output, Compress, indexs.Key);
    Compress.Seek(0, soFromBeginning);
    FB.CopyFrom(Compress, Compress.Size);
    fb2.Write(indexs.filename[ 1 ], SizeOf(Pack_Entries));
  end;
  fb2.Seek(0, soFromBeginning);
  fb2.ZlibCompress;
  fb2.Output.Seek(0, soFromBeginning);
  Head.version := 5;
  Head.encode_flag := 1;
  Head.entries_offset := FB.Position;
  Head.entries_length := fb2.Output.Size;
  Head.entries_count := High(_List) - Low(_List) + 1;
  FB.CopyFrom(fb2.Output, fb2.Output.Size);
  FB.Seek(0, soFromBeginning);
  FB.Write(Head.Magic[ 0 ], SizeOf(Pack_Head));
  FB.SaveToFile('C:\Users\SakuraTomo\PlayNC\JanRyuMon\data\scripts.rom');
  FB.Free;
  fb2.Free;
  Compress.Free;
end;

begin
  try
    Pack;
    Extract;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

end.
