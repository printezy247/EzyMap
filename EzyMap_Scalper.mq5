//+------------------------------------------------------------------+
//| EzyMap Scalper v2.4.7 - MT5 Phase 1 PREMIUM Indicator             |
//| Native MQL5 port of the TradingView v2.4.7 live signal engine.  |
//| Phase 1 Premium: engine + full map/dashboard/labels. NO orders.   |
//+------------------------------------------------------------------+
#property copyright "EzyMap"
#property version   "2.47"
#property indicator_chart_window
#property indicator_plots 0

#include <EzyMapLicense.mqh>
#define SCRIPT_ID "EzyMap_Scalper"

//------------------------------ Inputs ------------------------------
input int    InpDirectionHistory       = 64;
input int    InpSupportHistory         = 40;
input int    InpEntryHistory           = 24;
input int    InpSupportPivotBars       = 3;
input int    InpEntryPivotBars         = 1;
input bool   InpRequireDirectionalBody = false;
input double InpRejectionWickRatio     = 0.25;
input int    InpReadyExpiryBars        = 60;
input double InpConfluenceTolerancePips= 70.0;

input double InpScalpStopPips          = 20.0;
input double InpIntradayStopPips       = 35.0;
input double InpSwingStopPips          = 70.0;
input double InpScalpTargetMinPoints   = 15.0;
input double InpScalpTargetMaxPoints   = 80.0;
input double InpIntradayTargetMinPoints= 60.0;
input double InpIntradayTargetMaxPoints= 250.0;
input double InpSwingTargetMinPoints   = 180.0;
input double InpSwingTargetMaxPoints   = 800.0;
input double InpSnrFrontRunPips        = 10.0;

input bool   InpShowDirectionLevels    = true;
input bool   InpShowSupportingZones    = true;
input bool   InpShowEntryZone          = true;
input bool   InpShowDashboard          = true;
input bool   InpShowTradeCard          = true;
input bool   InpShowMonitoringCard     = true;
input bool   InpShowHistoricalMarkers  = true;
input int    InpMaxHistoricalMarkers   = 15;
input bool   InpEnableAlerts           = true;
input bool   InpAlertReady             = true;
input bool   InpAlertLive              = true;
input bool   InpAlertResult            = true;
input bool   InpPushNotifications      = false;

input color  InpBuyColor               = C'0,208,142';
input color  InpSellColor              = C'235,72,96';
input color  InpSupportColor           = C'52,211,176';
input color  InpResistanceColor        = C'237,185,58';
input color  InpPanelColor             = C'7,10,14';
input color  InpNeutralColor           = C'204,211,218';

//
// Premium MT5 presentation
//
input bool   InpApplyPremiumTheme       = true;
input bool   InpShowDrawingLabels       = true;
input bool   InpShowLowRiskSourceMarker = false;
input bool   InpShowLowRiskZones        = true;
input bool   InpLowRiskPreferNoOverlap  = true;
input bool   InpLowRiskUseChartCandles  = true;
input bool   InpShowBELevel             = true;
input bool   InpHideNativeTickerOHLC    = true;
input int    InpChartScale              = 3;
input double InpRightShiftPercent       = 22.0;

input color  InpChartBackground         = C'8,11,15';
input color  InpChartForeground         = C'176,185,195';
input color  InpBullCandleColor         = C'0,208,142';
input color  InpBearCandleColor         = C'235,72,96';
input color  InpBullWickColor           = C'70,220,172';
input color  InpBearWickColor           = C'245,105,125';
input color  InpPanelBorderColor        = C'56,65,76';
input color  InpPanelHeaderColor        = C'237,185,58';

input color  InpBuyHighRiskZoneColor    = C'18,74,61';
input color  InpBuyLowRiskZoneColor     = C'11,45,38';
input color  InpSellHighRiskZoneColor   = C'82,28,39';
input color  InpSellLowRiskZoneColor    = C'58,42,19';
input color  InpBEColor                 = C'126,137,150';

//----------------------------- Constants ----------------------------
#define PRODUCT_NAME "EzyMap Scalper"
#define PRODUCT_VERSION "v2.4.7"
#define EMA_LEN 13
#define TREND_MIN_CONFLUENCES 2
#define COUNTER_MIN_CONFLUENCES 3
#define MAX_ZONE_RETESTS 1
#define CONFIRM_WINDOW 4
#define MIN_RR 1.0
#define MAX_RR 7.0
#define BE_TRIGGER_R 1.0

string PREFIX="EZ247_";

enum EzyState { ST_MONITORING=0, ST_READY=1, ST_ACTIVE=2, ST_TP=3, ST_SL=4, ST_BE=5 };

struct ZoneInfo
{
   double lo;
   double hi;
   datetime time;
   bool valid;
};

struct TradePlan
{
   double sl;
   double tp;
   double rr;
   bool valid;
};

struct ReadySnapshot
{
   string direction;
   bool counterTrend;
   int confluences;
   int requiredConfluences;
   int zoneRetests;
   double supportLo;
   double supportHi;
   double entryLo;
   double entryHi;
   datetime entryTime;
   double planSL;
   double planTP;
   double planRR;
   datetime armedClock;
   bool zoneExited;
};

struct ActiveSnapshot
{
   string direction;
   bool counterTrend;
   int confluences;
   double entry;
   double sl;
   double tp;
   double rr;
   double entryLo;
   double entryHi;
   datetime entryTime;
   datetime startClock;
   double beTrigger;
   bool beArmed;
};

//--------------------------- Global state ---------------------------
EzyState g_state=ST_MONITORING;
ReadySnapshot g_ready;
ActiveSnapshot g_active;
datetime g_lastEntryClosedTime=0;
datetime g_lastMapCalcTime=0;
int g_structureDirection=0;
int g_bullChochAge=9999, g_bearChochAge=9999;
int g_bullRejectAge=9999, g_bearRejectAge=9999;
string g_lastResult="";
string g_indicatorShortName="";
datetime g_resultTime=0;

string g_historicalMarkerNames[];
int g_historicalMarkerSerial=0;

ENUM_TIMEFRAMES g_directionTF=PERIOD_M30;
ENUM_TIMEFRAMES g_supportTF=PERIOD_M5;
ENUM_TIMEFRAMES g_entryTF=PERIOD_M1;
string g_mode="SCALP";
string g_tfLabel="M1";
string g_dirLabel="M30";
string g_supLabel="M5";

// Current map snapshot
double g_S1=0,g_S2=0,g_R1=0,g_R2=0;
ZoneInfo g_buyHigh,g_buyLow,g_sellHigh,g_sellLow;
int g_buyHighConf=0,g_sellHighConf=0;
double g_pipSize=0,g_brnStep=0,g_microStep=0;
string g_biasText="NEUTRAL";
double g_livePrice=0.0;

//----------------------------- Helpers ------------------------------
double RoundPrice(double v)
{
   int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   return NormalizeDouble(v,digits);
}

string PriceText(double v)
{
   int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   return DoubleToString(v,digits);
}

string Upper(string s)
{
   StringToUpper(s);
   return s;
}

bool IsGold()
{
   string s=Upper(_Symbol);
   return (StringFind(s,"XAU")>=0 || StringFind(s,"GOLD")>=0);
}

bool IsBTC()
{
   string s=Upper(_Symbol);
   return (StringFind(s,"BTC")>=0 || StringFind(s,"XBT")>=0);
}

int TfSeconds(ENUM_TIMEFRAMES tf)
{
   return PeriodSeconds(tf);
}

bool ConfigureRouting()
{
   ENUM_TIMEFRAMES p=(ENUM_TIMEFRAMES)_Period;
   g_entryTF=p;
   if(p==PERIOD_M1)  { g_directionTF=PERIOD_M30; g_supportTF=PERIOD_M5;  g_mode="SCALP";    g_tfLabel="M1";  g_dirLabel="M30"; g_supLabel="M5"; }
   else if(p==PERIOD_M5)  { g_directionTF=PERIOD_H1;  g_supportTF=PERIOD_M15; g_mode="SCALP";    g_tfLabel="M5";  g_dirLabel="H1";  g_supLabel="M15"; }
   else if(p==PERIOD_M15) { g_directionTF=PERIOD_H4;  g_supportTF=PERIOD_M30; g_mode="INTRADAY"; g_tfLabel="M15"; g_dirLabel="H4";  g_supLabel="M30"; }
   else if(p==PERIOD_M30) { g_directionTF=PERIOD_D1;  g_supportTF=PERIOD_H1;  g_mode="INTRADAY"; g_tfLabel="M30"; g_dirLabel="D1";  g_supLabel="H1"; }
   else if(p==PERIOD_H1)  { g_directionTF=PERIOD_W1;  g_supportTF=PERIOD_H4;  g_mode="SWING";    g_tfLabel="H1";  g_dirLabel="W1";  g_supLabel="H4"; }
   else if(p==PERIOD_H4)  { g_directionTF=PERIOD_MN1; g_supportTF=PERIOD_D1;  g_mode="SWING";    g_tfLabel="H4";  g_dirLabel="MN1"; g_supLabel="D1"; }
   else return false;
   return true;
}

bool LoadRatesFlexible(ENUM_TIMEFRAMES tf,int requested,int minimum,MqlRates &rates[])
{
   ArraySetAsSeries(rates,true);
   ResetLastError();
   int got=CopyRates(_Symbol,tf,0,requested,rates);

   if(got<minimum)
   {
      // Trigger/allow MT5 history synchronization and report only when genuinely insufficient.
      Print("EzyMap: insufficient ",EnumToString(tf),
            " history. Loaded=",got,
            " Minimum=",minimum,
            " Error=",GetLastError());
      return false;
   }

   return true;
}

double EMAFromRates(MqlRates &r[],int total,int period,int shift)
{
   if(total<=period+shift+5) return EMPTY_VALUE;
   int oldest=total-1;
   double alpha=2.0/(period+1.0);
   double ema=r[oldest].close;
   for(int i=oldest-1;i>=shift;i--)
      ema=alpha*r[i].close+(1.0-alpha)*ema;
   return ema;
}

double ATRFromRates(MqlRates &r[],int total,int period,int shift)
{
   if(total<=period+shift+5) return EMPTY_VALUE;
   int oldest=total-2;
   double atr=0.0;
   int seedCount=0;
   for(int i=oldest;i>=MathMax(shift,oldest-period+1);i--)
   {
      double prev=r[i+1].close;
      double tr=MathMax(r[i].high-r[i].low,MathMax(MathAbs(r[i].high-prev),MathAbs(r[i].low-prev)));
      atr+=tr; seedCount++;
   }
   if(seedCount==0) return EMPTY_VALUE;
   atr/=seedCount;
   for(int i=oldest-period;i>=shift;i--)
   {
      if(i+1>=total) continue;
      double prev=r[i+1].close;
      double tr=MathMax(r[i].high-r[i].low,MathMax(MathAbs(r[i].high-prev),MathAbs(r[i].low-prev)));
      atr=(atr*(period-1)+tr)/period;
   }
   return atr;
}

bool Near(double a,double b,double tol) { return MathAbs(a-b)<=tol; }

bool NearRound(double v,double step,double tol)
{
   if(step<=0) return false;
   double nearest=MathRound(v/step)*step;
   return MathAbs(v-nearest)<=tol;
}

double Clamp(double v,double lo,double hi) { return MathMax(lo,MathMin(hi,v)); }

bool Overlap(double lo,double hi,double zlo,double zhi)
{
   return (hi>=zlo && lo<=zhi);
}

void PickDirectionLevels(MqlRates &d[],int total,double reference,double minDist,double fallbackLow,double fallbackHigh,double fallbackATR,
                         double &s1,double &s2,double &r1,double &r2)
{
   s1=s2=r1=r2=EMPTY_VALUE;
   double s1d=DBL_MAX,s2d=DBL_MAX,r1d=DBL_MAX,r2d=DBL_MAX;
   int maxN=MathMin(InpDirectionHistory,total-1);
   for(int i=1;i<=maxN;i++)
   {
      double level=d[i].close;
      if(level<reference && reference-level<s1d) { s1=level; s1d=reference-level; }
      if(level>reference && level-reference<r1d) { r1=level; r1d=level-reference; }
   }
   for(int i=1;i<=maxN;i++)
   {
      double level=d[i].close;
      if(s1!=EMPTY_VALUE && level<=s1-minDist && s1-level<s2d) { s2=level; s2d=s1-level; }
      if(r1!=EMPTY_VALUE && level>=r1+minDist && level-r1<r2d) { r2=level; r2d=level-r1; }
   }
   double safeATR=MathMax(fallbackATR,minDist*5.0);
   if(s1==EMPTY_VALUE) s1=MathMin(fallbackLow,reference-minDist);
   if(r1==EMPTY_VALUE) r1=MathMax(fallbackHigh,reference+minDist);
   if(s2==EMPTY_VALUE) s2=MathMin(fallbackLow,s1-minDist);
   if(r2==EMPTY_VALUE) r2=MathMax(fallbackHigh,r1+minDist);
   s1=RoundPrice(s1); s2=RoundPrice(s2); r1=RoundPrice(r1); r2=RoundPrice(r2);
}

ZoneInfo SupportZone(double level,MqlRates &s[],int total)
{
   ZoneInfo z; z.valid=false; z.lo=0; z.hi=0; z.time=0;
   double nearestDistance=DBL_MAX, nearestRange=0; datetime nearestTime=0;
   int maxN=MathMin(InpSupportHistory,total-1);
   for(int i=1;i<=maxN;i++)
   {
      if(s[i].high<=s[i].low) continue;
      if(s[i].low<=level && s[i].high>=level && !z.valid)
      {
         z.lo=RoundPrice(s[i].low); z.hi=RoundPrice(s[i].high); z.time=s[i].time; z.valid=true;
      }
      double mid=(s[i].high+s[i].low)/2.0;
      double dist=MathAbs(mid-level);
      if(dist<nearestDistance) { nearestDistance=dist; nearestRange=s[i].high-s[i].low; nearestTime=s[i].time; }
   }
   if(!z.valid && nearestTime>0)
   {
      double range=MathMax(nearestRange,_Point*10.0);
      z.lo=RoundPrice(level-range*0.5); z.hi=RoundPrice(level+range*0.5); z.time=nearestTime; z.valid=true;
   }
   return z;
}

// Refined LOW RISK zone selector.
//
// LOW RISK zones remain drawing-only and do not participate in READY/LIVE.
//
// BUY LOW RISK at S2:
//   1) Candle must overlap S2: low <= S2 <= high.
//   2) Prefer candles where the resulting zone [S2, candle high]
//      stays below the BUY HIGH RISK zone.
//   3) From the preferred set, choose the candle with the LOWEST LOW.
//   4) Zone is S2 -> selected candle HIGH.
//
// SELL LOW RISK at R2:
//   1) Candle must overlap R2: low <= R2 <= high.
//   2) Prefer candles where the resulting zone [candle low, R2]
//      stays above the SELL HIGH RISK zone.
//   3) From the preferred set, choose the candle with the HIGHEST HIGH.
//   4) Zone is selected candle LOW -> R2.
//
// If no non-overlapping candle exists, the same extreme rule is used
// without the separation requirement.
ZoneInfo LowRiskExtremeOverlapZone(double level,
                                   ZoneInfo &highRisk,
                                   MqlRates &candles[],
                                   int total,
                                   bool buy)
{
   ZoneInfo z;
   z.valid=false;
   z.lo=0.0;
   z.hi=0.0;
   z.time=0;

   if(level<=0 || level==EMPTY_VALUE || total<2)
      return z;

   int maxN=MathMin(InpEntryHistory,total-1);
   if(maxN<1)
      return z;

   int bestSeparated=-1;
   int bestFallback=-1;

   double bestSeparatedExtreme = buy ? DBL_MAX : -DBL_MAX;
   double bestFallbackExtreme  = buy ? DBL_MAX : -DBL_MAX;

   for(int i=1;i<=maxN;i++)
   {
      if(candles[i].high<=candles[i].low)
         continue;

      // Candle must physically overlap S2/R2.
      bool crosses=(candles[i].low<=level && candles[i].high>=level);
      if(!crosses)
         continue;

      double zoneLo = buy ? level : candles[i].low;
      double zoneHi = buy ? candles[i].high : level;

      if(zoneHi<=zoneLo+_Point)
         continue;

      // Avoid same-side HIGH RISK overlap whenever possible.
      bool separated=true;

      if(InpLowRiskPreferNoOverlap && highRisk.valid)
      {
         if(buy)
         {
            // BUY LOW RISK must remain underneath BUY HIGH RISK.
            separated=(zoneHi < highRisk.lo-_Point);
         }
         else
         {
            // SELL LOW RISK must remain above SELL HIGH RISK.
            separated=(zoneLo > highRisk.hi+_Point);
         }
      }

      // Extreme selection requested by user:
      // BUY = lowest LOW; SELL = highest HIGH.
      double extreme = buy ? candles[i].low : candles[i].high;

      if(buy)
      {
         if(extreme<bestFallbackExtreme ||
            (MathAbs(extreme-bestFallbackExtreme)<=_Point && (bestFallback<0 || i<bestFallback)))
         {
            bestFallbackExtreme=extreme;
            bestFallback=i;
         }

         if(separated &&
            (extreme<bestSeparatedExtreme ||
             (MathAbs(extreme-bestSeparatedExtreme)<=_Point && (bestSeparated<0 || i<bestSeparated))))
         {
            bestSeparatedExtreme=extreme;
            bestSeparated=i;
         }
      }
      else
      {
         if(extreme>bestFallbackExtreme ||
            (MathAbs(extreme-bestFallbackExtreme)<=_Point && (bestFallback<0 || i<bestFallback)))
         {
            bestFallbackExtreme=extreme;
            bestFallback=i;
         }

         if(separated &&
            (extreme>bestSeparatedExtreme ||
             (MathAbs(extreme-bestSeparatedExtreme)<=_Point && (bestSeparated<0 || i<bestSeparated))))
         {
            bestSeparatedExtreme=extreme;
            bestSeparated=i;
         }
      }
   }

   int selected=(bestSeparated>=0)?bestSeparated:bestFallback;

   if(selected<0)
      return z;

   if(buy)
   {
      z.lo=RoundPrice(level);
      z.hi=RoundPrice(candles[selected].high);
   }
   else
   {
      z.lo=RoundPrice(candles[selected].low);
      z.hi=RoundPrice(level);
   }

   z.time=candles[selected].time;
   z.valid=(z.hi>z.lo+_Point);
   return z;
}

bool IsPivotHigh(MqlRates &s[],int total,int idx,int bars)
{
   if(idx-bars<0 || idx+bars>=total) return false;
   double v=s[idx].high;
   for(int k=1;k<=bars;k++) if(s[idx-k].high>=v || s[idx+k].high>v) return false;
   return true;
}

bool IsPivotLow(MqlRates &s[],int total,int idx,int bars)
{
   if(idx-bars<0 || idx+bars>=total) return false;
   double v=s[idx].low;
   for(int k=1;k<=bars;k++) if(s[idx-k].low<=v || s[idx+k].low<v) return false;
   return true;
}

void SupportMetrics(MqlRates &s[],int total,int piv,double &swingHigh,double &swingLow,double &trendSupport,double &trendResistance)
{
   swingHigh=swingLow=trendSupport=trendResistance=EMPTY_VALUE;
   int ph1=-1,ph2=-1,pl1=-1,pl2=-1;
   for(int i=piv+1;i<MathMin(total-piv,120);i++)
   {
      if(ph1<0 && IsPivotHigh(s,total,i,piv)) ph1=i;
      else if(ph1>=0 && ph2<0 && IsPivotHigh(s,total,i,piv)) ph2=i;
      if(pl1<0 && IsPivotLow(s,total,i,piv)) pl1=i;
      else if(pl1>=0 && pl2<0 && IsPivotLow(s,total,i,piv)) pl2=i;
      if(ph2>=0 && pl2>=0) break;
   }
   if(ph1>=0) swingHigh=s[ph1].high;
   if(pl1>=0) swingLow=s[pl1].low;
   if(ph1>=0 && ph2>=0)
   {
      double dx=(double)(ph2-ph1);
      trendResistance=s[ph1].high+(s[ph1].high-s[ph2].high)/dx*(double)ph1;
   }
   if(pl1>=0 && pl2>=0)
   {
      double dx=(double)(pl2-pl1);
      trendSupport=s[pl1].low+(s[pl1].low-s[pl2].low)/dx*(double)pl1;
   }
}

int ZoneRetests(ZoneInfo &z,MqlRates &e[],int total,datetime currentEntryTime)
{
   if(!z.valid) return 999;
   datetime readyTime=z.time+TfSeconds(g_supportTF);
   int maxN=MathMin(InpEntryHistory,total-1);
   int retests=0; bool prevInside=false;
   for(int i=maxN;i>=1;i--)
   {
      bool eligible=(e[i].time>=readyTime && e[i].time<=currentEntryTime);
      if(!eligible) continue;
      bool inside=Overlap(e[i].low,e[i].high,z.lo,z.hi);
      if(inside && !prevInside) retests++;
      prevInside=inside;
   }
   return retests;
}

bool SelectEntryCandle(ZoneInfo &z,double cmp,bool buy,MqlRates &e[],int total,double &lo,double &hi,datetime &tm)
{
   lo=hi=0; tm=0; double best=DBL_MAX; bool found=false;
   int maxN=MathMin(InpEntryHistory,total-1);
   for(int i=1;i<=maxN;i++)
   {
      bool inside=(e[i].low>=z.lo && e[i].high<=z.hi && e[i].high>e[i].low);
      bool side=buy ? (e[i].high<cmp-_Point) : (e[i].low>cmp+_Point);
      if(!inside || !side) continue;
      double dist=buy ? cmp-e[i].high : e[i].low-cmp;
      if(dist<best) { best=dist; lo=RoundPrice(e[i].low); hi=RoundPrice(e[i].high); tm=e[i].time; found=true; }
   }
   return found;
}

int ConfluenceCount(ZoneInfo &z,double ema,double trend,double fib50,double fib618,double tol)
{
   if(!z.valid) return 0;
   double mid=(z.lo+z.hi)/2.0;
   int c=1;
   bool brn=NearRound(mid,g_brnStep,tol);
   bool micro=(!brn && NearRound(mid,g_microStep,tol));
   bool em=Near(mid,ema,tol);
   bool tr=(trend!=EMPTY_VALUE && Near(mid,trend,tol));
   bool fib=((fib50!=EMPTY_VALUE && Near(mid,fib50,tol)) || (fib618!=EMPTY_VALUE && Near(mid,fib618,tol)));
   if(brn) c++; if(micro)c++; if(em)c++; if(tr)c++; if(fib)c++;
   return c;
}

double NearestBelow4(double ref,double a,double b,double c,double d)
{
   double result=EMPTY_VALUE; double v[4]={a,b,c,d};
   for(int i=0;i<4;i++) if(v[i]!=EMPTY_VALUE && v[i]<ref && (result==EMPTY_VALUE || v[i]>result)) result=v[i];
   return result;
}

double NearestAbove4(double ref,double a,double b,double c,double d)
{
   double result=EMPTY_VALUE; double v[4]={a,b,c,d};
   for(int i=0;i<4;i++) if(v[i]!=EMPTY_VALUE && v[i]>ref && (result==EMPTY_VALUE || v[i]<result)) result=v[i];
   return result;
}

// NOTE: "entry" here is a PREVIEW price only, used to size SL/TP for the
// READY card (BUY previews off the top of the candidate zone, SELL off the
// bottom - i.e. the near side of each zone relative to price). The REAL
// entry is whatever livePrice is when ManageReady() detects the touch, and
// TP/RR are re-clamped there against that real entry. Don't "fix" this
// asymmetry - it's intentional, not a bug.
TradePlan BuildTradePlan(string dir,double entry,double entryLo,double entryHi,double volStop,double volTarget,double snr,
                         double targetMin,double targetMax,double s1,double s2,double r1,double r2,
                         double swingLow,double swingHigh,double trendSupport,double trendResistance)
{
   TradePlan p; p.valid=false; p.sl=p.tp=p.rr=0;
   if(dir=="BUY")
   {
      double baseSL=RoundPrice(entryLo-volStop);
      double fs=NearestBelow4(entryLo-snr,s1,s2,swingLow,trendSupport);
      double protectedSL=(fs!=EMPTY_VALUE)?RoundPrice(fs+snr):baseSL;
      p.sl=MathMax(baseSL,protectedSL);
      if(p.sl>=entry) return p;
      double risk=entry-p.sl;
      double desired=Clamp(MathMax(volTarget,risk*1.5),targetMin,targetMax);
      desired=MathMin(desired,risk*MAX_RR);
      double fr=NearestAbove4(entry,r1,r2,swingHigh,trendResistance);
      double available=(fr!=EMPTY_VALUE)?fr-snr-entry:desired;
      double reward=MathMin(desired,available);
      if(reward<risk*MIN_RR) return p;
      p.tp=RoundPrice(entry+MathMin(reward,risk*MAX_RR));
      p.rr=(p.tp-entry)/risk;
   }
   else
   {
      double baseSL=RoundPrice(entryHi+volStop);
      double fr=NearestAbove4(entryHi+snr,r1,r2,swingHigh,trendResistance);
      double protectedSL=(fr!=EMPTY_VALUE)?RoundPrice(fr-snr):baseSL;
      p.sl=MathMin(baseSL,protectedSL);
      if(p.sl<=entry) return p;
      double risk=p.sl-entry;
      double desired=Clamp(MathMax(volTarget,risk*1.5),targetMin,targetMax);
      desired=MathMin(desired,risk*MAX_RR);
      double fs=NearestBelow4(entry,s1,s2,swingLow,trendSupport);
      double available=(fs!=EMPTY_VALUE)?entry-(fs+snr):desired;
      double reward=MathMin(desired,available);
      if(reward<risk*MIN_RR) return p;
      p.tp=RoundPrice(entry-MathMin(reward,risk*MAX_RR));
      p.rr=(entry-p.tp)/risk;
   }
   p.valid=(p.rr>=MIN_RR-0.0001 && p.rr<=MAX_RR+0.0001);
   return p;
}

//----------------------------- Drawing ------------------------------
void DeleteObject(string suffix)
{
   ObjectDelete(0,PREFIX+suffix);
}

void SetObjectCommon(string n,bool back=false)
{
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,false);
   ObjectSetInteger(0,n,OBJPROP_BACK,back);
   ObjectSetInteger(0,n,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,100);
}

void ApplyPremiumChartTheme()
{
   if(!InpApplyPremiumTheme) return;

   int scale=(int)MathMax(0,MathMin(5,InpChartScale));
   double shift=MathMax(10.0,MathMin(50.0,InpRightShiftPercent));

   ChartSetInteger(0,CHART_MODE,CHART_CANDLES);
   ChartSetInteger(0,CHART_AUTOSCROLL,true);
   ChartSetInteger(0,CHART_SHIFT,true);
   ChartSetDouble(0,CHART_SHIFT_SIZE,shift);
   ChartSetInteger(0,CHART_SCALE,scale);
   ChartSetInteger(0,CHART_FOREGROUND,false);

   ChartSetInteger(0,CHART_SHOW_GRID,false);
   ChartSetInteger(0,CHART_SHOW_VOLUMES,CHART_VOLUME_HIDE);
   ChartSetInteger(0,CHART_SHOW_PERIOD_SEP,false);
   ChartSetInteger(0,CHART_SHOW_ASK_LINE,false);
   ChartSetInteger(0,CHART_SHOW_LAST_LINE,false);
   ChartSetInteger(0,CHART_SHOW_BID_LINE,true);
   ChartSetInteger(0,CHART_SHOW_OBJECT_DESCR,false);
   ChartSetInteger(0,CHART_SHOW_ONE_CLICK,false);

   if(InpHideNativeTickerOHLC)
   {
      ChartSetInteger(0,CHART_SHOW_TICKER,false);
      ChartSetInteger(0,CHART_SHOW_OHLC,false);
   }

   ChartSetInteger(0,CHART_COLOR_BACKGROUND,InpChartBackground);
   ChartSetInteger(0,CHART_COLOR_FOREGROUND,InpChartForeground);
   ChartSetInteger(0,CHART_COLOR_GRID,InpChartBackground);
   ChartSetInteger(0,CHART_COLOR_VOLUME,C'48,56,66');

   // Candle bodies
   ChartSetInteger(0,CHART_COLOR_CANDLE_BULL,InpBullCandleColor);
   ChartSetInteger(0,CHART_COLOR_CANDLE_BEAR,InpBearCandleColor);

   // Wick / outline colors
   ChartSetInteger(0,CHART_COLOR_CHART_UP,InpBullWickColor);
   ChartSetInteger(0,CHART_COLOR_CHART_DOWN,InpBearWickColor);
   ChartSetInteger(0,CHART_COLOR_CHART_LINE,InpChartForeground);

   ChartSetInteger(0,CHART_COLOR_BID,C'78,88,100');
   ChartSetInteger(0,CHART_COLOR_ASK,C'78,88,100');
   ChartSetInteger(0,CHART_COLOR_LAST,C'78,88,100');
   ChartSetInteger(0,CHART_COLOR_STOP_LEVEL,InpPanelHeaderColor);
}

void HLine(string suffix,double price,color clr,ENUM_LINE_STYLE style=STYLE_DOT,int width=1)
{
   if(price<=0 || price==EMPTY_VALUE) return;

   string n=PREFIX+suffix;
   if(ObjectFind(0,n)<0)
      ObjectCreate(0,n,OBJ_HLINE,0,0,price);

   ObjectSetDouble(0,n,OBJPROP_PRICE,price);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_STYLE,style);
   ObjectSetInteger(0,n,OBJPROP_WIDTH,width);
   SetObjectCommon(n,true);
}

void Rect(string suffix,datetime t1,double p1,datetime t2,double p2,color clr,bool back=true,int width=1,ENUM_LINE_STYLE style=STYLE_SOLID)
{
   if(t1<=0 || t2<=0 || p1<=0 || p2<=0) return;

   string n=PREFIX+suffix;
   double lo=MathMin(p1,p2), hi=MathMax(p1,p2);

   if(ObjectFind(0,n)<0)
      ObjectCreate(0,n,OBJ_RECTANGLE,0,t1,lo,t2,hi);
   else
   {
      ObjectMove(0,n,0,t1,lo);
      ObjectMove(0,n,1,t2,hi);
   }

   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FILL,true);
   ObjectSetInteger(0,n,OBJPROP_STYLE,style);
   ObjectSetInteger(0,n,OBJPROP_WIDTH,width);
   SetObjectCommon(n,back);
}

void Panel(string suffix,int x,int y,int width,int height,color bg,color border)
{
   string n=PREFIX+suffix;
   if(ObjectFind(0,n)<0)
      ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);

   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,width);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,height);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,n,OBJPROP_BORDER_COLOR,border);
   ObjectSetInteger(0,n,OBJPROP_COLOR,border);
   ObjectSetInteger(0,n,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,n,OBJPROP_WIDTH,1);
   SetObjectCommon(n,false);
}

void CornerLabel(string suffix,string value,int x,int y,color clr,int size=9,string font="Arial")
{
   string n=PREFIX+suffix;
   if(ObjectFind(0,n)<0)
      ObjectCreate(0,n,OBJ_LABEL,0,0,0);

   // Correct right-side anchoring: the text expands LEFT into the chart.
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,size);
   ObjectSetString(0,n,OBJPROP_FONT,font);
   ObjectSetString(0,n,OBJPROP_TEXT,value);
   SetObjectCommon(n,false);
}

void ChartText(string suffix,datetime tm,double price,string value,color clr,int size=8,ENUM_ANCHOR_POINT anchor=ANCHOR_LEFT)
{
   if(tm<=0 || price<=0 || price==EMPTY_VALUE) return;

   string n=PREFIX+suffix;
   if(ObjectFind(0,n)<0)
      ObjectCreate(0,n,OBJ_TEXT,0,tm,price);
   else
      ObjectMove(0,n,0,tm,price);

   ObjectSetString(0,n,OBJPROP_TEXT,value);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,size);
   ObjectSetInteger(0,n,OBJPROP_ANCHOR,anchor);
   ObjectSetString(0,n,OBJPROP_FONT,"Arial Bold");
   SetObjectCommon(n,false);
}

void PriceMarker(string suffix,datetime tm,double price,string value,color clr)
{
   ChartText(suffix,tm,price,value,clr,10,ANCHOR_LEFT);
}

void AlertUser(string msg)
{
   if(!InpEnableAlerts) return;
   Alert(msg);
   if(InpPushNotifications) SendNotification(msg);
}

string StateText()
{
   if(g_state==ST_READY) return "READY";
   if(g_state==ST_ACTIVE) return "LIVE";
   if(g_state==ST_TP) return "TP HIT";
   if(g_state==ST_SL) return "SL HIT";
   if(g_state==ST_BE) return "BE HIT";
   return "MONITORING";
}

color StateColor()
{
   if(g_state==ST_READY)
      return (g_ready.direction=="BUY")?InpBuyColor:InpSellColor;
   if(g_state==ST_ACTIVE)
      return (g_active.direction=="BUY")?InpBuyColor:InpSellColor;
   if(g_state==ST_TP) return InpBuyColor;
   if(g_state==ST_SL) return InpSellColor;
   if(g_state==ST_BE) return InpNeutralColor;
   return InpPanelHeaderColor;
}

// Small corner close button - tucked into the very top-right corner so it
// doesn't take space from the dashboard/trade card. Re-open by
// double-clicking the indicator in Navigator.
void DrawCloseButton()
{
   string n=PREFIX+"CLOSE_BTN";
   if(ObjectFind(0,n)<0)
      ObjectCreate(0,n,OBJ_BUTTON,0,0,0);

   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,4);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,4);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,24);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,24);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,C'40,14,18');
   ObjectSetInteger(0,n,OBJPROP_COLOR,InpSellColor);
   ObjectSetInteger(0,n,OBJPROP_BORDER_COLOR,InpPanelBorderColor);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,10);
   ObjectSetString(0,n,OBJPROP_FONT,"Arial Bold");
   ObjectSetString(0,n,OBJPROP_TEXT,"✕");
   ObjectSetInteger(0,n,OBJPROP_STATE,false);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,false);
   ObjectSetInteger(0,n,OBJPROP_BACK,false);
   ObjectSetInteger(0,n,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,150);
}

void DrawDashboard()
{
   if(!InpShowDashboard)
   {
      DeleteObject("DASH_PANEL");
      DeleteObject("DASH_TITLE");
      DeleteObject("DASH_BODY");
      DeleteObject("DASH_STATE");
      DeleteObject("DASH_COMPACT");
      DeleteObject("DASH_COMPACT_LEFT");
      DeleteObject("DASH_COMPACT_BIAS");
      DeleteObject("DASH_RIGHT");
      return;
   }

   // Remove legacy dashboard objects from prior builds.
   DeleteObject("DASH_PANEL");
   DeleteObject("DASH_TITLE");
   DeleteObject("DASH_BODY");
   DeleteObject("DASH_STATE");
   DeleteObject("DASH_COMPACT");
   DeleteObject("DASH_COMPACT_LEFT");
   DeleteObject("DASH_COMPACT_BIAS");

   // Privacy-safe single line:
   // XAUUSD • SCALP • M1 | BIAS BULLISH
   string biasText=(g_biasText=="")?"NEUTRAL":g_biasText;
   string compact=_Symbol+" • "+g_mode+" • "+g_tfLabel+" | BIAS "+biasText;

   color clr=InpNeutralColor;
   if(biasText=="BULLISH")
      clr=InpBuyColor;
   else if(biasText=="BEARISH")
      clr=InpSellColor;

   string n=PREFIX+"DASH_RIGHT";
   if(ObjectFind(0,n)<0)
      ObjectCreate(0,n,OBJ_LABEL,0,0,0);

   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,18);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,32);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,9);
   ObjectSetString(0,n,OBJPROP_FONT,"Arial Bold");
   ObjectSetString(0,n,OBJPROP_TEXT,compact);
   SetObjectCommon(n,false);
}

void ClearTradeCardRows()
{
   DeleteObject("CARD_PANEL");
   for(int i=0;i<10;i++)
      DeleteObject("CARD_ROW_"+IntegerToString(i));
   DeleteObject("CARD");
}

void CardRow(int row,string value,color clr,bool bold=false)
{
   string suffix="CARD_ROW_"+IntegerToString(row);
   string n=PREFIX+suffix;

   if(ObjectFind(0,n)<0)
      ObjectCreate(0,n,OBJ_LABEL,0,0,0);

   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,30);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,70+row*17);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,8);
   ObjectSetString(0,n,OBJPROP_FONT,bold?"Arial Bold":"Arial");
   ObjectSetString(0,n,OBJPROP_TEXT,value);
   SetObjectCommon(n,false);
}

void DrawTradeCard()
{
   if(!InpShowTradeCard)
   {
      ClearTradeCardRows();
      return;
   }

   // Always delete legacy single-label card.
   DeleteObject("CARD");

   int rows=0;
   color accent=InpNeutralColor;

   if(g_state==ST_READY)
   {
      accent=(g_ready.direction=="BUY")?InpBuyColor:InpSellColor;
      rows=g_ready.counterTrend?6:5;
      Panel("CARD_PANEL",14,58,300,34+rows*17,InpPanelColor,InpPanelBorderColor);

      CardRow(0,"SETUP READY • "+g_ready.direction,accent,true);
      CardRow(1,_Symbol+" • "+g_mode+" • "+g_tfLabel,InpNeutralColor,false);
      CardRow(2,"ENTRY  "+PriceText(g_ready.entryLo)+" - "+PriceText(g_ready.entryHi),InpNeutralColor,false);
      CardRow(3,"CONFIRMATION  ENTRY ZONE REJECTION",InpNeutralColor,false);
      CardRow(4,"CONFLUENCES  "+IntegerToString(g_ready.confluences),InpNeutralColor,false);
      if(g_ready.counterTrend)
         CardRow(5,"⚠ COUNTER-TREND",InpPanelHeaderColor,true);
   }
   else if(g_state==ST_ACTIVE)
   {
      accent=(g_active.direction=="BUY")?InpBuyColor:InpSellColor;
      rows=7+(g_active.beArmed?1:0)+(g_active.counterTrend?1:0);
      Panel("CARD_PANEL",14,58,300,34+rows*17,InpPanelColor,InpPanelBorderColor);

      int r=0;
      CardRow(r++,"TRADE ACTIVE • "+g_active.direction,accent,true);
      CardRow(r++,_Symbol+" • "+g_mode+" • "+g_tfLabel,InpNeutralColor,false);
      CardRow(r++,"ENTRY  "+PriceText(g_active.entry),InpNeutralColor,false);
      CardRow(r++,"TP     "+PriceText(g_active.tp),InpBuyColor,false);
      CardRow(r++,"SL     "+PriceText(g_active.sl),InpSellColor,false);
      CardRow(r++,"R:R    1:"+DoubleToString(g_active.rr,2),InpNeutralColor,false);
      CardRow(r++,"CONFLUENCES  "+IntegerToString(g_active.confluences),InpNeutralColor,false);

      if(g_active.beArmed)
         CardRow(r++,"BE ARMED @ +1R",InpBEColor,true);
      if(g_active.counterTrend)
         CardRow(r++,"⚠ COUNTER-TREND",InpPanelHeaderColor,true);
   }
   else if(g_state==ST_TP || g_state==ST_SL || g_state==ST_BE)
   {
      accent=(g_state==ST_TP)?InpBuyColor:(g_state==ST_SL?InpSellColor:InpNeutralColor);
      rows=2;
      Panel("CARD_PANEL",14,58,300,70,InpPanelColor,InpPanelBorderColor);
      CardRow(0,g_lastResult,accent,true);
      CardRow(1,_Symbol+" • "+g_tfLabel,InpNeutralColor,false);
   }
   else
   {
      if(!InpShowMonitoringCard)
      {
         ClearTradeCardRows();
         return;
      }

      rows=3;
      Panel("CARD_PANEL",14,58,300,86,InpPanelColor,InpPanelBorderColor);
      CardRow(0,"MONITORING",InpNeutralColor,true);
      CardRow(1,_Symbol+" • "+g_mode+" • "+g_tfLabel,InpNeutralColor,false);
      CardRow(2,"WAITING FOR VALID SETUP",InpNeutralColor,false);
   }

   // Remove unused rows from a previous larger state.
   for(int i=rows;i<10;i++)
      DeleteObject("CARD_ROW_"+IntegerToString(i));
}

void DrawLevelLabel(string suffix,string tag,double price,color clr,datetime labelTime)
{
   if(!InpShowDrawingLabels)
   {
      DeleteObject(suffix);
      return;
   }
   ChartText(suffix,labelTime,price,tag+"  "+PriceText(price),clr,8,ANCHOR_LEFT);
}

void DrawZoneLabel(string suffix,string tag,const ZoneInfo &z,color clr,datetime labelTime)
{
   if(!InpShowDrawingLabels || !z.valid)
   {
      DeleteObject(suffix);
      return;
   }
   ChartText(suffix,labelTime,(z.lo+z.hi)/2.0,tag,clr,8,ANCHOR_LEFT);
}

void DrawMap(datetime now)
{
   datetime mapFuture=now+TfSeconds(g_entryTF)*22;
   datetime labelTime=now+TfSeconds(g_entryTF)*3;

   // Direction S/R levels + labels
   if(InpShowDirectionLevels)
   {
      HLine("S1",g_S1,InpSupportColor,STYLE_DOT,1);
      HLine("S2",g_S2,InpSupportColor,STYLE_DASH,1);
      HLine("R1",g_R1,InpResistanceColor,STYLE_DOT,1);
      HLine("R2",g_R2,InpResistanceColor,STYLE_DASH,1);

      DrawLevelLabel("LBL_S1","S1",g_S1,InpSupportColor,labelTime);
      DrawLevelLabel("LBL_S2","S2",g_S2,InpSupportColor,labelTime);
      DrawLevelLabel("LBL_R1","R1",g_R1,InpResistanceColor,labelTime);
      DrawLevelLabel("LBL_R2","R2",g_R2,InpResistanceColor,labelTime);
   }
   else
   {
      DeleteObject("S1"); DeleteObject("S2"); DeleteObject("R1"); DeleteObject("R2");
      DeleteObject("LBL_S1"); DeleteObject("LBL_S2"); DeleteObject("LBL_R1"); DeleteObject("LBL_R2");
   }

   // FOUR support/resistance zones:
   // S1 = BUY HIGH RISK, S2 = BUY LOW RISK
   // R1 = SELL HIGH RISK, R2 = SELL LOW RISK
   if(InpShowSupportingZones)
   {
      if(g_buyHigh.valid)
         Rect("BUY_HIGH_ZONE",g_buyHigh.time,g_buyHigh.lo,mapFuture,g_buyHigh.hi,InpBuyHighRiskZoneColor,true,1,STYLE_SOLID);

      if(g_sellHigh.valid)
         Rect("SELL_HIGH_ZONE",g_sellHigh.time,g_sellHigh.lo,mapFuture,g_sellHigh.hi,InpSellHighRiskZoneColor,true,1,STYLE_SOLID);

      if(InpShowLowRiskZones && g_buyLow.valid)
         Rect("BUY_LOW_ZONE",g_buyLow.time,g_buyLow.lo,mapFuture,g_buyLow.hi,InpBuyLowRiskZoneColor,true,1,STYLE_DASH);

      if(InpShowLowRiskZones && g_sellLow.valid)
         Rect("SELL_LOW_ZONE",g_sellLow.time,g_sellLow.lo,mapFuture,g_sellLow.hi,InpSellLowRiskZoneColor,true,1,STYLE_DASH);

      DrawZoneLabel("LBL_BUY_HIGH","BUY • HIGH RISK",g_buyHigh,InpBuyColor,labelTime);
      DrawZoneLabel("LBL_SELL_HIGH","SELL • HIGH RISK",g_sellHigh,InpSellColor,labelTime);

      if(InpShowLowRiskZones)
      {
         DrawZoneLabel("LBL_BUY_LOW","BUY • LOW RISK",g_buyLow,InpSupportColor,labelTime);
         DrawZoneLabel("LBL_SELL_LOW","SELL • LOW RISK",g_sellLow,InpResistanceColor,labelTime);

         // Optional temporary validation marker for the exact candle chosen.
         if(InpShowLowRiskSourceMarker)
         {
            if(g_buyLow.valid)
               ChartText("SRC_BUY_LOW",g_buyLow.time,g_buyLow.hi,
                         "BUY LOW SOURCE",InpBuyColor,7,ANCHOR_LOWER);
            if(g_sellLow.valid)
               ChartText("SRC_SELL_LOW",g_sellLow.time,g_sellLow.lo,
                         "SELL LOW SOURCE",InpSellColor,7,ANCHOR_UPPER);
         }
         else
         {
            DeleteObject("SRC_BUY_LOW");
            DeleteObject("SRC_SELL_LOW");
         }
      }
      else
      {
         DeleteObject("BUY_LOW_ZONE"); DeleteObject("SELL_LOW_ZONE");
         DeleteObject("LBL_BUY_LOW"); DeleteObject("LBL_SELL_LOW");
         DeleteObject("SRC_BUY_LOW"); DeleteObject("SRC_SELL_LOW");
      }
   }
   else
   {
      DeleteObject("BUY_HIGH_ZONE"); DeleteObject("BUY_LOW_ZONE");
      DeleteObject("SELL_HIGH_ZONE"); DeleteObject("SELL_LOW_ZONE");
      DeleteObject("LBL_BUY_HIGH"); DeleteObject("LBL_BUY_LOW");
      DeleteObject("LBL_SELL_HIGH"); DeleteObject("LBL_SELL_LOW");
      DeleteObject("SRC_BUY_LOW"); DeleteObject("SRC_SELL_LOW");
   }

   // Frozen READY / LIVE entry rectangle.
   if((g_state==ST_READY || g_state==ST_ACTIVE) && InpShowEntryZone)
   {
      string direction=(g_state==ST_READY)?g_ready.direction:g_active.direction;
      double lo=(g_state==ST_READY)?g_ready.entryLo:g_active.entryLo;
      double hi=(g_state==ST_READY)?g_ready.entryHi:g_active.entryHi;
      datetime et=(g_state==ST_READY)?g_ready.entryTime:g_active.entryTime;
      color c=(direction=="BUY")?InpBuyColor:InpSellColor;

      Rect("ENTRY",et,lo,mapFuture,hi,c,false,2,STYLE_SOLID);

      if(InpShowDrawingLabels)
      {
         string stateTag=(g_state==ST_READY)?"READY":"LIVE";
         ChartText("LBL_ENTRY",labelTime,(lo+hi)/2.0,
                   stateTag+" "+direction+" • ENTRY ZONE",c,9,ANCHOR_LEFT);
      }

      if(g_state==ST_ACTIVE)
      {
         HLine("ACTIVE_ENTRY",g_active.entry,c,STYLE_SOLID,2);
         HLine("ACTIVE_TP",g_active.tp,InpBuyColor,STYLE_DASH,1);
         HLine("ACTIVE_SL",g_active.sl,InpSellColor,STYLE_DASH,1);

         if(InpShowBELevel)
            HLine("ACTIVE_BE",g_active.beTrigger,InpBEColor,STYLE_DOT,1);
         else
            DeleteObject("ACTIVE_BE");

         if(InpShowDrawingLabels)
         {
            ChartText("LBL_ACTIVE_ENTRY",labelTime,g_active.entry,
                      "ENTRY  "+PriceText(g_active.entry),c,8,ANCHOR_LEFT);
            ChartText("LBL_ACTIVE_TP",labelTime,g_active.tp,
                      "TP  "+PriceText(g_active.tp),InpBuyColor,8,ANCHOR_LEFT);
            ChartText("LBL_ACTIVE_SL",labelTime,g_active.sl,
                      "SL  "+PriceText(g_active.sl),InpSellColor,8,ANCHOR_LEFT);

            if(InpShowBELevel)
               ChartText("LBL_ACTIVE_BE",labelTime,g_active.beTrigger,
                         "BE +1R  "+PriceText(g_active.beTrigger),InpBEColor,8,ANCHOR_LEFT);
         }
      }
      else
      {
         DeleteObject("ACTIVE_ENTRY"); DeleteObject("ACTIVE_TP");
         DeleteObject("ACTIVE_SL"); DeleteObject("ACTIVE_BE");
         DeleteObject("LBL_ACTIVE_ENTRY"); DeleteObject("LBL_ACTIVE_TP");
         DeleteObject("LBL_ACTIVE_SL"); DeleteObject("LBL_ACTIVE_BE");
      }
   }
   else
   {
      DeleteObject("ENTRY");
      DeleteObject("LBL_ENTRY");
      DeleteObject("ACTIVE_ENTRY"); DeleteObject("ACTIVE_TP");
      DeleteObject("ACTIVE_SL"); DeleteObject("ACTIVE_BE");
      DeleteObject("LBL_ACTIVE_ENTRY"); DeleteObject("LBL_ACTIVE_TP");
      DeleteObject("LBL_ACTIVE_SL"); DeleteObject("LBL_ACTIVE_BE");
   }
}


void RemoveOldestHistoricalMarker()
{
   int n=ArraySize(g_historicalMarkerNames);
   if(n<=0) return;

   ObjectDelete(0,g_historicalMarkerNames[0]);

   for(int i=1;i<n;i++)
      g_historicalMarkerNames[i-1]=g_historicalMarkerNames[i];

   ArrayResize(g_historicalMarkerNames,n-1);
}

void AddHistoricalMarker(string direction,datetime tm,double price)
{
   if(!InpShowHistoricalMarkers) return;
   if(direction!="BUY" && direction!="SELL") return;
   if(tm<=0 || price<=0) return;

   g_historicalMarkerSerial++;
   string name=PREFIX+"HIST_"+IntegerToString((int)tm)+"_"+IntegerToString(g_historicalMarkerSerial);

   // Place BUY marker slightly under entry and SELL slightly above it.
   double offset=MathMax(g_pipSize*8.0,_Point*8.0);
   double markerPrice=(direction=="BUY")?price-offset:price+offset;

   if(!ObjectCreate(0,name,OBJ_TEXT,0,tm,markerPrice))
      return;

   ObjectSetString(0,name,OBJPROP_TEXT,direction);
   ObjectSetString(0,name,OBJPROP_FONT,"Arial Bold");
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,name,OBJPROP_COLOR,(direction=="BUY")?InpBuyColor:InpSellColor);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,(direction=="BUY")?ANCHOR_UPPER:ANCHOR_LOWER);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,110);

   int n=ArraySize(g_historicalMarkerNames);
   ArrayResize(g_historicalMarkerNames,n+1);
   g_historicalMarkerNames[n]=name;

   int maxMarkers=MathMax(1,InpMaxHistoricalMarkers);
   while(ArraySize(g_historicalMarkerNames)>maxMarkers)
      RemoveOldestHistoricalMarker();
}

void ClearHistoricalMarkers()
{
   int n=ArraySize(g_historicalMarkerNames);
   for(int i=0;i<n;i++)
      ObjectDelete(0,g_historicalMarkerNames[i]);

   ArrayResize(g_historicalMarkerNames,0);
}

//-------------------------- Signal engine ---------------------------
void UpdateEventAges(bool bullChoch,bool bearChoch,bool bullReject,bool bearReject)
{
   g_bullChochAge=bullChoch?0:MathMin(9999,g_bullChochAge+1);
   g_bearChochAge=bearChoch?0:MathMin(9999,g_bearChochAge+1);
   g_bullRejectAge=bullReject?0:MathMin(9999,g_bullRejectAge+1);
   g_bearRejectAge=bearReject?0:MathMin(9999,g_bearRejectAge+1);
}

void ResetReady()
{
   ZeroMemory(g_ready);
   g_ready.direction="NONE";
   g_state=ST_MONITORING;
}

void FinishTrade(EzyState result,double resultPips)
{
   // Preserve the completed LIVE signal as a historical BUY/SELL marker.
   // The marker is anchored to the original LIVE start time and entry.
   AddHistoricalMarker(g_active.direction,g_active.startClock,g_active.entry);

   if(result==ST_TP) g_lastResult="✅ COLLECT PROFIT";
   else if(result==ST_SL) g_lastResult="❌ HIT RISK";
   else g_lastResult="⚪ HIT BE";
   g_state=result; g_resultTime=TimeCurrent();
   string msg=g_lastResult+"\n\n"+_Symbol+" • "+g_active.direction+" • "+g_tfLabel+"\n\nRESULT\n"+(resultPips>0?"+":"")+DoubleToString(resultPips,0)+" PIPS\n\nEZYMAP • SCALP MASTERY";
   if(InpAlertResult) AlertUser(msg);
}

bool CalculateMapAndMaybeReady(double livePrice)
{
   MqlRates e[],d[],s[],chart[];

   // Request a healthy history buffer but do not require all requested bars.
   // This is especially important for H4 -> MN1 direction routing, where many
   // broker feeds do not expose 180 monthly candles immediately.
   bool entryReady   = LoadRatesFlexible(g_entryTF,80,30,e);
   bool directionReady=LoadRatesFlexible(g_directionTF,180,70,d);
   bool supportReady = LoadRatesFlexible(g_supportTF,180,50,s);
   bool chartReady   = LoadRatesFlexible((ENUM_TIMEFRAMES)_Period,180,30,chart);

   if(!entryReady || !directionReady || !supportReady || !chartReady)
      return false;

   // Perf: the map (S/R levels, HIGH/LOW RISK zones, confluence, bias) is
   // built entirely from CLOSED-bar data (e[1]/d[1]/s[1] onward), so it is
   // byte-identical on every intrabar tick until the entry-TF bar closes.
   // Skip the full rebuild when we've already computed this entry bar and
   // the map is valid - ManageReady()/ManageActive() still run every tick
   // against the fresh livePrice independently of this function.
   bool sameEntryBar=(e[1].time==g_lastMapCalcTime);
   bool mapValid=(g_S1>0 && g_S2>0 && g_R1>0 && g_R2>0);
   if(sameEntryBar && mapValid)
      return true;
   g_lastMapCalcTime=e[1].time;

   // Symbol engine
   g_pipSize=IsGold()?MathMax(0.10,_Point):(IsBTC()?MathMax(1.0,_Point):_Point);
   g_brnStep=IsGold()?100.0:(IsBTC()?1000.0:MathMax(livePrice*0.01,_Point*100.0));
   g_microStep=IsGold()?50.0:(IsBTC()?500.0:g_brnStep*0.5);
   double confTol=InpConfluenceTolerancePips*g_pipSize;
   double minLevelDist=(IsGold()||IsBTC())?70.0*g_pipSize:MathMax(10.0*g_pipSize,_Point*5.0);

   double entryRef=e[1].close;
   double entryEMA=EMAFromRates(e,ArraySize(e),EMA_LEN,1);
   double dirEMA=EMAFromRates(d,ArraySize(d),EMA_LEN,1);
   double dirEMAPrev=EMAFromRates(d,ArraySize(d),EMA_LEN,2);
   double dirATR=ATRFromRates(d,ArraySize(d),14,1);
   double chartATR=ATRFromRates(chart,ArraySize(chart),14,0);
   double supportEMA=EMAFromRates(s,ArraySize(s),EMA_LEN,1);
   double supportATR=ATRFromRates(s,ArraySize(s),14,1);
   double dirClose=d[1].close;
   g_livePrice=livePrice;
   bool dashboardBullBias=(dirClose>dirEMA && dirEMA>dirEMAPrev);
   bool dashboardBearBias=(dirClose<dirEMA && dirEMA<dirEMAPrev);
   g_biasText=dashboardBullBias?"BULLISH":(dashboardBearBias?"BEARISH":"NEUTRAL");

   double low100=DBL_MAX,high100=-DBL_MAX;
   for(int i=1;i<=MathMin(100,ArraySize(d)-1);i++) { low100=MathMin(low100,d[i].low); high100=MathMax(high100,d[i].high); }
   PickDirectionLevels(d,ArraySize(d),entryRef,minLevelDist,low100,high100,dirATR,g_S1,g_S2,g_R1,g_R2);

   double swingHigh,swingLow,trendSupport,trendResistance;
   SupportMetrics(s,ArraySize(s),InpSupportPivotBars,swingHigh,swingLow,trendSupport,trendResistance);
   // HIGH RISK zones: preserve validated supporting-timeframe selection.
   g_buyHigh=SupportZone(g_S1,s,ArraySize(s));
   g_sellHigh=SupportZone(g_R1,s,ArraySize(s));

   // LOW RISK zones: extreme chart/entry candle that physically overlaps S2/R2,
   // with same-side HIGH RISK separation preferred whenever possible.
   if(InpLowRiskUseChartCandles)
   {
      g_buyLow=LowRiskExtremeOverlapZone(g_S2,g_buyHigh,e,ArraySize(e),true);
      g_sellLow=LowRiskExtremeOverlapZone(g_R2,g_sellHigh,e,ArraySize(e),false);

      // Safe fallback if broker history contains no exact S2/R2 crossing candle.
      if(!g_buyLow.valid)
         g_buyLow=SupportZone(g_S2,s,ArraySize(s));
      if(!g_sellLow.valid)
         g_sellLow=SupportZone(g_R2,s,ArraySize(s));
   }
   else
   {
      g_buyLow=SupportZone(g_S2,s,ArraySize(s));
      g_sellLow=SupportZone(g_R2,s,ArraySize(s));
   }

   double supportRange=(swingHigh!=EMPTY_VALUE && swingLow!=EMPTY_VALUE)?MathAbs(swingHigh-swingLow):EMPTY_VALUE;
   double buyFib50=EMPTY_VALUE,buyFib618=EMPTY_VALUE,sellFib50=EMPTY_VALUE,sellFib618=EMPTY_VALUE;
   if(supportRange!=EMPTY_VALUE)
   {
      buyFib50=swingHigh-supportRange*0.50; buyFib618=swingHigh-supportRange*0.618;
      sellFib50=swingLow+supportRange*0.50; sellFib618=swingLow+supportRange*0.618;
   }
   g_buyHighConf=ConfluenceCount(g_buyHigh,supportEMA,trendSupport,buyFib50,buyFib618,confTol);
   g_sellHighConf=ConfluenceCount(g_sellHigh,supportEMA,trendResistance,sellFib50,sellFib618,confTol);

   // Confirmed entry candle event engine
   bool fresh=(e[1].time!=g_lastEntryClosedTime);
   if(!fresh) return true;

   double recentHigh=-DBL_MAX,recentLow=DBL_MAX;
   int lookback=MathMin(InpEntryHistory-1,InpEntryPivotBars*2+2);
   for(int i=2;i<=lookback+1 && i<ArraySize(e);i++) { recentHigh=MathMax(recentHigh,e[i].high); recentLow=MathMin(recentLow,e[i].low); }
   bool bullBreak=(e[1].high>recentHigh && e[1].close>e[2].close);
   bool bearBreak=(e[1].low<recentLow && e[1].close<e[2].close);
   bool bullBody=e[1].close>e[1].open, bearBody=e[1].close<e[1].open;
   bool bullChoch=bullBreak && g_structureDirection<=0 && (!InpRequireDirectionalBody || bullBody);
   bool bearChoch=bearBreak && g_structureDirection>=0 && (!InpRequireDirectionalBody || bearBody);
   double range=e[1].high-e[1].low, body=MathAbs(e[1].close-e[1].open), safeBody=MathMax(body,_Point);
   double lowerWick=MathMin(e[1].open,e[1].close)-e[1].low;
   double upperWick=e[1].high-MathMax(e[1].open,e[1].close);
   bool bullReject=bullBody && lowerWick>=safeBody*InpRejectionWickRatio && e[1].close>=e[1].low+range*0.45;
   bool bearReject=bearBody && upperWick>=safeBody*InpRejectionWickRatio && e[1].close<=e[1].high-range*0.45;
   if(bullBreak) g_structureDirection=1; if(bearBreak) g_structureDirection=-1;
   UpdateEventAges(bullChoch,bearChoch,bullReject,bearReject);
   g_lastEntryClosedTime=e[1].time;

   if(g_state!=ST_MONITORING) return true;

   bool bullRecentChoch=(g_bullChochAge<=CONFIRM_WINDOW), bearRecentChoch=(g_bearChochAge<=CONFIRM_WINDOW);
   bool bullRecentReject=(g_bullRejectAge<=CONFIRM_WINDOW), bearRecentReject=(g_bearRejectAge<=CONFIRM_WINDOW);

   bool bullishBias=(dirClose>dirEMA && dirEMA>dirEMAPrev);
   bool bearishBias=(dirClose<dirEMA && dirEMA<dirEMAPrev);
   double entryBiasTolerance=MathMax(supportATR*0.60,g_pipSize*15.0);
   bool entryBull=(entryRef>=entryEMA-entryBiasTolerance);
   bool entryBear=(entryRef<=entryEMA+entryBiasTolerance);
   bool trendBuy=bullishBias && entryBull;
   bool trendSell=bearishBias && entryBear;
   bool counterBuy=bearishBias && entryBull && !trendBuy;
   bool counterSell=bullishBias && entryBear && !trendSell;

   int buyRet=ZoneRetests(g_buyHigh,e,ArraySize(e),e[1].time);
   int sellRet=ZoneRetests(g_sellHigh,e,ArraySize(e),e[1].time);
   bool buyAllow=trendBuy||counterBuy, sellAllow=trendSell||counterSell;
   bool buyConfirm=buyAllow && bullRecentReject && (!counterBuy || bullRecentChoch);
   bool sellConfirm=sellAllow && bearRecentReject && (!counterSell || bearRecentChoch);
   int buyReq=counterBuy?COUNTER_MIN_CONFLUENCES:TREND_MIN_CONFLUENCES;
   int sellReq=counterSell?COUNTER_MIN_CONFLUENCES:TREND_MIN_CONFLUENCES;

   double buyLo,buyHi,sellLo,sellHi; datetime buyTm,sellTm;
   bool buyEntry=SelectEntryCandle(g_buyHigh,livePrice,true,e,ArraySize(e),buyLo,buyHi,buyTm);
   bool sellEntry=SelectEntryCandle(g_sellHigh,livePrice,false,e,ArraySize(e),sellLo,sellHi,sellTm);

   double stopPips=(g_mode=="SCALP")?InpScalpStopPips:((g_mode=="INTRADAY")?InpIntradayStopPips:InpSwingStopPips);
   double targetMinP=(g_mode=="SCALP")?InpScalpTargetMinPoints:((g_mode=="INTRADAY")?InpIntradayTargetMinPoints:InpSwingTargetMinPoints);
   double targetMaxP=(g_mode=="SCALP")?InpScalpTargetMaxPoints:((g_mode=="INTRADAY")?InpIntradayTargetMaxPoints:InpSwingTargetMaxPoints);
   double stopMult=(g_mode=="SCALP")?0.40:((g_mode=="INTRADAY")?0.60:0.85);
   double targetMult=(g_mode=="SCALP")?0.60:((g_mode=="INTRADAY")?1.0:1.5);
   double targetMin=targetMinP*g_pipSize,targetMax=targetMaxP*g_pipSize;
   double volStop=MathMax(stopPips*g_pipSize,MathMax(chartATR,targetMin)*stopMult);
   double volTarget=MathMax(chartATR,targetMin)*targetMult;
   double snr=InpSnrFrontRunPips*g_pipSize;

   TradePlan bp,sp; bp.valid=false; sp.valid=false;
   if(buyEntry) bp=BuildTradePlan("BUY",buyHi,buyLo,buyHi,volStop,volTarget,snr,targetMin,targetMax,g_S1,g_S2,g_R1,g_R2,swingLow,swingHigh,trendSupport,trendResistance);
   if(sellEntry) sp=BuildTradePlan("SELL",sellLo,sellLo,sellHi,volStop,volTarget,snr,targetMin,targetMax,g_S1,g_S2,g_R1,g_R2,swingLow,swingHigh,trendSupport,trendResistance);

   bool buyCandidate=buyAllow&&buyConfirm&&buyEntry&&buyRet<=MAX_ZONE_RETESTS&&g_buyHighConf>=buyReq&&bp.valid;
   bool sellCandidate=sellAllow&&sellConfirm&&sellEntry&&sellRet<=MAX_ZONE_RETESTS&&g_sellHighConf>=sellReq&&sp.valid;
   if(!buyCandidate && !sellCandidate) return true;

   bool chooseBuy=false;
   if(buyCandidate && !sellCandidate) chooseBuy=true;
   else if(buyCandidate && sellCandidate)
   {
      if(g_buyHighConf>g_sellHighConf) chooseBuy=true;
      else if(g_buyHighConf==g_sellHighConf)
      {
         double bd=MathAbs((g_buyHigh.lo+g_buyHigh.hi)/2.0-livePrice);
         double sd=MathAbs((g_sellHigh.lo+g_sellHigh.hi)/2.0-livePrice);
         chooseBuy=(bd<=sd);
      }
   }

   ZeroMemory(g_ready);
   if(chooseBuy)
   {
      g_ready.direction="BUY"; g_ready.counterTrend=counterBuy; g_ready.confluences=g_buyHighConf; g_ready.requiredConfluences=buyReq;
      g_ready.zoneRetests=buyRet; g_ready.supportLo=g_buyHigh.lo; g_ready.supportHi=g_buyHigh.hi;
      g_ready.entryLo=buyLo; g_ready.entryHi=buyHi; g_ready.entryTime=buyTm; g_ready.planSL=bp.sl; g_ready.planTP=bp.tp; g_ready.planRR=bp.rr;
   }
   else
   {
      g_ready.direction="SELL"; g_ready.counterTrend=counterSell; g_ready.confluences=g_sellHighConf; g_ready.requiredConfluences=sellReq;
      g_ready.zoneRetests=sellRet; g_ready.supportLo=g_sellHigh.lo; g_ready.supportHi=g_sellHigh.hi;
      g_ready.entryLo=sellLo; g_ready.entryHi=sellHi; g_ready.entryTime=sellTm; g_ready.planSL=sp.sl; g_ready.planTP=sp.tp; g_ready.planRR=sp.rr;
   }
   g_ready.armedClock=TimeCurrent(); g_ready.zoneExited=false; g_state=ST_READY;
   if(InpAlertReady)
   {
      string msg="🟡 "+g_ready.direction+" • SETUP READY\n\n"+_Symbol+" • "+g_mode+" • "+g_tfLabel+"\n\nENTRY ZONE: "+PriceText(g_ready.entryLo)+" - "+PriceText(g_ready.entryHi)+"\nCONFIRMATION: ENTRY ZONE REJECTION\n━━━━━━━━━━━━━━━━\n⏳ WAITING FOR ACTIVATION\n\nEZYMAP • SCALP MASTERY";
      AlertUser(msg);
   }
   return true;
}

void ManageReady(double livePrice)
{
   if(g_state!=ST_READY) return;
   bool inside=(livePrice>=g_ready.entryLo && livePrice<=g_ready.entryHi);
   if(inside)
   {
      double entry=RoundPrice(livePrice),sl=g_ready.planSL,tp=g_ready.planTP,rr=0;
      if(g_ready.direction=="BUY" && sl<entry)
      {
         double risk=entry-sl;
         double minTp=entry+risk*MIN_RR,maxTp=entry+risk*MAX_RR;
         tp=RoundPrice(MathMax(minTp,MathMin(maxTp,tp)));
         rr=(tp-entry)/risk;
      }
      else if(g_ready.direction=="SELL" && sl>entry)
      {
         double risk=sl-entry;
         double highestTarget=entry-risk*MIN_RR,lowestTarget=entry-risk*MAX_RR;
         tp=RoundPrice(MathMax(lowestTarget,MathMin(highestTarget,tp)));
         rr=(entry-tp)/risk;
      }
      if(rr>=MIN_RR-0.0001 && rr<=MAX_RR+0.0001)
      {
         ZeroMemory(g_active);
         g_active.direction=g_ready.direction; g_active.counterTrend=g_ready.counterTrend; g_active.confluences=g_ready.confluences;
         g_active.entry=entry; g_active.sl=sl; g_active.tp=tp; g_active.rr=rr;
         g_active.entryLo=g_ready.entryLo; g_active.entryHi=g_ready.entryHi; g_active.entryTime=g_ready.entryTime; g_active.startClock=TimeCurrent();
         double risk=MathAbs(entry-sl);
         g_active.beTrigger=RoundPrice(g_active.direction=="BUY"?entry+risk*BE_TRIGGER_R:entry-risk*BE_TRIGGER_R);
         g_active.beArmed=false; g_state=ST_ACTIVE;
         PriceMarker("LIVE_MARK",TimeCurrent(),entry,(g_active.direction=="BUY"?"▲ LIVE BUY":"▼ LIVE SELL"),(g_active.direction=="BUY"?InpBuyColor:InpSellColor));
         if(InpAlertLive)
         {
            string msg=(g_active.direction=="BUY"?"🟢 BUY • TRADE ACTIVE":"🔴 SELL • TRADE ACTIVE")+StringFormat("\n\n%s • %s • %s\n\nENTRY: %s\nTAKE PROFIT: %s\nSTOP LOSS: %s\n\nCONFLUENCES: %d\n━━━━━━━━━━━━━━━\n⚡️ POSITION ACTIVE",_Symbol,g_mode,g_tfLabel,PriceText(entry),PriceText(tp),PriceText(sl),g_active.confluences);
            if(g_active.counterTrend) msg+="\n⚠️ COUNTER-TREND TRADE";
            msg+="\n\nEZYMAP • SCALP MASTERY";
            AlertUser(msg);
         }
      }
      else ResetReady();
      return;
   }

   // Frozen READY invalidation rules before first touch.
   if((TimeCurrent()-g_ready.armedClock)>InpReadyExpiryBars*TfSeconds(g_entryTF)) { ResetReady(); return; }
   if(g_ready.direction=="BUY" && livePrice<g_ready.supportLo-g_pipSize*5.0) { ResetReady(); return; }
   if(g_ready.direction=="SELL" && livePrice>g_ready.supportHi+g_pipSize*5.0) { ResetReady(); return; }

   bool touchedSupport=(livePrice>=g_ready.supportLo && livePrice<=g_ready.supportHi);
   if(!touchedSupport) g_ready.zoneExited=true;
   if(g_ready.zoneExited && touchedSupport && g_ready.zoneRetests>=MAX_ZONE_RETESTS) { ResetReady(); return; }
}

void ManageActive(double livePrice)
{
   if(g_state!=ST_ACTIVE) return;

   // Strict LIVE lock: map changes never modify this snapshot.
   bool target=(g_active.direction=="BUY")?(livePrice>=g_active.tp):(livePrice<=g_active.tp);
   bool stop=(g_active.direction=="BUY")?(livePrice<=g_active.sl):(livePrice>=g_active.sl);
   bool trigger=(g_active.direction=="BUY")?(livePrice>=g_active.beTrigger):(livePrice<=g_active.beTrigger);
   if(trigger) g_active.beArmed=true;
   bool be=(g_active.beArmed && ((g_active.direction=="BUY")?(livePrice<=g_active.entry):(livePrice>=g_active.entry)));

   // BE has priority once armed, matching the TradingView v2.4.7 live engine.
   if(be) { FinishTrade(ST_BE,0.0); return; }
   if(stop)
   {
      double p=(g_active.direction=="BUY")?(g_active.sl-g_active.entry)/g_pipSize:(g_active.entry-g_active.sl)/g_pipSize;
      FinishTrade(ST_SL,p); return;
   }
   if(target)
   {
      double p=(g_active.direction=="BUY")?(g_active.tp-g_active.entry)/g_pipSize:(g_active.entry-g_active.tp)/g_pipSize;
      FinishTrade(ST_TP,p); return;
   }
}

void ResetResultAfterTTL()
{
   if((g_state==ST_TP || g_state==ST_SL || g_state==ST_BE) && TimeCurrent()-g_resultTime>=10)
   {
      ZeroMemory(g_active);
      g_state=ST_MONITORING;
      DeleteObject("LIVE_MARK");
   }
}


//-------------------------- Phase 2 Bridge --------------------------
string Phase2SafeSymbolKey()
{
   string s=_Symbol;
   string out="";
   for(int i=0;i<StringLen(s);i++)
   {
      ushort c=StringGetCharacter(s,i);
      bool ok=((c>='A' && c<='Z') || (c>='a' && c<='z') || (c>='0' && c<='9'));
      out += ok ? ShortToString(c) : "_";
   }
   return out;
}

string Phase2GVPrefix()
{
   return "EZP2_"+IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN))+"_"+Phase2SafeSymbolKey()+"_M5_";
}

void Phase2SetGV(string name,double value)
{
   GlobalVariableSet(Phase2GVPrefix()+name,value);
}

void PublishPhase2Bridge()
{
   // Phase 2 execution is intentionally M5 only.
   if(_Period!=PERIOD_M5)
      return;

   double dir=0.0;
   double entryLo=0.0,entryHi=0.0,sl=0.0;
   double conf=0.0,counter=0.0,signalId=0.0,armed=0.0;

   if(g_state==ST_READY)
   {
      dir=(g_ready.direction=="BUY")?1.0:-1.0;
      entryLo=g_ready.entryLo;
      entryHi=g_ready.entryHi;
      sl=g_ready.planSL;
      conf=(double)g_ready.confluences;
      counter=g_ready.counterTrend?1.0:0.0;
      signalId=(double)g_ready.armedClock;
      armed=(double)g_ready.armedClock;
   }
   else if(g_state==ST_ACTIVE || g_state==ST_TP || g_state==ST_SL || g_state==ST_BE)
   {
      dir=(g_active.direction=="BUY")?1.0:-1.0;
      entryLo=g_active.entryLo;
      entryHi=g_active.entryHi;
      sl=g_active.sl;
      conf=(double)g_active.confluences;
      counter=g_active.counterTrend?1.0:0.0;

      // Keep the READY identifier stable through the full lifecycle.
      signalId=(double)g_ready.armedClock;
      armed=(double)g_ready.armedClock;
   }

   Phase2SetGV("HEARTBEAT",(double)TimeCurrent());
   Phase2SetGV("STATE",(double)g_state);
   Phase2SetGV("DIR",dir);
   Phase2SetGV("ENTRY_LO",entryLo);
   Phase2SetGV("ENTRY_HI",entryHi);
   Phase2SetGV("SL",sl);
   Phase2SetGV("CONF",conf);
   Phase2SetGV("COUNTER",counter);
   Phase2SetGV("SIGNAL_ID",signalId);
   Phase2SetGV("ARMED_TIME",armed);
}

void ClearPhase2Bridge()
{
   if(_Period!=PERIOD_M5)
      return;

   string p=Phase2GVPrefix();
   GlobalVariableDel(p+"HEARTBEAT");
   GlobalVariableDel(p+"STATE");
   GlobalVariableDel(p+"DIR");
   GlobalVariableDel(p+"ENTRY_LO");
   GlobalVariableDel(p+"ENTRY_HI");
   GlobalVariableDel(p+"SL");
   GlobalVariableDel(p+"CONF");
   GlobalVariableDel(p+"COUNTER");
   GlobalVariableDel(p+"SIGNAL_ID");
   GlobalVariableDel(p+"ARMED_TIME");
}

//--------------------------- MT5 events -----------------------------
int OnInit()
{
   if(!ConfigureRouting())
   {
      Alert(PRODUCT_NAME+" "+PRODUCT_VERSION+": use M1, M5, M15, M30, H1 or H4 chart.");
      return INIT_FAILED;
   }
   g_indicatorShortName=PRODUCT_NAME+" "+PRODUCT_VERSION+" MT5 PHASE2 BRIDGE";
   IndicatorSetString(INDICATOR_SHORTNAME,g_indicatorShortName);

   if(!EzyMapLicenseGate(SCRIPT_ID,PREFIX,PRODUCT_NAME))
   {
      EventSetTimer(1);
      ChartRedraw(0);
      return INIT_SUCCEEDED;
   }

   ZeroMemory(g_ready); ZeroMemory(g_active); g_ready.direction="NONE"; g_active.direction="NONE";
   ApplyPremiumChartTheme();

   // UI must be visible immediately, even before all MTF history is loaded.
   g_biasText="NEUTRAL";
   DrawDashboard();
   DrawTradeCard();
   DrawCloseButton();
   PublishPhase2Bridge();
   ChartRedraw(0);

   // Timer keeps dashboard/card alive even when M1 history is still synchronizing
   // or the market is temporarily not producing ticks.
   EventSetTimer(1);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   ClearPhase2Bridge();
   ClearHistoricalMarkers();
   ObjectsDeleteAll(0,PREFIX);
   ChartRedraw(0);
}

void OnTimer()
{
   if(!EzyMapLicenseRecheck(SCRIPT_ID,PREFIX,PRODUCT_NAME)) return;

   // UI heartbeat independent from OnCalculate / tick availability.
   // Also re-attempt map construction after MT5 finishes loading higher-TF history.
   double livePrice=SymbolInfoDouble(_Symbol,SYMBOL_BID);

   if(livePrice>0 && (g_S1<=0 || g_S2<=0 || g_R1<=0 || g_R2<=0))
      CalculateMapAndMaybeReady(livePrice);

   DrawMap(TimeCurrent());
   DrawDashboard();
   DrawTradeCard();
   DrawCloseButton();
   PublishPhase2Bridge();
   ChartRedraw(0);
}

int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],const double &open[],const double &high[],const double &low[],const double &close[],const long &tick_volume[],const long &volume[],const int &spread[])
{
   if(!EzyMapLicenseRecheck(SCRIPT_ID,PREFIX,PRODUCT_NAME)) return 0;

   // Keep UI visible even while history is still loading.
   DrawDashboard();
   DrawTradeCard();
   DrawCloseButton();
   ChartRedraw(0);

   if(rates_total<100) return 0;
   double livePrice=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(livePrice<=0) livePrice=close[rates_total-1];

   ResetResultAfterTTL();
   CalculateMapAndMaybeReady(livePrice);
   ManageReady(livePrice);
   ManageActive(livePrice);
   DrawMap(TimeCurrent());
   DrawDashboard();
   DrawTradeCard();
   DrawCloseButton();
   PublishPhase2Bridge();
   ChartRedraw(0);
   return rates_total;
}

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id==CHARTEVENT_OBJECT_CLICK && EzyMapIsLicenseCloseClick(PREFIX,sparam))
   {
      ChartIndicatorDelete(0,0,g_indicatorShortName);
      return;
   }
   if(id==CHARTEVENT_OBJECT_CLICK && sparam==PREFIX+"CLOSE_BTN")
   {
      ChartIndicatorDelete(0,0,g_indicatorShortName);
      return;
   }
}
//+------------------------------------------------------------------+
