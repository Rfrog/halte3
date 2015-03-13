object Search: TSearch
  Left = 0
  Top = 0
  Caption = 'Search&Select'
  ClientHeight = 286
  ClientWidth = 356
  Color = clBtnFace
  DoubleBuffered = True
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = True
  PixelsPerInch = 96
  TextHeight = 13
  object PageControl1: TPageControl
    Left = 0
    Top = 0
    Width = 356
    Height = 247
    ActivePage = TabSheet1
    Align = alTop
    Style = tsFlatButtons
    TabOrder = 0
    object TabSheet1: TTabSheet
      Caption = 'Extension'
      object GroupBox1: TGroupBox
        Left = 3
        Top = 0
        Width = 113
        Height = 213
        Caption = 'Music'
        TabOrder = 0
        object CheckBox1: TCheckBox
          Left = 12
          Top = 24
          Width = 85
          Height = 25
          Caption = 'OGG'
          TabOrder = 0
        end
        object CheckBox2: TCheckBox
          Left = 12
          Top = 55
          Width = 85
          Height = 25
          Caption = 'MP3'
          TabOrder = 1
        end
        object CheckBox3: TCheckBox
          Left = 12
          Top = 86
          Width = 85
          Height = 25
          Caption = 'WAV'
          TabOrder = 2
        end
        object LabeledEdit1: TLabeledEdit
          Left = 10
          Top = 133
          Width = 89
          Height = 21
          EditLabel.Width = 47
          EditLabel.Height = 13
          EditLabel.Caption = 'Other Ext'
          TabOrder = 3
        end
      end
      object GroupBox2: TGroupBox
        Left = 118
        Top = 0
        Width = 113
        Height = 213
        Caption = 'Graphic'
        TabOrder = 1
        object CheckBox4: TCheckBox
          Left = 4
          Top = 24
          Width = 85
          Height = 25
          Caption = 'JPG'
          TabOrder = 0
        end
        object CheckBox5: TCheckBox
          Left = 4
          Top = 55
          Width = 85
          Height = 25
          Caption = 'BMP'
          TabOrder = 1
        end
        object CheckBox6: TCheckBox
          Left = 4
          Top = 86
          Width = 85
          Height = 25
          Caption = 'PNG'
          TabOrder = 2
        end
        object CheckBox7: TCheckBox
          Left = 4
          Top = 117
          Width = 85
          Height = 25
          Caption = 'TGA'
          TabOrder = 3
        end
        object LabeledEdit2: TLabeledEdit
          Left = 10
          Top = 164
          Width = 89
          Height = 21
          EditLabel.Width = 47
          EditLabel.Height = 13
          EditLabel.Caption = 'Other Ext'
          TabOrder = 4
        end
      end
      object GroupBox3: TGroupBox
        Left = 232
        Top = 0
        Width = 113
        Height = 213
        Caption = 'Text'
        TabOrder = 2
        object CheckBox8: TCheckBox
          Left = 5
          Top = 24
          Width = 85
          Height = 25
          Caption = 'TXT'
          TabOrder = 0
        end
        object CheckBox9: TCheckBox
          Left = 5
          Top = 55
          Width = 85
          Height = 25
          Caption = 'KS'
          TabOrder = 1
        end
        object LabeledEdit3: TLabeledEdit
          Left = 10
          Top = 98
          Width = 89
          Height = 21
          EditLabel.Width = 47
          EditLabel.Height = 13
          EditLabel.Caption = 'Other Ext'
          TabOrder = 2
        end
      end
    end
    object TabSheet2: TTabSheet
      Caption = 'KeyWord'
      ImageIndex = 1
      object Label1: TLabel
        Left = 40
        Top = 64
        Width = 241
        Height = 26
        Caption = 
          'Delimiter is '#39' , '#39' .(Do not contain space and quotes)'#13#10'It is OR ' +
          'between different keyword.NOT AND.'
      end
      object LabeledEdit4: TLabeledEdit
        Left = 3
        Top = 24
        Width = 342
        Height = 21
        EditLabel.Width = 47
        EditLabel.Height = 13
        EditLabel.Caption = 'Key Word'
        TabOrder = 0
      end
      object RadioGroup1: TRadioGroup
        Left = 16
        Top = 104
        Width = 305
        Height = 81
        Caption = 'Search Option'
        ItemIndex = 0
        Items.Strings = (
          'Check'
          'Uncheck')
        TabOrder = 1
      end
    end
    object TabSheet3: TTabSheet
      Caption = 'Index'
      ImageIndex = 2
      object LabeledEdit5: TLabeledEdit
        Left = 32
        Top = 24
        Width = 113
        Height = 21
        EditLabel.Width = 24
        EditLabel.Height = 13
        EditLabel.Caption = 'From'
        TabOrder = 0
      end
      object LabeledEdit6: TLabeledEdit
        Left = 184
        Top = 24
        Width = 121
        Height = 21
        EditLabel.Width = 12
        EditLabel.Height = 13
        EditLabel.Caption = 'To'
        TabOrder = 1
      end
      object RadioGroup2: TRadioGroup
        Left = 32
        Top = 72
        Width = 273
        Height = 89
        Caption = 'Option'
        ItemIndex = 0
        Items.Strings = (
          'Ckeck'
          'Unckeck')
        TabOrder = 2
      end
    end
    object TabSheet4: TTabSheet
      Caption = 'Other'
      ImageIndex = 3
      object Button1: TButton
        Left = 104
        Top = 24
        Width = 129
        Height = 25
        Caption = 'Check All'
        TabOrder = 0
        OnClick = Button1Click
      end
      object Button2: TButton
        Left = 104
        Top = 64
        Width = 129
        Height = 25
        Caption = 'Uncheck All'
        TabOrder = 1
        OnClick = Button2Click
      end
      object Button3: TButton
        Left = 104
        Top = 104
        Width = 129
        Height = 25
        Caption = 'Check Invert'
        TabOrder = 2
        OnClick = Button3Click
      end
    end
  end
  object Button4: TButton
    Left = 56
    Top = 248
    Width = 105
    Height = 33
    Caption = 'OK'
    TabOrder = 1
    OnClick = Button4Click
  end
  object Button5: TButton
    Left = 184
    Top = 248
    Width = 113
    Height = 33
    Caption = 'Cancel'
    TabOrder = 2
    OnClick = Button5Click
  end
end
