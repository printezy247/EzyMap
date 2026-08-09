//+------------------------------------------------------------------+
//| EzyMap Lot Size Calculator                                        |
//| On-chart GUI: type Pair, Capital, SL Distance (points), click     |
//| CALCULATE, get Min / Medium / Max risk lot size options.          |
//+------------------------------------------------------------------+
#property copyright "EzyMap"
#property version   "2.00"
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
input color  InpMinRiskColor     = C'52,211,176';
input color  InpMedRiskColor     = C'237,185,58';
input color  InpMaxRiskColor     = C'235,72,96';
input color  InpErrorColor       = C'235,72,96';

#define PRODUCT_NAME "EzyMap Lot Size Calculator"
string PREFIX="EZLOT_";

int PX=14;   // panel x
int PY=38;   // panel y
int PW=332;  // panel width
int PH=372;  // panel height

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
   SetCommon(n,true);
}

void MakeButton(string suffix,int x,int y,int w,int h,string text)
{
   string n=PREFIX+suffix;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,InpButtonColor);
   ObjectSetInteger(0,n,OBJPROP_COLOR,InpButtonTextColor);
   ObjectSetInteger(0,n,OBJPROP_BORDER_COLOR,InpButtonColor);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,10);
   ObjectSetString(0,n,OBJPROP_FONT,"Arial Bold");
   ObjectSetString(0,n,OBJPROP_TEXT,text);
   ObjectSetInteger(0,n,OBJPROP_STATE,false);
   SetCommon(n,true);
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
void BuildGUI()
{
   MakePanel();

   MakeLabel("TITLE",26,48,"EZYMAP LOT SIZE CALCULATOR",InpAccentColor,11,true);
   MakeLabel("SUB",26,68,"Fill in the 3 fields, then click CALCULATE",InpTextColor,8,false);

   MakeLabel("LBL_PAIR",26,92,"PAIR (SYMBOL)",InpTextColor,8,false);
   MakeEdit("EDIT_PAIR",26,108,280,26,_Symbol);

   MakeLabel("LBL_CAP",26,142,"CAPITAL / BALANCE ($)",InpTextColor,8,false);
   MakeEdit("EDIT_CAPITAL",26,158,280,26,DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2));

   MakeLabel("LBL_SL",26,192,"STOP LOSS DISTANCE (POINTS)",InpTextColor,8,false);
   MakeEdit("EDIT_SL",26,208,280,26,"200");

   MakeButton("BTN_CALC",26,242,280,32,"CALCULATE LOT SIZE");

   MakeLabel("RES_HEAD",26,286,"RESULTS",InpTextColor,9,true);
   MakeLabel("RES_MIN",26,304,"",InpMinRiskColor,9,false);
   MakeLabel("RES_MED",26,322,"",InpMedRiskColor,9,false);
   MakeLabel("RES_MAX",26,340,"",InpMaxRiskColor,9,false);
   MakeLabel("RES_NOTE",26,358,"Enter values above and press CALCULATE.",InpTextColor,8,false);
}

//----------------------------- Calculation ---------------------------
void DoCalculate()
{
   string pair=TrimBoth(GetEditText("EDIT_PAIR"));
   StringToUpper(pair);
   if(pair=="") pair=_Symbol;

   if(!SymbolSelect(pair,true))
   {
      SetLabelText("RES_MIN","",InpMinRiskColor);
      SetLabelText("RES_MED","",InpMedRiskColor);
      SetLabelText("RES_MAX","",InpMaxRiskColor);
      SetLabelText("RES_NOTE","⚠ Symbol \""+pair+"\" not found - check spelling / Market Watch.",InpErrorColor);
      ChartRedraw(0);
      return;
   }

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

   double tickValue=SymbolInfoDouble(pair,SYMBOL_TRADE_TICK_VALUE);
   double tickSize =SymbolInfoDouble(pair,SYMBOL_TRADE_TICK_SIZE);
   double point    =SymbolInfoDouble(pair,SYMBOL_POINT);
   double volMin=SymbolInfoDouble(pair,SYMBOL_VOLUME_MIN);
   double volMax=SymbolInfoDouble(pair,SYMBOL_VOLUME_MAX);
   double volStep=SymbolInfoDouble(pair,SYMBOL_VOLUME_STEP);

   if(tickValue<=0.0 || tickSize<=0.0 || point<=0.0 || volStep<=0.0)
   {
      SetLabelText("RES_NOTE","⚠ Trade specification unavailable for \""+pair+"\" - try again shortly.",InpErrorColor);
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

   string note=pair+"  •  SL "+DoubleToString(slPoints,0)+" pts  •  "+DoubleToString(moneyPerLotAtSL,2)+" "+AccountInfoString(ACCOUNT_CURRENCY)+" risk per 1.00 lot";
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
   DoCalculate();
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
   if(id==CHARTEVENT_OBJECT_CLICK && sparam==PREFIX+"BTN_CALC")
   {
      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      DoCalculate();
      return;
   }

   if(id==CHARTEVENT_OBJECT_ENDEDIT &&
      (sparam==PREFIX+"EDIT_PAIR" || sparam==PREFIX+"EDIT_CAPITAL" || sparam==PREFIX+"EDIT_SL"))
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
