(*------------------------------------------------------------------------------

Unit          : CustomStream
Author        : Ivan Dyachenko
E-mail        : ivan.dyachenko@gmail.com
Site          : http://atgrand.com
Project       : http://clevertis.atgrand.com
Date          : 2011-07-28
Generation by : AT&PI PaxCompiler Importer

------------------------------------------------------------------------------*)

{$I PaxCompiler.def}
unit IMPORT_CustomStream;

interface
uses
   Classes,
   RTLConsts,
   ZLib,
   CustomStream,
   iCore2,
   PaxCompiler;

procedure Register_CustomStream;

implementation

//--------------------------------------------------------------------------------
// TIndexStream
function TIndexStream_GetRlEntry(Self: TIndexStream; Index: Integer): TRlEntry;
begin
  Result := Self.RlEntry[Index];
end;

//--------------------------------------------------------------------------------
// TFileBufferStream
function TFileBufferStream_FIndexs(Self: TFileBufferStream): Longint;
begin
  Result := Self.Indexs;
end;

function TFileBufferStream_GetRlEntry(Self: TFileBufferStream): TRlEntry;
begin
  Result := Self.RlEntry;
end;

function TFileBufferStream_GetPrevEntry(Self: TFileBufferStream): TRlEntry;
begin
  Result := Self.PrevEntry;
end;

function TFileBufferStream_GetNextEntry(Self: TFileBufferStream): TRlEntry;
begin
  Result := Self.NextEntry;
end;

//--------------------------------------------------------------------------------
// TGlCompressBuffer
function TGlCompressBuffer_OutputStream(Self: TGlCompressBuffer): TMemoryStream;
begin
  Result := Self.Output;
end;


procedure Register_CustomStream;
var
  H : Integer;
  G : Integer;
begin
  H := RegisterNamespace(0, 'CustomStream');
  _uses['CustomStream'] := true;

//--------------------------------------------------------------------------------
// CONST
  RegisterConstant(H, 'nul'               , nul);

//--------------------------------------------------------------------------------
// TYPE

  G := RegisterEnumType (H, 'TZCompressionLevel');
       RegisterEnumValue(G, 'zcNone'          , 0);
       RegisterEnumValue(G, 'zcFastest'       , 1);
       RegisterEnumValue(G, 'zcDefault'       , 2);
       RegisterEnumValue(G, 'zcMax'           , 3);
  _type['TZCompressionLevel'] := G;

//--------------------------------------------------------------------------------
// CLASS

  _type['TRlEntry']           := RegisterClassType(H, TRlEntry);
  _type['TIndexStream']       := RegisterClassType(H, TIndexStream);
  _type['TFileBufferStream']  := RegisterClassType(H, TFileBufferStream);
  _type['TGlCompressBuffer']  := RegisterClassType(H, TGlCompressBuffer);
       RegisterHeader(G, 'procedure Assign(AObject: TRlEntry); ', @TRlEntry.Assign);
  G := _type['TIndexStream'];
       RegisterHeader  (G, 'function  _GetRlEntry(Index: Integer):TRlEntry;', @TIndexStream_GetRlEntry);
       RegisterProperty(G, 'property RlEntry[index: Integer]: TRlEntry read _GetRlEntry; ');

       RegisterHeader(G, 'procedure Clear; override; ', @TIndexStream.Clear);
       RegisterHeader(G, 'procedure InitializeStream; overload; ', @TIndexStream.InitializeStream);
       RegisterHeader(G, 'procedure InitializeStream(EntrySize: Longint); overload; ', @TIndexStream.InitializeStream);
       RegisterHeader(G, 'procedure Seek(Origin: TSeekOrigin; Count: Longint); ', @TIndexStream.Seek);
       RegisterHeader(G, 'function GenerateEntry: Boolean; virtual; ', @TIndexStream.GenerateEntry);
       RegisterHeader(G, 'procedure Add(Entry: TRlEntry); overload; ', @TIndexStream.Add);
  G := _type['TFileBufferStream'];
       RegisterHeader  (G, 'function  _FIndexs:Longint;', @TFileBufferStream_FIndexs);
       RegisterProperty(G, 'property Indexs: Longint read _FIndexs; ');

       RegisterHeader  (G, 'function  _GetRlEntry:TRlEntry;', @TFileBufferStream_GetRlEntry);
       RegisterProperty(G, 'property RlEntry: TRlEntry read _GetRlEntry; ');

       RegisterHeader  (G, 'function  _GetPrevEntry:TRlEntry;', @TFileBufferStream_GetPrevEntry);
       RegisterProperty(G, 'property PrevEntry: TRlEntry read _GetPrevEntry; ');

       RegisterHeader  (G, 'function  _GetNextEntry:TRlEntry;', @TFileBufferStream_GetNextEntry);
       RegisterProperty(G, 'property NextEntry: TRlEntry read _GetNextEntry; ');

       RegisterHeader(G, 'procedure Seek(Origin: TSeekOrigin; Count: Longint); ', @TFileBufferStream.Seek);
       RegisterHeader(G, 'function ReadData(var Buffer): Longint; overload; ', @TFileBufferStream.ReadData);
       RegisterHeader(G, 'function ReadData(Buffer: TStream): Longint; overload; ', @TFileBufferStream.ReadData);
       RegisterHeader(G, 'procedure Decyption(var Buffer); virtual; ', @TFileBufferStream.Decyption);
       RegisterHeader(G, 'procedure SetIndexStream(Stream: TIndexStream); ', @TFileBufferStream.SetIndexStream);
       RegisterHeader(G, 'procedure free; overload; ', @TFileBufferStream.free);
       RegisterHeader(G, 'function Read(var Buffer; Size: int64; offset: int64) ', @TFileBufferStream.Read);
       RegisterHeader(G, 'function Read(Buffer: TStream; Size: int64; offset: int64) ', @TFileBufferStream.Read);
       RegisterHeader(G, 'constructor Create(const AFileName: string; Mode: Word; IndexStream: TIndexStream); overload; ', @TFileBufferStream.Create);
  G := _type['TGlCompressBuffer'];
       RegisterHeader  (G, 'function  _OutputStream:TMemoryStream;', @TGlCompressBuffer_OutputStream);
       RegisterProperty(G, 'property Output: TMemoryStream read _OutputStream; ');

       RegisterHeader(G, 'procedure Clear; overload; ', @TGlCompressBuffer.Clear);
       RegisterHeader(G, 'procedure ZlibDecompress(DestLen: LongWord); ', @TGlCompressBuffer.ZlibDecompress);
       RegisterHeader(G, 'procedure LzssCompress; ', @TGlCompressBuffer.LzssCompress);
       RegisterHeader(G, 'procedure RleDecompress; ', @TGlCompressBuffer.RleDecompress);
       RegisterHeader(G, 'procedure RleCompress; ', @TGlCompressBuffer.RleCompress);
       RegisterHeader(G, 'procedure MGRDecompress(Input, Output: TMemoryStream; Decompressed_Length: Cardinal); ', @TGlCompressBuffer.MGRDecompress);
       RegisterHeader(G, 'function LZSSDecode3(CryptLength, SlidWindowIndex, SlidWindowLength: Integer): Boolean; ', @TGlCompressBuffer.LZSSDecode3);
       RegisterHeader(G, 'procedure Lz77Decompress; ', @TGlCompressBuffer.Lz77Decompress);
       RegisterHeader(G, 'procedure Lz77Compress; ', @TGlCompressBuffer.Lz77Compress);
       RegisterHeader(G, 'procedure LZWDecompress(DecompressLength: Cardinal); ', @TGlCompressBuffer.LZWDecompress);
       RegisterHeader(G, 'constructor Create; overload; ', @TGlCompressBuffer.Create);

//--------------------------------------------------------------------------------
// METHOD


//--------------------------------------------------------------------------------
// VAR


end;

initialization

Register_CustomStream;

end.
