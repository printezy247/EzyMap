//+------------------------------------------------------------------+
//| EzyMap Higher-Timeframe S/R Snapshot                               |
//| Draws Daily/Weekly/Monthly classic pivot levels (PP, R1-R3,       |
//| S1-S3) and previous-period High/Low directly on the chart,        |
//| regardless of which timeframe you're currently viewing.           |
//+------------------------------------------------------------------+
#property copyright "EzyMap"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

#include <EzyMapLicense.mqh>
#define SCRIPT_ID "EzyMap_HTFSnapshot"

input bool InpShowDaily        = true;
input bool InpShowWeekly       = true;
input bool InpShowMonthly      = true;
input bool InpShowPivotPoint   = true;
input bool InpShowR1S1         = true;
input bool InpShowR2S2         = false;
input bool InpShowR3S3         = false;
input bool InpShowPrevHighLow  = true;
input bool InpShowLabels       = true;

input color InpPanelColor       = C'7,10,14';
input color InpPanelBorderColor = C'56,65,76';
input color InpTextColor        = C'204,211,218';
input color InpAccentColor      = C'237,185,58';
input color InpDailyColor       = C'52,211,176';
input color InpWeeklyColor      = C'237,185,58';
input color InpMonthlyColor     = C'186,130,224';
input color InpPrevHLColor      = C'150,160,200';
input color InpCloseBtnColor    = C'40,14,18';
input color InpCloseBtnTextColor= C'235,72,96';

#define PRODUCT_NAME "EzyMap HTF S/R Snapshot"
string PREFIX="EZHTF_";

int PX=14;
int PY=38;
int PW=280;
int PH=104;

//----------------------------- Helpers ------------------------------
void SetCommon(string n,bool back=false,int zorder=100)
{
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,false);
   ObjectSetInteger(0,n,OBJPROP_BACK,back);
   ObjectSetInteger(0,n,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,zorder);
}

void DeleteObj(string suffix) { ObjectDelete(0,PREFIX+suffix); }

void MakeRect(string suffix,int x,int y,int w,int h,color bg,color border,int zorder=100)
{
   string n=PREFIX+suffix;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,n,OBJPROP_BORDER_COLOR,border);
   ObjectSetInteger(0,n,OBJPROP_COLOR,border);
   ObjectSetInteger(0,n,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,n,OBJPROP_WIDTH,1);
   SetCommon(n,false,zorder);
}

void MakeLabel(string suffix,int x,int y,string text,color clr,int size=9,bool bold=false,int zorder=100)
{
   string n=PREFIX+suffix;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,size);
   ObjectSetString(0,n,OBJPROP_FONT,bold?"Arial Bold":"Arial");
   ObjectSetString(0,n,OBJPROP_TEXT,text);
   SetCommon(n,false,zorder);
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
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
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
   SetCommon(n,false,zorder);
}

string PriceText(double v)
{
   int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   return DoubleToString(v,digits);
}

void HLine(string suffix,double price,color clr,ENUM_LINE_STYLE style,int width)
{
   if(price<=0) { DeleteObj(suffix); return; }
   string n=PREFIX+suffix;
   if(ObjectFind(0,n)<0)
      ObjectCreate(0,n,OBJ_HLINE,0,0,price);
   ObjectSetDouble(0,n,OBJPROP_PRICE,price);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_STYLE,style);
   ObjectSetInteger(0,n,OBJPROP_WIDTH,width);
   SetCommon(n,true,40);
}

void LevelText(string suffix,datetime tm,double price,string text,color clr)
{
   if(!InpShowLabels || price<=0) { DeleteObj(suffix); return; }
   string n=PREFIX+suffix;
   if(ObjectFind(0,n)<0)
      ObjectCreate(0,n,OBJ_TEXT,0,tm,price);
   else
      ObjectMove(0,n,0,tm,price);
   ObjectSetString(0,n,OBJPROP_TEXT,text);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,7);
   ObjectSetInteger(0,n,OBJPROP_ANCHOR,ANCHOR_LEFT);
   ObjectSetString(0,n,OBJPROP_FONT,"Arial Bold");
   SetCommon(n,false,60);
}

//------------------------------ Build GUI ----------------------------
void BuildGUI()
{
   MakeRect("PANEL",PX,PY,PW,PH,InpPanelColor,InpPanelBorderColor,50);
   MakeButton("BTN_CLOSE",PX+PW-38,PY+6,30,26,"✕",InpCloseBtnColor,InpCloseBtnTextColor,11);

   MakeLabel("TITLE",26,48,"EZYMAP HTF S/R SNAPSHOT",InpAccentColor,10,true);
   MakeLabel("SUB",26,66,_Symbol+" • auto-refreshing",InpTextColor,8,false);
   MakeLabel("LEGEND",26,86,"■ D1   ■ W1   ■ MN1   ■ Prev H/L",InpTextColor,8,false);
}

//------------------------- Pivot calculation --------------------------
void ComputePivots(double h,double l,double c,double &pp,double &r1,double &s1,double &r2,double &s2,double &r3,double &s3)
{
   pp=(h+l+c)/3.0;
   r1=2.0*pp-l;
   s1=2.0*pp-h;
   r2=pp+(h-l);
   s2=pp-(h-l);
   r3=h+2.0*(pp-l);
   s3=l-2.0*(h-pp);
}

void DrawTF(string tag,ENUM_TIMEFRAMES tf,color clr,bool show,datetime labelTime)
{
   if(!show)
   {
      string suf[]={"PP","R1","S1","R2","S2","R3","S3","PH","PL"};
      for(int i=0;i<ArraySize(suf);i++)
      {
         DeleteObj(tag+"_"+suf[i]);
         DeleteObj("LBL_"+tag+"_"+suf[i]);
      }
      return;
   }

   MqlRates r[];
   ArraySetAsSeries(r,true);
   if(CopyRates(_Symbol,tf,1,1,r)<1)
      return;

   double h=r[0].high, l=r[0].low, c=r[0].close;
   double pp,r1,s1,r2,s2,r3,s3;
   ComputePivots(h,l,c,pp,r1,s1,r2,s2,r3,s3);

   if(InpShowPivotPoint)
   {
      HLine(tag+"_PP",pp,clr,STYLE_SOLID,1);
      LevelText("LBL_"+tag+"_PP",labelTime,pp,tag+" PP  "+PriceText(pp),clr);
   }
   else { DeleteObj(tag+"_PP"); DeleteObj("LBL_"+tag+"_PP"); }

   if(InpShowR1S1)
   {
      HLine(tag+"_R1",r1,clr,STYLE_DOT,1);
      LevelText("LBL_"+tag+"_R1",labelTime,r1,tag+" R1  "+PriceText(r1),clr);
      HLine(tag+"_S1",s1,clr,STYLE_DOT,1);
      LevelText("LBL_"+tag+"_S1",labelTime,s1,tag+" S1  "+PriceText(s1),clr);
   }
   else
   {
      DeleteObj(tag+"_R1"); DeleteObj("LBL_"+tag+"_R1");
      DeleteObj(tag+"_S1"); DeleteObj("LBL_"+tag+"_S1");
   }

   if(InpShowR2S2)
   {
      HLine(tag+"_R2",r2,clr,STYLE_DASH,1);
      LevelText("LBL_"+tag+"_R2",labelTime,r2,tag+" R2  "+PriceText(r2),clr);
      HLine(tag+"_S2",s2,clr,STYLE_DASH,1);
      LevelText("LBL_"+tag+"_S2",labelTime,s2,tag+" S2  "+PriceText(s2),clr);
   }
   else
   {
      DeleteObj(tag+"_R2"); DeleteObj("LBL_"+tag+"_R2");
      DeleteObj(tag+"_S2"); DeleteObj("LBL_"+tag+"_S2");
   }

   if(InpShowR3S3)
   {
      HLine(tag+"_R3",r3,clr,STYLE_DASHDOT,1);
      LevelText("LBL_"+tag+"_R3",labelTime,r3,tag+" R3  "+PriceText(r3),clr);
      HLine(tag+"_S3",s3,clr,STYLE_DASHDOT,1);
      LevelText("LBL_"+tag+"_S3",labelTime,s3,tag+" S3  "+PriceText(s3),clr);
   }
   else
   {
      DeleteObj(tag+"_R3"); DeleteObj("LBL_"+tag+"_R3");
      DeleteObj(tag+"_S3"); DeleteObj("LBL_"+tag+"_S3");
   }

   if(InpShowPrevHighLow)
   {
      HLine(tag+"_PH",h,InpPrevHLColor,STYLE_SOLID,1);
      LevelText("LBL_"+tag+"_PH",labelTime,h,"PREV "+tag+" HIGH  "+PriceText(h),InpPrevHLColor);
      HLine(tag+"_PL",l,InpPrevHLColor,STYLE_SOLID,1);
      LevelText("LBL_"+tag+"_PL",labelTime,l,"PREV "+tag+" LOW  "+PriceText(l),InpPrevHLColor);
   }
   else
   {
      DeleteObj(tag+"_PH"); DeleteObj("LBL_"+tag+"_PH");
      DeleteObj(tag+"_PL"); DeleteObj("LBL_"+tag+"_PL");
   }
}

void RefreshLevels()
{
   datetime labelTime=TimeCurrent()+PeriodSeconds(_Period)*8;
   DrawTF("D1",PERIOD_D1,InpDailyColor,InpShowDaily,labelTime);
   DrawTF("W1",PERIOD_W1,InpWeeklyColor,InpShowWeekly,labelTime);
   DrawTF("MN1",PERIOD_MN1,InpMonthlyColor,InpShowMonthly,labelTime);
   ChartRedraw(0);
}

//--------------------------- MT5 events -----------------------------
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME,PRODUCT_NAME);
   EventSetTimer(60);
   if(!EzyMapLicenseGate(SCRIPT_ID,PREFIX,PRODUCT_NAME))
   {
      ChartRedraw(0);
      return INIT_SUCCEEDED;
   }

   BuildGUI();
   RefreshLevels();
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
   EzyMapLicenseRecheck(SCRIPT_ID,PREFIX,PRODUCT_NAME);
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
   RefreshLevels();
   return rates_total;
}
//+------------------------------------------------------------------+
