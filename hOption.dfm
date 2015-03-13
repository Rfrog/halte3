object OptionForm: TOptionForm
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  Caption = 'Option'
  ClientHeight = 213
  ClientWidth = 312
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
  object Label3: TLabel
    Left = 16
    Top = 103
    Width = 129
    Height = 52
    Caption = 
      'MemoryStream: Faster,do '#13#10'not support big package.'#13#10'FileStream: ' +
      'Slower,'#13#10'but support big package. '
  end
  object RadioGroup1: TRadioGroup
    Left = 16
    Top = 16
    Width = 129
    Height = 81
    Caption = 'Stream Mode'
    ItemIndex = 0
    Items.Strings = (
      'Memory Stream'
      'File Stream')
    TabOrder = 0
  end
  object GroupBox1: TGroupBox
    Left = 151
    Top = 16
    Width = 146
    Height = 145
    Caption = 'Font'
    TabOrder = 1
    object Label1: TLabel
      Left = 16
      Top = 24
      Width = 3
      Height = 13
    end
    object Label2: TLabel
      Left = 16
      Top = 56
      Width = 3
      Height = 13
    end
    object Button1: TButton
      Left = 24
      Top = 96
      Width = 105
      Height = 25
      Caption = 'Change'
      TabOrder = 0
      OnClick = Button1Click
    end
  end
  object Button2: TButton
    Left = 32
    Top = 176
    Width = 113
    Height = 29
    Caption = 'OK'
    TabOrder = 2
    OnClick = Button2Click
  end
  object Button3: TButton
    Left = 167
    Top = 176
    Width = 113
    Height = 29
    Caption = 'Cancel'
    TabOrder = 3
    OnClick = Button3Click
  end
  object FontDialog1: TFontDialog
    OnShow = FontDialog1Show
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Tahoma'
    Font.Style = []
    OnApply = FontDialog1Apply
    Left = 272
    Top = 176
  end
end
