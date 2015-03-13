library BGI;

uses
  FastMM4 in '..\..\..\FastMM\FastMM4.pas',
  SysUtils,
  Classes,
  CustomStream in '..\..\..\core\CustomStream.pas',
  PluginFunc in '..\..\..\core\PluginFunc.pas',
  Windows,
  FastMM4Messages in '..\..\..\FastMM\FastMM4Messages.pas';
{$E GP}
{$R *.res}

Type
  Pack_Head = Packed Record
    magic: array [0 .. 11] of AnsiChar;
    indexs: Cardinal;
  End;

  Pack_Entries = packed Record
    filename: array [1 .. 16] of AnsiChar;
    start_offset: Cardinal;
    length: Cardinal;
    reserved: Cardinal;
    reserved1: Cardinal;
  End;

  TBGI_DSCHeader = packed record
    magic: array [1 .. $10] of AnsiChar;
    HelpNumber: Cardinal;
    DecryptedSize: Cardinal;
    PassCount: Cardinal;
    Dummy: Cardinal;
  end;

  TBGI_CBGHeader = packed record
    magic: array [1 .. $10] of AnsiChar;
    Width: word;
    Height: word;
    BPP: Cardinal;
    Dummy1: Cardinal;
    Dummy2: Cardinal;
    ZLen: Cardinal;
    Key: Cardinal;
    ELen: Cardinal;
    SCSum: byte;
    XCSum: byte;
    Dummy3: word;
  end;

  TBGI_HuffmanTreeNode = record
    Val: boolean;
    Fr: Cardinal;
    Left: Cardinal;
    Right: Cardinal;
  end;

  TBMP = packed record
    BMPHeader: array [1 .. 2] of AnsiChar; // 'BM'
    FileSize: longword; // File size. Long word (4 bytes)
    Dummy_0: longword; // Dummy
    ImgOffset: longword;
    // Image data offset (EXCLUDING PALETTE SIZE!)
    HeaderSize: longword; // Info header size (normally 40)
    Width: longword; // Image Width
    Height: longword; // Image Height
    XYZ: word; // Number of XYZ planes (always 1)
    Bitdepth: word; // Bits per pixel
    CompType: longword;
    // Data compression type (0,3 - no, 1 - 8-bit RLE, 2 - 4-bit RLE)
    StreamSize: longword;
    // Bitmap stream size (excluding header)
    Hres: longword;
    // Horisontal pixels per meter resolution (ignore)
    Vres: longword;
    // Vertical pixels per meter resolution (ignore)
    UsedColors: longword;
    // Count of used colors. Equals 2^Bitdepth. (could be ignored)
    NeedColors: longword;
    // Count of significant colors. Equals UsedColors. :) (could be ignored)
  end;

function GetScanlineLen2(Width, Bitdepth: integer): integer;
begin
  Result := (Width * Bitdepth) div 8;
end;

procedure VerticalFlipIO(InputStream, OutputStream: TStream;
  ScanlineLen, Height: integer);
var
  i: integer;
begin
  for i := Height - 1 downto 0 do
  begin
    InputStream.Seek(i * ScanlineLen, soBeginning);
    OutputStream.CopyFrom(InputStream, ScanlineLen);
  end;
end;

procedure VerticalFlip(InputStream: TStream;
  ScanlineLen, Height: integer);
var
  tmpStream: TStream;
begin
  tmpStream := TMemoryStream.Create;
  VerticalFlipIO(InputStream, tmpStream, ScanlineLen, Height);
  InputStream.Size := 0;
  tmpStream.Seek(0, soBeginning);
  InputStream.CopyFrom(tmpStream, tmpStream.Size);
  FreeAndNil(tmpStream);
end;

function CountNumber(var STNum: Cardinal): Cardinal;
var
  HNum, work, work2, work3: Cardinal;
begin
  work := 20021 * (STNum and $FFFF);
  HNum := (((STNum and $FFFF0000) shr 16) or $44530000) * 20021;
  work2 := STNum * 346 + HNum;
  work2 := work2 + (work shr 16);
  work := work and $FFFF;
  work3 := work2 and $FFFF;
  Result := work2 and $7FFF;
  work3 := work3 shl 16;
  STNum := work + work3 + 1;
end;

function DecodeDSC(InputStream, OutputStream: TStream): boolean;
var
  Header: TBGI_DSCHeader;
  STNum, Counted, cnt, cnt2, dcnt2, cnt3, cnta1, i, worknum,
    worknum2, cnta2, w10, w11, sav, wcnt1, wcnt2, wword, condit,
    scnta2, count16, wc, bufc, ecnt, bufc2, n2, incnt, passcnt,
    dbufc1, j, coucbyte, w9, outpos, cntout: Cardinal;
  Si12, Si34, w17, w18: integer;
  BufArr: array [0 .. $FFB] of Cardinal;
  Arr1: array [0 .. 512] of Cardinal;
  Arr2: array [0 .. 1023] of Cardinal;
  INBuf: array of byte;
  wbyte, stbyte, cbyte, cbyte2, cbyte3, rb: byte;
  word16: word;
begin
  Result := false;
  InputStream.Read(Header, sizeof(Header));
  if Header.magic <> 'DSC FORMAT 1.00'#0 then
    Exit;
  FillChar(BufArr[0], $3FF0, 0);
  SetLength(INBuf, InputStream.Size - sizeof(Header));
  InputStream.Read(INBuf[0], InputStream.Size - sizeof(Header));

  FillChar(Arr1[0], 513 * 4, 0);
  FillChar(Arr2[0], 1024 * 4, 0);
  STNum := Header.HelpNumber;
  cnt := 0;
  cnt2 := 0;
  while cnt < 512 do
  begin
    Counted := CountNumber(STNum);
    wbyte := byte(Counted and $FF);
    wbyte := INBuf[cnt] - wbyte;
    if wbyte <> 0 then
    begin
      Arr1[cnt2] := cnt + (wbyte shl 16);
      Inc(cnt2);
    end;
    Inc(cnt);
  end;
  dcnt2 := cnt2;

  if (cnt2 - 1) > 0 then
  begin
    cnta1 := 0;
    cnt3 := 1;
    while (cnt3 - 1) < (cnt2 - 1) do
    begin
      for i := cnt3 to cnt2 - 1 do
      begin
        worknum := Arr1[cnta1];
        worknum2 := Arr1[i];
        if worknum2 < worknum then
        begin
          Arr1[cnta1] := worknum2;
          Arr1[i] := worknum;
        end;
      end;
      Inc(cnta1);
      Inc(cnt3);
    end;
  end;

  Si12 := 1;
  Si34 := 1;
  w10 := 0;
  w11 := 0;
  ecnt := 0;
  condit := 0;

  if cnt2 > 0 then
  begin
    cnta2 := 0;
    while true do
    begin
      worknum := w10 xor $200;
      sav := worknum;
      wcnt1 := w11;
      wcnt2 := worknum;
      wword := (Arr1[wcnt1] shr 16) and $FFFF;
      scnta2 := wcnt2;
      count16 := 0;
      while condit = wword do
      begin
        bufc := 4 * Arr2[cnta2];
        wc := Arr1[wcnt1] and $1FF;
        Inc(cnta2);
        BufArr[bufc] := 0;
        BufArr[bufc + 1] := wc;
        Inc(count16);
        Inc(wcnt1);
        Inc(ecnt);
        wword := (Arr1[wcnt1] shr 16) and $FFFF;
      end;
      w17 := Si34 - count16;
      w18 := 2 * w17;
      if count16 < Si34 then
      begin
        Si34 := w17;
        while Si34 <> 0 do
        begin
          bufc2 := 4 * Arr2[cnta2];
          Inc(cnta2);
          n2 := 2;
          BufArr[bufc2] := 1;
          Inc(bufc2, 2);
          while n2 > 0 do
          begin
            Arr2[wcnt2] := Si12;
            BufArr[bufc2] := Si12;
            Inc(wcnt2);
            Inc(bufc2);
            Inc(Si12);
            Dec(n2);
          end;
          Dec(Si34);
        end;
      end;
      w11 := ecnt;
      Si34 := w18;
      Inc(condit);
      if ecnt >= dcnt2 then
        Break;
      w10 := sav;
      cnta2 := scnta2;
    end;
  end;

  incnt := $200;
  cbyte := 0;
  passcnt := 0;

  while passcnt < Header.PassCount do
  begin
    dbufc1 := 0;
    repeat
      if cbyte = 0 then
      begin
        cbyte := 8;
        cbyte2 := INBuf[incnt];
        Inc(incnt);
      end;
      Dec(cbyte);
      dbufc1 := BufArr[2 + (byte(cbyte2 shr 7) + dbufc1 * 4)];
      cbyte2 := cbyte2 * 2;
    until BufArr[dbufc1 * 4] = 0;
    word16 := word(BufArr[dbufc1 * 4 + 1]);
    if (word16 and $100) <> 0 then
    begin
      w9 := cbyte2 shr (8 - cbyte);
      cbyte3 := cbyte;
      if cbyte < 12 then
      begin
        j := ((11 - cbyte) shr 3) + 1;
        coucbyte := cbyte + 8 * j;
        while j <> 0 do
        begin
          w9 := INBuf[incnt] + (w9 shl 8);
          Inc(incnt);
          Dec(j);
        end;
      end;
      cbyte := coucbyte - 12;
      cbyte2 := byte(byte(w9) shl (8 - cbyte));
      outpos := OutputStream.Position - 2 - (w9 shr cbyte);
      cntout := (word16 and $FF) + 2;
      while cntout > 0 do
      begin
        OutputStream.Position := outpos;
        OutputStream.Read(rb, 1);
        OutputStream.Position := OutputStream.Size;
        OutputStream.Write(rb, 1);
        Inc(outpos);
        Dec(cntout);
      end;
    end
    else
    begin
      OutputStream.Write(word16, 1);
    end;
    Inc(passcnt);
  end;
  SetLength(INBuf, 0);
  Result := true;
end;

function CountNumber2(var STNum: Cardinal): Cardinal;
var
  work, work2, work3: Cardinal;
begin
  work := 20021 * (STNum and $FFFF);
  work2 := 20021 * (STNum shr $10);
  work3 := 346 * STNum + work2 + (work shr $10);
  STNum := (work3 shl $10) + (work and $FFFF) + 1;
  Result := work3 and $7FFF;
end;

function CountData(Stream: TStream): Cardinal;
var
  cur: byte;
  shift: Cardinal;
begin
  cur := $FF;
  shift := 0;
  Result := 0;
  while (cur and $80) <> 0 do
  begin
    Stream.Read(cur, 1);
    Result := Result or ((cur and $7F) shl shift);
    shift := shift + 7;
  end;
end;

function DecodeCBG(InputStream, OutputStream: TStream): boolean;
var
  Header: TBGI_CBGHeader;
  INBuf: array of byte;
  i, j, HuffKeyNum, FTotal, nodes, min, frec, root, mask, node,
    len, line, x, y, pos: Cardinal;
  Fr: array [0 .. 255] of Cardinal;
  HummfArr, DummyArr: array of byte;
  workb, workb2, zero, colors: byte;
  NodesArr: array [0 .. 510] of TBGI_HuffmanTreeNode;
  ch: array [0 .. 1] of Cardinal;
  HuffmStream, tmpStream: TStream;
  BMPHdr: TBMP;
begin
  Result := false;
  InputStream.Position := 0;
  InputStream.Read(Header, sizeof(Header));
  if Header.magic <> 'CompressedBG___'#0 then
    Exit;
  tmpStream := TMemoryStream.Create;
  tmpStream.Size := Header.Width * Header.Height *
    (Header.BPP shr 3);
  tmpStream.Position := 0;
  HuffKeyNum := Header.Key;
  for i := 1 to Header.ELen do
  begin
    workb := byte(CountNumber2(HuffKeyNum) and $FF);
    InputStream.Read(workb2, 1);
    workb2 := workb2 - workb;
    InputStream.Position := InputStream.Position - 1;
    InputStream.Write(workb2, 1);
  end;
  InputStream.Position := $30;
  for i := 0 to 255 do
  begin
    Fr[i] := CountData(InputStream);
  end;
  FTotal := 0;
  for i := 0 to 255 do
  begin
    NodesArr[i].Val := Fr[i] > 0;
    NodesArr[i].Fr := Fr[i];
    NodesArr[i].Left := i;
    NodesArr[i].Right := i;

    FTotal := FTotal + Fr[i];
  end;
  for i := 256 to 510 do
  begin
    NodesArr[i].Val := false;
    NodesArr[i].Fr := 0;
    NodesArr[i].Left := $FFFFFFFF;
    NodesArr[i].Right := $FFFFFFFF;
  end;

  for nodes := 256 to 510 do
  begin
    frec := 0;
    for i := 0 to 1 do
    begin
      min := $FFFFFFFF;
      ch[i] := $FFFFFFFF;
      for j := 0 to nodes - 1 do
        if NodesArr[j].Val and (NodesArr[j].Fr < min) then
        begin
          min := NodesArr[j].Fr;
          ch[i] := j;
        end;
      if ch[i] <> $FFFFFFFF then
      begin
        NodesArr[ch[i]].Val := false;
        frec := frec + NodesArr[ch[i]].Fr;
      end;
    end;
    NodesArr[nodes].Val := true;
    NodesArr[nodes].Fr := frec;
    NodesArr[nodes].Left := ch[0];
    NodesArr[nodes].Right := ch[1];
    if frec = FTotal then
      Break;
  end;

  // Dec(nodes);
  root := nodes;
  mask := $80;
  InputStream.Read(workb, 1);
  SetLength(HummfArr, Header.ZLen);
  for i := 0 to Header.ZLen - 1 do
  begin
    node := root;
    while node >= 256 do
    begin
      if (workb and mask) <> 0 then
      begin
        node := NodesArr[node].Right;
      end
      else
      begin
        node := NodesArr[node].Left;
      end;
      mask := mask shr 1;
      if mask = 0 then
      begin
        InputStream.Read(workb, 1);
        mask := $80;
      end;
    end;
    HummfArr[i] := byte(node);
  end;

  zero := 0;
  HuffmStream := TMemoryStream.Create;
  HuffmStream.Write(HummfArr[0], Header.ZLen);
  HuffmStream.Position := 0;

  while HuffmStream.Position < Header.ZLen do
  begin
    len := CountData(HuffmStream);
    if zero <> 0 then
    begin
      if len > 0 then
      begin
        SetLength(DummyArr, len);
        FillChar(DummyArr[0], len, 0);
        tmpStream.Write(DummyArr[0], len);
      end;
    end
    else
    begin
      tmpStream.CopyFrom(HuffmStream, len);
    end;
    zero := zero xor 1;
  end;

  colors := Header.BPP shr 3;
  line := Header.Width * colors;
  pos := 0;
  for y := 0 to Header.Height - 1 do
  begin
    for x := 0 to Header.Width - 1 do
    begin
      for i := 0 to colors - 1 do
      begin
        if (x = 0) and (y = 0) then
          workb := 0
        else if y = 0 then
        begin
          tmpStream.Position := pos - colors;
          tmpStream.Read(workb, 1);
        end
        else if x = 0 then
        begin
          tmpStream.Position := pos - line;
          tmpStream.Read(workb, 1);
        end
        else
        begin
          tmpStream.Position := pos - colors;
          tmpStream.Read(workb, 1);
          tmpStream.Position := pos - line;
          tmpStream.Read(workb2, 1);
          workb := (workb + workb2) shr 1
        end;
        tmpStream.Position := pos;
        tmpStream.Read(workb2, 1);
        workb := workb + workb2;
        tmpStream.Position := pos;
        tmpStream.Write(workb, 1);
        Inc(pos);
      end;
    end;
  end;

  FreeAndNil(HuffmStream);
  SetLength(DummyArr, 0);
  SetLength(HummfArr, 0);
  tmpStream.Position := 0;
  VerticalFlip(tmpStream, GetScanlineLen2(Header.Width,
    Header.BPP), Header.Height);

  with BMPHdr do
  begin
    BMPHeader := 'BM';
    FileSize := OutputStream.Size + sizeof(TBMP);
    Dummy_0 := 0;
    ImgOffset := sizeof(TBMP);
    HeaderSize := 40;
    Width := Header.Width;
    Height := Header.Height;
    XYZ := 1;
    Bitdepth := Header.BPP;
    CompType := 0;
    StreamSize := Header.Width * Header.Height *
      (Header.BPP shr 3);
    Hres := 0;
    Vres := 0;
    UsedColors := 0;
    NeedColors := 0;
  end;
  OutputStream.Write(BMPHdr, sizeof(TBMP));
  tmpStream.Position := 0;
  OutputStream.CopyFrom(tmpStream, tmpStream.Size);
  FreeAndNil(tmpStream);
  Result := true;
end;

function AutoDetect(FileBuffer: TFileBufferStream): TDetectState;
var
  Head: Pack_Head;
begin
  Result := dsFalse;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.magic[0], sizeof(Pack_Head));
    if SameText(Trim(Head.magic), Trim('PackFile    ')) then
    begin
      Result := dsTrue;
    end;
  except
    Result := dsError;
  end;
end;

function GetPluginName: PChar;
begin
  Result := PChar(FormatPluginName
    ('Ethornell Buriko General Interpreter', clEngine));
end;

function GenerateEntries(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): boolean;
var
  Head: Pack_Head;
  indexs: Pack_Entries;
  i: integer;
  Rlentry: TRlEntry;
  data_start: Cardinal;
begin
  Result := true;
  try
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Read(Head.magic[0], sizeof(Pack_Head));
    if (Head.indexs * sizeof(Pack_Entries)) >
      FileBuffer.Size then
      raise Exception.Create('OVERFLOW');
    data_start := sizeof(Pack_Head) + Head.indexs *
      sizeof(Pack_Entries);
    for i := 0 to Head.indexs - 1 do
    begin
      FileBuffer.Read(indexs.filename[1], sizeof(Pack_Entries));
      Rlentry := TRlEntry.Create;
      Rlentry.AName := Trim(indexs.filename);
      Rlentry.AOffset := indexs.start_offset + data_start;
      Rlentry.AOrigin := soFromBeginning;
      Rlentry.AStoreLength := indexs.length;
      Rlentry.ARLength := 0;
      if (Rlentry.AOffset + Rlentry.AStoreLength) >
        FileBuffer.Size then
        raise Exception.Create('OverFlow');
      IndexStream.Add(Rlentry);
    end;
  except
    Result := false;
  end;
end;

procedure Decyption();
begin
  { do nothing }
end;

function ReadData(FileBuffer: TFileBufferStream;
  OutBuffer: TStream): LongInt;
var
  magic: array [0 .. 15] of AnsiChar;
  tmpbuffer: TMemoryStream;
begin
  tmpbuffer := TMemoryStream.Create;
  Result := FileBuffer.ReadData(tmpbuffer);
  tmpbuffer.Seek(0, soFromBeginning);
  tmpbuffer.Read(magic[0], 16);
  tmpbuffer.Seek(0, soFromBeginning);
  OutBuffer.Seek(0, soFromBeginning);
  if SameText(Trim(magic), 'DSC FORMAT 1.00') then
    DecodeDSC(tmpbuffer, OutBuffer)
  else if SameText(Trim(magic), 'CompressedBG___') then
    DecodeCBG(tmpbuffer, OutBuffer)
  else
    OutBuffer.CopyFrom(tmpbuffer, tmpbuffer.Size);
  tmpbuffer.Destroy;
end;

const
  magic: AnsiString = 'PackFile    ';

function PackData(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream; var Percent: word): boolean;
var
  Head: Pack_Head;
  indexs: array of Pack_Entries;
  i: integer;
  tmpStream: TFileStream;
  tmpsize: Cardinal;
begin
  Result := true;
  try
    Percent := 0;
    tmpsize := 0;
    Head.indexs := IndexStream.Count;
    Move(pbyte(magic)^, Head.magic[0], 12);
    SetLength(indexs, Head.indexs);
    ZeroMemory(@indexs[0].filename[1],
      Head.indexs * sizeof(Pack_Entries));
    for i := 0 to Head.indexs - 1 do
    begin
      if length(IndexStream.Rlentry[i].AName) > 16 then
        raise Exception.Create('Name too long.');
      Move(pbyte(AnsiString(IndexStream.Rlentry[i].AName))^,
        indexs[i].filename[1], 16);
      indexs[i].start_offset := tmpsize;
      indexs[i].length := IndexStream.Rlentry[i].ARLength;
      tmpsize := tmpsize + indexs[i].length;
      Percent := 10 * (i + 1) div Head.indexs;
    end;
    FileBuffer.Seek(0, soFromBeginning);
    FileBuffer.Write(Head.magic[0], sizeof(Pack_Head));
    FileBuffer.Write(indexs[0].filename[1],
      Head.indexs * sizeof(Pack_Entries));
    for i := 0 to Head.indexs - 1 do
    begin
      tmpStream := TFileStream.Create(IndexStream.ParentPath +
        IndexStream.Rlentry[i].AName, fmOpenRead);
      FileBuffer.CopyFrom(tmpStream, tmpStream.Size);
      tmpStream.Free;
      Percent := 10 + 90 * (i + 1) div Head.indexs;
    end;
    SetLength(indexs, 0);
  except
    Result := false;
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
