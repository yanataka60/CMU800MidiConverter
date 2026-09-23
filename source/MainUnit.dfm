object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'CMU-800 MIDI Converter v1.05'
  ClientHeight = 650
  ClientWidth = 920
  Color = clWhitesmoke
  Font.Charset = SHIFTJIS_CHARSET
  Font.Color = clWindowText
  Font.Height = -15
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  DesignSize = (
    920
    650)
  TextHeight = 20
  object pnlHeader: TPanel
    Left = 0
    Top = 0
    Width = 920
    Height = 86
    Align = alTop
    BevelOuter = bvNone
    Color = 16763090
    ParentBackground = False
    TabOrder = 0
    object lblLogo: TLabel
      Left = 24
      Top = 14
      Width = 313
      Height = 37
      Caption = 'CMU-800 MIDI Converter'
      Font.Charset = SHIFTJIS_CHARSET
      Font.Color = 3158064
      Font.Height = -27
      Font.Name = 'Segoe UI Semibold'
      Font.Style = []
      ParentFont = False
    end
    object lblSubTitle: TLabel
      Left = 26
      Top = 50
      Width = 345
      Height = 20
      Caption = 'MIDI DATA '#12434' CMU-800 '#29992' MZT / CMU DATA '#12395#22793#25563
      Font.Charset = SHIFTJIS_CHARSET
      Font.Color = 7368816
      Font.Height = -15
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object lblVersion: TLabel
      Left = 859
      Top = 28
      Width = 34
      Height = 20
      Alignment = taRightJustify
      Caption = 'v1.05'
      Font.Charset = SHIFTJIS_CHARSET
      Font.Color = 7368816
      Font.Height = -15
      Font.Name = 'Segoe UI Semibold'
      Font.Style = []
      ParentFont = False
    end
  end
  object pnlTop: TPanel
    Left = 0
    Top = 86
    Width = 920
    Height = 314
    Align = alTop
    BevelOuter = bvNone
    Color = clWhitesmoke
    ParentBackground = False
    TabOrder = 1
    object grpFiles: TGroupBox
      Left = 18
      Top = 14
      Width = 566
      Height = 282
      Caption = '  '#12501#12449#12452#12523'  '
      Color = clAliceblue
      Font.Charset = SHIFTJIS_CHARSET
      Font.Color = 3158064
      Font.Height = -16
      Font.Name = 'Segoe UI Semibold'
      Font.Style = []
      ParentBackground = False
      ParentColor = False
      ParentFont = False
      TabOrder = 0
      object lblInput: TLabel
        Left = 18
        Top = 32
        Width = 137
        Height = 20
        Caption = 'MIDI DATA'#65288#20837#21147#65289
        Font.Charset = SHIFTJIS_CHARSET
        Font.Color = 4210752
        Font.Height = -15
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object lblOutput: TLabel
        Left = 18
        Top = 103
        Width = 137
        Height = 20
        Caption = 'CMU DATA'#65288#20986#21147#65289
        Font.Charset = SHIFTJIS_CHARSET
        Font.Color = 4210752
        Font.Height = -15
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object lblBase: TLabel
        Left = 18
        Top = 182
        Width = 114
        Height = 19
        Caption = 'Load address (hex)'
        Font.Charset = SHIFTJIS_CHARSET
        Font.Color = 4210752
        Font.Height = -14
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object lblQuant: TLabel
        Left = 158
        Top = 182
        Width = 123
        Height = 19
        Caption = 'Steps / quarter note'
        Font.Charset = SHIFTJIS_CHARSET
        Font.Color = 4210752
        Font.Height = -14
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object lblHint: TLabel
        Left = 18
        Top = 246
        Width = 387
        Height = 15
        Caption = 'MIDI'#12434#36984#25246#12377#12427#12392#12289#20986#21147#21517#12399#33258#21205#30340#12395#12300'CMU '#20803#12501#12449#12452#12523#21517'.mzt'#12301#12395#12394#12426#12414#12377#12290
        Font.Charset = SHIFTJIS_CHARSET
        Font.Color = clGray
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object edtInput: TEdit
        Left = 18
        Top = 56
        Width = 416
        Height = 28
        Font.Charset = SHIFTJIS_CHARSET
        Font.Color = clWindowText
        Font.Height = -15
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        TabOrder = 0
        OnExit = edtInputExit
      end
      object btnInput: TButton
        Left = 444
        Top = 54
        Width = 102
        Height = 32
        Caption = 'Browse...'
        TabOrder = 1
        OnClick = btnInputClick
      end
      object edtOutput: TEdit
        Left = 18
        Top = 127
        Width = 416
        Height = 28
        Font.Charset = SHIFTJIS_CHARSET
        Font.Color = clWindowText
        Font.Height = -15
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        TabOrder = 2
      end
      object btnOutput: TButton
        Left = 444
        Top = 125
        Width = 102
        Height = 32
        Caption = 'Browse...'
        TabOrder = 3
        OnClick = btnOutputClick
      end
      object edtBase: TEdit
        Left = 18
        Top = 206
        Width = 100
        Height = 29
        MaxLength = 4
        TabOrder = 4
      end
      object spnQuant: TSpinEdit
        Left = 158
        Top = 206
        Width = 92
        Height = 31
        MaxValue = 96
        MinValue = 1
        TabOrder = 5
        Value = 24
      end
    end
    object grpOptions: TGroupBox
      Left = 598
      Top = 14
      Width = 304
      Height = 282
      Caption = '  '#22793#25563#12458#12503#12471#12519#12531'  '
      Color = 14671871
      Font.Charset = SHIFTJIS_CHARSET
      Font.Color = 3158064
      Font.Height = -16
      Font.Name = 'Segoe UI Semibold'
      Font.Style = []
      ParentBackground = False
      ParentColor = False
      ParentFont = False
      TabOrder = 1
      object lblConvertHint: TLabel
        Left = 18
        Top = 250
        Width = 198
        Height = 15
        Caption = '96 STEP'#21516#26399' / MIDI -24 / 10'#38936#22495#24418#24335
        Font.Charset = SHIFTJIS_CHARSET
        Font.Color = clGray
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object chkVelocityGate: TCheckBox
        Left = 18
        Top = 39
        Width = 265
        Height = 24
        Caption = 'Velocity '#12434' GATE'#38263#12408#21453#26144
        TabOrder = 0
      end
      object chkHarmonyBoost: TCheckBox
        Left = 18
        Top = 72
        Width = 265
        Height = 42
        Caption = #12495#12540#12514#12491#12540#12434#35036#24375#12377#12427#13#10#65288#31354#12365'CHORD'#12408'1oct'#19979#12434#36861#21152#65289
        TabOrder = 1
        WordWrap = True
      end
      object chkMelodyPriority: TCheckBox
        Left = 18
        Top = 118
        Width = 265
        Height = 24
        Caption = #20027#26059#24459#20778#20808#65288'Melody Priority'#65289
        Checked = True
        State = cbChecked
        TabOrder = 2
      end
      object chkNativeRhythmV3: TCheckBox
        Left = 18
        Top = 146
        Width = 265
        Height = 40
        Caption = 'Native Rhythm v4'#65288#12458#12503#12471#12519#12531#65289#13#10'CH0 Pattern + CH9 Table'
        Checked = True
        State = cbChecked
        TabOrder = 3
        WordWrap = True
      end
      object btnConvert: TButton
        Left = 18
        Top = 194
        Width = 265
        Height = 48
        Caption = #22793#25563#38283#22987
        Default = True
        Font.Charset = SHIFTJIS_CHARSET
        Font.Color = clWindowText
        Font.Height = -18
        Font.Name = 'Segoe UI Semibold'
        Font.Style = []
        ParentFont = False
        TabOrder = 4
        OnClick = btnConvertClick
      end
    end
  end
  object pnlLogHeader: TPanel
    Left = 0
    Top = 400
    Width = 920
    Height = 38
    Align = alTop
    BevelOuter = bvNone
    Color = 13434879
    ParentBackground = False
    TabOrder = 2
    object lblLog: TLabel
      Left = 22
      Top = 8
      Width = 59
      Height = 21
      Caption = #22793#25563#12525#12464
      Font.Charset = SHIFTJIS_CHARSET
      Font.Color = 3158064
      Font.Height = -16
      Font.Name = 'Segoe UI Semibold'
      Font.Style = []
      ParentFont = False
    end
  end
  object memLog: TMemo
    Left = 18
    Top = 438
    Width = 884
    Height = 174
    Anchors = [akLeft, akTop, akRight, akBottom]
    Color = clWhite
    Font.Charset = SHIFTJIS_CHARSET
    Font.Color = 3158064
    Font.Height = -14
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 3
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 620
    Width = 920
    Height = 30
    Align = alBottom
    BevelOuter = bvNone
    Color = 16763090
    ParentBackground = False
    TabOrder = 4
    object lblStatus: TLabel
      Left = 18
      Top = 6
      Width = 52
      Height = 15
      Caption = #28310#20633#23436#20102
      Font.Charset = SHIFTJIS_CHARSET
      Font.Color = 6316128
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object lblFooter: TLabel
      Left = 735
      Top = 6
      Width = 163
      Height = 15
      Alignment = taRightJustify
      Caption = 'CMU-800 MIDI Converter v1.05'
      Font.Charset = SHIFTJIS_CHARSET
      Font.Color = clGray
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
  end
  object OpenDialog: TOpenDialog
    Left = 48
    Top = 456
  end
  object SaveDialog: TSaveDialog
    DefaultExt = 'mzt'
    Filter = 
      'MZ tape image (*.mzt)|*.mzt|CMU-800 raw song data (*.cmu)|*.cmu|' +
      'Binary file (*.bin)|*.bin'
    Options = [ofOverwritePrompt, ofHideReadOnly, ofEnableSizing]
    Left = 128
    Top = 456
  end
end
