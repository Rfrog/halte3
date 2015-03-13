unit hMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics,
  Controls, Forms,
  Dialogs, Menus, ActnList, StdActns, StdCtrls, CheckLst,
  ComCtrls, CustomStream, CustoManager, hBrowser;

type
  TMainForm = class(TForm)
    MainMenu1: TMainMenu;
    Files1: TMenuItem;
    Edit1: TMenuItem;
    Options1: TMenuItem;
    Help1: TMenuItem;
    About1: TMenuItem;
    ChoosePlugin1: TMenuItem;
    OpenPackage1: TMenuItem;
    Exit1: TMenuItem;
    Search1: TMenuItem;
    SaveInformation1: TMenuItem;
    SavePackage1: TMenuItem;
    Plugin1: TMenuItem;
    Package1: TMenuItem;
    FileList1: TMenuItem;
    ExtractFiles1: TMenuItem;
    ImportFiles1: TMenuItem;
    ListView1: TListView;
    StatusBar1: TStatusBar;
    ProgressBar1: TProgressBar;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    DetectPackage1: TMenuItem;
    RefreshPlugin1: TMenuItem;
    Scripts1: TMenuItem;
    procedure Exit1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure OpenPackage1Click(Sender: TObject);
    procedure SavePackage1Click(Sender: TObject);
    procedure ImportFiles1Click(Sender: TObject);
    procedure ExtractFiles1Click(Sender: TObject);
    procedure ChoosePlugin1Click(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure About1Click(Sender: TObject);
    procedure Search1Click(Sender: TObject);
    procedure Options1Click(Sender: TObject);
    procedure Help1Click(Sender: TObject);
    procedure SaveInformation1Click(Sender: TObject);
    procedure ListView1DblClick(Sender: TObject);
    procedure DetectPackage1Click(Sender: TObject);
    procedure RefreshPlugin1Click(Sender: TObject);
  private
    procedure Initialize;
    procedure Uninitialize;
    procedure AddFileItem(Entry: TRlEntry);
    procedure ClearList;
    procedure GGetIndex;
    procedure GetCheckedFiles;
    procedure SaveConfig;
    procedure LoadConfig;
    procedure OnProcessPlugin;
  protected
    procedure WMDropFiles(var Msg: TMessage); message wm_DropFiles;
  public
    procedure PreviewRes(Index: Integer);
    procedure ClearAllInfo;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

uses ShellAPI, hTypes, IOUtils, Types, hPlugin, hABOUT, hSearch,
  hOption, IniFiles, hHelp, hPreview, hAutoDetect;

procedure TMainForm.ClearAllInfo;
begin
  ClearAll;
  ClearList;
end;

procedure TMainForm.ChoosePlugin1Click(Sender: TObject);
begin
  PluginDialog.Show;
end;

procedure TMainForm.ClearList;
var
  i: Integer;
begin
  for i := 0 to ListView1.Items.Count - 1 do
    (ListView1.Items[i].SubItems.Objects[ListView1.Items[i].SubItems.IndexOf
      (EntryMagic)] as TRlEntry).Free;
  ListView1.Clear;
end;

procedure TMainForm.DetectPackage1Click(Sender: TObject);
var
  oStatus: TStatus;
begin
  oStatus := Status;
  try
    Status := clExtract;
    if not frmAutoDetect.OpenDialog1.Execute(ClientHandle) then
      Exit;
    OpenPackage(frmAutoDetect.OpenDialog1.FileName);
    try
      frmAutoDetect.Show;
      frmAutoDetect.DoAutoDetect;
    finally
      ClosePackage;
    end;
  finally
    Status := oStatus;
  end;
end;

procedure TMainForm.WMDropFiles(var Msg: TMessage);
var
  FileName: array [0 .. 256] of Char;
  FileNameString: string;
begin
  DragQueryFileW(THandle(Msg.WParam), 0, FileName, SizeOf(FileName));
  FileNameString := FileName;
  if PluginStatus <> clUnLoaded then
  begin
    ClearAll;
    ClearList;
    Status := clExtract;
    PackagePath := FileNameString;
    GGetIndex;
  end;
  DragFinish(THandle(Msg.WParam));
end;

procedure TMainForm.SaveConfig;
var
  Config: TIniFile;
begin
  Config := TIniFile.Create(ExtractFilePath(Application.ExeName) + ConfigFile);
  try
    Config.WriteString(ConfigSection, ConfigFontName, ListView1.Font.Name);
    Config.WriteInteger(ConfigSection, ConfigFontSize, ListView1.Font.Size);
    Config.WriteInteger(ConfigSection, ConfigFormHeight, MainForm.Height);
    Config.WriteInteger(ConfigSection, ConfigFormWidth, MainForm.Width);
    case Bufferoption of
      clMemoryBuffer:
        Config.WriteInteger(ConfigSection, ConfigStreamMode, 0);
      clFileBuffer:
        Config.WriteInteger(ConfigSection, ConfigStreamMode, 1);
    end;
  finally
    Config.Free;
  end;
end;

procedure TMainForm.SaveInformation1Click(Sender: TObject);
const
  FormatStr = '%:-20s|';
var
  StrList: TStringList;
  Str: string;
  Line: string;
  i, j: Integer;
begin
  if not SaveDialog1.Execute(Handle) then
    Exit;
  StrList := TStringList.Create;
  try
    Str := '';
    Line := '';
    for i := 0 to ListView1.Columns.Count - 1 do
    begin
      Str := Str + Format(FormatStr, [ListView1.Columns[i].Caption]);
      Line := Line + '--------------------+';
    end;
    StrList.Add(Str);
    StrList.Add(Line);
    for j := 0 to ListView1.Items.Count - 1 do
    begin
      Str := Format(FormatStr, [ListView1.Items[j].Caption]);
      for i := 1 to ListView1.Columns.Count - 1 do
        Str := Str + Format(FormatStr, [ListView1.Items[j].SubItems[i - 1]]);
      StrList.Add(Str);
    end;
    StrList.SaveToFile(SaveDialog1.FileName);
  finally
    StrList.Free;
  end;
end;

procedure TMainForm.PreviewRes(Index: Integer);
var
  tmpEntry: TRlEntry;
  Buffer: TMemoryStream;
begin
  if (Index < 0) or (Index >= ListView1.Items.Count) then
    Exit;
  case Status of
    clExtract:
      begin
        IndexStream.Clear;
        tmpEntry := TRlEntry.Create;
        tmpEntry.Assign(TRlEntry(ListView1.Items[Index].SubItems.Objects
          [ListView1.Items[Index].SubItems.IndexOf(EntryMagic)]));
        IndexStream.Add(tmpEntry);
        OpenPackage(PackagePath);
        Buffer := TMemoryStream.Create;
        try
          ExtractFile(0, Buffer);
          PreviewDialog.Preview(Buffer, ListView1.Items[Index].SubItems[0]);
          PreviewDialog.Show;
        finally
          ClosePackage;
          Buffer.Free;
        end;
      end;
    clPack:
      begin
        Buffer := TMemoryStream.Create;
        try
          Buffer.LoadFromFile(IndexStream.ParentPath + ListView1.Items[Index]
            .SubItems[0]);
          PreviewDialog.Preview(Buffer, ListView1.Items[Index].SubItems[0]);
          PreviewDialog.Show;
        finally
          Buffer.Free;
        end;
      end;
  end;
end;

procedure TMainForm.RefreshPlugin1Click(Sender: TObject);
var
  i: Integer;
begin
  if not DirectoryExists(ExtractFilePath(Application.ExeName) + GPluginPath)
  then
    ForceDirectories(ExtractFilePath(Application.ExeName) + GPluginPath);
  Plugin.FreePlugin;
  Plugin.Clear;
  PluginDialog.PluginList.Clear;
  PluginDialog.Show;
  Plugin.GenerateGPList(ExtractFilePath(Application.ExeName) + GPluginPath);
  for i := 0 to Plugin.Count - 1 do
  begin
    PluginDialog.PluginList.Items.Add(Plugin[i]);
    Application.ProcessMessages;
  end;
  Plugin.Selected := -1;
end;

procedure TMainForm.ListView1DblClick(Sender: TObject);
begin
  PreviewRes(ListView1.ItemIndex);
end;

procedure TMainForm.OnProcessPlugin;
begin
  Application.ProcessMessages;
end;

procedure TMainForm.LoadConfig;
var
  Config: TIniFile;
  i: Integer;
begin
  Config := TIniFile.Create(ExtractFilePath(Application.ExeName) + ConfigFile);
  try
    ListView1.Font.Name := Config.ReadString(ConfigSection, ConfigFontName,
      ListView1.Font.Name);
    ListView1.Font.Size := Config.ReadInteger(ConfigSection, ConfigFontSize,
      ListView1.Font.Size);
    i := Config.ReadInteger(ConfigSection, ConfigStreamMode, 0);
    MainForm.Height := Config.ReadInteger(ConfigSection, ConfigFormHeight,
      MainForm.Height);
    MainForm.Width := Config.ReadInteger(ConfigSection, ConfigFormWidth,
      MainForm.Width);
    case i of
      0:
        Bufferoption := clMemoryBuffer;
      1:
        Bufferoption := clFileBuffer;
    else
      raise Exception.Create('Config File Error.');
    end;
  finally
    Config.Free;
  end;
end;

procedure TMainForm.About1Click(Sender: TObject);
begin
  AboutBox.Show;
end;

procedure TMainForm.AddFileItem(Entry: TRlEntry);
begin
  with ListView1.Items.Add do
  begin
    Caption := HextoStr(ListView1.Items.Count);
    SubItems.Add(Entry.AName);
    SubItems.Add(HextoStr(Entry.AOffset));
    SubItems.Add(HextoStr(Entry.AStoreLength));
    SubItems.Add(HextoStr(Entry.ARLength));
    SubItems.AddObject(EntryMagic, Entry);
    Checked := True;
  end;
end;

procedure TMainForm.Exit1Click(Sender: TObject);
begin
  Application.Terminate;
end;

procedure TMainForm.GetCheckedFiles;
var
  tmpEntry: TRlEntry;
  i: Integer;
begin
  IndexStream.Clear;
  for i := 0 to ListView1.Items.Count - 1 do
    if ListView1.Items[i].Checked then
    begin
      tmpEntry := TRlEntry.Create;
      tmpEntry.Assign(TRlEntry(ListView1.Items[i].SubItems.Objects
        [ListView1.Items[i].SubItems.IndexOf(EntryMagic)]));
      IndexStream.Add(tmpEntry);
    end;
end;

procedure TMainForm.ExtractFiles1Click(Sender: TObject);
var
  Percent: Word;
  Path: string;
begin
  if Status <> clExtract then
    raise Exception.Create('Error RunTime AppType.');
  if ListView1.Items.Count < 1 then
    Exit;
  Path := BrowseForFolder('Choose Folder',
    ExtractFilePath(Application.ExeName) + '\');
  if not DirectoryExists(Path) then
    Exit;
  GetCheckedFiles;
  OpenPackage(PackagePath);
  try
    GetFiles := TFileTaskPool.Create(Percent, Path + '\');
    try
      GetFiles.Resume;
      while not GetFiles.Finished do
      begin
        ProgressBar1.Position := Percent;
        Application.ProcessMessages;
      end;
      ProgressBar1.Position := 100;
    finally
      GetFiles.Free;
    end;
  finally
    ClosePackage;
  end;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  Initialize;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  Uninitialize;
end;

procedure TMainForm.FormResize(Sender: TObject);
begin
  ListView1.Height := ClientHeight * intListHeight div intMaxPercent;
  StatusBar1.Height := ClientHeight * intStatHeight div intMaxPercent;
  ProgressBar1.Height := ClientHeight * intProgressBarHeight div intMaxPercent;
end;

procedure TMainForm.FormShow(Sender: TObject);
var
  i: Integer;
begin
  if not DirectoryExists(ExtractFilePath(Application.ExeName) + GPluginPath)
  then
    ForceDirectories(ExtractFilePath(Application.ExeName) + GPluginPath);
  PluginDialog.Show;
  Plugin.GenerateGPList(ExtractFilePath(Application.ExeName) + GPluginPath);
  for i := 0 to Plugin.Count - 1 do
  begin
    PluginDialog.PluginList.Items.Add(Plugin[i]);
    Application.ProcessMessages;
  end;
  Plugin.Selected := -1;
end;

procedure TMainForm.ImportFiles1Click(Sender: TObject);
var
  List: TStringDynArray;
  i: Integer;
  TestBuffer: TFileStream;
  RlEntry: TRlEntry;
  virtualSize: Cardinal;
  Path: string;
begin
  Path := BrowseForFolder('Choose Folder',
    ExtractFilePath(Application.ExeName) + '\');
  if not DirectoryExists(Path) then
    Exit;
  ClearAll;
  ClearList;
  Status := clPack;
  List := TDirectory.GetFiles(Path, '*.*',
    TSearchOption.soAllDirectories);
  IndexStream.ParentPath := Path + '\';
  virtualSize := 0;
  for i := Low(List) to High(List) do
  begin
    RlEntry := TRlEntry.Create;
    TestBuffer := TFileStream.Create(List[i], fmOpenRead);
    Delete(List[i], 1, Length(Path) + 1);
    RlEntry.AName := List[i];
    RlEntry.AOffset := virtualSize;
    RlEntry.ARLength := TestBuffer.Size;
    RlEntry.AStoreLength := RlEntry.ARLength;
    virtualSize := virtualSize + RlEntry.ARLength;
    TestBuffer.Free;
    AddFileItem(RlEntry);
    ProgressBar1.Position := 100 * (i + 1) div High(List);
    Application.ProcessMessages;
  end;
  ProgressBar1.Position := 100;
end;

procedure TMainForm.Initialize;
begin
  DragAcceptFiles(Handle, True);
  IndexStream := TIndexStream.Create;
  Plugin := TGPManager.Create;
  Plugin.OnProcessList := OnProcessPlugin;
  Plugin.Selected := -1;
  ProgressBar1.Min := 0;
  ProgressBar1.Max := 100;
  ListView1.Clear;
  ClearAll;
  LoadConfig;
end;

procedure TMainForm.GGetIndex;
var
  i: Integer;
  tmpEntry: TRlEntry;
begin
  OpenPackage(PackagePath);
  try
    GetIndex := TIndexTaskPool.Create;
    try
      GetIndex.Resume;
      while not GetIndex.Finished do
        Application.ProcessMessages;
    finally
      GetIndex.Free;
    end;
    for i := 0 to IndexStream.Count - 1 do
    begin
      tmpEntry := TRlEntry.Create;
      tmpEntry.Assign(IndexStream.RlEntry[i]);
      AddFileItem(tmpEntry);
      ProgressBar1.Position := 100 * (i + 1) div IndexStream.Count;
      Application.ProcessMessages;
    end;
    ProgressBar1.Position := 100;
  finally
    ClosePackage;
    Status := clExtract;
  end;
end;

procedure TMainForm.Help1Click(Sender: TObject);
begin
  HelpForm.Show;
end;

procedure TMainForm.OpenPackage1Click(Sender: TObject);
begin
  if PluginStatus = clUnLoaded then
    raise Exception.Create('Plugin Uninitialized.');
  if not OpenDialog1.Execute(Handle) then
    Exit;
  ClearAll;
  ClearList;
  Status := clExtract;
  PackagePath := OpenDialog1.FileName;
  GGetIndex;
end;

procedure TMainForm.Options1Click(Sender: TObject);
begin
  OptionForm.Show;
end;

procedure TMainForm.SavePackage1Click(Sender: TObject);
var
  Percent: Word;
begin
  if PluginStatus = clUnLoaded then
    raise Exception.Create('Plugin Uninitialized.');
  if Status <> clPack then
    raise Exception.Create('Error RunTime AppType.');
  if not SaveDialog1.Execute(Handle) then
    Exit;
  PackagePath := SaveDialog1.FileName;
  GetCheckedFiles;
  OpenPackage(PackagePath);
  try
    PackFiles := TPackTaskPool.Create(Percent);
    try
      PackFiles.Resume;
      while not PackFiles.Finished do
      begin
        ProgressBar1.Position := Percent;
        Application.ProcessMessages;
      end;
      ProgressBar1.Position := 100;
    finally
      PackFiles.Free;
    end;
  finally
    ClosePackage;
  end;
end;

procedure TMainForm.Search1Click(Sender: TObject);
begin
  Search.Show;
end;

procedure TMainForm.Uninitialize;
begin
  SaveConfig;
  ClearList;
  ClearAll;
  IndexStream.Free;
  Plugin.Free;
end;

end.
