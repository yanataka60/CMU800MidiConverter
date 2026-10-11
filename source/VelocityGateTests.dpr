program VelocityGateTests;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.Math, VelocityGatePolicy in 'VelocityGatePolicy.pas';
var A, B: TVelocityGateAnalysis; Checks: Integer;
procedure Require(Value: Boolean; const S: string);
begin if not Value then raise Exception.Create(S); Inc(Checks); end;
begin
  try
    A:=Default(TVelocityGateAnalysis);
    Require(A.Resolve(vgAuto),'No notes fallback');
    Require(not A.Resolve(vgOff),'Manual OFF/no notes');
    A.TotalDuration:=100; A.VelocityDuration:=64.99;
    Require(not A.Resolve(vgAuto),'Below 65 must be OFF');
    Require(A.Resolve(vgOn),'Manual ON must override low ratio');
    A.VelocityDuration:=65;
    Require(A.Resolve(vgAuto),'Exactly 65 must be ON');
    A.VelocityDuration:=65.01;
    Require(A.Resolve(vgAuto),'Above 65 must be ON');
    Require(not A.Resolve(vgOff),'Manual OFF must override high ratio');
    A:=Default(TVelocityGateAnalysis); A.AddNote(1,127); A.AddNote(3,40);
    Require(not A.Resolve(vgAuto),'Duration weighting, not simple velocity average');
    B:=Default(TVelocityGateAnalysis); B.AddNote(2,127); B.AddNote(6,40);
    Require(Abs(A.RetainedPercent-B.RetainedPercent)<1E-8,'Speed ratio invariance');
    B.AddNote(0,1);
    Require(B.NoteCount=2,'Zero length must be ignored');
    A:=Default(TVelocityGateAnalysis); A.AddNote(4,100);
    Require(A.Resolve(vgAuto),'Velocity100 must be auto ON');
    Require(not A.Resolve(vgOff),'Manual OFF retained');
    Writeln(Checks,' auto gate policy checks passed.');
  except on E:Exception do begin Writeln(E.Message); ExitCode:=1; end; end;
end.
