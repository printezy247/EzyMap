//+------------------------------------------------------------------+
//| EzyMap Margin & Max Lots Calculator                                |
//| On-chart GUI: pick a pair, type Capital/Free Margin, click        |
//| CALCULATE - get margin per lot and Conservative/Moderate/         |
//| Aggressive max lot sizes.                                         |
//|                                                                    |
//| Built as an EXPERT ADVISOR, not an indicator: OrderCalcMargin() is |
//| a trade-context function that MT5 does not allow indicators to    |
//| call (fails with error #4014 regardless of symbol/timing) - only  |
//| EAs and Scripts can call it. An EA is required here to keep the   |
//| persistent on-chart GUI (a Script can't stay open for buttons).   |
//| It does not place any trades - only calls the read-only margin    |
//| calculation function.                                             |
//+------------------------------------------------------------------+
#property copyright "EzyMap"
#property version   "2.00"
#property strict

input double InpConservativePercent = 30.0;   // Conservative tier (% of free margin used)
input double InpModeratePercent     = 50.0;   // Moderate tier (% of free margin used)
input double InpAggressivePercent   = 80.0;   // Aggressive tier (% of free margin used)

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
input color  InpConsColor        = C'52,211,176';
input color  InpModColor         = C'237,185,58';
input color  InpAggColor         = C'235,72,96';
input color  InpErrorColor       = C'235,72,96';
input color  InpCloseBtnColor    = C'40,14,18';
input color  InpCloseBtnTextColor= C'235,72,96';

#define PRODUCT_NAME "EzyMap Margin Calculator"
string PREFIX="EZMGN_";

int PX=14;
int PY=38;
int PW=332;
int PH=356;

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
int g_selectedIndex=-1;
bool g_dropdownOpen=false;

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

int VolumeDecimals(double step)
{
   if(step>=1.0) return 0;
   if(step>=0.1) return 1;
   return 2;
}

//------------------------------ Layout -------------------------------
#define HEAD_X 26
#define HEAD_Y 100
#define HEAD_W 280
#define HEAD_H 26

#define DD_COLS 2
#define DD_ITEM_W 136
#define DD_ITEM_H 22
#define DD_GAP 8
#define DD_X (HEAD_X)
#define DD_Y (HEAD_Y+HEAD_H+4)

//------------------------------ Build GUI ----------------------------
void BuildGUI()
{
   MakeRect("PANEL",PX,PY,PW,PH,InpPanelColor,InpPanelBorderColor,50);

   // Small corner close button - re-open by double-clicking the indicator
   // in Navigator, no need for it to take a full row.
   MakeButton("BTN_CLOSE",PX+PW-38,PY+6,30,26,"✕",InpCloseBtnColor,InpCloseBtnTextColor,11);

   MakeLabel("TITLE",26,48,"EZYMAP MARGIN & MAX LOTS CALC",InpAccentColor,11,true);
   MakeLabel("SUB",26,68,"1) Pick a pair  2) Fill Capital  3) Calculate",InpTextColor,8,false);

   MakeLabel("LBL_PAIR",HEAD_X,86,"SELECT PAIR",InpTextColor,8,false);
   MakeButton("BTN_HEAD",HEAD_X,HEAD_Y,HEAD_W,HEAD_H,"TAP TO SELECT PAIR   ▾",InpEditBgColor,InpTextColor,9);
   MakeLabel("SEL_NOTE",26,134,"No pair selected yet.",InpTextColor,8,false);

   MakeLabel("LBL_CAP",26,152,"CAPITAL / FREE MARGIN ($)",InpTextColor,8,false);
   MakeEdit("EDIT_CAPITAL",26,166,280,22,DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE),2));

   MakeButton("BTN_CALC",26,196,280,28,"CALCULATE",InpButtonColor,InpButtonTextColor,10);

   MakeLabel("RES_HEAD",26,234,"RESULTS",InpTextColor,9,true);
   MakeLabel("RES_LEV",26,250," ",InpTextColor,8,false);
   MakeLabel("RES_MARGIN",26,266," ",InpAccentColor,9,false);
   MakeLabel("RES_CONS",26,284," ",InpConsColor,9,false);
   MakeLabel("RES_MOD",26,302," ",InpModColor,9,false);
   MakeLabel("RES_AGG",26,320," ",InpAggColor,9,false);
   MakeLabel("RES_NOTE",26,338,"Pick a pair above to begin.",InpTextColor,8,false);
}

void ItemCoords(int idx,int &x,int &y)
{
   int col=idx%DD_COLS, row=idx/DD_COLS;
   x=DD_X+col*(DD_ITEM_W+DD_GAP);
   y=DD_Y+row*(DD_ITEM_H+2);
}

int DropdownRows() { return (PAIR_COUNT+DD_COLS-1)/DD_COLS; }

void OpenDropdown()
{
   int rows=DropdownRows();
   int bgH=rows*(DD_ITEM_H+2)+8;
   MakeRect("DD_BG",DD_X-6,DD_Y-4,DD_ITEM_W*DD_COLS+DD_GAP+12,bgH,InpPanelColor,InpAccentColor,200);

   for(int i=0;i<PAIR_COUNT;i++)
   {
      int x,y; ItemCoords(i,x,y);
      bool sel=(i==g_selectedIndex);
      MakeButton("DD_ITEM_"+IntegerToString(i),x,y,DD_ITEM_W,DD_ITEM_H,g_aliasLabels[i],
                 sel?InpSymBtnSelColor:InpSymBtnColor, sel?InpSymBtnSelText:InpSymBtnTextColor,8,210);
   }

   ObjectSetString(0,PREFIX+"BTN_HEAD",OBJPROP_TEXT,"TAP TO SELECT PAIR   ▴");
   g_dropdownOpen=true;
   ChartRedraw(0);
}

void CloseDropdown()
{
   DeleteObj("DD_BG");
   for(int i=0;i<PAIR_COUNT;i++)
      DeleteObj("DD_ITEM_"+IntegerToString(i));

   string headText=(g_selectedIndex>=0)?g_aliasLabels[g_selectedIndex]+"   ▾":"TAP TO SELECT PAIR   ▾";
   ObjectSetString(0,PREFIX+"BTN_HEAD",OBJPROP_TEXT,headText);
   g_dropdownOpen=false;
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

// Scans 'inMarketWatchOnly' true = only symbols the user already has
// watched (SymbolsTotal(true)) - these are guaranteed synced/tradeable.
// false = the broker's entire symbol universe (thousands of entries,
// many inactive/unsynced duplicates), used only as a last-resort fallback.
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

// Prefer whatever the user already has in Market Watch - it's guaranteed
// selected, synced and tradeable there, unlike a fresh match pulled from
// the broker's full symbol universe (which can land on an unsynced or
// otherwise unusable duplicate, e.g. a swap-free/ECN variant of the same
// pair that OrderCalcMargin then fails on).
string ResolveSymbol(string alias,bool &wasAlreadyWatched)
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
   if(found!="")
   {
      wasAlreadyWatched=true;
      return found;
   }

   wasAlreadyWatched=false;
   return ScanSymbols(upperCandidates,false);
}

// After adding a symbol that wasn't already in Market Watch, give the
// terminal a brief moment to sync its trade specification/price before
// margin math relies on it - avoids OrderCalcMargin failing on a symbol
// that was only just selected.
bool WaitForSymbolReady(string symbol)
{
   for(int i=0;i<10;i++)
   {
      if(SymbolInfoDouble(symbol,SYMBOL_BID)>0.0 && SymbolInfoDouble(symbol,SYMBOL_ASK)>0.0)
         return true;
      Sleep(100);
   }
   return false;
}

//----------------------------- Calculation ---------------------------
// Finds the largest lot size (respecting the volume step) whose margin
// requirement fits inside 'budget', re-checking via OrderCalcMargin at
// each step so tiered/non-linear broker margin schedules stay accurate.
string BuildTierText(string label,double pct,double budget,string symbol,double price,
                      double volMin,double volMax,double volStep,int decimals,string &warnOut)
{
   double marginForOne=0.0;
   if(!OrderCalcMargin(ORDER_TYPE_BUY,symbol,1.0,price,marginForOne) || marginForOne<=0.0)
      return label+" ("+DoubleToString(pct,0)+"%): unavailable";

   double estimate=MathFloor((budget/marginForOne)/volStep)*volStep;
   if(estimate>volMax) estimate=MathFloor(volMax/volStep)*volStep;

   double actualMargin=0.0;
   bool fits=false;
   while(estimate>=volMin)
   {
      if(OrderCalcMargin(ORDER_TYPE_BUY,symbol,estimate,price,actualMargin) && actualMargin<=budget)
      {
         fits=true;
         break;
      }
      estimate-=volStep;
   }

   if(!fits || estimate<volMin)
   {
      warnOut=" ⚠ some tiers can't even afford the broker min lot.";
      return label+" ("+DoubleToString(pct,0)+"%):  0.00 lots  (min lot too expensive)";
   }

   estimate=NormalizeDouble(estimate,8);
   return label+" ("+DoubleToString(pct,0)+"%):  "+DoubleToString(estimate,decimals)+" lots   ~"+
          DoubleToString(actualMargin,2)+" "+AccountInfoString(ACCOUNT_CURRENCY)+" margin used";
}

void DoCalculate()
{
   if(g_selectedIndex<0)
   {
      SetLabelText("RES_NOTE","⚠ Please select a pair from the dropdown above.",InpErrorColor);
      ChartRedraw(0);
      return;
   }

   string alias=g_aliasKeys[g_selectedIndex];
   bool wasAlreadyWatched=false;
   string symbol=ResolveSymbol(alias,wasAlreadyWatched);
   if(symbol=="" || !SymbolSelect(symbol,true))
   {
      SetLabelText("SEL_NOTE","⚠ Could not find a broker symbol for "+g_aliasLabels[g_selectedIndex]+".",InpErrorColor);
      SetLabelText("RES_NOTE","Add it to Market Watch manually and try again.",InpErrorColor);
      ChartRedraw(0);
      return;
   }
   if(!wasAlreadyWatched && !WaitForSymbolReady(symbol))
   {
      SetLabelText("SEL_NOTE","Selected: "+g_aliasLabels[g_selectedIndex]+"  →  broker symbol: "+symbol,InpAccentColor);
      SetLabelText("RES_NOTE","⚠ "+symbol+" was just added to Market Watch and hasn't synced yet - click CALCULATE again in a moment.",InpErrorColor);
      ChartRedraw(0);
      return;
   }
   SetLabelText("SEL_NOTE","Selected: "+g_aliasLabels[g_selectedIndex]+"  →  broker symbol: "+symbol,InpAccentColor);

   double capital=StringToDouble(TrimBoth(GetEditText("EDIT_CAPITAL")));
   if(capital<=0.0)
   {
      SetLabelText("RES_NOTE","⚠ Capital / Free Margin must be greater than 0.",InpErrorColor);
      ChartRedraw(0);
      return;
   }

   // Prefer a fresh tick over the cached SYMBOL_ASK value - right after
   // SymbolSelect() the cached price can still be stale/zero for a symbol
   // that wasn't already on the current chart.
   MqlTick tick;
   double price=0.0;
   if(SymbolInfoTick(symbol,tick) && tick.ask>0.0)
      price=tick.ask;
   else
      price=SymbolInfoDouble(symbol,SYMBOL_ASK);

   double volMin=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
   double volMax=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
   double volStep=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);

   if(price<=0.0 || volStep<=0.0)
   {
      SetLabelText("RES_LEV"," ",InpTextColor);
      SetLabelText("RES_MARGIN"," ",InpAccentColor);
      SetLabelText("RES_CONS"," ",InpConsColor);
      SetLabelText("RES_MOD"," ",InpModColor);
      SetLabelText("RES_AGG"," ",InpAggColor);
      SetLabelText("RES_NOTE","⚠ Trade specification unavailable for "+symbol+" - try again shortly.",InpErrorColor);
      ChartRedraw(0);
      return;
   }

   ResetLastError();
   double marginPerLot=0.0;
   if(!OrderCalcMargin(ORDER_TYPE_BUY,symbol,1.0,price,marginPerLot) || marginPerLot<=0.0)
   {
      int err=GetLastError();
      SetLabelText("RES_LEV"," ",InpTextColor);
      SetLabelText("RES_MARGIN"," ",InpAccentColor);
      SetLabelText("RES_CONS"," ",InpConsColor);
      SetLabelText("RES_MOD"," ",InpModColor);
      SetLabelText("RES_AGG"," ",InpAggColor);
      SetLabelText("RES_NOTE","⚠ Could not compute margin for "+symbol+" (error #"+IntegerToString(err)+"). Check Market Watch / symbol permissions.",InpErrorColor);
      ChartRedraw(0);
      return;
   }

   int decimals=VolumeDecimals(volStep);
   int leverage=(int)AccountInfoInteger(ACCOUNT_LEVERAGE);
   string cur=AccountInfoString(ACCOUNT_CURRENCY);

   string warn="";
   double consBudget=capital*InpConservativePercent/100.0;
   double modBudget =capital*InpModeratePercent/100.0;
   double aggBudget =capital*InpAggressivePercent/100.0;

   string consTxt=BuildTierText("CONSERVATIVE",InpConservativePercent,consBudget,symbol,price,volMin,volMax,volStep,decimals,warn);
   string modTxt =BuildTierText("MODERATE",InpModeratePercent,modBudget,symbol,price,volMin,volMax,volStep,decimals,warn);
   string aggTxt =BuildTierText("AGGRESSIVE",InpAggressivePercent,aggBudget,symbol,price,volMin,volMax,volStep,decimals,warn);

   SetLabelText("RES_LEV","Account leverage: 1:"+IntegerToString(leverage),InpTextColor);
   SetLabelText("RES_MARGIN","Margin per 1.00 lot: "+DoubleToString(marginPerLot,2)+" "+cur,InpAccentColor);
   SetLabelText("RES_CONS",consTxt,InpConsColor);
   SetLabelText("RES_MOD",modTxt,InpModColor);
   SetLabelText("RES_AGG",aggTxt,InpAggColor);

   string note=symbol+"  •  free margin used as capital base unless you typed your own";
   if(warn!="") note=warn;
   SetLabelText("RES_NOTE",note,warn!=""?InpErrorColor:InpTextColor);

   ChartRedraw(0);
}

//--------------------------- MT5 events -----------------------------
int OnInit()
{
   g_selectedIndex=-1;
   g_dropdownOpen=false;
   BuildGUI();
   ChartRedraw(0);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0,PREFIX);
   ChartRedraw(0);
}

void OnTick()
{
   // No per-tick work needed - this EA only acts on button clicks.
}

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id==CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam==PREFIX+"BTN_CLOSE")
      {
         ExpertRemove();
         return;
      }

      if(sparam==PREFIX+"BTN_HEAD")
      {
         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         if(g_dropdownOpen) CloseDropdown(); else OpenDropdown();
         return;
      }

      if(sparam==PREFIX+"BTN_CALC")
      {
         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         if(g_dropdownOpen) CloseDropdown();
         DoCalculate();
         return;
      }

      if(g_dropdownOpen)
      {
         for(int i=0;i<PAIR_COUNT;i++)
         {
            string n=PREFIX+"DD_ITEM_"+IntegerToString(i);
            if(sparam==n)
            {
               ObjectSetInteger(0,n,OBJPROP_STATE,false);
               g_selectedIndex=i;
               CloseDropdown();
               DoCalculate();
               return;
            }
         }
      }
   }

   if(id==CHARTEVENT_OBJECT_ENDEDIT && sparam==PREFIX+"EDIT_CAPITAL")
   {
      DoCalculate();
      return;
   }
}
//+------------------------------------------------------------------+
