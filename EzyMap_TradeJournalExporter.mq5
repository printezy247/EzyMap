//+------------------------------------------------------------------+
//| EzyMap Trade Journal Exporter                                      |
//| On-chart panel: pick lookback days + optional symbol filter,      |
//| tap EXPORT NOW - writes closed trade history to CSV and a styled |
//| HTML report (MQL5\Files folder), with R-multiples and duration.  |
//+------------------------------------------------------------------+
#property copyright "EzyMap"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

#include <EzyMapLicense.mqh>
#define SCRIPT_ID "EzyMap_TradeJournalExporter"

input color InpPanelColor       = C'7,10,14';
input color InpPanelBorderColor = C'56,65,76';
input color InpTextColor        = C'204,211,218';
input color InpAccentColor      = C'237,185,58';
input color InpEditBgColor      = C'20,24,30';
input color InpEditTextColor    = C'255,255,255';
input color InpButtonColor      = C'0,208,142';
input color InpButtonTextColor  = C'7,10,14';
input color InpToggleOnColor    = C'0,208,142';
input color InpToggleOffColor   = C'30,36,44';
input color InpToggleOffText    = C'204,211,218';
input color InpErrorColor       = C'235,72,96';
input color InpCloseBtnColor    = C'40,14,18';
input color InpCloseBtnTextColor= C'235,72,96';

#define PRODUCT_NAME "EzyMap Trade Journal Exporter"
string PREFIX="EZTJ_";

int PX=14;
int PY=38;
int PW=320;
int PH=288;

bool g_exportCSV=true;
bool g_exportHTML=true;

struct TradeRow
{
   ulong    posId;
   string   symbol;
   string   direction;
   double   volume;
   datetime openTime;
   double   openPrice;
   datetime closeTime;
   double   closePrice;
   double   sl;
   int      durationMin;
   double   profit;
   double   swap;
   double   commission;
   double   netPL;
   double   rMultiple;
   bool     hasR;
};

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

//------------------------------ Build GUI ----------------------------
void BuildGUI()
{
   MakeRect("PANEL",PX,PY,PW,PH,InpPanelColor,InpPanelBorderColor,50);
   MakeButton("BTN_CLOSE",PX+PW-38,PY+6,30,26,"✕",InpCloseBtnColor,InpCloseBtnTextColor,11);

   MakeLabel("TITLE",26,48,"EZYMAP TRADE JOURNAL EXPORTER",InpAccentColor,10,true);
   MakeLabel("SUB",26,66,"Exports closed trades to CSV + HTML report",InpTextColor,8,false);

   MakeLabel("LBL_DAYS",26,86,"LOOKBACK (days)",InpTextColor,8,false);
   MakeEdit("EDIT_DAYS",26,100,280,22,"90");

   MakeLabel("LBL_SYM",26,126,"SYMBOL FILTER (blank = all symbols)",InpTextColor,8,false);
   MakeEdit("EDIT_SYM",26,140,280,22,"");

   MakeButton("BTN_TOGGLE_CSV",26,166,136,26,"CSV: ON",InpToggleOnColor,InpPanelColor,9);
   MakeButton("BTN_TOGGLE_HTML",170,166,136,26,"HTML: ON",InpToggleOnColor,InpPanelColor,9);

   MakeButton("BTN_EXPORT",26,198,280,30,"EXPORT NOW",InpButtonColor,InpButtonTextColor,10);

   MakeLabel("NOTE",26,238,"Ready.",InpTextColor,8,false);
   MakeLabel("NOTE2",26,256," ",InpTextColor,8,false);
}

void RefreshToggleButtons()
{
   MakeButton("BTN_TOGGLE_CSV",26,166,136,26,g_exportCSV?"CSV: ON":"CSV: OFF",g_exportCSV?InpToggleOnColor:InpToggleOffColor,g_exportCSV?InpPanelColor:InpToggleOffText,9);
   MakeButton("BTN_TOGGLE_HTML",170,166,136,26,g_exportHTML?"HTML: ON":"HTML: OFF",g_exportHTML?InpToggleOnColor:InpToggleOffColor,g_exportHTML?InpPanelColor:InpToggleOffText,9);
}

//----------------------------- Trade reconstruction --------------------
bool ComputeTradeRow(ulong posId,TradeRow &row)
{
   double sumProfit=0.0,sumSwap=0.0,sumComm=0.0;
   datetime openTime=0,closeTime=0;
   double openPrice=0.0,closePrice=0.0,volume=0.0;
   string symbol="",direction="";
   ulong entryOrderTicket=0;
   bool foundIn=false,foundOut=false;

   int total=HistoryDealsTotal();
   for(int i=0;i<total;i++)
   {
      ulong dealTicket=HistoryDealGetTicket(i);
      if(dealTicket==0) continue;
      if((ulong)HistoryDealGetInteger(dealTicket,DEAL_POSITION_ID)!=posId) continue;

      ENUM_DEAL_ENTRY entry=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket,DEAL_ENTRY);
      sumProfit+=HistoryDealGetDouble(dealTicket,DEAL_PROFIT);
      sumSwap+=HistoryDealGetDouble(dealTicket,DEAL_SWAP);
      sumComm+=HistoryDealGetDouble(dealTicket,DEAL_COMMISSION);

      if(entry==DEAL_ENTRY_IN && !foundIn)
      {
         foundIn=true;
         symbol=HistoryDealGetString(dealTicket,DEAL_SYMBOL);
         ENUM_DEAL_TYPE dtype=(ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket,DEAL_TYPE);
         direction=(dtype==DEAL_TYPE_BUY)?"BUY":"SELL";
         openTime=(datetime)HistoryDealGetInteger(dealTicket,DEAL_TIME);
         openPrice=HistoryDealGetDouble(dealTicket,DEAL_PRICE);
         volume=HistoryDealGetDouble(dealTicket,DEAL_VOLUME);
         entryOrderTicket=HistoryDealGetInteger(dealTicket,DEAL_ORDER);
      }
      else if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY)
      {
         datetime t=(datetime)HistoryDealGetInteger(dealTicket,DEAL_TIME);
         if(t>=closeTime)
         {
            closeTime=t;
            closePrice=HistoryDealGetDouble(dealTicket,DEAL_PRICE);
            foundOut=true;
         }
      }
   }

   if(!foundIn) return false;

   row.posId=posId;
   row.symbol=symbol;
   row.direction=direction;
   row.volume=volume;
   row.openTime=openTime;
   row.openPrice=openPrice;
   row.closeTime=foundOut?closeTime:0;
   row.closePrice=foundOut?closePrice:0.0;
   row.profit=sumProfit;
   row.swap=sumSwap;
   row.commission=sumComm;
   row.netPL=sumProfit+sumSwap+sumComm;
   row.durationMin=foundOut?(int)((closeTime-openTime)/60):0;
   row.sl=0.0;
   row.hasR=false;
   row.rMultiple=0.0;

   if(entryOrderTicket!=0 && HistoryOrderSelect(entryOrderTicket))
   {
      double sl=HistoryOrderGetDouble(entryOrderTicket,ORDER_SL);
      if(sl>0.0)
      {
         row.sl=sl;
         double tickValue=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE);
         double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
         if(tickSize>0.0 && tickValue>0.0)
         {
            double riskMoney=MathAbs(openPrice-sl)/tickSize*tickValue*volume;
            if(riskMoney>0.0)
            {
               row.rMultiple=row.netPL/riskMoney;
               row.hasR=true;
            }
         }
      }
   }
   return true;
}

//----------------------------- Export logic ---------------------------
string SafeTimestamp()
{
   string ts=TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS);
   StringReplace(ts,".","-");
   StringReplace(ts,":","-");
   StringReplace(ts," ","_");
   return ts;
}

int WriteCSV(TradeRow &rows[],int count,string fileName)
{
   int fh=FileOpen(fileName,FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(fh==INVALID_HANDLE) return -1;

   FileWrite(fh,"Ticket","Symbol","Direction","Volume","OpenTime","OpenPrice","CloseTime","ClosePrice","SL","DurationMin","Profit","Swap","Commission","NetPL","RMultiple");
   for(int i=0;i<count;i++)
   {
      TradeRow r=rows[i];
      int digits=(int)SymbolInfoInteger(r.symbol,SYMBOL_DIGITS);
      FileWrite(fh,
         IntegerToString((long)r.posId),
         r.symbol,
         r.direction,
         DoubleToString(r.volume,2),
         TimeToString(r.openTime,TIME_DATE|TIME_SECONDS),
         DoubleToString(r.openPrice,digits),
         r.closeTime>0?TimeToString(r.closeTime,TIME_DATE|TIME_SECONDS):"OPEN",
         r.closeTime>0?DoubleToString(r.closePrice,digits):"",
         r.sl>0?DoubleToString(r.sl,digits):"",
         IntegerToString(r.durationMin),
         DoubleToString(r.profit,2),
         DoubleToString(r.swap,2),
         DoubleToString(r.commission,2),
         DoubleToString(r.netPL,2),
         r.hasR?DoubleToString(r.rMultiple,2):"N/A"
      );
   }
   FileClose(fh);
   return count;
}

int WriteHTML(TradeRow &rows[],int count,string fileName,int days,string symFilter)
{
   int fh=FileOpen(fileName,FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(fh==INVALID_HANDLE) return -1;

   double totalNet=0.0; int wins=0, losses=0;
   for(int i=0;i<count;i++)
   {
      totalNet+=rows[i].netPL;
      if(rows[i].netPL>0) wins++;
      else if(rows[i].netPL<0) losses++;
   }
   double winRate=(count>0)?(double)wins/count*100.0:0.0;

   string html="";
   html+="<html><head><meta charset='UTF-8'><title>EzyMap Trade Journal</title><style>";
   html+="body{background:#07090d;color:#c8d3da;font-family:Arial,sans-serif;padding:20px;}";
   html+="h1{color:#edb93a;} .sub{color:#8894a0;margin-bottom:20px;}";
   html+=".summary{background:#0c1015;border:1px solid #38414c;border-radius:8px;padding:14px;margin-bottom:20px;display:flex;gap:30px;}";
   html+=".summary div{font-size:14px;} .summary b{font-size:18px;display:block;color:#edb93a;}";
   html+="table{border-collapse:collapse;width:100%;font-size:13px;}";
   html+="th{background:#12161c;color:#edb93a;text-align:left;padding:8px;border-bottom:1px solid #38414c;}";
   html+="td{padding:7px 8px;border-bottom:1px solid #1c222a;}";
   html+=".win{color:#00d08e;} .loss{color:#eb4860;}";
   html+="</style></head><body>";
   html+="<h1>EzyMap Trade Journal</h1>";
   html+="<div class='sub'>Last "+IntegerToString(days)+" day(s)"+(symFilter!=""?"  •  filter: "+symFilter:"")+"  •  generated "+TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS)+"</div>";
   html+="<div class='summary'>";
   html+="<div>TRADES<b>"+IntegerToString(count)+"</b></div>";
   html+="<div>WIN RATE<b>"+DoubleToString(winRate,1)+"%</b></div>";
   html+="<div>WINS / LOSSES<b>"+IntegerToString(wins)+" / "+IntegerToString(losses)+"</b></div>";
   html+="<div>NET P/L<b>"+(totalNet>=0.0?"+":"")+DoubleToString(totalNet,2)+" "+AccountInfoString(ACCOUNT_CURRENCY)+"</b></div>";
   html+="</div>";
   html+="<table><tr><th>Ticket</th><th>Symbol</th><th>Dir</th><th>Vol</th><th>Open</th><th>Close</th><th>Duration</th><th>Net P/L</th><th>R</th></tr>";

   for(int i=0;i<count;i++)
   {
      TradeRow r=rows[i];
      int digits=(int)SymbolInfoInteger(r.symbol,SYMBOL_DIGITS);
      string rowClass=(r.netPL>0)?"win":((r.netPL<0)?"loss":"");
      html+="<tr>";
      html+="<td>"+IntegerToString((long)r.posId)+"</td>";
      html+="<td>"+r.symbol+"</td>";
      html+="<td>"+r.direction+"</td>";
      html+="<td>"+DoubleToString(r.volume,2)+"</td>";
      html+="<td>"+TimeToString(r.openTime,TIME_DATE|TIME_MINUTES)+" @ "+DoubleToString(r.openPrice,digits)+"</td>";
      html+="<td>"+(r.closeTime>0?TimeToString(r.closeTime,TIME_DATE|TIME_MINUTES)+" @ "+DoubleToString(r.closePrice,digits):"OPEN")+"</td>";
      html+="<td>"+(r.durationMin>0?IntegerToString(r.durationMin)+" min":"-")+"</td>";
      html+="<td class='"+rowClass+"'>"+(r.netPL>=0.0?"+":"")+DoubleToString(r.netPL,2)+"</td>";
      html+="<td>"+(r.hasR?DoubleToString(r.rMultiple,2):"N/A")+"</td>";
      html+="</tr>";
   }
   html+="</table></body></html>";

   FileWriteString(fh,html);
   FileClose(fh);
   return count;
}

void ExportJournal()
{
   int days=(int)StringToInteger(TrimBoth(GetEditText("EDIT_DAYS")));
   if(days<=0)
   {
      SetLabelText("NOTE","⚠ Lookback days must be greater than 0.",InpErrorColor);
      ChartRedraw(0);
      return;
   }
   if(!g_exportCSV && !g_exportHTML)
   {
      SetLabelText("NOTE","⚠ Turn on at least one of CSV / HTML.",InpErrorColor);
      ChartRedraw(0);
      return;
   }

   string symFilter=TrimBoth(GetEditText("EDIT_SYM"));
   StringToUpper(symFilter);

   datetime fromTime=TimeCurrent()-days*86400;
   if(!HistorySelect(fromTime,TimeCurrent()))
   {
      SetLabelText("NOTE","⚠ Could not load trade history.",InpErrorColor);
      ChartRedraw(0);
      return;
   }

   ulong posIds[];
   ArrayResize(posIds,0);
   int totalDeals=HistoryDealsTotal();

   for(int i=0;i<totalDeals;i++)
   {
      ulong dealTicket=HistoryDealGetTicket(i);
      if(dealTicket==0) continue;

      ENUM_DEAL_ENTRY entry=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket,DEAL_ENTRY);
      if(entry!=DEAL_ENTRY_IN) continue;

      ENUM_DEAL_TYPE dtype=(ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket,DEAL_TYPE);
      if(dtype!=DEAL_TYPE_BUY && dtype!=DEAL_TYPE_SELL) continue;

      if(symFilter!="")
      {
         string sym=HistoryDealGetString(dealTicket,DEAL_SYMBOL);
         string symUpper=sym; StringToUpper(symUpper);
         if(StringFind(symUpper,symFilter)<0) continue;
      }

      ulong posId=HistoryDealGetInteger(dealTicket,DEAL_POSITION_ID);

      bool dup=false;
      for(int k=0;k<ArraySize(posIds);k++)
         if(posIds[k]==posId) { dup=true; break; }
      if(dup) continue;

      int n=ArraySize(posIds);
      ArrayResize(posIds,n+1);
      posIds[n]=posId;
   }

   if(ArraySize(posIds)==0)
   {
      SetLabelText("NOTE","No trades found in the last "+IntegerToString(days)+" day(s)"+(symFilter!=""?" for "+symFilter:"")+".",InpTextColor);
      ChartRedraw(0);
      return;
   }

   TradeRow rows[];
   ArrayResize(rows,0);
   for(int i=0;i<ArraySize(posIds);i++)
   {
      TradeRow r;
      if(ComputeTradeRow(posIds[i],r))
      {
         int n=ArraySize(rows);
         ArrayResize(rows,n+1);
         rows[n]=r;
      }
   }

   string ts=SafeTimestamp();
   string baseName="EzyMap_Journal_"+ts;
   string resultTxt="";

   if(g_exportCSV)
   {
      string csvName=baseName+".csv";
      int r=WriteCSV(rows,ArraySize(rows),csvName);
      resultTxt+=(r>=0)?("CSV: "+csvName+"  "):("CSV FAILED  ");
   }
   if(g_exportHTML)
   {
      string htmlName=baseName+".html";
      int r=WriteHTML(rows,ArraySize(rows),htmlName,days,symFilter);
      resultTxt+=(r>=0)?("HTML: "+htmlName):("HTML FAILED");
   }

   SetLabelText("NOTE","Exported "+IntegerToString(ArraySize(rows))+" trade(s).",InpAccentColor);
   SetLabelText("NOTE2",resultTxt+"  (in MQL5\\Files)",InpTextColor);
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

   g_exportCSV=true;
   g_exportHTML=true;
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
   if(id!=CHARTEVENT_OBJECT_CLICK) return;

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
   if(sparam==PREFIX+"BTN_TOGGLE_CSV")
   {
      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      g_exportCSV=!g_exportCSV;
      RefreshToggleButtons();
      ChartRedraw(0);
      return;
   }
   if(sparam==PREFIX+"BTN_TOGGLE_HTML")
   {
      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      g_exportHTML=!g_exportHTML;
      RefreshToggleButtons();
      ChartRedraw(0);
      return;
   }
   if(sparam==PREFIX+"BTN_EXPORT")
   {
      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      ExportJournal();
      return;
   }
}

int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],const double &open[],const double &high[],const double &low[],const double &close[],const long &tick_volume[],const long &volume[],const int &spread[])
{
   return rates_total;
}
//+------------------------------------------------------------------+
