//+------------------------------------------------------------------+
//| EzyMapLicense.mqh                                                 |
//| Shared license-check client for the EzyMap MT5 tool suite.        |
//| #include this file, then in your script:                          |
//|                                                                    |
//|   OnInit()                                                        |
//|   {                                                                |
//|      if(!EzyMapLicenseGate(SCRIPT_ID,PREFIX,PRODUCT_NAME))         |
//|      {                                                             |
//|         ChartRedraw(0);                                            |
//|         return(INIT_SUCCEEDED);   // locked panel already shown    |
//|      }                                                             |
//|      ... your normal BuildGUI()/setup here ...                     |
//|   }                                                                |
//|                                                                    |
//|   OnTimer() / OnCalculate()  (call once per tick/timer to keep     |
//|                                re-validating in the background)    |
//|   {                                                                |
//|      if(!EzyMapLicenseRecheck(SCRIPT_ID,PREFIX,PRODUCT_NAME)) return;|
//|      ... your normal refresh logic here ...                        |
//|   }                                                                |
//|                                                                    |
//|   OnChartEvent(...)                                                |
//|   {
//|      if(EzyMapIsLicenseCloseClick(PREFIX,sparam))                  |
//|      {                                                             |
//|         ChartIndicatorDelete(0,0,PRODUCT_NAME); // or ExpertRemove()|
//|         return;                                                    |
//|      }                                                             |
//|      ...                                                           |
//|   }                                                                |
//|                                                                    |
//| SCRIPT_ID must match the id this tool is registered under on the   |
//| license server (see EzyMapLicenseServer/lib/products.js) - e.g.    |
//| "EzyMap_BulkClose".                                                |
//+------------------------------------------------------------------+
#property copyright "EzyMap"
#property strict

input string InpEzyLicenseServerURL      = "http://127.0.0.1:3000"; // EzyMap license server URL
input int    InpEzyLicenseRecheckMinutes = 30;                      // Re-check subscription every N minutes

bool     __EzyLic_Valid     = false;
bool     __EzyLic_Checked   = false;
datetime __EzyLic_LastCheck = 0;
string   __EzyLic_Reason    = "";

//----------------------------- Networking ----------------------------
bool EzyMap_DoLicenseRequest(string scriptId, string &reasonOut)
{
   long acct = AccountInfoInteger(ACCOUNT_LOGIN);
   string url = InpEzyLicenseServerURL + "/license/check?account=" + IntegerToString(acct) + "&script=" + scriptId;

   char post[]; char result[]; string headers = "";
   ResetLastError();
   int res = WebRequest("GET", url, "", 5000, post, result, headers);
   if(res == -1)
   {
      int err = GetLastError();
      if(err == 4060)
         reasonOut = "Add this URL under Tools > Options > Expert Advisors > Allow WebRequest for listed URL: " + InpEzyLicenseServerURL;
      else
         reasonOut = "License server unreachable (error " + IntegerToString(err) + "). Check your internet connection.";
      return false;
   }

   string response = CharArrayToString(result);
   string parts[];
   int n = StringSplit(response, '|', parts);
   if(n >= 1 && parts[0] == "VALID")
   {
      reasonOut = (n >= 3) ? ("Licensed via " + parts[2] + (n >= 2 ? (" - expires " + parts[1]) : "")) : "Licensed.";
      return true;
   }
   reasonOut = (n >= 2) ? parts[1] : "No active subscription found for this account.";
   return false;
}

//----------------------------- Locked panel ---------------------------
void EzyLic_SetCommon(string n, int zorder)
{
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, n, OBJPROP_BACK, false);
   ObjectSetInteger(0, n, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(0, n, OBJPROP_ZORDER, zorder);
}

void EzyLic_MakeRect(string n, int x, int y, int w, int h, color bg, color border)
{
   if(ObjectFind(0, n) < 0) ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, n, OBJPROP_BORDER_COLOR, border);
   ObjectSetInteger(0, n, OBJPROP_COLOR, border);
   EzyLic_SetCommon(n, 900);
}

void EzyLic_MakeLabel(string n, int x, int y, string text, color clr, int size, bool bold)
{
   if(ObjectFind(0, n) < 0) ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, n, OBJPROP_FONT, bold ? "Arial Bold" : "Arial");
   ObjectSetString(0, n, OBJPROP_TEXT, text);
   EzyLic_SetCommon(n, 901);
}

// NOTE: SELECTABLE must be FALSE (handled by EzyLic_SetCommon) or the
// first click just selects the button instead of firing it.
void EzyLic_MakeButton(string n, int x, int y, int w, int h, string text, color bg, color txt)
{
   if(ObjectFind(0, n) < 0) ObjectCreate(0, n, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, n, OBJPROP_COLOR, txt);
   ObjectSetInteger(0, n, OBJPROP_BORDER_COLOR, C'56,65,76');
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, n, OBJPROP_FONT, "Arial Bold");
   ObjectSetString(0, n, OBJPROP_TEXT, text);
   ObjectSetInteger(0, n, OBJPROP_STATE, false);
   EzyLic_SetCommon(n, 902);
}

void EzyLic_WrapText(string text, int maxChars, string &lines[])
{
   ArrayResize(lines, 0);
   string words[];
   int wc = StringSplit(text, ' ', words);
   string cur = "";
   for(int i = 0; i < wc; i++)
   {
      string candidate = (cur == "") ? words[i] : (cur + " " + words[i]);
      if(StringLen(candidate) > maxChars && cur != "")
      {
         int n = ArraySize(lines);
         ArrayResize(lines, n + 1);
         lines[n] = cur;
         cur = words[i];
      }
      else cur = candidate;
   }
   if(cur != "")
   {
      int n = ArraySize(lines);
      ArrayResize(lines, n + 1);
      lines[n] = cur;
   }
   if(ArraySize(lines) == 0)
   {
      ArrayResize(lines, 1);
      lines[0] = text;
   }
}

// Draws a small "License Required" panel with the server's reason text
// and its own close (X) button, namespaced under prefix+"EZLIC_" so it
// never collides with the host tool's own GUI object names.
void EzyMapDrawLockedPanel(string prefix, string productName, string reason)
{
   string lines[];
   EzyLic_WrapText(reason, 52, lines);
   int maxLines = 4;
   if(ArraySize(lines) > maxLines) ArrayResize(lines, maxLines);

   int x = 14, y = 38, w = 380;
   int lineH = 16;
   int h = 74 + ArraySize(lines) * lineH;

   EzyLic_MakeRect(prefix + "EZLIC_BG", x, y, w, h, C'20,10,12', C'235,72,96');
   EzyLic_MakeButton(prefix + "EZLIC_CLOSE", x + w - 38, y + 6, 30, 26, "✕", C'40,14,18', C'235,72,96');
   EzyLic_MakeLabel(prefix + "EZLIC_TITLE", x + 12, y + 10, productName + " - License Required", C'235,110,130', 10, true);

   for(int i = 0; i < ArraySize(lines); i++)
      EzyLic_MakeLabel(prefix + "EZLIC_L" + IntegerToString(i), x + 12, y + 34 + i * lineH, lines[i], C'204,211,218', 9, false);

   EzyLic_MakeLabel(prefix + "EZLIC_FOOT", x + 12, y + 34 + ArraySize(lines) * lineH + 6,
                     "Contact EzyMap to purchase or renew your subscription.", C'150,155,162', 8, false);

   ChartRedraw(0);
}

void EzyMapRemoveLockedPanel(string prefix)
{
   ObjectDelete(0, prefix + "EZLIC_BG");
   ObjectDelete(0, prefix + "EZLIC_CLOSE");
   ObjectDelete(0, prefix + "EZLIC_TITLE");
   ObjectDelete(0, prefix + "EZLIC_FOOT");
   for(int i = 0; i < 6; i++) ObjectDelete(0, prefix + "EZLIC_L" + IntegerToString(i));
}

//----------------------------- Public API -----------------------------
bool EzyMapCheckLicense(string scriptId)
{
   string reason = "";
   bool ok = EzyMap_DoLicenseRequest(scriptId, reason);
   __EzyLic_Valid     = ok;
   __EzyLic_Checked   = true;
   __EzyLic_LastCheck = TimeCurrent();
   __EzyLic_Reason    = reason;
   if(!ok) Print("EzyMap License [", scriptId, "]: ", reason);
   return ok;
}

// Call as the FIRST line of OnInit(). Returns true if licensed (proceed
// with your normal setup). Returns false if not - a "License Required"
// panel has already been drawn; just return(INIT_SUCCEEDED) and skip setup.
bool EzyMapLicenseGate(string scriptId, string prefix, string productName)
{
   bool ok = EzyMapCheckLicense(scriptId);
   if(!ok) EzyMapDrawLockedPanel(prefix, productName, __EzyLic_Reason);
   return ok;
}

// Call once per OnTimer/OnCalculate tick to keep re-validating in the
// background without hammering the server - only actually re-checks every
// InpEzyLicenseRecheckMinutes. Returns the (possibly cached) valid state.
// If the state flips to invalid mid-session, the locked panel is redrawn
// automatically - bail out of your own refresh logic when this is false.
bool EzyMapLicenseRecheck(string scriptId, string prefix, string productName)
{
   if(!__EzyLic_Checked) return EzyMapLicenseGate(scriptId, prefix, productName);
   if(TimeCurrent() - __EzyLic_LastCheck < InpEzyLicenseRecheckMinutes * 60) return __EzyLic_Valid;

   bool wasValid = __EzyLic_Valid;
   bool ok = EzyMapCheckLicense(scriptId);
   if(!ok) EzyMapDrawLockedPanel(prefix, productName, __EzyLic_Reason);
   else if(!wasValid) EzyMapRemoveLockedPanel(prefix);
   return ok;
}

// Detects a click on the locked panel's own close (X) button - wire into
// OnChartEvent alongside your existing close-button handling.
bool EzyMapIsLicenseCloseClick(string prefix, string sparam)
{
   return (sparam == prefix + "EZLIC_CLOSE");
}
