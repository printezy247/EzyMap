//+------------------------------------------------------------------+
//| EzyMap Session Overlap & Volatility Clock                         |
//| Live panel: which of Sydney/Tokyo/London/New York are open right |
//| now (GMT-based), overlap windows, and average H1 range per       |
//| session over a lookback window for the current chart symbol.     |
//+------------------------------------------------------------------+
#property copyright "EzyMap"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

input int InpRefreshSeconds = 5;    // Live refresh interval (seconds)
input int InpLookbackDays   = 10;   // Days of H1 history used for average range

input color  InpPanelColor       = C'7,10,14';
input color  InpPanelBorderColor = C'56,65,76';
input color  InpTextColor        = C'204,211,218';
input color  InpAccentColor      = C'237,185,58';
input color  InpOpenColor        = C'0,208,142';
input color  InpClosedColor      = C'126,137,150';
input color  InpOverlapColor     = C'235,72,96';
input color  InpErrorColor       = C'235,72,96';
input color  InpCloseBtnColor    = C'40,14,18';
input color  InpCloseBtnTextColor= C'235,72,96';

#define PRODUCT_NAME "EzyMap Session Clock"
string PREFIX="EZSESS_";

int PX=14;
int PY=38;
int PW=310;
int PH=340;

string g_sessionNames[4] = {"SYDNEY","TOKYO","LONDON","NEW YORK"};
// Standard UTC session windows (approximate, ignores DST shifts).
int g_sessionStartHour[4] = {22,0,8,13};
int g_sessionEndHour[4]   = {7,9,17,22};

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

double PipSize()
{
   string s=_Symbol; StringToUpper(s);
   bool isGold=(StringFind(s,"XAU")>=0 || StringFind(s,"GOLD")>=0);
   bool isBTC =(StringFind(s,"BTC")>=0 || StringFind(s,"XBT")>=0);
   if(isGold) return MathMax(0.10,_Point);
   if(isBTC)  return MathMax(1.0,_Point);
   return _Point;
}

//------------------------------ Build GUI ----------------------------
void BuildGUI()
{
   MakeRect("PANEL",PX,PY,PW,PH,InpPanelColor,InpPanelBorderColor,50);

   // Small corner close button - re-open by double-clicking the indicator
   // in Navigator, no need for it to take a full row.
   MakeButton("BTN_CLOSE",PX+PW-38,PY+6,30,26,"✕",InpCloseBtnColor,InpCloseBtnTextColor,11);

   MakeLabel("TITLE",26,48,"EZYMAP SESSION & VOLATILITY CLOCK",InpAccentColor,10,true);
   MakeLabel("SUB",26,66,_Symbol+" • GMT-based sessions, live",InpTextColor,8,false);

   MakeLabel("GMT_TIME",26,86,"Loading...",InpTextColor,9,true);

   MakeLabel("SESS_HEAD",26,108,"SESSIONS",InpTextColor,9,true);
   for(int i=0;i<4;i++)
      MakeLabel("SESS_"+IntegerToString(i),26,124+i*18," ",InpTextColor,9,false);

   MakeLabel("OVERLAP",26,200,"Loading...",InpAccentColor,9,false);

   MakeLabel("AVG_HEAD",26,222,"AVG H1 RANGE (last "+IntegerToString(InpLookbackDays)+" days)",InpTextColor,9,true);
   for(int i=0;i<4;i++)
      MakeLabel("AVG_"+IntegerToString(i),26,238+i*18," ",InpTextColor,9,false);

   MakeLabel("NOTE",26,314,"Loading...",InpTextColor,8,false);
}

//----------------------------- Calculation ---------------------------
bool InSession(int hour,int idx)
{
   int startH=g_sessionStartHour[idx], endH=g_sessionEndHour[idx];
   if(startH<endH) return (hour>=startH && hour<endH);
   return (hour>=startH || hour<endH); // wraps midnight (Sydney)
}

void RefreshPanel()
{
   datetime nowServer=TimeCurrent();
   datetime nowGmt=TimeGMT();
   int gmtOffsetSec=(int)(nowGmt-nowServer);

   MqlDateTime gmtStruct;
   TimeToStruct(nowGmt,gmtStruct);
   int nowHour=gmtStruct.hour;

   string dayNames[7] = {"Sun","Mon","Tue","Wed","Thu","Fri","Sat"};
   SetLabelText("GMT_TIME","GMT TIME  "+StringFormat("%02d:%02d:%02d",gmtStruct.hour,gmtStruct.min,gmtStruct.sec)+"  ("+dayNames[gmtStruct.day_of_week]+")",InpTextColor);

   bool isOpen[4];
   int openCount=0;
   for(int i=0;i<4;i++)
   {
      isOpen[i]=InSession(nowHour,i);
      if(isOpen[i]) openCount++;
      string txt=g_sessionNames[i]+"   "+(isOpen[i]?"OPEN":"closed")+
                 "   ("+StringFormat("%02d",g_sessionStartHour[i])+":00-"+StringFormat("%02d",g_sessionEndHour[i])+":00 GMT)";
      SetLabelText("SESS_"+IntegerToString(i),txt,isOpen[i]?InpOpenColor:InpClosedColor);
   }

   string overlapTxt="No major overlap right now.";
   color overlapClr=InpTextColor;
   if(isOpen[2] && isOpen[3])       { overlapTxt="🔥 LONDON-NEW YORK OVERLAP - highest liquidity window."; overlapClr=InpOverlapColor; }
   else if(isOpen[0] && isOpen[1])  { overlapTxt="SYDNEY-TOKYO OVERLAP active."; overlapClr=InpOverlapColor; }
   else if(isOpen[1] && isOpen[2])  { overlapTxt="TOKYO-LONDON OVERLAP active."; overlapClr=InpOverlapColor; }
   else if(openCount==0)            { overlapTxt="All major sessions closed - lowest liquidity window."; overlapClr=InpClosedColor; }
   SetLabelText("OVERLAP",overlapTxt,overlapClr);

   // Average completed-session H1 range per session over the lookback window.
   double pip=PipSize();
   double sumRange[4]; int count[4];
   ArrayInitialize(sumRange,0.0);
   ArrayInitialize(count,0);
   bool inSess[4]; double curHigh[4], curLow[4];
   ArrayInitialize(inSess,false);
   ArrayInitialize(curHigh,0.0);
   ArrayInitialize(curLow,0.0);

   MqlRates r[];
   ArraySetAsSeries(r,false);
   int requestBars=MathMax(60,InpLookbackDays*30);
   int got=CopyRates(_Symbol,PERIOD_H1,0,requestBars,r);

   if(got>=24)
   {
      for(int b=0;b<got;b++)
      {
         datetime barGmt=r[b].time+gmtOffsetSec;
         MqlDateTime bs;
         TimeToStruct(barGmt,bs);
         int h=bs.hour;

         for(int s=0;s<4;s++)
         {
            bool nowIn=InSession(h,s);
            if(nowIn && !inSess[s])
            {
               inSess[s]=true; curHigh[s]=r[b].high; curLow[s]=r[b].low;
            }
            else if(nowIn && inSess[s])
            {
               curHigh[s]=MathMax(curHigh[s],r[b].high);
               curLow[s]=MathMin(curLow[s],r[b].low);
            }
            else if(!nowIn && inSess[s])
            {
               sumRange[s]+=(curHigh[s]-curLow[s]);
               count[s]++;
               inSess[s]=false;
            }
         }
      }

      for(int s=0;s<4;s++)
      {
         if(count[s]>0)
         {
            double avgPips=(sumRange[s]/count[s])/pip;
            SetLabelText("AVG_"+IntegerToString(s),g_sessionNames[s]+"   "+DoubleToString(avgPips,0)+" pts  ("+IntegerToString(count[s])+" sessions)",InpTextColor);
         }
         else
         {
            SetLabelText("AVG_"+IntegerToString(s),g_sessionNames[s]+"   not enough history yet",InpClosedColor);
         }
      }
      SetLabelText("NOTE",_Symbol+" • H1 data • updated "+TimeToString(nowServer,TIME_SECONDS),InpTextColor);
   }
   else
   {
      for(int s=0;s<4;s++)
         SetLabelText("AVG_"+IntegerToString(s),g_sessionNames[s]+"   waiting for history...",InpClosedColor);
      SetLabelText("NOTE","⚠ Not enough H1 history loaded yet for "+_Symbol+".",InpErrorColor);
   }

   ChartRedraw(0);
}

//--------------------------- MT5 events -----------------------------
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME,PRODUCT_NAME);
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
   RefreshPanel();
}

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
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
