unit hHelp;

interface

uses Windows, SysUtils, Classes, Graphics, Forms, Controls,
  StdCtrls,
  Buttons, ExtCtrls, ComCtrls;

type
  THelpForm = class(TForm)
    ListView1: TListView;
    Button1: TButton;
    procedure OKBtnClick(Sender: TObject);
    procedure ListView1ColumnClick(Sender: TObject;
      Column: TListColumn);
    procedure FormShow(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  private
    procedure LoadDocument;
  public

  end;

var
  HelpForm: THelpForm;

const
  HelpDocument = '\SupportList.Dat';

implementation

{$R *.dfm}

uses hDocumentTypes;

var
  m_bSort: boolean = True;

function CustomSortProc(Item1, Item2: TListItem;
  ParamSort: integer): integer; stdcall;
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

procedure THelpForm.LoadDocument;
var
  sData: TDataConnect;
  I: integer;
begin
  sData := TDataConnect.Create;
  try
    sData.LoadDocument(ExtractFilePath(Application.ExeName) +
      HelpDocument);
    for I := 0 to sData.NodeList.Count - 1 do
    begin
      with ListView1.Items.Add do
      begin
        Caption := Trim(sData.NodeList[I].AEngine);
        SubItems.Add(Trim(sData.NodeList[I].AName));
        SubItems.Add(Trim(sData.NodeList[I].AGameMaker));
        SubItems.Add(Trim(sData.NodeList[I].AExtension));
        SubItems.Add(Trim(sData.NodeList[I].AState));
      end;
      Application.ProcessMessages;
    end;
  finally
    sData.Free;
  end;
end;

procedure THelpForm.Button1Click(Sender: TObject);
begin
 Hide;
end;

procedure THelpForm.FormShow(Sender: TObject);
begin
  inherited;
  ListView1.Clear;
  LoadDocument;
end;

procedure THelpForm.ListView1ColumnClick(Sender: TObject;
  Column: TListColumn);
begin
  inherited;
  ListView1.CustomSort(@CustomSortProc, Column.Index);
end;

procedure THelpForm.OKBtnClick(Sender: TObject);
begin
  inherited;
  Hide;
end;

end.
