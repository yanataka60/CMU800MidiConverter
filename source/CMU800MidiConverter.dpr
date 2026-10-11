program CMU800MidiConverter;

uses
  Vcl.Forms,
  MainUnit in 'MainUnit.pas' {MainForm},
  MidiTiming in 'MidiTiming.pas',
  VelocityGatePolicy in 'VelocityGatePolicy.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'CMU-800 MIDI Converter v1.14';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
