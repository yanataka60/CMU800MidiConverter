unit MidiTiming;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.Generics.Defaults;

type
  TTempoPoint = record
    Tick: Int64;
    MicrosecondsPerQuarter, Order: Integer;
    ElapsedTickMicroseconds: Extended;
  end;

  TMidiTiming = class
  private
    FPoints: TList<TTempoPoint>;
    FDivision, FReferenceMicroseconds: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure AddTempo(ATick: Int64; AMicrosecondsPerQuarter: Integer);
    procedure Prepare(ADivision: Integer);
    function ReferenceBPM: Double;
    function TickToStep(ATick: Int64): Int64;
    function TickToStepPosition(ATick: Extended): Extended;
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
  FDivision := 0;
  FReferenceMicroseconds := 500000;
  { Standard MIDI default: 500000 us/quarter = 120 BPM. }
  AddTempo(0, 500000);
end;

procedure TMidiTiming.AddTempo(ATick: Int64; AMicrosecondsPerQuarter: Integer);
var P: TTempoPoint;
begin
  if (ATick < 0) or (AMicrosecondsPerQuarter <= 0) then
    raise EReadError.Create('MIDIのテンポ指定イベントが不正です。');
  P.Tick := ATick;
  P.MicrosecondsPerQuarter := AMicrosecondsPerQuarter;
  P.Order := FPoints.Count;
  P.ElapsedTickMicroseconds := 0;
  FPoints.Add(P);
end;

procedure TMidiTiming.Prepare(ADivision: Integer);
var I: Integer; P, Previous: TTempoPoint; Elapsed: Extended;
    FirstTick: Int64;
begin
  if (ADivision <= 0) or (ADivision > $7FFF) then
    raise EConvertError.Create('時間変換の設定が不正です。');
  FDivision := ADivision;
  FPoints.Sort(TComparer<TTempoPoint>.Construct(
    function(const X, Y: TTempoPoint): Integer
    begin
      if X.Tick < Y.Tick then Exit(-1);
      if X.Tick > Y.Tick then Exit(1);
      Result := X.Order - Y.Order;
    end));
  { The synthetic default is not a MIDI tempo event. Use the earliest
    explicit tempo as the reference, including the region before it.
    At the same tick the last event in file order wins. }
  FReferenceMicroseconds := 500000;
  FirstTick := -1;
  for I := 0 to FPoints.Count - 1 do begin
    P := FPoints[I];
    if P.Order = 0 then Continue;
    if FirstTick < 0 then FirstTick := P.Tick;
    if P.Tick <> FirstTick then Break;
    FReferenceMicroseconds := P.MicrosecondsPerQuarter;
  end;
  for I := 0 to FPoints.Count - 1 do begin
    P := FPoints[I];
    if P.Order = 0 then begin
      P.MicrosecondsPerQuarter := FReferenceMicroseconds;
      FPoints[I] := P;
      Break;
    end;
  end;
  Elapsed := 0;
  Previous := FPoints[0];
  for I := 0 to FPoints.Count - 1 do begin
    P := FPoints[I];
    Elapsed := Elapsed + Extended(P.Tick - Previous.Tick) *
      Previous.MicrosecondsPerQuarter;
    P.ElapsedTickMicroseconds := Elapsed;
    FPoints[I] := P;
    Previous := P;
  end;
end;

function TMidiTiming.ReferenceBPM: Double;
begin
  Result := 60000000.0 / FReferenceMicroseconds;
end;

function TMidiTiming.TickToStepPosition(ATick: Extended): Extended;
var Lo, Hi, Mid: Integer; P: TTempoPoint; Time, Steps: Extended;
begin
  if (ATick < 0) or (FDivision <= 0) then
    raise EConvertError.Create('MIDIの時間変換が準備されていません。');
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
  { 24 steps/quarter at the first MIDI tempo: no tempo or one tempo
    leaves 4/4 measures at 96 steps. Later changes use their ratio only. }
  Steps := Time / FDivision * 24 / FReferenceMicroseconds;
  { Output address space limits useful song lengths; reject extreme input
    before downstream Integer durations or measure counts could overflow. }
  if Steps > 1000000000 then
    raise EConvertError.Create('変換後の曲が長すぎます。');
  Result := Steps;
end;

function TMidiTiming.TickToStep(ATick: Int64): Int64;
begin
  Result := Trunc(TickToStepPosition(ATick) + 0.5);
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
