program TempoConversionTests;
{$APPTYPE CONSOLE}
uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils, System.Math,
  Vcl.Forms, MainUnit in 'MainUnit.pas' {MainForm}, MidiTiming in 'MidiTiming.pas';
var
  Root, TempDir, OutputName, InputName: string;
  Tracks: TArray<TBytes>;
  Data, OriginalPayload: TBytes;
  PatternLengths, Boundaries: TArray<Integer>;
  TestIndex, SpeedIndex, Speed, I, J, Channel, Patterns, Total,
  PatternTotal, VoiceTotal, BoundaryIndex, Measures: Integer;

procedure Require(B: Boolean; const S: string);
begin if not B then raise Exception.Create(S); end;
function ExpectedStep(Tick: Integer): Integer;
var Elapsed: Extended;
begin
  if TestIndex=0 then Elapsed:=Extended(Tick)*666667
  else if Tick<=960 then Elapsed:=Extended(Tick)*500000
  else if Tick<=5760 then Elapsed:=960.0*500000+Extended(Tick-960)*400000
  else if Tick<=7680 then Elapsed:=960.0*500000+4800.0*400000+Extended(Tick-5760)*500000
  else Elapsed:=960.0*500000+4800.0*400000+1920.0*500000+Extended(Tick-7680)*400000;
  if TestIndex=0 then Result:=Trunc(Elapsed/480*24/666667.0+0.5)
  else Result:=Trunc(Elapsed/480*24/500000.0+0.5);
end;

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
  Require((C=10) and (First=Length(Data)),'Invalid sections');
end;
begin
  Application.Initialize; Application.CreateForm(TMainForm,MainForm);
  MainForm.OnDestroy:=nil;
  Root:=IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  TempDir:=TPath.Combine(TPath.GetTempPath,'CMUTempoTests_'+IntToStr(GetTickCount64));
  ForceDirectories(TempDir);
  try
    try
      MainForm.chkChordSeparation.Checked:=False;
      MainForm.chkMelodyPriority.Checked:=False;
      MainForm.cmbVelocityGate.ItemIndex:=1;
      MainForm.chkNativeRhythmV3.Checked:=True;
      MainForm.edtBase.Text:='337D';
      for TestIndex:=0 to 1 do begin
        if TestIndex=0 then begin
          InputName:=Root+'tests\repeated_90bpm_64bars.mid'; Measures:=64;
        end else begin
          InputName:=Root+'tests\variable_tempo_six_voices.mid'; Measures:=6;
        end;
        OriginalPayload:=nil;
        for SpeedIndex:=0 to 0 do begin
          Speed:=100;
          MainForm.edtInput.Text:=InputName;
          OutputName:=TPath.Combine(TempDir,Format('tempo_%d_%d.mzt',[TestIndex,Speed]));
          MainForm.edtOutput.Text:=OutputName; MainForm.btnConvertClick(nil);
          Require(FileExists(OutputName),'Missing converted data');
          Require(not FileExists(OutputName+'.tempo.txt'),'Unexpected player BPM instructions');
          Require(Pos('代表TOTAL ST:',MainForm.memLog.Text)>0,'Representative ST is not reported');
          if TestIndex=0 then Require(Pos(Format('代表TOTAL ST: %d',[ExpectedStep(1920)]),
            MainForm.memLog.Text)>0,'Wrong representative measure ST');
          Data:=TFile.ReadAllBytes(OutputName);
          ReadTracks;
          SetLength(PatternLengths,0); PatternTotal:=0; Patterns:=0; I:=0;
          while I+2<Length(Tracks[0]) do begin
            if Tracks[0][I]=$FD then begin
              Inc(Patterns); SetLength(PatternLengths,Patterns);
              PatternLengths[Patterns-1]:=PatternTotal; PatternTotal:=0;
            end else if Tracks[0][I]<$FD then Inc(PatternTotal,Tracks[0][I+1]);
            Inc(I,3);
          end;
          if TestIndex=0 then Require((Patterns=1) and (PatternLengths[0]=ExpectedStep(1920)),
            'Constant 90 BPM must reuse one correctly scaled pattern');
          SetLength(Boundaries,0); Total:=0; I:=0;
          while I+2<Length(Tracks[9]) do begin
            if Tracks[9][I]<$FD then begin
              J:=Tracks[9][I]-1; Require((J>=0) and (J<Patterns),'Invalid pattern order');
              Inc(Total,PatternLengths[J]); SetLength(Boundaries,Length(Boundaries)+1);
              Boundaries[High(Boundaries)]:=Total;
            end;
            Inc(I,3);
          end;
          Require(Length(Boundaries)=Measures,'Wrong MIDI measure count');
          Require(Total=ExpectedStep(Measures*1920),'Wrong relative tempo integration');
          for J:=0 to Measures-1 do
            Require(Boundaries[J]=ExpectedStep((J+1)*1920),'Wrong measure boundary');
          for Channel:=1 to 6 do begin
            if Length(Tracks[Channel])=3 then begin
              Require(TestIndex=0,'Six-voice fixture lost a physical channel'); Continue;
            end;
            VoiceTotal:=0; BoundaryIndex:=0; I:=0;
            while I+2<Length(Tracks[Channel]) do begin
              if Tracks[Channel][I]=$FD then begin
                Require(BoundaryIndex<Length(Boundaries),'Too many voice FD marks');
                Require(VoiceTotal=Boundaries[BoundaryIndex],'Voice/rhythm FD mismatch');
                Inc(BoundaryIndex);
              end else if Tracks[Channel][I]<$FD then Inc(VoiceTotal,Tracks[Channel][I+1]);
              Inc(I,3);
            end;
            Require((BoundaryIndex=Measures) and (VoiceTotal=Total),'Incomplete voice synchronization');
          end;
        end;
      end;
      Writeln('Relative tempo STEP scaling, pattern reuse and 6-channel synchronization passed.');
    except on E: Exception do begin Writeln(E.Message); ExitCode:=1; end; end;
  finally
    MainForm.Free;
    if DirectoryExists(TempDir) then TDirectory.Delete(TempDir,True);
  end;
end.
