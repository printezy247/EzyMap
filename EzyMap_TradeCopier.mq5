//+------------------------------------------------------------------+
//| EzyMap Trade Copier (local, single terminal)                      |
//| Mirrors direction/volume of positions on a Source symbol onto a  |
//| Destination symbol, scaled by a multiplier or fixed lot size.    |
//| Configure Source/Destination symbols in the Inputs tab.          |
//+------------------------------------------------------------------+
#property copyright "EzyMap"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
#include <EzyMapLicense.mqh>

#define SCRIPT_ID "EzyMap_TradeCopier"
CTrade trade;

enum ELotMode
{
   LOT_MULTIPLIER = 0,   // Destination lot = Source lot x Multiplier
   LOT_FIXED       = 1   // Destination lot = fixed size, ignores source volume
};

input string InpSourceSymbol   = "";        // Source symbol ("" = the chart this EA is attached to)
input long   InpSourceMagic    = 0;         // Only copy source positions with this magic (0 = any)
input string InpDestSymbol     = "";        // Destination symbol - REQUIRED, must match Market Watch exactly
input ELotMode InpLotMode      = LOT_MULTIPLIER;
input double InpLotMultiplier  = 1.0;
input double InpFixedLot       = 0.01;
input long   InpMagicForCopies = 990099;    // Magic tag applied to copied trades
input int    InpPollSeconds    = 1;         // How often the copier re-checks for changes

input color InpPanelColor       = C'7,10,14';
input color InpPanelBorderColor = C'56,65,76';
input color InpTextColor        = C'204,211,218';
input color InpAccentColor      = C'237,185,58';
input color InpOkColor          = C'0,208,142';
input color InpErrorColor       = C'235,72,96';
input color InpPauseColor       = C'237,185,58';
input color InpResumeColor      = C'0,208,142';
input color InpCloseBtnColor    = C'40,14,18';
input color InpCloseBtnTextColor= C'235,72,96';

#define PRODUCT_NAME "EzyMap Trade Copier"
string PREFIX="EZCOPY_";

int PX=14;
int PY=38;
int PW=310;
int PH=260;

string g_sourceSymbol="";
bool g_paused=false;

ulong g_sourceTickets[];
ulong g_destTickets[];

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

   MakeLabel("TITLE",26,48,"EZYMAP TRADE COPIER",InpAccentColor,10,true);
   MakeLabel("SUB",26,66,"Local, single-terminal - Source → Destination",InpTextColor,8,false);

   string lotTxt=(InpLotMode==LOT_MULTIPLIER)?("x"+DoubleToString(InpLotMultiplier,2)+" of source volume"):("fixed "+DoubleToString(InpFixedLot,2)+" lot");
   MakeLabel("SOURCE",26,86,"SOURCE: "+g_sourceSymbol+"  (magic "+(InpSourceMagic==0?"any":IntegerToString(InpSourceMagic))+")",InpTextColor,9,false);
   MakeLabel("DEST",26,104,"DEST:   "+InpDestSymbol+"  ("+lotTxt+")",InpTextColor,9,false);

   MakeLabel("ACTIVE",26,128,"Loading...",InpAccentColor,9,true);

   MakeButton("BTN_PAUSE",26,152,280,30,"PAUSE COPYING",InpPauseColor,InpPanelColor,10);

   MakeLabel("NOTE",26,192,"Ready.",InpTextColor,8,false);
}

void RefreshPauseButton()
{
   if(g_paused)
      MakeButton("BTN_PAUSE",26,152,280,30,"RESUME COPYING",InpResumeColor,InpPanelColor,10);
   else
      MakeButton("BTN_PAUSE",26,152,280,30,"PAUSE COPYING",InpPauseColor,InpPanelColor,10);
}

//------------------------------ Mapping ------------------------------
int FindMappingIndex(ulong srcTicket)
{
   for(int i=0;i<ArraySize(g_sourceTickets);i++)
      if(g_sourceTickets[i]==srcTicket) return i;
   return -1;
}

void AddMapping(ulong srcTicket,ulong destTicket)
{
   int n=ArraySize(g_sourceTickets);
   ArrayResize(g_sourceTickets,n+1);
   ArrayResize(g_destTickets,n+1);
   g_sourceTickets[n]=srcTicket;
   g_destTickets[n]=destTicket;
}

void RemoveMappingAt(int idx)
{
   int n=ArraySize(g_sourceTickets);
   for(int i=idx;i<n-1;i++)
   {
      g_sourceTickets[i]=g_sourceTickets[i+1];
      g_destTickets[i]=g_destTickets[i+1];
   }
   ArrayResize(g_sourceTickets,n-1);
   ArrayResize(g_destTickets,n-1);
}

void GetSourcePositionTickets(ulong &out[])
{
   ArrayResize(out,0);
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=g_sourceSymbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)==InpMagicForCopies) continue; // never copy our own copies
      if(InpSourceMagic!=0 && PositionGetInteger(POSITION_MAGIC)!=InpSourceMagic) continue;

      int n=ArraySize(out);
      ArrayResize(out,n+1);
      out[n]=ticket;
   }
}

//----------------------------- Sync logic -----------------------------
void SyncCopies()
{
   if(g_paused) return;

   ulong currentSource[];
   GetSourcePositionTickets(currentSource);

   // Closed on source -> close the matching copy
   for(int i=ArraySize(g_sourceTickets)-1;i>=0;i--)
   {
      bool stillOpen=false;
      for(int j=0;j<ArraySize(currentSource);j++)
         if(currentSource[j]==g_sourceTickets[i]) { stillOpen=true; break; }

      if(!stillOpen)
      {
         ulong destTicket=g_destTickets[i];
         if(PositionSelectByTicket(destTicket))
            trade.PositionClose(destTicket);
         SetLabelText("NOTE","Closed copy for source #"+IntegerToString((long)g_sourceTickets[i]),InpTextColor);
         RemoveMappingAt(i);
      }
   }

   // New on source -> open a matching copy
   for(int j=0;j<ArraySize(currentSource);j++)
   {
      ulong srcTicket=currentSource[j];
      if(FindMappingIndex(srcTicket)>=0) continue;
      if(!PositionSelectByTicket(srcTicket)) continue;

      ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double srcVol=PositionGetDouble(POSITION_VOLUME);

      double destVol=(InpLotMode==LOT_MULTIPLIER)?(srcVol*InpLotMultiplier):InpFixedLot;

      double volStep=SymbolInfoDouble(InpDestSymbol,SYMBOL_VOLUME_STEP);
      double volMin=SymbolInfoDouble(InpDestSymbol,SYMBOL_VOLUME_MIN);
      double volMax=SymbolInfoDouble(InpDestSymbol,SYMBOL_VOLUME_MAX);
      if(volStep<=0.0) continue;

      destVol=MathFloor(destVol/volStep)*volStep;
      destVol=MathMax(volMin,MathMin(volMax,destVol));
      if(destVol<volMin) continue;

      trade.SetExpertMagicNumber(InpMagicForCopies);
      bool ok=(type==POSITION_TYPE_BUY)?trade.Buy(destVol,InpDestSymbol):trade.Sell(destVol,InpDestSymbol);

      if(ok)
      {
         ulong destTicket=trade.ResultOrder();
         AddMapping(srcTicket,destTicket);
         SetLabelText("NOTE","Opened "+(type==POSITION_TYPE_BUY?"BUY":"SELL")+" "+DoubleToString(destVol,2)+" "+InpDestSymbol+" mirroring source #"+IntegerToString((long)srcTicket),InpOkColor);
      }
      else
      {
         SetLabelText("NOTE","⚠ Copy failed for source #"+IntegerToString((long)srcTicket)+" - "+trade.ResultRetcodeDescription()+" (#"+IntegerToString(trade.ResultRetcode())+")",InpErrorColor);
      }
   }

   SetLabelText("ACTIVE","Active copies: "+IntegerToString(ArraySize(g_sourceTickets))+(g_paused?"   (PAUSED)":""),g_paused?InpErrorColor:InpAccentColor);
   ChartRedraw(0);
}

//--------------------------- MT5 events -----------------------------
int OnInit()
{
   g_sourceSymbol=(InpSourceSymbol=="")?_Symbol:InpSourceSymbol;

   if(!SymbolSelect(g_sourceSymbol,true))
   {
      Alert(PRODUCT_NAME+": source symbol \""+g_sourceSymbol+"\" not found - check spelling against Market Watch.");
      return INIT_FAILED;
   }
   if(InpDestSymbol=="" || !SymbolSelect(InpDestSymbol,true))
   {
      Alert(PRODUCT_NAME+": set InpDestSymbol to a valid Market Watch symbol before attaching.");
      return INIT_FAILED;
   }
   if(InpDestSymbol==g_sourceSymbol)
   {
      Alert(PRODUCT_NAME+": Source and Destination symbols must be different.");
      return INIT_FAILED;
   }

   if(!EzyMapLicenseGate(SCRIPT_ID,PREFIX,PRODUCT_NAME))
   {
      EventSetTimer(MathMax(1,InpPollSeconds));
      ChartRedraw(0);
      return INIT_SUCCEEDED;
   }

   trade.SetAsyncMode(false);
   g_paused=false;
   ArrayResize(g_sourceTickets,0);
   ArrayResize(g_destTickets,0);

   BuildGUI();
   SyncCopies();
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
   if(!EzyMapLicenseRecheck(SCRIPT_ID,PREFIX,PRODUCT_NAME)) return;
   SyncCopies();
}

void OnTimer()
{
   if(!EzyMapLicenseRecheck(SCRIPT_ID,PREFIX,PRODUCT_NAME)) return;
   SyncCopies();
}

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id!=CHARTEVENT_OBJECT_CLICK) return;

   if(EzyMapIsLicenseCloseClick(PREFIX,sparam))
   {
      ExpertRemove();
      return;
   }

   if(sparam==PREFIX+"BTN_CLOSE")
   {
      ExpertRemove();
      return;
   }
   if(sparam==PREFIX+"BTN_PAUSE")
   {
      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      g_paused=!g_paused;
      RefreshPauseButton();
      SetLabelText("NOTE",g_paused?"Copying paused - existing copies left open.":"Copying resumed.",InpTextColor);
      ChartRedraw(0);
      return;
   }
}
//+------------------------------------------------------------------+
