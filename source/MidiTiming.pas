unit MidiTiming;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.Generics.Defaults;

const
  CMidiConversionBPM = 120;

type
  TTempoPoint = record
    Tick: Int64;
    MicrosecondsPerQuarter, Order: Integer;
    ElapsedTickMicroseconds: Extended;
  end;

  TMidiTiming = class
  private
    FPoints: TList<TTempoPoint>;
    FDivision, FSpeedPercent: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure AddTempo(ATick: Int64; AMicrosecondsPerQuarter: Integer);
    procedure Prepare(ADivision, ASpeedPercent: Integer);
    function TickToStep(ATick: Int64): Int64;
    function TempoCount: Integer;
    function PointCount: Integer;
    function TempoPoint(Index: Integer): TTempoPoint;
  end;

implementation

constructor TMidiTiming.Create;
begin
  inherited;
  FPoints := TList<TTempoPoint>.Create;
  Clear;
end;

destructor TMidiTiming.Destroy;
begin
  FPoints.Free;
  inherited;
end;

procedure TMidiTiming.Clear;
begin
  FPoints.Clear;
  { Standard MIDI default: 500000 us/quarter = 120 BPM. }
  AddTempo(0, 500000);
end;

procedure TMidiTiming.AddTempo(ATick: Int64; AMicrosecondsPerQuarter: Integer);
var P: TTempoPoint;
begin
  if (ATick < 0) or (AMicrosecondsPerQuarter <= 0) then
    raise EReadError.Create('Invalid MIDI tempo event');
  P.Tick := ATick;
  P.MicrosecondsPerQuarter := AMicrosecondsPerQuarter;
  P.Order := FPoints.Count;
  P.ElapsedTickMicroseconds := 0;
  FPoints.Add(P);
end;

procedure TMidiTiming.Prepare(ADivision, ASpeedPercent: Integer);
var I: Integer; P, Previous: TTempoPoint; Elapsed: Extended;
begin
  if (ADivision <= 0) or (ADivision > $7FFF) or
     (ASpeedPercent < 1) or (ASpeedPercent > 200) then
    raise EConvertError.Create('Invalid timing settings');
  FDivision := ADivision;
  FSpeedPercent := ASpeedPercent;
  FPoints.Sort(TComparer<TTempoPoint>.Construct(
    function(const X, Y: TTempoPoint): Integer
    begin
      if X.Tick < Y.Tick then Exit(-1);
      if X.Tick > Y.Tick then Exit(1);
      Result := X.Order - Y.Order;
    end));
  { Same tick: the last event in file order wins. Do not round individual
    segments; accumulate time, then quantize each absolute endpoint once. }
  Elapsed := 0;
  Previous := FPoints[0];
  for I := 0 to FPoints.Count - 1 do
  begin
    P := FPoints[I];
    Elapsed := Elapsed + Extended(P.Tick - Previous.Tick) *
      Previous.MicrosecondsPerQuarter;
    P.ElapsedTickMicroseconds := Elapsed;
    FPoints[I] := P;
    Previous := P;
  end;
end;

function TMidiTiming.TickToStep(ATick: Int64): Int64;
var Lo, Hi, Mid: Integer; P: TTempoPoint; Time, Steps: Extended;
begin
  if (ATick < 0) or (FDivision <= 0) then
    raise EConvertError.Create('MIDI timing is not prepared');
  Lo := 0;
  Hi := FPoints.Count;
  while Lo < Hi do
  begin
    Mid := Lo + (Hi - Lo) div 2;
    if FPoints[Mid].Tick <= ATick then Lo := Mid + 1 else Hi := Mid;
  end;
  P := FPoints[Lo - 1];
  Time := P.ElapsedTickMicroseconds + Extended(ATick - P.Tick) *
    P.MicrosecondsPerQuarter;
  { Internal conversion clock: 24 steps/quarter at 120 BPM.
    Speed 200% halves the output duration; 50% doubles it. }
  Steps := Time / FDivision * CMidiConversionBPM * 24 * 100 /
    (60000000.0 * FSpeedPercent);
  { Output address space limits useful song lengths; reject extreme input
    before downstream Integer durations or measure counts could overflow. }
  if Steps > 1000000000 then
    raise EConvertError.Create('Converted song is too long');
  Result := Trunc(Steps + 0.5);
end;

function TMidiTiming.TempoCount: Integer;
begin
  Result := FPoints.Count - 1;
end;

function TMidiTiming.PointCount: Integer;
begin
  Result := FPoints.Count;
end;

function TMidiTiming.TempoPoint(Index: Integer): TTempoPoint;
begin
  Result := FPoints[Index];
end;

end.
