//+------------------------------------------------------------------+
//| EzyMap Lot Size Calculator                                        |
//| Risk-based position sizing script. Computes a broker-safe lot     |
//| size from account risk (percent or fixed money) and a SL price.  |
//+------------------------------------------------------------------+
#property copyright "EzyMap"
#property version   "1.00"
#property script_show_inputs
#property strict

enum ELC_Direction
{
   ELC_BUY  = 0,
   ELC_SELL = 1
};

enum ELC_RiskMode
{
   ELC_RISK_PCT_BALANCE = 0,
   ELC_RISK_PCT_EQUITY  = 1,
   ELC_RISK_FIXED_MONEY = 2
};

input ELC_Direction InpDirection        = ELC_BUY;
input double        InpEntryPrice       = 0.0;   // 0 = use current market price
input double        InpStopLossPrice    = 0.0;   // required
input double        InpTakeProfitPrice  = 0.0;   // 0 = skip R:R display
input ELC_RiskMode  InpRiskMode         = ELC_RISK_PCT_BALANCE;
input double        InpRiskValue        = 1.0;   // percent (of balance/equity) or money, per InpRiskMode

input bool          InpShowPanel        = true;
input color         InpPanelColor       = C'7,10,14';
input color         InpPanelBorderColor = C'56,65,76';
input color         InpTextColor        = C'204,211,218';
input color         InpBuyColor         = C'0,208,142';
input color         InpSellColor        = C'235,72,96';
input color         InpWarnColor        = C'237,185,58';

#define PRODUCT_NAME "EzyMap Lot Size Calculator"
string PREFIX="EZLC_";

//----------------------------- Drawing ------------------------------
void DeleteObject(string suffix) { ObjectDelete(0,PREFIX+suffix); }

void ClearPanel()
{
   ObjectDelete(0,PREFIX+"PANEL");
   for(int i=0;i<12;i++)
      DeleteObject("ROW_"+IntegerToString(i));
}

void SetObjectCommon(string n)
{
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,false);
   ObjectSetInteger(0,n,OBJPROP_BACK,false);
   ObjectSetInteger(0,n,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,100);
}

void Panel(int width,int height)
{
   string n=PREFIX+"PANEL";
   if(ObjectFind(0,n)<0)
      ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);

   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,14);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,38);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,width);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,height);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,InpPanelColor);
   ObjectSetInteger(0,n,OBJPROP_BORDER_COLOR,InpPanelBorderColor);
   ObjectSetInteger(0,n,OBJPROP_COLOR,InpPanelBorderColor);
   ObjectSetInteger(0,n,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,n,OBJPROP_WIDTH,1);
   SetObjectCommon(n);
}

void Row(int row,string value,color clr,bool bold=false)
{
   string n=PREFIX+"ROW_"+IntegerToString(row);
   if(ObjectFind(0,n)<0)
      ObjectCreate(0,n,OBJ_LABEL,0,0,0);

   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,26);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,50+row*17);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,bold?9:8);
   ObjectSetString(0,n,OBJPROP_FONT,bold?"Arial Bold":"Arial");
   ObjectSetString(0,n,OBJPROP_TEXT,value);
   SetObjectCommon(n);
}

string PriceText(double v)
{
   int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   return DoubleToString(v,digits);
}

string MoneyText(double v)
{
   return DoubleToString(v,2)+" "+AccountInfoString(ACCOUNT_CURRENCY);
}

//----------------------------- Core logic ---------------------------
void OnStart()
{
   ClearPanel();

   if(!SymbolSelect(_Symbol,true))
   {
      Alert(PRODUCT_NAME+": failed to select symbol "+_Symbol);
      return;
   }

   bool isBuy=(InpDirection==ELC_BUY);
   double entry=InpEntryPrice;
   if(entry<=0.0)
      entry=isBuy?SymbolInfoDouble(_Symbol,SYMBOL_ASK):SymbolInfoDouble(_Symbol,SYMBOL_BID);

   if(InpStopLossPrice<=0.0)
   {
      string msg=PRODUCT_NAME+": set InpStopLossPrice to a valid price before running.";
      Alert(msg); Print(msg);
      return;
   }

   double sl=InpStopLossPrice;
   bool slValid=isBuy?(sl<entry):(sl>entry);
   if(!slValid)
   {
      string msg=PRODUCT_NAME+": Stop Loss is on the wrong side of Entry for a "+(isBuy?"BUY":"SELL")+" trade.";
      Alert(msg); Print(msg);
      DrawError(msg);
      return;
   }

   double tickValue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double tickSize =SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double volMin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double volMax=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double volStep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);

   if(tickValue<=0.0 || tickSize<=0.0 || volStep<=0.0)
   {
      string msg=PRODUCT_NAME+": symbol trade specification unavailable (tick value/size/volume step). Try again once the symbol is fully synced.";
      Alert(msg); Print(msg);
      DrawError(msg);
      return;
   }

   double slDistance=MathAbs(entry-sl);
   double slTicks=slDistance/tickSize;
   double moneyPerLotAtSL=slTicks*tickValue;

   double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   double equity =AccountInfoDouble(ACCOUNT_EQUITY);

   double riskMoney=0.0;
   string riskLabel="";
   if(InpRiskMode==ELC_RISK_PCT_BALANCE)
   {
      riskMoney=balance*InpRiskValue/100.0;
      riskLabel=DoubleToString(InpRiskValue,2)+"% of Balance";
   }
   else if(InpRiskMode==ELC_RISK_PCT_EQUITY)
   {
      riskMoney=equity*InpRiskValue/100.0;
      riskLabel=DoubleToString(InpRiskValue,2)+"% of Equity";
   }
   else
   {
      riskMoney=InpRiskValue;
      riskLabel="Fixed "+MoneyText(InpRiskValue);
   }

   if(riskMoney<=0.0 || moneyPerLotAtSL<=0.0)
   {
      string msg=PRODUCT_NAME+": computed risk amount or SL distance is zero - check inputs.";
      Alert(msg); Print(msg);
      DrawError(msg);
      return;
   }

   double rawLots=riskMoney/moneyPerLotAtSL;
   double lots=MathFloor(rawLots/volStep)*volStep;
   bool belowMin=false, cappedMax=false;
   if(lots<volMin) { lots=volMin; belowMin=true; }
   if(lots>volMax) { lots=volMax; cappedMax=true; }
   lots=NormalizeDouble(lots,8);

   double actualRisk=lots*moneyPerLotAtSL;
   double actualRiskPctBalance=(balance>0.0)?actualRisk/balance*100.0:0.0;

   bool haveTP=(InpTakeProfitPrice>0.0);
   double rr=0.0, rewardMoney=0.0;
   if(haveTP)
   {
      double tp=InpTakeProfitPrice;
      double rewardDistance=MathAbs(tp-entry);
      rr=(slDistance>0.0)?rewardDistance/slDistance:0.0;
      rewardMoney=lots*(rewardDistance/tickSize)*tickValue;
   }

   int slPoints=(int)MathRound(slDistance/_Point);

   Print("=== ",PRODUCT_NAME," ===");
   Print(_Symbol," ",(isBuy?"BUY":"SELL")," Entry=",PriceText(entry)," SL=",PriceText(sl)," SL(points)=",slPoints);
   Print("Risk: ",riskLabel," = ",MoneyText(riskMoney));
   Print("Lot size: ",DoubleToString(lots,2)," (raw ",DoubleToString(rawLots,2),", step ",DoubleToString(volStep,2),", min ",DoubleToString(volMin,2),", max ",DoubleToString(volMax,2),")");
   Print("Actual risk at this lot size: ",MoneyText(actualRisk)," (",DoubleToString(actualRiskPctBalance,2),"% of balance)");
   if(haveTP) Print("R:R = 1:",DoubleToString(rr,2)," | Potential reward: ",MoneyText(rewardMoney));
   if(belowMin) Print("WARNING: raw lot size was below broker minimum - risk floored up to ",DoubleToString(volMin,2)," lots.");
   if(cappedMax) Print("WARNING: raw lot size exceeded broker maximum - capped to ",DoubleToString(volMax,2)," lots.");

   if(InpShowPanel)
      DrawPanel(isBuy,entry,sl,slPoints,riskLabel,riskMoney,rawLots,lots,actualRisk,actualRiskPctBalance,haveTP,rr,rewardMoney,belowMin,cappedMax);

   string alertMsg=PRODUCT_NAME+"\n"+_Symbol+" "+(isBuy?"BUY":"SELL")+"\nLOT SIZE: "+DoubleToString(lots,2)+"\nRISK: "+MoneyText(actualRisk)+" ("+DoubleToString(actualRiskPctBalance,2)+"%)";
   if(haveTP) alertMsg+="\nR:R  1:"+DoubleToString(rr,2);
   Alert(alertMsg);

   ChartRedraw(0);
}

void DrawError(string msg)
{
   if(!InpShowPanel) return;
   Panel(340,50);
   Row(0,"LOT SIZE CALCULATOR - ERROR",InpWarnColor,true);
   Row(1,msg,InpTextColor,false);
   ChartRedraw(0);
}

void DrawPanel(bool isBuy,double entry,double sl,int slPoints,string riskLabel,double riskMoney,
               double rawLots,double lots,double actualRisk,double actualRiskPct,
               bool haveTP,double rr,double rewardMoney,bool belowMin,bool cappedMax)
{
   color accent=isBuy?InpBuyColor:InpSellColor;
   int rows=8+(haveTP?1:0)+(belowMin||cappedMax?1:0);
   Panel(340,34+rows*17);

   int r=0;
   Row(r++,"LOT SIZE CALCULATOR • "+(isBuy?"BUY":"SELL"),accent,true);
   Row(r++,_Symbol,InpTextColor,false);
   Row(r++,"ENTRY  "+PriceText(entry),InpTextColor,false);
   Row(r++,"SL     "+PriceText(sl)+"  ("+IntegerToString(slPoints)+" pts)",InpSellColor,false);
   Row(r++,"RISK   "+riskLabel,InpTextColor,false);
   Row(r++,"LOT SIZE   "+DoubleToString(lots,2),accent,true);
   Row(r++,"ACTUAL RISK  "+MoneyText(actualRisk)+" ("+DoubleToString(actualRiskPct,2)+"%)",InpTextColor,false);
   if(haveTP)
      Row(r++,"R:R  1:"+DoubleToString(rr,2)+"   REWARD "+MoneyText(rewardMoney),InpBuyColor,false);
   if(belowMin)
      Row(r++,"⚠ FLOORED TO BROKER MIN LOT",InpWarnColor,true);
   else if(cappedMax)
      Row(r++,"⚠ CAPPED TO BROKER MAX LOT",InpWarnColor,true);
   Row(r++,"EZYMAP • SCRIPTS",InpTextColor,false);

   for(int i=rows;i<12;i++)
      DeleteObject("ROW_"+IntegerToString(i));
}
//+------------------------------------------------------------------+
