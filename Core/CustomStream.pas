{ ******************************************************* }
{ }
{ CustomStream }
{ }
{ Copyright (C) 2010 - 2011 HatsuneTakumi }
{ }
{ HalTe3 Public License V1 }
{ }
{ ******************************************************* }

unit CustomStream;

interface

uses
  Classes,
  RTLConsts,
  ZLib;

const
  nul = -1;

type

  TZCompressionLevel = (zcNone, zcFastest, zcDefault, zcMax);
  TCompressionLevel  = (clNone = Integer(zcNone), clFastest,
    clDefault, clMax);

  { TRlEntry }
  TRlEntry = class(
    TObject)
    AName: string;
    ANameLength: Cardinal;
    AOffset: UInt64;
    AOrigin: Word;
    AStoreLength: UInt64;
    ARLength: UInt64;
    AHash: array [ 0 .. 3 ] of Cardinal;
    ADate: Cardinal;
    ATime: Cardinal;
    AKey: Cardinal;
    AKey2: Cardinal;
  public
    procedure Assign(AObject: TRlEntry);
  end;

  { TIndexStream }
  TIndexStream = class(
    TStringList)
  private
    FEntryCount: Longint;
    FParentPath: string;
    function GetRlEntry(Index: Integer): TRlEntry;
  protected
    property EntryCount: Longint
      read   FEntryCount
      write  FEntryCount;
  public
    property RlEntry[ index: Integer ]: TRlEntry
      read   GetRlEntry;
    property ParentPath: string
      read   FParentPath
      write  FParentPath;
    destructor Destroy; override;
    procedure Clear; override;
    procedure InitializeStream; overload;
    procedure InitializeStream(EntrySize: Longint); overload;
    procedure Seek(Origin: TSeekOrigin; Count: Longint);
      overload;
    function GenerateEntry: Boolean; virtual;
    procedure Add(Entry: TRlEntry); overload;
  end;

  { TFileBufferStream }
  TFileBufferStream = class(
    TFileStream)
  private
    FEntryCount : Longint;
    FIndexs     : Longint;
    FIndexStream: TIndexStream;
  protected
    property EntryCount: Longint
      read   FEntryCount
      write  FEntryCount;
    property IndexStream: TIndexStream
      read   FIndexStream
      write  FIndexStream;
    function GetRlEntry: TRlEntry;
    function GetPrevEntry: TRlEntry;
    function GetNextEntry: TRlEntry;
  public
    property EntrySelected: Longint
      read   FEntryCount
      write  FEntryCount;
    property Indexs: Longint
      read   FIndexs;
    property RlEntry: TRlEntry
      read   GetRlEntry;
    property PrevEntry: TRlEntry
      read   GetPrevEntry;
    property NextEntry: TRlEntry
      read   GetNextEntry;
    constructor Create(const AFileName: string; Mode: Word;
      IndexStream: TIndexStream); overload;
    procedure Seek(Origin: TSeekOrigin; Count: Longint);
      overload;
    function ReadData(var Buffer): Longint; overload;
    function ReadData(Buffer: TStream): Longint; overload;
    procedure Decyption(var Buffer); virtual;
    procedure SetIndexStream(Stream: TIndexStream);
    procedure free; overload;
    function Read(var Buffer; Size: int64; offset: int64)
      : int64; overload;
    function Read(Buffer: TStream; Size: int64; offset: int64)
      : int64; overload;
  end;

  { TGlCompressBuffer }
  TGlCompressBuffer = class(
    TMemoryStream)
  private
    OutputStream: TMemoryStream;
  public
    property Output: TMemoryStream
      read   OutputStream;
    constructor Create; overload;
    destructor Destroy; override;
    procedure Clear;
    procedure ZlibDecompress(DestLen: LongWord);
    procedure ZlibCompress(CompressLevel
      : TCompressionLevel = clFastest);
    procedure LzssDecompress(CryptLength, SlidWindowIndex,
      SlidWindowLength: Integer; FillBuffer: Integer = $100);
    procedure LzssCompress;
    procedure RleDecompress;
    procedure RleCompress;
    procedure MGRDecompress(Input, Output: TMemoryStream;
      Decompressed_Length: Cardinal);
    procedure RLEDecompress2(BreakFlag: byte = $FF;
      ComFlag: byte = $1);
    function LZSSDecode3(CryptLength, SlidWindowIndex,
      SlidWindowLength: Integer): Boolean;
    procedure Lz77Decompress;
    procedure Lz77Compress;
    procedure LZWDecompress(DecompressLength: Cardinal);
  end;

implementation

uses
  PluginFunc;

procedure TRlEntry.Assign(AObject: TRlEntry);
begin
  AName        := AObject.AName;
  ANameLength  := AObject.ANameLength;
  AOffset      := AObject.AOffset;
  AOrigin      := AObject.AOrigin;
  AStoreLength := AObject.AStoreLength;
  ARLength     := AObject.ARLength;
  AHash        := AObject.AHash;
  ATime        := AObject.ATime;
  ADate        := AObject.ADate;
  AKey         := AObject.AKey;
  AKey2        := AObject.AKey2;
end;

{ ==========================================================
  TIndexStream
  General Index Process Class
  HatsuneTakumi (C) 2011 All right reserved
  ========================================================== }
function TIndexStream.GenerateEntry: Boolean;
begin
  { default = do nothing
    override this function to process FRlIndex }
  Result := True;
end;

procedure TIndexStream.Add(Entry: TRlEntry);
begin
  Self.EntryCount := Self.AddObject(Entry.AName, Entry);
end;

function TIndexStream.GetRlEntry(Index: Integer): TRlEntry;
begin
  if index > Self.Count then
    raise EReadError.Create(sIndexOverflow);
  Result          := TRlEntry(Self.Objects[ index ]);
  Self.EntryCount := index;
end;

procedure TIndexStream.Seek(Origin: TSeekOrigin; Count: Longint);
begin
  case Origin of
    soBeginning:
      EntryCount := Count;
    soCurrent:
      EntryCount := EntryCount + Count;
    soEnd:
      EntryCount := Self.Count + Count;
  end;
end;

procedure TIndexStream.InitializeStream;
begin
  Clear;
end;

procedure TIndexStream.InitializeStream(EntrySize: Longint);
begin
  Clear;
end;

destructor TIndexStream.Destroy;
begin
  Clear;
  inherited Destroy;
end;

procedure TIndexStream.Clear;
var
  i: Integer;
begin
  Self.EntryCount := nul;
  for i           := 0 to Self.Count - 1 do
  begin
    (Self.Objects[ i ]).free;
    Self.Objects[ i ] := nil;
  end;
  inherited Clear;
end;

{ ==========================================================
  TFileBufferStream
  General Data Process Class
  HatsuneTakumi (C) 2011 All right reserved
  ========================================================== }
function TFileBufferStream.Read(var Buffer; Size: int64;
  offset: int64): int64;
begin
  Self.Seek(offset, soFromBeginning);
  Result := Self.Read(Buffer, Size);
end;

function TFileBufferStream.Read(Buffer: TStream; Size: int64;
  offset: int64): int64;
begin
  Self.Seek(offset, soFromBeginning);
  Result := Buffer.CopyFrom(Self, Size);
end;

function TFileBufferStream.GetRlEntry: TRlEntry;
begin
  Result := Self.FIndexStream.RlEntry[ Self.EntryCount ];
end;

function TFileBufferStream.GetPrevEntry: TRlEntry;
begin
  Result := Self.FIndexStream.RlEntry[ Self.EntryCount - 1 ];
end;

function TFileBufferStream.GetNextEntry: TRlEntry;
begin
  Result := Self.FIndexStream.RlEntry[ Self.EntryCount + 1 ];
end;

procedure TFileBufferStream.free;
{ var
  i: Integer; }
begin
  { for i := 0 to Self.Indexs - 1 do
    Self.FIndexStream.RlEntry[i].free; }
  inherited free;
end;

procedure TFileBufferStream.SetIndexStream(Stream: TIndexStream);
begin
  Self.IndexStream := Stream;
  Self.EntryCount  := 0;
  Self.FIndexs     := Stream.Count;
end;

constructor TFileBufferStream.Create(const AFileName: string;
  Mode: Word; IndexStream: TIndexStream);
begin
{$IFDEF MSWINDOWS}
  inherited Create(AFileName, Mode, 0);
{$ENDIF}
{$IFDEF POSIX}
  inherited Create(AFileName, Mode, FileAccessRights);
{$ENDIF}
  SetIndexStream(IndexStream);
end;

procedure TFileBufferStream.Seek(Origin: TSeekOrigin;
  Count: Integer);
begin
  case Origin of
    soBeginning:
      EntryCount := Count;
    soCurrent:
      EntryCount := EntryCount + Count;
    soEnd:
      EntryCount := Indexs + Count;
  end;
end;

function TFileBufferStream.ReadData(Buffer: TStream): Longint;
var
  RlSize, RlOffset: Longint;
  Origin          : Word;
begin
  if (EntryCount > Indexs) or (EntryCount < 0) then
    raise EReadError.CreateRes(@SReadError);
  RlSize := Self.FIndexStream.RlEntry[ Self.EntryCount ]
    .AStoreLength;
  RlOffset := Self.FIndexStream.RlEntry[ Self.EntryCount ].AOffset;
  Origin   := Self.FIndexStream.RlEntry[ Self.EntryCount ].AOrigin;
  if RlOffset > Self.Size then
    raise EReadError.CreateRes(@SReadError);
  if (RlSize + RlOffset) > Self.Size then
    raise EReadError.CreateRes(@SReadError);
  Self.Seek(RlOffset, Origin);
  Result := Buffer.CopyFrom(Self, RlSize);
  Decyption(Buffer);
  EntryCount := EntryCount + 1;
end;

function TFileBufferStream.ReadData(var Buffer): Longint;
var
  RlSize, RlOffset: Longint;
  Origin          : Word;
begin
  if (EntryCount > Indexs) or (EntryCount < 0) then
    raise EReadError.CreateRes(@SReadError);
  RlSize := Self.FIndexStream.RlEntry[ Self.EntryCount ]
    .AStoreLength;
  RlOffset := Self.FIndexStream.RlEntry[ Self.EntryCount ].AOffset;
  Origin   := Self.FIndexStream.RlEntry[ Self.EntryCount ].AOrigin;
  if RlOffset > Self.Size then
    raise EReadError.CreateRes(@SReadError);
  if (RlSize + RlOffset) > Self.Size then
    raise EReadError.CreateRes(@SReadError);
  Self.Seek(RlOffset, Origin);
  Result     := Self.Read(Buffer, RlSize);
  EntryCount := EntryCount + 1;
  Decyption(Buffer);
end;

procedure TFileBufferStream.Decyption(var Buffer);
begin
  { default = do nothing
    override this procedure to process buffer read through ReadData }
end;

{ ==========================================================
  TGlCompressBuffer
  General Data Compress/Decompress Class
  HatsuneTakumi (C) 2011 All right reserved
  ========================================================== }
constructor TGlCompressBuffer.Create;
begin
  inherited Create;
  OutputStream := TMemoryStream.Create;
end;

destructor TGlCompressBuffer.Destroy;
begin
  OutputStream.Destroy;
  inherited Destroy;
end;

procedure TGlCompressBuffer.Clear;
begin
  inherited Clear;
  OutputStream.Clear;
end;

procedure TGlCompressBuffer.ZlibDecompress(DestLen: LongWord);
var
  zstream  : TZStreamRec;
  SourceLen: LongWord;
begin
  FillChar(zstream, SizeOf(TZStreamRec), 0);
  SourceLen     := Self.Size;
  Self.Position := 0;
  Output.Size   := DestLen;

  zstream.zalloc := zlibAllocMem;
  zstream.zfree  := zlibFreeMem;

  zstream.next_in   := Self.Memory;
  zstream.avail_in  := SourceLen;
  zstream.next_out  := Output.Memory;
  zstream.avail_out := DestLen;
  InflateInit_(zstream, ZLIB_VERSION, SizeOf(TZStreamRec));
  try
    inflate(zstream, Z_NO_FLUSH);
  finally
    inflateEnd(zstream);
  end;
end;

procedure TGlCompressBuffer.ZlibCompress(CompressLevel
  : TCompressionLevel = clFastest);
const
  ZLevels: array [ TCompressionLevel ] of ShortInt =
    (Z_NO_COMPRESSION, Z_BEST_SPEED, Z_DEFAULT_COMPRESSION,
    Z_BEST_COMPRESSION);
var
  zstream           : TZStreamRec;
  SourceLen, DestLen: LongWord;
begin
  FillChar(zstream, SizeOf(TZStreamRec), 0);
  SourceLen := Self.Size;
  DestLen   := ((SourceLen + (SourceLen div 10) + 12) + 255)
    and not 255;
  Output.Size     := DestLen;
  Output.Position := 0;

  zstream.zalloc := zlibAllocMem;
  zstream.zfree  := zlibFreeMem;

  zstream.next_in   := Self.Memory;
  zstream.avail_in  := SourceLen;
  zstream.next_out  := Pointer(LongWord(Output.Memory));
  zstream.avail_out := DestLen;
  DeflateInit_(zstream, ZLevels[ CompressLevel ], ZLIB_VERSION,
    SizeOf(TZStreamRec));
  try
    deflate(zstream, Z_FINISH);
  finally
    deflateEnd(zstream);
  end;
  Output.Size := zstream.total_out;
end;

procedure TGlCompressBuffer.RleDecompress;
var
  raw          : byte;
  Wraw, wraw2  : Word;
  i, current, j: Integer;
  buff         : byte;
begin
  Self.Position   := 0;
  Output.Position := 0;
  while True do
  begin
    Self.Read(raw, 1);
    for i := 0 to 8 - 1 do
    begin
      if Self.Position = Self.Size then
        exit;
      if (raw and $01) = 1 then
        Output.CopyFrom(Self, 1)
      else
      begin
        Self.Read(Wraw, 2);
        wraw2   := Wraw;
        Wraw    := Wraw shr 4;
        wraw2   := (wraw2 and $0F) + 2;
        current := Output.Position;
        for j   := 0 to wraw2 - 1 do
        begin
          Output.Seek(current - Wraw, soFromBeginning);
          Output.Read(buff, 1);
          Output.Seek(current, soFromBeginning);
          Output.Write(buff, 1);
          inc(current);
        end;
      end;
      raw := raw shr 1;
    end;
  end;
end;

procedure TGlCompressBuffer.RLEDecompress2(BreakFlag: byte = $FF;
  ComFlag: byte = $1);
var
  cp       : Cardinal;
  flag, dat: byte;
  i        : Integer;
begin
  while True do
  begin
    Self.Read(flag, 1);
    if flag = $FF then
      Break;
    Self.Read(cp, 4);
    if flag = 1 then
    begin
      Self.Read(dat, 1);
      for i := 0 to cp - 1 do
        Output.Write(dat, 1);
    end
    else
    begin
      Output.CopyFrom(Self, cp);
    end;
  end;
end;

procedure TGlCompressBuffer.LzssCompress;
var
  Dummy : byte;
  Buffer: int64;
  i     : Integer;
begin
  Dummy := $FF;
  for i := 1 to (Self.Size div 8) do
  begin
    Output.Write(Dummy, 1);
    Self.Read(Buffer, 8);
    Output.Write(Buffer, 8);
  end;
  Self.Read(Buffer, (Self.Size mod 8));
  Output.Write(Buffer, (Self.Size mod 8));
end;

procedure TGlCompressBuffer.RleCompress;
var
  Dummy : byte;
  Buffer: int64;
  i     : Integer;
begin
  Dummy := $FF;
  for i := 1 to (Self.Size div 8) do
  begin
    Output.Write(Dummy, 1);
    Self.Read(Buffer, 8);
    Output.Write(Buffer, 8);
  end;
  Self.Read(Buffer, (Self.Size mod 8));
  Output.Write(Buffer, (Self.Size mod 8));
end;

procedure TGlCompressBuffer.LzssDecompress(CryptLength,
  SlidWindowIndex, SlidWindowLength: Integer;
  FillBuffer: Integer = $100);
var
  SlidingWindow              : array of byte;
  Temp1, Temp2, EAX, ECX, EDI: Integer;
  AL, DI                     : byte;
begin
  SetLength(SlidingWindow, SlidWindowLength + 1);
  if FillBuffer <> $100 then
    FillChar(SlidingWindow[ 0 ], SlidWindowLength + 1, FillBuffer);
  Temp1 := 0;
  while (CryptLength > 0) do
  begin
    EAX   := Temp1;
    EAX   := EAX shr 1;
    Temp1 := EAX;
    if ((EAX and $FF00) and $100) = 0 then
    begin
      AL := 0;
      Self.Read(AL, 1);
      dec(CryptLength);
      EAX   := AL or $FF00;
      Temp1 := EAX;
    end;
    if ((Temp1 and $FF) and $1) <> 0 then
    begin
      Self.Read(AL, 1);
      dec(CryptLength);
      Output.Write(AL, 1);
      SlidingWindow[ SlidWindowIndex ] := AL;
      inc(SlidWindowIndex);
      SlidWindowIndex := SlidWindowIndex and SlidWindowLength;
    end
    else
    begin
      Self.Read(DI, 1);
      Self.Read(AL, 1);
      dec(CryptLength, 2);
      ECX   := (AL and $F0) shl 4;
      EDI   := DI or ECX;
      EAX   := (AL and $F) + 2;
      Temp2 := EAX;
      ECX   := 0;
      if EAX > 0 then
      begin
        while (ECX <= Temp2) do
        begin
          EAX := (ECX + EDI) and SlidWindowLength;
          AL  := SlidingWindow[ EAX ];
          Output.Write(AL, 1);
          SlidingWindow[ SlidWindowIndex ] := AL;
          inc(SlidWindowIndex);
          SlidWindowIndex := SlidWindowIndex and
            SlidWindowLength;
          inc(ECX);
        end;
      end;
    end;
  end;
end;

Procedure TGlCompressBuffer.MGRDecompress(Input,
  Output: TMemoryStream; Decompressed_Length: Cardinal);
var
  CurByte, Act_UncompreLen, offset, Compressed_Length: Cardinal;
  code                                               : byte;
  copy_bytes, i                                      : Integer;
  src, dst, Compressed_Buffer, Decompressed_Buffer   : Pbyte;
begin
  CurByte             := 0;
  Act_UncompreLen     := 0;
  Output.Size         := Decompressed_Length;
  Compressed_Length   := Input.Size;
  Compressed_Buffer   := Input.Memory;
  Decompressed_Buffer := Output.Memory;
  while True do
  begin
    if (CurByte > Compressed_Length) or
      (Act_UncompreLen > Decompressed_Length) then
      Break;
    code := Compressed_Buffer[ CurByte ];
    inc(CurByte);
    if code < 32 then
    begin
      copy_bytes := code + 1;
      if Act_UncompreLen + copy_bytes > Decompressed_Length then
        exit;
      src             := @Compressed_Buffer[ CurByte ];
      dst             := @Decompressed_Buffer[ Act_UncompreLen ];
      CurByte         := CurByte + copy_bytes;
      Act_UncompreLen := Act_UncompreLen + copy_bytes;
    end
    else
    begin
      offset := (code and $1F) shl 8;
      src    := @Decompressed_Buffer
        [ Act_UncompreLen - (offset + 1) ];
      copy_bytes := code shr 5;

      if (copy_bytes = 7) then
      begin
        copy_bytes := Compressed_Buffer[ CurByte ] + 7;
        inc(CurByte);
      end;
      src := src - Compressed_Buffer[ CurByte ];
      inc(CurByte);
      dst        := @Decompressed_Buffer[ Act_UncompreLen ];
      copy_bytes := copy_bytes + 2;

      if (Act_UncompreLen + copy_bytes >
        Decompressed_Length) then
        exit;

      if (src < Decompressed_Buffer) then
        exit;
      Act_UncompreLen := Act_UncompreLen + copy_bytes;
    end;
    for i := 0 to copy_bytes - 1 do
    begin
      dst^ := src^;
      inc(dst);
      inc(src);
    end;
  end;
end;

function TGlCompressBuffer.LZSSDecode3(CryptLength,
  SlidWindowIndex, SlidWindowLength: Integer): Boolean;
var
  SlidingWindow              : array of byte;
  Temp1, Temp2, EAX, ECX, EDI: Integer;
  AX                         : Word;
  AL                         : byte;
begin
  Result := False;
  SetLength(SlidingWindow, SlidWindowLength + 1);
  Temp1 := 0;
  while (CryptLength > 0) do
  begin
    EAX   := Temp1;
    EAX   := EAX shr 1;
    Temp1 := EAX;
    if ((EAX and $FF00) and $100) = 0 then
    begin
      AL := 0;
      Self.Read(AL, 1);
      dec(CryptLength);
      EAX   := AL or $FF00;
      Temp1 := EAX;
    end;
    if ((Temp1 and $FF) and $1) <> 0 then
    begin
      Self.Read(AL, 1);
      dec(CryptLength);
      Self.Output.Write(AL, 1);
      SlidingWindow[ SlidWindowIndex ] := AL;
      inc(SlidWindowIndex);
      SlidWindowIndex := SlidWindowIndex and SlidWindowLength;
    end
    else
    begin
      Self.Read(AX, 2);
      dec(CryptLength, 2);

      EDI   := AX and $FFF;
      EAX   := (AX shr $C) + 3;
      Temp2 := EAX;
      ECX   := 0;

      if EAX > 0 then
      begin
        while (ECX < Temp2) do
        begin
          EAX := (ECX + EDI) and SlidWindowLength;
          AL  := SlidingWindow[ EAX ];
          Self.Output.Write(AL, 1);
          SlidingWindow[ SlidWindowIndex ] := AL;
          inc(SlidWindowIndex);
          SlidWindowIndex := SlidWindowIndex and
            SlidWindowLength;
          inc(ECX);
        end;
      end;
    end;
    Result := True;
  end;
end;

procedure TGlCompressBuffer.Lz77Decompress;
label
  loop,
  loop2,
  finish;
var
  ebx, edx, esi, EDI, ebp, MyPosition: Cardinal;
  dl                                 : byte;
  C                                  : Integer;
begin
  ebx             := 1;
  Self.Position   := 0;
  Output.Position := 0;
loop:
  while ebx > 0 do
  begin
    if Self.Position >= Self.Size then
      Goto finish;
    Self.Read(dl, 1);
    if dl = 0 then
    begin
      // 如果标识符为00,那么后面8个字节均为未压缩数据
      Output.CopyFrom(Self, 8);
      goto loop;
    end;
    edx := dl;
    edx := (edx shl $18) OR $800000;
    ebp := edx;
  loop2:
    while True do
    begin
      if Self.Position >= Self.Size then
        Goto finish;
      if Integer(ebp) >= 0 then
      begin
        MyPosition := 0;
        while (Integer(ebp) > 0) AND (MyPosition < 7) do
        begin
          ebp := ebp shl 1;
          Output.CopyFrom(Self, 1);
          inc(MyPosition);
        end;
      end;
      begin
        ebp := ebp shl 1;
        if ebp = 0 then
          goto loop;
        Self.Read(dl, 1);
        esi := Output.Position;
        EDI := dl;
        edx := dl;
        edx := (edx and $0F0) shl 4;
        Self.Read(dl, 1);
        esi := esi - (edx + dl);
        // 位置为0,既没有压缩或压缩是当前位置,既是结束标志
        if esi = Self.Position then
          Goto finish;
        EDI := EDI and $0F;
        if EDI = 0 then
        begin
          Self.Read(dl, 1);
          EDI := dl + $10;
        end
        else
        begin
          if EDI = 1 then
          begin
            MyPosition := Output.Position;
            Output.Seek(esi, soFromBeginning);
            Output.Read(dl, 1);
            Output.Seek(MyPosition, soFromBeginning);
            Output.Write(dl, 1);
            MyPosition := Output.Position;
            Output.Seek(esi + 1, soFromBeginning);
            Output.Read(dl, 1);
            Output.Seek(MyPosition, soFromBeginning);
            Output.Write(dl, 1);
            Goto loop2;
          end;
        end;
        MyPosition := Output.Position;
        Output.Seek(esi, soFromBeginning);
        Output.Read(dl, 1);
        Output.Seek(MyPosition, soFromBeginning);
        Output.Write(dl, 1);
        inc(esi);
        for C := 0 to EDI - 1 do
        begin
          MyPosition := Output.Position;
          Output.Seek(esi, soFromBeginning);
          Output.Read(dl, 1);
          Output.Seek(MyPosition, soFromBeginning);
          Output.Write(dl, 1);
          inc(esi);
        end;
      end;
    end;
  finish:
    dec(ebx);
  end;
end;

procedure TGlCompressBuffer.Lz77Compress;
var
  C: byte;
  i: Integer;
begin
  C := 00;
  Output.Clear;
  Self.Position   := 0;
  Output.Position := 0;
  while Self.Position < Self.Size - (Self.Size mod 8) do
  begin
    Output.Write(C, 1);
    Output.CopyFrom(Self, 8);
  end;
  Output.Write(C, 1);
  Output.CopyFrom(Self, (Self.Size mod 8));
  for i := 0 to 8 - (Self.Size mod 8) do
    Output.Write(C, 1);
  C := $C0;
  Output.Write(C, 1);
  C := ($00 shr 4) and $F0;
  Output.Write(C, 1);
  C := 00;
  Output.Write(C, 1);
end;

var
  lzw_dict_letter     : array [ 0 .. 35022 ] of byte;
  lzw_dict_prefix_code: array [ 0 .. 35022 ] of Cardinal;

procedure _LZWDecompress(Buffer: Pbyte; length: Cardinal; decompr: TStream);
var
  code_bits, cur_pos, prefix_code: Cardinal;
  last_code                      : byte;
  phrase_len, suffix_code, code  : Cardinal;
  phrase                         : array [ 0 .. 4095 ] of byte;
  curbits, CurByte, cache        : Cardinal;
  i                              : Integer;
  procedure GetHigh(code_bits: Cardinal; var val: Cardinal);
  var
    bits_value, req: Cardinal;
  begin
    bits_value := 0;
    while code_bits > 0 do
    begin
      if curbits = 0 then
      begin
        cache   := Buffer[ CurByte ];
        CurByte := CurByte + 1;
        curbits := 8;
      end;
      if curbits < code_bits then
        req := curbits
      else
        req      := code_bits;
      bits_value := bits_value shl req;
      bits_value := bits_value or (cache shr (curbits - req));
      cache      := cache and ((1 shl (curbits - req)) - 1);
      code_bits  := code_bits - req;
      curbits    := curbits - req;
    end;
    val := bits_value;
  end;

begin
  curbits := 0;
  CurByte := 0;
  cache   := 0;
  while True do
  begin
    code_bits := 9;
    cur_pos   := 259;
    GetHigh(code_bits, prefix_code);
    if prefix_code = 256 then
      Break;
    decompr.Write(byte(prefix_code), 1);
    last_code := prefix_code;
    while True do
    begin
      GetHigh(code_bits, suffix_code);
      if suffix_code = 257 then
        inc(code_bits)
      else
        if suffix_code = 258 then
        Break
      else
        if suffix_code = 256 then
        exit
      else
      begin
        if suffix_code < cur_pos then
        begin
          phrase_len := 0;
          code       := suffix_code;
        end else
        begin
          phrase[ 0 ] := last_code;
          code        := prefix_code;
          phrase_len  := 1;
        end;
        while code > 255 do
        begin
          phrase[ phrase_len ] := lzw_dict_letter[ code ];
          inc(phrase_len);
          code := lzw_dict_prefix_code[ code ];
        end;
        phrase[ phrase_len ] := code;
        inc(phrase_len);
        last_code := code;
        for i     := phrase_len - 1 downto 0 do
        begin
          decompr.Write(phrase[ i ], 1);
        end;
        lzw_dict_prefix_code[ cur_pos ] := prefix_code;
        lzw_dict_letter[ cur_pos ]      := code;
        inc(cur_pos);
        prefix_code := suffix_code;
      end;
    end;
  end;
end;

procedure TGlCompressBuffer.LZWDecompress;
begin
  _LZWDecompress(Memory, Size, Output);
end;

end.
