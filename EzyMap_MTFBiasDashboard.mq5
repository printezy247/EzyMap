//+------------------------------------------------------------------+
//| EzyMap Multi-Timeframe Bias Dashboard                             |
//| Live-updating panel: bias for the current chart's symbol across   |
//| M1 -> W1, using EMA slope + ATR-normalized distance, ranked into  |
//| Strong Bullish .. Strong Bearish tiers.                           |
//+------------------------------------------------------------------+
#property copyright "EzyMap"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

#include <EzyMapLicense.mqh>
#define SCRIPT_ID "EzyMap_MTFBiasDashboard"

input int    InpRefreshSeconds  = 5;     // Live refresh interval (seconds)
input int    InpEmaPeriod       = 13;    // EMA period used for bias
input int    InpAtrPeriod       = 14;    // ATR period used for normalization
input double InpSlopeWeight     = 3.0;   // Weight applied to EMA slope vs price distance
input double InpStrongThreshold = 1.5;   // |composite| >= this -> STRONG tier
input double InpModThreshold    = 0.6;   // |composite| >= this -> plain BULLISH/BEARISH tier
input double InpWeakThreshold   = 0.15;  // |composite| >= this -> WEAK tier, below -> NEUTRAL

input color  InpPanelColor       = C'7,10,14';
input color  InpPanelBorderColor = C'56,65,76';
input color  InpTextColor        = C'204,211,218';
input color  InpAccentColor      = C'237,185,58';
input color  InpStrongBullColor  = C'0,208,142';
input color  InpBullColor        = C'52,211,176';
input color  InpWeakBullColor    = C'126,199,178';
input color  InpNeutralColor     = C'204,211,218';
input color  InpWeakBearColor    = C'229,166,150';
input color  InpBearColor        = C'235,130,110';
input color  InpStrongBearColor  = C'235,72,96';
input color  InpErrorColor       = C'235,72,96';
input color  InpCloseBtnColor    = C'40,14,18';
input color  InpCloseBtnTextColor= C'235,72,96';

#define PRODUCT_NAME "EzyMap MTF Bias Dashboard"
string PREFIX="EZMTF_";

int PX=14;
int PY=38;
int PW=310;
int PH=308;

ENUM_TIMEFRAMES g_tfs[8] = {PERIOD_M1,PERIOD_M5,PERIOD_M15,PERIOD_M30,PERIOD_H1,PERIOD_H4,PERIOD_D1,PERIOD_W1};
string g_tfLabels[8] = {"M1","M5","M15","M30","H1","H4","D1","W1"};

//----------------------------- Helpers ------------------------------
void SetCommon(string n,int zorder=100)
{
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,false);
   ObjectSetInteger(0,n,OBJPROP_BACK,false);
   ObjectSetInteger(0,n,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,zorder);
}

void MakeRect(string suffix,int x,int y,int w,int h,color bg,color border,int zorder=100)
{
   string n=PREFIX+suffix;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,n,OBJPROP_BORDER_COLOR,border);
   ObjectSetInteger(0,n,OBJPROP_COLOR,border);
   ObjectSetInteger(0,n,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,n,OBJPROP_WIDTH,1);
   SetCommon(n,zorder);
}

void MakeLabel(string suffix,int x,int y,string text,color clr,int size=9,bool bold=false,int zorder=100)
{
   string n=PREFIX+suffix;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,size);
   ObjectSetString(0,n,OBJPROP_FONT,bold?"Arial Bold":"Arial");
   ObjectSetString(0,n,OBJPROP_TEXT,text);
   SetCommon(n,zorder);
}

void SetLabelText(string suffix,string text,color clr)
{
   string n=PREFIX+suffix;
   if(ObjectFind(0,n)<0) return;
   ObjectSetString(0,n,OBJPROP_TEXT,text);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
}

void MakeButton(string suffix,int x,int y,int w,int h,string text,color bg,color txt,int size=9,int zorder=100)
{
   string n=PREFIX+suffix;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,n,OBJPROP_COLOR,txt);
   ObjectSetInteger(0,n,OBJPROP_BORDER_COLOR,InpPanelBorderColor);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,size);
   ObjectSetString(0,n,OBJPROP_FONT,"Arial Bold");
   ObjectSetString(0,n,OBJPROP_TEXT,text);
   ObjectSetInteger(0,n,OBJPROP_STATE,false);
   SetCommon(n,zorder);
}

//------------------------------ Build GUI ----------------------------
void BuildGUI()
{
   MakeRect("PANEL",PX,PY,PW,PH,InpPanelColor,InpPanelBorderColor,50);

   // Small corner close button - re-open by double-clicking the indicator
   // in Navigator, no need for it to take a full row.
   MakeButton("BTN_CLOSE",PX+PW-38,PY+6,30,26,"✕",InpCloseBtnColor,InpCloseBtnTextColor,11);

   MakeLabel("TITLE",26,48,"EZYMAP MTF BIAS DASHBOARD",InpAccentColor,10,true);
   MakeLabel("SUB",26,66,_Symbol+" • live, auto-refreshing",InpTextColor,8,false);

   MakeLabel("CONFLUENCE",26,86,"Loading...",InpTextColor,9,true);

   for(int i=0;i<8;i++)
      MakeLabel("ROW_"+IntegerToString(i),26,108+i*20," ",InpTextColor,9,false);

   MakeLabel("NOTE",26,268,"Loading...",InpTextColor,8,false);
}

//----------------------------- Calculation ---------------------------
double EMAFromRates(MqlRates &r[],int total,int period,int shift)
{
   if(total<=period+shift+5) return EMPTY_VALUE;
   int oldest=total-1;
   double alpha=2.0/(period+1.0);
   double ema=r[oldest].close;
   for(int i=oldest-1;i>=shift;i--)
      ema=alpha*r[i].close+(1.0-alpha)*ema;
   return ema;
}

double ATRFromRates(MqlRates &r[],int total,int period,int shift)
{
   if(total<=period+shift+5) return EMPTY_VALUE;
   int oldest=total-2;
   double atr=0.0;
   int seedCount=0;
   for(int i=oldest;i>=MathMax(shift,oldest-period+1);i--)
   {
      double prev=r[i+1].close;
      double tr=MathMax(r[i].high-r[i].low,MathMax(MathAbs(r[i].high-prev),MathAbs(r[i].low-prev)));
      atr+=tr; seedCount++;
   }
   if(seedCount==0) return EMPTY_VALUE;
   atr/=seedCount;
   for(int i=oldest-period;i>=shift;i--)
   {
      if(i+1>=total) continue;
      double prev=r[i+1].close;
      double tr=MathMax(r[i].high-r[i].low,MathMax(MathAbs(r[i].high-prev),MathAbs(r[i].low-prev)));
      atr=(atr*(period-1)+tr)/period;
   }
   return atr;
}

bool ComputeTFBias(ENUM_TIMEFRAMES tf,double &composite)
{
   MqlRates r[];
   ArraySetAsSeries(r,true);
   int got=CopyRates(_Symbol,tf,0,80,r);
   if(got<InpEmaPeriod+InpAtrPeriod+10) return false;

   double emaNow =EMAFromRates(r,got,InpEmaPeriod,1);
   double emaPrev=EMAFromRates(r,got,InpEmaPeriod,2);
   double atr    =ATRFromRates(r,got,InpAtrPeriod,1);
   if(emaNow==EMPTY_VALUE || emaPrev==EMPTY_VALUE || atr==EMPTY_VALUE || atr<=0.0)
      return false;

   double close=r[1].close;
   double distScore =(close-emaNow)/atr;
   double slopeScore=(emaNow-emaPrev)/atr*InpSlopeWeight;
   composite=distScore+slopeScore;
   return true;
}

string TierLabel(double composite,color &clr)
{
   double a=MathAbs(composite);
   if(composite>=InpStrongThreshold)      { clr=InpStrongBullColor; return "STRONG BULLISH"; }
   if(composite>=InpModThreshold)         { clr=InpBullColor;       return "BULLISH"; }
   if(composite>=InpWeakThreshold)        { clr=InpWeakBullColor;   return "WEAK BULLISH"; }
   if(a<InpWeakThreshold)                 { clr=InpNeutralColor;    return "NEUTRAL"; }
   if(composite>-InpModThreshold)         { clr=InpWeakBearColor;   return "WEAK BEARISH"; }
   if(composite>-InpStrongThreshold)      { clr=InpBearColor;       return "BEARISH"; }
   clr=InpStrongBearColor; return "STRONG BEARISH";
}

void RefreshPanel()
{
   int bullCount=0, bearCount=0, neutralCount=0, resolvedCount=0;

   for(int i=0;i<8;i++)
   {
      double composite=0.0;
      if(!ComputeTFBias(g_tfs[i],composite))
      {
         SetLabelText("ROW_"+IntegerToString(i),g_tfLabels[i]+"   insufficient history",InpErrorColor);
         continue;
      }

      color clr;
      string tier=TierLabel(composite,clr);
      string line=g_tfLabels[i]+"   "+tier+"   ("+(composite>=0.0?"+":"")+DoubleToString(composite,2)+")";
      SetLabelText("ROW_"+IntegerToString(i),line,clr);

      resolvedCount++;
      if(StringFind(tier,"BULLISH")>=0) bullCount++;
      else if(StringFind(tier,"BEARISH")>=0) bearCount++;
      else neutralCount++;
   }

   if(resolvedCount==0)
   {
      SetLabelText("CONFLUENCE","⚠ Not enough history loaded yet - try again shortly.",InpErrorColor);
   }
   else
   {
      string summary;
      color summaryColor=InpNeutralColor;
      if(bullCount>bearCount && bullCount>=resolvedCount/2+1)
      {
         summary="CONFLUENCE: "+IntegerToString(bullCount)+"/"+IntegerToString(resolvedCount)+" TFs BULLISH - trend aligned up";
         summaryColor=InpBullColor;
      }
      else if(bearCount>bullCount && bearCount>=resolvedCount/2+1)
      {
         summary="CONFLUENCE: "+IntegerToString(bearCount)+"/"+IntegerToString(resolvedCount)+" TFs BEARISH - trend aligned down";
         summaryColor=InpBearColor;
      }
      else
      {
         summary="CONFLUENCE: mixed ("+IntegerToString(bullCount)+" bull / "+IntegerToString(bearCount)+" bear / "+IntegerToString(neutralCount)+" neutral)";
         summaryColor=InpNeutralColor;
      }
      SetLabelText("CONFLUENCE",summary,summaryColor);
   }

   string tm=TimeToString(TimeCurrent(),TIME_SECONDS);
   SetLabelText("NOTE",_Symbol+" • EMA"+IntegerToString(InpEmaPeriod)+"/ATR"+IntegerToString(InpAtrPeriod)+" • updated "+tm,InpTextColor);
   ChartRedraw(0);
}

//--------------------------- MT5 events -----------------------------
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME,PRODUCT_NAME);
   if(!EzyMapLicenseGate(SCRIPT_ID,PREFIX,PRODUCT_NAME))
   {
      EventSetTimer(MathMax(1,InpRefreshSeconds));
      ChartRedraw(0);
      return INIT_SUCCEEDED;
   }

   BuildGUI();
   RefreshPanel();
   EventSetTimer(MathMax(1,InpRefreshSeconds));
   ChartRedraw(0);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0,PREFIX);
   ChartRedraw(0);
}

void OnTimer()
{
   if(!EzyMapLicenseRecheck(SCRIPT_ID,PREFIX,PRODUCT_NAME)) return;
   RefreshPanel();
}

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id==CHARTEVENT_OBJECT_CLICK && EzyMapIsLicenseCloseClick(PREFIX,sparam))
   {
      ChartIndicatorDelete(0,0,PRODUCT_NAME);
      return;
   }
   if(id==CHARTEVENT_OBJECT_CLICK && sparam==PREFIX+"BTN_CLOSE")
   {
      ChartIndicatorDelete(0,0,PRODUCT_NAME);
      return;
   }
}

int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],const double &open[],const double &high[],const double &low[],const double &close[],const long &tick_volume[],const long &volume[],const int &spread[])
{
   return rates_total;
}
//+------------------------------------------------------------------+
