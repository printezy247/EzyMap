# EzyMap License Server

Subscription/licensing backend for the 17 EzyMap MT5 tools. Locks each
tool to a paying account (by MT5 login number) so a leaked `.ex5` file is
useless without an active subscription - the compiled file still runs,
but it phones home on startup and periodically afterwards, and refuses to
work if the account behind it isn't paid up.

## The two products

- **bundle** - one subscription, unlocks all 17 tools.
- **elite5** - a cheaper, standalone subscription that unlocks ONLY these
  5 tools (also included in bundle - elite5 is just a lower-priced entry
  point for customers who only want these 5):
  - `EzyMap_AutoTPSL`
  - `EzyMap_BulkClose`
  - `EzyMap_CurrencyStrengthMeter`
  - `EzyMap_MTFBiasDashboard`
  - `EzyMap_DrawdownGuardian`

Both products are sold in **1 month / 6 months / 1 year** tiers (see
`lib/products.js` for the exact day counts and to add more tiers/products
later). The other 12 tools require `bundle` only.

## 1. Run it

```bash
cd EzyMapLicenseServer
npm install
npm start
```

Runs on port 3000 by default (copy `.env.example` to `.env` to change it).
For real customers this needs to be deployed somewhere always-on and
publicly reachable (same options as the Telegram bot - a $5/mo VPS,
Railway, Render, etc). MT5's `WebRequest()` requires **https** in most
broker builds for anything but localhost, so for production put this
behind a reverse proxy with a real TLS certificate (e.g. Caddy, or
Railway/Render's built-in HTTPS) rather than serving plain http.

## 2. Grant/manage subscriptions (admin CLI)

```bash
# New customer buys the Elite5 6-month plan:
node admin.js grant --account 12345678 --product elite5 --tier 6m --note "PayPal #123"

# New customer buys the full Bundle for 1 year:
node admin.js grant --account 87654321 --product bundle --tier 1y

# Renewing early extends from the CURRENT expiry, not from today - no
# paid-for time is lost:
node admin.js grant --account 12345678 --product elite5 --tier 1m

# Stop a subscription (chargeback, refund, abuse):
node admin.js revoke --account 12345678 --product elite5

# See everything:
node admin.js list

# See one customer:
node admin.js list --account 12345678

# Test what a specific tool would see for a specific account (mirrors
# exactly what the server endpoint returns):
node admin.js check --account 12345678 --script EzyMap_BulkClose
```

Tiers: `1m` (30 days), `6m` (182 days), `1y` (365 days).

Subscriptions are stored in `data/subscriptions.json` (gitignored - this
is real customer data, back it up separately, e.g. a periodic `scp`/cron
copy off the server).

## 3. Wire it into MT5

Every `.mq5` file already `#include`s `EzyMapLicense.mqh` (in the repo
root, next to the tools) and calls the license check on `OnInit` plus a
periodic re-check on `OnTimer`/`OnTick`. Nothing to add per-tool - just:

1. **Deploy this server** somewhere with a stable URL (e.g.
   `https://license.yourdomain.com`).
2. **Whitelist that URL in every customer's MT5**: Tools > Options >
   Expert Advisors tab > check "Allow WebRequest for listed URL" > add
   the server's URL. (If they forget this step, the tool shows exactly
   this instruction on-chart instead of a cryptic error - see
   `EzyMapLicense.mqh`.)
3. Each tool has an input `InpEzyLicenseServerURL` (defaults to
   `http://127.0.0.1:3000` for local testing) - set this to your real
   server URL before compiling the `.ex5` you distribute, so customers
   never have to touch it.
4. `InpEzyLicenseRecheckMinutes` (default 30) controls how often a
   running tool re-validates in the background - if you revoke someone
   mid-session, they lose access within that window, not just on restart.

### How the check works

`GET /license/check?account=<mt5_login>&script=<tool_id>` returns plain
text (not JSON, so MQL5's `StringSplit` can parse it with no library):

```
VALID|2026-09-13T04:05:28.593Z|elite5|1m
INVALID|No active EzyMap subscription found for this account. Contact EzyMap to purchase/renew.
```

If invalid (or the server is unreachable, or the WebRequest URL isn't
whitelisted yet), the tool shows a small on-chart "License Required"
panel with the reason and its own close button instead of its normal
GUI - it does not silently fail or crash.

## Adding a new tool later

Add its id to `SCRIPT_REQUIREMENTS` in `lib/products.js` (either
`['bundle']` or `['bundle','elite5']`), then in the new `.mq5` file mirror
the pattern used in any existing tool: `#include <EzyMapLicense.mqh>`,
`#define SCRIPT_ID "EzyMap_YourToolName"`, call `EzyMapLicenseGate(...)`
as the first line of `OnInit`, and `EzyMapLicenseRecheck(...)` in
`OnTimer`/`OnTick`.
