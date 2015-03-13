unit hAutoDetect;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics,
  Controls, Forms,
  Dialogs, StdCtrls, ComCtrls;

type
  TfrmAutoDetect = class(TForm)
    ListView1: TListView;
    Button1: TButton;
    Button2: TButton;
    OpenDialog1: TOpenDialog;
    procedure Button1Click(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormHide(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure ListView1ColumnClick(Sender: TObject;
      Column: TListColumn);
  private
    procedure Process(index: Integer);
    procedure GetList;
  public
    procedure DoAutoDetect;
  end;

  TThreadAutoDetect = class(TThread)
  private
    FProcess: TProc<Integer>;
    FCount: Integer;
  public
    constructor Create(Process: TProc<Integer>; Count: Integer);
    destructor Destroy; override;
    procedure Execute; override;
  end;

var
  frmAutoDetect: TfrmAutoDetect;

const
  sTrue = 'True';
  sFalse = 'False';
  sUnknown = 'Unknow';
  sError = 'Error';
  sUnsupport = 'AutoDetect Unsupported';

implementation

{$R *.dfm}

uses hTypes, PluginFunc;

constructor TThreadAutoDetect.Create(Process: TProc<Integer>;
  Count: Integer);
begin
  inherited Create(True);
  FProcess := Process;
  FCount := Count;
end;

destructor TThreadAutoDetect.Destroy;
begin
  inherited Destroy;
end;

procedure TThreadAutoDetect.Execute;
var
  i: Integer;
begin
  for i := 0 to FCount - 1 do
  begin
    FProcess(i);
    if Terminated then
      Break;
  end;
end;

var
  m_bSort: boolean = True;

function CustomSortProc(Item1, Item2: TListItem;
  ParamSort: Integer): Integer; stdcall;
var
  txt1, txt2: string;
begin
  if ParamSort <> 0 then
  begin
    try
      txt1 := Item1.SubItems.Strings[ParamSort - 1];
      txt2 := Item2.SubItems.Strings[ParamSort - 1];
      if m_bSort then
      begin
        Result := CompareText(txt1, txt2);
      end
      else
      begin
        Result := -CompareText(txt1, txt2);
      end;
    except
    end;
  end
  else
  begin
    if m_bSort then
    begin
      Result := CompareText(Item1.Caption, Item2.Caption);
    end
    else
    begin
      Result := -CompareText(Item1.Caption, Item2.Caption);
    end;
  end;
end;

procedure TfrmAutoDetect.GetList;
var
  GPos: Integer;
  i: Integer;
begin
  GPos := Plugin.Selected;
  for i := 0 to Plugin.Count - 1 do
  begin
    with ListView1.Items.Add do
    begin
      Plugin.LoadPlugin(i);
      Caption := HextoStr(i);
      SubItems.Add(Plugin.GpInfo.AName);
    end;
  end;
  if GPos in [0 .. Plugin.Count] then
    Plugin.LoadPlugin(GPos);
end;

procedure TfrmAutoDetect.ListView1ColumnClick(Sender: TObject;
  Column: TListColumn);
begin
  ListView1.CustomSort(@CustomSortProc, Column.Index);
end;

procedure TfrmAutoDetect.Button2Click(Sender: TObject);
var
  oStatus: TStatus;
begin
  oStatus := Status;
  try
    Status := clExtract;
    if not OpenDialog1.Execute(ClientHandle) then
      Exit;
    OpenPackage(OpenDialog1.FileName);
    try
      ListView1.Clear;
      GetList;
      frmAutoDetect.DoAutoDetect;
    finally
      ClosePackage;
    end;
  finally
    Status := oStatus;
  end;
end;

procedure TfrmAutoDetect.DoAutoDetect;
var
  GPos: Integer;
  ThreadAutoDetect: TThreadAutoDetect;
begin
  GPos := Plugin.Selected;
  ThreadAutoDetect := TThreadAutoDetect.Create(Process,
    Plugin.Count);
  ListView1.ColumnClick := False;
  try
    ThreadAutoDetect.Resume;
    while not ThreadAutoDetect.Finished do
      Application.ProcessMessages;
  finally
    ThreadAutoDetect.Free;
     ListView1.ColumnClick := True;
  end;
  if GPos in [0 .. Plugin.Count - 1] then
    Plugin.LoadPlugin(GPos);
end;

procedure TfrmAutoDetect.FormHide(Sender: TObject);
begin
  ListView1.Clear;
end;

procedure TfrmAutoDetect.FormShow(Sender: TObject);
begin
  ListView1.Clear;
  GetList;
end;

procedure TfrmAutoDetect.Process(index: Integer);
begin
  Plugin.LoadPlugin(index);
  case AutoDetect of
    dsTrue:
      ListView1.Items[index].SubItems.Add(sTrue);
    dsFalse:
      ListView1.Items[index].SubItems.Add(sFalse);
    dsUnknown:
      ListView1.Items[index].SubItems.Add(sUnknown);
    dsError:
      ListView1.Items[index].SubItems.Add(sError);
    dsUnsupport:
      ListView1.Items[index].SubItems.Add(sUnsupport);
  end;
  Plugin.FreePlugin;
end;

procedure TfrmAutoDetect.Button1Click(Sender: TObject);
begin
  Hide;
end;

end.
