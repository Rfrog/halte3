unit hTypes;

interface

uses SysUtils, CustomStream, CustoManager, Classes, Windows,
  PluginFunc;

type
  TStatus = (clExtract, clPack, clNone);
  TBufferOption = (clFileBuffer, clMemoryBuffer);
  TPluginStatus = (clUnLoaded, clGPLoaded);

  TFileTaskPool = class(TThread)
  private
    FPercent: PWord;
    FPath: string;
  public
    constructor Create(var Percent: Word; Path: string);
    destructor Destroy; override;
    procedure Execute; override;
  end;

  TIndexTaskPool = class(TThread)
  public
    constructor Create;
    destructor Destroy; override;
    procedure Execute; override;
  end;

  TPackTaskPool = class(TThread)
  private
    FPPercent: PWord;
  public
    constructor Create(var Percent: Word);
    destructor Destroy; override;
    procedure Execute; override;
  end;

const
  intMaxPercent = 100;
  intListHeight = 90;
  intStatHeight = 5;
  intProgressBarHeight = 5;
  EntryMagic = 'Halte3-$-AEntry-V1';
  GPluginPath = '\GP\';

  ConfigFile = '\halte3.ini';
  ConfigSection = 'Config';
  ConfigFontName = 'Fontname';
  ConfigFontSize = 'Fontsize';
  ConfigStreamMode = 'StreamMode';
  ConfigFormHeight = 'FormHeight';
  ConfigFormWidth = 'FormWidth';
  ConfigPlugin = 'PluginIndex';

const
  AppName = 'Halte3';
  Producer = 'HatsuneTakumi';
  Mail = #13#10 + 'HatsuneTakumi@vip.qq.com';

var
  IndexStream: TIndexStream;
  Buffer: TFileBufferStream;
  Plugin: TGPManager;
  GetFiles: TFileTaskPool;
  GetIndex: TIndexTaskPool;
  PackFiles: TPackTaskPool;
  Status: TStatus = clNone;
  Bufferoption: TBufferOption = clMemoryBuffer;
  PluginStatus: TPluginStatus = clUnLoaded;
  PackagePath: string;

function HextoStr(Value: Cardinal): string;
function FormatVersion(Version: Cardinal): string;
procedure OpenPackage(Package: string);
function AutoDetect: TDetectState;
procedure ExtractIndexs;
procedure ExtractFile(Name: string; Output: TStream); overload;
procedure ExtractFile(Index: Integer; Output: TStream); overload;
procedure PackFile(var Percent: Word);
procedure ClosePackage;
procedure ClearAll;

implementation

procedure ClearAll;
begin
  IndexStream.Clear;
  Status := clNone;
end;

constructor TFileTaskPool.Create;
begin
  inherited Create(True);
  FPercent := @Percent;
  FPath := Path;
end;

destructor TFileTaskPool.Destroy;
begin
  inherited Destroy;
end;

procedure TFileTaskPool.Execute;
var
  i: Integer;
  Stream: TStream;
begin
  FPercent^ := 0;
  for i := 0 to Buffer.Indexs - 1 do
  begin
    if Terminated then
      Exit;
    if not DirectoryExists
      (ExtractFilePath(FPath + IndexStream.RlEntry[i]
      .AName)) then
      ForceDirectories
        (ExtractFilePath(FPath + IndexStream.RlEntry[i].AName));
    case Bufferoption of
      clFileBuffer:
        begin
          Stream := TFileStream.Create
            (FPath + IndexStream.RlEntry[i].AName, fmCreate);
          try
            ExtractFile(i, Stream);
          finally
            Stream.free;
          end;
          FPercent^ := 100 * (i + 1) div IndexStream.Count;
        end;
      clMemoryBuffer:
        begin
          Stream := TMemoryStream.Create;
          try
            ExtractFile(i, Stream);
            (Stream as TMemoryStream)
              .SaveToFile(FPath + IndexStream.RlEntry[i].AName);
          finally
            Stream.free;
          end;
          FPercent^ := 100 * (i + 1) div IndexStream.Count;
        end;
    end;
  end;
  FPercent^ := 100;
end;

constructor TIndexTaskPool.Create;
begin
  inherited Create(True);
end;

destructor TIndexTaskPool.Destroy;
begin
  inherited Destroy;
end;

procedure TIndexTaskPool.Execute;
begin
  ExtractIndexs;
end;

constructor TPackTaskPool.Create;
begin
  inherited Create(True);
  FPPercent := @Percent;
end;

destructor TPackTaskPool.Destroy;
begin
  inherited Destroy;
end;

procedure TPackTaskPool.Execute;
begin
  PackFile(FPPercent^);
end;

function HextoStr;
begin
  Result := '$' + IntToHex(Value, 8);
end;

function FormatVersion;
begin
  Result := Format('%d.%d.%d.%d', [Byte(Version shr 24),
    Byte(Version shr 16), Byte(Version shr 8), Byte(Version)])
end;

function AutoDetect: TDetectState;
begin
  Buffer.Seek(0, soFromBeginning);
  if Plugin.GpInfo.ASupportAutoDetect = 0 then
    Result := dsUnsupport
  else
    Result := Plugin.AutoDetect(Buffer);
  Buffer.Seek(0, soFromBeginning);
end;

procedure ExtractIndexs;
begin
  Plugin.GenerateEntry(IndexStream, Buffer);
end;

procedure ExtractFile(Name: string; Output: TStream);
begin
  Buffer.EntrySelected := IndexStream.IndexOf(Name);
  Plugin.ReadData(Buffer, Output);
end;

procedure ExtractFile(Index: Integer; Output: TStream);
begin
  Buffer.EntrySelected := Index;
  Plugin.ReadData(Buffer, Output);
end;

procedure PackFile;
var
  InputStream, FileOutBuffer, IndexOutBuffer: TStream;
  i: Integer;
  PPath, POutFile, PIndexFile: array [0 .. 100] of WideChar;
begin
  case Plugin.GpInfo.ASupportPack of
    0:
      begin
        Plugin.PackData(IndexStream, Buffer, Percent);
      end;
    1:
      begin
        case Bufferoption of
          clFileBuffer:
            begin
              Percent := 0;
              GetTempPath(100, PPath);
              GetTempFileName(PPath, 'Halte', 0, POutFile);
              FileOutBuffer := TFileStream.Create(POutFile,
                fmCreate);
              GetTempFileName(PPath, 'Halte', 0, PIndexFile);
              IndexOutBuffer := TFileStream.Create(PIndexFile,
                fmCreate);
              try
                for i := 0 to IndexStream.Count - 1 do
                begin
                  InputStream :=
                    TFileStream.Create(IndexStream.ParentPath +
                    IndexStream.RlEntry[i].AName, fmOpenRead);
                  try
                    InputStream.Seek(0, soFromBeginning);
                    begin
                      IndexStream.RlEntry[i].ANameLength :=
                        Length(IndexStream.RlEntry[i].AName) *
                        SizeOf(char);
                      IndexStream.RlEntry[i].ARLength :=
                        InputStream.Size;
                      IndexStream.RlEntry[i].AStoreLength :=
                        IndexStream.RlEntry[i].ARLength;
                      IndexStream.RlEntry[i].AOrigin :=
                        soFromBeginning;
                    end;
                    Plugin.PackProcessData
                      (IndexStream.RlEntry[i], InputStream,
                      FileOutBuffer);
                  finally
                    InputStream.free;
                  end;
                  Percent := 80 * (i + 1) div IndexStream.Count;
                end;
                IndexOutBuffer.Seek(0, soFromBeginning);
                Plugin.PackProcessIndex(IndexStream,
                  IndexOutBuffer);
                Percent := 90;
                FileOutBuffer.Seek(0, soFromBeginning);
                IndexOutBuffer.Seek(0, soFromBeginning);
                Buffer.Seek(0, soFromBeginning);
                Plugin.MakePackage(IndexStream, IndexOutBuffer,
                  FileOutBuffer, Buffer);
                Percent := 100;
              finally
                FileOutBuffer.free;
                IndexOutBuffer.free;
                Deletefile(POutFile);
                Deletefile(PIndexFile);
              end;
            end;
          clMemoryBuffer:
            begin
              InputStream := TMemoryStream.Create;
              FileOutBuffer := TMemoryStream.Create;
              IndexOutBuffer := TMemoryStream.Create;
              try
                for i := 0 to IndexStream.Count - 1 do
                begin
                  (InputStream as TMemoryStream).Clear;
                  (InputStream as TMemoryStream)
                    .LoadFromFile(IndexStream.ParentPath +
                    IndexStream.RlEntry[i].AName);
                    begin
                      IndexStream.RlEntry[i].ANameLength :=
                        Length(IndexStream.RlEntry[i].AName) *
                        SizeOf(char);
                      IndexStream.RlEntry[i].ARLength :=
                        InputStream.Size;
                      IndexStream.RlEntry[i].AStoreLength :=
                        IndexStream.RlEntry[i].ARLength;
                      IndexStream.RlEntry[i].AOrigin :=
                        soFromBeginning;
                    end;
                  InputStream.Seek(0, soFromBeginning);
                  Plugin.PackProcessData(IndexStream.RlEntry[i],
                    InputStream, FileOutBuffer);
                  Percent := 80 * (i + 1) div IndexStream.Count;
                end;
                IndexOutBuffer.Seek(0, soFromBeginning);
                Plugin.PackProcessIndex(IndexStream,
                  IndexOutBuffer);
                Percent := 90;
                FileOutBuffer.Seek(0, soFromBeginning);
                IndexOutBuffer.Seek(0, soFromBeginning);
                Buffer.Seek(0, soFromBeginning);
                Plugin.MakePackage(IndexStream, IndexOutBuffer,
                  FileOutBuffer, Buffer);
                Percent := 100;
              finally
                InputStream.free;
                FileOutBuffer.free;
                IndexOutBuffer.free;
              end;
            end;
        else
          raise Exception.Create('Stream mode error.');
        end;
      end;
    -1:
      raise Exception.Create('This plugin do not support pack.');
  end;
end;

procedure OpenPackage;
begin
  case Status of
    clExtract:
      begin
        Buffer := TFileBufferStream.Create(Package, fmOpenRead);
        Buffer.SetIndexStream(IndexStream);
      end;
    clPack:
      begin
        Buffer := TFileBufferStream.Create(Package, fmCreate);
        Buffer.SetIndexStream(IndexStream);
      end;
    clNone:
      raise Exception.Create('RunTime type undefined.');
  end;

end;

procedure ClosePackage;
begin
  Buffer.free;
  case Status of
    clExtract:
      IndexStream.Clear;
    clPack:
      IndexStream.Clear;
    clNone:
      raise Exception.Create('RunTime type undefined.');
  end;
end;

end.
