unit GR32_ColorGradients;

(* ***** BEGIN LICENSE BLOCK ***************************************************
* Version: MPL 1.1 or LGPL 2.1 with linking exception                          *
*                                                                              *
* The contents of this file are subject to the Mozilla Public License Version  *
* 1.1 (the "License"); you may not use this file except in compliance with     *
* the License. You may obtain a copy of the License at                         *
* http://www.mozilla.org/MPL/                                                  *
*                                                                              *
* Software distributed under the License is distributed on an "AS IS" basis,   *
* WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License     *
* for the specific language governing rights and limitations under the         *
* License.                                                                     *
*                                                                              *
* Alternatively, the contents of this file may be used under the terms of the  *
* Free Pascal modified version of the GNU Lesser General Public License        *
* Version 2.1 (the "FPC modified LGPL License"), in which case the provisions  *
* of this license are applicable instead of those above.                       *
* Please see the file LICENSE.txt for additional information concerning this   *
* license.                                                                     *
*                                                                              *
* The Original Code is Color Gradients for Graphics32                          *
*                                                                              *
* The Initial Developer of the Original Code is Angus Johnson                  *
*                                                                              *
* Portions created by the Initial Developer are Copyright (C) 2008-2012        *
* the Initial Developer. All Rights Reserved.                                  *
*                                                                              *
* Contributor(s): Christian Budde <Christian@aixcoustic.com>                   *
*                                                                              *
* ***** END LICENSE BLOCK *****************************************************)

interface

{$I GR32.inc}

uses
  Types, Classes, SysUtils, Math, GR32, GR32_Polygons;

const
  LUTSize = 512;
  LUTSizeMin1 = LUTSize - 1;

type
  TColor32Gradient = record
    Offset: TFloat; //expected range between 0.0 and 1.0
    Color32: TColor32;
  end;
  TArrayOfColor32Gradient = array of TColor32Gradient;

  TLinearGradientType = (lgVertical, lgHorizontal, lgAngled);

  TGradient32 = class(TPersistent)
  private
    FGradientColors: array of TColor32Gradient;
    FOnGradientColorsChanged: TNotifyEvent;
    function GetGradientEntry(Index: Integer): TColor32Gradient;
    function GetGradientCount: Integer; {$IFDEF USEINLINING}inline;{$ENDIF}
    function GetStartColor: TColor32;
    function GetEndColor: TColor32;
  protected
    procedure GradientColorsChanged; virtual;
    procedure AssignTo(Dest: TPersistent); override;
  public
    constructor Create(const GradientColors: array of TColor32Gradient); overload;
    constructor Create(StartColor, EndColor: TColor32); overload;

    procedure ClearColors;
    procedure AddColorStop(Offset: TFloat; Color: TColor32); virtual;
    procedure SetColors(const GradientColors: array of TColor32Gradient);
    function GetColorAt(Fraction: TFloat): TColor32;
    procedure FillColorLookUpTable(var ColorLUT: array of TColor32);

    property GradientEntry[Index: Integer]: TColor32Gradient read GetGradientEntry;
    property GradientCount: Integer read GetGradientCount;
    property StartColor: TColor32 read GetStartColor;
    property EndColor: TColor32 read GetendColor;
    property OnGradientColorsChanged: TNotifyEvent
      read FOnGradientColorsChanged write FOnGradientColorsChanged;
  end;

  TCustomGradientSampler = class(TCustomSampler)
  private
    FGradient: TGradient32;
    FInitialized: Boolean;
    procedure SetGradient(const Value: TGradient32);
  protected
    procedure GradientChangedHandler(Sender: TObject);
    procedure GradientSamplerChanged; //de-initializes sampler
    property Initialized: Boolean read FInitialized;
  public
    procedure PrepareSampling; override;
    constructor Create;
    destructor Destroy; override;
    property Gradient: TGradient32 read FGradient write SetGradient;
  end;

  TRadialGradientSampler = class(TCustomGradientSampler)
  private
    FCenterX: TFloat;
    FCenterY: TFloat;
    FGradientLUT: array [Byte] of TColor32;
    FRadius: TFloat;
    FSqrInvRadius: TFloat;
    procedure SetRadius(const Value: TFloat);
    function GetCenter: TFloatPoint;
    procedure SetCenter(const Value: TFloatPoint);
  public
    procedure PrepareSampling; override;

    function GetSampleInt(X, Y: Integer): TColor32; override;
    function GetSampleFixed(X, Y: TFixed): TColor32; override;
    function GetSampleFloat(X, Y: TFloat): TColor32; override;

    property Radius: TFloat read FRadius write SetRadius;
    property Center: TFloatPoint read GetCenter write SetCenter;
  end;

  TCustomGradientPolygonFiller = class(TCustomPolygonFiller)
  private
    FGradient: TGradient32;
    FInitialized: Boolean;
  protected
    procedure OnBeginRendering; override; //flags initialized
    procedure GradientColorsChangedHandler(Sender: TObject);
    procedure GradientFillerChanged; virtual;

    procedure FillLineNone(Dst: PColor32; DstX, DstY, Length: Integer;
      AlphaValues: PColor32);
    procedure FillLineSolid(Dst: PColor32; DstX, DstY, Length: Integer;
      AlphaValues: PColor32);

    property Initialized: Boolean read FInitialized;
  public
    constructor Create;
    destructor Destroy; override;

    property Gradient: TGradient32 read FGradient;
  end;

  TLinearGradientPolygonFiller = class(TCustomGradientPolygonFiller)
  private
    FIncline: TFloat;
    FStartPoint: TFloatPoint;
    FEndPoint: TFloatPoint;
    procedure SetStartPoint(const Value: TFloatPoint);
    procedure SetEndPoint(const Value: TFloatPoint);

    function ColorStopToScanLine(Index: Integer; Y: Integer): TFloat;
    procedure UpdateIncline;
  protected
    procedure EndPointChanged;
    procedure StartPointChanged;

    procedure OnBeginRendering; override;

    function GetFillLine: TFillLineEvent; override;

    procedure FillLineNegative(Dst: PColor32; DstX, DstY, Length: Integer;
      AlphaValues: PColor32);
    procedure FillLinePositive(Dst: PColor32; DstX, DstY, Length: Integer;
      AlphaValues: PColor32);
    procedure FillLineVertical(Dst: PColor32;
      DstX, DstY, Length: Integer; AlphaValues: PColor32);
    procedure FillLineVerticalExtreme(Dst: PColor32; DstX, DstY,
      Length: Integer; AlphaValues: PColor32);
  public
    property StartPoint: TFloatPoint read FStartPoint write SetStartPoint;
    property EndPoint: TFloatPoint read FEndPoint write SetEndPoint;
  end;

  TCustomRadialGradientPolygonFiller = class(TCustomGradientPolygonFiller)
  protected
    FGradientLUT: array [0..LUTSizeMin1] of TColor32;
  end;

  TRadialGradientPolygonFiller = class(TCustomRadialGradientPolygonFiller)
  private
    FColorBuffer: TArrayOfColor32;
    FCenter: TFloatPoint;
    FRadiusX: TFloat;
    FRadiusY: TFloat;

    FEllipseBounds: TFloatRect;
    procedure SetEllipseBounds(const Value: TFloatRect);
    procedure InitColorBuffer;
  protected
    procedure OnBeginRendering; override;
    function GetFillLine: TFillLineEvent; override;
    procedure FillLineCircle(Dst: PColor32; DstX, DstY, Length: Integer;
      AlphaValues: PColor32); //nb: a color buffer of just one quadrant
    procedure FillLineEllipse(Dst: PColor32; DstX, DstY, Length: Integer;
      AlphaValues: PColor32);
  public
    property EllipseBounds: TFloatRect read FEllipseBounds write SetEllipseBounds;
  end;

  TSVGRadialGradientPolygonFiller = class(TCustomRadialGradientPolygonFiller)
  private
    FColorBuffer: TArrayOfColor32;

    FOffset: TPoint;
    FRadius: TPoint;
    FFocalPt: TFloatPoint;

    FEllipseBounds: TFloatRect;
    FFocalPointNative: TFloatPoint;

    procedure SetEllipseBounds(const Value: TFloatRect);
    procedure SetFocalPoint(const Value: TFloatPoint);
    procedure InitMembers;
    procedure InitColorBuffer;
  protected
    procedure OnBeginRendering; override;
    function GetFillLine: TFillLineEvent; override;
    procedure FillLineEllipse(Dst: PColor32; DstX, DstY, Length: Integer;
      AlphaValues: PColor32);
  public
    property EllipseBounds: TFloatRect read FEllipseBounds write SetEllipseBounds;
    property FocalPoint: TFloatPoint read FFocalPointNative write SetFocalPoint;
  end;

implementation

uses
  GR32_Math, GR32_Blend, GR32_Geometry;

resourcestring
  RCStrIndexOutOfBounds = 'Index out of bounds (%d)';

const
  FloatTolerance = 0.001;
  clNone32: TColor32 = $00000000;

{ TGradient32 }

constructor TGradient32.Create(StartColor, EndColor: TColor32);
var
  Temp: array of TColor32Gradient;
begin
  SetLength(Temp, 2);
  Temp[0].Offset := 0;
  Temp[0].Color32 := StartColor;
  Temp[1].Offset := 1;
  Temp[1].Color32 := EndColor;
  Create(Temp);
end;

constructor TGradient32.Create(const GradientColors: array of TColor32Gradient);
begin
  inherited Create;
  SetColors(GradientColors);
end;

procedure TGradient32.AssignTo(Dest: TPersistent);
begin
  if Dest is TGradient32 then
    TGradient32(Dest).SetColors(self.FGradientColors) else
    inherited;
end;

procedure TGradient32.ClearColors;
begin
  SetLength(FGradientColors, 0);
  GradientColorsChanged;
end;

procedure TGradient32.SetColors(const GradientColors: array of TColor32Gradient);
var
  Index: Integer;
begin
  if Length(GradientColors) = 0 then
  begin
    if length(FGradientColors) > 0 then
      ClearColors;
  end else
  begin
    SetLength(FGradientColors, Length(GradientColors));
    for Index := 0 to Length(GradientColors) - 1 do
      FGradientColors[Index] := GradientColors[Index];
    GradientColorsChanged;
  end;
end;

function TGradient32.GetGradientCount: Integer;
begin
  Result := Length(FGradientColors);
end;

function TGradient32.GetGradientEntry(Index: Integer): TColor32Gradient;
begin
  if Index > Length(FGradientColors) then
    raise Exception.CreateFmt(RCStrIndexOutOfBounds, [Index])
  else
    Result := FGradientColors[Index];
end;

function TGradient32.GetStartColor: TColor32;
begin
  if Length(FGradientColors) = 0 then
    Result := clNone32
  else
    Result := FGradientColors[0].Color32;
end;

function TGradient32.GetEndColor: TColor32;
var
  Count: Integer;
begin
  Count := Length(FGradientColors);
  if Count = 0 then
    Result := clNone32
  else
    Result := FGradientColors[Count - 1].Color32;
end;

function TGradient32.GetColorAt(Fraction: TFloat): TColor32;
var
  I, Count: Integer;
begin
  Count := GradientCount;
  if (Count = 0) or (Fraction <= FGradientColors[0].Offset) then
    Result := StartColor
  else if (Fraction >= FGradientColors[Count - 1].Offset) then
    Result := EndColor
  else
  begin
    I := 1;
    while (I < Count) and (Fraction > FGradientColors[I].Offset) do
      Inc(I);
    Fraction := (Fraction - FGradientColors[I - 1].Offset) /
      (FGradientColors[I].Offset - FGradientColors[I - 1].Offset);
    if Fraction <= 0 then
      Result := FGradientColors[I - 1].Color32
    else if Fraction >= 1 then
      Result := FGradientColors[I].Color32
    else
    begin
      Result := CombineReg(FGradientColors[I].Color32,
          FGradientColors[I - 1].Color32, Round($FF * Fraction));
      EMMS;
    end;
  end;
end;

procedure TGradient32.FillColorLookUpTable(var ColorLUT: array of TColor32);
var
  I, J, Count, HighLUT: Integer;
  Fraction, F, Delta: TFloat;
begin
  HighLUT := High(ColorLUT);
  Count := GradientCount;
  if (Count < 2) or (HighLUT < 1) then
  begin
    for I := 0 to HighLUT do
      ColorLUT[I] := StartColor;
    Exit;
  end;

  ColorLUT[0] := StartColor;
  ColorLUT[HighLUT] := EndColor;
  Delta := 1 / HighLUT;
  Fraction := Delta;

  I := 1;
  while Fraction <= FGradientColors[0].Offset do
  begin
    ColorLUT[I] := ColorLUT[0];
    Fraction := Fraction + Delta;
    Inc(i);
  end;

  J := 1;
  for I := I to HighLUT - 1 do
  begin
    while (J < Count) and (Fraction > FGradientColors[J].Offset) do
      Inc(J);
    if J = Count then
    begin
      for J := I to HighLUT - 1 do
        ColorLUT[J] := ColorLUT[HighLUT];
      Break;
    end;
    F := (Fraction - FGradientColors[J - 1].Offset) /
      (FGradientColors[J].Offset - FGradientColors[J - 1].Offset);
    if F <= 0 then
      ColorLUT[I] := FGradientColors[J - 1].Color32
    else if F >= 1 then
      ColorLUT[I] := FGradientColors[J].Color32
    else
    begin
      ColorLUT[I] := CombineReg(FGradientColors[J].Color32,
        FGradientColors[J - 1].Color32, Round($FF * F));
      EMMS;
    end;
    Fraction := Fraction + Delta;
  end;
end;

procedure TGradient32.GradientColorsChanged;
begin
  if Assigned(FOnGradientColorsChanged) then
    FOnGradientColorsChanged(Self);
end;

procedure TGradient32.AddColorStop(Offset: TFloat; Color: TColor32);
var
  Index, OldCount: Integer;
begin
  OldCount := Length(FGradientColors);
  Index := 0;
  while (Index < OldCount) and (Offset >= FGradientColors[Index].Offset) do
    Inc(Index);
  SetLength(FGradientColors, OldCount + 1);
  if (Index < OldCount) then
    Move(FGradientColors[Index], FGradientColors[Index + 1],
      (OldCount - Index) * SizeOf(TColor32Gradient));
  FGradientColors[Index].Offset := Offset;
  FGradientColors[Index].Color32 := Color;
  GradientColorsChanged;
end;

{ TCustomGradientSampler }

constructor TCustomGradientSampler.Create;
begin
  inherited;
  FGradient := TGradient32.Create;
end;

destructor TCustomGradientSampler.Destroy;
begin
  FGradient.Free;
  inherited;
end;

procedure TCustomGradientSampler.SetGradient(const Value: TGradient32);
begin
  if not assigned(Value) then
    FGradient.ClearColors else
    Value.AssignTo(self);
  GradientSamplerChanged;
end;

procedure TCustomGradientSampler.GradientChangedHandler(Sender: TObject);
begin
  GradientSamplerChanged;
end;

procedure TCustomGradientSampler.GradientSamplerChanged;
begin
  FInitialized := False;
end;

procedure TCustomGradientSampler.PrepareSampling;
begin
  inherited;
  FInitialized := True;
end;


{ TRadialGradientSampler }

function TRadialGradientSampler.GetSampleFixed(X, Y: TFixed): TColor32;
var
  RelativeRadius: TFloat;
begin
  RelativeRadius := Sqrt((Sqr(FixedToFloat * X - FCenterX) +
    Sqr(FixedToFloat * Y - FCenterY)) * FSqrInvRadius);
  Result := FGradientLUT[EnsureRange(Round($FF * RelativeRadius), 0, $FF)];
end;

function TRadialGradientSampler.GetSampleFloat(X, Y: TFloat): TColor32;
var
  RelativeRadius: TFloat;
begin
  RelativeRadius := Sqrt((Sqr(X - FCenterX) + Sqr(Y - FCenterY)) * FSqrInvRadius);
  Result := FGradientLUT[EnsureRange(Round($FF * RelativeRadius), 0, $FF)];
end;

function TRadialGradientSampler.GetSampleInt(X, Y: Integer): TColor32;
var
  RelativeRadius: TFloat;
begin
  RelativeRadius := Sqrt((Sqr(X - FCenterX) + Sqr(Y - FCenterY)) * FSqrInvRadius);
  Result := FGradientLUT[EnsureRange(Round($FF * RelativeRadius), 0, $FF)];
end;

procedure TRadialGradientSampler.PrepareSampling;
begin
  if not Initialized then
  begin
    FGradient.FillColorLookUpTable(FGradientLUT);
    inherited;
  end;
end;

procedure TRadialGradientSampler.SetRadius(const Value: TFloat);
begin
  if FRadius <> Value then
  begin
    FRadius := Value;
    FSqrInvRadius := 1 / Sqr(FRadius);
  end;
end;

function TRadialGradientSampler.GetCenter: TFloatPoint;
begin
  Result.X := FCenterX;
  Result.Y := FCenterY;
end;

procedure TRadialGradientSampler.SetCenter(const Value: TFloatPoint);
begin
  FCenterX := Value.X;
  FCenterY := Value.Y;
end;


{TCustomGradientPolygonFiller}

constructor TCustomGradientPolygonFiller.Create;
begin
  inherited Create;
  FGradient := TGradient32.Create;
  FGradient.OnGradientColorsChanged := GradientColorsChangedHandler;
end;

destructor TCustomGradientPolygonFiller.Destroy;
begin
  FGradient.Free;
  inherited;
end;

procedure TCustomGradientPolygonFiller.FillLineNone(Dst: PColor32; DstX,
  DstY, Length: Integer; AlphaValues: PColor32);
begin
  // do nothing!
end;

procedure TCustomGradientPolygonFiller.FillLineSolid(Dst: PColor32; DstX,
  DstY, Length: Integer; AlphaValues: PColor32);
var
  X: Integer;
  Color32: TColor32;
  BlendMemEx: TBlendMemEx;
begin
  BlendMemEx := BLEND_MEM_EX[cmBlend]^;
  Color32 := FGradient.FGradientColors[0].Color32;

  for X := DstX to DstX + Length - 1 do
  begin
    BlendMemEx(Color32, Dst^, AlphaValues^);
    Inc(Dst);
    Inc(AlphaValues);
  end;
  EMMS;
end;

procedure TCustomGradientPolygonFiller.GradientColorsChangedHandler(Sender: TObject);
begin
  GradientFillerChanged;
end;

procedure TCustomGradientPolygonFiller.GradientFillerChanged;
begin
  FInitialized := False;
end;

procedure TCustomGradientPolygonFiller.OnBeginRendering;
begin
  FInitialized := True;
end;


{TLinearGradientPolygonFiller}

procedure TLinearGradientPolygonFiller.SetStartPoint(const Value: TFloatPoint);
begin
  if (FStartPoint.X <> Value.X) or (FStartPoint.Y <> Value.Y) then
  begin
    FStartPoint := Value;
    StartPointChanged;
  end;
end;

procedure TLinearGradientPolygonFiller.SetEndPoint(const Value: TFloatPoint);
begin
  if (FEndPoint.X <> Value.X) or (FEndPoint.Y <> Value.Y) then
  begin
    FEndPoint := Value;
    EndPointChanged;
  end;
end;

procedure TLinearGradientPolygonFiller.StartPointChanged;
begin
  GradientFillerChanged;
  UpdateIncline;
end;

procedure TLinearGradientPolygonFiller.EndPointChanged;
begin
  GradientFillerChanged;
  UpdateIncline;
end;

procedure TLinearGradientPolygonFiller.UpdateIncline;
begin
  if (FEndPoint.X - FStartPoint.X) <> 0 then
    FIncline := (FEndPoint.Y - FStartPoint.Y) / (FEndPoint.X - FStartPoint.X);
end;

function TLinearGradientPolygonFiller.ColorStopToScanLine(Index: Integer;
  Y: Integer): TFloat;
var
  Offset: TFloat;
begin
  Offset := FGradient.FGradientColors[Index].Offset;
  Result := (1 - Offset) * FStartPoint.X + Offset * FEndPoint.X +
    ((1 - Offset) * (FStartPoint.Y - Y) + Offset * (FEndPoint.Y - Y)) * FIncline;
end;

procedure TLinearGradientPolygonFiller.OnBeginRendering;
begin
  if not Initialized then
  begin
    inherited; //sets initialized = True
  end;
end;

function TLinearGradientPolygonFiller.GetFillLine: TFillLineEvent;
begin
  case FGradient.GradientCount of
    0: Result := FillLineNone;
    1: Result := FillLineSolid;
    else
      if FStartPoint.X = FEndPoint.X then
        if FStartPoint.Y = FEndPoint.Y then
          Result := FillLineVerticalExtreme
        else
          Result := FillLineVertical
      else
      if FStartPoint.X < FEndPoint.X then
        Result := FillLinePositive
      else
        Result := FillLineNegative;
  end;
end;

procedure TLinearGradientPolygonFiller.FillLineVertical(Dst: PColor32; DstX,
  DstY, Length: Integer; AlphaValues: PColor32);
var
  X: Integer;
  Color32: TColor32;
begin
  Color32 := FGradient.GetColorAt((DstY - FStartPoint.Y) /
    (FEndPoint.Y - FStartPoint.Y));

  for X := DstX to DstX + Length - 1 do
  begin
    BlendMemEx(Color32, Dst^, AlphaValues^);
    Inc(Dst);
    Inc(AlphaValues);
  end;
  EMMS;
end;

procedure TLinearGradientPolygonFiller.FillLineVerticalExtreme(Dst: PColor32; DstX,
  DstY, Length: Integer; AlphaValues: PColor32);
var
  X: Integer;
  Color32: TColor32;
begin
  if DstY < FStartPoint.Y then
    Color32 := FGradient.StartColor
  else
    Color32 := FGradient.EndColor;

  for X := DstX to DstX + Length - 1 do
  begin
    BlendMemEx(Color32, Dst^, AlphaValues^);
    Inc(Dst);
    Inc(AlphaValues);
  end;
  EMMS;
end;

procedure FillLineAlpha(var Dst: PColor32; var AlphaValues: PColor32;
  Count: Integer; Color: TColor32); {$IFDEF USEINLINING}inline;{$ENDIF}
var
  X: Integer;
begin
  for X := 0 to Count - 1 do
  begin
    BlendMemEx(Color, Dst^, AlphaValues^);
    Inc(Dst);
    Inc(AlphaValues);
  end;
  EMMS;
end;

procedure TLinearGradientPolygonFiller.FillLinePositive(Dst: PColor32; DstX,
  DstY, Length: Integer; AlphaValues: PColor32);
var
  X, Index: Integer;
  IntScale, IntValue: Integer;
  Colors: array [0..1] of TColor32;
  Scale: TFloat;
  XOffset: array [0..1] of TFloat;
  XPos: array [0..2] of Integer;
begin
  // set first offset/position
  XOffset[0] := ColorStopToScanLine(0, DstY);
  XPos[0] := Round(XOffset[0]);
  XPos[2] := DstX + Length;

  // check if only a solid start color should be drawn.
  if XPos[0] >= XPos[2] - 1 then
  begin
    FillLineSolid(Dst, DstX, DstY, Length, AlphaValues);
    Exit;
  end;

  // set start color
  Colors[0] := FGradient.FGradientColors[0].Color32;

  // eventually draw solid start color
  FillLineAlpha(Dst, AlphaValues, XPos[0] - DstX, Colors[0]);

  Index := 1;
  repeat
    // set start position to be at least DstX
    if XPos[0] < DstX then
      XPos[0] := DstX;

    // set destination color and offset
    Colors[1] := FGradient.FGradientColors[Index].Color32;
    XOffset[1] := ColorStopToScanLine(Index, DstY);

    // calculate destination pixel position
    XPos[1] := Round(XOffset[1]);
    if XPos[1] > XPos[2] then
      XPos[1] := XPos[2];

    // check whether
    if XPos[1] > XPos[0] then
    begin
      Scale := 1 / (XOffset[1] - XOffset[0]);
      IntScale := Round($7FFFFFFF * Scale);
      IntValue := Round($7FFFFFFF * (XPos[0] - XOffset[0]) * Scale);

      for X := XPos[0] to XPos[1] - 1 do
      begin
        BlendMemEx(CombineReg(Colors[1], Colors[0], IntValue shr 23),
          Dst^, AlphaValues^);
        IntValue := IntValue + IntScale;

        Inc(Dst);
        Inc(AlphaValues);
      end;
      EMMS;
    end;

    // check whether further drawing is still necessary
    if XPos[1] = XPos[2] then
      Exit;

    Inc(Index);

    XPos[0] := XPos[1];
    XOffset[0] := XOffset[1];
    Colors[0] := Colors[1];
  until (Index = FGradient.GradientCount);

  if XPos[0] < DstX then
    XPos[0] := DstX;

  FillLineAlpha(Dst, AlphaValues, XPos[2] - XPos[0], Colors[0]);
end;


procedure TLinearGradientPolygonFiller.FillLineNegative(Dst: PColor32; DstX,
  DstY, Length: Integer; AlphaValues: PColor32);
var
  X, Index: Integer;
  IntScale, IntValue: Integer;
  Colors: array [0..1] of TColor32;
  Scale: TFloat;
  XOffset: array [0..1] of TFloat;
  XPos: array [0..2] of Integer;
begin
  Index := FGradient.GradientCount - 1;

  // set first offset/position
  XOffset[0] := ColorStopToScanLine(Index, DstY);
  XPos[0] := Round(XOffset[0]);
  XPos[2] := DstX + Length;

  // set start color
  Colors[0] := FGradient.FGradientColors[Index].Color32;

  // check if only a solid start color should be drawn.
  if XPos[0] >= XPos[2] - 1 then
  begin
    FillLineAlpha(Dst, AlphaValues, Length, Colors[0]);
    Exit;
  end;

  // eventually draw solid start color
  FillLineAlpha(Dst, AlphaValues, XPos[0] - DstX, Colors[0]);

  Dec(Index);
  repeat
    // set start position to be at least DstX
    if XPos[0] < DstX then
      XPos[0] := DstX;

    // set destination color and offset
    Colors[1] := FGradient.FGradientColors[Index].Color32;
    XOffset[1] := ColorStopToScanLine(Index, DstY);

    // calculate destination pixel position
    XPos[1] := Round(XOffset[1]);
    if XPos[1] > XPos[2] then
      XPos[1] := XPos[2];

    // check whether
    if XPos[1] > XPos[0] then
    begin
      Scale := 1 / (XOffset[1] - XOffset[0]);
      IntScale := Round($7FFFFFFF * Scale);
      IntValue := Round($7FFFFFFF * (XPos[0] - XOffset[0]) * Scale);

      for X := XPos[0] to XPos[1] - 1 do
      begin
        BlendMemEx(CombineReg(Colors[1], Colors[0], IntValue shr 23),
          Dst^, AlphaValues^);
        IntValue := IntValue + IntScale;

        Inc(Dst);
        Inc(AlphaValues);
      end;
      EMMS;
    end;

    // check whether further drawing is still necessary
    if XPos[1] = XPos[2] then
      Exit;

    Dec(Index);

    XPos[0] := XPos[1];
    XOffset[0] := XOffset[1];
    Colors[0] := Colors[1];
  until (Index < 0);

  if XPos[0] < DstX then
    XPos[0] := DstX;

  FillLineAlpha(Dst, AlphaValues, XPos[2] - XPos[0], Colors[0]);
end;



{TRadialGradientPolygonFiller}

procedure TRadialGradientPolygonFiller.SetEllipseBounds(const Value: TFloatRect);
var
  Radius: TFloatPoint;
begin
  with Value do
  begin
    FCenter := FloatPoint((Left + Right) * 0.5, (Top + Bottom) * 0.5);
    Radius.X := Round((Right - Left) * 0.5);
    Radius.Y := Round((Bottom - Top) * 0.5);
  end;
  //only notify on changes to the radii ...
  if (Abs(Radius.X - FRadiusX) > FloatTolerance) or
    (Abs(Radius.Y - FRadiusY) > FloatTolerance) then
      GradientFillerChanged;
  FRadiusX := Radius.X;
  FRadiusY := Radius.Y;
  FEllipseBounds := Value;
end;

procedure TRadialGradientPolygonFiller.InitColorBuffer;
var
  I,J, RX, RY: Integer;
  RadiusXDivRadiusY, Rad, Rad2, X, Y: TFloat;
begin
  if (FRadiusX = 0) or (FRadiusY = 0) then
    Exit;

  FGradient.FillColorLookUpTable(FGradientLUT);

  RX := Round(FRadiusX);
  RY := Round(FRadiusY);

  SetLength(FColorBuffer, RX * RY);

  //fill the color buffer using GradientLUT ...
  if RX = RY then
  begin
    for I := 0 to RX - 1 do
      for J := 0 to RY - 1 do
      begin
        Rad := Math.Hypot(I, J); //nb: avoids integer Hypot() in GR32_Math
        if Rad >= FRadiusX then
          FColorBuffer[(J * RX) + I] := FGradientLUT[LUTSizeMin1]
        else
          FColorBuffer[(J * RX) + I] :=
            FGradientLUT[Trunc(Rad * LUTSizeMin1 / RX)];
      end;
  end else
  begin
    RadiusXDivRadiusY := FRadiusX / FRadiusY;
    for I := 0 to RX - 1 do
      for J := 0 to RY - 1 do
      begin
        Rad := Math.Hypot(I, J); //nb: avoids integer Hypot() in GR32_Math
        if I = 0 then
          Rad2 := FRadiusY
        else if J = 0 then
          Rad2 := FRadiusX
        else
        begin
          GR32_Math.SinCos(ArcTan(RadiusXDivRadiusY * J / I), Y, X);
          Rad2 := Hypot(X * FRadiusX, Y * FRadiusY);
        end;
        if Rad >= Rad2 then
          FColorBuffer[(J * RX) + I] := FGradientLUT[LUTSizeMin1]
        else
          FColorBuffer[(J * RX) + I] :=
            FGradientLUT[Round(Rad * LUTSizeMin1 / Rad2)];
      end;
  end;
end;

procedure TRadialGradientPolygonFiller.OnBeginRendering;
begin
  if not Initialized then
  begin
    InitColorBuffer;
    inherited; //sets initialized = True
  end;
end;

function TRadialGradientPolygonFiller.GetFillLine: TFillLineEvent;
begin
  if FRadiusX = FRadiusY then
    Result := FillLineCircle
  else
    Result := FillLineEllipse;
end;

procedure TRadialGradientPolygonFiller.FillLineCircle(Dst: PColor32;
  DstX, DstY, Length: Integer; AlphaValues: PColor32);
var
  X: Integer;
  RelativeRadius: TFloat;
  SqrInvRadius: TFloat;
  YDist: TFloat;
  Index: Integer;
  Color32: TColor32;
  BlendMemEx: TBlendMemEx;
begin
  SqrInvRadius := Sqr(1 / FRadiusX);
  BlendMemEx := BLEND_MEM_EX[cmBlend]^;
  YDist := Sqr(DstY - FCenter.Y);
  for X := DstX to DstX + Length - 1 do
  begin
    RelativeRadius := Sqrt((Sqr(X - FCenter.X) + YDist) * SqrInvRadius);
    Index := EnsureRange(Round($1FF * RelativeRadius), 0, $1FF);
    Color32 := FGradientLUT[Index];
    BlendMemEx(Color32 and $00FFFFFF or $FF000000, Dst^, AlphaValues^);
    EMMS;
    Inc(Dst);
    Inc(AlphaValues);
  end;
end;

procedure TRadialGradientPolygonFiller.FillLineEllipse(Dst: PColor32;
  DstX, DstY, Length: Integer; AlphaValues: PColor32);
var
  X: Integer;
  Delta: TFloatPoint;
  Color32: TColor32;
  BlendMemEx: TBlendMemEx;
begin
  BlendMemEx := BLEND_MEM_EX[cmBlend]^;
  Delta.Y := Abs(DstY - FCenter.Y);
  for X := DstX to DstX + Length - 1 do
  begin
    Delta.X := Abs(X - FCenter.X);
    if (Delta.X >= FRadiusX) or (Delta.Y >= FRadiusY) then
      Color32 := FGradientLUT[LUTSizeMin1] else
      Color32 := FColorBuffer[Trunc(Delta.Y * FRadiusX + Delta.X)];
    BlendMemEx(Color32, Dst^, AlphaValues^);
    EMMS;
    Inc(Dst);
    Inc(AlphaValues);
  end;
end;


{TSVGRadialGradientPolygonFiller}

procedure TSVGRadialGradientPolygonFiller.SetEllipseBounds(const Value: TFloatRect);
begin
  FEllipseBounds := Value;
  GradientFillerChanged;
end;

procedure TSVGRadialGradientPolygonFiller.SetFocalPoint(const Value: TFloatPoint);
begin
  FFocalPointNative := Value;
  GradientFillerChanged;
end;

procedure TSVGRadialGradientPolygonFiller.InitMembers;
var
  X, Y: TFloat;
begin
  FRadius.X := Round((FEllipseBounds.Right - FEllipseBounds.Left) * 0.5);
  FRadius.Y := Round((FEllipseBounds.Bottom - FEllipseBounds.Top) * 0.5);
  FOffset.X := -Round(FEllipseBounds.Left);
  FOffset.Y := -Round(FEllipseBounds.Top);
  //make FFocalPoint relative to the ellipse midpoint ...
  FFocalPt.X :=
    FFocalPointNative.X - (FEllipseBounds.Right + FEllipseBounds.Left) * 0.5;
  FFocalPt.Y :=
    FFocalPointNative.Y - (FEllipseBounds.Bottom + FEllipseBounds.Top) * 0.5;

  //make sure the focal point stays within the bounding ellipse ...
  if Abs(FFocalPt.X) < FloatTolerance then
  begin
    X := 0;
    if FFocalPt.Y < 0 then
      Y := -1 else
      Y := 1;
  end else
    GR32_Math.SinCos(ArcTan(FRadius.X / FRadius.Y *
      FFocalPt.Y / FFocalPt.X), Y, X);
  if FFocalPt.X < 0 then
  begin
    X := -X;
    Y := -Y;
  end;
  X := X * FRadius.X;
  Y := Y * FRadius.Y;
  if (Y * Y + X * X) < (FFocalPt.X * FFocalPt.X + FFocalPt.Y * FFocalPt.Y) then
  begin
    FFocalPt.X := Trunc(X);
    FFocalPt.Y := Trunc(Y);
  end;
end;

procedure TSVGRadialGradientPolygonFiller.InitColorBuffer;
var
  I, J, FocalPointX, RadXSqrd, RadYSqrd, DiamX, DiamY: Integer;
  Rad, Rad2, X2, Y2, DistYDown, DistYUp: TFloat;
  m, b, Qa, Qb, Qc, Qz: Double;
begin
  if (FRadius.X = 0) or (FRadius.Y = 0) then
    Exit;

  FGradient.FillColorLookUpTable(FGradientLUT);

  RadXSqrd := FRadius.X * FRadius.X;
  RadYSqrd := FRadius.Y * FRadius.Y;

  DiamX := (FRadius.X * 2) + 1;
  DiamY := (FRadius.Y * 2) + 1;
  FocalPointX := Round(FFocalPt.X);

  //Because the slope of vertical lines is infinite, we need to find where a
  //vertical line through the FocalPoint intersects with the Ellipse, and
  //store the distances from the focal point to these 2 intersections points ...
  Y2 := Sqrt(RadYSqrd - FFocalPt.X * FFocalPt.X * RadYSqrd / RadXSqrd);
  DistYDown := Abs(Y2 - FFocalPt.Y);
  DistYUp := Abs(-Y2 - FFocalPt.Y);

  SetLength(FColorBuffer, DiamX * DiamY);
  for I := -FRadius.X to FRadius.X do
    for J := -FRadius.Y to FRadius.Y do
    begin
      Rad := Hypot(I - FFocalPt.X , J - FFocalPt.Y);
      if I = FocalPointX then //ie on the vertical line (see above)
      begin
        if I * I <= RadXSqrd then
        begin
          if J < FFocalPt.Y then
            Rad2 := DistYUp else
            Rad2 := DistYDown;
          if Rad >= Rad2 then
            FColorBuffer[((J + FRadius.Y) * DiamX) + I + FRadius.X] :=
              FGradientLUT[LUTSizeMin1]
          else
            FColorBuffer[((J + FRadius.Y) * DiamX) + i + FRadius.X] :=
              FGradientLUT[Trunc(Rad * LUTSizeMin1 / Rad2)];
        end else
          FColorBuffer[((J + FRadius.Y) * DiamX) + I + FRadius.X] :=
            FGradientLUT[LUTSizeMin1];
        continue;
      end;

      //equation of line: y = mx + b
      m := (J - FFocalPt.Y)/(I - FFocalPt.X);
      b := FFocalPt.Y - m * FFocalPt.X;
      //equation of ellipse ...
      //  x^2/RadXSqrd + y^2/RadYSqrd = 1
      //  x^2*RadYSqrd/RadXSqrd + y^2 = RadYSqrd
      //  RadYSqrd(x^2) + RadXSqrd(y^2) = RadXSqrd*RadYSqrd
      //simultaneous equations ...
      //  RadYSqrd(x^2) + RadXSqrd(mx + b)^2 = RadXSqrd*RadYSqrd
      //  (RadYSqrd + RadXSqrd*m^2)(x^2) +
      //    RadXSqrd*2mb(x) + RadXSqrd*b^2 - RadXSqrd*RadYSqrd = 0

      //apply quadratic equation ...
      Qa := (RadYSqrd + RadXSqrd * m * m);
      Qb := RadXSqrd * 2 * m * b;
      Qc := RadXSqrd * b * b - RadXSqrd * RadYSqrd;
      Qz := Qb * Qb - 4 * Qa * Qc;
      if Qz >= 0 then
      begin
        Qz := Sqrt(Qz);
        X2 := (-Qb + Qz) / (2 * Qa);
        if (FFocalPt.X > X2) = (I > FFocalPt.X) then
          X2 := (-Qb - Qz) / (2 * Qa);
        Y2 := m * X2 + b;
        Rad2 := Hypot(X2 - FFocalPt.X, Y2 - FFocalPt.Y);
      end else
        Rad2 := Rad;

      if Rad >= Rad2 then
        FColorBuffer[((J + FRadius.Y) * DiamX) + I + FRadius.X] :=
          FGradientLUT[LUTSizeMin1]
      else
        FColorBuffer[((J + FRadius.Y) * DiamX) + I + FRadius.X] :=
          FGradientLUT[Trunc(Rad * LUTSizeMin1 / Rad2)];
    end;
end;

procedure TSVGRadialGradientPolygonFiller.OnBeginRendering;
begin
  if not Initialized then
  begin
    InitMembers;
    InitColorBuffer;
    inherited; //sets initialized = True
  end;
end;

function TSVGRadialGradientPolygonFiller.GetFillLine: TFillLineEvent;
begin
  Result := FillLineEllipse;
end;

procedure TSVGRadialGradientPolygonFiller.FillLineEllipse(Dst: PColor32;
  DstX, DstY, Length: Integer; AlphaValues: PColor32);
var
  X, DiamX, DiamY: Integer;
  Delta: TPoint;
  Color32: TColor32;
  BlendMemEx: TBlendMemEx;
begin
  BlendMemEx := BLEND_MEM_EX[cmBlend]^;
  Delta.Y := DstY + FOffset.Y;
  DiamX := FRadius.X * 2 + 1;
  DiamY := FRadius.Y * 2 + 1;
  for X := DstX to DstX + Length - 1 do
  begin
    Delta.X := X + FOffset.X;
    if (Delta.X < 0) or (Delta.Y < 0) or (Delta.X >= DiamX) or (Delta.Y >= DiamY) then
      Color32 := FGradientLUT[LUTSizeMin1] else
      Color32 := FColorBuffer[Delta.Y * DiamX + Delta.X];
    BlendMemEx(Color32, Dst^, AlphaValues^);
    Inc(Dst);
    Inc(AlphaValues);
  end;
  EMMS;
end;

end.
