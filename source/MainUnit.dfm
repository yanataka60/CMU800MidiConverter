object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'CMU-800 MIDI Converter v1.08b'
  ClientHeight = 650
  ClientWidth = 920
  Color = 16119285
  Font.Charset = SHIFTJIS_CHARSET
  Font.Color = clWindowText
  Font.Height = -15
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
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
      Width = 340
      Height = 32
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
      Width = 360
      Height = 20
      Caption = 'MIDI DATA を CMU-800 用 MZT / CMU DATA に変換'
      Font.Charset = SHIFTJIS_CHARSET
      Font.Color = 7368816
      Font.Height = -15
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object lblVersion: TLabel
      Left = 835
      Top = 28
      Width = 58
      Height = 20
      Alignment = taRightJustify
      Caption = 'v1.08b'
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
    Color = 16119285
    ParentBackground = False
    TabOrder = 1
    object grpFiles: TGroupBox
      Left = 18
      Top = 14
      Width = 566
      Height = 282
      Color = 16775408
      ParentBackground = False
      Caption = '  ファイル  '
      Font.Charset = SHIFTJIS_CHARSET
      Font.Color = 3158064
      Font.Height = -16
      Font.Name = 'Segoe UI Semibold'
      Font.Style = []
      ParentFont = False
      TabOrder = 0
      object lblInput: TLabel
        Left = 18
        Top = 32
        Width = 128
        Height = 20
        Caption = 'MIDI DATA（入力）'
        Font.Charset = SHIFTJIS_CHARSET
        Font.Color = 4210752
        Font.Height = -15
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
        OnChange = edtInputChange
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
      object lblOutput: TLabel
        Left = 18
        Top = 103
        Width = 128
        Height = 20
        Caption = 'CMU DATA（出力）'
        Font.Charset = SHIFTJIS_CHARSET
        Font.Color = 4210752
        Font.Height = -15
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
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
      object lblBase: TLabel
        Left = 18
        Top = 182
        Width = 112
        Height = 20
        Caption = 'Load address (hex)'
        Font.Charset = SHIFTJIS_CHARSET
        Font.Color = 4210752
        Font.Height = -14
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object edtBase: TEdit
        Left = 18
        Top = 206
        Width = 100
        Height = 28
        MaxLength = 4
        TabOrder = 4
      end
      object lblSpeed: TLabel
        Left = 158
        Top = 182
        Width = 133
        Height = 20
        Caption = '演奏速度 (%)'
        Font.Charset = SHIFTJIS_CHARSET
        Font.Color = 4210752
        Font.Height = -14
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object spnSpeed: TSpinEdit
        Left = 158
        Top = 206
        Width = 92
        Height = 28
        MaxValue = 200
        MinValue = 1
        TabOrder = 5
        Value = 100
        OnChange = TimingChange
      end
      object lblHint: TLabel
        Left = 18
        Top = 240
        Width = 528
        Height = 36
        AutoSize = False
        WordWrap = True
        Caption = 'MIDIを選択すると変換前後のBPMを表示します。'
        Font.Charset = SHIFTJIS_CHARSET
        Font.Color = 4210752
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
    end
    object grpOptions: TGroupBox
      Left = 598
      Top = 14
      Width = 304
      Height = 282
      Color = 14671871
      ParentBackground = False
      Caption = '  変換オプション  '
      Font.Charset = SHIFTJIS_CHARSET
      Font.Color = 3158064
      Font.Height = -16
      Font.Name = 'Segoe UI Semibold'
      Font.Style = []
      ParentFont = False
      TabOrder = 1
      object chkVelocityGate: TCheckBox
        Left = 18
        Top = 39
        Width = 265
        Height = 24
        Caption = 'Velocity を GATE長へ反映'
        TabOrder = 0
      end
      object chkHarmonyBoost: TCheckBox
        Left = 18
        Top = 72
        Width = 265
        Height = 42
        Caption = 'ハーモニーを補強する'#13#10'（空きCHORDへ1oct下を追加）'
        TabOrder = 1
        WordWrap = True
      end
      object chkMelodyPriority: TCheckBox
        Left = 18
        Top = 118
        Width = 265
        Height = 24
        Caption = '主旋律優先（Melody Priority）'
        Checked = True
        State = cbChecked
        TabOrder = 2
      end
      object chkNativeRhythmV3: TCheckBox
        Left = 18
        Top = 146
        Width = 265
        Height = 40
        Caption = 'Native Rhythm v4（オプション）'#13#10'CH0 Pattern + CH9 Table'
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
        Caption = '変換開始'
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
      object lblConvertHint: TLabel
        Left = 18
        Top = 250
        Width = 240
        Height = 17
        Caption = 'MIDI TEMPO追従 / 基準24 STEP'
        Font.Charset = SHIFTJIS_CHARSET
        Font.Color = 8421504
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
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
      Width = 78
      Height = 21
      Caption = '変換ログ'
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
      Width = 48
      Height = 17
      Caption = '準備完了'
      Font.Charset = SHIFTJIS_CHARSET
      Font.Color = 6316128
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object lblFooter: TLabel
      Left = 730
      Top = 6
      Width = 168
      Height = 17
      Alignment = taRightJustify
      Caption = 'CMU-800 MIDI Converter v1.08b'
      Font.Charset = SHIFTJIS_CHARSET
      Font.Color = 8421504
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
    Filter = 'MZ tape image (*.mzt)|*.mzt|CMU-800 raw song data (*.cmu)|*.cmu|Binary file (*.bin)|*.bin'
    Options = [ofOverwritePrompt, ofHideReadOnly, ofEnableSizing]
    Left = 128
    Top = 456
  end
end
