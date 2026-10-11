program OptionRegressionTests;

{$APPTYPE CONSOLE}

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils,
  Vcl.Forms,
  MainUnit in 'MainUnit.pas' {MainForm},
  MidiTiming in 'MidiTiming.pas';

var
  Tracks: TArray<TBytes>;
  Root, TempDir, FileName: string;
  Bits, WithDrums, I, J, Channel, Start, Count, Gate: Integer;
  Data: TBytes;
  LongNote: TTrackData;
  Priority, Separation, Velocity, Rhythm, Found: Boolean;

procedure Require(Condition: Boolean; const MessageText: string);
begin
  if not Condition then raise Exception.Create(MessageText);
end;

function HasNote(Track: Integer; MidiNote: Integer): Boolean;
var P: Integer;
begin
  Result := False;
  P := 0;
  while P + 2 < Length(Tracks[Track]) do begin
    if Tracks[Track][P] = MidiNote - 24 then Exit(True);
    Inc(P,3);
  end;
end;

begin
  ExitCode := 0;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  { Test execution must not overwrite the user's folder or option settings. }
  MainForm.OnDestroy := nil;
  Root := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  TempDir := TPath.Combine(TPath.GetTempPath, 'CMUOptionTests_' + IntToStr(GetTickCount64));
  ForceDirectories(TempDir);
  try
    try
      LongNote := TTrackData.Create;
      try
        LongNote.AddEvent(60,300,50);
        Require(Length(LongNote.Data)=9, 'Long note should use three records');
        Require((LongNote.Data[0]=60) and (LongNote.Data[2]=50), 'First gate mismatch');
        Require((LongNote.Data[3]=0) and (LongNote.Data[5]=0) and
                (LongNote.Data[6]=0) and (LongNote.Data[8]=0), 'Gate restarted after exhaustion');
      finally LongNote.Free; end;
      for WithDrums := 0 to 1 do
        for Bits := 0 to 15 do begin
          Velocity := (Bits and 1) <> 0;
          Separation := (Bits and 2) <> 0;
          Priority := (Bits and 4) <> 0;
          Rhythm := (Bits and 8) <> 0;
          if Velocity then MainForm.cmbVelocityGate.ItemIndex := 1
          else MainForm.cmbVelocityGate.ItemIndex := 2;
          MainForm.chkChordSeparation.Checked := Separation;
          MainForm.chkMelodyPriority.Checked := Priority;
          MainForm.chkNativeRhythmV3.Checked := Rhythm;
         
          MainForm.edtBase.Text := '337D';
          if WithDrums = 1 then
            MainForm.edtInput.Text := Root + 'tests\options_with_drums.mid'
          else
            MainForm.edtInput.Text := Root + 'tests\options_no_drums.mid';
          FileName := TPath.Combine(TempDir, Format('options_%d_%d.mzt',[WithDrums,Bits]));
          MainForm.edtOutput.Text := FileName;
          MainForm.btnConvertClick(nil);
          Require(FileExists(FileName), 'Conversion did not create output');
          Data := TFile.ReadAllBytes(FileName);
          SetLength(Tracks,10);
          Start := 128;
          Channel := 0;
          I := 128;
          while I + 2 < Length(Data) do begin
            if Data[I] = $FE then begin
              Require(Channel < 10, 'Too many tracks');
              Tracks[Channel] := Copy(Data,Start,I+3-Start);
              Inc(Channel);
              Start := I+3;
            end;
            Inc(I,3);
          end;
          Require((Channel=10) and (Start=Length(Data)), 'Invalid CMU sections');
          Require(HasNote(2,36), 'BASS missing from CH2');
          Count := 0;
          for I := 1 to 6 do begin
            if HasNote(I,84) then Inc(Count);
            if I <> 2 then Require(not HasNote(I,36), 'BASS leaked from CH2');
          end;
          Require((Count>0)=Priority, 'High-note retention does not match Melody Priority');
          I := 0;
          while I+2 < Length(Tracks[2]) do begin
            if Tracks[2][I] < $FD then
              Require(Tracks[2][I] in [0,12], 'Non-BASS note in CH2');
            Inc(I,3);
          end;
          if Separation then begin
            Require(HasNote(1,72), 'Melody not placed in CH1');
            for I := 3 to 6 do begin
              Require(not HasNote(I,72), 'Melody leaked to chord channels');
              Require(not HasNote(I,84), 'Priority melody leaked to chord channels');
            end;
            Require(not HasNote(1,69), 'Chord leaked to CH1');
          end;
          Gate := -1;
          for I := 1 to 6 do begin
            J := 0;
            while J+2 < Length(Tracks[I]) do begin
              if Tracks[I][J] = 45 then Gate := Tracks[I][J+2]; { MIDI69 }
              Inc(J,3);
            end;
          end;
          if Velocity then Require(Gate=24, 'Velocity gate should be24')
          else Require(Gate=48, 'Full-length gate should be48');
          Found := Length(Tracks[0])>3;
          Require(Found=(Rhythm and (WithDrums=1)), 'Rhythm generation does not match option/input');
          Require((Length(Tracks[9])>3)=Found, 'Rhythm order table mismatch');
          if Found then Require(Tracks[0][0]=$3F, 'GM35 must map to BD');
          TFile.Delete(FileName);
        end;
      Writeln('32 option combinations passed against actual MainUnit conversion.');
    except
      on E: Exception do begin Writeln(E.Message); ExitCode := 1; end;
    end;
  finally
    MainForm.Free;
    if DirectoryExists(TempDir) then TDirectory.Delete(TempDir,True);
  end;
end.
