{ ******************************************************* }
{ }
{ Plugin Function Unit }
{ }
{ Copyright (C) 2010 - 2011 HatsuneTakumi }
{ }
{ HalTe3 Public License V1 }
{ }
{ ******************************************************* }

unit PluginFunc;

interface

uses CustomStream, Classes, SysUtils;

type

  TStrArray = array of string;
  TNameOrigin = (clEngine, clGameMaker, clGameName);
  TDetectState = (dsTrue = 0, dsFalse = 1, dsUnknown = 2,
    dsError = 3, dsUnsupport = $FF);

  TGpInfo = record
    ACopyRight: string;
    AVersion: string;
    AGameEngine: string;
    ACompany: string;
    AGameList: TStrArray;
    AExtension: string;
    AMagicList: string;
    AMoreInfo: string;
  end;

  GetPluginName = function(): PChar;
  GenerateEntries = function(IndexStream: TIndexStream;
    FileBuffer: TFileBufferStream): Boolean;
  DoAutoDetect = function(FileBuffer: TFileBufferStream)
    : TDetectState;
  DoReadData = function(FileBuffer: TFileBufferStream;
    OutBuffer: TStream): LongInt;
  DoPackData = function(IndexStream: TIndexStream;
    FileBuffer: TFileBufferStream; var Percent: Word): Boolean;
  GetPluginInfo = function(): TGpInfo;
  /// /////////////New Pack Func///////////////
  DoPackProcessData = function(RlEntry: TRlEntry;
    InputBuffer, FileOutBuffer: TStream): Boolean;
  DoPackProcessIndex = function(IndexStream: TIndexStream;
    IndexOutBuffer: TStream): Boolean;
  DoMakePackage = function(IndexStream: TIndexStream;
    IndexOutBuffer, FileOutBuffer: TStream;
    Package: TFileBufferStream): Boolean;

  /// /////////////////////////////////////////
  TGPFunction = record
    FGenerateEntry: GenerateEntries;
    FReadData: DoReadData;
    FPackProcessData: DoPackProcessData;
    FPackProcessIndex: DoPackProcessIndex;
    FMakePackage: DoMakePackage;
    FPackData: DoPackData;
    FAutoDetect: DoAutoDetect;
  end;

const
  sGetPluginName: PChar = 'GetPluginName';
  sGenerateEntries: PChar = 'GenerateEntries';
  sAutoDetect: PChar = 'AutoDetect';
  sReadData: PChar = 'ReadData';
  sPackData: PChar = 'PackData';
  sGetPluginInfo: PChar = 'GetPluginInfo';
  sPackProcessData: PChar = 'PackProcessData';
  sPackProcessIndex: PChar = 'PackProcessIndex';
  sMakePackage: PChar = 'MakePackage';

  sGetMemory: PChar = 'GetMemory';
  sFreeMemory: PChar = 'FreeMemory';
  sFreeContextInfo: PChar = 'FreeContextInfo';

const
  sGetFuncError =
    'An error occurred while getting function address.';
  sGetNameError = 'An error occurred while getting plugin name.';
  sLoadError = 'Can not load this plugin.';
  sUnInitialize = 'Can not process before open a file.';
  sUnInitialize2 = 'Can not process before load a plugin.';
  sUnInitialize3 =
    'Can not process before create base structure.';
  sPluginProcessError = 'Plugin Error : Process data.';
  sPluginReadError = 'Plugin Error : Read data.';
  sInvalidPlugin = 'Invalid Plugin.';
  sMissingParameters = 'Missing Parameters';
  sClassError = 'Invalid class.';
  sIndexOverflow = 'Index Overflow.';
  sNoInfo = 'No more infomation.';
  sInfoHeader = 'Halte2 Plugin Information';
  sCopyRight = 'Plugin CopyRight:';
  sVersion = 'Plugin Version';
  sGameEngine = 'Game Engine:';
  sCompany = 'Company:';
  sGameList = 'Supported Game List:';
  sExtension = 'Package Extension:';
  sMagicList = 'Magic List:';
  sMoreInfo = 'Info.:';

function FormatPluginName(Name: string;
  Origin: TNameOrigin): string;
procedure SaveAndClear(Buffer: TStream; FileName: string);
procedure SaveToStream(Input, output: TStream);
procedure DivStream(Input: TStream; DivSize: Cardinal;
  OutPath: string);
function CompareExt(FileName, Ext: string): Boolean;
function CompareStreamData(Stream: TStream; Buffer: PByte;
  BufferLen: Cardinal): Boolean; overload;
function CompareStreamData(Stream1, Stream2: TStream;
  BufferLen: Cardinal): Boolean; overload;

implementation

function FormatPluginName(Name: string;
  Origin: TNameOrigin): string;
begin
  case Origin of
    clEngine:
      Result := '[E]' + Name;
    clGameMaker:
      Result := '[M]' + Name;
    clGameName:
      Result := '[N]' + Name;
  end;
end;

procedure SaveAndClear(Buffer: TStream; FileName: string);
var
  Pos: Int64;
  MyBuffer: TFileStream;
begin
  MyBuffer := TFileStream.Create(FileName, fmCreate);
  try
    Pos := Buffer.Position;
    Buffer.Seek(0, soFromBeginning);
    MyBuffer.CopyFrom(Buffer, Buffer.Size);
    Buffer.Seek(0, soFromBeginning);
    Buffer.Size := 0;
    Buffer.Seek(Pos, soFromBeginning);
  finally
    MyBuffer.Free;
  end;
end;

procedure SaveToStream(Input, output: TStream);
var
  Pos: Int64;
begin
  Pos := Input.Position;
  Input.Seek(0, soFromBeginning);
  output.CopyFrom(Input, Input.Size);
  Input.Seek(Pos, soFromBeginning);
end;

procedure DivStream(Input: TStream; DivSize: Cardinal;
  OutPath: string);
var
  output: TFileStream;
begin
  output := TFileStream.Create(OutPath, fmCreate);
  try
    output.CopyFrom(Input, DivSize);
  finally
    output.Free;
  end;
end;

function CompareExt(FileName, Ext: string): Boolean;
begin
  Result := SameText(ExtractFileExt(FileName), Ext);
end;

function CompareStreamData(Stream: TStream; Buffer: PByte;
  BufferLen: Cardinal): Boolean; overload;
var
  sBuffer: array of Byte;
begin
  SetLength(sBuffer, BufferLen);
  Stream.Read(sBuffer[ Low(sBuffer)], BufferLen);
  Result := CompareMem(sBuffer, Buffer, BufferLen);
  SetLength(sBuffer, 0);
end;

function CompareStreamData(Stream1, Stream2: TStream;
  BufferLen: Cardinal): Boolean; overload;
var
  Buffer1, Buffer2: array of Byte;
begin
  SetLength(Buffer1, BufferLen);
  SetLength(Buffer2, BufferLen);
  Stream1.Read(Buffer1[ Low(Buffer1)], BufferLen);
  Stream2.Read(Buffer2[ Low(Buffer2)], BufferLen);
  Result := CompareMem(Buffer1, Buffer2, BufferLen);
  SetLength(Buffer1, 0);
  SetLength(Buffer2, 0);
end;

end.
