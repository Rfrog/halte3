object PluginDialog: TPluginDialog
  Left = 227
  Top = 108
  BorderStyle = bsDialog
  Caption = 'Plugin'
  ClientHeight = 324
  ClientWidth = 393
  Color = clBtnFace
  DoubleBuffered = True
  ParentFont = True
  OldCreateOrder = True
  Position = poScreenCenter
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object Bevel1: TBevel
    Left = 8
    Top = 8
    Width = 281
    Height = 308
    Shape = bsFrame
  end
  object OKBtn: TButton
    Left = 310
    Top = 224
    Width = 75
    Height = 25
    Caption = 'OK'
    Default = True
    ModalResult = 1
    TabOrder = 1
    OnClick = OKBtnClick
  end
  object CancelBtn: TButton
    Left = 310
    Top = 271
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Cancel'
    ModalResult = 2
    TabOrder = 2
    OnClick = CancelBtnClick
  end
  object PluginList: TListBox
    Left = 8
    Top = 8
    Width = 281
    Height = 308
    BorderStyle = bsNone
    ItemHeight = 13
    TabOrder = 3
    OnDblClick = PluginListDblClick
  end
  object LabeledEdit1: TLabeledEdit
    Left = 296
    Top = 32
    Width = 89
    Height = 21
    EditLabel.Width = 33
    EditLabel.Height = 13
    EditLabel.Caption = 'Search'
    TabOrder = 0
    OnChange = LabeledEdit1Change
  end
  object GroupBox1: TGroupBox
    Left = 295
    Top = 59
    Width = 90
    Height = 150
    Caption = 'NamingRules:'
    TabOrder = 4
    object Label1: TLabel
      Left = 16
      Top = 37
      Width = 50
      Height = 13
      Caption = 'Game Title'
    end
    object Label2: TLabel
      Left = 16
      Top = 77
      Width = 59
      Height = 13
      Caption = 'Game Maker'
    end
    object Label3: TLabel
      Left = 16
      Top = 119
      Width = 62
      Height = 13
      Caption = 'Game Engine'
    end
    object CheckBox1: TCheckBox
      Left = 3
      Top = 16
      Width = 73
      Height = 17
      Caption = '[N]'
      Checked = True
      State = cbChecked
      TabOrder = 0
    end
    object CheckBox2: TCheckBox
      Left = 3
      Top = 56
      Width = 73
      Height = 17
      Caption = '[M]'
      Checked = True
      State = cbChecked
      TabOrder = 1
    end
    object CheckBox3: TCheckBox
      Left = 3
      Top = 96
      Width = 73
      Height = 17
      Caption = '[E]'
      Checked = True
      State = cbChecked
      TabOrder = 2
    end
  end
end
