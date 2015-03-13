{ ******************************************************* }
{ }
{ CustomManager }
{ }
{ Copyright (C) 2010 - 2011 HatsuneTakumi }
{ }
{ HalTe3 Public License V1 }
{ }
{ ******************************************************* }

unit CustoManager;

interface

uses Classes, PluginFunc, CustomStream, hCPtypes;

{$DEFINE CSUPPORT}

const
  nul = -1;
  null = 0;
  PluginExt = '*.GP';
  CUIExt = '*.cui';
  CPluginExt = '*.CGP';

  GPExt = '.GP';
  CPExt = '.CGP';

type

  TOnProcessList = procedure() of object;
  POnProcessList = ^TOnProcessList;

  TPluginType = (ptFastCall, ptStdCall, ptCdecl, ptUnknow);

  { TGPlugin }
  TGPlugin = class(TObject)
    APath: string;
    AHash: Cardinal;
    AName: string;
    ASupportPack: Integer;
    ASupportAutoDetect: Integer;
    APluginType: TPluginType;
    GpInfo: TGpInfo;
  public
    constructor Create;
    destructor Destroy; override;
  end;

  { TGPManager }
  TGPManager = class(TStringList)
  private
    FHandle: Cardinal;
    FSelected: LongInt;
    FCGPFunction: TCGPFunction;
    FGPFunction: TGPFunction;
    FPluginType: TPluginType;
    FOnProcessList: TOnProcessList;
  protected
    procedure AddPlugin(Plugin: TGPlugin);
    function CreateObjectFromName(APath: string): TGPlugin;
    function GetPlugin: TGPlugin;
  public
    property Selected: LongInt read FSelected write FSelected;
    property Handle: Cardinal read FHandle;
    property GpInfo: TGPlugin read GetPlugin;

    property OnProcessList: TOnProcessList read FOnProcessList
      write FOnProcessList;

    procedure GenerateGPList(Path: string);

    function GenerateEntry(IndexStream: TIndexStream;
      FileBuffer: TFileBufferStream): Boolean;
    function AutoDetect(FileBuffer: TFileBufferStream)
      : TDetectState;
    function ReadData(FileBuffer: TFileBufferStream;
      OutBuffer: TStream): LongInt;
    function PackData(IndexStream: TIndexStream;
      FileBuffer: TFileBufferStream; var Percent: Word): Boolean;
    function PackProcessData(RlEntry: TRlEntry;
      InputBuffer, FileOutBuffer: TStream): Boolean;
    function PackProcessIndex(IndexStream: TIndexStream;
      IndexOutBuffer: TStream): Boolean;
    function MakePackage(IndexStream: TIndexStream;
      IndexOutBuffer, FileOutBuffer: TStream;
      Package: TFileBufferStream): Boolean;

    constructor Create; overload;
    procedure Clear; override;
    function LoadPlugin(Index: Integer): Cardinal;
    procedure FreePlugin;
    destructor Destroy; override;
    procedure Add(PluginPath: string); overload;
  end;

implementation

uses IOUtils, Types, Windows, SysUtils;

function FormatWithType(Name: PChar;
  PluginType: TPluginType): string;
begin
  Result := Name;
  case PluginType of
    ptFastCall:
      Result := '[D]' + Name;
    ptStdCall:
      Result := '[C]' + Name;
    ptUnknow:
      ;
  end;
end;

constructor TGPlugin.Create;
begin
  APath := '';
  AHash := $0;
  AName := '';
  ASupportPack := 0;
  ASupportAutoDetect := 0;
  APluginType := ptUnknow;
end;

destructor TGPlugin.Destroy;
begin
  inherited
end;

{ ==========================================================
  TGPManager
  General Plugin Handle Class
  HatsuneTakumi (C) 2011 All right reserved
  ========================================================== }
function TGPManager.GetPlugin: TGPlugin;
begin
  if FSelected >= Count then
    raise Exception.Create(sInvalidPlugin);
  Result := Self.Objects[FSelected] as TGPlugin;
end;

procedure TGPManager.FreePlugin;
begin
  if Self.Handle > 0 then
    FreeLibrary(Self.FHandle);
  FHandle := null;
end;

function TGPManager.LoadPlugin(Index: Integer): Cardinal;
var
  Path: string;
begin
  FreePlugin;
  Self.Selected := Index;
  Path := (Self.Objects[Self.Selected] as TGPlugin).APath;
  Self.FHandle := LoadLibrary(PChar(Path));
  FPluginType := (Self.Objects[Self.Selected] as TGPlugin)
    .APluginType;
  try
    if Self.Handle = 0 then
      raise Exception.Create(sLoadError);
    case (Self.Objects[Self.Selected] as TGPlugin).APluginType of
      ptFastCall:
        begin
          @FGPFunction.FGenerateEntry :=
            GetProcAddress(Self.Handle, sGenerateEntries);
          if @FGPFunction.FGenerateEntry = nil then
            raise Exception.Create(sLoadError);
          @FGPFunction.FAutoDetect := GetProcAddress(Self.Handle,
            sAutoDetect);
          if @FGPFunction.FAutoDetect = nil then
            (Self.GetObject(Self.Selected) as TGPlugin)
              .ASupportAutoDetect :=
              0 else (Self.GetObject(Self.Selected) as TGPlugin)
              .ASupportAutoDetect := 1;
          @FGPFunction.FReadData := GetProcAddress(Self.Handle,
            sReadData);
          if @FGPFunction.FReadData = nil then
            raise Exception.Create(sLoadError);
          case (Self.GetObject(Self.Selected) as TGPlugin)
            .ASupportPack of
            0:
              begin
                @FGPFunction.FPackData :=
                  GetProcAddress(Self.Handle, sPackData);
                if @FGPFunction.FReadData = nil then
                  raise Exception.Create(sLoadError);
              end;
            1:
              begin
                @FGPFunction.FPackProcessData :=
                  GetProcAddress(Self.Handle, sPackProcessData);
                if @FGPFunction.FPackProcessData = nil then
                  raise Exception.Create(sLoadError);
                @FGPFunction.FPackProcessIndex :=
                  GetProcAddress(Self.Handle, sPackProcessIndex);
                if @FGPFunction.FPackProcessIndex = nil then
                  raise Exception.Create(sLoadError);
                @FGPFunction.FMakePackage :=
                  GetProcAddress(Self.Handle, sMakePackage);
                if @FGPFunction.FMakePackage = nil then
                  raise Exception.Create(sLoadError);
              end;
          end;
        end;
      ptStdCall:
        begin
{$IFDEF CSUPPORT}
          @FCGPFunction.FGetMemory := GetProcAddress(Self.Handle,
            sGetMemory);
          if @FCGPFunction.FGetMemory = nil then
            raise Exception.Create(sLoadError);
          @FCGPFunction.FFreeMemory :=
            GetProcAddress(Self.Handle, sFreeMemory);
          if @FCGPFunction.FFreeMemory = nil then
            raise Exception.Create(sLoadError);
          @FCGPFunction.FExtractIndexs :=
            GetProcAddress(Self.Handle, sGenerateEntries);
          if @FCGPFunction.FExtractIndexs = nil then
            raise Exception.Create(sLoadError);
          @FCGPFunction.FAutoDetect :=
            GetProcAddress(Self.Handle, sAutoDetect);
          if @FCGPFunction.FAutoDetect = nil then
            (Self.GetObject(Self.Selected) as TGPlugin)
              .ASupportAutoDetect :=
              0 else (Self.GetObject(Self.Selected) as TGPlugin)
              .ASupportAutoDetect := 1;
          @FCGPFunction.FExtractData :=
            GetProcAddress(Self.Handle, sReadData);
          if @FCGPFunction.FExtractData = nil then
            raise Exception.Create(sLoadError);
          case (Self.GetObject(Self.Selected) as TGPlugin)
            .ASupportPack of
            0:
              begin
                @FCGPFunction.FPackData :=
                  GetProcAddress(Self.Handle, sPackData);
                if @FCGPFunction.FPackData = nil then
                  raise Exception.Create(sLoadError);
              end;
            1:
              begin
                @FCGPFunction.FProcessFiles :=
                  GetProcAddress(Self.Handle, sPackProcessData);
                if @FCGPFunction.FProcessFiles = nil then
                  raise Exception.Create(sLoadError);
                @FCGPFunction.FProcessIndexs :=
                  GetProcAddress(Self.Handle, sPackProcessIndex);
                if @FCGPFunction.FProcessIndexs = nil then
                  raise Exception.Create(sLoadError);
                @FCGPFunction.FMakePackage :=
                  GetProcAddress(Self.Handle, sMakePackage);
                if @FCGPFunction.FMakePackage = nil then
                  raise Exception.Create(sLoadError);
              end;
          end;
{$ENDIF}
        end;
      ptUnknow:
        ;
    end;
  finally
    Result := Self.Handle;
  end;
end;

function TGPManager.CreateObjectFromName(APath: string)
  : TGPlugin;
var
  DHWND: Cardinal;

  GetName: GetPluginName;
  GetPack: DoPackData;
  GetInfo: GetPluginInfo;
  MyMakePackage: DoMakePackage;

  cGetPluginName: TGetPluginName;
  cMakePackage: TMakePackage;
  cPackData: TPackData;
  MyFreeMemory: TFreeMemory;
begin
  Result := TGPlugin.Create;
  Result.APath := APath;
  Result.AHash := 0;
  if CompareExt(APath, GPExt) then
    Result.APluginType := ptFastCall
  else if CompareExt(APath, CPExt) then
    Result.APluginType := ptStdCall
  else
    Result.APluginType := ptUnknow;
  try
    DHWND := LoadLibrary(PChar(APath));
    try
      if DHWND = 0 then
        raise Exception.Create(sLoadError);
      case Result.APluginType of
        ptFastCall:
          begin
            @GetName := GetProcAddress(DHWND, sGetPluginName);
            if @GetName = nil then
              raise Exception.Create(sGetNameError);
            Result.AName := FormatWithType(GetName,
              Result.APluginType);
            @MyMakePackage := GetProcAddress(DHWND,
              sMakePackage);
            if @MyMakePackage <> nil then
              Result.ASupportPack := 1
            else
            begin
              @GetPack := GetProcAddress(DHWND, sPackData);
              if @GetPack = nil then
                Result.ASupportPack := -1
              else
                Result.ASupportPack := 0;
            end;
            @GetInfo := GetProcAddress(DHWND, sGetPluginInfo);
            if @GetInfo <> nil then
              Result.GpInfo := GetInfo;
          end;
        ptStdCall:
          begin
{$IFDEF CSUPPORT}
            @MyFreeMemory := GetProcAddress(DHWND, sFreeMemory);
            if @MyFreeMemory = nil then
              raise Exception.Create(sLoadError);
            @cGetPluginName := GetProcAddress(DHWND,
              sGetPluginName);
            if @cGetPluginName = nil then
              raise Exception.Create(sGetNameError);
            Result.AName := FormatWithType(cGetPluginName,
              Result.APluginType);
            @cMakePackage := GetProcAddress(DHWND, sMakePackage);
            if @cMakePackage <> nil then
              Result.ASupportPack := 1
            else
            begin
              @cPackData := GetProcAddress(DHWND, sPackData);
              if @cPackData = nil then
                Result.ASupportPack := -1
              else
                Result.ASupportPack := 0;
            end;
{$ENDIF}
          end;
        ptUnknow:
          ;
      end;
    finally
      FreeLibrary(DHWND);
    end;
  except
    Result.Free;
    Result := nil;
  end;
end;

procedure TGPManager.GenerateGPList(Path: string);
var
  FList: TStringDynArray;
  i: Integer;
begin
  if not DirectoryExists(Path) then
    ForceDirectories(Path);
  FList := IOUtils.TDirectory.GetFiles(Path, PluginExt,
    TSearchOption.soAllDirectories);
  try
    for i := low(FList) to high(FList) do
    begin
      AddPlugin(CreateObjectFromName(FList[i]));
      if Assigned(OnProcessList) then
        OnProcessList;
    end;
  finally
    SetLength(FList, 0);
  end;
{$IFDEF CSUPPORT}
  FList := IOUtils.TDirectory.GetFiles(Path, CPluginExt,
    TSearchOption.soAllDirectories);
  try
    for i := low(FList) to high(FList) do
    begin
      AddPlugin(CreateObjectFromName(FList[i]));
      if Assigned(OnProcessList) then
        OnProcessList;
    end;
  finally
    SetLength(FList, 0);
  end;
{$ENDIF}
end;

procedure TGPManager.AddPlugin(Plugin: TGPlugin);
begin
  if Plugin = nil then
    Exit;
  if Self.IndexOf(Plugin.AName) >= 0 then
  begin
    Plugin.Free;
  end
  else
    Self.AddObject(Plugin.AName, Plugin);
end;

constructor TGPManager.Create;
begin
  inherited Create;
  FHandle := null;
  FSelected := nul;
end;

destructor TGPManager.Destroy;
begin
  FreePlugin;
  Clear;
  inherited Destroy;
end;

procedure TGPManager.Add(PluginPath: string);
begin
  AddPlugin(CreateObjectFromName(PluginPath));
  if Assigned(OnProcessList) then
    OnProcessList;
end;

procedure TGPManager.Clear;
var
  i: Integer;
begin
  for i := 0 to Self.Count - 1 do
  begin
    (Self.Objects[i] as TGPlugin).Free;
    Self.Objects[i] := nil;
  end;
  FHandle := null;
  FSelected := nul;
  inherited Clear;
end;

function TGPManager.GenerateEntry(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream): Boolean;
var
  i: Integer;
  RlEntry: TRlEntry;
  Indexs: TIndexsArray;
  IndexNum: Cardinal;
begin
  Result := True;
  case FPluginType of
    ptFastCall:
      Result := FGPFunction.FGenerateEntry(IndexStream,
        FileBuffer);
    ptStdCall:
      begin
{$IFDEF CSUPPORT}
        IndexNum := FCGPFunction.FExtractIndexs
          (FileBuffer.Handle, Indexs);
        if Indexs = nil then
          raise Exception.Create('Indexs data error.');
        try
          for i := 0 to IndexNum - 1 do
          begin
            RlEntry := TRlEntry.Create;
            with RlEntry do
            begin
              AName := Trim(Indexs[i].AName);
              ANameLength := Indexs[i].ANameLength;
              AOffset := Indexs[i].AOffset;
              AOrigin := Indexs[i].AOrigin;
              AStoreLength := Indexs[i].AStoreLength;
              ARLength := Indexs[i].ARLength;
              AHash[0] := Indexs[i].AHash[0];
              AHash[1] := Indexs[i].AHash[1];
              AHash[2] := Indexs[i].AHash[2];
              AHash[3] := Indexs[i].AHash[3];
              ADate := Indexs[i].ADate;
              ATime := Indexs[i].ATime;
              AKey := Indexs[i].AKey;
              RlEntry.AKey2 := Indexs[i].AKey2;
            end;
            IndexStream.Add(RlEntry);
          end;
        finally
          FCGPFunction.FFreeMemory(Indexs);
          Indexs := nil;
        end;
{$ENDIF}
      end;
    ptUnknow:
      Result := False;
  end;
end;

function TGPManager.ReadData(FileBuffer: TFileBufferStream;
  OutBuffer: TStream): LongInt;
var
  Buffer: Pointer;
  Entry: TEntry;
begin
  Result := 0;
  case FPluginType of
    ptFastCall:
      Result := FGPFunction.FReadData(FileBuffer, OutBuffer);
    ptStdCall:
      begin
{$IFDEF CSUPPORT}
        with Entry do
        begin
          System.Move(Pbyte(FileBuffer.RlEntry.AName)^,
            AName[ Low(AName)], Length(FileBuffer.RlEntry.AName)
            * SizeOf(char));
          ANameLength := FileBuffer.RlEntry.ANameLength;
          AOffset := FileBuffer.RlEntry.AOffset;
          AOrigin := FileBuffer.RlEntry.AOrigin;
          AStoreLength := FileBuffer.RlEntry.AStoreLength;
          ARLength := FileBuffer.RlEntry.ARLength;
          AHash[0] := FileBuffer.RlEntry.AHash[0];
          AHash[1] := FileBuffer.RlEntry.AHash[1];
          AHash[2] := FileBuffer.RlEntry.AHash[2];
          AHash[3] := FileBuffer.RlEntry.AHash[3];
          ADate := FileBuffer.RlEntry.ADate;
          ATime := FileBuffer.RlEntry.ATime;
          AKey := FileBuffer.RlEntry.AKey;
          AKey2 := FileBuffer.RlEntry.AKey2;
        end;
        Result := FCGPFunction.FExtractData(FileBuffer.Handle,
          @Entry, Buffer);
        try
          OutBuffer.Seek(0, soFromBeginning);
          OutBuffer.WriteBuffer(Buffer^, Result);
          OutBuffer.Seek(0, soFromBeginning);
        finally
          FCGPFunction.FFreeMemory(Buffer);
          Buffer := nil;
        end;
{$ENDIF}
      end;
    ptUnknow:
      Result := -1;
  end;
end;

function TGPManager.AutoDetect(FileBuffer: TFileBufferStream)
  : TDetectState;
begin
  Result := dsFalse;
  case FPluginType of
    ptFastCall:
      Result := FGPFunction.FAutoDetect(FileBuffer);
    ptStdCall:
      begin
{$IFDEF CSUPPORT}
        Result := TDetectState
          (FCGPFunction.FAutoDetect(FileBuffer.Handle));
{$ENDIF}
      end;
    ptUnknow:
      Result := dsUnsupport;
  end;
end;

function TGPManager.PackData(IndexStream: TIndexStream;
  FileBuffer: TFileBufferStream; var Percent: Word): Boolean;
var
  Indexs: TIndexsArray;
  i: Integer;
  Tmpstream: TFileStream;
begin
  Result := True;
  case FPluginType of
    ptFastCall:
      Result := FGPFunction.FPackData(IndexStream,
        FileBuffer, Percent);
    ptStdCall:
      begin
{$IFDEF CSUPPORT}
        Indexs := FCGPFunction.FGetMemory(IndexStream.Count *
          SizeOf(TEntry));
        try
          for i := 0 to IndexStream.Count - 1 do
          begin
            Tmpstream := TFileStream.Create
              (IndexStream.ParentPath + IndexStream.RlEntry[i]
              .AName, fmOpenRead);
            try
              Tmpstream.Seek(0, soFromBeginning);
              begin
                IndexStream.RlEntry[i].ANameLength :=
                  Length(IndexStream.RlEntry[i].AName) *
                  SizeOf(char);
                IndexStream.RlEntry[i].ARLength :=
                  Tmpstream.Size;
                IndexStream.RlEntry[i].AStoreLength :=
                  IndexStream.RlEntry[i].ARLength;
                IndexStream.RlEntry[i].AOrigin :=
                  soFromBeginning;
              end;
            finally
              Tmpstream.Free;
            end;
            with Indexs[i] do
            begin
              System.Move(Pbyte(IndexStream.RlEntry[i].AName)^,
                AName[ Low(AName)],
                Length(IndexStream.RlEntry[i].AName) *
                SizeOf(char));
              ANameLength := IndexStream.RlEntry[i].ANameLength;
              AOffset := IndexStream.RlEntry[i].AOffset;
              AOrigin := IndexStream.RlEntry[i].AOrigin;
              AStoreLength := IndexStream.RlEntry[i]
                .AStoreLength;
              ARLength := IndexStream.RlEntry[i].ARLength;
              AHash[0] := IndexStream.RlEntry[i].AHash[0];
              AHash[1] := IndexStream.RlEntry[i].AHash[1];
              AHash[2] := IndexStream.RlEntry[i].AHash[2];
              AHash[3] := IndexStream.RlEntry[i].AHash[3];
              ADate := IndexStream.RlEntry[i].ADate;
              ATime := IndexStream.RlEntry[i].ATime;
              AKey := IndexStream.RlEntry[i].AKey;
              AKey2 := IndexStream.RlEntry[i].AKey2;
            end;
          end;
          FCGPFunction.FPackData(Indexs, IndexStream.Count,
            FileBuffer.Handle, Percent);
        finally
          FCGPFunction.FFreeMemory(Indexs);
        end;
{$ENDIF}
      end;
    ptUnknow:
      Result := False;
  end;
end;

function TGPManager.PackProcessData(RlEntry: TRlEntry;
  InputBuffer: TStream; FileOutBuffer: TStream): Boolean;
var
  Input, Output: Pointer;
  Entry: TEntry;
  BufferSize: Cardinal;
begin
  Result := True;
  case FPluginType of
    ptFastCall:
      Result := FGPFunction.FPackProcessData(RlEntry,
        InputBuffer, FileOutBuffer);
    ptStdCall:
      begin
{$IFDEF CSUPPORT}
        Input := FCGPFunction.FGetMemory
          (Cardinal(InputBuffer.Size));
        try
          ZeroMemory(@Entry.AName[0], SizeOf(TEntry));
          with Entry do
          begin
            System.Move(Pbyte(RlEntry.AName)^,
              AName[ Low(AName)], Length(RlEntry.AName) *
              SizeOf(char));
            ANameLength := RlEntry.ANameLength;
            AOffset := FileOutBuffer.Position;
            AOrigin := RlEntry.AOrigin;
            AStoreLength := RlEntry.AStoreLength;
            ARLength := RlEntry.ARLength;
            AHash[0] := RlEntry.AHash[0];
            AHash[1] := RlEntry.AHash[1];
            AHash[2] := RlEntry.AHash[2];
            AHash[3] := RlEntry.AHash[3];
            ADate := RlEntry.ADate;
            ATime := RlEntry.ATime;
            AKey := RlEntry.AKey;
            AKey2 := RlEntry.AKey2;
          end;
          InputBuffer.Seek(0, soFromBeginning);
          InputBuffer.ReadBuffer(Input^, InputBuffer.Size);
          InputBuffer.Seek(0, soFromBeginning);
          BufferSize := FCGPFunction.FProcessFiles(Input,
            @Entry, Output);
          FileOutBuffer.WriteBuffer(Output^, BufferSize);
          with RlEntry do
          begin
            AName := Trim(Entry.AName);
            ANameLength := Entry.ANameLength;
            AOffset := Entry.AOffset;
            AOrigin := Entry.AOrigin;
            AStoreLength := Entry.AStoreLength;
            ARLength := Entry.ARLength;
            AHash[0] := Entry.AHash[0];
            AHash[1] := Entry.AHash[1];
            AHash[2] := Entry.AHash[2];
            AHash[3] := RlEntry.AHash[3];
            ADate := Entry.ADate;
            ATime := Entry.ATime;
            AKey := Entry.AKey;
            AKey2 := Entry.AKey2;
          end;
        finally
          FCGPFunction.FFreeMemory(Input);
          FCGPFunction.FFreeMemory(Output);
          Output := nil;
        end;
{$ENDIF}
      end;
    ptUnknow:
      Result := False;
  end;
end;

function TGPManager.PackProcessIndex(IndexStream: TIndexStream;
  IndexOutBuffer: TStream): Boolean;
var
  Buffer: Pointer;
  Indexs: TIndexsArray;
  i: Integer;
  BufferSize: Cardinal;
begin
  Result := True;
  case FPluginType of
    ptFastCall:
      Result := FGPFunction.FPackProcessIndex(IndexStream,
        IndexOutBuffer);
    ptStdCall:
      begin
{$IFDEF CSUPPORT}
        Indexs := FCGPFunction.FGetMemory(IndexStream.Count *
          SizeOf(TEntry));
        try
          ZeroMemory(@Indexs[0].AName[0], IndexStream.Count *
            SizeOf(TEntry));
          for i := 0 to IndexStream.Count - 1 do
          begin
            with Indexs[i] do
            begin
              System.Move(Pbyte(IndexStream.RlEntry[i].AName)^,
                AName[ Low(AName)],
                Length(IndexStream.RlEntry[i].AName) *
                SizeOf(char));
              ANameLength := IndexStream.RlEntry[i].ANameLength;
              AOffset := IndexStream.RlEntry[i].AOffset;
              AOrigin := IndexStream.RlEntry[i].AOrigin;
              AStoreLength := IndexStream.RlEntry[i]
                .AStoreLength;
              ARLength := IndexStream.RlEntry[i].ARLength;
              AHash[0] := IndexStream.RlEntry[i].AHash[0];
              AHash[1] := IndexStream.RlEntry[i].AHash[1];
              AHash[2] := IndexStream.RlEntry[i].AHash[2];
              AHash[3] := IndexStream.RlEntry[i].AHash[3];
              ADate := IndexStream.RlEntry[i].ADate;
              ATime := IndexStream.RlEntry[i].ATime;
              AKey := IndexStream.RlEntry[i].AKey;
              AKey2 := IndexStream.RlEntry[i].AKey2;
            end;
          end;
          BufferSize := FCGPFunction.FProcessIndexs(Indexs,
            IndexStream.Count, Buffer);
          IndexOutBuffer.Seek(0, soFromBeginning);
          IndexOutBuffer.WriteBuffer(Buffer^, BufferSize);
          IndexOutBuffer.Seek(0, soFromBeginning);
        finally
          FCGPFunction.FFreeMemory(Indexs);
          FCGPFunction.FFreeMemory(Buffer);
          Buffer := nil;
        end;
{$ENDIF}
      end;
    ptUnknow:
      Result := False;
  end;
end;

function TGPManager.MakePackage(IndexStream: TIndexStream;
  IndexOutBuffer: TStream; FileOutBuffer: TStream;
  Package: TFileBufferStream): Boolean;
var
  Data, Index: Pointer;
  Indexs: TIndexsArray;
  i: Integer;
begin
  Result := True;
  case FPluginType of
    ptFastCall:
      Result := FGPFunction.FMakePackage(IndexStream,
        IndexOutBuffer, FileOutBuffer, Package);
    ptStdCall:
      begin
{$IFDEF CSUPPORT}
        Index := FCGPFunction.FGetMemory(IndexOutBuffer.Size);
        Data := FCGPFunction.FGetMemory(FileOutBuffer.Size);
        Indexs := FCGPFunction.FGetMemory(IndexStream.Count *
          SizeOf(TEntry));
        try
          for i := 0 to IndexStream.Count - 1 do
          begin
            with Indexs[i] do
            begin
              System.Move(Pbyte(IndexStream.RlEntry[i].AName)^,
                AName[ Low(AName)],
                Length(IndexStream.RlEntry[i].AName) *
                SizeOf(char));
              ANameLength := IndexStream.RlEntry[i].ANameLength;
              AOffset := IndexStream.RlEntry[i].AOffset;
              AOrigin := IndexStream.RlEntry[i].AOrigin;
              AStoreLength := IndexStream.RlEntry[i]
                .AStoreLength;
              ARLength := IndexStream.RlEntry[i].ARLength;
              AHash[0] := IndexStream.RlEntry[i].AHash[0];
              AHash[1] := IndexStream.RlEntry[i].AHash[1];
              AHash[2] := IndexStream.RlEntry[i].AHash[2];
              AHash[3] := IndexStream.RlEntry[i].AHash[3];
              ADate := IndexStream.RlEntry[i].ADate;
              ATime := IndexStream.RlEntry[i].ATime;
              AKey := IndexStream.RlEntry[i].AKey;
              AKey2 := IndexStream.RlEntry[i].AKey2;
            end;
          end;
          IndexOutBuffer.Seek(0, soFromBeginning);
          IndexOutBuffer.ReadBuffer(Index^, IndexOutBuffer.Size);
          FileOutBuffer.Seek(0, soFromBeginning);
          FileOutBuffer.ReadBuffer(Data^, FileOutBuffer.Size);
          FCGPFunction.FMakePackage(Indexs, IndexStream.Count,
            Data, FileOutBuffer.Size, Index, IndexOutBuffer.Size,
            Package.Handle);
        finally
          FCGPFunction.FFreeMemory(Index);
          FCGPFunction.FFreeMemory(Data);
          FCGPFunction.FFreeMemory(Indexs);
        end;
{$ENDIF}
      end;
    ptUnknow:
      Result := False;
  end;
end;

end.
