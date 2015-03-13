unit hSGPSupport;

interface

{$DEFINE SHOWERROR}

uses PaxCompiler, PaxProgram, PaxRegister, Classes, PluginFunc,
  Generics.Collections, IOUtils, Types, SysUtils, CustomStream,
  IMPORT_Classes, IMPORT_Dialogs, IMPORT_SysUtils,
  IMPORT_Variants
{$IFDEF SHOWERROR}
    , Dialogs
{$ENDIF};

const
  sScriptExt = '.SGP';
  sScriptDirectory = 'SGP';
  sScriptFilter = '*.SGP';
  sMain = 'Main';

type

  TMain = procedure();

  TOnProcess = procedure() of object;
  POnProcess = ^TOnProcess;

  // <T,T> = <Name,Path>
  TScriptManager = class(TDictionary<string, string>)
  private
    FItemIndex: string;
    FPaxCompiler1: TPaxCompiler;
    FPaxPascalLanguage1: TPaxPascalLanguage;
    FPaxProgram1: TPaxProgram;

    FIndexStream: TIndexStream;
    FFileBuffer: TFileBufferStream;
    FOutBuffer: TStream;

    FOnProcess: TOnProcess;
  protected
    procedure ExportClasses;
    procedure ExportStream;
    procedure SetOnprocess(AOnProcess: TOnProcess);
    procedure OnCompile(Sender: TPaxCompiler);
  public
    property OnProcess: TOnProcess read FOnProcess
      write SetOnprocess;

    property IndexStream: TIndexStream read FIndexStream
      write FIndexStream;
    property FileBuffer: TFileBufferStream read FFileBuffer
      write FFileBuffer;
    property OutBuffer: TStream read FOutBuffer write FOutBuffer;

    constructor Create;
    destructor Destroy; override;
    procedure Reset;
    procedure RunScript(Name: string; var Param: string);
    procedure GetScriptList(Path: string);
    function GetScriptName(Path: string): string;
  end;

implementation

constructor TScriptManager.Create;
begin
  ExportClasses;
  FPaxCompiler1 := TPaxCompiler.Create(nil);
  FPaxPascalLanguage1 := TPaxPascalLanguage.Create(nil);
  FPaxProgram1 := TPaxProgram.Create(nil);
  FItemIndex := '';
  inherited Create;
end;

destructor TScriptManager.Destroy;
begin
  FPaxCompiler1.Free;
  FPaxPascalLanguage1.Free;
  FPaxProgram1.Free;
  inherited Destroy;
end;

procedure TScriptManager.Reset;
begin
  FPaxCompiler1.Reset;
  FPaxCompiler1.RegisterLanguage(FPaxPascalLanguage1);
  ExportStream;
  FItemIndex := '';
end;

procedure TScriptManager.ExportStream;
begin
  if Assigned(FIndexStream) then
    FPaxCompiler1.RegisterVariable(0, 'SGPIndexStream',
      _typeCLASS, @FIndexStream);
  if Assigned(FFileBuffer) then
    FPaxCompiler1.RegisterVariable(0, 'SGPFileBuffer',
      _typeCLASS, @FFileBuffer);
  if Assigned(FOutBuffer) then
    FPaxCompiler1.RegisterVariable(0, 'SGPOutBuffer', _typeCLASS,
      @FOutBuffer);
end;

procedure TScriptManager.SetOnprocess(AOnProcess: TOnProcess);
begin
  FOnProcess := AOnProcess;
  FPaxCompiler1.OnCompilerProgress := OnCompile;
end;

procedure TScriptManager.OnCompile(Sender: TPaxCompiler);
begin
  if Assigned(FOnProcess) then
    FOnProcess;
end;

procedure TScriptManager.GetScriptList(Path: string);
var
  List: TStringDynArray;
  i: Integer;
begin
  List := TDirectory.GetFiles(Path, sScriptFilter,
    TSearchOption.soAllDirectories);
  try
    for i := Low(List) to High(List) do
    begin
      Add(GetScriptName(List[i]), List[i]);
      FOnProcess;
    end;
  finally
    SetLength(List, 0);
  end;
end;

function TScriptManager.GetScriptName(Path: string): string;
{$IFDEF SHOWERROR}
var
  i: Integer;
{$ENDIF}
begin
  Result := 'GetNameError';
  Reset;
  try
    FPaxCompiler1.AddModule('GETNAME',
      FPaxPascalLanguage1.LanguageName);
    FPaxCompiler1.AddCodeFromFile('GETNAME', Path);
    FPaxCompiler1.RegisterVariable(0, 'SGPPluginName',
      _typeSTRING, @Result);
    FPaxCompiler1.RegisterVariable(0, 'SGPParam',
      _typeSTRING, @Result);
    if FPaxCompiler1.Compile(FPaxProgram1) then
    begin
      FPaxProgram1.Run;
    end
    else
{$IFDEF SHOWERROR}
      for i := 0 to FPaxCompiler1.ErrorCount do
        ShowMessage(FPaxCompiler1.ErrorMessage[i]);
{$ELSE}
      raise Exception.Create('Compile Error');
{$ENDIF}
  finally
    Reset;
  end;
end;

procedure TScriptManager.RunScript(Name: string;
  var Param: string);
var
  ScriptName: string;
  H_P: Integer;
  P: Pointer;
{$IFDEF SHOWERROR}
  i: Integer;
{$ENDIF}
begin
  FItemIndex := Name;
  Reset;
  try
    FPaxCompiler1.AddModule('Main',
      FPaxPascalLanguage1.LanguageName);
    FPaxCompiler1.RegisterVariable(0, 'SGPPluginName',
      _typeSTRING, @ScriptName);
    FPaxCompiler1.RegisterVariable(0, 'SGPParam',
      _typeSTRING, @Param);
    FPaxCompiler1.AddCodeFromFile('Main', Items[Name]);
    if FPaxCompiler1.Compile(FPaxProgram1) then
    begin
      FPaxProgram1.Run;
      if not SameText(ScriptName, Name) then
        raise Exception.Create('Script error.');
      H_P := FPaxCompiler1.GetHandle(0, sMain, true);
      P := FPaxProgram1.GetAddress(H_P);
      TMain(P)();
    end
    else
{$IFDEF SHOWERROR}
      for i := 0 to FPaxCompiler1.ErrorCount do
        ShowMessage(FPaxCompiler1.ErrorMessage[i]);
{$ELSE}
      raise Exception.Create('Compile Error');
{$ENDIF}
  finally
    Reset;
  end;
end;

procedure TScriptManager.ExportClasses;
begin
  Register_Classes;
  Register_Dialogs;
  Register_SysUtils;
  Register_Variants;
end;

end.
