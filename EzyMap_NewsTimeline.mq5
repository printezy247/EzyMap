//+------------------------------------------------------------------+
//| EzyMap News Impact Timeline                                        |
//| Draws a thin vertical line on the chart at each upcoming news     |
//| release time relevant to the current symbol's currencies, color- |
//| coded by impact (High/Medium/Low), using MT5's built-in Economic |
//| Calendar - no external data source needed.                       |
//+------------------------------------------------------------------+
#property copyright "EzyMap"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

input int  InpLookAheadHours = 48;   // How far ahead to show upcoming news
input int  InpLookBehindHours= 2;    // How far back to still show recent news
input int  InpRefreshMinutes = 5;    // Auto-refresh interval
input bool InpShowHigh       = true;
input bool InpShowMedium     = true;
input bool InpShowLow        = false;
input bool InpShowLabels     = true;

input color InpPanelColor       = C'7,10,14';
input color InpPanelBorderColor = C'56,65,76';
input color InpTextColor        = C'204,211,218';
input color InpAccentColor      = C'237,185,58';
input color InpHighColor        = C'235,72,96';
input color InpMediumColor      = C'237,185,58';
input color InpLowColor         = C'126,137,150';
input color InpToggleOffColor   = C'30,36,44';
input color InpToggleOffText    = C'204,211,218';
input color InpErrorColor       = C'235,72,96';
input color InpCloseBtnColor    = C'40,14,18';
input color InpCloseBtnTextColor= C'235,72,96';

#define PRODUCT_NAME "EzyMap News Timeline"
string PREFIX="EZNEWS_";

int PX=14;
int PY=38;
int PW=320;
int PH=334;

bool g_showHigh=true;
bool g_showMedium=true;
bool g_showLow=false;

//----------------------------- Helpers ------------------------------
void SetCommon(string n,bool back=false,int zorder=100)
{
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,false);
   ObjectSetInteger(0,n,OBJPROP_BACK,back);
   ObjectSetInteger(0,n,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,zorder);
}

void MakeRect(string suffix,int x,int y,int w,int h,color bg,color border,int zorder=100)
{
   string n=PREFIX+suffix;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,n,OBJPROP_BORDER_COLOR,border);
   ObjectSetInteger(0,n,OBJPROP_COLOR,border);
   ObjectSetInteger(0,n,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,n,OBJPROP_WIDTH,1);
   SetCommon(n,false,zorder);
}

void MakeLabel(string suffix,int x,int y,string text,color clr,int size=9,bool bold=false,int zorder=100)
{
   string n=PREFIX+suffix;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,size);
   ObjectSetString(0,n,OBJPROP_FONT,bold?"Arial Bold":"Arial");
   ObjectSetString(0,n,OBJPROP_TEXT,text);
   SetCommon(n,false,zorder);
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
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
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
   SetCommon(n,false,zorder);
}

void MakeEdit(string suffix,int x,int y,int w,int h,string defaultText)
{
   string n=PREFIX+suffix;
   if(ObjectFind(0,n)<0)
   {
      ObjectCreate(0,n,OBJ_EDIT,0,0,0);
      ObjectSetString(0,n,OBJPROP_TEXT,defaultText);
   }
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,C'20,24,30');
   ObjectSetInteger(0,n,OBJPROP_COLOR,C'255,255,255');
   ObjectSetInteger(0,n,OBJPROP_BORDER_COLOR,InpPanelBorderColor);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,10);
   ObjectSetString(0,n,OBJPROP_FONT,"Arial");
   ObjectSetInteger(0,n,OBJPROP_ALIGN,ALIGN_CENTER);
   ObjectSetInteger(0,n,OBJPROP_READONLY,false);
   SetCommon(n,false,100);
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

//------------------------------ Currency detection ---------------------
void DetectCurrencies(string sym,string &out[])
{
   string s=sym; StringToUpper(s);
   string all[7]={"USD","EUR","GBP","JPY","AUD","CAD","CHF"};
   int n=0;
   ArrayResize(out,0);
   for(int i=0;i<7;i++)
   {
      if(StringFind(s,all[i])>=0)
      {
         ArrayResize(out,n+1);
         out[n]=all[i];
         n++;
      }
   }
   if(n==0)
   {
      // Gold/oil/indices/crypto etc without a spelled-out currency code -
      // treat as USD-relevant, since that's the dominant macro driver.
      ArrayResize(out,1);
      out[0]="USD";
   }
}

//------------------------------ Build GUI ----------------------------
void BuildGUI()
{
   MakeRect("PANEL",PX,PY,PW,PH,InpPanelColor,InpPanelBorderColor,50);
   MakeButton("BTN_CLOSE",PX+PW-38,PY+6,30,26,"✕",InpCloseBtnColor,InpCloseBtnTextColor,11);

   string curs[];
   DetectCurrencies(_Symbol,curs);
   string curTxt="";
   for(int i=0;i<ArraySize(curs);i++) curTxt+=(i>0?", ":"")+curs[i];

   MakeLabel("TITLE",26,48,"EZYMAP NEWS IMPACT TIMELINE",InpAccentColor,10,true);
   MakeLabel("SUB",26,66,_Symbol+" currencies: "+curTxt,InpTextColor,8,false);

   MakeButton("BTN_HIGH",26,86,88,24,"HIGH: ON",InpHighColor,InpPanelColor,9);
   MakeButton("BTN_MED",122,86,88,24,"MED: ON",InpMediumColor,InpPanelColor,9);
   MakeButton("BTN_LOW",218,86,88,24,"LOW: OFF",InpToggleOffColor,InpToggleOffText,9);

   MakeLabel("LBL_LOOKAHEAD",26,118,"LOOK AHEAD (hours)",InpTextColor,8,false);
   MakeEdit("EDIT_LOOKAHEAD",26,132,280,22,IntegerToString(InpLookAheadHours));

   MakeButton("BTN_REFRESH",26,162,280,26,"REFRESH NOW",InpAccentColor,InpPanelColor,10);

   MakeLabel("UPCOMING_HEAD",26,196,"NEXT EVENTS",InpTextColor,9,true);
   for(int i=0;i<5;i++)
      MakeLabel("UP_"+IntegerToString(i),26,212+i*16," ",InpTextColor,8,false);

   MakeLabel("NOTE",26,300,"Ready.",InpTextColor,8,false);
}

void RefreshToggleButtons()
{
   MakeButton("BTN_HIGH",26,86,88,24,g_showHigh?"HIGH: ON":"HIGH: OFF",g_showHigh?InpHighColor:InpToggleOffColor,g_showHigh?InpPanelColor:InpToggleOffText,9);
   MakeButton("BTN_MED",122,86,88,24,g_showMedium?"MED: ON":"MED: OFF",g_showMedium?InpMediumColor:InpToggleOffColor,g_showMedium?InpPanelColor:InpToggleOffText,9);
   MakeButton("BTN_LOW",218,86,88,24,g_showLow?"LOW: ON":"LOW: OFF",g_showLow?InpLowColor:InpToggleOffColor,g_showLow?InpPanelColor:InpToggleOffText,9);
}

//----------------------------- Impact helpers --------------------------
string ImportanceText(ENUM_CALENDAR_EVENT_IMPORTANCE imp)
{
   if(imp==CALENDAR_IMPORTANCE_HIGH) return "HIGH";
   if(imp==CALENDAR_IMPORTANCE_MODERATE) return "MEDIUM";
   if(imp==CALENDAR_IMPORTANCE_LOW) return "LOW";
   return "NONE";
}

color ImportanceColor(ENUM_CALENDAR_EVENT_IMPORTANCE imp)
{
   if(imp==CALENDAR_IMPORTANCE_HIGH) return InpHighColor;
   if(imp==CALENDAR_IMPORTANCE_MODERATE) return InpMediumColor;
   if(imp==CALENDAR_IMPORTANCE_LOW) return InpLowColor;
   return InpLowColor;
}

bool ShouldShow(ENUM_CALENDAR_EVENT_IMPORTANCE imp)
{
   if(imp==CALENDAR_IMPORTANCE_HIGH) return g_showHigh;
   if(imp==CALENDAR_IMPORTANCE_MODERATE) return g_showMedium;
   if(imp==CALENDAR_IMPORTANCE_LOW) return g_showLow;
   return false;
}

//----------------------------- Drawing -------------------------------
void DrawNewsLine(long valueId,datetime tm,color clr,string label)
{
   string n=PREFIX+"VLINE_"+IntegerToString(valueId);
   if(ObjectFind(0,n)<0)
      ObjectCreate(0,n,OBJ_VLINE,0,tm,0);
   else
      ObjectMove(0,n,0,tm,0);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_STYLE,STYLE_DOT);
   ObjectSetInteger(0,n,OBJPROP_WIDTH,1);
   SetCommon(n,true,30);

   if(!InpShowLabels) return;

   string ln=PREFIX+"LBL_"+IntegerToString(valueId);
   double priceTop=ChartGetDouble(0,CHART_PRICE_MAX,0);
   if(ObjectFind(0,ln)<0)
      ObjectCreate(0,ln,OBJ_TEXT,0,tm,priceTop);
   else
      ObjectMove(0,ln,0,tm,priceTop);
   ObjectSetString(0,ln,OBJPROP_TEXT,label);
   ObjectSetInteger(0,ln,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,ln,OBJPROP_FONTSIZE,7);
   ObjectSetInteger(0,ln,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
   ObjectSetString(0,ln,OBJPROP_FONT,"Arial Bold");
   SetCommon(ln,false,60);
}

//----------------------------- Calendar scan --------------------------
struct NewsItem
{
   long     valueId;
   datetime tm;
   string   text;
   ENUM_CALENDAR_EVENT_IMPORTANCE importance;
};

void RefreshNews()
{
   ObjectsDeleteAll(0,PREFIX+"VLINE_");
   ObjectsDeleteAll(0,PREFIX+"LBL_");

   int lookAhead=(int)StringToInteger(TrimBoth(GetEditText("EDIT_LOOKAHEAD")));
   if(lookAhead<=0) lookAhead=InpLookAheadHours;

   datetime fromTime=TimeCurrent()-InpLookBehindHours*3600;
   datetime toTime=TimeCurrent()+lookAhead*3600;

   string curs[];
   DetectCurrencies(_Symbol,curs);

   NewsItem items[];
   ArrayResize(items,0);

   for(int c=0;c<ArraySize(curs);c++)
   {
      MqlCalendarValue values[];
      int got=CalendarValueHistory(values,fromTime,toTime,NULL,curs[c]);
      if(got<=0) continue;

      for(int i=0;i<got;i++)
      {
         bool dup=false;
         for(int k=0;k<ArraySize(items);k++)
            if(items[k].valueId==values[i].id) { dup=true; break; }
         if(dup) continue;

         MqlCalendarEvent ev;
         if(!CalendarEventById(values[i].event_id,ev)) continue;

         NewsItem item;
         item.valueId=values[i].id;
         item.tm=values[i].time;
         item.importance=ev.importance;
         item.text=curs[c]+" "+ev.name;

         int n=ArraySize(items);
         ArrayResize(items,n+1);
         items[n]=item;
      }
   }

   // Sort ascending by time (simple selection sort - small lists).
   int total=ArraySize(items);
   for(int i=0;i<total;i++)
      for(int j=i+1;j<total;j++)
         if(items[j].tm<items[i].tm)
         {
            NewsItem tmp=items[i]; items[i]=items[j]; items[j]=tmp;
         }

   int drawn=0;
   int upcomingShown=0;
   for(int i=0;i<total;i++)
   {
      if(!ShouldShow(items[i].importance)) continue;

      color clr=ImportanceColor(items[i].importance);
      string tag=ImportanceText(items[i].importance);
      DrawNewsLine(items[i].valueId,items[i].tm,clr,items[i].text+" ("+tag+")");
      drawn++;

      if(items[i].tm>=TimeCurrent() && upcomingShown<5)
      {
         int minsAway=(int)((items[i].tm-TimeCurrent())/60);
         string whenTxt=(minsAway<60)?(IntegerToString(minsAway)+"m"):(IntegerToString(minsAway/60)+"h "+IntegerToString(minsAway%60)+"m");
         SetLabelText("UP_"+IntegerToString(upcomingShown),"In "+whenTxt+": "+items[i].text+" ("+tag+")",clr);
         upcomingShown++;
      }
   }
   for(int i=upcomingShown;i<5;i++)
      SetLabelText("UP_"+IntegerToString(i)," ",InpTextColor);

   SetLabelText("NOTE",IntegerToString(drawn)+" event(s) shown • updated "+TimeToString(TimeCurrent(),TIME_SECONDS),InpTextColor);
   ChartRedraw(0);
}

//--------------------------- MT5 events -----------------------------
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME,PRODUCT_NAME);
   g_showHigh=InpShowHigh;
   g_showMedium=InpShowMedium;
   g_showLow=InpShowLow;

   BuildGUI();
   RefreshNews();
   EventSetTimer(MathMax(30,InpRefreshMinutes*60));
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
   RefreshNews();
}

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id!=CHARTEVENT_OBJECT_CLICK) return;

   if(sparam==PREFIX+"BTN_CLOSE")
   {
      ChartIndicatorDelete(0,0,PRODUCT_NAME);
      return;
   }
   if(sparam==PREFIX+"BTN_HIGH")
   {
      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      g_showHigh=!g_showHigh;
      RefreshToggleButtons();
      RefreshNews();
      return;
   }
   if(sparam==PREFIX+"BTN_MED")
   {
      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      g_showMedium=!g_showMedium;
      RefreshToggleButtons();
      RefreshNews();
      return;
   }
   if(sparam==PREFIX+"BTN_LOW")
   {
      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      g_showLow=!g_showLow;
      RefreshToggleButtons();
      RefreshNews();
      return;
   }
   if(sparam==PREFIX+"BTN_REFRESH")
   {
      ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
      RefreshNews();
      return;
   }
}

int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],const double &open[],const double &high[],const double &low[],const double &close[],const long &tick_volume[],const long &volume[],const int &spread[])
{
   return rates_total;
}
//+------------------------------------------------------------------+
