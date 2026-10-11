program TimingTests;
{$APPTYPE CONSOLE}
uses System.SysUtils, MidiTiming in 'MidiTiming.pas';
var Timing: TMidiTiming; Checks: Integer;
procedure Check(Tick, Expected: Int64);
var Actual: Int64;
begin
  Actual := Timing.TickToStep(Tick);
  if Actual <> Expected then
    raise Exception.CreateFmt('tick %d: expected %d, actual %d', [Tick, Expected, Actual]);
  Inc(Checks);
end;
begin
  Timing := TMidiTiming.Create;
  try
    try
      { No explicit tempo: one 4/4 measure is 96 steps. }
      Timing.Prepare(480); Check(480,24); Check(1920,96);
      { A single 90 BPM event changes no durations. }
      Timing.Clear; Timing.AddTempo(0,666667);
      Timing.Prepare(480); Check(480,24); Check(1920,96);
      { A single tempo later in the file is still the global reference. }
      Timing.Clear; Timing.AddTempo(960,1000000);
      Timing.Prepare(480); Check(480,24); Check(1920,96);
      { 120 -> 160 BPM: following measure 72 steps. }
      Timing.Clear; Timing.AddTempo(0,500000); Timing.AddTempo(1920,375000);
      Timing.Prepare(480); Check(1920,96); Check(3840,168);
      { 90 -> 180 BPM: following measure 48 steps. }
      Timing.Clear; Timing.AddTempo(0,666666); Timing.AddTempo(1920,333333);
      Timing.Prepare(480); Check(1920,96); Check(3840,144);
      { A change in the middle of a measure is integrated by segment. }
      Timing.Clear; Timing.AddTempo(0,500000); Timing.AddTempo(960,1000000);
      Timing.Prepare(480); Check(960,48); Check(1920,144);
      { Identical repeated tempos leave every measure at 96 steps. }
      Timing.Clear; Timing.AddTempo(0,666667); Timing.AddTempo(1920,666667);
      Timing.Prepare(480); Check(1920,96); Check(3840,192);
      { Chronological order matters, not track parse order. }
      Timing.Clear; Timing.AddTempo(1920,375000); Timing.AddTempo(0,500000);
      Timing.Prepare(480); Check(3840,168);
      { Same tick: final event wins; prepare is repeatable. }
      Timing.Clear; Timing.AddTempo(0,500000); Timing.AddTempo(0,250000);
      Timing.Prepare(480); Check(1920,96);
      Timing.Prepare(480); Check(1920,96);
      { First event later, followed by a real change. }
      Timing.Clear; Timing.AddTempo(960,500000); Timing.AddTempo(1920,1000000);
      Timing.Prepare(480); Check(1920,96); Check(3840,288);
      Writeln(Checks, ' relative tempo timing checks passed.');
    except on E: Exception do begin Writeln(E.Message); ExitCode := 1; end; end;
  finally Timing.Free; end;
end.
