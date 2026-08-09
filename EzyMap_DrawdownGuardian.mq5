//+------------------------------------------------------------------+
//| EzyMap Drawdown / Daily Loss Limit Guardian                       |
//| Prop-firm style account protection: tracks a daily loss limit    |
//| (resets each trading day) and a trailing max-drawdown limit from |
//| your account's peak equity. On breach, flattens everything and,  |
//| for the daily limit, keeps auto-closing any NEW position for the |
//| rest of the day - protects against revenge trading, not just a   |
//| one-time flatten.                                                 |
//+------------------------------------------------------------------+
#property copyright "EzyMap"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

input double InpMaxDailyLossPercent = 5.0;    // Daily loss limit (% of day-start balance/equity)
input double InpMaxOverallDDPercent = 10.0;   // Max drawdown limit (% from peak equity, trailing)
input bool   InpUseEquityForDayStart= true;   // true = day-start reference is equity, false = balance
input int    InpDailyResetHour      = 0;      // Server-time hour (0-23) that marks a new trading day
input bool   InpAutoCloseOnBreach   = true;   // Auto-flatten all positions when a limit is breached
input bool   InpLockNewTradesOnBreach=true;   // Keep auto-closing any new position for the rest of the day after a daily breach
input int    InpPollSeconds         = 2;      // How often the guardian checks account state

input color InpPanelColor       = C'7,10,14';
input color InpPanelBorderColor = C'56,65,76';
input color InpTextColor        = C'204,211,218';
input color InpAccentColor      = C'237,185,58';
input color InpSafeColor        = C'0,208,142';
input color InpWarnColor        = C'237,185,58';
input color InpDangerColor      = C'235,72,96';
input color InpNeutralBtnColor  = C'30,36,44';
input color InpNeutralTextColor = C'204,211,218';
input color InpCloseBtnColor    = C'40,14,18';
input color InpCloseBtnTextColor= C'235,72,96';

#define PRODUCT_NAME "EzyMap Drawdown Guardian"
string PREFIX="EZDD_";
string g_gvPrefix="";

int PX=14;
int PY=38;
int PW=310;
int PH=304;

double g_peakEquity=0.0;
double g_dayStartRef=0.0;
long   g_dayKey=0;
bool   g_locked=false;
bool   g_overallStopped=false;

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

   MakeLabel("TITLE",26,48,"EZYMAP DRAWDOWN GUARDIAN",InpAccentColor,10,true);
   MakeLabel("SUB",26,66,"Daily loss limit + trailing max drawdown",InpTextColor,8,false);

   MakeLabel("EQUITY",26,86,"Loading...",InpTextColor,9,false);
   MakeLabel("DAILY",26,104,"Loading...",InpTextColor,9,false);
   MakeLabel("OVERALL",26,122,"Loading...",InpTextColor,9,false);

   MakeLabel("STATUS",26,148,"Loading...",InpSafeColor,12,true);

   MakeButton("BTN_UNLOCK",26,180,280,28,"RESUME TRADING TODAY (override lock)",InpNeutralBtnColor,InpNeutralTextColor,9);
   MakeButton("BTN_RESET_BASELINE",26,212,280,28,"RESET DRAWDOWN BASELINE",InpNeutralBtnColor,InpNeutralTextColor,9);

   MakeLabel("NOTE",26,248,"Ready.",InpTextColor,8,false);
   MakeLabel("NOTE2",26,266,"",InpTextColor,8,false);
}

//----------------------------- Persistence ---------------------------
void LoadState()
{
   g_gvPrefix="EZDD_"+IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN))+"_";

   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   double balance=AccountInfoDouble(ACCOUNT_BALANCE);

   if(!GlobalVariableCheck(g_gvPrefix+"PEAK"))
      GlobalVariableSet(g_gvPrefix+"PEAK",equity);
   g_peakEquity=GlobalVariableGet(g_gvPrefix+"PEAK");

   g_overallStopped=GlobalVariableCheck(g_gvPrefix+"STOPPED") && GlobalVariableGet(g_gvPrefix+"STOPPED")!=0.0;

   long todayKey=(long)MathFloor((TimeCurrent()-InpDailyResetHour*3600)/86400.0);
   long storedKey=GlobalVariableCheck(g_gvPrefix+"DAYKEY")?(long)GlobalVariableGet(g_gvPrefix+"DAYKEY"):-1;

   if(storedKey!=todayKey)
   {
      double dayStart=InpUseEquityForDayStart?equity:balance;
      GlobalVariableSet(g_gvPrefix+"DAYKEY",(double)todayKey);
      GlobalVariableSet(g_gvPrefix+"DAYSTART",dayStart);
      GlobalVariableSet(g_gvPrefix+"LOCKED",0.0);
   }

   g_dayKey=todayKey;
   g_dayStartRef=GlobalVariableGet(g_gvPrefix+"DAYSTART");
   g_locked=GlobalVariableCheck(g_gvPrefix+"LOCKED") && GlobalVariableGet(g_gvPrefix+"LOCKED")!=0.0;
}

void SaveLocked(bool v)  { GlobalVariableSet(g_gvPrefix+"LOCKED",v?1.0:0.0); g_locked=v; }
void SaveStopped(bool v) { GlobalVariableSet(g_gvPrefix+"STOPPED",v?1.0:0.0); g_overallStopped=v; }
void SavePeak(double v)  { GlobalVariableSet(g_gvPrefix+"PEAK",v); g_peakEquity=v; }

//----------------------------- Guardian logic --------------------------
void FlattenAccount(string reason)
{
   int closed=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) continue;
      if(trade.PositionClose(ticket)) closed++;
   }
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0) continue;
      trade.OrderDelete(ticket);
   }
   SetLabelText("NOTE2",reason+" - closed "+IntegerToString(closed)+" position(s).",InpDangerColor);
   Alert(PRODUCT_NAME+": "+reason+" - flattened "+IntegerToString(closed)+" position(s).");
}

void EnforceLockIfNeeded()
{
   if(!g_overallStopped && !(g_locked && InpLockNewTradesOnBreach)) return;
   // Either the account is permanently stopped, or the daily lock forbids
   // any new trading - either way, any position that appears gets closed.
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) continue;
      trade.PositionClose(ticket);
   }
}

void RefreshGuardian()
{
   // Re-check the trading day boundary every tick, not just OnInit, so a
   // long-running attachment correctly rolls over at the reset hour.
   long todayKey=(long)MathFloor((TimeCurrent()-InpDailyResetHour*3600)/86400.0);
   if(todayKey!=g_dayKey)
   {
      double equity0=AccountInfoDouble(ACCOUNT_EQUITY);
      double balance0=AccountInfoDouble(ACCOUNT_BALANCE);
      double dayStart=InpUseEquityForDayStart?equity0:balance0;
      GlobalVariableSet(g_gvPrefix+"DAYKEY",(double)todayKey);
      GlobalVariableSet(g_gvPrefix+"DAYSTART",dayStart);
      g_dayStartRef=dayStart;
      g_dayKey=todayKey;
      SaveLocked(false);
      SetLabelText("NOTE","New trading day - daily lock reset.",InpAccentColor);
   }

   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   string cur=AccountInfoString(ACCOUNT_CURRENCY);

   if(equity>g_peakEquity) SavePeak(equity);

   double dailyLossMoney=g_dayStartRef-equity;
   double dailyLossPct=(g_dayStartRef>0.0)?dailyLossMoney/g_dayStartRef*100.0:0.0;

   double ddMoney=g_peakEquity-equity;
   double ddPct=(g_peakEquity>0.0)?ddMoney/g_peakEquity*100.0:0.0;

   SetLabelText("EQUITY","Equity: "+DoubleToString(equity,2)+" "+cur+"   Balance: "+DoubleToString(balance,2)+" "+cur,InpTextColor);

   color dailyClr=(dailyLossPct>=InpMaxDailyLossPercent)?InpDangerColor:((dailyLossPct>=InpMaxDailyLossPercent*0.7)?InpWarnColor:InpTextColor);
   SetLabelText("DAILY","Today: "+(dailyLossMoney>=0.0?"-":"+")+DoubleToString(MathAbs(dailyLossMoney),2)+" ("+DoubleToString(dailyLossPct,1)+"% / limit "+DoubleToString(InpMaxDailyLossPercent,1)+"%)",dailyClr);

   color ddClr=(ddPct>=InpMaxOverallDDPercent)?InpDangerColor:((ddPct>=InpMaxOverallDDPercent*0.7)?InpWarnColor:InpTextColor);
   SetLabelText("OVERALL","Overall DD: -"+DoubleToString(ddMoney,2)+" ("+DoubleToString(ddPct,1)+"% / limit "+DoubleToString(InpMaxOverallDDPercent,1)+"%)",ddClr);

   // Breach checks
   if(!g_overallStopped && ddPct>=InpMaxOverallDDPercent)
   {
      SaveStopped(true);
      if(InpAutoCloseOnBreach) FlattenAccount("MAX DRAWDOWN BREACHED");
   }
   if(!g_locked && !g_overallStopped && dailyLossPct>=InpMaxDailyLossPercent)
   {
      SaveLocked(true);
      if(InpAutoCloseOnBreach) FlattenAccount("DAILY LOSS LIMIT HIT");
   }

   EnforceLockIfNeeded();

   string statusTxt; color statusClr;
   if(g_overallStopped)      { statusTxt="STATUS: STOPPED - MAX DRAWDOWN BREACHED"; statusClr=InpDangerColor; }
   else if(g_locked)         { statusTxt="STATUS: LOCKED - DAILY LIMIT HIT"; statusClr=InpDangerColor; }
   else if(dailyLossPct>=InpMaxDailyLossPercent*0.7 || ddPct>=InpMaxOverallDDPercent*0.7)
                              { statusTxt="STATUS: WARNING - approaching a limit"; statusClr=InpWarnColor; }
   else                       { statusTxt="STATUS: SAFE"; statusClr=InpSafeColor; }
   SetLabelText("STATUS",statusTxt,statusClr);

   ChartRedraw(0);
}

//--------------------------- MT5 events -----------------------------
int OnInit()
{
   trade.SetAsyncMode(false);
   LoadState();
   BuildGUI();
   RefreshGuardian();
   EventSetTimer(MathMax(1,InpPollSeconds));
   ChartRedraw(0);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0,PREFIX);
   ChartRedraw(0);
}

void OnTick()
{
   RefreshGuardian();
}

void OnTimer()
{
   RefreshGuardian();
}

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id!=CHARTEVENT_OBJECT_CLICK) return;

   if(sparam==PREFIX+"BTN_CLOSE")
   {
      ExpertRemove();
      return;
   }
   if(sparam==PREFIX+"BTN_UNLOCK")
   {
      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      if(!g_locked)
      {
         SetLabelText("NOTE","No daily lock active right now.",InpTextColor);
         ChartRedraw(0);
         return;
      }
      int res=MessageBox("Manually resume trading for today, overriding the daily loss lock?\n\nThe guardian will stop auto-closing new positions until the next daily reset.\n\nAre you sure?",
                          "EzyMap Drawdown Guardian - Confirm",MB_YESNO|MB_ICONWARNING|MB_DEFBUTTON2);
      if(res==IDYES)
      {
         SaveLocked(false);
         SetLabelText("NOTE","Daily lock manually overridden - trading resumed for today.",InpWarnColor);
      }
      else
         SetLabelText("NOTE","Cancelled: resume trading.",InpTextColor);
      ChartRedraw(0);
      return;
   }
   if(sparam==PREFIX+"BTN_RESET_BASELINE")
   {
      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      int res=MessageBox("Reset the drawdown baseline to current equity?\n\nThis clears the STOPPED state if the max drawdown limit was breached, and starts trailing drawdown fresh from here.\n\nAre you sure?",
                          "EzyMap Drawdown Guardian - Confirm",MB_YESNO|MB_ICONWARNING|MB_DEFBUTTON2);
      if(res==IDYES)
      {
         SavePeak(AccountInfoDouble(ACCOUNT_EQUITY));
         SaveStopped(false);
         SetLabelText("NOTE","Drawdown baseline reset to current equity.",InpAccentColor);
      }
      else
         SetLabelText("NOTE","Cancelled: reset baseline.",InpTextColor);
      ChartRedraw(0);
      return;
   }
}
//+------------------------------------------------------------------+
