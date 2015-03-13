object HelpForm: THelpForm
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  Caption = 'Help'
  ClientHeight = 331
  ClientWidth = 428
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = True
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object ListView1: TListView
    Left = 0
    Top = 0
    Width = 425
    Height = 297
    BorderStyle = bsNone
    Columns = <
      item
        AutoSize = True
        Caption = 'GameEngine'
      end
      item
        AutoSize = True
        Caption = 'GameName'
      end
      item
        AutoSize = True
        Caption = 'GameMaker'
      end
      item
        AutoSize = True
        Caption = 'Extension'
      end
      item
        AutoSize = True
        Caption = 'State'
      end>
    DoubleBuffered = True
    ReadOnly = True
    RowSelect = True
    ParentDoubleBuffered = False
    TabOrder = 0
    ViewStyle = vsReport
    OnColumnClick = ListView1ColumnClick
  end
  object Button1: TButton
    Left = 0
    Top = 304
    Width = 425
    Height = 25
    Caption = 'Close'
    TabOrder = 1
    OnClick = Button1Click
  end
end
