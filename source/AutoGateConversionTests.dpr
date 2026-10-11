program AutoGateConversionTests;
{$APPTYPE CONSOLE}
uses
  Winapi.Windows, System.SysUtils, System.IOUtils, Vcl.Forms,
  MainUnit in 'MainUnit.pas' {MainForm}, MidiTiming in 'MidiTiming.pas',
  VelocityGatePolicy in 'VelocityGatePolicy.pas';
var
  Root, TempDir, FileName: string;
  TestIndex, SpeedIndex, Mode, ExpectedMode: Integer;
  Reference, Data: TBytes;
procedure Require(B: Boolean; const S: string);
begin if not B then raise Exception.Create(S); end;
begin
  Application.Initialize; Application.CreateForm(TMainForm,MainForm);
  MainForm.OnDestroy:=nil;
  Root:=IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  TempDir:=TPath.Combine(TPath.GetTempPath,'CMUAutoGateTests_'+IntToStr(GetTickCount64));
  ForceDirectories(TempDir);
  try
    try
      MainForm.chkChordSeparation.Checked:=False;
      MainForm.chkMelodyPriority.Checked:=False;
      MainForm.chkNativeRhythmV3.Checked:=True;
      MainForm.edtBase.Text:='337D';
      for TestIndex:=0 to 1 do begin
        if TestIndex=0 then begin
          MainForm.edtInput.Text:=Root+'tests\auto_gate_on.mid'; ExpectedMode:=1;
        end else begin
          MainForm.edtInput.Text:=Root+'tests\auto_gate_off.mid'; ExpectedMode:=2;
        end;
        for SpeedIndex:=0 to 0 do begin
          Reference:=nil;
          for Mode:=0 to 2 do begin
            MainForm.cmbVelocityGate.ItemIndex:=Mode;
            FileName:=TPath.Combine(TempDir,Format('gate_%d_%d_%d.mzt',[TestIndex,SpeedIndex,Mode]));
            MainForm.edtOutput.Text:=FileName; MainForm.btnConvertClick(nil);
            Require(FileExists(FileName),'Missing output');
            Data:=TFile.ReadAllBytes(FileName); Data:=Copy(Data,128,Length(Data)-128);
            if Mode=0 then begin
              Reference:=Copy(Data,0,Length(Data));
              if TestIndex=0 then Require(Pos(Format('%.2f%%',[100.0/127*100]),MainForm.memLog.Text)>0,'Auto ON estimate/drum exclusion')
              else Require(Pos(Format('%.2f%%',[50.0/127*100]),MainForm.memLog.Text)>0,'Auto OFF estimate/drum exclusion');
            end else if Mode=ExpectedMode then begin
              Require(Length(Data)=Length(Reference),'Auto/manual sizes differ');
              Require(CompareMem(@Data[0],@Reference[0],Length(Data)),'Auto differs from expected manual mode');
            end else if Length(Data)=Length(Reference) then
              Require(not CompareMem(@Data[0],@Reference[0],Length(Data)),'Manual override was ignored');
          end;
        end;
      end;
      Writeln('Auto/manual GATE output matching, manual overrides passed.');
    except on E:Exception do begin Writeln(E.Message); ExitCode:=1; end; end;
  finally
    MainForm.Free;
    if DirectoryExists(TempDir) then TDirectory.Delete(TempDir,True);
  end;
end.
