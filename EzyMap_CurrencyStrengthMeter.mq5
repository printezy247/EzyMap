//+------------------------------------------------------------------+
//| EzyMap Currency Strength Meter                                    |
//| Live-updating panel: ranks USD/EUR/GBP/JPY/AUD/CAD/CHF by relative|
//| strength since the selected timeframe's current bar open.        |
//+------------------------------------------------------------------+
#property copyright "EzyMap"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

input int InpRefreshSeconds = 3;   // Live refresh interval (seconds)

input color  InpPanelColor       = C'7,10,14';
input color  InpPanelBorderColor = C'56,65,76';
input color  InpTextColor        = C'204,211,218';
input color  InpAccentColor      = C'237,185,58';
input color  InpSymBtnColor      = C'30,36,44';
input color  InpSymBtnBorder     = C'56,65,76';
input color  InpSymBtnTextColor  = C'204,211,218';
input color  InpSymBtnSelColor   = C'237,185,58';
input color  InpSymBtnSelText    = C'7,10,14';
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

#define PRODUCT_NAME "EzyMap Currency Strength Meter"
string PREFIX="EZCSM_";

int PX=14;
int PY=38;
int PW=310;
int PH=298;

string g_currencies[7] = {"USD","EUR","GBP","JPY","AUD","CAD","CHF"};

// Full 21-pair matrix across the 7 currencies (every combination once).
string g_forexPairs[21] =
{
   "EURUSD","GBPUSD","USDJPY","USDCHF","AUDUSD","USDCAD",
   "EURGBP","EURJPY","EURCHF","EURAUD","EURCAD",
   "GBPJPY","GBPCHF","GBPAUD","GBPCAD",
   "AUDJPY","AUDCHF","AUDCAD",
   "CADJPY","CADCHF","CHFJPY"
};

ENUM_TIMEFRAMES g_tfValues[4] = {PERIOD_M15,PERIOD_H1,PERIOD_H4,PERIOD_D1};
string g_tfLabels[4] = {"M15","H1","H4","D1"};
int g_tfIndex=1; // default H1

string g_tierLabels[7] = {"STRONG BULLISH","BULLISH","WEAK BULLISH","NEUTRAL","WEAK BEARISH","BEARISH","STRONG BEARISH"};

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
   ObjectSetInteger(0,n,OBJPROP_BORDER_COLOR,InpSymBtnBorder);
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

   MakeLabel("TITLE",26,48,"EZYMAP CURRENCY STRENGTH METER",InpAccentColor,10,true);
   MakeLabel("SUB",26,66,"Live rank-based bias, auto-refreshing",InpTextColor,8,false);

   for(int i=0;i<4;i++)
   {
      int w=62, gap=6;
      int x=26+i*(w+gap);
      MakeButton("BTN_TF_"+IntegerToString(i),x,82,w,24,g_tfLabels[i],InpSymBtnColor,InpSymBtnTextColor,9);
   }

   for(int i=0;i<7;i++)
      MakeLabel("ROW_"+IntegerToString(i),26,116+i*20," ",InpTextColor,9,false);

   MakeLabel("NOTE",26,264,"Loading...",InpTextColor,8,false);

   RefreshTfButtons();
}

void RefreshTfButtons()
{
   for(int i=0;i<4;i++)
   {
      string n=PREFIX+"BTN_TF_"+IntegerToString(i);
      bool sel=(i==g_tfIndex);
      ObjectSetInteger(0,n,OBJPROP_BGCOLOR,sel?InpSymBtnSelColor:InpSymBtnColor);
      ObjectSetInteger(0,n,OBJPROP_COLOR,sel?InpSymBtnSelText:InpSymBtnTextColor);
   }
}

//------------------------- Symbol resolution -------------------------
void CandidatesFor(string alias,string &out[])
{
   string a[]={alias};
   ArrayCopy(out,a);
}

string ScanSymbols(string &upperCandidates[],bool inMarketWatchOnly)
{
   int total=SymbolsTotal(inMarketWatchOnly);
   for(int i=0;i<total;i++)
   {
      string name=SymbolName(i,inMarketWatchOnly);
      string upperName=name; StringToUpper(upperName);
      for(int c=0;c<ArraySize(upperCandidates);c++)
         if(upperName==upperCandidates[c]) return name;
   }
   for(int i=0;i<total;i++)
   {
      string name=SymbolName(i,inMarketWatchOnly);
      string upperName=name; StringToUpper(upperName);
      for(int c=0;c<ArraySize(upperCandidates);c++)
         if(StringFind(upperName,upperCandidates[c])==0) return name;
   }
   return "";
}

string ResolveSymbol(string alias)
{
   string candidates[];
   CandidatesFor(alias,candidates);
   string upperCandidates[];
   ArrayResize(upperCandidates,ArraySize(candidates));
   for(int c=0;c<ArraySize(candidates);c++)
   {
      string u=candidates[c];
      StringToUpper(u);
      upperCandidates[c]=u;
   }

   string found=ScanSymbols(upperCandidates,true);
   if(found!="") return found;
   return ScanSymbols(upperCandidates,false);
}

int CurrencyIndex(string c)
{
   for(int i=0;i<7;i++)
      if(g_currencies[i]==c) return i;
   return -1;
}

//----------------------------- Calculation ---------------------------
// Strength of each currency = average % move (since the current bar's
// open on the chosen timeframe) across every pair it appears in, sign-
// corrected for base vs quote. Ranked 1-7 rather than judged against a
// fixed threshold, so labels stay meaningful across any timeframe.
bool ComputeStrength(ENUM_TIMEFRAMES tf,double &scores[])
{
   ArrayResize(scores,7);
   ArrayInitialize(scores,0.0);
   int count[7];
   ArrayInitialize(count,0);

   int resolved=0;
   for(int p=0;p<21;p++)
   {
      string key=g_forexPairs[p];
      string base=StringSubstr(key,0,3);
      string quote=StringSubstr(key,3,3);

      string symbol=ResolveSymbol(key);
      if(symbol=="" || !SymbolSelect(symbol,true))
         continue;

      double openArr[];
      if(CopyOpen(symbol,tf,0,1,openArr)<1)
         continue;
      double open=openArr[0];
      double bid=SymbolInfoDouble(symbol,SYMBOL_BID);
      if(open<=0.0 || bid<=0.0)
         continue;

      double ret=(bid-open)/open*100.0;
      int baseIdx=CurrencyIndex(base);
      int quoteIdx=CurrencyIndex(quote);
      if(baseIdx<0 || quoteIdx<0)
         continue;

      scores[baseIdx]+=ret;  count[baseIdx]++;
      scores[quoteIdx]-=ret; count[quoteIdx]++;
      resolved++;
   }

   if(resolved==0) return false;

   for(int i=0;i<7;i++)
      if(count[i]>0) scores[i]/=count[i];

   return true;
}

void RefreshPanel()
{
   ENUM_TIMEFRAMES tf=g_tfValues[g_tfIndex];
   double scores[];
   if(!ComputeStrength(tf,scores))
   {
      SetLabelText("NOTE","⚠ Could not resolve enough forex pairs - check Market Watch.",InpErrorColor);
      ChartRedraw(0);
      return;
   }

   int order[7];
   for(int i=0;i<7;i++) order[i]=i;
   for(int i=0;i<7;i++)
      for(int j=i+1;j<7;j++)
         if(scores[order[j]]>scores[order[i]])
         {
            int tmp=order[i]; order[i]=order[j]; order[j]=tmp;
         }

   color tierColors[7] =
   {
      InpStrongBullColor, InpBullColor, InpWeakBullColor, InpNeutralColor,
      InpWeakBearColor, InpBearColor, InpStrongBearColor
   };

   for(int rank=0;rank<7;rank++)
   {
      int idx=order[rank];
      string line=IntegerToString(rank+1)+". "+g_currencies[idx]+"   "+
                  (scores[idx]>=0.0?"+":"")+DoubleToString(scores[idx],3)+"%   "+g_tierLabels[rank];
      SetLabelText("ROW_"+IntegerToString(rank),line,tierColors[rank]);
   }

   string tm=TimeToString(TimeCurrent(),TIME_SECONDS);
   SetLabelText("NOTE",g_tfLabels[g_tfIndex]+" • since current bar open • updated "+tm,InpTextColor);
   ChartRedraw(0);
}

//--------------------------- MT5 events -----------------------------
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME,PRODUCT_NAME);
   g_tfIndex=1;
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
   if(id==CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam==PREFIX+"BTN_CLOSE")
      {
         ChartIndicatorDelete(0,0,PRODUCT_NAME);
         return;
      }

      for(int t=0;t<4;t++)
      {
         if(sparam==PREFIX+"BTN_TF_"+IntegerToString(t))
         {
            ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
            g_tfIndex=t;
            RefreshTfButtons();
            RefreshPanel();
            return;
         }
      }
   }
}

int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],const double &open[],const double &high[],const double &low[],const double &close[],const long &tick_volume[],const long &volume[],const int &spread[])
{
   return rates_total;
}
//+------------------------------------------------------------------+
