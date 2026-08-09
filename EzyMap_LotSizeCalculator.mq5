//+------------------------------------------------------------------+
//| EzyMap Lot Size Calculator                                        |
//| On-chart GUI: pick a pair from the buttons, type Capital and SL   |
//| Distance (points), click CALCULATE - get Min/Med/Max risk lots.  |
//+------------------------------------------------------------------+
#property copyright "EzyMap"
#property version   "3.00"
#property indicator_chart_window
#property indicator_plots 0

input double InpMinRiskPercent = 0.5;   // Min risk tier (% of capital)
input double InpMedRiskPercent = 1.0;   // Medium risk tier (% of capital)
input double InpMaxRiskPercent = 2.0;   // Max risk tier (% of capital)

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
input color  InpMinRiskColor     = C'52,211,176';
input color  InpMedRiskColor     = C'237,185,58';
input color  InpMaxRiskColor     = C'235,72,96';
input color  InpErrorColor       = C'235,72,96';

#define PRODUCT_NAME "EzyMap Lot Size Calculator"
string PREFIX="EZLOT_";

int PX=14;   // panel x
int PY=38;   // panel y
int PW=332;  // panel width
int PH=500;  // panel height

// Instrument picker: friendly label -> alias key used to resolve the
// broker's actual symbol name (handles suffixes like XAUUSD.sc, BTCUSD-ECN, etc).
string g_aliasKeys[11]   = {"GBPUSD","EURUSD","USDJPY","USDCAD","AUDUSD","USDCHF","XAUUSD","XAGUSD","OIL","US30","BTCUSD"};
string g_aliasLabels[11] = {"GBP/USD","EUR/USD","USD/JPY","USD/CAD","AUD/USD","USD/CHF","XAU/USD","XAG/USD","OIL","US30","BTC/USD"};
int g_selectedIndex=-1;

//----------------------------- Helpers ------------------------------
void SetCommon(string n,bool selectable)
{
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,selectable);
   ObjectSetInteger(0,n,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,false);
   ObjectSetInteger(0,n,OBJPROP_BACK,false);
   ObjectSetInteger(0,n,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,100);
}

void MakePanel()
{
   string n=PREFIX+"PANEL";
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,PX);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,PY);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,PW);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,PH);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,InpPanelColor);
   ObjectSetInteger(0,n,OBJPROP_BORDER_COLOR,InpPanelBorderColor);
   ObjectSetInteger(0,n,OBJPROP_COLOR,InpPanelBorderColor);
   ObjectSetInteger(0,n,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,n,OBJPROP_WIDTH,1);
   SetCommon(n,false);
}

void MakeLabel(string suffix,int x,int y,string text,color clr,int size=9,bool bold=false)
{
   string n=PREFIX+suffix;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,size);
   ObjectSetString(0,n,OBJPROP_FONT,bold?"Arial Bold":"Arial");
   ObjectSetString(0,n,OBJPROP_TEXT,text);
   SetCommon(n,false);
}

void SetLabelText(string suffix,string text,color clr)
{
   string n=PREFIX+suffix;
   if(ObjectFind(0,n)<0) return;
   ObjectSetString(0,n,OBJPROP_TEXT,text);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
}

// NOTE: SELECTABLE must be FALSE on edit/button objects. If it is TRUE,
// the first click just "selects" the object (drag handles) instead of
// focusing it for typing/clicking - this was the root cause of the
// "can't type a value" issue.
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
   SetCommon(n,false);
}

void MakeButton(string suffix,int x,int y,int w,int h,string text,color bg,color txt,int size=10)
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
   SetCommon(n,false);
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

//------------------------------ Build GUI ----------------------------
void SymBtnCoords(int idx,int &x,int &y)
{
   int col=idx%3, row=idx/3;
   int colW=88, gap=8, startX=26, startY=108, rowH=32;
   x=startX+col*(colW+gap);
   y=startY+row*rowH;
}

void BuildGUI()
{
   MakePanel();

   MakeLabel("TITLE",26,48,"EZYMAP LOT SIZE CALCULATOR",InpAccentColor,11,true);
   MakeLabel("SUB",26,68,"1) Pick a pair   2) Fill Capital & SL   3) Calculate",InpTextColor,8,false);

   MakeLabel("LBL_PAIR",26,90,"SELECT PAIR",InpTextColor,8,false);
   for(int i=0;i<11;i++)
   {
      int x,y; SymBtnCoords(i,x,y);
      MakeButton("BTN_SYM_"+IntegerToString(i),x,y,88,26,g_aliasLabels[i],InpSymBtnColor,InpSymBtnTextColor,8);
   }
   MakeLabel("SEL_NOTE",26,244,"No pair selected yet.",InpTextColor,8,false);

   MakeLabel("LBL_CAP",26,268,"CAPITAL / BALANCE ($)",InpTextColor,8,false);
   MakeEdit("EDIT_CAPITAL",26,284,280,26,DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2));

   MakeLabel("LBL_SL",26,318,"STOP LOSS DISTANCE (POINTS)",InpTextColor,8,false);
   MakeEdit("EDIT_SL",26,334,280,26,"200");

   MakeButton("BTN_CALC",26,368,280,32,"CALCULATE LOT SIZE",InpButtonColor,InpButtonTextColor,10);

   MakeLabel("RES_HEAD",26,412,"RESULTS",InpTextColor,9,true);
   MakeLabel("RES_MIN",26,430,"",InpMinRiskColor,9,false);
   MakeLabel("RES_MED",26,448,"",InpMedRiskColor,9,false);
   MakeLabel("RES_MAX",26,466,"",InpMaxRiskColor,9,false);
   MakeLabel("RES_NOTE",26,484,"Pick a pair above to begin.",InpTextColor,8,false);
}

void RefreshSymButtons()
{
   for(int i=0;i<11;i++)
   {
      string n=PREFIX+"BTN_SYM_"+IntegerToString(i);
      bool sel=(i==g_selectedIndex);
      ObjectSetInteger(0,n,OBJPROP_BGCOLOR,sel?InpSymBtnSelColor:InpSymBtnColor);
      ObjectSetInteger(0,n,OBJPROP_COLOR,sel?InpSymBtnSelText:InpSymBtnTextColor);
   }
}

//------------------------- Symbol resolution -------------------------
// Different brokers suffix/rename symbols (XAUUSD.sc, BTCUSD-ECN, US30.cash...).
// Resolve the alias to whatever matching symbol the broker actually offers.
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

   // Pass 1: exact match
   for(int i=0;i<total;i++)
   {
      string name=SymbolName(i,false);
      string upperName=name; StringToUpper(upperName);
      for(int c=0;c<ArraySize(upperCandidates);c++)
         if(upperName==upperCandidates[c]) return name;
   }
   // Pass 2: name starts with candidate
   for(int i=0;i<total;i++)
   {
      string name=SymbolName(i,false);
      string upperName=name; StringToUpper(upperName);
      for(int c=0;c<ArraySize(upperCandidates);c++)
         if(StringFind(upperName,upperCandidates[c])==0) return name;
   }
   // Pass 3: name contains candidate anywhere
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
void DoCalculate()
{
   if(g_selectedIndex<0)
   {
      SetLabelText("RES_NOTE","⚠ Please select a pair from the buttons above first.",InpErrorColor);
      ChartRedraw(0);
      return;
   }

   string alias=g_aliasKeys[g_selectedIndex];
   string symbol=ResolveSymbol(alias);

   if(symbol=="" || !SymbolSelect(symbol,true))
   {
      SetLabelText("SEL_NOTE","⚠ Could not find a broker symbol for "+g_aliasLabels[g_selectedIndex]+".",InpErrorColor);
      SetLabelText("RES_MIN","",InpMinRiskColor);
      SetLabelText("RES_MED","",InpMedRiskColor);
      SetLabelText("RES_MAX","",InpMaxRiskColor);
      SetLabelText("RES_NOTE","Add it to Market Watch manually and try again.",InpErrorColor);
      ChartRedraw(0);
      return;
   }

   SetLabelText("SEL_NOTE","Selected: "+g_aliasLabels[g_selectedIndex]+"  →  broker symbol: "+symbol,InpAccentColor);

   double capital=StringToDouble(TrimBoth(GetEditText("EDIT_CAPITAL")));
   double slPoints=StringToDouble(TrimBoth(GetEditText("EDIT_SL")));

   if(capital<=0.0 || slPoints<=0.0)
   {
      SetLabelText("RES_MIN","",InpMinRiskColor);
      SetLabelText("RES_MED","",InpMedRiskColor);
      SetLabelText("RES_MAX","",InpMaxRiskColor);
      SetLabelText("RES_NOTE","⚠ Capital and SL Distance must both be greater than 0.",InpErrorColor);
      ChartRedraw(0);
      return;
   }

   double tickValue=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE);
   double tickSize =SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   double point    =SymbolInfoDouble(symbol,SYMBOL_POINT);
   double volMin=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
   double volMax=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
   double volStep=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);

   if(tickValue<=0.0 || tickSize<=0.0 || point<=0.0 || volStep<=0.0)
   {
      SetLabelText("RES_NOTE","⚠ Trade specification unavailable for "+symbol+" - try again shortly.",InpErrorColor);
      ChartRedraw(0);
      return;
   }

   double moneyPerPointPerLot=(tickValue/tickSize)*point;
   double moneyPerLotAtSL=moneyPerPointPerLot*slPoints;
   if(moneyPerLotAtSL<=0.0)
   {
      SetLabelText("RES_NOTE","⚠ Could not compute risk per lot - check SL distance.",InpErrorColor);
      ChartRedraw(0);
      return;
   }

   int decimals=VolumeDecimals(volStep);
   string warn="";
   string minTxt=BuildTierText("MIN RISK",InpMinRiskPercent,capital,moneyPerLotAtSL,volMin,volMax,volStep,decimals,warn);
   string medTxt=BuildTierText("MED RISK",InpMedRiskPercent,capital,moneyPerLotAtSL,volMin,volMax,volStep,decimals,warn);
   string maxTxt=BuildTierText("MAX RISK",InpMaxRiskPercent,capital,moneyPerLotAtSL,volMin,volMax,volStep,decimals,warn);

   SetLabelText("RES_MIN",minTxt,InpMinRiskColor);
   SetLabelText("RES_MED",medTxt,InpMedRiskColor);
   SetLabelText("RES_MAX",maxTxt,InpMaxRiskColor);

   string note="SL "+DoubleToString(slPoints,0)+" pts  •  "+DoubleToString(moneyPerLotAtSL,2)+" "+AccountInfoString(ACCOUNT_CURRENCY)+" risk per 1.00 lot";
   if(warn!="") note+="   "+warn;
   SetLabelText("RES_NOTE",note,warn!=""?InpErrorColor:InpTextColor);

   ChartRedraw(0);
}

string BuildTierText(string label,double riskPercent,double capital,double moneyPerLotAtSL,
                      double volMin,double volMax,double volStep,int decimals,string &warnOut)
{
   double riskMoney=capital*riskPercent/100.0;
   double rawLots=riskMoney/moneyPerLotAtSL;
   double lots=MathFloor(rawLots/volStep)*volStep;

   string flag="";
   if(lots<volMin) { lots=volMin; flag=" (min lot)"; warnOut=" ⚠ some tiers floored to broker min lot."; }
   if(lots>volMax) { lots=volMax; flag=" (max lot)"; }
   lots=NormalizeDouble(lots,8);

   double actualRisk=lots*moneyPerLotAtSL;

   return label+" ("+DoubleToString(riskPercent,2)+"%):  "+DoubleToString(lots,decimals)+" lots"+flag+
          "   ~"+DoubleToString(actualRisk,2)+" "+AccountInfoString(ACCOUNT_CURRENCY);
}

//--------------------------- MT5 events -----------------------------
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME,PRODUCT_NAME);
   BuildGUI();
   RefreshSymButtons();
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
      if(sparam==PREFIX+"BTN_CALC")
      {
         ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
         DoCalculate();
         return;
      }

      for(int i=0;i<11;i++)
      {
         string n=PREFIX+"BTN_SYM_"+IntegerToString(i);
         if(sparam==n)
         {
            ObjectSetInteger(0,n,OBJPROP_STATE,false);
            g_selectedIndex=i;
            RefreshSymButtons();
            DoCalculate();
            return;
         }
      }
   }

   if(id==CHARTEVENT_OBJECT_ENDEDIT &&
      (sparam==PREFIX+"EDIT_CAPITAL" || sparam==PREFIX+"EDIT_SL"))
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
