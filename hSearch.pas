unit hSearch;

interface

uses Windows, SysUtils, Classes, Graphics, Forms, Controls,
  StdCtrls,
  Buttons, ExtCtrls, ComCtrls;

type
  TSearch = class(TForm)
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    TabSheet3: TTabSheet;
    TabSheet4: TTabSheet;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    GroupBox3: TGroupBox;
    CheckBox1: TCheckBox;
    CheckBox2: TCheckBox;
    CheckBox3: TCheckBox;
    CheckBox4: TCheckBox;
    CheckBox5: TCheckBox;
    CheckBox6: TCheckBox;
    CheckBox7: TCheckBox;
    CheckBox8: TCheckBox;
    CheckBox9: TCheckBox;
    LabeledEdit1: TLabeledEdit;
    LabeledEdit2: TLabeledEdit;
    LabeledEdit3: TLabeledEdit;
    LabeledEdit4: TLabeledEdit;
    RadioGroup1: TRadioGroup;
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    LabeledEdit5: TLabeledEdit;
    LabeledEdit6: TLabeledEdit;
    RadioGroup2: TRadioGroup;
    Label1: TLabel;
    Button4: TButton;
    Button5: TButton;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
  private
    procedure SelectItem(Index: Integer; Stat: Boolean);
    function CheckExtension(Name: string; ExtList: TStringList): Boolean;
    function CheckKeyWord(Name: string; ExtList: TStringList): Boolean;
  public

  end;

var
  Search: TSearch;

const
  Music: array [0 .. 2] of string = ('.ogg', '.MP3', '.WAV');

  Graphic: array [0 .. 3] of string = ('.jpg', '.BMP', '.PNG', '.TGA');

  Script: array [0 .. 1] of string = ('.TXT', '.KS');

implementation

{$R *.dfm}

uses hMain, StrUtils, Types;

procedure TSearch.SelectItem(Index: Integer; Stat: Boolean);
begin
  if (Index < 0) or (Index > MainForm.ListView1.Items.Count) then
    Exit;
  MainForm.ListView1.Items[Index].Checked := Stat;
end;

procedure TSearch.Button1Click(Sender: TObject);
var
  i: Integer;
begin
  inherited;
  for i := 0 to MainForm.ListView1.Items.Count - 1 do
    SelectItem(i, True);
end;

procedure TSearch.Button2Click(Sender: TObject);
var
  i: Integer;
begin
  inherited;
  for i := 0 to MainForm.ListView1.Items.Count - 1 do
    SelectItem(i, False);
end;

procedure TSearch.Button3Click(Sender: TObject);
var
  i: Integer;
begin
  inherited;
  for i := 0 to MainForm.ListView1.Items.Count - 1 do
    SelectItem(i, not MainForm.ListView1.Items[i].Checked);
end;

procedure TSearch.Button4Click(Sender: TObject);
var
  tmpList: TStringList;
  KeyWordList: TStringDynArray;
  i: Integer;
begin
  inherited;
  tmpList := TStringList.Create;
  try
    case PageControl1.ActivePageIndex of
      0:
        begin
          tmpList.Clear;
          if CheckBox1.Checked then
            tmpList.Add(Music[0]);
          if CheckBox2.Checked then
            tmpList.Add(Music[1]);
          if CheckBox3.Checked then
            tmpList.Add(Music[2]);
          if CheckBox4.Checked then
            tmpList.Add(Graphic[0]);
          if CheckBox5.Checked then
            tmpList.Add(Graphic[1]);
          if CheckBox6.Checked then
            tmpList.Add(Graphic[2]);
          if CheckBox7.Checked then
            tmpList.Add(Graphic[3]);
          if CheckBox8.Checked then
            tmpList.Add(Script[0]);
          if CheckBox9.Checked then
            tmpList.Add(Script[1]);
          if Trim(LabeledEdit1.Text) <> '' then
            tmpList.Add(Trim(LabeledEdit1.Text));
          if Trim(LabeledEdit2.Text) <> '' then
            tmpList.Add(Trim(LabeledEdit2.Text));
          if Trim(LabeledEdit3.Text) <> '' then
            tmpList.Add(Trim(LabeledEdit3.Text));
          for i := 0 to MainForm.ListView1.Items.Count - 1 do
            SelectItem(i, CheckExtension(MainForm.ListView1.Items[i].SubItems
              [0], tmpList));
        end;
      1:
        begin
          if Trim(LabeledEdit4.Text) = '' then
            Exit;
          tmpList.Clear;
          KeyWordList := SplitString(Trim(LabeledEdit4.Text), ',');
          for i := Low(KeyWordList) to High(KeyWordList) do
            tmpList.Add(KeyWordList[i]);
          case RadioGroup1.ItemIndex of
            0:
              begin
                for i := 0 to MainForm.ListView1.Items.Count - 1 do
                  SelectItem(i,
                    CheckKeyWord(MainForm.ListView1.Items[i].SubItems[0],
                    tmpList));
              end;
            1:
              begin
                for i := 0 to MainForm.ListView1.Items.Count - 1 do
                  SelectItem(i,
                    not CheckKeyWord(MainForm.ListView1.Items[i].SubItems[0],
                    tmpList));
              end;
          end;
        end;
      2:
        begin
          case RadioGroup2.ItemIndex of
            0:
              begin
                for i := StrToInt(LabeledEdit5.Text)
                  to StrToInt(LabeledEdit6.Text) do
                  SelectItem(i, True);
              end;
            1:
              begin
                for i := StrToInt(LabeledEdit5.Text)
                  to StrToInt(LabeledEdit6.Text) do
                  SelectItem(i, False);
              end;
          end;

        end;
      3:
        begin

        end;
    end;
  finally
    tmpList.Free;
  end;
  Hide;
end;

procedure TSearch.Button5Click(Sender: TObject);
begin
  Hide;
end;

function TSearch.CheckExtension(Name: string; ExtList: TStringList): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to ExtList.Count - 1 do
    if SameText(ExtractFileExt(Name), ExtList[i]) then
    begin
      Result := True;
      Break;
    end;
end;

function TSearch.CheckKeyWord(Name: string; ExtList: TStringList): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to ExtList.Count - 1 do
    if ContainsText(Name, ExtList[i]) then
    begin
      Result := True;
      Break;
    end;
end;

end.
