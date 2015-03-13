unit hABOUT;

interface

uses Windows, SysUtils, Classes, Graphics, Forms, Controls,
  StdCtrls,
  Buttons, ExtCtrls, jpeg;

type
  TAboutBox = class(TForm)
    Panel1: TPanel;
    ProductName: TLabel;
    Version: TLabel;
    Copyright: TLabel;
    Comments: TLabel;
    OKButton: TButton;
    ProgramIcon: TImage;
    procedure FormCreate(Sender: TObject);
    procedure CommentsClick(Sender: TObject);
    procedure OKButtonClick(Sender: TObject);
  private
    { Private 宣言 }
  public
    { Public 宣言 }
  end;

var
  AboutBox: TAboutBox;

implementation

{$R *.dfm}
uses hTypes;

procedure TAboutBox.CommentsClick(Sender: TObject);
begin
  WinExec('explorer.exe mailto:'+mail,0);
end;

procedure TAboutBox.FormCreate(Sender: TObject);
begin
  ProductName.Caption := ProductName.Caption + ' ' + AppName;
  Version.Caption := Version.Caption + ' ' +
    FormatVersion(GetFileVersion(Application.ExeName));
  Copyright.Caption := Copyright.Caption + ' ' + Producer;
  Comments.Caption := Comments.Caption + ' ' + Mail;
end;

procedure TAboutBox.OKButtonClick(Sender: TObject);
begin
  Hide;
end;

end.
