object frmScripts: TfrmScripts
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Scripts'
  ClientHeight = 348
  ClientWidth = 340
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object ListBox1: TListBox
    Left = 0
    Top = 0
    Width = 340
    Height = 265
    Align = alTop
    ItemHeight = 13
    TabOrder = 0
  end
  object Button1: TButton
    Left = 0
    Top = 318
    Width = 340
    Height = 31
    Align = alTop
    Caption = 'Run Script'
    TabOrder = 1
    OnClick = Button1Click
  end
  object Edit1: TEdit
    Left = 0
    Top = 265
    Width = 340
    Height = 21
    Align = alTop
    TabOrder = 2
  end
  object Button2: TButton
    Left = 0
    Top = 286
    Width = 340
    Height = 32
    Align = alTop
    Caption = 'Choose File'
    TabOrder = 3
    OnClick = Button2Click
  end
  object OpenDialog1: TOpenDialog
    Left = 256
    Top = 16
  end
end
