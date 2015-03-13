unit hOption;

interface

uses Windows, SysUtils, Classes, Graphics, Forms, Controls,
  StdCtrls,
  Buttons, ExtCtrls, Dialogs;

type
  TOptionForm = class(TForm)
    RadioGroup1: TRadioGroup;
    FontDialog1: TFontDialog;
    GroupBox1: TGroupBox;
    Label1: TLabel;
    Label2: TLabel;
    Button1: TButton;
    Label3: TLabel;
    Button2: TButton;
    Button3: TButton;
    procedure FormShow(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure FontDialog1Apply(Sender: TObject; Wnd: HWND);
    procedure FontDialog1Show(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
  private
    procedure ApplyFontChange;
  public
    { Public 宣言 }
  end;

var
  OptionForm: TOptionForm;

const
  sFont = 'Font: ';
  sSize = 'Size: ';

implementation

{$R *.dfm}

uses hTypes, hMain;

procedure TOptionForm.Button1Click(Sender: TObject);
begin
  inherited;
  FontDialog1.Font := MainForm.ListView1.Font;
  if not FontDialog1.Execute(Handle) then
  Exit;
  ApplyFontChange;
end;

procedure TOptionForm.Button2Click(Sender: TObject);
begin
  case RadioGroup1.ItemIndex of
    0:
      Bufferoption := clMemoryBuffer;
    1:
      Bufferoption := clFileBuffer;
  end;
  Hide;
end;

procedure TOptionForm.Button3Click(Sender: TObject);
begin
  Hide;
end;

procedure TOptionForm.ApplyFontChange;
begin
  MainForm.ListView1.Font := FontDialog1.Font;
  Label1.Caption := sFont + MainForm.ListView1.Font.Name;
  Label2.Caption := sSize +
    IntToStr(MainForm.ListView1.Font.Size);
end;

procedure TOptionForm.FontDialog1Apply(Sender: TObject;
  Wnd: HWND);
begin
  inherited;
  ApplyFontChange;
end;

procedure TOptionForm.FontDialog1Show(Sender: TObject);
begin
  inherited;
  FontDialog1.Font := MainForm.ListView1.Font;
end;

procedure TOptionForm.FormShow(Sender: TObject);
begin
  inherited;
  case Bufferoption of
    clMemoryBuffer:
      RadioGroup1.ItemIndex := 0;
    clFileBuffer:
      RadioGroup1.ItemIndex := 1;
  end;
  Label1.Caption := sFont + MainForm.ListView1.Font.Name;
  Label2.Caption := sSize +
    IntToStr(MainForm.ListView1.Font.Size);
end;

end.
