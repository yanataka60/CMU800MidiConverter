unit MainUnit;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.ShellAPI,
  System.SysUtils, System.UITypes, System.Classes, System.Math, System.IniFiles,
  System.Generics.Collections, System.Generics.Defaults,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.Graphics,
  Vcl.ExtCtrls, Vcl.Dialogs, Vcl.Samples.Spin, MidiTiming, VelocityGatePolicy;

type
  TMidiNote = record
    StartTick, EndTick: Int64;
    Note, Velocity, Channel, ProgramNo, OrderNo: Integer;
  end;

  TTrackData = class
  public
    Data: TBytes;
    procedure Add(B: Byte);
    procedure AddEvent(ANote, ALen, AGate: Integer);
  end;

  TMainForm = class(TForm)
    pnlHeader: TPanel;
    lblLogo: TLabel;
    lblSubTitle: TLabel;
    lblVersion: TLabel;
    pnlTop: TPanel;
    grpFiles: TGroupBox;
    grpOptions: TGroupBox;
    pnlLogHeader: TPanel;
    pnlFooter: TPanel;
    lblLog: TLabel;
    lblStatus: TLabel;
    lblFooter: TLabel;
    lblHint: TLabel;
    lblConvertHint: TLabel;
    lblInput: TLabel;
    edtInput: TEdit;
    btnInput: TButton;
    lblOutput: TLabel;
    edtOutput: TEdit;
    btnOutput: TButton;
    lblBase: TLabel;
    edtBase: TEdit;
    lblVelocityGate: TLabel;
    cmbVelocityGate: TComboBox;
    chkChordSeparation: TCheckBox;
    chkMelodyPriority: TCheckBox;
    chkNativeRhythmV3: TCheckBox;
    btnConvert: TButton;
    memLog: TMemo;
    OpenDialog: TOpenDialog;
    SaveDialog: TSaveDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnInputClick(Sender: TObject);
    procedure btnOutputClick(Sender: TObject);
    procedure btnConvertClick(Sender: TObject);
    procedure edtInputExit(Sender: TObject);
    procedure edtInputChange(Sender: TObject);
  private
    FDivision: Integer;
    FTiming: TMidiTiming;
    FPreviewFile: string;
    FLastNoteTick: Int64;
    FNotes: TList<TMidiNote>;
    FInputDir, FOutputDir: string;
    procedure WMDropFiles(var Msg: TWMDropFiles); message WM_DROPFILES;
    function SettingsFileName: string;
    function ValidFolderFromText(const S: string): string;
    procedure LoadSettings;
    procedure SaveSettings;
    procedure SelectMidiFile(const FileName: string);
    function ReadBE16(const B: TBytes; var P: Integer): Cardinal;
    function ReadBE32(const B: TBytes; var P: Integer): Cardinal;
    function ReadVarLen(const B: TBytes; var P: Integer; Limit: Integer): Cardinal;
    procedure ParseMidi(const FileName: string; ALog: Boolean = True);
    procedure RefreshTempoPreview;
    procedure LogTempoMap;
    function SelectedVelocityGateMode: TVelocityGateMode;
    function ResolveVelocityGate: Boolean;
    procedure ParseTrack(const B: TBytes; StartPos, TrackLen: Integer);
    procedure BuildTracks(Tracks: TObjectList<TTrackData>);
    procedure SaveCMUData(const FileName: string; Tracks: TObjectList<TTrackData>;
      BaseAddress: Word);
    procedure Log(const S: string);
  public
    procedure WndProc(var Message: TMessage); override;
    destructor Destroy; override;
  end;

var MainForm: TMainForm;

implementation

{$R *.dfm}

procedure TTrackData.Add(B: Byte);
var N: Integer;
begin
  N := Length(Data); SetLength(Data, N + 1); Data[N] := B;
end;

procedure TTrackData.AddEvent(ANote, ALen, AGate: Integer);
var
  ThisLen, ThisGate: Integer;
begin
  while ALen > 0 do
  begin
    ThisLen := Min(ALen, 127);
    if AGate <= 0 then Add(0)
    else Add(Byte(EnsureRange(ANote, 0, 127)));
    Add(Byte(ThisLen));
    if (ANote = 0) or (AGate <= 0) then
      ThisGate := 0
    else
      ThisGate := EnsureRange(Min(AGate, ThisLen), 1, 127);
    Add(Byte(ThisGate));
    Dec(ALen, ThisLen);
    AGate := Max(0, AGate - ThisLen);
  end;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  { Retro UI: standard DFM controls only. Buttons become owner-drawn at runtime. }
  SetWindowLong(btnInput.Handle, GWL_STYLE, GetWindowLong(btnInput.Handle, GWL_STYLE) or BS_OWNERDRAW);
  SetWindowLong(btnOutput.Handle, GWL_STYLE, GetWindowLong(btnOutput.Handle, GWL_STYLE) or BS_OWNERDRAW);
  SetWindowLong(btnConvert.Handle, GWL_STYLE, GetWindowLong(btnConvert.Handle, GWL_STYLE) or BS_OWNERDRAW);
  SetWindowRgn(btnInput.Handle, CreateRoundRectRgn(0, 0, btnInput.Width + 1, btnInput.Height + 1, 14, 14), True);
  SetWindowRgn(btnOutput.Handle, CreateRoundRectRgn(0, 0, btnOutput.Width + 1, btnOutput.Height + 1, 14, 14), True);
  SetWindowRgn(btnConvert.Handle, CreateRoundRectRgn(0, 0, btnConvert.Width + 1, btnConvert.Height + 1, 18, 18), True);
  chkNativeRhythmV3.Checked := True;
  chkMelodyPriority.Checked := True;
  chkChordSeparation.Checked := False;
  FNotes := TList<TMidiNote>.Create;
  FTiming := TMidiTiming.Create;
  Caption := 'CMU-800 MIDI Converter v1.15a';
  lblVersion.Caption := 'v1.15a';
  lblFooter.Caption := 'CMU-800 MIDI Converter v1.15a';
  OpenDialog.Filter := 'Standard MIDI File (*.mid;*.midi)|*.mid;*.midi|All files (*.*)|*.*';
  SaveDialog.Filter := 'MZ tape image (*.mzt)|*.mzt|CMU-800 raw song data (*.cmu)|*.cmu|Binary file (*.bin)|*.bin';
  SaveDialog.DefaultExt := 'mzt';
  SaveDialog.FilterIndex := 1;
  edtBase.Text := '337D';
  lblHint.Caption := 'MIDIの最初のBPMを基準に、以降のテンポ変化だけをSTEPへ反映します。';
  cmbVelocityGate.ItemIndex := Ord(vgAuto);
  LoadSettings;
  DragAcceptFiles(Handle,True);
end;


procedure TMainForm.WndProc(var Message: TMessage);
var
  DI: PDrawItemStruct;
  R: TRect;
  FillC, BorderC, TextC: TColor;
  Br: HBRUSH;
  Pen: HPEN;
  OldPen, OldBrush: HGDIOBJ;
  S: string;
  Flags: UINT;
begin
  if Message.Msg = WM_DRAWITEM then
  begin
    DI := PDrawItemStruct(Message.LParam);
    if (DI <> nil) and ((DI^.hwndItem = btnInput.Handle) or
       (DI^.hwndItem = btnOutput.Handle) or (DI^.hwndItem = btnConvert.Handle)) then
    begin
      R := DI^.rcItem;
      if DI^.hwndItem = btnConvert.Handle then
      begin
        FillC := RGB(255, 139, 74);       { warm retro orange }
        BorderC := RGB(177, 72, 38);
        TextC := RGB(48, 35, 32);
        S := btnConvert.Caption;
      end
      else if DI^.hwndItem = btnInput.Handle then
      begin
        FillC := RGB(73, 201, 211);       { aqua }
        BorderC := RGB(31, 116, 130);
        TextC := RGB(24, 54, 61);
        S := btnInput.Caption;
      end
      else
      begin
        FillC := RGB(255, 205, 86);       { sunny yellow }
        BorderC := RGB(166, 116, 25);
        TextC := RGB(62, 48, 22);
        S := btnOutput.Caption;
      end;

      if (DI^.itemState and ODS_SELECTED) <> 0 then
        FillC := RGB(Max(0, GetRValue(ColorToRGB(FillC)) - 24),
                     Max(0, GetGValue(ColorToRGB(FillC)) - 24),
                     Max(0, GetBValue(ColorToRGB(FillC)) - 24));

      Br := CreateSolidBrush(ColorToRGB(FillC));
      Pen := CreatePen(PS_SOLID, 1, ColorToRGB(BorderC));
      OldBrush := SelectObject(DI^.hDC, Br);
      OldPen := SelectObject(DI^.hDC, Pen);
      RoundRect(DI^.hDC, R.Left, R.Top, R.Right, R.Bottom, 14, 14);
      SelectObject(DI^.hDC, OldPen);
      SelectObject(DI^.hDC, OldBrush);
      DeleteObject(Pen);
      DeleteObject(Br);

      SetBkMode(DI^.hDC, TRANSPARENT);
      SetTextColor(DI^.hDC, ColorToRGB(TextC));
      SelectObject(DI^.hDC, btnConvert.Font.Handle);
      Flags := DT_CENTER or DT_VCENTER or DT_SINGLELINE;
      DrawText(DI^.hDC, PChar(S), Length(S), R, Flags);

      if (DI^.itemState and ODS_FOCUS) <> 0 then
      begin
        InflateRect(R, -5, -5);
        DrawFocusRect(DI^.hDC, R);
      end;
      Message.Result := 1;
      Exit;
    end;
  end;
  inherited WndProc(Message);
end;

destructor TMainForm.Destroy;
begin FTiming.Free; FNotes.Free; inherited; end;

procedure TMainForm.FormDestroy(Sender:TObject);
begin
  DragAcceptFiles(Handle,False);
  SaveSettings;
end;

function TMainForm.SettingsFileName:string;
var Dir:string;
begin
  { Keep the INI file beside CMU800MidiConverter.exe. }
  Dir:=ExtractFilePath(ParamStr(0));
  Result:=IncludeTrailingPathDelimiter(Dir)+'CMU800MidiConverter.ini';
end;

function TMainForm.ValidFolderFromText(const S: string): string;
var
  P: string;
begin
  Result := '';
  P := Trim(S);
  if P = '' then Exit;
  try
    P := ExpandFileName(P);
  except
    Exit;
  end;
  if DirectoryExists(P) then
    Exit(ExcludeTrailingPathDelimiter(P));
  P := ExtractFilePath(P);
  if (P <> '') and DirectoryExists(P) then
    Result := ExcludeTrailingPathDelimiter(P);
end;

procedure TMainForm.LoadSettings;
var Ini:TIniFile; ModeText:string;
begin
  Ini:=TIniFile.Create(SettingsFileName);
  try
    FInputDir:=Ini.ReadString('Folders','Input','');
    FOutputDir:=Ini.ReadString('Folders','Output','');
    ModeText := LowerCase(Trim(Ini.ReadString('Options','VelocityGateMode','')));
    if ModeText = 'auto' then cmbVelocityGate.ItemIndex := Ord(vgAuto)
    else if ModeText = 'on' then cmbVelocityGate.ItemIndex := Ord(vgOn)
    else if ModeText = 'off' then cmbVelocityGate.ItemIndex := Ord(vgOff)
    else if Ini.ValueExists('Options','VelocityGate') then
    begin
      if Ini.ReadBool('Options','VelocityGate',True) then
        cmbVelocityGate.ItemIndex := Ord(vgOn)
      else cmbVelocityGate.ItemIndex := Ord(vgOff);
    end
    else cmbVelocityGate.ItemIndex := Ord(vgAuto);
    chkChordSeparation.Checked := Ini.ReadBool('Options','ChordSeparation',False);
    chkMelodyPriority.Checked := Ini.ReadBool('Options','MelodyPriority',True);
    chkNativeRhythmV3.Checked := Ini.ReadBool('Options','NativeRhythm',True);
  finally Ini.Free; end;
  if DirectoryExists(FInputDir) then OpenDialog.InitialDir:=FInputDir else FInputDir:='';
  if DirectoryExists(FOutputDir) then SaveDialog.InitialDir:=FOutputDir else FOutputDir:='';
end;

procedure TMainForm.SaveSettings;
var Ini:TIniFile;
begin
  if edtInput.Text<>'' then FInputDir:=ExtractFilePath(ExpandFileName(edtInput.Text));
  if edtOutput.Text<>'' then FOutputDir:=ExtractFilePath(ExpandFileName(edtOutput.Text));
  try
    Ini:=TIniFile.Create(SettingsFileName);
    try
      Ini.WriteString('Folders','Input',FInputDir);
      Ini.WriteString('Folders','Output',FOutputDir);
      case SelectedVelocityGateMode of
        vgAuto: Ini.WriteString('Options','VelocityGateMode','auto');
        vgOn: Ini.WriteString('Options','VelocityGateMode','on');
        vgOff: Ini.WriteString('Options','VelocityGateMode','off');
      end;
      Ini.DeleteKey('Options','VelocityGate');
      Ini.WriteBool('Options','ChordSeparation',chkChordSeparation.Checked);
      Ini.DeleteKey('Options','HarmonyBoost');
      Ini.WriteBool('Options','MelodyPriority',chkMelodyPriority.Checked);
      Ini.WriteBool('Options','NativeRhythm',chkNativeRhythmV3.Checked);
      Ini.DeleteKey('Timing','SpeedPercent');
      Ini.DeleteKey('Timing','ReferenceBPM');
      Ini.DeleteKey('Timing','ConversionBPM');
    finally Ini.Free; end;
  except
    { Do not prevent application shutdown if settings cannot be written. }
  end;
end;

procedure TMainForm.SelectMidiFile(const FileName:string);
var BPMText: string;
begin
  edtInput.Text := ExpandFileName(FileName);

  { MIDI DATAを設定した時点では、CMU DATAの出力先も必ず
    MIDI DATAと同じフォルダへ合わせる。 }
  FInputDir := ExtractFilePath(edtInput.Text);
  OpenDialog.InitialDir := FInputDir;

  FOutputDir := FInputDir;
  SaveDialog.InitialDir := FOutputDir;
  RefreshTempoPreview;
  BPMText := '';
  if (FPreviewFile = ExpandFileName(edtInput.Text)) and
     (FTiming.TempoCount > 0) then
    BPMText := '(' + IntToStr(Trunc(FTiming.ReferenceBPM + 0.5)) + 'BPM)';
  edtOutput.Text := IncludeTrailingPathDelimiter(FInputDir) +
    'CMU ' + ChangeFileExt(ExtractFileName(edtInput.Text), '') + BPMText + '.mzt';
end;

procedure TMainForm.WMDropFiles(var Msg:TWMDropFiles);
var Buf:array[0..MAX_PATH] of Char; FileName,Ext:string;
begin
  try
    if DragQueryFile(Msg.Drop,0,Buf,Length(Buf))=0 then Exit;
    FileName:=Buf; Ext:=LowerCase(ExtractFileExt(FileName));
    if (Ext<>'.mid') and (Ext<>'.midi') then begin
      MessageDlg('Drop a MIDI file (*.mid or *.midi).',mtWarning,[mbOK],0);
      Exit;
    end;
    SelectMidiFile(FileName);
    Log('MIDIファイルをドロップしました: '+FileName);
  finally DragFinish(Msg.Drop); end;
end;

procedure TMainForm.Log(const S: string);
begin memLog.Lines.Add(S); Application.ProcessMessages; end;

procedure TMainForm.btnInputClick(Sender: TObject);
var Dir: string;
begin
  { Prefer the folder currently written in MIDI DATA. }
  Dir := ValidFolderFromText(edtInput.Text);
  if Dir <> '' then
    OpenDialog.InitialDir := Dir
  else if (FInputDir <> '') and DirectoryExists(FInputDir) then
    OpenDialog.InitialDir := FInputDir;
  if OpenDialog.Execute then SelectMidiFile(OpenDialog.FileName);
end;

procedure TMainForm.btnOutputClick(Sender: TObject);
var Dir: string;
begin
  { Prefer the folder currently written in CMU DATA. }
  Dir := ValidFolderFromText(edtOutput.Text);
  if Dir <> '' then
    SaveDialog.InitialDir := Dir
  else if (FOutputDir <> '') and DirectoryExists(FOutputDir) then
    SaveDialog.InitialDir := FOutputDir;
  SaveDialog.FileName := ExtractFileName(edtOutput.Text);
  if SaveDialog.Execute then begin
    edtOutput.Text := SaveDialog.FileName;
    FOutputDir:=ExtractFilePath(ExpandFileName(edtOutput.Text));
  end;
end;

procedure TMainForm.edtInputExit(Sender: TObject);
var S: string;
begin
  S := Trim(edtInput.Text);
  if (S <> '') and FileExists(S) and
     (SameText(ExtractFileExt(S), '.mid') or SameText(ExtractFileExt(S), '.midi')) then
    SelectMidiFile(S);
end;

function TMainForm.ReadBE16(const B: TBytes; var P: Integer): Cardinal;
begin
  if P + 2 > Length(B) then raise EReadError.Create('MIDIファイルが途中で終わっています。');
  Result := (Cardinal(B[P]) shl 8) or B[P+1]; Inc(P,2);
end;

function TMainForm.ReadBE32(const B: TBytes; var P: Integer): Cardinal;
begin
  if P + 4 > Length(B) then raise EReadError.Create('MIDIファイルが途中で終わっています。');
  Result := (Cardinal(B[P]) shl 24) or (Cardinal(B[P+1]) shl 16) or
            (Cardinal(B[P+2]) shl 8) or B[P+3]; Inc(P,4);
end;

function TMainForm.ReadVarLen(const B: TBytes; var P: Integer; Limit: Integer): Cardinal;
var C: Byte; N: Integer;
begin
  Result := 0;
  for N := 0 to 3 do begin
    if P >= Limit then raise EReadError.Create('可変長数値が不正です。');
    C := B[P]; Inc(P); Result := (Result shl 7) or (C and $7F);
    if (C and $80) = 0 then Exit;
  end;
  raise EReadError.Create('可変長数値が長すぎます。');
end;

procedure TMainForm.ParseTrack(const B: TBytes; StartPos, TrackLen: Integer);
type TActive = record
       Used,KeyDown:Boolean;
       StartTick:Int64;
       Velocity,ProgramNo:Integer;
     end;
var P,L,Status,D1,D2,Ch,N,MetaType:Integer; Tick:Int64;
    Delta,Sz:Cardinal; Active:array[0..15,0..127] of TActive;
    Programs:array[0..15] of Integer;
    Note:TMidiNote;

  procedure FinishNote(AChannel,ANote:Integer);
  begin
    if not Active[AChannel,ANote].Used then Exit;
    Note.StartTick:=Active[AChannel,ANote].StartTick;
    Note.EndTick:=Tick;
    Note.Note:=ANote;
    Note.Velocity:=Active[AChannel,ANote].Velocity;
    Note.Channel:=AChannel;
    Note.ProgramNo:=Active[AChannel,ANote].ProgramNo;
    Note.OrderNo := FNotes.Count;
    FNotes.Add(Note);
    Active[AChannel,ANote].Used:=False;
    Active[AChannel,ANote].KeyDown:=False;
  end;
begin
  FillChar(Active,SizeOf(Active),0); FillChar(Programs,SizeOf(Programs),0);
  P:=StartPos; L:=StartPos+TrackLen;
  Status := 0; Tick := 0;
  while P < L do begin
    Delta := ReadVarLen(B,P,L); Inc(Tick,Delta);
    if P >= L then raise EReadError.Create('MIDIイベントが途中で切れています。');
    if B[P] >= $80 then begin Status := B[P]; Inc(P); end
    else if Status = 0 then raise EReadError.Create('ランニングステータスに必要な先行ステータスバイトがありません。');
    if Status = $FF then begin
      if P >= L then raise EReadError.Create('MIDIメタイベントが途中で切れています。'); MetaType := B[P]; Inc(P); Sz := ReadVarLen(B,P,L);
      if Sz > Cardinal(L-P) then raise EReadError.Create('MIDIメタイベントが不正です。');
      if MetaType = $51 then begin
        if Sz <> 3 then raise EReadError.Create('MIDIのテンポ指定イベントが不正です。');
        FTiming.AddTempo(Tick, (Integer(B[P]) shl 16) or
          (Integer(B[P+1]) shl 8) or Integer(B[P+2]));
      end;
      Inc(P,Integer(Sz)); if MetaType = $2F then Break; Status := 0; Continue;
    end;
    if (Status = $F0) or (Status = $F7) then begin
      Sz:=ReadVarLen(B,P,L);
      if Sz>Cardinal(L-P) then raise EReadError.Create('MIDIのシステムエクスクルーシブイベントが不正です。');
      Inc(P,Integer(Sz)); Status:=0; Continue;
    end;
    if P >= L then raise EReadError.Create('MIDIチャンネルイベントが途中で切れています。');
    if ((Status and $F0) in [$80,$90,$A0,$B0,$E0]) and (P+1 >= L) then
      raise EReadError.Create('MIDIチャンネルイベントが途中で切れています。');
    Ch := Status and $0F;
    case Status and $F0 of
      $80,$90,$A0,$B0,$E0: begin D1:=B[P]; D2:=B[P+1]; Inc(P,2); end;
      $C0,$D0: begin D1:=B[P]; D2:=0; Inc(P); end;
    else raise EReadError.CreateFmt('未対応のMIDIステータスです: %.2x',[Status]); end;
    if (D1 > 127) or (D2 > 127) then raise EReadError.Create('MIDIのデータバイトが不正です。');
    if (Status and $F0)=$C0 then begin Programs[Ch]:=D1; Continue; end;
    if ((Status and $F0)=$B0) and (D1=64) then begin
      { v0.37: CMU-800 has only six physical note voices. Do not extend a
        physical voice until sustain-pedal release; key release frees it. }
      Continue;
    end;
    if ((Status and $F0)=$90) and (D2>0) then begin
      if Active[Ch,D1].Used then FinishNote(Ch,D1);
      Active[Ch,D1].Used:=True; Active[Ch,D1].KeyDown:=True;
      Active[Ch,D1].StartTick:=Tick; Active[Ch,D1].Velocity:=D2;
      Active[Ch,D1].ProgramNo:=Programs[Ch];
    end else if ((Status and $F0)=$80) or (((Status and $F0)=$90) and (D2=0)) then begin
      if Active[Ch,D1].Used then begin
        Active[Ch,D1].KeyDown:=False;
        { v0.37: release the CMU physical voice at the actual MIDI key-off. }
        FinishNote(Ch,D1);
      end;
    end;
  end;
  for Ch:=0 to 15 do for N:=0 to 127 do if Active[Ch,N].Used then FinishNote(Ch,N);
end;

procedure TMainForm.ParseMidi(const FileName: string; ALog: Boolean);
var B:TBytes; P, I, Tracks, MidiFormat, HLen, TLen:Integer; FS:TFileStream;
begin
  FPreviewFile := '';
  FLastNoteTick := 0;
  FNotes.Clear; FTiming.Clear; FS:=TFileStream.Create(FileName,fmOpenRead or fmShareDenyWrite);
  try
    if FS.Size>MaxInt then raise EReadError.Create('MIDIファイルが大きすぎます。');
    SetLength(B,Integer(FS.Size));
    if Length(B)>0 then FS.ReadBuffer(B[0],Length(B));
  finally FS.Free; end;
  P:=0; if (Length(B)<14) or (AnsiChar(B[0])<>'M') or (AnsiChar(B[1])<>'T') or
    (AnsiChar(B[2])<>'h') or (AnsiChar(B[3])<>'d') then raise EReadError.Create('標準MIDIファイルではありません。');
  P:=4; HLen:=ReadBE32(B,P); MidiFormat:=ReadBE16(B,P); Tracks:=ReadBE16(B,P); FDivision:=ReadBE16(B,P);
  if (MidiFormat > 1) then raise EReadError.Create('MIDI形式0と1に対応しています。他の形式は未対応です。');
  if (HLen < 6) or (HLen > Length(B)-8) then raise EReadError.Create('MIDIヘッダの長さが不正です。');
  if FDivision = 0 then raise EReadError.Create('MIDIの時間分解能が不正です。');
  if (FDivision and $8000)<>0 then raise EReadError.Create('SMPTE形式の時間分解能は未対応です。');
  P:=8+HLen; if ALog then Log(System.SysUtils.Format('MIDI形式: %d／トラック数: %d／四分音符の分解能: %d tick',[MidiFormat,Tracks,FDivision]));
  for I:=0 to Tracks-1 do begin
    if (P+8>Length(B)) or (AnsiChar(B[P])<>'M') or (AnsiChar(B[P+1])<>'T') or
      (AnsiChar(B[P+2])<>'r') or (AnsiChar(B[P+3])<>'k') then raise EReadError.Create('MIDIトラックのMTrkチャンクが見つかりません。');
    Inc(P,4); TLen:=Integer(ReadBE32(B,P)); if (TLen<0) or (P+TLen>Length(B)) then raise EReadError.Create('MIDIトラックのMTrkチャンクが途中で切れています。');
    ParseTrack(B,P,TLen); Inc(P,TLen);
  end;
  FTiming.Prepare(FDivision);
  for I := 0 to FNotes.Count - 1 do
    if FNotes[I].EndTick > FLastNoteTick then FLastNoteTick := FNotes[I].EndTick;
  FPreviewFile := ExpandFileName(FileName);
  if ALog then begin
    Log(Format('音符イベント%d件、テンポ指定イベント%d件を読み込みました。',
      [FNotes.Count, FTiming.TempoCount]));
    Log('基本: 四分音符24 STEP／4/4小節96 STEP。BPM指定なし・1回のみではSTEP長を変更しません。');
    Log(Format('MIDI BPM指定%d件／最初のBPM %.2f。以降は最初のBPMとの比率だけをSTEP長へ反映します。',
      [FTiming.TempoCount, FTiming.ReferenceBPM]));
    LogTempoMap;
  end;
end;

procedure TMainForm.edtInputChange(Sender: TObject);
begin
  FPreviewFile := '';
  lblHint.Caption := 'MIDIの最初のBPMを基準に、以降のテンポ変化だけをSTEPへ反映します。';
end;

procedure TMainForm.RefreshTempoPreview;
begin
  if (FTiming = nil) or not FileExists(edtInput.Text) then begin
    FPreviewFile := '';
    lblHint.Caption := 'MIDIの最初のBPMを基準に、以降のテンポ変化だけをSTEPへ反映します。';
    Exit;
  end;
  try
    if FPreviewFile <> ExpandFileName(edtInput.Text) then
      ParseMidi(edtInput.Text, False)
    else FTiming.Prepare(FDivision);
    if FTiming.TempoCount = 0 then
      lblHint.Caption := 'MIDI BPM指定なし: 4/4の1小節96 STEPを維持します。'
    else if FTiming.TempoCount = 1 then
      lblHint.Caption := Format('MIDI BPM指定1回（%.2f BPM）: 4/4の1小節96 STEPを維持します。', [FTiming.ReferenceBPM])
    else
      lblHint.Caption := Format('最初のBPM %.2f／BPM指定%d件。以降は96×最初のBPM÷その区間のBPMで換算します。',
        [FTiming.ReferenceBPM, FTiming.TempoCount]);
  except
    on E: Exception do begin
      FPreviewFile := '';
      lblHint.Caption := 'BPM読み取り不可: ' + E.Message;
    end;
  end;
end;

procedure TMainForm.LogTempoMap;
var I: Integer; P: TTempoPoint; BPM: Double;
begin
  Log('MIDIテンポとSTEP換算（最初の指定を基準とする相対変化のみ）:');
  for I := 0 to FTiming.PointCount - 1 do begin
    P := FTiming.TempoPoint(I);
    if I < FTiming.PointCount - 1 then
      if FTiming.TempoPoint(I+1).Tick = P.Tick then Continue;
    if P.Tick > FLastNoteTick then Break;
    BPM := 60000000.0 / P.MicrosecondsPerQuarter;
    Log(Format('  tick %d: %.2f BPM／このテンポ一定の4/4小節は%.2f STEP',
      [P.Tick, BPM, 96.0 * FTiming.ReferenceBPM / BPM]));
  end;
end;

function TMainForm.SelectedVelocityGateMode: TVelocityGateMode;
begin
  if cmbVelocityGate.ItemIndex in [Ord(vgAuto),Ord(vgOn),Ord(vgOff)] then
    Result := TVelocityGateMode(cmbVelocityGate.ItemIndex)
  else Result := vgAuto;
end;

function TMainForm.ResolveVelocityGate: Boolean;
var
  Analysis: TVelocityGateAnalysis;
  N: TMidiNote;
  Mode: TVelocityGateMode;
  Duration: Extended;
  ResultText: string;
begin
  Mode := SelectedVelocityGateMode;
  Analysis := Default(TVelocityGateAnalysis);
  if Mode = vgAuto then
    for N in FNotes do
    begin
      { Match Native Rhythm's percussion classification. BASS is included.
        Before allocation/rounding: the estimate describes the source notes,
        and tempo changes within a note contribute their actual duration.
        The tempo reference cancels from the retained-duration ratio. }
      if (N.Channel = 9) or (N.ProgramNo in [112..119]) then Continue;
      Duration := FTiming.TickToStepPosition(N.EndTick) -
        FTiming.TickToStepPosition(N.StartTick);
      Analysis.AddNote(Duration, N.Velocity);
    end;
  Result := Analysis.Resolve(Mode);
  if Result then ResultText := 'ON' else ResultText := 'OFF';
  if Mode = vgAuto then
  begin
    if Analysis.NoteCount = 0 then
      Log('Velocity→GATE 自動: 対象音符なし。従来の既定ONを使用します。')
    else
      Log(Format('Velocity→GATE 自動: 発音時間保持率 %.2f%% → %s（判定境界 %.0f%%、対象%d音）',
        [Analysis.RetainedPercent, ResultText, CAutomaticGateThresholdPercent, Analysis.NoteCount]));
    Log('自動判定は元MIDIの音長とVelocityによる推定です。必要に応じてON／OFFを指定してください。');
  end
  else Log('Velocity→GATE 手動: ' + ResultText);
end;

procedure TMainForm.BuildTracks(Tracks: TObjectList<TTrackData>);
type
  TAssignedNote = record
    StartPos, EndPos, OriginalEndPos: Int64;
    OrigStartTick: Int64;
    Note, Velocity: Integer;
  end;
const
  PriorityText: array[Boolean] of string = ('OFF','ON');
var
  UseVelocityGate: Boolean;
  Sorted: TList<TMidiNote>;
  Voices: array[0..5] of TList<TAssignedNote>;
  Drums: TDictionary<Int64,Byte>;
  N: TMidiNote;
  A: TAssignedNote;
  I, J, Part, Dur, Gate, Dropped, Pitch, BestV, NextPhysicalVoice: Integer;
  S, E, Cursor, NextStart, BestEnd: Int64;
  Mask: Byte;
  Keys: TList<Int64>;
  Patterns: TList<string>;
  PatternMap: TDictionary<string,Integer>;
  Orders: TList<Integer>;
  MeasureEnds: TList<Int64>;
  MeasureTicks, MeasureStartTick, MeasureEndTick: Int64;
  KeyIndex, BarUnits: Integer;
  RawStart, RawEnd, RawSlot: Extended;
  MeasureCount, M, Slot, PatternNo, SlotStart, SlotEnd, SlotDur: Integer;
  MelodyInputCount, MelodySameStartRemoved: Integer;
  PercussionInputCount, Replaced, MelodyChannel, C: Integer;
  ChannelCounts, ChannelOverlap: array[0..15] of Integer;
  ChannelPitch: array[0..15] of Int64;
  ChannelEnd: array[0..15] of Int64;
  Score, BestScore: Double;
  ExtCY51, ExtCY52, ExtCY53, ExtCY55, ExtCY59: Integer;
  Sig: string;
  Code: Byte;

  procedure LogRepresentativeMeasureST;
  var
    Totals: TDictionary<Int64,Int64>;
    Index: Integer;
    PreviousEnd, LengthST, SumST, RepresentativeST, BestTotal: Int64;
  begin
    { Reporting only: never normalize or change any measure/event endpoint.
      Group equal measure ST values and sum their elapsed step durations.
      The group occupying the longest time is representative; ties use the
      first encountered measure length. }
    Totals := TDictionary<Int64,Int64>.Create;
    try
      PreviousEnd := 0;
      for Index := 0 to MeasureEnds.Count - 1 do
      begin
        LengthST := MeasureEnds[Index] - PreviousEnd;
        PreviousEnd := MeasureEnds[Index];
        if not Totals.TryGetValue(LengthST, SumST) then SumST := 0;
        Totals.AddOrSetValue(LengthST, SumST + LengthST);
      end;
      PreviousEnd := 0;
      RepresentativeST := 96;
      BestTotal := -1;
      for Index := 0 to MeasureEnds.Count - 1 do
      begin
        LengthST := MeasureEnds[Index] - PreviousEnd;
        PreviousEnd := MeasureEnds[Index];
        SumST := Totals[LengthST];
        if SumST > BestTotal then
        begin
          BestTotal := SumST;
          RepresentativeST := LengthST;
        end;
      end;
      Log(Format('代表TOTAL ST: %d（%d小節／累積%d ST、表示用）',
        [RepresentativeST, BestTotal div RepresentativeST, BestTotal]));
    finally
      Totals.Free;
    end;
  end;

  function QuantizeTick(ATick: Int64): Int64;
  begin
    Result := FTiming.TickToStep(ATick);
  end;

  function RhythmHitBits(ANote, AProgram: Integer): Byte;
  begin
    { Native Rhythm: CMU-800 drum map from the supplied reference table.
      HIT MASK (1 = request this drum); CH0 stores the active-low inverse.
        $40 BD, $20 SD, $10 LT, $08 MT, $04 CY, $02 OH, $01 CH.

      Official fixed map:
        BD 35,36 / SD 38,40 / LT 41,43,45,47 / MT 48,50 /
        CY 49,57 / OH 46 / CH 42.

      User-requested compatibility extension:
        51,52,53,55,59 -> CY; 44 (Pedal Hi-Hat) -> CH.
      These extended CY notes are counted and reported in the conversion log. }
    case ANote of
      35,36:             Result := $40; { BD }
      38,40:             Result := $20; { SD }
      41,43,45,47:       Result := $10; { LT }
      48,50:             Result := $08; { MT }
      49,57:             Result := $04; { CY: official map }
      51,52,53,55,59:    Result := $04; { CY: compatibility extension }
      46:                Result := $02; { OH }
      42,44:             Result := $01; { CH: closed / pedal hi-hat }
    else
      Result := $00; { Not defined by the CMU-800 drum map: do not invent a voice. }
    end;
  end;

  function IsPercussion(const X: TMidiNote): Boolean;
  begin
    Result := (X.Channel = 9) or (X.ProgramNo in [112..119]);
  end;

  function IsBass(const X: TMidiNote): Boolean;
  begin
    { Explicit GM Bass programs only (zero-based 32..39).
      Low pitch or a MIDI channel number never establishes a BASS role. }
    Result := X.ProgramNo in [32..39];
  end;

  function VoiceFreeAt(V: Integer): Int64;
  begin
    if Voices[V].Count = 0 then Exit(0);
    Result := Voices[V][Voices[V].Count-1].EndPos;
  end;

  function LastVoiceNote(V: Integer; ADefault: Integer): Integer;
  begin
    if Voices[V].Count = 0 then Exit(ADefault);
    Result := Voices[V][Voices[V].Count-1].Note;
  end;

  function ChooseFreeChordVoice(AStart: Int64; ANote: Integer): Integer;
  var
    V, D, BestD: Integer;
  begin
    Result := -1;
    BestD := MaxInt;
    { v0.27: voice leading. Among free harmony voices choose the voice whose
      previous pitch is nearest to the new pitch. }
    for V := 2 to 5 do
      if VoiceFreeAt(V) <= AStart then
      begin
        if Voices[V].Count = 0 then D := 0
        else D := Abs(LastVoiceNote(V, ANote) - ANote);
        if (Result < 0) or (D < BestD) then
        begin
          Result := V;
          BestD := D;
        end;
      end;
  end;

  function IsMelodyCandidate(const X: TMidiNote): Boolean;
  var K: Integer; Other: TMidiNote;
  begin
    Result := X.Channel = MelodyChannel;
    if not Result then Exit;
    { A chord carried by the melody MIDI channel contributes only its top
      note to CH1. The other notes remain accompaniment candidates. }
    for K := 0 to Sorted.Count - 1 do begin
      Other := Sorted[K];
      if Other.StartTick > X.StartTick then Break;
      if (Other.StartTick = X.StartTick) and (Other.Channel = X.Channel) and
         not IsPercussion(Other) and not IsBass(Other) and
         (Other.Note > X.Note) then Exit(False);
    end;
  end;

  function ReplaceLowerVoice(AStart: Int64; ANote: Integer;
    MelodyOnly: Boolean): Integer;
  var V, Lowest: Integer; Previous: TAssignedNote;
  begin
    Result := -1;
    Lowest := ANote;
    for V := 0 to 5 do begin
      if V = 1 then Continue;
      if MelodyOnly and (V <> 0) then Continue;
      if (VoiceFreeAt(V) > AStart) and
         (LastVoiceNote(V, ANote) < Lowest) then begin
        Lowest := LastVoiceNote(V, ANote);
        Result := V;
      end;
    end;
    if Result >= 0 then begin
      Previous := Voices[Result][Voices[Result].Count-1];
      Previous.EndPos := AStart;
      Voices[Result][Voices[Result].Count-1] := Previous;
      Inc(Replaced);
    end;
  end;

  procedure AssignToVoice(V: Integer; const X: TMidiNote; AStartPos, AEndPos: Int64);
  var T: TAssignedNote;
  begin
    if (V = 1) and not IsBass(X) then
      raise EConvertError.Create('CH2はBASS専用です。BASS以外の音は割り当てできません。');
    if (V <> 1) and IsBass(X) then
      raise EConvertError.Create('BASSはCH2に割り当てる必要があります。');
    T.StartPos := AStartPos;
    T.EndPos := AEndPos;
    T.OriginalEndPos := AEndPos;
    T.OrigStartTick := X.StartTick;
    T.Note := X.Note;
    T.Velocity := X.Velocity;
    Voices[V].Add(T);
  end;

  function ChoosePhysicalVoice(AStart: Int64): Integer;
  const
    PhysicalVoices: array[0..4] of Integer = (0,2,3,4,5);
  var K, RotationIndex, V: Integer;
  begin
    Result := -1;
    { Explicit five-voice ring: CH1 -> CH3 -> CH4 -> CH5 -> CH6.
      Skip occupied voices without ever borrowing BASS/CH2. }
    for K := 0 to High(PhysicalVoices) do
    begin
      RotationIndex := (NextPhysicalVoice + K) mod Length(PhysicalVoices);
      V := PhysicalVoices[RotationIndex];
      if VoiceFreeAt(V) <= AStart then
      begin
        Result := V;
        NextPhysicalVoice := (RotationIndex + 1) mod Length(PhysicalVoices);
        Exit;
      end;
    end;
  end;

  procedure EmitDuration(TrackIndex, NoteValue: Integer; Duration: Int64;
    GateValue: Integer; var TimePos: Int64);
  var
    Chunk, ToMeasure, ChunkGate, Lo, Hi, Mid: Integer;
    Boundary: Int64;
  begin
    while Duration > 0 do
    begin
      { Find the next original-MIDI measure boundary on the mapped timeline. }
      Lo := 0; Hi := MeasureEnds.Count;
      while Lo < Hi do begin
        Mid := Lo + (Hi - Lo) div 2;
        if MeasureEnds[Mid] <= TimePos then Lo := Mid + 1 else Hi := Mid;
      end;
      if Lo >= MeasureEnds.Count then
        raise EConvertError.Create('音符がMIDIの小節時間軸の範囲を超えています。');
      Boundary := MeasureEnds[Lo];
      ToMeasure := Integer(Boundary - TimePos);
      Chunk := Integer(Min(Duration, Int64(ToMeasure)));
      if NoteValue = 0 then
        ChunkGate := 0
      else
      begin
        ChunkGate := Min(GateValue, Chunk);
        if ChunkGate < 1 then ChunkGate := 1;
      end;
      if GateValue <= 0 then Tracks[TrackIndex].AddEvent(0, Chunk, 0)
      else Tracks[TrackIndex].AddEvent(NoteValue, Chunk, ChunkGate);
      Inc(TimePos, Chunk);
      Dec(Duration, Chunk);
      GateValue := Max(0, GateValue - Chunk);

      { Note and rhythm FD markers share original-MIDI measure boundaries. }
      if TimePos = Boundary then
      begin
        Tracks[TrackIndex].Add($FD);
        Tracks[TrackIndex].Add(0);
        Tracks[TrackIndex].Add(0);
      end;
    end;
  end;

begin
  UseVelocityGate := ResolveVelocityGate;
  MeasureEnds := TList<Int64>.Create;
  Sorted := TList<TMidiNote>.Create;
  Drums := TDictionary<Int64,Byte>.Create;
  Keys := TList<Int64>.Create;
  Patterns := TList<string>.Create;
  PatternMap := TDictionary<string,Integer>.Create;
  Orders := TList<Integer>.Create;
  for I := 0 to 5 do Voices[I] := TList<TAssignedNote>.Create;
  try
    Sorted.AddRange(FNotes);
    Sorted.Sort(TComparer<TMidiNote>.Construct(
      function(const X,Y: TMidiNote): Integer
      begin
        if X.StartTick < Y.StartTick then Exit(-1);
        if X.StartTick > Y.StartTick then Exit(1);
        if chkMelodyPriority.Checked then begin
          if X.Note > Y.Note then Exit(-1);
          if X.Note < Y.Note then Exit(1);
        end;
        Result := X.OrderNo - Y.OrderNo;
      end));

    MeasureTicks := Int64(FDivision) * 4; { existing 4/4 convention }
    MeasureCount := Max(1, Integer((FLastNoteTick + MeasureTicks - 1) div MeasureTicks));
    for M := 1 to MeasureCount do begin
      E := QuantizeTick(Int64(M) * MeasureTicks);
      if (M = 1) and (E < 1) then
        raise EConvertError.Create('MIDIの1小節がCMUの1 STEPより短くなっています。');
      if (M > 1) and (E <= MeasureEnds[M-2]) then
        raise EConvertError.Create('MIDIの1小節がCMUの1 STEPより短くなっています。');
      MeasureEnds.Add(E);
    end;
    LogRepresentativeMeasureST;
    Log('CC64のサステインでは物理CHの占有時間を延長しません。MIDIのキーオフ時にCHを解放します。');
    Dropped := 0;
    MelodyInputCount := 0;
    MelodySameStartRemoved := 0;
    NextPhysicalVoice := 0;
    PercussionInputCount := 0;
    Replaced := 0;
    ExtCY51 := 0; ExtCY52 := 0; ExtCY53 := 0; ExtCY55 := 0; ExtCY59 := 0;

    FillChar(ChannelCounts, SizeOf(ChannelCounts), 0);
    FillChar(ChannelOverlap, SizeOf(ChannelOverlap), 0);
    FillChar(ChannelPitch, SizeOf(ChannelPitch), 0);
    FillChar(ChannelEnd, SizeOf(ChannelEnd), 0);
    for I := 0 to Sorted.Count - 1 do begin
      N := Sorted[I];
      if IsPercussion(N) or IsBass(N) then Continue;
      C := N.Channel;
      Inc(ChannelCounts[C]);
      Inc(ChannelPitch[C], N.Note);
      if N.StartTick < ChannelEnd[C] then Inc(ChannelOverlap[C]);
      if N.EndTick > ChannelEnd[C] then ChannelEnd[C] := N.EndTick;
    end;
    MelodyChannel := 0;
    BestScore := -1E100;
    for C := 0 to 15 do
      if ChannelCounts[C] > 0 then begin
        { Prefer a high, relatively monophonic line. This is a heuristic,
          not a claim that MIDI contains an explicit melody designation. }
        Score := ChannelPitch[C] / ChannelCounts[C] -
          12.0 * ChannelOverlap[C] / ChannelCounts[C];
        if Score > BestScore then begin BestScore := Score; MelodyChannel := C; end;
      end;

    { Phase 1: quantize every MIDI note onto one common absolute CMU timeline. }
    for I := 0 to Sorted.Count - 1 do
    begin
      N := Sorted[I];
      S := QuantizeTick(N.StartTick);
      E := QuantizeTick(N.EndTick);
      if E <= S then E := S + 1;

      if IsPercussion(N) then
      begin
        Inc(PercussionInputCount);
        Mask := RhythmHitBits(N.Note, N.ProgramNo);
        if Mask <> 0 then
        begin
          case N.Note of
            51: Inc(ExtCY51);
            52: Inc(ExtCY52);
            53: Inc(ExtCY53);
            55: Inc(ExtCY55);
            59: Inc(ExtCY59);
          end;
          if Drums.ContainsKey(N.StartTick) then
            Drums[N.StartTick] := Drums[N.StartTick] or Mask
          else
            Drums.Add(N.StartTick, Mask);
        end;
        Continue;
      end;

      { The three voice options are independent. CH2 is always BASS-only. }
      if IsBass(N) then begin
        if VoiceFreeAt(1) <= S then Part := 1 else Part := -1;
      end
      else if not chkChordSeparation.Checked then begin
        Part := ChoosePhysicalVoice(S);
        if (Part < 0) and chkMelodyPriority.Checked then
          Part := ReplaceLowerVoice(S, N.Note, False);
      end
      else if IsMelodyCandidate(N) then begin
        if VoiceFreeAt(0) <= S then Part := 0
        else if chkMelodyPriority.Checked then
          Part := ReplaceLowerVoice(S, N.Note, True)
        else Part := -1;
      end
      else
        Part := ChooseFreeChordVoice(S, N.Note);
      if Part < 0 then
      begin
        Inc(Dropped);
        { v0.38: per-note DROP diagnostics are disabled. }
        Continue;
      end;
      AssignToVoice(Part, N, S, E);
      if Part = 0 then
        Inc(MelodyInputCount);

    end;

    Log(Format('CH2 BASS: GM音色32～39（0起算）のみ。割当%d音。低音だけではBASS判定しません。',
      [Voices[1].Count]));
    if chkChordSeparation.Checked then
      Log(Format('CHORD分離ON: 主旋律候補のMIDI CH%dをCH1へ、伴奏をCH3～CH6へ割り当てます。', [MelodyChannel+1]))
    else
      Log('CHORD分離OFF: 非BASS音はCH1→CH3→CH4→CH5→CH6を巡回（発音中のCHは飛ばします）。');
    Log(Format('主旋律優先: %s／高い音を残すために置き換えた低い音: %d音',
      [PriorityText[chkMelodyPriority.Checked], Replaced]));
    Log(Format('音符割り当て: CH1=%d音、CH2 BASS=%d音、CH3=%d音、CH4=%d音、CH5=%d音、CH6=%d音／割り当てできなかった音=%d音',
      [Voices[0].Count, Voices[1].Count, Voices[2].Count, Voices[3].Count,
       Voices[4].Count, Voices[5].Count, Dropped]));

    { Phase 2: serialize each voice independently.
      Clamp a note at the next note start so overlapping NOTE ON/OFF pairs cannot
      create a late stray note in the CMU stream. }
    for Part := 0 to 5 do
    begin
      Cursor := 0;
      for I := 0 to Voices[Part].Count - 1 do
      begin
        A := Voices[Part][I];
        if I + 1 < Voices[Part].Count then
        begin
          NextStart := Voices[Part][I+1].StartPos;
          if A.EndPos > NextStart then A.EndPos := NextStart;
        end;
        if A.EndPos <= A.StartPos then Continue;

        if A.StartPos > Cursor then
          EmitDuration(Part + 1, 0, A.StartPos - Cursor, 0, Cursor);

        Dur := Integer(A.EndPos - A.StartPos);
        if UseVelocityGate then
          Gate := Integer(Min(Int64(Dur), Max(Int64(1), ((A.OriginalEndPos - A.StartPos) * A.Velocity) div 127)))
        else
          Gate := Dur;

        { Confirmed from CMUMML.EXE PLAY routine:
          song note < FD is sent to MIDI as song_note + 24.
          Therefore MIDI -> native CMU song data is MIDI note - 24. }
        Pitch := EnsureRange(A.Note - 24, 1, $7C);
        EmitDuration(Part + 1, Pitch, Dur, Gate, Cursor);
      end;
      { Finish active voices at the same final measure as rhythm. }
      if (Voices[Part].Count > 0) and (Cursor < MeasureEnds[MeasureCount-1]) then
        EmitDuration(Part + 1, 0, MeasureEnds[MeasureCount-1] - Cursor, 0, Cursor);
    end;

    { Playback-tested compatibility rhythm path (v0.10e compatible).
      CMU-800 hardware rhythm is NOT CH1..CH8. It is an independent 8255
      Port-B output at I/O $99:
        bit7 BD, bit6 SD, bit5 LT, bit4 HT, bit3 CY, bit2 OH, bit1 CH.
      A drum is triggered by a 1->0 transition and must then be returned to 1.
      Therefore MIDI channel 10 must conceptually map to:
        MIDI drums -> CMU rhythm data -> sequencer playback -> OUT ($99),A
      and must not be described as CMU CH1.
      This compatibility encoder is intentionally retained until the original
      sequencer's rhythm-track timing semantics are completely reconstructed. }
    Keys.AddRange(Drums.Keys);
    Keys.Sort;
    Log(Format('GM／互換リズム音として判定した入力音符: %d音', [PercussionInputCount]));
    if ExtCY51 > 0 then Log(Format('CY追加割り当て: MIDI 51（ライドシンバル1）→ CY: %d打', [ExtCY51]));
    if ExtCY52 > 0 then Log(Format('CY追加割り当て: MIDI 52（チャイニーズシンバル）→ CY: %d打', [ExtCY52]));
    if ExtCY53 > 0 then Log(Format('CY追加割り当て: MIDI 53（ライドベル）→ CY: %d打', [ExtCY53]));
    if ExtCY55 > 0 then Log(Format('CY追加割り当て: MIDI 55（スプラッシュシンバル）→ CY: %d打', [ExtCY55]));
    if ExtCY59 > 0 then Log(Format('CY追加割り当て: MIDI 59（ライドシンバル2）→ CY: %d打', [ExtCY59]));
    Log(Format('MIDIリズム音の打点位置: %d箇所', [Keys.Count]));
    Cursor := 0;
    if chkNativeRhythmV3.Checked and (Keys.Count > 0) then
    begin
      { Original MIDI measure and slot positions define the hit pattern.
        Only slot durations are tempo-mapped. The signature includes note,
        ST and gate, so patterns with different timing are never conflated. }
      KeyIndex := 0;
      for M := 0 to MeasureCount - 1 do begin
        MeasureStartTick := Int64(M) * MeasureTicks;
        MeasureEndTick := MeasureStartTick + MeasureTicks;
        RawStart := FTiming.TickToStepPosition(MeasureStartTick);
        RawEnd := FTiming.TickToStepPosition(MeasureEndTick);
        if M = 0 then BarUnits := Integer(MeasureEnds[M])
        else BarUnits := Integer(MeasureEnds[M] - MeasureEnds[M-1]);
        if BarUnits < 16 then
          raise EConvertError.Create('内蔵リズムには1小節あたり16 STEP以上必要です。演奏速度％を下げてください。');
        SetLength(Sig, 48);
        SlotStart := 0;
        for Slot := 0 to 15 do begin
          { Normalize local cumulative time to the rounded measure length.
            Stable tempos therefore share a signature whenever bar length agrees.
            Preserve at least one step for each remaining slot. }
          RawSlot := FTiming.TickToStepPosition(
            Extended(MeasureStartTick) + Extended(Slot+1) * MeasureTicks / 16);
          if Slot = 15 then SlotEnd := BarUnits
          else SlotEnd := EnsureRange(Integer(Trunc(
            (RawSlot - RawStart) * BarUnits / (RawEnd - RawStart) + 0.5 + 1E-9)),
            SlotStart + 1, BarUnits - (15-Slot));
          SlotDur := SlotEnd - SlotStart;
          if SlotDur > 127 then
            raise EConvertError.Create('内蔵リズムの1枠が127 STEPを超えています。演奏速度％を上げてください。');
          Sig[Slot*3+1] := Char($7F);
          Sig[Slot*3+2] := Char(SlotDur);
          Sig[Slot*3+3] := Char(1);
          SlotStart := SlotEnd;
        end;
        while KeyIndex < Keys.Count do begin
          S := Keys[KeyIndex];
          if S >= MeasureEndTick then Break;
          if S >= MeasureStartTick then begin
            Slot := Integer(((S - MeasureStartTick) * 16 + MeasureTicks div 2) div MeasureTicks);
            Slot := EnsureRange(Slot, 0, 15);
            Mask := Drums[S];
            Code := Byte(Ord(Sig[Slot*3+1]));
            Sig[Slot*3+1] := Char(Code and Byte($7F and (not Mask)));
          end;
          Inc(KeyIndex);
        end;
        if not PatternMap.TryGetValue(Sig, PatternNo) then begin
          PatternNo := Patterns.Count + 1;
          Patterns.Add(Sig);
          PatternMap.Add(Sig, PatternNo);
        end;
        Orders.Add(PatternNo);
      end;

      if Patterns.Count > $FC then
        raise EConvertError.CreateFmt(
          '内蔵リズム: 異なるパターン%d個がCMUのパターン表の上限を超えています。',
          [Patterns.Count]);

      { CH0 stores exactly 16 records with the measure's mapped ST values. }
      for M := 0 to Patterns.Count - 1 do begin
        Sig := Patterns[M];
        for Slot := 0 to 15 do begin
          Tracks[0].Add(Byte(Ord(Sig[Slot*3+1])));
          Tracks[0].Add(Byte(Ord(Sig[Slot*3+2])));
          Tracks[0].Add(Byte(Ord(Sig[Slot*3+3])));
        end;
        Tracks[0].Add($FD);
        Tracks[0].Add($0C);
        Tracks[0].Add($06);
      end;

       { CH9 rhythm table/order: every record is a 1-based pattern number.
        Additional CMU DATA disproved the former 'first record = pattern count'
        interpretation.  Parameter bytes are 00,00 in the analyzed samples. }
      { CH9 is a pattern-order table from its first record; no count header. }
      { Do not use AddEvent(...,0,0) here: AddEvent emits nothing when
        ALen=0.  CH9 is a raw three-byte pattern sequence record. }
      for I := 0 to Orders.Count - 1 do
      begin
        Tracks[9].Add(Byte(Orders[I]));
        Tracks[9].Add($00);
        Tracks[9].Add($00);
      end;

      Log(Format('内蔵リズム: MIDIの%d小節 → CH0の異なるパターン%d個／CH9の演奏順序%d件',
        [MeasureCount, Patterns.Count, Orders.Count]));
    end
    else
    begin
      { Native Rhythm OFF: leave CH9 empty.  In v0.24 the legacy rhythm
        stream was written after the real CH9 because of the extra leading
        FE segment, so PLAYER V0.33B did not use it.  After fixing the
        CH0..CH9 alignment, putting that stream in Tracks[9] would be
        misread as CH9 pattern numbers.  Keeping CH9 empty preserves the
        playback-tested OFF behaviour. }
      if chkNativeRhythmV3.Checked then Log('内蔵リズム: 対応するリズム音がないため、リズムデータを生成しません。')
      else Log('内蔵リズムOFF: リズムデータを生成しません。');
    end;

    for I := 0 to 9 do
    begin
      { Standard CMU channel terminator: FE 0C 06 }
      Tracks[I].Add($FE);
      Tracks[I].Add($0C);
      Tracks[I].Add($06);
    end;

    Log(Format('CMU時間軸: 元MIDIの4/4拍子%d小節。テンポに合わせたST長で、音符とリズムのFD区切り位置をそろえます。', [MeasureCount]));
    Log('音程変換: CMUの音符値＝MIDIノート番号－24。');
    if Dropped > 0 then
      Log(Format('同時発音できるCH数を超えたため、%d音を出力しませんでした。',
        [Dropped]));
  finally
    for I := 0 to 5 do Voices[I].Free;
    Orders.Free;
    PatternMap.Free;
    Patterns.Free;
    Keys.Free;
    Drums.Free;
    Sorted.Free;
    MeasureEnds.Free;
  end;
end;

procedure TMainForm.SaveCMUData(const FileName:string; Tracks:TObjectList<TTrackData>; BaseAddress:Word);
var OutB,Header:TBytes; I,J,P,NameLen:Integer; FS:TFileStream;
    MZTName:AnsiString; IsMZT:Boolean;
begin
  { PLAYER V0.33B treats $337D itself as CH0.  Do not prepend an empty
    FE record: Tracks[0..9] map directly to CH0..CH9. }
  SetLength(OutB,0);
  for I:=0 to 9 do begin P:=Length(OutB); SetLength(OutB,P+Length(Tracks[I].Data));
    for J:=0 to High(Tracks[I].Data) do OutB[P+J]:=Tracks[I].Data[J]; end;
  if Cardinal(BaseAddress)+Cardinal(Length(OutB))>$10000 then raise ERangeError.Create('出力データがアドレス$10000未満の範囲に収まりません。');
  IsMZT:=SameText(ExtractFileExt(FileName),'.mzt');
  FS:=TFileStream.Create(FileName,fmCreate);
  try
    if IsMZT then begin
      SetLength(Header,128);
      FillChar(Header[0],Length(Header),$FF);
      Header[0]:=$C8;                    { CMU-800 DATA MZT mode ID }
      for I:=1 to 17 do Header[I]:=$0D; { filename area + mandatory CR }
      MZTName:=AnsiString(UpperCase(ChangeFileExt(ExtractFileName(FileName),'')));
      NameLen:=Min(16,Length(MZTName));   { filename is at most 16 bytes }
      for I:=1 to NameLen do Header[I]:=Byte(MZTName[I]);
      Header[$11]:=$0D;                  { byte 17 must always be CR }
      Header[$12]:=Byte(Length(OutB));
      Header[$13]:=Byte(Length(OutB) shr 8);
      Header[$14]:=Byte(BaseAddress);
      Header[$15]:=Byte(BaseAddress shr 8);
      Header[$16]:=$A0;                 { restart CMU PLAYER at $12A0 }
      Header[$17]:=$12;
      FS.WriteBuffer(Header[0],Length(Header));
    end;
    if Length(OutB)>0 then FS.WriteBuffer(OutB[0],Length(OutB));
  finally FS.Free; end;
  if IsMZT then
    Log(Format('MZT保存完了: ヘッダ128バイト＋データ%dバイト／ロードアドレス$%.4x／実行アドレス$12A0',[Length(OutB),BaseAddress]))
  else
    Log(Format('CMUデータ保存完了: %dバイト／ロードアドレス$%.4x',[Length(OutB),BaseAddress]));
end;

procedure TMainForm.btnConvertClick(Sender:TObject);
var Tracks:TObjectList<TTrackData>; I,Code:Integer; Base:Cardinal;
begin
  memLog.Clear;
  try
    if not FileExists(edtInput.Text) then raise EFileNotFoundException.Create('入力MIDIファイルを指定してください。');
    if edtOutput.Text='' then raise Exception.Create('出力ファイルを指定してください。');
    Val('$'+Trim(edtBase.Text),Base,Code); if (Code<>0) or (Base>$FFFF) then raise Exception.Create('ロードアドレスの16進数指定が不正です。');
    ParseMidi(edtInput.Text); RefreshTempoPreview; Tracks:=TObjectList<TTrackData>.Create(True);
    try for I:=0 to 9 do Tracks.Add(TTrackData.Create); BuildTracks(Tracks); SaveCMUData(edtOutput.Text,Tracks,Word(Base));
    finally Tracks.Free; end;
    Log('変換が完了しました。');
  except on E:Exception do begin Log('エラー: '+E.Message); MessageDlg(E.Message,mtError,[mbOK],0); end; end;
end;

end.
