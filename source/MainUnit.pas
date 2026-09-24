unit MainUnit;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.ShellAPI,
  System.SysUtils, System.UITypes, System.Classes, System.Math, System.IniFiles,
  System.Generics.Collections, System.Generics.Defaults,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.Graphics,
  Vcl.ExtCtrls, Vcl.Dialogs, Vcl.Samples.Spin;

type
  TMidiNote = record
    StartTick, EndTick: Int64;
    Note, Velocity, Channel, ProgramNo: Integer;
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
    lblQuant: TLabel;
    spnQuant: TSpinEdit;
    btnResetSteps: TButton;
    chkVelocityGate: TCheckBox;
    chkRoleVoices: TCheckBox;
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
    procedure btnResetStepsClick(Sender: TObject);
    procedure edtInputExit(Sender: TObject);
  private
    FDivision: Integer;
    FNotes: TList<TMidiNote>;
    FInputDir: string;
    procedure WMDropFiles(var Msg: TWMDropFiles); message WM_DROPFILES;
    function SettingsFileName: string;
    function ValidFolderFromText(const S: string): string;
    procedure LoadSettings;
    procedure SaveSettings;
    procedure SelectMidiFile(const FileName: string);
    function ReadBE16(const B: TBytes; var P: Integer): Cardinal;
    function ReadBE32(const B: TBytes; var P: Integer): Cardinal;
    function ReadVarLen(const B: TBytes; var P: Integer; Limit: Integer): Cardinal;
    procedure ParseMidi(const FileName: string);
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
    Add(Byte(EnsureRange(ANote, 0, 127)));
    Add(Byte(ThisLen));
    if ANote = 0 then
      ThisGate := 0
    else
      ThisGate := EnsureRange(Min(AGate, ThisLen), 1, 127);
    Add(Byte(ThisGate));
    Dec(ALen, ThisLen);
    if AGate > ThisLen then
      Dec(AGate, ThisLen)
    else if ANote <> 0 then
      AGate := 1;
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
  btnResetSteps.Font.Size := 8;
  chkNativeRhythmV3.Checked := True;
  chkVelocityGate.Checked := True;
  chkRoleVoices.Checked := False;
  chkMelodyPriority.Checked := True;
  FNotes := TList<TMidiNote>.Create;
  OpenDialog.Filter := 'Standard MIDI File (*.mid;*.midi)|*.mid;*.midi|All files (*.*)|*.*';
  SaveDialog.Filter := 'MZ tape image (*.mzt)|*.mzt|CMU-800 raw song data (*.cmu)|*.cmu|Binary file (*.bin)|*.bin';
  SaveDialog.DefaultExt := 'mzt';
  SaveDialog.FilterIndex := 1;
  edtBase.Text := '337D'; spnQuant.Value := 44;
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
begin FNotes.Free; inherited; end;

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
var Ini:TIniFile;
begin
  Ini:=TIniFile.Create(SettingsFileName);
  try
    FInputDir:=Ini.ReadString('Folders','Input','');
    chkVelocityGate.Checked:=Ini.ReadBool('Options','VelocityGate',True);
    chkRoleVoices.Checked:=Ini.ReadBool('Options','RoleVoices',False);
    chkMelodyPriority.Checked:=Ini.ReadBool('Options','MelodyPriority',True);
    chkNativeRhythmV3.Checked:=Ini.ReadBool('Options','NativeRhythmV4',True);
    spnQuant.Value:=EnsureRange(Ini.ReadInteger('Options','StepsPerQuarter',44),
      spnQuant.MinValue,spnQuant.MaxValue);
  finally Ini.Free; end;
  if not DirectoryExists(FInputDir) then
    FInputDir := ExtractFilePath(ParamStr(0));
  OpenDialog.InitialDir := FInputDir;
  SaveDialog.InitialDir := FInputDir;
end;

procedure TMainForm.SaveSettings;
var Ini:TIniFile;
begin
  if edtInput.Text<>'' then FInputDir:=ExtractFilePath(ExpandFileName(edtInput.Text));
  try
    Ini:=TIniFile.Create(SettingsFileName);
    try
      Ini.WriteString('Folders','Input',FInputDir);
      Ini.DeleteKey('Folders','Output');
      Ini.WriteInteger('Options','StepsPerQuarter',spnQuant.Value);
      Ini.WriteBool('Options','VelocityGate',chkVelocityGate.Checked);
      Ini.WriteBool('Options','RoleVoices',chkRoleVoices.Checked);
      Ini.WriteBool('Options','MelodyPriority',chkMelodyPriority.Checked);
      Ini.WriteBool('Options','NativeRhythmV4',chkNativeRhythmV3.Checked);
    finally Ini.Free; end;
  except
    { Do not prevent application shutdown if settings cannot be written. }
  end;
end;

procedure TMainForm.SelectMidiFile(const FileName:string);
begin
  edtInput.Text := ExpandFileName(FileName);

  { MIDI DATAを設定した時点では、CMU DATAの出力先も必ず
    MIDI DATAと同じフォルダへ合わせる。 }
  FInputDir := ExtractFilePath(edtInput.Text);
  OpenDialog.InitialDir := FInputDir;

  SaveDialog.InitialDir := FInputDir;
  edtOutput.Text := IncludeTrailingPathDelimiter(FInputDir) +
    'CMU ' + ChangeFileExt(ExtractFileName(edtInput.Text), '.mzt');
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
    Log('MIDI file dropped: '+FileName);
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
  else if (FInputDir <> '') and DirectoryExists(FInputDir) then
    SaveDialog.InitialDir := FInputDir;
  SaveDialog.FileName := ExtractFileName(edtOutput.Text);
  if SaveDialog.Execute then
    edtOutput.Text := SaveDialog.FileName;
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
  if P + 2 > Length(B) then raise EReadError.Create('Unexpected end of MIDI file');
  Result := (Cardinal(B[P]) shl 8) or B[P+1]; Inc(P,2);
end;

function TMainForm.ReadBE32(const B: TBytes; var P: Integer): Cardinal;
begin
  if P + 4 > Length(B) then raise EReadError.Create('Unexpected end of MIDI file');
  Result := (Cardinal(B[P]) shl 24) or (Cardinal(B[P+1]) shl 16) or
            (Cardinal(B[P+2]) shl 8) or B[P+3]; Inc(P,4);
end;

function TMainForm.ReadVarLen(const B: TBytes; var P: Integer; Limit: Integer): Cardinal;
var C: Byte; N: Integer;
begin
  Result := 0;
  for N := 0 to 3 do begin
    if P >= Limit then raise EReadError.Create('Invalid variable length value');
    C := B[P]; Inc(P); Result := (Result shl 7) or (C and $7F);
    if (C and $80) = 0 then Exit;
  end;
  raise EReadError.Create('Variable length value is too long');
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
    if B[P] >= $80 then begin Status := B[P]; Inc(P); end
    else if Status = 0 then raise EReadError.Create('Running status without status byte');
    if Status = $FF then begin
      if P >= L then Break; MetaType := B[P]; Inc(P); Sz := ReadVarLen(B,P,L);
      if P + Integer(Sz) > L then raise EReadError.Create('Invalid meta event');
      Inc(P,Integer(Sz)); if MetaType = $2F then Break; Status := 0; Continue;
    end;
    if (Status = $F0) or (Status = $F7) then begin
      Sz:=ReadVarLen(B,P,L);
      if P+Integer(Sz)>L then raise EReadError.Create('Invalid SysEx event');
      Inc(P,Integer(Sz)); Status:=0; Continue;
    end;
    Ch := Status and $0F;
    case Status and $F0 of
      $80,$90,$A0,$B0,$E0: begin D1:=B[P]; D2:=B[P+1]; Inc(P,2); end;
      $C0,$D0: begin D1:=B[P]; D2:=0; Inc(P); end;
    else raise EReadError.CreateFmt('Unsupported MIDI status %.2x',[Status]); end;
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

procedure TMainForm.ParseMidi(const FileName: string);
var B:TBytes; P, I, Tracks, MidiFormat, HLen, TLen:Integer; FS:TFileStream;
begin
  FNotes.Clear; FS:=TFileStream.Create(FileName,fmOpenRead or fmShareDenyWrite);
  try
    if FS.Size>MaxInt then raise EReadError.Create('MIDI file is too large');
    SetLength(B,Integer(FS.Size));
    if Length(B)>0 then FS.ReadBuffer(B[0],Length(B));
  finally FS.Free; end;
  P:=0; if (Length(B)<14) or (AnsiChar(B[0])<>'M') or (AnsiChar(B[1])<>'T') or
    (AnsiChar(B[2])<>'h') or (AnsiChar(B[3])<>'d') then raise EReadError.Create('Not a Standard MIDI File');
  P:=4; HLen:=ReadBE32(B,P); MidiFormat:=ReadBE16(B,P); Tracks:=ReadBE16(B,P); FDivision:=ReadBE16(B,P);
  if (FDivision and $8000)<>0 then raise EReadError.Create('SMPTE time division is not supported');
  P:=8+HLen; Log(System.SysUtils.Format('MIDI format %d, tracks %d, division %d',[MidiFormat,Tracks,FDivision]));
  for I:=0 to Tracks-1 do begin
    if (P+8>Length(B)) or (AnsiChar(B[P])<>'M') or (AnsiChar(B[P+1])<>'T') or
      (AnsiChar(B[P+2])<>'r') or (AnsiChar(B[P+3])<>'k') then raise EReadError.Create('MTrk chunk not found');
    Inc(P,4); TLen:=Integer(ReadBE32(B,P)); if (TLen<0) or (P+TLen>Length(B)) then raise EReadError.Create('Truncated MTrk chunk');
    ParseTrack(B,P,TLen); Inc(P,TLen);
  end;
  Log(Format('%d note events read',[FNotes.Count]));
end;

procedure TMainForm.BuildTracks(Tracks: TObjectList<TTrackData>);
type
  TAssignedNote = record
    StartPos, EndPos: Int64;
    OrigStartTick: Int64;
    Note, Velocity: Integer;
  end;
var
  Sorted: TList<TMidiNote>;
  MelodyAt: TDictionary<Int64,Integer>;
  Voices: array[0..5] of TList<TAssignedNote>;
  Drums: TDictionary<Int64,Byte>;
  N: TMidiNote;
  A: TAssignedNote;
  I, J, Part, UnitsPerQuarter, MeasureUnits, Dur, Gate, Dropped, Pitch, BestV, NextPhysicalVoice, NextChordVoice: Integer;
  S, E, Cursor, NextStart, BestEnd: Int64;
  Mask: Byte;
  Keys: TList<Int64>;
  Patterns: TList<string>;
  PatternMap: TDictionary<string,Integer>;
  Orders: TList<Integer>;
  MaxSongPos: Int64;
  MeasureCount, M, Slot, PatternNo, SlotStart, SlotEnd, SlotDur: Integer;
  MelodyInputCount, MelodySameStartRemoved: Integer;
  PreemptedCount: Integer;
  PercussionInputCount, HarmonyAddedCount: Integer;
  ExtCY51, ExtCY52, ExtCY53, ExtCY55, ExtCY59: Integer;
  Sig: string;
  Code: Byte;

  function QuantizeTick(ATick: Int64): Int64;
  begin
    { Exact rational conversion.  Do not first truncate FDivision / units.
      This is essential for triplets and MIDI divisions not divisible by 24. }
    Result := (ATick * UnitsPerQuarter + FDivision div 2) div FDivision;
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
        51,52,53,55,59 -> CY.
      These extended CY notes are counted and reported in the conversion log. }
    case ANote of
      35,36:             Result := $40; { BD }
      38,40:             Result := $20; { SD }
      41,43,45,47:       Result := $10; { LT }
      48,50:             Result := $08; { MT }
      49,57:             Result := $04; { CY: official map }
      51,52,53,55,59:    Result := $04; { CY: compatibility extension }
      46:                Result := $02; { OH }
      42:                Result := $01; { CH }
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
    Result := (X.ProgramNo in [32..39]) or
      ((X.Channel <> 0) and (X.Note < 43) and not (X.ProgramNo in [40..95]));
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

  function BassNeededAt(AStart: Int64): Boolean;
  var
    K: Integer;
    BS, BE: Int64;
  begin
    Result := False;
    { Reserve Voice 2 for a real bass note even if pitch sorting makes that
      bass event appear later at the same CMU time. }
    for K := 0 to Sorted.Count - 1 do
      if IsBass(Sorted[K]) and not IsPercussion(Sorted[K]) then
      begin
        BS := QuantizeTick(Sorted[K].StartTick);
        BE := QuantizeTick(Sorted[K].EndTick);
        if BE <= BS then BE := BS + 1;
        if (BS <= AStart) and (BE > AStart) then Exit(True);
      end;
  end;

  procedure AssignToVoice(V: Integer; const X: TMidiNote; AStartPos, AEndPos: Int64);
  var T: TAssignedNote;
  begin
    T.StartPos := AStartPos;
    T.EndPos := AEndPos;
    T.OrigStartTick := X.StartTick;
    T.Note := X.Note;
    T.Velocity := X.Velocity;
    Voices[V].Add(T);
  end;

  function ChoosePhysicalVoice(AStart: Int64): Integer;
  const
    MelodicVoices: array[0..4] of Integer = (0, 2, 3, 4, 5);
  var K, V: Integer;
  begin
    Result := -1;
    for K := 0 to 4 do
    begin
      V := MelodicVoices[(NextPhysicalVoice + K) mod 5];
      if VoiceFreeAt(V) <= AStart then
      begin
        Result := V;
        NextPhysicalVoice := (NextPhysicalVoice + K + 1) mod 5;
        Exit;
      end;
    end;
  end;

  function PreemptLowerNote(AStart: Int64; IncomingPitch: Integer; RoleAllocated: Boolean): Integer;
  var V, FirstVoice, LowPitch: Integer; T: TAssignedNote;
  begin
    Result := -1;
    LowPitch := IncomingPitch;
    if RoleAllocated then FirstVoice := 2 else FirstVoice := 0;
    for V := FirstVoice to 5 do
    begin
      if V = 1 then Continue; { CH2 remains reserved for bass. }
      if Voices[V].Count = 0 then Continue;
      T := Voices[V][Voices[V].Count - 1];
      if (T.StartPos < AStart) and (T.EndPos > AStart) and (T.Note < LowPitch) then
      begin
        Result := V;
        LowPitch := T.Note;
      end;
    end;
    if Result >= 0 then
    begin
      T := Voices[Result][Voices[Result].Count - 1];
      T.EndPos := AStart;
      Voices[Result][Voices[Result].Count - 1] := T;
    end;
  end;

  function ChooseChordVoice(AStart: Int64): Integer;
  var K, V: Integer;
  begin
    Result := -1;
    for K := 0 to 3 do
    begin
      V := 2 + (NextChordVoice + K) mod 4;
      if VoiceFreeAt(V) <= AStart then
      begin
        Result := V;
        NextChordVoice := (NextChordVoice + K + 1) mod 4;
        Exit;
      end;
    end;
  end;

  procedure EmitDuration(TrackIndex, NoteValue: Integer; Duration: Int64;
    GateValue: Integer; var TimePos: Int64);
  var
    Chunk, ToMeasure, ChunkGate: Integer;
  begin
    while Duration > 0 do
    begin
      ToMeasure := MeasureUnits - Integer(TimePos mod MeasureUnits);
      Chunk := Integer(Min(Duration, Int64(ToMeasure)));
      if NoteValue = 0 then
        ChunkGate := 0
      else
      begin
        ChunkGate := Min(GateValue, Chunk);
        if ChunkGate < 1 then ChunkGate := 1;
      end;
      Tracks[TrackIndex].AddEvent(NoteValue, Chunk, ChunkGate);
      Inc(TimePos, Chunk);
      Dec(Duration, Chunk);
      if GateValue > Chunk then Dec(GateValue, Chunk)
      else if NoteValue <> 0 then GateValue := 1;

      { CMUMML writes FD 00 00 at every closing ']' (one 96-step measure).
        Its PLAY routine treats FD as a channel synchronization wait marker. }
      if (TimePos mod MeasureUnits) = 0 then
      begin
        Tracks[TrackIndex].Add($FD);
        Tracks[TrackIndex].Add(0);
        Tracks[TrackIndex].Add(0);
      end;
    end;
  end;

begin
  Sorted := TList<TMidiNote>.Create;
  MelodyAt := TDictionary<Int64,Integer>.Create;
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
        if X.Note > Y.Note then Exit(-1);
        if X.Note < Y.Note then Exit(1);
        Result := 0;
      end));

    UnitsPerQuarter := Max(1, spnQuant.Value);
    MeasureUnits := UnitsPerQuarter * 4;
    Log('v0.38: CC64 sustain does not extend physical-voice occupancy; MIDI key-off releases the voice.');
    Dropped := 0;
    PreemptedCount := 0;
    MelodyInputCount := 0;
    MelodySameStartRemoved := 0;
    NextPhysicalVoice := 0;
    NextChordVoice := 0;
    PercussionInputCount := 0;
    HarmonyAddedCount := 0;
    ExtCY51 := 0; ExtCY52 := 0; ExtCY53 := 0; ExtCY55 := 0; ExtCY59 := 0;

    if chkRoleVoices.Checked then
      for I := 0 to Sorted.Count - 1 do
      begin
        N := Sorted[I];
        if IsPercussion(N) or IsBass(N) then Continue;
        S := QuantizeTick(N.StartTick);
        if not MelodyAt.TryGetValue(S, J) then
          MelodyAt.Add(S, I)
        else if ((N.Channel = 0) and (Sorted[J].Channel <> 0)) or
                (((N.Channel = 0) = (Sorted[J].Channel = 0)) and
                 ((N.Note > Sorted[J].Note) or
                  ((N.Note = Sorted[J].Note) and (N.Velocity > Sorted[J].Velocity)))) then
          MelodyAt[S] := I;
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
          if Drums.ContainsKey(S) then
            Drums[S] := Drums[S] or Mask
          else
            Drums.Add(S, Mask);
        end;
        Continue;
      end;

      { CH2 is reserved for bass.  With role allocation ON, the preferred
        lead uses CH1 and accompaniment uses CH3..CH6.  OFF retains a
        five-voice rotation for all non-bass notes. }
      if IsBass(N) then
      begin
        if VoiceFreeAt(1) <= S then Part := 1 else Part := -1;
      end
      else if chkRoleVoices.Checked then
      begin
        if MelodyAt.TryGetValue(S, J) and (J = I) then
        begin
          Part := 0;
          if VoiceFreeAt(0) > S then
          begin
            J := Voices[0].Count - 1;
            A := Voices[0][J];
            A.EndPos := S;
            Voices[0][J] := A;
          end;
        end
        else
          Part := ChooseChordVoice(S);
      end
      else
        Part := ChoosePhysicalVoice(S);
      if (Part < 0) and (not IsBass(N)) and chkMelodyPriority.Checked then
      begin
        Part := PreemptLowerNote(S, N.Note, chkRoleVoices.Checked);
        if Part >= 0 then Inc(PreemptedCount);
      end;
      if Part < 0 then
      begin
        Inc(Dropped);
        { v0.38: per-note DROP diagnostics are disabled. }
        Continue;
      end;
      AssignToVoice(Part, N, S, E);
      if Part = 0 then
        Inc(MelodyInputCount);

      { v0.34: do not let generated Harmony Boost notes consume a physical
        voice before all original MIDI notes have been allocated. }
    end;

    { v0.34: Melody Collision Rescue is unnecessary with physical-voice
      allocation: quantized collisions use separate free voices. }

    if chkRoleVoices.Checked then
      Log('Role allocation ON: CH1=lead (MIDI CH1 preferred), CH2=Bass, CH3..CH6=accompaniment.')
    else
      Log('Role allocation OFF: CH2=Bass, other notes rotate over CH1 and CH3..CH6.');
    if chkMelodyPriority.Checked then
      Log(Format('Melody Priority ON: %d lower notes shortened to retain higher notes.', [PreemptedCount]));
    Log(Format('Voice counts: CH1=%d, CH2=%d, CH3=%d, CH4=%d, CH5=%d, CH6=%d, dropped=%d',
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
        if chkVelocityGate.Checked then
          Gate := Max(1, (Dur * A.Velocity) div 127)
        else
          Gate := Max(1, (Dur * 7) div 8);

        { Confirmed from CMUMML.EXE PLAY routine:
          song note < FD is sent to MIDI as song_note + 24.
          Therefore MIDI -> native CMU song data is MIDI note - 24. }
        Pitch := EnsureRange(A.Note - 24, 1, $7C);
        EmitDuration(Part + 1, Pitch, Dur, Gate, Cursor);
      end;
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
    Log(Format('GM/compatible percussion input notes=%d', [PercussionInputCount]));
    if ExtCY51 > 0 then Log(Format('Extended CY mapping: MIDI 51 (Ride Cymbal 1) -> CY : %d hits', [ExtCY51]));
    if ExtCY52 > 0 then Log(Format('Extended CY mapping: MIDI 52 (Chinese Cymbal) -> CY : %d hits', [ExtCY52]));
    if ExtCY53 > 0 then Log(Format('Extended CY mapping: MIDI 53 (Ride Bell) -> CY : %d hits', [ExtCY53]));
    if ExtCY55 > 0 then Log(Format('Extended CY mapping: MIDI 55 (Splash Cymbal) -> CY : %d hits', [ExtCY55]));
    if ExtCY59 > 0 then Log(Format('Extended CY mapping: MIDI 59 (Ride Cymbal 2) -> CY : %d hits', [ExtCY59]));
    Log(Format('quantized hit positions=%d', [Keys.Count]));
    { Harmony Boost is fixed OFF.
      Its conversion-log output is intentionally disabled.
      Log(Format('Harmony Boost: OFF, added=%d', [HarmonyAddedCount])); }
    Cursor := 0;
    if chkNativeRhythmV3.Checked then
    begin
      { Native Rhythm v4 mode: independently implemented from analysis of CMU-800 DATA structure.
        This remains an option by design: correct CMU structure does not guarantee
        correct automatic arrangement of every source MIDI.
        CH0 = rhythm pattern bank, CH9 = rhythm table/order.
        Reference CMU DATA shows CH0 as an FD-delimited pattern bank.  Each pattern always consists of 16 records. At the canonical
        24 steps/quarter this totals 96 ST (16 * 6); other settings scale ST.  CH9 starts with 75, then
        contains only 1..75 with 00,00 parameters.

        Build 4*StepsPerQuarter measures from MIDI percussion, quantize each hit
        to one of 16 sixteenth-note slots, deduplicate identical patterns, write the
        unique patterns to CH0, and write the pattern-number sequence to CH9. }
      MaxSongPos := 0;
      for I := 0 to Sorted.Count - 1 do
      begin
        E := QuantizeTick(Sorted[I].EndTick);
        if E > MaxSongPos then MaxSongPos := E;
      end;
      if MaxSongPos < 1 then MaxSongPos := MeasureUnits;
      MeasureCount := Integer((MaxSongPos + MeasureUnits - 1) div MeasureUnits);

      for M := 0 to MeasureCount - 1 do
      begin
        SetLength(Sig, 16);
        for Slot := 1 to 16 do
          Sig[Slot] := Char($7F);

        for I := 0 to Keys.Count - 1 do
        begin
          S := Keys[I];
          if (S < Int64(M) * MeasureUnits) or (S >= Int64(M + 1) * MeasureUnits) then Continue;
          { Map the hit proportionally into one of 16 sixteenth-note slots. }
          Slot := Integer(((S - Int64(M) * MeasureUnits) * 16 + MeasureUnits div 2) div MeasureUnits);
          if Slot < 0 then Slot := 0;
          if Slot > 15 then Slot := 15;
          Mask := Drums[S];
          Code := Byte(Ord(Sig[Slot + 1]));
          Code := Code and Byte($7F and (not Mask));
          Sig[Slot + 1] := Char(Code);
        end;

        if not PatternMap.TryGetValue(Sig, PatternNo) then
        begin
          PatternNo := Patterns.Count + 1;
          Patterns.Add(Sig);
          PatternMap.Add(Sig, PatternNo);
        end;
        Orders.Add(PatternNo);
      end;

      if Patterns.Count > $FC then
        raise EConvertError.CreateFmt(
          'Native Rhythm v4: unique rhythm patterns=%d exceeds CMU table range',
          [Patterns.Count]);

      { CH0 pattern bank: always 16 records.  Their ST values are scaled
        so the complete pattern length equals 4 * Steps/quarter. }
      for M := 0 to Patterns.Count - 1 do
      begin
        Sig := Patterns[M];
        for Slot := 1 to 16 do
        begin
          SlotStart := ((Slot - 1) * MeasureUnits) div 16;
          SlotEnd := (Slot * MeasureUnits) div 16;
          SlotDur := Max(1, SlotEnd - SlotStart);
          Tracks[0].AddEvent(Byte(Ord(Sig[Slot])), SlotDur, 1);
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

      Log(Format('Native Rhythm v4: %d measures -> %d unique CH0 patterns; CH9 order entries=%d',
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
      Log('Native Rhythm OFF: CH9 sequence is left empty (v0.24-compatible audible behaviour).');
    end;

    for I := 0 to 9 do
    begin
      { Standard CMU channel terminator: FE 0C 06 }
      Tracks[I].Add($FE);
      Tracks[I].Add($0C);
      Tracks[I].Add($06);
    end;

    Log(Format('CMU timeline: %d units/quarter, %d units/4-4 measure (Steps/quarter applied to note + rhythm data)', [UnitsPerQuarter, MeasureUnits]));
    Log('v0.29b pitch mapping: CMU song note = MIDI note - 24.');
    if chkNativeRhythmV3.Checked then
      Log('v0.29b: v0.27 Intelligent 6-Voice allocation retained; Native Rhythm v4 default ON.')
    else
      Log('v0.29b: Native Rhythm v4 is OFF; compatibility rhythm path is used.');
    if chkVelocityGate.Checked then Log('Velocity GATE: ON for CH1-CH6.');
    if Dropped > 0 then
      Log(Format('%d notes exceeded available CMU voices and were suppressed',
        [Dropped]));
  finally
    for I := 0 to 5 do Voices[I].Free;
    Orders.Free;
    PatternMap.Free;
    Patterns.Free;
    Keys.Free;
    Drums.Free;
    Sorted.Free;
    MelodyAt.Free;
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
  if Cardinal(BaseAddress)+Cardinal(Length(OutB))>$10000 then raise ERangeError.Create('Output does not fit below $10000');
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
    Log(Format('Saved MZT: header 128 + data %d bytes; load $%.4x, exec $12A0',[Length(OutB),BaseAddress]))
  else
    Log(Format('Saved raw data: %d bytes; load address $%.4x',[Length(OutB),BaseAddress]));
end;

procedure TMainForm.btnResetStepsClick(Sender: TObject);
begin
  spnQuant.Value := 44;
end;

procedure TMainForm.btnConvertClick(Sender:TObject);
var Tracks:TObjectList<TTrackData>; I,Code:Integer; Base:Cardinal;
begin
  memLog.Clear;
  try
    if not FileExists(edtInput.Text) then raise EFileNotFoundException.Create('Select an input MIDI file');
    if edtOutput.Text='' then raise Exception.Create('Select an output file');
    Val('$'+Trim(edtBase.Text),Base,Code); if (Code<>0) or (Base>$FFFF) then raise Exception.Create('Invalid hexadecimal load address');
    ParseMidi(edtInput.Text); Tracks:=TObjectList<TTrackData>.Create(True);
    try for I:=0 to 9 do Tracks.Add(TTrackData.Create); BuildTracks(Tracks); SaveCMUData(edtOutput.Text,Tracks,Word(Base));
    finally Tracks.Free; end;
    Log('Conversion completed.');
  except on E:Exception do begin Log('ERROR: '+E.Message); MessageDlg(E.Message,mtError,[mbOK],0); end; end;
end;

end.
