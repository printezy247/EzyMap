//+------------------------------------------------------------------+
//| EzyMap Bulk Close / Partial Close                                  |
//| On-chart trade management panel: close all / profitable / losing /|
//| this-symbol positions, partial close, delete pending orders.      |
//|                                                                    |
//| Built as an EXPERT ADVISOR (needs Algo Trading enabled) since it  |
//| actually closes real positions - PositionClose/OrderDelete are    |
//| trade-context functions indicators cannot call. Every destructive |
//| action requires a native confirmation dialog before executing.    |
//+------------------------------------------------------------------+
#property copyright "EzyMap"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
#include <EzyMapLicense.mqh>
CTrade trade;

#define SCRIPT_ID "EzyMap_BulkClose"

input int InpRefreshSeconds = 2;   // Live summary refresh interval (seconds)

input color InpPanelColor       = C'7,10,14';
input color InpPanelBorderColor = C'56,65,76';
input color InpTextColor        = C'204,211,218';
input color InpAccentColor      = C'237,185,58';
input color InpEditBgColor      = C'20,24,30';
input color InpEditTextColor    = C'255,255,255';
input color InpDangerColor      = C'235,72,96';
input color InpProfitColor      = C'0,208,142';
input color InpLossColor        = C'235,130,110';
input color InpNeutralBtnColor  = C'30,36,44';
input color InpNeutralTextColor = C'204,211,218';
input color InpErrorColor       = C'235,72,96';
input color InpCloseBtnColor    = C'40,14,18';
input color InpCloseBtnTextColor= C'235,72,96';

#define PRODUCT_NAME "EzyMap Bulk Close"
string PREFIX="EZBC_";

int PX=14;
int PY=38;
int PW=310;
int PH=522;

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

//------------------------------ Build GUI ----------------------------
void BuildGUI()
{
   MakeRect("PANEL",PX,PY,PW,PH,InpPanelColor,InpPanelBorderColor,50);
   MakeButton("BTN_CLOSE",PX+PW-38,PY+6,30,26,"✕",InpCloseBtnColor,InpCloseBtnTextColor,11);

   MakeLabel("TITLE",26,48,"EZYMAP BULK CLOSE",InpAccentColor,10,true);
   MakeLabel("SUB",26,66,"Trade management - confirms before closing",InpTextColor,8,false);

   MakeLabel("ACCOUNT_MODE",26,84,"Loading...",InpTextColor,8,false);
   MakeLabel("SUMMARY",26,102,"Loading...",InpTextColor,9,true);

   MakeButton("BTN_CLOSE_ALL",26,124,280,30,"CLOSE ALL POSITIONS (ALL SYMBOLS)",InpDangerColor,InpPanelColor,9);
   MakeButton("BTN_CLOSE_PROFIT",26,160,280,28,"CLOSE ALL PROFITABLE",InpProfitColor,InpPanelColor,9);
   MakeButton("BTN_CLOSE_LOSS",26,192,280,28,"CLOSE ALL LOSING",InpLossColor,InpPanelColor,9);
   MakeButton("BTN_CLOSE_SYMBOL",26,224,280,28,"CLOSE THIS SYMBOL ONLY",InpAccentColor,InpPanelColor,9);

   MakeLabel("LBL_PCT",26,260,"PARTIAL CLOSE % (this symbol)",InpTextColor,8,false);
   MakeEdit("EDIT_PCT",26,274,280,22,"50");
   MakeButton("BTN_PARTIAL",26,300,280,28,"PARTIAL CLOSE THIS SYMBOL",InpNeutralBtnColor,InpNeutralTextColor,9);

   MakeButton("BTN_DELETE_PENDING",26,336,280,28,"DELETE ALL PENDING ORDERS",InpNeutralBtnColor,InpNeutralTextColor,9);

   MakeLabel("LBL_LAYERS_HEAD",26,372,"LAYERS ON "+_Symbol,InpTextColor,8,true);
   MakeLabel("LAYER_COUNTS",26,388,"Loading...",InpTextColor,9,false);

   MakeLabel("LBL_LAYER_N",26,412,"LAYERS TO CLOSE (BUY=high first, SELL=low first)",InpTextColor,8,false);
   MakeEdit("EDIT_LAYER_COUNT",26,426,280,22,"1");
   MakeButton("BTN_CLOSE_BUY_LAYERS",26,452,136,28,"CLOSE BUY LAYERS",InpProfitColor,InpPanelColor,9);
   MakeButton("BTN_CLOSE_SELL_LAYERS",170,452,136,28,"CLOSE SELL LAYERS",InpLossColor,InpPanelColor,9);

   MakeLabel("NOTE",26,488,_Symbol+" • ready.",InpTextColor,8,false);
}

bool IsNettingAccount()
{
   return (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE)==ACCOUNT_MARGIN_MODE_RETAIL_NETTING;
}

void RefreshAccountModeBanner()
{
   if(IsNettingAccount())
      SetLabelText("ACCOUNT_MODE","⚠ NETTING account - same-direction trades merge into ONE ticket per symbol, layers won't separate.",InpErrorColor);
   else
      SetLabelText("ACCOUNT_MODE","Hedging account - each trade keeps its own ticket.",InpTextColor);
}

//----------------------------- Live summary ---------------------------
void RefreshSummary()
{
   RefreshAccountModeBanner();

   int count=0;
   double totalPL=0.0;
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      count++;
      totalPL+=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
   }

   color clr=(totalPL>0.0)?InpProfitColor:(totalPL<0.0?InpLossColor:InpTextColor);
   string txt="Open Positions: "+IntegerToString(count)+"   Floating P/L: "+(totalPL>=0.0?"+":"")+DoubleToString(totalPL,2)+" "+AccountInfoString(ACCOUNT_CURRENCY);
   SetLabelText("SUMMARY",txt,clr);

   RefreshLayerCounts();
   ChartRedraw(0);
}

void RefreshLayerCounts()
{
   int buyN=0, sellN=0;
   double buyVol=0.0, sellVol=0.0;
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;

      ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double vol=PositionGetDouble(POSITION_VOLUME);
      if(type==POSITION_TYPE_BUY)  { buyN++;  buyVol+=vol; }
      if(type==POSITION_TYPE_SELL) { sellN++; sellVol+=vol; }
   }

   string txt="BUY: "+IntegerToString(buyN)+" layer(s), "+DoubleToString(buyVol,2)+" lot   •   SELL: "+IntegerToString(sellN)+" layer(s), "+DoubleToString(sellVol,2)+" lot";
   SetLabelText("LAYER_COUNTS",txt,InpTextColor);
}

//----------------------------- Trade actions ---------------------------
// mode: 0=all, 1=profitable only, 2=losing only
// symbolFilter: "" = all symbols, otherwise only that symbol
int ClosePositions(int mode,string symbolFilter,double &sumClosedPL)
{
   int closed=0;
   sumClosedPL=0.0;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) continue;
      if(!PositionSelectByTicket(ticket)) continue;

      if(symbolFilter!="" && PositionGetString(POSITION_SYMBOL)!=symbolFilter) continue;

      double net=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      if(mode==1 && net<=0.0) continue;
      if(mode==2 && net>=0.0) continue;

      if(trade.PositionClose(ticket))
      {
         closed++;
         sumClosedPL+=net;
      }
   }
   return closed;
}

int CountMatching(int mode,string symbolFilter,double &sumPL)
{
   int n=0;
   sumPL=0.0;
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(symbolFilter!="" && PositionGetString(POSITION_SYMBOL)!=symbolFilter) continue;

      double net=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      if(mode==1 && net<=0.0) continue;
      if(mode==2 && net>=0.0) continue;

      n++;
      sumPL+=net;
   }
   return n;
}

void DoClose(int mode,string symbolFilter,string actionLabel)
{
   double previewPL=0.0;
   int previewCount=CountMatching(mode,symbolFilter,previewPL);

   if(previewCount==0)
   {
      SetLabelText("NOTE","Nothing to close for: "+actionLabel,InpTextColor);
      ChartRedraw(0);
      return;
   }

   string question=actionLabel+"\n\n"+IntegerToString(previewCount)+" position(s), net P/L "+
                    (previewPL>=0.0?"+":"")+DoubleToString(previewPL,2)+" "+AccountInfoString(ACCOUNT_CURRENCY)+
                    "\n\nAre you sure?";
   int res=MessageBox(question,"EzyMap Bulk Close - Confirm",MB_YESNO|MB_ICONWARNING|MB_DEFBUTTON2);
   if(res!=IDYES)
   {
      SetLabelText("NOTE","Cancelled: "+actionLabel,InpTextColor);
      ChartRedraw(0);
      return;
   }

   double sumClosedPL=0.0;
   int closed=ClosePositions(mode,symbolFilter,sumClosedPL);
   SetLabelText("NOTE","Closed "+IntegerToString(closed)+" position(s), net "+(sumClosedPL>=0.0?"+":"")+DoubleToString(sumClosedPL,2)+" "+AccountInfoString(ACCOUNT_CURRENCY),
                sumClosedPL>=0.0?InpProfitColor:InpLossColor);
   RefreshSummary();
}

void DoPartialClose()
{
   double pct=StringToDouble(TrimBoth(GetEditText("EDIT_PCT")));
   if(pct<=0.0 || pct>=100.0)
   {
      SetLabelText("NOTE","⚠ Partial close % must be between 0 and 100.",InpErrorColor);
      ChartRedraw(0);
      return;
   }

   int matchCount=0;
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol) matchCount++;
   }

   if(matchCount==0)
   {
      SetLabelText("NOTE","No open positions on "+_Symbol+" to partially close.",InpTextColor);
      ChartRedraw(0);
      return;
   }

   string question="Partially close "+DoubleToString(pct,0)+"% of "+IntegerToString(matchCount)+" position(s) on "+_Symbol+"?\n\nAre you sure?";
   int res=MessageBox(question,"EzyMap Bulk Close - Confirm",MB_YESNO|MB_ICONWARNING|MB_DEFBUTTON2);
   if(res!=IDYES)
   {
      SetLabelText("NOTE","Cancelled: partial close.",InpTextColor);
      ChartRedraw(0);
      return;
   }

   int done=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;

      string sym=PositionGetString(POSITION_SYMBOL);
      double vol=PositionGetDouble(POSITION_VOLUME);
      double volStep=SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP);
      double volMin=SymbolInfoDouble(sym,SYMBOL_VOLUME_MIN);
      if(volStep<=0.0) continue;

      double closeVol=MathFloor((vol*pct/100.0)/volStep)*volStep;
      if(closeVol<volMin || closeVol>=vol) continue;

      if(trade.PositionClosePartial(ticket,closeVol))
         done++;
   }

   SetLabelText("NOTE","Partially closed "+IntegerToString(done)+" position(s) on "+_Symbol+".",InpAccentColor);
   RefreshSummary();
}

void DoDeletePending()
{
   int total=OrdersTotal();
   if(total==0)
   {
      SetLabelText("NOTE","No pending orders to delete.",InpTextColor);
      ChartRedraw(0);
      return;
   }

   string question="Delete ALL "+IntegerToString(total)+" pending order(s) across all symbols?\n\nAre you sure?";
   int res=MessageBox(question,"EzyMap Bulk Close - Confirm",MB_YESNO|MB_ICONWARNING|MB_DEFBUTTON2);
   if(res!=IDYES)
   {
      SetLabelText("NOTE","Cancelled: delete pending orders.",InpTextColor);
      ChartRedraw(0);
      return;
   }

   int deleted=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0) continue;
      if(trade.OrderDelete(ticket)) deleted++;
   }

   SetLabelText("NOTE","Deleted "+IntegerToString(deleted)+" pending order(s).",InpAccentColor);
   ChartRedraw(0);
}

//----------------------------- Layer close ---------------------------
// Collects every open position of 'type' on the current symbol and
// sorts the tickets by open price - ascending (lowest first) or
// descending (highest first) per 'highestFirst' - using a simple
// selection sort; position counts here are small (layering stacks,
// not hundreds of positions) so this stays fast.
int CollectLayerTickets(ENUM_POSITION_TYPE type,bool highestFirst,ulong &tickets[],double &prices[])
{
   int n=0;
   ArrayResize(tickets,0);
   ArrayResize(prices,0);

   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)!=type) continue;

      n++;
      ArrayResize(tickets,n);
      ArrayResize(prices,n);
      tickets[n-1]=ticket;
      prices[n-1]=PositionGetDouble(POSITION_PRICE_OPEN);
   }

   for(int i=0;i<n;i++)
      for(int j=i+1;j<n;j++)
      {
         bool swapNeeded=highestFirst?(prices[j]>prices[i]):(prices[j]<prices[i]);
         if(swapNeeded)
         {
            double tp=prices[i]; prices[i]=prices[j]; prices[j]=tp;
            ulong tt=tickets[i]; tickets[i]=tickets[j]; tickets[j]=tt;
         }
      }

   return n;
}

// BUY: highest-price layer first (typically the original/first layer
// before price dropped - the most underwater one). SELL: lowest-price
// layer first (typically the original/first layer before price rose).
void DoCloseLayersByCount(ENUM_POSITION_TYPE type,string label,bool highestFirst)
{
   int wantCount=(int)StringToInteger(TrimBoth(GetEditText("EDIT_LAYER_COUNT")));
   if(wantCount<=0)
   {
      SetLabelText("NOTE","⚠ Enter how many layers to close (whole number > 0).",InpErrorColor);
      ChartRedraw(0);
      return;
   }

   ulong tickets[]; double prices[];
   int total=CollectLayerTickets(type,highestFirst,tickets,prices);
   if(total==0)
   {
      SetLabelText("NOTE","No "+label+" layers open on "+_Symbol+".",InpTextColor);
      ChartRedraw(0);
      return;
   }

   int closeCount=MathMin(wantCount,total);

   double sumPL=0.0, sumVol=0.0;
   for(int i=0;i<closeCount;i++)
   {
      if(!PositionSelectByTicket(tickets[i])) continue;
      sumPL+=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      sumVol+=PositionGetDouble(POSITION_VOLUME);
   }

   string priceOrderTxt=highestFirst?"HIGHEST-price":"LOWEST-price";
   string question="Close the "+IntegerToString(closeCount)+" "+priceOrderTxt+" "+label+" layer(s) on "+_Symbol+
                    " out of "+IntegerToString(total)+" total?\n\nTotal volume: "+DoubleToString(sumVol,2)+
                    " lots\nNet P/L: "+(sumPL>=0.0?"+":"")+DoubleToString(sumPL,2)+" "+AccountInfoString(ACCOUNT_CURRENCY)+
                    "\n\nAre you sure?";
   int res=MessageBox(question,"EzyMap Bulk Close - Confirm",MB_YESNO|MB_ICONWARNING|MB_DEFBUTTON2);
   if(res!=IDYES)
   {
      SetLabelText("NOTE","Cancelled: close "+label+" layers.",InpTextColor);
      ChartRedraw(0);
      return;
   }

   int done=0;
   for(int i=0;i<closeCount;i++)
      if(trade.PositionClose(tickets[i])) done++;

   SetLabelText("NOTE","Closed "+IntegerToString(done)+" "+label+" layer(s) ("+priceOrderTxt+" first) on "+_Symbol+".",InpAccentColor);
   RefreshSummary();
}

//--------------------------- MT5 events -----------------------------
int OnInit()
{
   if(!EzyMapLicenseGate(SCRIPT_ID,PREFIX,PRODUCT_NAME))
   {
      EventSetTimer(MathMax(1,InpRefreshSeconds));
      ChartRedraw(0);
      return INIT_SUCCEEDED;
   }

   trade.SetAsyncMode(false);
   BuildGUI();
   RefreshSummary();
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

void OnTick()
{
}

void OnTimer()
{
   if(!EzyMapLicenseRecheck(SCRIPT_ID,PREFIX,PRODUCT_NAME)) return;
   RefreshSummary();
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
   if(sparam==PREFIX+"BTN_CLOSE_ALL")
   {
      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      DoClose(0,"","Close ALL open positions across ALL symbols");
      return;
   }
   if(sparam==PREFIX+"BTN_CLOSE_PROFIT")
   {
      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      DoClose(1,"","Close all PROFITABLE positions across all symbols");
      return;
   }
   if(sparam==PREFIX+"BTN_CLOSE_LOSS")
   {
      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      DoClose(2,"","Close all LOSING positions across all symbols");
      return;
   }
   if(sparam==PREFIX+"BTN_CLOSE_SYMBOL")
   {
      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      DoClose(0,_Symbol,"Close all positions on "+_Symbol+" only");
      return;
   }
   if(sparam==PREFIX+"BTN_PARTIAL")
   {
      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      DoPartialClose();
      return;
   }
   if(sparam==PREFIX+"BTN_DELETE_PENDING")
   {
      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      DoDeletePending();
      return;
   }
   if(sparam==PREFIX+"BTN_CLOSE_BUY_LAYERS")
   {
      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      DoCloseLayersByCount(POSITION_TYPE_BUY,"BUY",true);
      return;
   }
   if(sparam==PREFIX+"BTN_CLOSE_SELL_LAYERS")
   {
      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      DoCloseLayersByCount(POSITION_TYPE_SELL,"SELL",false);
      return;
   }
}
//+------------------------------------------------------------------+
