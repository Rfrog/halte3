unit hCPtypes;

interface

uses Windows;

{$DEFINE STDCALL}

type

  TEntry = packed record
    AName: array [0 .. $500 - 1] of Char;
    ANameLength: Cardinal;
    AOffset: Cardinal;
    AOrigin: Word;
    AStoreLength: Cardinal;
    ARLength: Cardinal;
    AHash: array [0 .. 3] of Cardinal;
    ADate: Cardinal;
    ATime: Cardinal;
    AKey: Cardinal;
    AKey2: Cardinal;
  end;

  TCGPStream = Pointer;
  TFileHandle = Cardinal;
  TIndexsArray = array of TEntry;
  PIndexsArray = ^TIndexsArray;
  PEntry = ^TEntry;

{$IFDEF STDCALL}
  TGetPluginName = function(): PChar; stdcall;

  TGetMemory = function(Size: Cardinal): Pointer; stdcall;
  TFreeMemory = function(Memory: Pointer): Integer; stdcall;

  TExtractIndexs = function(Input: TFileHandle;
    out Output: TIndexsArray): Cardinal; stdcall;
  TExtractData = function(Input: TFileHandle; Entry: PEntry;
    out Output: TCGPStream): Cardinal; stdcall;

  TProcessFiles = function(Input: TCGPStream; Entry: PEntry;
    out Output: TCGPStream): Cardinal; stdcall;
  TProcessIndexs = function(Input: TIndexsArray;
    Indexs: Cardinal; out Output: TCGPStream): Cardinal; stdcall;
  TMakePackage = function(Index: TIndexsArray; Indexs: Cardinal;
    FileData: TCGPStream; FileDataSize: Cardinal;
    IndexData: TCGPStream; IndexDataSize: Cardinal;
    Package: TFileHandle): Cardinal; stdcall;
  TPackData = function(Index: TIndexsArray; Indexs: Cardinal;
    Package: TFileHandle; var Percent: Word): Cardinal; stdcall;

  TAutoDetect = function(Input: TFileHandle): Integer; stdcall;
{$ENDIF}
{$IFDEF CDECL}
  TGetPluginName = function(): PChar; cdecl;

  TGetMemory = function(Size: Cardinal): Pointer; cdecl;
  TFreeMemory = function(Memory: Pointer): Integer; cdecl;

  TExtractIndexs = function(Input: TFileHandle;
    out Output: TIndexsArray): Cardinal; cdecl;
  TExtractData = function(Input: TFileHandle; Entry: PEntry;
    out Output: TCGPStream): Cardinal; cdecl;

  TProcessFiles = function(Input: TCGPStream; Entry: PEntry;
    out Output: TCGPStream): Cardinal; cdecl;
  TProcessIndexs = function(Input: TIndexsArray;
    Indexs: Cardinal; out Output: TCGPStream): Cardinal; cdecl;
  TMakePackage = function(Index: TIndexsArray; Indexs: Cardinal;
    FileData: TCGPStream; FileDataSize: Cardinal;
    IndexData: TCGPStream; IndexDataSize: Cardinal;
    Package: TFileHandle): Cardinal; cdecl;
  TPackData = function(Index: TIndexsArray; Indexs: Cardinal;
    Package: TFileHandle; var Percent: Word): Cardinal; cdecl;

  TAutoDetect = function(Input: TFileHandle): Integer; cdecl;

{$ENDIF}

  TCGPFunction = record
    FGetMemory: TGetMemory;
    FFreeMemory: TFreeMemory;
    FExtractIndexs: TExtractIndexs;
    FExtractData: TExtractData;
    FProcessFiles: TProcessFiles;
    FProcessIndexs: TProcessIndexs;
    FMakePackage: TMakePackage;
    FPackData: TPackData;
    FAutoDetect: TAutoDetect;
  end;

implementation

end.
