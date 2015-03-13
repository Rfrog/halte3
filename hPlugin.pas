unit hPlugin;

interface

uses Windows, SysUtils, Classes, Graphics, Forms, Controls,
  StdCtrls,
  Buttons, ExtCtrls;

type
  TPluginDialog = class(TForm)
    OKBtn: TButton;
    CancelBtn: TButton;
    Bevel1: TBevel;
    PluginList: TListBox;
    LabeledEdit1: TLabeledEdit;
    GroupBox1: TGroupBox;
    CheckBox1: TCheckBox;
    CheckBox2: TCheckBox;
    CheckBox3: TCheckBox;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    procedure CancelBtnClick(Sender: TObject);
    procedure OKBtnClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure PluginListDblClick(Sender: TObject);
    procedure LabeledEdit1Change(Sender: TObject);
    function CheckPluginName(Name: string): Boolean;
  private
    procedure LoadPlugin;
  public

  end;

var
  PluginDialog: TPluginDialog;

implementation

uses hTypes, hMain, StrUtils;

{$R *.dfm}

const
  FASTCALLLAB = '[D]';
  STDCALLLAB = '[C]';
  TitleLab = '[N]';
  MakerLab = '[M]';
  EngineLab = '[E]';

procedure TPluginDialog.CancelBtnClick(Sender: TObject);
begin
  Hide;
end;

procedure TPluginDialog.FormShow(Sender: TObject);
begin
  PluginList.ItemIndex := Plugin.Selected;
end;

function TPluginDialog.CheckPluginName(Name: string): Boolean;
var
  Lab1, Lab2: String[3];
begin
  Result := False;
  try
    Lab1 := LeftStr(Name, 3);
    Lab2 := Copy(Name, 4, 3);
    if not(SameText(Lab1, FASTCALLLAB) or SameText(Lab1,
      STDCALLLAB)) then
      Exit;
    if CheckBox1.Checked and SameText(Lab2, TitleLab) then
    begin
      Result := True;
      Exit;
    end;
    if CheckBox2.Checked and SameText(Lab2, MakerLab) then
    begin
      Result := True;
      Exit;
    end;
    if CheckBox3.Checked and SameText(Lab2, EngineLab) then
    begin
      Result := True;
      Exit;
    end;
  finally

  end;
end;

procedure TPluginDialog.LabeledEdit1Change(Sender: TObject);
var
  i: Integer;
begin
  for i := 0 to PluginList.Count - 1 do
  begin
    if not CheckPluginName(PluginList.Items[i]) then
    Continue;
    if ContainsText(PluginList.Items[i], LabeledEdit1.Text) then
    begin
      PluginList.ItemIndex := i;
      Break;
    end;
  end;
end;

procedure TPluginDialog.LoadPlugin;
begin
  Plugin.LoadPlugin(Plugin.IndexOf(PluginList.Items
    [PluginList.ItemIndex]));
  PluginStatus := clGPLoaded;
  MainForm.Caption := PluginList.Items[PluginList.ItemIndex];
end;

procedure TPluginDialog.OKBtnClick(Sender: TObject);
begin
  if PluginList.ItemIndex < 0 then
    raise Exception.Create('Plugin not selected.');
  try
    MainForm.ClearAllInfo;
    LoadPlugin;
  finally
    Hide;
  end;
end;

procedure TPluginDialog.PluginListDblClick(Sender: TObject);
begin
  if PluginList.ItemIndex < 0 then
    raise Exception.Create('Plugin not selected.');
  try
    MainForm.ClearAllInfo;
    LoadPlugin;
  finally
    Hide;
  end;
end;

end.
