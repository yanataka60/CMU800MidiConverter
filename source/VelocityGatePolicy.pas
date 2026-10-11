unit VelocityGatePolicy;

interface

uses System.Math;

const
  CAutomaticGateThresholdPercent = 65.0;

type
  TVelocityGateMode = (vgAuto, vgOn, vgOff);
  TVelocityGateAnalysis = record
    TotalDuration, VelocityDuration: Extended;
    NoteCount: Integer;
    procedure AddNote(Duration: Extended; Velocity: Integer);
    function RetainedPercent: Double;
    function Resolve(Mode: TVelocityGateMode): Boolean;
  end;

implementation

procedure TVelocityGateAnalysis.AddNote(Duration: Extended; Velocity: Integer);
begin
  if Duration <= 0 then Exit;
  TotalDuration := TotalDuration + Duration;
  VelocityDuration := VelocityDuration + Duration * EnsureRange(Velocity,0,127) / 127;
  Inc(NoteCount);
end;

function TVelocityGateAnalysis.RetainedPercent: Double;
begin
  if TotalDuration <= 0 then Exit(100);
  Result := VelocityDuration / TotalDuration * 100;
end;

function TVelocityGateAnalysis.Resolve(Mode: TVelocityGateMode): Boolean;
begin
  case Mode of
    vgOn: Result := True;
    vgOff: Result := False;
  else
    { Preserve the previous ON default when there are no melodic notes.
      Tolerance only absorbs arithmetic error at exactly 65 percent. }
    Result := (TotalDuration <= 0) or
      (RetainedPercent + 1E-9 >= CAutomaticGateThresholdPercent);
  end;
end;

end.
