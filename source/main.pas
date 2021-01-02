unit main;

{$MODE Delphi}

interface

uses
    {$IFDEF Win32}
  Windows,  Messages,
{$ELSE}
  LMessages, LCLType,
{$ENDIF}
   {$IFDEF FPC}LResources, {$ENDIF}
  LCLIntf, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls, ComCtrls, filter_rbj,
  Buttons,ffts, define_types;

type
   //this custom control type is used to eliminate screen flicker
  // see http://wiki.lazarus.freepascal.org/Developing_with_Graphics
  TMyDrawingControl = class(TCustomControl)
  public
    procedure EraseBackground(DC: HDC); override;
    procedure Paint; override;
  end;

  { TForm1 }

  TForm1 = class(TForm)
    FFTbox: TGroupBox;
    FFTChart: TImage;
    HzDrop: TComboBox;
    Timer1: TTimer;
    ToolPanel: TPanel;
    InputBox: TGroupBox;
    Freq1: TTrackBar;
    Freq2: TTrackBar;
    Freq3: TTrackBar;
    Filterbox: TGroupBox;
    Label1: TLabel;
    GainLabel: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    SpeedButton1: TSpeedButton;
    QIsBandWidthCheck: TCheckBox;
    FiltTypeDrop: TComboBox;
    Hz: TTrackBar;
    Q: TTrackBar;
    Gain: TTrackBar;
    DisplayPanel: TPanel;
    OutChart: TIMage;
    InChart: TImage;
    procedure FormCreate(Sender: TObject);
    procedure HzDropChange(Sender: TObject);
    procedure InChartPaint(Sender: TObject);
    procedure UpdateFilter;
    procedure Timer1Timer(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure Freq1Change(Sender: TObject);
    procedure FiltTypeDropChange(Sender: TObject);
    procedure GainChange(Sender: TObject);
    procedure SpeedButton1Click(Sender: TObject);
    procedure DisplayPanelResize(Sender: TObject);
    procedure DrawFFT;
    //procedure CreateFFT (var lImage: TImage);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation
var
  kSamplesPerSec : integer= 256;
  kSamplesPerMSec : single =  256{kSamplesPerSec}/1000;
  kSkip: integer = 0;
var
  F1,F2,F3: single;
  gLastSample: integer;
  gStartTick: DWord;
  gRGJFilter : TRbjEqFilter;
  InVis,OutVis: TMyDrawingControl;


procedure TMyDrawingControl.EraseBackground(DC: HDC);
begin
  // Uncomment this to enable default background erasing
  //inherited EraseBackground(DC);
end;

procedure TMyDrawingControl.Paint;
var
  x, y: Integer;
  Bitmap: TBitmap;
begin
  Bitmap := TBitmap.Create;
  try
    // Initializes the Bitmap Size
    Bitmap.Height := Height;
    Bitmap.Width := Width;
    if odd(Tag) then
       Canvas.Draw(0, 0, Form1.OutChart.Picture.Bitmap)
    else
    	 Canvas.Draw(0, 0, Form1.InChart.Picture.Bitmap);


  finally
    Bitmap.Free;
  end;

  inherited Paint;
end;

procedure MinMax ( lData: singlep; lnSamp: integer; var lMin,lMax: single);
var
  i: integer;
begin
  if lnSamp < 1 then
  	 exit;
  lMin := lData^[1];
  lMax := lData^[1];
  for i := 1 to lnSamp do begin
    if lData^[i] < lMin then
       lMin := lData^[i];
    if lData^[i] > lMax then
       lMax := lData^[i];
  end;
end;

procedure DrawChart (var lImage: TImage; lData: singlep; lnSamp: integer; SampleRateHz: single);
const
  kB= 6;//border
var
  TxtHt,bottom,x,y,i,cH,cW: integer;//chart height/width
  lMin,lMax: single;
  lS: string;
begin
  MinMax(lData,lnSamp,lMin,lMax);
  with lImage.Picture.Bitmap.Canvas do begin
  	   brush.color := clMoneyGreen;
       FillRect(0,0,lImage.Width,lImage.Height);
       TxtHt := TextHeight('0');
       cW := lImage.Width-kB-kB;
       cH := lImage.Height-kB-TxtHt-kB;
       if (cH < 1) or (cW < 1) then
    	  exit;

       Font.color := clWhite;
       TextOut(kB,kB,floattostrf(lMax, ffFixed, 8, 2));
       TextOut(kB,kB+cH,'0');
       lS := inttostr(round(SampleRateHz/2)); //graph is linear, 0..Nyquist
       TextOut(kB+cW-TextWidth(lS),kB+cH,lS);
       TextOut(kB+cW div 2-TextWidth('Hz') div 2,kB+cH,'Hz');

       pen.color := clBLack;
       moveto(kB, cH+kB);
       for i := 1 to lnSamp do begin
       	   x := round((i/lnSamp) * cW);
       	   y := round( ((lData^[i]-lMin)/lMax)*cH);
         lineto(kB + x,cH+kB- y);
       end;
       //lImage.invalidate;
  end; //with Image
end;

procedure TForm1.DrawFFT;
var
  x,fftx: Singlep;
  SamplesDiv2,Samples,i,loop: integer;
  lRGJFilter : TRbjEqFilter;
begin
  Samples := round(kSamplesPerSec * 1); //collect one second of data
  SamplesDiv2:= (Samples div 2)-1;

  if (F1<1) and (F2<1) and (F3 < 1) then
  	 exit;
  getmem(x,Samples*sizeof(single));
  getmem(fftx,SamplesDiv2*sizeof(single));
  lRGJFilter := TRbjEqFilter.Create(kSamplesPerSec,0);
  lRGJFilter.CalcFilterCoeffs(FiltTypeDrop.ItemIndex,Hz.Position,Q.Position/100,Gain.Position/100, QIsBandWidthCheck.Checked);
  for loop := 1 to 2 do //do this twice so the filter has a chance adapt to the signal
  	  for i := 1 to Samples do begin
         if F1 > 0 then
           x^[i] :=sin (i * 2.0 * pi /F1)
         else
           x^[i] := 0;
         if F2 > 0 then
           x^[i] :=x^[i]+sin (i * 2.0 * pi /F2);
         if F3 > 0 then
           x^[i] :=x^[i]+sin (i * 2.0 * pi /F3);
  		 x^[i] := lRGJFilter.Process(x^[i])
  	  end;
  lRGJFilter.Free;
  FFTPower(x,fftx,Samples);
  DrawChart(FFTChart,fftx,SamplesDiv2,kSamplesPerSec);
  freemem(x);
  freemem(fftx);
end;


procedure AddSample (lImage: TImage; lXPos: integer; lYPos: single);
//YPos will range from -1..1
var
lYposI: integer;
begin
  with lImage.Picture.Bitmap.Canvas do begin
       pen.color := clBlack;
       lYPosi := round(((lYPos/2)+0.5)* lImage.Height);
       moveto(lXPos-1-kSkip, lImage.Tag);
       if lXPos > 1 then
          lineto(lXPos, lYPosi)
       else begin
            brush.color := clMoneyGreen;
            FillRect(0,0,lImage.Width,lImage.Height);
            Font.color := clWhite;
            if odd(lImage.Tag) then
               TextOut(2,2,'Filtered signal')
            else
            	TextOut(2,2,'Original signal');
       end;
       lImage.Tag := lYPosi;
  end; //with Image
end; //proc AddSample

procedure ResetClock;
begin
  gStartTick := GetTickCount;
  gLastSample := 0;
end;



procedure TForm1.Timer1Timer(Sender: TObject);
var
  lTick,lSample,lS,lChannels: integer;
  v: single;
begin
  lTick := GetTickCount-gStartTick;
   if lTick < 0 then begin
    ResetClock;
    exit;
   end;
   //if lTick > 1000 then
   //	  exit;
   lSample := round(lTick*kSamplesPerMSec);
   if lSample > gLastSample then begin
    for lS := gLastSample+1 to lSample do begin
      InputBox.Tag := InputBox.Tag + 1;
      if InputBox.Tag >= (MaxInt-1) then
        InputBox.Tag := 0;
      Timer1.Tag := Timer1.Tag +kSkip+ 1;
      if Timer1.Tag >= (InChart.width) then  begin
        Timer1.Tag := 1;
      end;
      if F1 > 0 then
        lChannels := 1
      else
        lChannels := 0;
      if F2 > 0 then
        inc(lChannels);
      if F3 > 0 then
        inc(lChannels);
      if F1 > 0 then
        v :=sin (InputBox.Tag * 2.0 * pi /F1)
      else
        v := 0;
      if F2 > 0 then
        v :=v+sin (InputBox.Tag * 2.0 * pi /F2);
      if F3 > 0 then
        v :=v+sin (InputBox.Tag * 2.0 * pi /F3);
      if lChannels > 1 then
        v := v / lChannels;
      //Timer1.tag := Timer1.tag+kSkip;
      	 AddSample (InChart, Timer1.tag, v);
      	 AddSample (OutChart, Timer1.tag, gRGJFilter.Process(v));

    end;//for each sample
   end; //if new samples
   gLastSample := lSample;
   InVis.Invalidate;
   OutVis.Invalidate;

end;

procedure TForm1.FormShow(Sender: TObject);
begin
   Form1.DoubleBuffered:= true;
  // FFTBox.caption := 'FFT (sample rate '+inttostr(kSamplesPerSec)+' Hz)';
  gRGJFilter := TRbjEqFilter.Create(kSamplesPerSec,0);
  FiltTypeDrop.ItemIndex := 0;
  UpdateFilter;
  Freq1Change(nil);
  ResetClock;
  Timer1.enabled := true;
  FiltTypeDropChange(nil);
end;

procedure TForm1.Freq1Change(Sender: TObject);
var
  lS: string;
begin
  if Freq1.position < 1 then
    F1 := 0
  else
    F1 := kSamplesPerSec/Freq1.position; //samples per cycle
  if Freq2.position < 1 then
    F2 := 0
  else
    F2 := kSamplesPerSec/Freq2.position; //samples per cycle
  if Freq3.position < 1 then
    F3 := 0
  else
    F3 := kSamplesPerSec/Freq3.position; //samples per cycle
  lS := 'Input Hz: ';
  if Freq1.position > 0 then
    lS := lS+' '+inttostr(Freq1.Position);
  if Freq2.position > 0 then
    lS := lS+' '+inttostr(Freq2.Position);
  if Freq3.position > 0 then
    lS := lS+' '+inttostr(Freq3.Position);
  InputBox.Caption := lS;
  DrawFFT;
end;

procedure TForm1.UpdateFilter;
var
  lHz: integer;
  lQ,lGain: double;
begin
  lHz := Hz.Position;
  lQ := Q.Position/100;
  lGain := Gain.Position/100;
  if FiltTypeDrop.ItemIndex >=  kPeaking then
    FilterBox.Caption := 'Hz: '+inttostr(lHz)+'  Q:'+floattostr(lQ)+' Gain:'+floattostr(lGain)
  else
    FilterBox.Caption := 'Hz: '+inttostr(lHz)+'  Q:'+floattostr(lQ);
  FilterBox.refresh;
   gRGJFilter.CalcFilterCoeffs(FiltTypeDrop.ItemIndex,lHz,lQ,lGain, QIsBandWidthCheck.Checked);
  DrawFFT;
end;

procedure TForm1.InChartPaint(Sender: TObject);
begin
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Application.ShowButtonGlyphs := sbgNever;
  FFTChart.Picture.Bitmap.Width:= FFTChart.Width;
  FFTChart.Picture.Bitmap.Height:= FFTChart.Height;
  InChart.Picture.Bitmap.Width:= InChart.Width;
  InChart.Picture.Bitmap.Height:= InChart.Height;
  OutChart.Picture.Bitmap.Width:= OutChart.Width;
  OutChart.Picture.Bitmap.Height:= OutChart.Height;
  InChart.Visible := false;
  OutChart.visible := false;
  InVis := TMyDrawingControl.Create(Self);
  InVis.Height := InChart.Height;
  InVis.Width := InChart.Width;
  //InVis.Tag := 0;
  InVis.Top := 0;
  InVis.Left := 0;
  InVis.Parent := Self;
  OutChart.Tag := 1;
  OutVis := TMyDrawingControl.Create(Self);
  OutVis.Height := OutChart.Height;
  OutVis.Width := OutChart.Width;
  OutVis.Top := OutChart.Top;
  OutVis.Tag := 1;
  OutVis.Left := 0;
  OutVis.Parent := Self;
  HzDrop.ItemIndex := 3;

end;

procedure TForm1.HzDropChange(Sender: TObject);
begin
  case HzDrop.ItemIndex of
  	   0: kSamplesPerSec := 32;
       1: kSamplesPerSec := 64;
  	   2: kSamplesPerSec := 128;
  	   else kSamplesPerSec := 256;
  end;
  case HzDrop.ItemIndex of
  	   0: kSkip := 7;
       1: kSkip := 3;
  	   2: kSkip := 1;
  	   else kSkip := 0;
  end;
  kSamplesPerMSec :=  kSamplesPerSec/1000;
  Freq1Change(nil);
end;

procedure TForm1.FiltTypeDropChange(Sender: TObject);
begin
  Gain.visible :=FiltTypeDrop.ItemIndex >=  kPeaking;
  GainLabel.Visible := Gain.visible;
  UpdateFilter;
end;

procedure TForm1.GainChange(Sender: TObject);
begin
  UpdateFilter;
end;

procedure TForm1.SpeedButton1Click(Sender: TObject);
begin
  Timer1.enabled := false;
  showmessage('This demonstrates signal processing using open source filters (RBJ Audio EQ Cookbook), and FFT (by Nils Haeck).');
  ResetClock;
  Timer1.Enabled := true;
end;

procedure TForm1.DisplayPanelResize(Sender: TObject);
begin
  InChart.Height := DisplayPanel.ClientHeight div 2;
  OutChart.Height := DisplayPanel.ClientHeight div 2;
end;

initialization
  {$i main.lrs}

end.
