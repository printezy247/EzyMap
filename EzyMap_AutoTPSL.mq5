//+------------------------------------------------------------------+
//| EzyMap Auto TP/SL                                                  |
//| Watches for any new position without SL/TP set (one-click        |
//| trading, manual market execution, layering) and automatically    |
//| applies TP/SL at fixed pip distances from the entry price.       |
//+------------------------------------------------------------------+
#property copyright "EzyMap"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

input double InpTPPips           = 30.0;   // Take Profit distance (pips)
input double InpSLPips           = 50.0;   // Stop Loss distance (pips)
input bool   InpApplyToAllSymbols= false;  // false = only positions on this chart's symbol
input long   InpMagicFilter      = 0;      // 0 = any magic number, otherwise only that magic
input int    InpPollSeconds      = 1;

input color InpPanelColor       = C'7,10,14';
input color InpPanelBorderColor = C'56,65,76';
input color InpTextColor        = C'204,211,218';
input color InpAccentColor      = C'237,185,58';
input color InpEditBgColor      = C'20,24,30';
input color InpEditTextColor    = C'255,255,255';
input color InpButtonColor      = C'0,208,142';
input color InpButtonTextColor  = C'7,10,14';
input color InpNeutralBtnColor  = C'30,36,44';
input color InpNeutralTextColor = C'204,211,218';
input color InpPauseColor       = C'237,185,58';
input color InpResumeColor      = C'0,208,142';
input color InpErrorColor       = C'235,72,96';
input color InpCloseBtnColor    = C'40,14,18';
input color InpCloseBtnTextColor= C'235,72,96';

#define PRODUCT_NAME "EzyMap Auto TP/SL"
string PREFIX="EZATS_";

int PX=14;
int PY=38;
int PW=310;
int PH=344;

double g_tpPips=30.0;
double g_slPips=50.0;
bool   g_paused=false;
int    g_appliedCount=0;

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

// Standard broker-adaptive pip detection: brokers that quote an extra
// "fractional pip" digit (3 or 5 decimal places - e.g. gold at 2015.325,
// EURUSD at 1.08123) use 1 pip = 10 x point; everything else (2 or 4
// decimal places) uses 1 pip = 1 x point. This adapts correctly per
// symbol/broker instead of guessing from the symbol name.
double PipSize(string sym)
{
   int digits=(int)SymbolInfoInteger(sym,SYMBOL_DIGITS);
   double point=SymbolInfoDouble(sym,SYMBOL_POINT);
   if(point<=0.0) return 0.0;
   return (digits==3 || digits==5)?point*10.0:point;
}

//------------------------------ Build GUI ----------------------------
void BuildGUI()
{
   MakeRect("PANEL",PX,PY,PW,PH,InpPanelColor,InpPanelBorderColor,50);
   MakeButton("BTN_CLOSE",PX+PW-38,PY+6,30,26,"✕",InpCloseBtnColor,InpCloseBtnTextColor,11);

   MakeLabel("TITLE",26,48,"EZYMAP AUTO TP/SL",InpAccentColor,10,true);
   MakeLabel("SUB",26,66,InpApplyToAllSymbols?"Scope: ALL SYMBOLS":"Scope: "+_Symbol+" only",InpTextColor,8,false);

   MakeLabel("LBL_TP",26,86,"TAKE PROFIT (pips)",InpTextColor,8,false);
   MakeEdit("EDIT_TP",26,100,280,22,DoubleToString(g_tpPips,1));

   MakeLabel("LBL_SL",26,126,"STOP LOSS (pips)",InpTextColor,8,false);
   MakeEdit("EDIT_SL",26,140,280,22,DoubleToString(g_slPips,1));

   MakeButton("BTN_APPLY_SETTINGS",26,166,280,26,"APPLY TP/SL SETTINGS",InpButtonColor,InpButtonTextColor,9);

   MakeLabel("STATUS",26,200,"Loading...",InpTextColor,9,true);
   MakeButton("BTN_PAUSE",26,222,280,26,"PAUSE AUTO TP/SL",InpPauseColor,InpPanelColor,9);

   MakeLabel("COUNT",26,256,"Auto-set this session: 0",InpTextColor,8,false);
   MakeButton("BTN_APPLY_EXISTING",26,278,280,26,"APPLY TO EXISTING POSITIONS NOW",InpNeutralBtnColor,InpNeutralTextColor,9);

   MakeLabel("NOTE",26,312,"Watching for new positions...",InpTextColor,8,false);
}

void RefreshStatusLabels()
{
   SetLabelText("STATUS","Status: "+(g_paused?"PAUSED":"ACTIVE (TP "+DoubleToString(g_tpPips,1)+"p / SL "+DoubleToString(g_slPips,1)+"p)"),g_paused?InpPauseColor:InpAccentColor);
   if(g_paused)
      MakeButton("BTN_PAUSE",26,222,280,26,"RESUME AUTO TP/SL",InpResumeColor,InpPanelColor,9);
   else
      MakeButton("BTN_PAUSE",26,222,280,26,"PAUSE AUTO TP/SL",InpPauseColor,InpPanelColor,9);
   SetLabelText("COUNT","Auto-set this session: "+IntegerToString(g_appliedCount),InpTextColor);
}

//----------------------------- Core logic -----------------------------
bool ApplyAutoSLTP(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return false;

   double curSL=PositionGetDouble(POSITION_SL);
   double curTP=PositionGetDouble(POSITION_TP);
   if(curSL!=0.0 || curTP!=0.0) return false; // already managed - never override

   string sym=PositionGetString(POSITION_SYMBOL);
   if(!InpApplyToAllSymbols && sym!=_Symbol) return false;
   if(InpMagicFilter!=0 && (long)PositionGetInteger(POSITION_MAGIC)!=InpMagicFilter) return false;

   ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double pip=PipSize(sym);
   int digits=(int)SymbolInfoInteger(sym,SYMBOL_DIGITS);
   double point=SymbolInfoDouble(sym,SYMBOL_POINT);

   double tp,sl;
   if(type==POSITION_TYPE_BUY) { tp=entry+g_tpPips*pip; sl=entry-g_slPips*pip; }
   else                        { tp=entry-g_tpPips*pip; sl=entry+g_slPips*pip; }

   // The broker enforces a minimum SL/TP distance from entry
   // (SYMBOL_TRADE_STOPS_LEVEL, in points) - widen to meet it instead of
   // letting PositionModify fail outright on a too-tight request.
   long stopsLevelPts=(long)SymbolInfoInteger(sym,SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance=stopsLevelPts*point;
   bool widened=false;

   if(minDistance>0.0)
   {
      if(type==POSITION_TYPE_BUY)
      {
         if(entry-sl<minDistance) { sl=entry-minDistance; widened=true; }
         if(tp-entry<minDistance) { tp=entry+minDistance; widened=true; }
      }
      else
      {
         if(sl-entry<minDistance) { sl=entry+minDistance; widened=true; }
         if(entry-tp<minDistance) { tp=entry-minDistance; widened=true; }
      }
   }

   tp=NormalizeDouble(tp,digits);
   sl=NormalizeDouble(sl,digits);

   if(trade.PositionModify(ticket,sl,tp))
   {
      g_appliedCount++;
      string widenNote=widened?("  (widened to broker min "+IntegerToString(stopsLevelPts)+" pts)"):"";
      SetLabelText("NOTE","Set SL/TP on "+sym+" #"+IntegerToString((long)ticket)+"  SL "+DoubleToString(sl,digits)+"  TP "+DoubleToString(tp,digits)+widenNote,InpAccentColor);
      RefreshStatusLabels();
      return true;
   }

   SetLabelText("NOTE","⚠ Failed on "+sym+" #"+IntegerToString((long)ticket)+" - "+trade.ResultRetcodeDescription()+" (broker min distance: "+IntegerToString(stopsLevelPts)+" pts)",InpErrorColor);
   return false;
}

void ScanAndApply()
{
   if(g_paused) return;
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) continue;
      ApplyAutoSLTP(ticket);
   }
   ChartRedraw(0);
}

//--------------------------- MT5 events -----------------------------
int OnInit()
{
   trade.SetAsyncMode(false);
   g_tpPips=InpTPPips;
   g_slPips=InpSLPips;
   g_paused=false;
   g_appliedCount=0;

   BuildGUI();
   RefreshStatusLabels();
   ScanAndApply();
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
   ScanAndApply();
}

void OnTimer()
{
   ScanAndApply();
}

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id!=CHARTEVENT_OBJECT_CLICK) return;

   if(sparam==PREFIX+"BTN_CLOSE")
   {
      ExpertRemove();
      return;
   }
   if(sparam==PREFIX+"BTN_APPLY_SETTINGS")
   {
      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      double newTP=StringToDouble(TrimBoth(GetEditText("EDIT_TP")));
      double newSL=StringToDouble(TrimBoth(GetEditText("EDIT_SL")));
      if(newTP<=0.0 || newSL<=0.0)
      {
         SetLabelText("NOTE","⚠ TP and SL pips must both be greater than 0.",InpErrorColor);
         ChartRedraw(0);
         return;
      }
      g_tpPips=newTP;
      g_slPips=newSL;
      RefreshStatusLabels();
      SetLabelText("NOTE","Settings applied - new positions will use TP "+DoubleToString(g_tpPips,1)+"p / SL "+DoubleToString(g_slPips,1)+"p.",InpAccentColor);
      ChartRedraw(0);
      return;
   }
   if(sparam==PREFIX+"BTN_PAUSE")
   {
      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      g_paused=!g_paused;
      RefreshStatusLabels();
      SetLabelText("NOTE",g_paused?"Paused - new positions will be left alone.":"Resumed - watching for new positions.",InpTextColor);
      ChartRedraw(0);
      return;
   }
   if(sparam==PREFIX+"BTN_APPLY_EXISTING")
   {
      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);

      int candidateCount=0;
      for(int i=0;i<PositionsTotal();i++)
      {
         ulong ticket=PositionGetTicket(i);
         if(ticket==0 || !PositionSelectByTicket(ticket)) continue;
         if(PositionGetDouble(POSITION_SL)!=0.0 || PositionGetDouble(POSITION_TP)!=0.0) continue;
         if(!InpApplyToAllSymbols && PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
         if(InpMagicFilter!=0 && (long)PositionGetInteger(POSITION_MAGIC)!=InpMagicFilter) continue;
         candidateCount++;
      }

      if(candidateCount==0)
      {
         SetLabelText("NOTE","No existing positions without SL/TP found.",InpTextColor);
         ChartRedraw(0);
         return;
      }

      string question="Apply TP "+DoubleToString(g_tpPips,1)+"p / SL "+DoubleToString(g_slPips,1)+"p to "+
                       IntegerToString(candidateCount)+" existing position(s) that currently have no SL/TP set?\n\nAre you sure?";
      int res=MessageBox(question,"EzyMap Auto TP/SL - Confirm",MB_YESNO|MB_ICONWARNING|MB_DEFBUTTON2);
      if(res!=IDYES)
      {
         SetLabelText("NOTE","Cancelled: apply to existing positions.",InpTextColor);
         ChartRedraw(0);
         return;
      }

      int done=0;
      for(int i=0;i<PositionsTotal();i++)
      {
         ulong ticket=PositionGetTicket(i);
         if(ticket==0) continue;
         if(ApplyAutoSLTP(ticket)) done++;
      }
      SetLabelText("NOTE","Applied SL/TP to "+IntegerToString(done)+" of "+IntegerToString(candidateCount)+" existing position(s).",InpAccentColor);
      ChartRedraw(0);
      return;
   }
}
//+------------------------------------------------------------------+
