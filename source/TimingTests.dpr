program TimingTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  MidiTiming in 'MidiTiming.pas';

var Timing: TMidiTiming; Checks: Integer;

procedure Check(Tick, Expected: Int64);
var Actual: Int64;
begin
  Actual := Timing.TickToStep(Tick);
  if Actual <> Expected then
    raise Exception.CreateFmt('tick %d: expected %d, actual %d',
      [Tick, Expected, Actual]);
  Inc(Checks);
end;

begin
  Timing := TMidiTiming.Create;
  try
    try
      Timing.Prepare(480,100);
      Check(0,0); Check(160,8); Check(320,16); Check(480,24);
      { Tempo-only events can be added before or after note-track parsing. }
      Timing.Clear;
      Timing.AddTempo(960,500000);
      Timing.AddTempo(480,1000000);
      Timing.Prepare(480,100);
      Check(480,24); Check(720,48); Check(960,72); Check(1440,96);
      { Note 240..720 crosses the tempo change: start=12, end=48. }
      Check(240,12);
      Timing.Prepare(480,200);
      Check(480,12); Check(960,36); Check(1440,48);
      Timing.Prepare(480,50);
      Check(480,48); Check(960,144);
      Timing.Clear;
      Timing.AddTempo(0,1000000);
      Timing.AddTempo(0,250000);
      Timing.Prepare(480,100);
      Check(480,12);
      Timing.Clear;
      Timing.AddTempo(100,750000);
      Timing.Prepare(1000,100);
      Check(100,2); Check(1000,35); Check(1000000,35999);
      Timing.Clear;
      Timing.Prepare(960,1);
      Check(960,2400);
      Timing.Clear;
      Timing.Prepare(48,100);
      Check(16,8); Check(48,24);
      Writeln(Checks, ' timing checks passed.');
    except
      on E: Exception do begin Writeln(E.Message); ExitCode := 1; end;
    end;
  finally
    Timing.Free;
  end;
end.
