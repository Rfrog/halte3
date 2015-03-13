inherited PreviewDialog: TPreviewDialog
  BorderIcons = []
  Caption = 'Preview'
  ClientHeight = 355
  ClientWidth = 418
  DoubleBuffered = True
  KeyPreview = True
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnHide = FormHide
  OnKeyDown = FormKeyDown
  OnShow = FormShow
  ExplicitWidth = 424
  ExplicitHeight = 383
  PixelsPerInch = 96
  TextHeight = 13
  inherited Bevel1: TBevel
    Left = 0
    Top = 21
    Width = 418
    Height = 308
    Align = alTop
    ExplicitLeft = 0
    ExplicitTop = 21
    ExplicitWidth = 418
    ExplicitHeight = 308
  end
  inherited OKBtn: TButton
    Left = 0
    Top = 329
    Width = 418
    Align = alTop
    OnClick = OKBtnClick
    ExplicitLeft = 0
    ExplicitTop = 322
    ExplicitWidth = 418
  end
  inherited CancelBtn: TButton
    Left = 326
    Top = 314
    Visible = False
    ExplicitLeft = 326
    ExplicitTop = 314
  end
  object Edit1: TEdit
    Left = 0
    Top = 0
    Width = 418
    Height = 21
    Align = alTop
    TabOrder = 2
    Text = 'Edit1'
  end
end
