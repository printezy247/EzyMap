//+------------------------------------------------------------------+
//| EzyMap Risk:Reward & Breakeven Calculator                         |
//| On-chart GUI: pick Direction + Pair, fill Entry/SL/TP/Lot/        |
//| Commission, click CALCULATE - get R:R, win-rate and true BE price.|
//+------------------------------------------------------------------+
#property copyright "EzyMap"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

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
input color  InpBuyColor         = C'0,208,142';
input color  InpSellColor        = C'235,72,96';
input color  InpErrorColor       = C'235,72,96';
input color  InpCloseBtnColor    = C'40,14,18';
input color  InpCloseBtnTextColor= C'235,72,96';

#define PRODUCT_NAME "EzyMap Risk-Reward Calculator"
string PREFIX="EZRR_";

int PX=14;
int PY=38;
int PW=332;
int PH=570;

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
int g_direction=-1; // 0=BUY, 1=SELL

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
#define DIR_Y 100
#define HEAD_X 26
#define HEAD_Y 148
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

   MakeLabel("TITLE",26,48,"EZYMAP RISK:REWARD & BREAKEVEN CALC",InpAccentColor,10,true);
   MakeLabel("SUB",26,66,"1) Direction+Pair  2) Prices/Lot  3) Calculate",InpTextColor,8,false);

   MakeLabel("LBL_DIR",26,86,"DIRECTION",InpTextColor,8,false);
   MakeButton("BTN_BUY",26,DIR_Y,136,26,"BUY",InpSymBtnColor,InpSymBtnTextColor,10);
   MakeButton("BTN_SELL",170,DIR_Y,136,26,"SELL",InpSymBtnColor,InpSymBtnTextColor,10);

   MakeLabel("LBL_PAIR",HEAD_X,134,"SELECT PAIR",InpTextColor,8,false);
   MakeButton("BTN_HEAD",HEAD_X,HEAD_Y,HEAD_W,HEAD_H,"TAP TO SELECT PAIR   ▾",InpEditBgColor,InpTextColor,9);
   MakeLabel("SEL_NOTE",26,182,"No pair selected yet.",InpTextColor,8,false);

   MakeLabel("LBL_ENTRY",26,200,"ENTRY PRICE",InpTextColor,8,false);
   MakeEdit("EDIT_ENTRY",26,214,280,22,"0.00000");

   MakeLabel("LBL_SL",26,236,"STOP LOSS PRICE",InpTextColor,8,false);
   MakeEdit("EDIT_SL",26,250,280,22,"0.00000");

   MakeLabel("LBL_TP",26,272,"TAKE PROFIT PRICE",InpTextColor,8,false);
   MakeEdit("EDIT_TP",26,286,280,22,"0.00000");

   MakeLabel("LBL_LOT",26,308,"LOT SIZE",InpTextColor,8,false);
   MakeEdit("EDIT_LOT",26,322,280,22,"0.01");

   MakeLabel("LBL_COMM",26,344,"COMMISSION (round turn, $ per lot)",InpTextColor,8,false);
   MakeEdit("EDIT_COMM",26,358,280,22,"0");

   MakeButton("BTN_CALC",26,388,280,28,"CALCULATE",InpButtonColor,InpButtonTextColor,10);

   MakeLabel("RES_HEAD",26,430,"RESULTS",InpTextColor,9,true);
   MakeLabel("RES_RISK",26,446,"",InpSellColor,9,false);
   MakeLabel("RES_REWARD",26,462,"",InpBuyColor,9,false);
   MakeLabel("RES_RR",26,478,"",InpAccentColor,9,true);
   MakeLabel("RES_WINRATE",26,494,"",InpTextColor,8,false);
   MakeLabel("RES_BE",26,510,"",InpAccentColor,9,false);
   MakeLabel("RES_NET",26,526,"",InpTextColor,8,false);
   MakeLabel("RES_NOTE",26,542,"Pick Direction + Pair above to begin.",InpTextColor,8,false);

   RefreshDirButtons();
}

void RefreshDirButtons()
{
   ObjectSetInteger(0,PREFIX+"BTN_BUY",OBJPROP_BGCOLOR,(g_direction==0)?InpBuyColor:InpSymBtnColor);
   ObjectSetInteger(0,PREFIX+"BTN_BUY",OBJPROP_COLOR,(g_direction==0)?InpPanelColor:InpSymBtnTextColor);
   ObjectSetInteger(0,PREFIX+"BTN_SELL",OBJPROP_BGCOLOR,(g_direction==1)?InpSellColor:InpSymBtnColor);
   ObjectSetInteger(0,PREFIX+"BTN_SELL",OBJPROP_COLOR,(g_direction==1)?InpPanelColor:InpSymBtnTextColor);
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

   int total=SymbolsTotal(false);

   for(int i=0;i<total;i++)
   {
      string name=SymbolName(i,false);
      string upperName=name; StringToUpper(upperName);
      for(int c=0;c<ArraySize(upperCandidates);c++)
         if(upperName==upperCandidates[c]) return name;
   }
   for(int i=0;i<total;i++)
   {
      string name=SymbolName(i,false);
      string upperName=name; StringToUpper(upperName);
      for(int c=0;c<ArraySize(upperCandidates);c++)
         if(StringFind(upperName,upperCandidates[c])==0) return name;
   }
   for(int i=0;i<total;i++)
   {
      string name=SymbolName(i,false);
      string upperName=name; StringToUpper(upperName);
      for(int c=0;c<ArraySize(upperCandidates);c++)
         if(StringFind(upperName,upperCandidates[c])>=0) return name;
   }
   return "";
}

//----------------------------- Calculation ---------------------------
string PriceText(string symbol,double v)
{
   int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   return DoubleToString(v,digits);
}

void DoCalculate()
{
   if(g_direction<0)
   {
      SetLabelText("RES_NOTE","⚠ Please pick BUY or SELL first.",InpErrorColor);
      ChartRedraw(0);
      return;
   }
   if(g_selectedIndex<0)
   {
      SetLabelText("RES_NOTE","⚠ Please select a pair from the dropdown above.",InpErrorColor);
      ChartRedraw(0);
      return;
   }

   string alias=g_aliasKeys[g_selectedIndex];
   string symbol=ResolveSymbol(alias);
   if(symbol=="" || !SymbolSelect(symbol,true))
   {
      SetLabelText("SEL_NOTE","⚠ Could not find a broker symbol for "+g_aliasLabels[g_selectedIndex]+".",InpErrorColor);
      SetLabelText("RES_NOTE","Add it to Market Watch manually and try again.",InpErrorColor);
      ChartRedraw(0);
      return;
   }
   SetLabelText("SEL_NOTE","Selected: "+g_aliasLabels[g_selectedIndex]+"  →  broker symbol: "+symbol,InpAccentColor);

   bool isBuy=(g_direction==0);
   double entry=StringToDouble(TrimBoth(GetEditText("EDIT_ENTRY")));
   double sl   =StringToDouble(TrimBoth(GetEditText("EDIT_SL")));
   double tp   =StringToDouble(TrimBoth(GetEditText("EDIT_TP")));
   double lots =StringToDouble(TrimBoth(GetEditText("EDIT_LOT")));
   double commPerLot=StringToDouble(TrimBoth(GetEditText("EDIT_COMM")));

   if(entry<=0.0 || sl<=0.0 || tp<=0.0 || lots<=0.0)
   {
      SetLabelText("RES_NOTE","⚠ Entry, SL, TP and Lot Size must all be greater than 0.",InpErrorColor);
      ChartRedraw(0);
      return;
   }

   bool slValid=isBuy?(sl<entry):(sl>entry);
   bool tpValid=isBuy?(tp>entry):(tp<entry);
   if(!slValid)
   {
      SetLabelText("RES_NOTE","⚠ Stop Loss is on the wrong side of Entry for a "+(isBuy?"BUY":"SELL")+".",InpErrorColor);
      ChartRedraw(0);
      return;
   }
   if(!tpValid)
   {
      SetLabelText("RES_NOTE","⚠ Take Profit is on the wrong side of Entry for a "+(isBuy?"BUY":"SELL")+".",InpErrorColor);
      ChartRedraw(0);
      return;
   }

   double tickValue=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE);
   double tickSize =SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   double point    =SymbolInfoDouble(symbol,SYMBOL_POINT);

   if(tickValue<=0.0 || tickSize<=0.0 || point<=0.0)
   {
      SetLabelText("RES_NOTE","⚠ Trade specification unavailable for "+symbol+" - try again shortly.",InpErrorColor);
      ChartRedraw(0);
      return;
   }

   double moneyPerPointPerLot=(tickValue/tickSize)*point;

   double riskPoints=MathAbs(entry-sl)/point;
   double rewardPoints=MathAbs(tp-entry)/point;
   double riskMoney=riskPoints*moneyPerPointPerLot*lots;
   double rewardMoney=rewardPoints*moneyPerPointPerLot*lots;
   double rr=(riskPoints>0.0)?rewardPoints/riskPoints:0.0;
   double winRate=(riskPoints+rewardPoints>0.0)?riskPoints/(riskPoints+rewardPoints)*100.0:0.0;

   double commissionTotal=commPerLot*lots;
   double commPoints=(moneyPerPointPerLot*lots>0.0)?commissionTotal/(moneyPerPointPerLot*lots):0.0;
   double bePrice=isBuy?(entry+commPoints*point):(entry-commPoints*point);

   double netRewardMoney=rewardMoney-commissionTotal;
   double netRiskMoney=riskMoney+commissionTotal;
   double netRR=(netRiskMoney>0.0)?netRewardMoney/netRiskMoney:0.0;
   double netWinRate=(netRewardMoney+netRiskMoney>0.0)?netRiskMoney/(netRewardMoney+netRiskMoney)*100.0:0.0;

   string cur=AccountInfoString(ACCOUNT_CURRENCY);

   SetLabelText("RES_RISK","RISK:     "+DoubleToString(riskPoints,0)+" pts   ~"+DoubleToString(riskMoney,2)+" "+cur,InpSellColor);
   SetLabelText("RES_REWARD","REWARD:   "+DoubleToString(rewardPoints,0)+" pts   ~"+DoubleToString(rewardMoney,2)+" "+cur,InpBuyColor);
   SetLabelText("RES_RR","R:R  1 : "+DoubleToString(rr,2),InpAccentColor);
   SetLabelText("RES_WINRATE","Breakeven win rate needed: "+DoubleToString(winRate,1)+"%",InpTextColor);
   SetLabelText("RES_BE","TRUE BE PRICE (w/ commission): "+PriceText(symbol,bePrice),InpAccentColor);
   SetLabelText("RES_NET","NET (after commission): R:R 1:"+DoubleToString(netRR,2)+"   win rate "+DoubleToString(netWinRate,1)+"%",InpTextColor);

   int spreadPts=(int)SymbolInfoInteger(symbol,SYMBOL_SPREAD);
   string note=symbol+"  •  current spread "+IntegerToString(spreadPts)+" pts (already reflected in your live P/L, not added again)";
   SetLabelText("RES_NOTE",note,InpTextColor);

   ChartRedraw(0);
}

//--------------------------- MT5 events -----------------------------
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME,PRODUCT_NAME);
   g_selectedIndex=-1;
   g_dropdownOpen=false;
   g_direction=-1;
   BuildGUI();
   ChartRedraw(0);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0,PREFIX);
   ChartRedraw(0);
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

      if(sparam==PREFIX+"BTN_BUY")
      {
         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         g_direction=0;
         RefreshDirButtons();
         return;
      }

      if(sparam==PREFIX+"BTN_SELL")
      {
         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         g_direction=1;
         RefreshDirButtons();
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
               return;
            }
         }
      }
   }

   if(id==CHARTEVENT_OBJECT_ENDEDIT &&
      (sparam==PREFIX+"EDIT_ENTRY" || sparam==PREFIX+"EDIT_SL" || sparam==PREFIX+"EDIT_TP" ||
       sparam==PREFIX+"EDIT_LOT" || sparam==PREFIX+"EDIT_COMM"))
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
