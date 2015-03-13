object PreviewDialog: TPreviewDialog
  Left = 227
  Top = 108
  BorderStyle = bsDialog
  Caption = 'Preview'
  ClientHeight = 237
  ClientWidth = 602
  Color = clBtnFace
  ParentFont = True
  OldCreateOrder = True
  Position = poMainFormCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object Bevel1: TBevel
    Left = 0
    Top = 0
    Width = 289
    Height = 233
    Shape = bsFrame
  end
  object Image1: TImage
    Left = 0
    Top = 0
    Width = 289
    Height = 233
    IncrementalDisplay = True
    Proportional = True
    Stretch = True
  end
  object OKBtn: TButton
    Left = 295
    Top = 208
    Width = 299
    Height = 25
    Caption = 'OK'
    Default = True
    ModalResult = 1
    TabOrder = 0
    OnClick = OKBtnClick
  end
  object Memo1: TMemo
    Left = 296
    Top = 35
    Width = 298
    Height = 167
    Lines.Strings = (
      '')
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 1
  end
  object Edit1: TEdit
    Left = 295
    Top = 8
    Width = 233
    Height = 21
    TabOrder = 2
    Text = 'Edit1'
  end
  object Button1: TButton
    Left = 534
    Top = 8
    Width = 65
    Height = 21
    Caption = 'Set'
    TabOrder = 3
    OnClick = Button1Click
  end
end
