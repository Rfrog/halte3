object Form6: TForm6
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = 'Halte3-DocumentBuilder'
  ClientHeight = 366
  ClientWidth = 461
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poDesktopCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object LabeledEdit1: TLabeledEdit
    Left = 8
    Top = 32
    Width = 193
    Height = 21
    EditLabel.Width = 32
    EditLabel.Height = 13
    EditLabel.Caption = 'Engine'
    MaxLength = 50
    TabOrder = 0
  end
  object LabeledEdit2: TLabeledEdit
    Left = 8
    Top = 122
    Width = 193
    Height = 21
    EditLabel.Width = 54
    EditLabel.Height = 13
    EditLabel.Caption = 'GameName'
    MaxLength = 100
    TabOrder = 1
  end
  object LabeledEdit3: TLabeledEdit
    Left = 8
    Top = 80
    Width = 193
    Height = 21
    EditLabel.Width = 56
    EditLabel.Height = 13
    EditLabel.Caption = 'GameMaker'
    MaxLength = 50
    TabOrder = 2
  end
  object LabeledEdit4: TLabeledEdit
    Left = 240
    Top = 32
    Width = 213
    Height = 21
    EditLabel.Width = 47
    EditLabel.Height = 13
    EditLabel.Caption = 'Extension'
    MaxLength = 50
    TabOrder = 3
  end
  object Button1: TButton
    Left = 312
    Top = 118
    Width = 42
    Height = 25
    Caption = 'Add'
    TabOrder = 4
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 240
    Top = 118
    Width = 45
    Height = 25
    Caption = 'Save'
    TabOrder = 5
    OnClick = Button2Click
  end
  object ListView1: TListView
    Left = 8
    Top = 149
    Width = 445
    Height = 209
    BorderStyle = bsNone
    Columns = <
      item
        AutoSize = True
        Caption = 'Engine'
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
        Caption = 'state'
      end>
    DoubleBuffered = True
    ReadOnly = True
    RowSelect = True
    ParentDoubleBuffered = False
    TabOrder = 6
    ViewStyle = vsReport
    OnClick = ListView1Click
  end
  object Button3: TButton
    Left = 360
    Top = 118
    Width = 42
    Height = 25
    Caption = 'Delete'
    TabOrder = 7
    OnClick = Button3Click
  end
  object Button4: TButton
    Left = 408
    Top = 118
    Width = 41
    Height = 25
    Caption = 'Change'
    TabOrder = 8
    OnClick = Button4Click
  end
  object CheckBox1: TCheckBox
    Left = 240
    Top = 72
    Width = 73
    Height = 33
    Caption = 'Extract'
    Checked = True
    State = cbChecked
    TabOrder = 9
  end
  object CheckBox2: TCheckBox
    Left = 360
    Top = 72
    Width = 73
    Height = 33
    Caption = 'Pack'
    Checked = True
    State = cbChecked
    TabOrder = 10
  end
end
