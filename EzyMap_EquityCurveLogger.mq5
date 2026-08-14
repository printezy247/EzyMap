//+------------------------------------------------------------------+
//| EzyMap Equity Curve Logger                                         |
//| Appends a timestamped Balance/Equity/Margin snapshot to a single  |
//| running CSV file every N minutes, for charting the account's     |
//| equity curve externally in Excel/Google Sheets over time.        |
//+------------------------------------------------------------------+
#property copyright "EzyMap"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

#include <EzyMapLicense.mqh>
#define SCRIPT_ID "EzyMap_EquityCurveLogger"

input int    InpLogIntervalMinutes = 15;    // How often to append a snapshot row
input string InpFileNamePrefix     = "EzyMap_EquityCurve";

input color InpPanelColor       = C'7,10,14';
input color InpPanelBorderColor = C'56,65,76';
input color InpTextColor        = C'204,211,218';
input color InpAccentColor      = C'237,185,58';
input color InpUpColor          = C'0,208,142';
input color InpDownColor        = C'235,72,96';
input color InpButtonColor      = C'0,208,142';
input color InpButtonTextColor  = C'7,10,14';
input color InpErrorColor       = C'235,72,96';
input color InpCloseBtnColor    = C'40,14,18';
input color InpCloseBtnTextColor= C'235,72,96';

#define PRODUCT_NAME "EzyMap Equity Curve Logger"
string PREFIX="EZEQ_";

int PX=14;
int PY=38;
int PW=320;
int PH=298;

string   g_fileName="";
datetime g_lastLogTime=0;
int      g_rowsLoggedSession=0;
double   g_startEquity=0.0;
double   g_sessionHigh=0.0;
double   g_sessionLow=0.0;

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
   MakeButton("BTN_CLOSE",PX+PW-38,PY+6,30,26,"✕",InpCloseBtnColor,InpCloseBtnTextColor,11);

   MakeLabel("TITLE",26,48,"EZYMAP EQUITY CURVE LOGGER",InpAccentColor,10,true);
   MakeLabel("SUB",26,66,"Appends a snapshot every "+IntegerToString(InpLogIntervalMinutes)+" min to CSV",InpTextColor,8,false);

   MakeLabel("EQUITY",26,86," ",InpTextColor,9,false);
   MakeLabel("SESSION",26,104," ",InpTextColor,8,false);
   MakeLabel("CHANGE",26,122," ",InpTextColor,9,false);
   MakeLabel("FLOATING",26,140," ",InpTextColor,8,false);
   MakeLabel("LASTLOG",26,164," ",InpTextColor,8,false);
   MakeLabel("NEXTLOG",26,182," ",InpTextColor,8,false);

   MakeButton("BTN_LOG_NOW",26,206,280,28,"LOG SNAPSHOT NOW",InpButtonColor,InpButtonTextColor,10);

   MakeLabel("FILEINFO",26,244," ",InpTextColor,8,false);
   MakeLabel("NOTE",26,262,"Ready.",InpTextColor,8,false);
}

//----------------------------- Logging ---------------------------------
void EnsureFileHeader()
{
   if(FileIsExist(g_fileName)) return;

   int fh=FileOpen(g_fileName,FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(fh==INVALID_HANDLE) return;
   FileWrite(fh,"Timestamp","Balance","Equity","Margin","FreeMargin","MarginLevelPct","FloatingPL","OpenPositions");
   FileClose(fh);
}

bool AppendSnapshot()
{
   int fh=FileOpen(g_fileName,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(fh==INVALID_HANDLE) return false;

   FileSeek(fh,0,SEEK_END);

   double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   double margin=AccountInfoDouble(ACCOUNT_MARGIN);
   double freeMargin=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double marginLevel=AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   double floatingPL=equity-balance;
   int openPositions=PositionsTotal();

   FileWrite(fh,
      TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),
      DoubleToString(balance,2),
      DoubleToString(equity,2),
      DoubleToString(margin,2),
      DoubleToString(freeMargin,2),
      DoubleToString(marginLevel,2),
      DoubleToString(floatingPL,2),
      IntegerToString(openPositions)
   );
   FileClose(fh);
   return true;
}

void LogSnapshot(bool manual)
{
   if(AppendSnapshot())
   {
      g_lastLogTime=TimeCurrent();
      g_rowsLoggedSession++;
      SetLabelText("NOTE",(manual?"Manual snapshot logged at ":"Auto-logged at ")+TimeToString(TimeCurrent(),TIME_SECONDS)+".",InpAccentColor);
   }
   else
   {
      SetLabelText("NOTE","⚠ Could not write to "+g_fileName+" - error #"+IntegerToString(GetLastError()),InpErrorColor);
   }
}

//----------------------------- Live stats ------------------------------
void RefreshPanel()
{
   double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   double floatingPL=equity-balance;
   string cur=AccountInfoString(ACCOUNT_CURRENCY);

   if(equity>g_sessionHigh) g_sessionHigh=equity;
   if(equity<g_sessionLow)  g_sessionLow=equity;

   double netChange=equity-g_startEquity;
   double netChangePct=(g_startEquity>0.0)?netChange/g_startEquity*100.0:0.0;

   SetLabelText("EQUITY","Equity: "+DoubleToString(equity,2)+" "+cur+"   Balance: "+DoubleToString(balance,2)+" "+cur,InpTextColor);
   SetLabelText("SESSION","Session High/Low: "+DoubleToString(g_sessionHigh,2)+" / "+DoubleToString(g_sessionLow,2),InpTextColor);
   SetLabelText("CHANGE","Net change (session): "+(netChange>=0.0?"+":"")+DoubleToString(netChange,2)+" ("+(netChangePct>=0.0?"+":"")+DoubleToString(netChangePct,2)+"%)",netChange>=0.0?InpUpColor:InpDownColor);
   SetLabelText("FLOATING","Floating P/L: "+(floatingPL>=0.0?"+":"")+DoubleToString(floatingPL,2)+"   Open positions: "+IntegerToString(PositionsTotal()),InpTextColor);

   int secsSinceLog=(g_lastLogTime>0)?(int)(TimeCurrent()-g_lastLogTime):-1;
   SetLabelText("LASTLOG",(g_lastLogTime>0)?("Last logged: "+TimeToString(g_lastLogTime,TIME_SECONDS)):"Last logged: never yet",InpTextColor);

   int intervalSecs=MathMax(1,InpLogIntervalMinutes)*60;
   int nextIn=(g_lastLogTime>0)?MathMax(0,intervalSecs-secsSinceLog):0;
   SetLabelText("NEXTLOG","Next auto-log in: "+IntegerToString(nextIn)+"s   •   "+IntegerToString(g_rowsLoggedSession)+" row(s) logged this session",InpTextColor);

   SetLabelText("FILEINFO","File: "+g_fileName+"  (MQL5\\Files)",InpTextColor);

   if(g_lastLogTime==0 || (TimeCurrent()-g_lastLogTime)>=intervalSecs)
      LogSnapshot(false);

   ChartRedraw(0);
}

//--------------------------- MT5 events -----------------------------
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME,PRODUCT_NAME);
   if(!EzyMapLicenseGate(SCRIPT_ID,PREFIX,PRODUCT_NAME))
   {
      EventSetTimer(1);
      ChartRedraw(0);
      return INIT_SUCCEEDED;
   }

   g_fileName=InpFileNamePrefix+"_"+IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN))+".csv";
   EnsureFileHeader();

   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   g_startEquity=eq;
   g_sessionHigh=eq;
   g_sessionLow=eq;
   g_lastLogTime=0;
   g_rowsLoggedSession=0;

   BuildGUI();
   RefreshPanel();
   EventSetTimer(1);
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
   if(id!=CHARTEVENT_OBJECT_CLICK) return;

   if(EzyMapIsLicenseCloseClick(PREFIX,sparam))
   {
      ChartIndicatorDelete(0,0,PRODUCT_NAME);
      return;
   }

   if(sparam==PREFIX+"BTN_CLOSE")
   {
      ChartIndicatorDelete(0,0,PRODUCT_NAME);
      return;
   }
   if(sparam==PREFIX+"BTN_LOG_NOW")
   {
      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      LogSnapshot(true);
      ChartRedraw(0);
      return;
   }
}

int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],const double &open[],const double &high[],const double &low[],const double &close[],const long &tick_volume[],const long &volume[],const int &spread[])
{
   return rates_total;
}
//+------------------------------------------------------------------+
