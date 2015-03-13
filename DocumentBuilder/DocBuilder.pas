unit DocBuilder;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics,
  Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, ComCtrls, hDocumentTypes,
  StrUtils;

type
  TForm6 = class(TForm)
    LabeledEdit1: TLabeledEdit;
    LabeledEdit2: TLabeledEdit;
    LabeledEdit3: TLabeledEdit;
    LabeledEdit4: TLabeledEdit;
    Button1: TButton;
    Button2: TButton;
    ListView1: TListView;
    Button3: TButton;
    Button4: TButton;
    CheckBox1: TCheckBox;
    CheckBox2: TCheckBox;
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure ListView1Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
  private
    Nodes: TDataConnect;
  public
    function GetState: string;
    procedure SetState;
  end;

var
  Form6: TForm6;

implementation

{$R *.dfm}

const
  HelpDocument = '\SupportList.Dat';

function TForm6.GetState;
begin
  Result := '';
  if CheckBox1.Checked then
    Result := Result + '[E]';
  if CheckBox2.Checked then
    Result := Result + '[P]';
end;

procedure TForm6.SetState;
begin
  if ContainsText(ListView1.Items[ListView1.ItemIndex].SubItems
    [3], '[E]') then
    CheckBox1.Checked := True
  else
    CheckBox1.Checked := False;
  if ContainsText(ListView1.Items[ListView1.ItemIndex].SubItems
    [3], '[P]') then
    CheckBox2.Checked := True
  else
    CheckBox2.Checked := False;
end;

procedure TForm6.Button1Click(Sender: TObject);
begin
  with ListView1.Items.Add do
  begin
    Caption := Trim(LabeledEdit1.Text);
    SubItems.Add(Trim(LabeledEdit2.Text));
    SubItems.Add(Trim(LabeledEdit3.Text));
    SubItems.Add(Trim(LabeledEdit4.Text));
    SubItems.Add(Trim(GetState));
  end;
  LabeledEdit1.Clear;
  LabeledEdit2.Clear;
  LabeledEdit3.Clear;
  LabeledEdit4.Clear;
end;

procedure TForm6.Button2Click(Sender: TObject);
var
  I: Integer;
  tmpNode: TRecNode;
  dataNode: TDataNode;
begin
  Nodes.NodeList.Clear;
  for I := 0 to ListView1.Items.Count - 1 do
  begin
    ZeroMemory(@tmpNode.AEngine[1], SizeOf(TRecNode));
    with tmpNode do
    begin
      MoveChars(Pbyte(ListView1.Items[I].Caption)^, AEngine[1],
        Length(ListView1.Items[I].Caption));
      MoveChars(Pbyte(ListView1.Items[I].SubItems[0])^, AName[1],
        Length(ListView1.Items[I].SubItems[0]));
      MoveChars(Pbyte(ListView1.Items[I].SubItems[1])^,
        AGameMaker[1], Length(ListView1.Items[I].SubItems[1]));
      MoveChars(Pbyte(ListView1.Items[I].SubItems[2])^,
        AExtension[1], Length(ListView1.Items[I].SubItems[2]));
      MoveChars(Pbyte(ListView1.Items[I].SubItems[3])^,
        AState[1], Length(ListView1.Items[I].SubItems[3]));
    end;
    dataNode := TDataNode.Create;
    dataNode.Assign(tmpNode);
    Nodes.NodeList.Add(dataNode);
  end;
  Nodes.SaveDocument(ExtractFilePath(Application.ExeName) +
    HelpDocument);
end;

procedure TForm6.Button3Click(Sender: TObject);
begin
  ListView1.Items.Delete(ListView1.ItemIndex);
end;

procedure TForm6.Button4Click(Sender: TObject);
begin
  ListView1.Items[ListView1.ItemIndex].Caption :=
    LabeledEdit1.Text;
  ListView1.Items[ListView1.ItemIndex].SubItems[0] :=
    LabeledEdit2.Text;
  ListView1.Items[ListView1.ItemIndex].SubItems[1] :=
    LabeledEdit3.Text;
  ListView1.Items[ListView1.ItemIndex].SubItems[2] :=
    LabeledEdit4.Text;
  ListView1.Items[ListView1.ItemIndex].SubItems[3] := GetState;
end;

procedure TForm6.FormCreate(Sender: TObject);
var
  I: Integer;
begin
  Nodes := TDataConnect.Create;
  if FileExists(ExtractFilePath(Application.ExeName) +
    HelpDocument) then
    Nodes.LoadDocument(ExtractFilePath(Application.ExeName) +
      HelpDocument);
  for I := 0 to Nodes.NodeList.Count - 1 do
  begin
    with ListView1.Items.Add do
    begin
      Caption := Trim(Nodes.NodeList[I].AEngine);
      SubItems.Add(Trim(Nodes.NodeList[I].AName));
      SubItems.Add(Trim(Nodes.NodeList[I].AGameMaker));
      SubItems.Add(Trim(Nodes.NodeList[I].AExtension));
      SubItems.Add(Trim(Nodes.NodeList[I].AState));
    end;
    Application.ProcessMessages;
  end;
end;

procedure TForm6.FormDestroy(Sender: TObject);
begin
  Nodes.Free;
end;

procedure TForm6.ListView1Click(Sender: TObject);
begin
  LabeledEdit1.Text := ListView1.Items
    [ListView1.ItemIndex].Caption;
  LabeledEdit2.Text := ListView1.Items[ListView1.ItemIndex]
    .SubItems[0];
  LabeledEdit3.Text := ListView1.Items[ListView1.ItemIndex]
    .SubItems[1];
  LabeledEdit4.Text := ListView1.Items[ListView1.ItemIndex]
    .SubItems[2];
  SetState;
end;

end.
