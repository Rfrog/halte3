object frmAutoDetect: TfrmAutoDetect
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'AutoDetect'
  ClientHeight = 333
  ClientWidth = 419
  Color = clBtnFace
  DoubleBuffered = True
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  OnHide = FormHide
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object ListView1: TListView
    Left = 0
    Top = 0
    Width = 419
    Height = 281
    Align = alClient
    Columns = <
      item
        AutoSize = True
        Caption = 'Index'
      end
      item
        AutoSize = True
        Caption = 'PluginName'
      end
      item
        AutoSize = True
        Caption = 'DetectResult'
      end>
    ReadOnly = True
    RowSelect = True
    TabOrder = 0
    ViewStyle = vsReport
    OnColumnClick = ListView1ColumnClick
  end
  object Button1: TButton
    Left = 0
    Top = 307
    Width = 419
    Height = 26
    Align = alBottom
    Caption = 'Close'
    TabOrder = 1
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 0
    Top = 281
    Width = 419
    Height = 26
    Align = alBottom
    Caption = 'Choose Package'
    TabOrder = 2
    OnClick = Button2Click
  end
  object OpenDialog1: TOpenDialog
    Left = 344
    Top = 240
  end
end
