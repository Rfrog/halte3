unit hScripts;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics,
  Controls, Forms,
  Dialogs, StdCtrls;

type
  TfrmScripts = class(TForm)
    ListBox1: TListBox;
    Button1: TButton;
    Edit1: TEdit;
    Button2: TButton;
    OpenDialog1: TOpenDialog;
    procedure FormShow(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
  private
    { Private êÈåæ }
  public
    { Public êÈåæ }
  end;

var
  frmScripts: TfrmScripts;

const
  SGPPath = '\SGP\';

implementation

{$R *.dfm}

uses Types, IOUtils, hTypes;

procedure TfrmScripts.Button1Click(Sender: TObject);
var
  Param: string;
begin
  if not(ListBox1.ItemIndex in [0 .. ListBox1.Count - 1]) then
  begin
    Exit;
  end;
  Param := Edit1.Text;
  ScriptManager.RunScript
    (ListBox1.Items[ListBox1.ItemIndex], Param);
  Edit1.Text := Param;
end;

procedure TfrmScripts.Button2Click(Sender: TObject);
begin
  if not OpenDialog1.Execute then
    Exit;
  OpenDialog1.InitialDir := ExtractFilePath(Application.ExeName);
  Edit1.Text := OpenDialog1.FileName;
end;

procedure TfrmScripts.FormShow(Sender: TObject);
var
  List: TStringDynArray;
  i: Integer;
begin
  Position := poMainFormCenter;
  List := TDirectory.GetFiles
    (ExtractFilePath(Application.ExeName) + SGPPath,
    sScriptFilter, TSearchOption.soAllDirectories);
  try
    for i := Low(List) to High(List) do
    begin
      ScriptManager.Add(ScriptManager.GetScriptName(List[i]
        ), List[i]);
      ListBox1.Items.Add(ScriptManager.GetScriptName(List[i]));
      Application.ProcessMessages;
    end;
  finally
    SetLength(List, 0);
  end;
end;

end.
