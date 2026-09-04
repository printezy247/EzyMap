//+------------------------------------------------------------------+
//| EzyMap Correlation-Adjusted Position Sizer                        |
//| On-chart GUI: pick Pair A + Pair B, a timeframe, Capital and Base |
//| Risk %, click CALCULATE - get their correlation and an adjusted   |
//| risk-per-pair so two correlated trades don't stack full risk.     |
//+------------------------------------------------------------------+
#property copyright "EzyMap"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

#include <EzyMapLicense.mqh>
#define SCRIPT_ID "EzyMap_CorrelationSizer"

input int InpLookbackBars = 60;   // Bars used for the correlation window

input color  InpPanelColor       = C'7,10,14';
input color  InpPanelBorderColor = C'56,65,76';
input color  InpTextColor        = C'204,211,218';
input color  InpAccentColor      = C'237,185,58';
input color  InpEditBgColor      = C'20,24,30';
input color  InpEditTextColor    = C'255,255,255';
input color  InpButtonColor      = C'0,208,142';
input color  InpButtonTextColor  = C'7,10,14';
input color  InpSymBtnColor      = C'30,36,44';
input color  InpSymBtnBorder     = C'56,65,76';
input color  InpSymBtnTextColor  = C'204,211,218';
input color  InpSymBtnSelColor   = C'237,185,58';
input color  InpSymBtnSelText    = C'7,10,14';
input color  InpStrongColor      = C'235,72,96';
input color  InpModColor         = C'237,185,58';
input color  InpWeakColor        = C'52,211,176';
input color  InpErrorColor       = C'235,72,96';
input color  InpCloseBtnColor    = C'40,14,18';
input color  InpCloseBtnTextColor= C'235,72,96';

#define PRODUCT_NAME "EzyMap Correlation Sizer"
string PREFIX="EZCORR_";

int PX=14;
int PY=38;
int PW=332;
int PH=500;

#define PAIR_COUNT 26
string g_aliasKeys[PAIR_COUNT] =
{
   "EURUSD","GBPUSD","USDJPY","USDCHF","AUDUSD","USDCAD",
   "EURGBP","EURJPY","EURCHF","EURAUD","EURCAD",
   "GBPJPY","GBPCHF","GBPAUD","GBPCAD",
   "AUDJPY","AUDCHF","AUDCAD",
   "CADJPY","CADCHF","CHFJPY",
   "XAUUSD","XAGUSD","OIL","US30","BTCUSD"
};
string g_aliasLabels[PAIR_COUNT] =
{
   "EUR/USD","GBP/USD","USD/JPY","USD/CHF","AUD/USD","USD/CAD",
   "EUR/GBP","EUR/JPY","EUR/CHF","EUR/AUD","EUR/CAD",
   "GBP/JPY","GBP/CHF","GBP/AUD","GBP/CAD",
   "AUD/JPY","AUD/CHF","AUD/CAD",
   "CAD/JPY","CAD/CHF","CHF/JPY",
   "XAU/USD","XAG/USD","OIL","US30","BTC/USD"
};
int g_selectedIndex[2] = {-1,-1};    // 0 = Pair A, 1 = Pair B
bool g_dropdownOpen[2] = {false,false};

ENUM_TIMEFRAMES g_tfValues[3] = {PERIOD_H1,PERIOD_H4,PERIOD_D1};
string g_tfLabels[3] = {"H1","H4","D1"};
int g_tfIndex=2; // default D1

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

void DeleteObj(string suffix) { ObjectDelete(0,PREFIX+suffix); }

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

// SELECTABLE must stay FALSE on edit/button objects, otherwise the first
// click just "selects" the object instead of focusing/clicking it.
void MakeEdit(string suffix,int x,int y,int w,int h,string defaultText)
{
   string n=PREFIX+suffix;
   if(ObjectFind(0,n)<0)
   {
      ObjectCreate(0,n,OBJ_EDIT,0,0,0);
      ObjectSetString(0,n,OBJPROP_TEXT,defaultText);
   }
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,InpEditBgColor);
   ObjectSetInteger(0,n,OBJPROP_COLOR,InpEditTextColor);
   ObjectSetInteger(0,n,OBJPROP_BORDER_COLOR,InpPanelBorderColor);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,10);
   ObjectSetString(0,n,OBJPROP_FONT,"Arial");
   ObjectSetInteger(0,n,OBJPROP_ALIGN,ALIGN_CENTER);
   ObjectSetInteger(0,n,OBJPROP_READONLY,false);
   SetCommon(n,100);
}

void MakeButton(string suffix,int x,int y,int w,int h,string text,color bg,color txt,int size=10,int zorder=100)
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

string GetEditText(string suffix)
{
   string n=PREFIX+suffix;
   return ObjectGetString(0,n,OBJPROP_TEXT);
}

string TrimBoth(string s)
{
   StringTrimLeft(s);
   StringTrimRight(s);
   return s;
}

//------------------------------ Layout -------------------------------
#define HEAD_X 26
#define HEAD_W 280
#define HEAD_H 26
#define HEAD_Y_A 100
#define HEAD_Y_B 148

#define DD_COLS 2
#define DD_ITEM_W 136
#define DD_ITEM_H 22
#define DD_GAP 8
#define DD_X (HEAD_X)

int DropdownRows() { return (PAIR_COUNT+DD_COLS-1)/DD_COLS; }

int SlotHeadY(int slot) { return (slot==0)?HEAD_Y_A:HEAD_Y_B; }
string SlotTag(int slot) { return (slot==0)?"A":"B"; }

//------------------------------ Build GUI ----------------------------
void BuildGUI()
{
   MakeRect("PANEL",PX,PY,PW,PH,InpPanelColor,InpPanelBorderColor,50);

   // Small corner close button - re-open by double-clicking the indicator
   // in Navigator, no need for it to take a full row.
   MakeButton("BTN_CLOSE",PX+PW-38,PY+6,30,26,"✕",InpCloseBtnColor,InpCloseBtnTextColor,11);

   MakeLabel("TITLE",26,48,"EZYMAP CORRELATION POSITION SIZER",InpAccentColor,10,true);
   MakeLabel("SUB",26,66,"1) Pick Pair A+B  2) Capital/Risk  3) Calculate",InpTextColor,8,false);

   MakeLabel("LBL_A",HEAD_X,86,"PAIR A",InpTextColor,8,false);
   MakeButton("BTN_HEAD_A",HEAD_X,HEAD_Y_A,HEAD_W,HEAD_H,"TAP TO SELECT PAIR   ▾",InpEditBgColor,InpTextColor,9);

   MakeLabel("LBL_B",HEAD_X,134,"PAIR B",InpTextColor,8,false);
   MakeButton("BTN_HEAD_B",HEAD_X,HEAD_Y_B,HEAD_W,HEAD_H,"TAP TO SELECT PAIR   ▾",InpEditBgColor,InpTextColor,9);

   MakeLabel("SEL_NOTE",26,182,"No pairs selected yet.",InpTextColor,8,false);

   MakeLabel("LBL_TF",26,200,"TIMEFRAME (correlation window)",InpTextColor,8,false);
   for(int i=0;i<3;i++)
   {
      int w=88, gap=8;
      int x=HEAD_X+i*(w+gap);
      MakeButton("BTN_TF_"+IntegerToString(i),x,214,w,24,g_tfLabels[i],InpSymBtnColor,InpSymBtnTextColor,9);
   }

   MakeLabel("LBL_CAP",26,248,"CAPITAL ($)",InpTextColor,8,false);
   MakeEdit("EDIT_CAPITAL",26,262,280,22,DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2));

   MakeLabel("LBL_RISK",26,294,"BASE RISK PER TRADE (%)",InpTextColor,8,false);
   MakeEdit("EDIT_RISK",26,308,280,22,"1.0");

   MakeButton("BTN_CALC",26,340,280,28,"CALCULATE",InpButtonColor,InpButtonTextColor,10);

   MakeLabel("RES_HEAD",26,382,"RESULTS",InpTextColor,9,true);
   MakeLabel("RES_CORR",26,398," ",InpAccentColor,9,true);
   MakeLabel("RES_MEANING",26,414," ",InpTextColor,8,false);
   MakeLabel("RES_ADJ",26,432," ",InpAccentColor,9,false);
   MakeLabel("RES_CAP",26,450," ",InpTextColor,8,false);
   MakeLabel("RES_NOTE",26,468,"Pick two different pairs above to begin.",InpTextColor,8,false);

   RefreshTfButtons();
}

void RefreshTfButtons()
{
   for(int i=0;i<3;i++)
   {
      string n=PREFIX+"BTN_TF_"+IntegerToString(i);
      bool sel=(i==g_tfIndex);
      ObjectSetInteger(0,n,OBJPROP_BGCOLOR,sel?InpSymBtnSelColor:InpSymBtnColor);
      ObjectSetInteger(0,n,OBJPROP_COLOR,sel?InpSymBtnSelText:InpSymBtnTextColor);
   }
}

void ItemCoords(int idx,int ddX,int ddY,int &x,int &y)
{
   int col=idx%DD_COLS, row=idx/DD_COLS;
   x=ddX+col*(DD_ITEM_W+DD_GAP);
   y=ddY+row*(DD_ITEM_H+2);
}

void OpenDropdown(int slot)
{
   int other=(slot==0)?1:0;
   if(g_dropdownOpen[other]) CloseDropdown(other);

   int ddY=SlotHeadY(slot)+HEAD_H+4;
   int rows=DropdownRows();
   int bgH=rows*(DD_ITEM_H+2)+8;
   string tag=SlotTag(slot);

   MakeRect("DD_BG_"+tag,DD_X-6,ddY-4,DD_ITEM_W*DD_COLS+DD_GAP+12,bgH,InpPanelColor,InpAccentColor,200);

   for(int i=0;i<PAIR_COUNT;i++)
   {
      int x,y; ItemCoords(i,DD_X,ddY,x,y);
      bool sel=(i==g_selectedIndex[slot]);
      MakeButton("DD_ITEM_"+tag+"_"+IntegerToString(i),x,y,DD_ITEM_W,DD_ITEM_H,g_aliasLabels[i],
                 sel?InpSymBtnSelColor:InpSymBtnColor, sel?InpSymBtnSelText:InpSymBtnTextColor,8,210);
   }

   ObjectSetString(0,PREFIX+"BTN_HEAD_"+tag,OBJPROP_TEXT,"TAP TO SELECT PAIR   ▴");
   g_dropdownOpen[slot]=true;
   ChartRedraw(0);
}

void CloseDropdown(int slot)
{
   string tag=SlotTag(slot);
   DeleteObj("DD_BG_"+tag);
   for(int i=0;i<PAIR_COUNT;i++)
      DeleteObj("DD_ITEM_"+tag+"_"+IntegerToString(i));

   string headText=(g_selectedIndex[slot]>=0)?g_aliasLabels[g_selectedIndex[slot]]+"   ▾":"TAP TO SELECT PAIR   ▾";
   ObjectSetString(0,PREFIX+"BTN_HEAD_"+tag,OBJPROP_TEXT,headText);
   g_dropdownOpen[slot]=false;
   ChartRedraw(0);
}

//------------------------- Symbol resolution -------------------------
void CandidatesFor(string alias,string &out[])
{
   if(alias=="XAUUSD")      { string a[]={"XAUUSD","GOLD"}; ArrayCopy(out,a); }
   else if(alias=="XAGUSD") { string a[]={"XAGUSD","SILVER"}; ArrayCopy(out,a); }
   else if(alias=="OIL")    { string a[]={"USOIL","XTIUSD","WTI","UKOIL","XBRUSD","OILUSD","BRENT","USOUSD"}; ArrayCopy(out,a); }
   else if(alias=="US30")   { string a[]={"US30","DJ30","WS30","DOW30","DJI"}; ArrayCopy(out,a); }
   else if(alias=="BTCUSD") { string a[]={"BTCUSD","BTCUSDT"}; ArrayCopy(out,a); }
   else                     { string a[]={alias}; ArrayCopy(out,a); }
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
   for(int i=0;i<total;i++)
   {
      string name=SymbolName(i,inMarketWatchOnly);
      string upperName=name; StringToUpper(upperName);
      for(int c=0;c<ArraySize(upperCandidates);c++)
         if(StringFind(upperName,upperCandidates[c])>=0) return name;
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

//----------------------------- Calculation ---------------------------
// Correlation of % returns over the selected timeframe/lookback. Simple
// index-aligned comparison (not timestamp-matched), which is the standard
// approach for retail correlation tools but can be slightly off for pairs
// with different trading-session gaps (e.g. crypto vs forex).
double PearsonCorrelation(string symA,string symB,ENUM_TIMEFRAMES tf,int bars,bool &ok)
{
   ok=false;
   double a[],b[];
   ArraySetAsSeries(a,false);
   ArraySetAsSeries(b,false);

   int gotA=CopyClose(symA,tf,1,bars+1,a);
   int gotB=CopyClose(symB,tf,1,bars+1,b);
   if(gotA<bars+1 || gotB<bars+1) return 0.0;

   int n=bars;
   double retA[],retB[];
   ArrayResize(retA,n);
   ArrayResize(retB,n);
   for(int i=0;i<n;i++)
   {
      if(a[i]<=0.0 || b[i]<=0.0) return 0.0;
      retA[i]=(a[i+1]-a[i])/a[i];
      retB[i]=(b[i+1]-b[i])/b[i];
   }

   double meanA=0.0,meanB=0.0;
   for(int i=0;i<n;i++) { meanA+=retA[i]; meanB+=retB[i]; }
   meanA/=n; meanB/=n;

   double num=0.0,denA=0.0,denB=0.0;
   for(int i=0;i<n;i++)
   {
      double da=retA[i]-meanA, db=retB[i]-meanB;
      num+=da*db; denA+=da*da; denB+=db*db;
   }
   if(denA<=0.0 || denB<=0.0) return 0.0;

   double corr=num/MathSqrt(denA*denB);
   corr=MathMax(-1.0,MathMin(1.0,corr));
   ok=true;
   return corr;
}

void DoCalculate()
{
   if(g_selectedIndex[0]<0 || g_selectedIndex[1]<0)
   {
      SetLabelText("RES_NOTE","⚠ Please select both Pair A and Pair B above.",InpErrorColor);
      ChartRedraw(0);
      return;
   }
   if(g_selectedIndex[0]==g_selectedIndex[1])
   {
      SetLabelText("RES_NOTE","⚠ Pick two different pairs - A and B are the same right now.",InpErrorColor);
      ChartRedraw(0);
      return;
   }

   string symA=ResolveSymbol(g_aliasKeys[g_selectedIndex[0]]);
   string symB=ResolveSymbol(g_aliasKeys[g_selectedIndex[1]]);
   if(symA=="" || symB=="" || !SymbolSelect(symA,true) || !SymbolSelect(symB,true))
   {
      SetLabelText("SEL_NOTE","⚠ Could not resolve both broker symbols.",InpErrorColor);
      SetLabelText("RES_NOTE","Add the missing pair to Market Watch manually and try again.",InpErrorColor);
      ChartRedraw(0);
      return;
   }
   SetLabelText("SEL_NOTE","A: "+symA+"   •   B: "+symB,InpAccentColor);

   double capital=StringToDouble(TrimBoth(GetEditText("EDIT_CAPITAL")));
   double baseRiskPct=StringToDouble(TrimBoth(GetEditText("EDIT_RISK")));
   if(capital<=0.0 || baseRiskPct<=0.0)
   {
      SetLabelText("RES_NOTE","⚠ Capital and Base Risk % must both be greater than 0.",InpErrorColor);
      ChartRedraw(0);
      return;
   }

   ENUM_TIMEFRAMES tf=g_tfValues[g_tfIndex];
   bool ok=false;
   double corr=PearsonCorrelation(symA,symB,tf,InpLookbackBars,ok);
   if(!ok)
   {
      SetLabelText("RES_NOTE","⚠ Not enough "+g_tfLabels[g_tfIndex]+" history for both pairs yet - try a shorter lookback or wait for history to load.",InpErrorColor);
      ChartRedraw(0);
      return;
   }

   double absCorr=MathAbs(corr);
   string strength=(absCorr>=0.7)?"STRONG":((absCorr>=0.3)?"MODERATE":"WEAK/NONE");
   string direction=(corr>=0.0)?"POSITIVE":"NEGATIVE";
   color corrColor=(absCorr>=0.7)?InpStrongColor:((absCorr>=0.3)?InpModColor:InpWeakColor);

   // Combined risk budget shrinks toward one trade's worth of risk as
   // correlation approaches 1 (two positions that move together behave
   // like one bigger position); at 0 correlation, both trades keep their
   // full independent risk.
   double totalBudgetPct=baseRiskPct*(2.0-absCorr);
   double perPairPct=totalBudgetPct/2.0;
   double perPairMoney=capital*perPairPct/100.0;
   double totalMoney=capital*totalBudgetPct/100.0;

   SetLabelText("RES_CORR","Correlation: "+DoubleToString(corr,2)+"  ("+strength+" "+direction+")",corrColor);

   string meaning;
   if(corr>=0.0)
      meaning="Positive: these tend to move together - same-direction trades stack risk.";
   else
      meaning="Negative: these tend to move opposite - can act as a natural hedge if traded in opposite directions.";
   SetLabelText("RES_MEANING",meaning,InpTextColor);

   SetLabelText("RES_ADJ","Adjusted risk per pair: "+DoubleToString(perPairPct,2)+"%  (~"+DoubleToString(perPairMoney,2)+" "+AccountInfoString(ACCOUNT_CURRENCY)+")",InpAccentColor);
   SetLabelText("RES_CAP","Combined budget: "+DoubleToString(totalBudgetPct,2)+"%  (~"+DoubleToString(totalMoney,2)+" "+AccountInfoString(ACCOUNT_CURRENCY)+")  vs "+DoubleToString(baseRiskPct*2.0,2)+"% if uncorrelated",InpTextColor);
   SetLabelText("RES_NOTE",g_tfLabels[g_tfIndex]+" • "+IntegerToString(InpLookbackBars)+" bars • rough guide, not a precise risk model",InpTextColor);

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

   g_selectedIndex[0]=-1; g_selectedIndex[1]=-1;
   g_dropdownOpen[0]=false; g_dropdownOpen[1]=false;
   g_tfIndex=2;
   BuildGUI();
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
   if(id==CHARTEVENT_OBJECT_CLICK)
   {
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

      if(sparam==PREFIX+"BTN_HEAD_A")
      {
         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         if(g_dropdownOpen[0]) CloseDropdown(0); else OpenDropdown(0);
         return;
      }
      if(sparam==PREFIX+"BTN_HEAD_B")
      {
         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         if(g_dropdownOpen[1]) CloseDropdown(1); else OpenDropdown(1);
         return;
      }

      for(int t=0;t<3;t++)
      {
         if(sparam==PREFIX+"BTN_TF_"+IntegerToString(t))
         {
            ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
            g_tfIndex=t;
            RefreshTfButtons();
            return;
         }
      }

      if(sparam==PREFIX+"BTN_CALC")
      {
         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         if(g_dropdownOpen[0]) CloseDropdown(0);
         if(g_dropdownOpen[1]) CloseDropdown(1);
         DoCalculate();
         return;
      }

      if(g_dropdownOpen[0])
      {
         for(int i=0;i<PAIR_COUNT;i++)
         {
            string n=PREFIX+"DD_ITEM_A_"+IntegerToString(i);
            if(sparam==n)
            {
               ObjectSetInteger(0,n,OBJPROP_STATE,false);
               g_selectedIndex[0]=i;
               CloseDropdown(0);
               return;
            }
         }
      }
      if(g_dropdownOpen[1])
      {
         for(int i=0;i<PAIR_COUNT;i++)
         {
            string n=PREFIX+"DD_ITEM_B_"+IntegerToString(i);
            if(sparam==n)
            {
               ObjectSetInteger(0,n,OBJPROP_STATE,false);
               g_selectedIndex[1]=i;
               CloseDropdown(1);
               return;
            }
         }
      }
   }

   if(id==CHARTEVENT_OBJECT_ENDEDIT &&
      (sparam==PREFIX+"EDIT_CAPITAL" || sparam==PREFIX+"EDIT_RISK"))
   {
      DoCalculate();
      return;
   }
}

int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],const double &open[],const double &high[],const double &low[],const double &close[],const long &tick_volume[],const long &volume[],const int &spread[])
{
   return rates_total;
}
//+------------------------------------------------------------------+
