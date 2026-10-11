program RoutingRegressionTests;
{$APPTYPE CONSOLE}
uses
  Winapi.Windows, System.SysUtils, System.IOUtils, Vcl.Forms,
  MainUnit in 'MainUnit.pas' {MainForm}, MidiTiming in 'MidiTiming.pas',
  VelocityGatePolicy in 'VelocityGatePolicy.pas';
const
  FixtureNames: array[0..3] of string = ('melody_low_ch1','melody_low_ch2','melody_low_ch5','program_change_bass');
  Ring: array[0..4] of Integer = (1,3,4,5,6);
var
  Root, TempDir, FileName: string;
  Data: TBytes;
  Tracks: TArray<TBytes>;
  Fixture, Mode, Bits, Cases, I, Expected, NoteCount: Integer;
procedure Require(B: Boolean; const S: string);
begin if not B then raise Exception.Create(S); end;
procedure ReadTracks;
var P, C, First: Integer;
begin
  SetLength(Tracks,10); P:=128; First:=P; C:=0;
  while P+2<Length(Data) do begin
    if Data[P]=$FE then begin
      Require(C<10,'Too many channels');
      Tracks[C]:=Copy(Data,First,P+3-First); Inc(C); First:=P+3;
    end;
    Inc(P,3);
  end;
  Require((C=10) and (First=Length(Data)),'Invalid CMU sections');
end;
procedure CheckNote(MidiNote, ExpectedVoice, ExpectedStart: Integer);
var C, P, Position, Found: Integer;
begin
  Found:=0;
  for C:=1 to 6 do begin
    Position:=0; P:=0;
    while P+2<Length(Tracks[C]) do begin
      if Tracks[C][P]<$FD then begin
        if Tracks[C][P]=MidiNote-24 then begin
          Inc(Found);
          Require(C=ExpectedVoice,Format('MIDI%d expected CH%d, actual CH%d',[MidiNote,ExpectedVoice,C]));
          Require(Position=ExpectedStart,'Note timing changed during routing');
        end;
        Inc(Position,Tracks[C][P+1]);
      end;
      Inc(P,3);
    end;
  end;
  Require(Found=1,'Missing/duplicated melody or BASS note');
end;
begin
  Application.Initialize; Application.CreateForm(TMainForm,MainForm);
  MainForm.OnDestroy:=nil;
  Root:=IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  TempDir:=TPath.Combine(TPath.GetTempPath,'CMURoutingTests_'+IntToStr(GetTickCount64));
  ForceDirectories(TempDir);
  try
    try
      MainForm.edtBase.Text:='337D';
      Cases:=0;
      for Fixture:=0 to 3 do
        for Mode:=0 to 2 do
          for Bits:=0 to 7 do begin
            MainForm.cmbVelocityGate.ItemIndex:=Mode;
            MainForm.chkChordSeparation.Checked:=(Bits and 1)<>0;
            MainForm.chkMelodyPriority.Checked:=(Bits and 2)<>0;
            MainForm.chkNativeRhythmV3.Checked:=(Bits and 4)<>0;
            MainForm.edtInput.Text:=Root+'tests\'+FixtureNames[Fixture]+'.mid';
            FileName:=TPath.Combine(TempDir,Format('route_%d_%d_%d.mzt',[Fixture,Mode,Bits]));
            MainForm.edtOutput.Text:=FileName; MainForm.btnConvertClick(nil);
            Require(FileExists(FileName),'Conversion failed');
            Data:=TFile.ReadAllBytes(FileName); ReadTracks;
            Require((Length(Tracks[0])=3) and (Length(Tracks[9])=3),'Rhythm emitted without drums');
            if Fixture<3 then begin
              Require(Length(Tracks[2])=3,'Low melody wrongly classified as BASS'); NoteCount:=8;
            end else NoteCount:=10;
            for I:=0 to NoteCount-1 do begin
              if (Fixture=3) and (I>=5) then Expected:=2
              else if MainForm.chkChordSeparation.Checked then Expected:=1
              else Expected:=Ring[I mod Length(Ring)];
              CheckNote(36+I,Expected,I*24);
            end;
            Inc(Cases);
          end;
      Writeln(Cases,' routing cases passed: low melody, five-voice rotation and program-change BASS.');
    except on E:Exception do begin Writeln(E.Message); ExitCode:=1; end; end;
  finally
    MainForm.Free;
    if DirectoryExists(TempDir) then TDirectory.Delete(TempDir,True);
  end;
end.
