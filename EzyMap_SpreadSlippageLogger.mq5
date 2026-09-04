//+------------------------------------------------------------------+
//| EzyMap Spread & Slippage Logger                                    |
//| Live panel: current spread for a watchlist of symbols (flags      |
//| abnormal widening vs a rolling average - useful before news),     |
//| plus recent execution slippage pulled from real trade history.   |
//+------------------------------------------------------------------+
#property copyright "EzyMap"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

#include <EzyMapLicense.mqh>
#define SCRIPT_ID "EzyMap_SpreadSlippageLogger"

input string InpWatchlist           = "";    // Extra symbols to watch, comma-separated (e.g. "GBPUSD,XAUUSD,BTCUSD"). Current chart symbol is always included.
input double InpHighSpreadMultiplier= 2.0;   // Flag spread as WIDE if >= this x its own rolling average
input int    InpSpreadAvgSamples    = 20;    // Rolling average sample count per symbol
input int    InpMaxSlippageRows     = 6;     // How many recent trades to show (max 8)
input int    InpHistoryLookbackDays = 7;     // How far back to scan trade history for slippage
input int    InpRefreshSeconds      = 2;

input color InpPanelColor       = C'7,10,14';
input color InpPanelBorderColor = C'56,65,76';
input color InpTextColor        = C'204,211,218';
input color InpAccentColor      = C'237,185,58';
input color InpNormalColor      = C'52,211,176';
input color InpWideColor        = C'235,72,96';
input color InpGoodSlipColor    = C'0,208,142';
input color InpBadSlipColor     = C'235,72,96';
input color InpErrorColor       = C'235,72,96';
input color InpCloseBtnColor    = C'40,14,18';
input color InpCloseBtnTextColor= C'235,72,96';

#define PRODUCT_NAME "EzyMap Spread & Slippage Logger"
string PREFIX="EZSSL_";

int PX=14;
int PY=38;
int PW=320;
int PH=374;

#define MAX_WATCH 8
#define MAX_SLIP_ROWS 8
#define AVG_BUF 64

string g_watchSymbols[MAX_WATCH];
int    g_watchCount=0;
double g_spreadBuf[MAX_WATCH][AVG_BUF];
int    g_spreadBufCount[MAX_WATCH];
int    g_spreadBufPos[MAX_WATCH];

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

string TrimBoth(string s)
{
   StringTrimLeft(s);
   StringTrimRight(s);
   return s;
}

//------------------------------ Symbol setup --------------------------
string ResolveWatchSymbol(string alias)
{
   string upper=alias;
   StringToUpper(upper);

   int total=SymbolsTotal(true);
   for(int i=0;i<total;i++)
   {
      string name=SymbolName(i,true);
      string un=name; StringToUpper(un);
      if(un==upper) return name;
   }
   for(int i=0;i<total;i++)
   {
      string name=SymbolName(i,true);
      string un=name; StringToUpper(un);
      if(StringFind(un,upper)==0) return name;
   }

   total=SymbolsTotal(false);
   for(int i=0;i<total;i++)
   {
      string name=SymbolName(i,false);
      string un=name; StringToUpper(un);
      if(un==upper) return name;
   }
   return "";
}

void BuildWatchlist()
{
   g_watchCount=0;
   g_watchSymbols[g_watchCount++]=_Symbol;

   string parts[];
   int n=StringSplit(InpWatchlist,',',parts);
   for(int i=0;i<n && g_watchCount<MAX_WATCH;i++)
   {
      string sym=TrimBoth(parts[i]);
      if(sym=="") continue;
      string resolved=ResolveWatchSymbol(sym);
      if(resolved=="") continue;
      if(!SymbolSelect(resolved,true)) continue;

      bool dup=false;
      for(int k=0;k<g_watchCount;k++)
         if(g_watchSymbols[k]==resolved) { dup=true; break; }
      if(dup) continue;

      g_watchSymbols[g_watchCount++]=resolved;
   }

   for(int i=0;i<MAX_WATCH;i++)
   {
      g_spreadBufCount[i]=0;
      g_spreadBufPos[i]=0;
   }
}

//------------------------------ Build GUI ----------------------------
void BuildGUI()
{
   MakeRect("PANEL",PX,PY,PW,PH,InpPanelColor,InpPanelBorderColor,50);
   MakeButton("BTN_CLOSE",PX+PW-38,PY+6,30,26,"✕",InpCloseBtnColor,InpCloseBtnTextColor,11);

   MakeLabel("TITLE",26,48,"EZYMAP SPREAD & SLIPPAGE LOGGER",InpAccentColor,10,true);
   MakeLabel("SUB",26,66,"Live spread watch + recent execution slippage",InpTextColor,8,false);

   MakeLabel("SPREAD_HEAD",26,84,"LIVE SPREAD WATCH",InpTextColor,9,true);
   for(int i=0;i<MAX_WATCH;i++)
      MakeLabel("SPREAD_"+IntegerToString(i),26,100+i*16," ",InpTextColor,8,false);

   MakeLabel("SLIP_HEAD",26,232,"RECENT EXECUTION SLIPPAGE",InpTextColor,9,true);
   for(int i=0;i<MAX_SLIP_ROWS;i++)
      MakeLabel("SLIP_"+IntegerToString(i),26,248+i*16," ",InpTextColor,8,false);

   MakeLabel("NOTE",26,356,"Ready.",InpTextColor,8,false);
}

//----------------------------- Spread tracking -------------------------
void SampleSpreads()
{
   for(int i=0;i<g_watchCount;i++)
   {
      double spread=(double)SymbolInfoInteger(g_watchSymbols[i],SYMBOL_SPREAD);
      int pos=g_spreadBufPos[i];
      g_spreadBuf[i][pos]=spread;
      g_spreadBufPos[i]=(pos+1)%AVG_BUF;
      if(g_spreadBufCount[i]<MathMin(AVG_BUF,InpSpreadAvgSamples))
         g_spreadBufCount[i]++;
   }
}

double AvgSpread(int i)
{
   int n=g_spreadBufCount[i];
   if(n==0) return 0.0;
   double sum=0.0;
   for(int k=0;k<n;k++) sum+=g_spreadBuf[i][k];
   return sum/n;
}

void RefreshSpreadRows()
{
   for(int i=0;i<MAX_WATCH;i++)
   {
      if(i>=g_watchCount) { SetLabelText("SPREAD_"+IntegerToString(i)," ",InpTextColor); continue; }

      double cur=(double)SymbolInfoInteger(g_watchSymbols[i],SYMBOL_SPREAD);
      double avg=AvgSpread(i);
      bool wide=(avg>0.0 && cur>=avg*InpHighSpreadMultiplier);

      string txt=g_watchSymbols[i]+"   "+DoubleToString(cur,0)+" pts";
      if(avg>0.0) txt+="  (avg "+DoubleToString(avg,0)+")";
      if(wide) txt+="  ⚠ WIDE";

      SetLabelText("SPREAD_"+IntegerToString(i),txt,wide?InpWideColor:InpNormalColor);
   }
}

//----------------------------- Slippage log ---------------------------
void RefreshSlippageRows()
{
   int maxRows=MathMin(InpMaxSlippageRows,MAX_SLIP_ROWS);

   datetime fromTime=TimeCurrent()-InpHistoryLookbackDays*86400;
   if(!HistorySelect(fromTime,TimeCurrent()))
   {
      SetLabelText("NOTE","⚠ Could not load trade history.",InpErrorColor);
      return;
   }

   int total=HistoryDealsTotal();
   int shown=0;

   for(int i=total-1;i>=0 && shown<maxRows;i--)
   {
      ulong dealTicket=HistoryDealGetTicket(i);
      if(dealTicket==0) continue;

      ENUM_DEAL_ENTRY entry=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket,DEAL_ENTRY);
      if(entry!=DEAL_ENTRY_IN) continue;

      ENUM_DEAL_TYPE dtype=(ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket,DEAL_TYPE);
      if(dtype!=DEAL_TYPE_BUY && dtype!=DEAL_TYPE_SELL) continue;

      string sym=HistoryDealGetString(dealTicket,DEAL_SYMBOL);
      double dealPrice=HistoryDealGetDouble(dealTicket,DEAL_PRICE);
      ulong orderTicket=HistoryDealGetInteger(dealTicket,DEAL_ORDER);

      if(!HistoryOrderSelect(orderTicket)) continue;
      double reqPrice=HistoryOrderGetDouble(orderTicket,ORDER_PRICE_OPEN);
      double point=SymbolInfoDouble(sym,SYMBOL_POINT);
      if(point<=0.0 || reqPrice<=0.0 || dealPrice<=0.0) continue;

      double slipPts=(dtype==DEAL_TYPE_BUY)?(dealPrice-reqPrice)/point:(reqPrice-dealPrice)/point;
      // slipPts > 0 = unfavorable (paid more on buy / received less on sell)

      string dirTxt=(dtype==DEAL_TYPE_BUY)?"BUY":"SELL";
      string txt=dirTxt+" "+sym+"   "+(slipPts>=0.0?"+":"")+DoubleToString(slipPts,1)+" pts";
      color clr=(slipPts>0.0)?InpBadSlipColor:((slipPts<0.0)?InpGoodSlipColor:InpTextColor);

      SetLabelText("SLIP_"+IntegerToString(shown),txt,clr);
      shown++;
   }

   for(int i=shown;i<MAX_SLIP_ROWS;i++)
      SetLabelText("SLIP_"+IntegerToString(i)," ",InpTextColor);

   if(shown==0)
      SetLabelText("NOTE","No recent market-entry trades found in the last "+IntegerToString(InpHistoryLookbackDays)+" day(s).",InpTextColor);
   else
      SetLabelText("NOTE","Updated "+TimeToString(TimeCurrent(),TIME_SECONDS)+" • positive = unfavorable slippage",InpTextColor);
}

void RefreshAll()
{
   SampleSpreads();
   RefreshSpreadRows();
   RefreshSlippageRows();
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

   BuildWatchlist();
   BuildGUI();
   RefreshAll();
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
   RefreshAll();
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
