# EzyMap License Server

Subscription/licensing backend for the 17 EzyMap MT5 tools, plus a
self-service checkout page that auto-grants a subscription the moment a
customer pays (via Xendit) - no manual admin work per sale.

Locks each tool to a paying account (by MT5 login number) so a leaked
`.ex5` file is useless without an active subscription - the compiled file
still runs, but it phones home on startup and periodically afterwards,
and refuses to work if the account behind it isn't paid up.

## The products

- **bundle** - one subscription, unlocks all 17 tools.
- 5 "hot selling" tools are ALSO sold individually - a customer can buy
  just one of these without the rest (also included free in `bundle`):
  - `bulkclose` -> `EzyMap_BulkClose`
  - `drawdownguardian` -> `EzyMap_DrawdownGuardian`
  - `autotpsl` -> `EzyMap_AutoTPSL`
  - `currencystrength` -> `EzyMap_CurrencyStrengthMeter`
  - `mtfbias` -> `EzyMap_MTFBiasDashboard`

All products are sold in **1 month / 6 months / 1 year** tiers. See
`lib/products.js` for the tool-to-product mapping and `lib/pricing.js`
for prices - both are the single source of truth, edit them freely. The
other 12 tools require `bundle` only.

## 1. Run it

```bash
cd EzyMapLicenseServer
npm install
cp .env.example .env   # then fill in ADMIN_TOKEN at minimum
npm start
```

Runs on port 3000 by default. For real customers this needs to be
deployed somewhere always-on and publicly reachable with HTTPS (MT5's
`WebRequest()` requires it) - see the beginner deployment walkthrough
below.

## 2. Self-service checkout (Xendit)

Visiting `/checkout.html` on your server shows customers a payment page:
pick a product + tier, type their MT5 account number, pay - their
subscription unlocks automatically within about a minute, no manual
`admin.js grant` needed.

### One-time Xendit setup

1. Create a Xendit account at **xendit.co** (supports MYR, IDR, PHP and
   more, plus e-wallets like GrabPay/Touch 'n Go and local bank
   transfers - good fit for Southeast Asian customers).
2. Dashboard -> **Settings -> API Keys** -> copy your **Secret Key**
   (starts with `xnd_development_...` for testing, `xnd_production_...`
   once you're live).
3. Add it to `.env`:
   ```
   XENDIT_SECRET_KEY=xnd_development_xxxxxxxxxxxx
   ```
4. Dashboard -> **Settings -> Callbacks** -> find "Invoices Callback" ->
   set the URL to `https://your-server-url/webhook/xendit` -> copy the
   **Verification Token** shown there.
5. Add it to `.env`:
   ```
   XENDIT_CALLBACK_TOKEN=<the verification token from step 4>
   ```
6. Restart the server. Open `https://your-server-url/checkout.html` and
   do a small test purchase using Xendit's test mode - confirm
   `node admin.js list --account <the test account>` shows the grant
   landed within a minute of "paying."
7. Once happy, switch `XENDIT_SECRET_KEY` to your production key and
   Xendit's dashboard out of test mode.

If a payment comes in with a status other than `PAID`/`SETTLED` (e.g.
`EXPIRED`), nothing is granted - only confirmed payments unlock anything.

### What actually happens on a purchase

1. Customer fills the form on `/checkout.html` -> browser posts to
   `/checkout/create`.
2. Server looks up the price in `lib/pricing.js`, creates a Xendit
   invoice with `external_id` encoding `grant_<account>_<product>_<tier>_<random>`,
   and redirects the customer to Xendit's hosted payment page.
3. Customer pays (card, bank transfer, e-wallet - whatever Xendit
   offers them).
4. Xendit calls `POST /webhook/xendit` on your server with the invoice
   status. If `PAID`/`SETTLED`, the server parses the `external_id` back
   apart and calls the same `store.grant()` the admin CLI uses.
5. Customer is redirected to `/thanks.html`. Their MT5 tool picks up the
   new license on its next periodic check (within `InpEzyLicenseRecheckMinutes`,
   default 30 min - or immediately if they restart the tool).

## 3. Grant/manage subscriptions manually (admin CLI)

Still useful for bank-transfer customers, refunds, or anything outside
the automated checkout.

```bash
# New customer buys Drawdown Guardian standalone, 6 months, paid by bank transfer:
node admin.js grant --account 12345678 --product drawdownguardian --tier 6m --note "bank transfer receipt #123"

# New customer buys the full Bundle for 1 year:
node admin.js grant --account 87654321 --product bundle --tier 1y

# Renewing early extends from the CURRENT expiry, not from today - no
# paid-for time is lost:
node admin.js grant --account 12345678 --product drawdownguardian --tier 1m

# Stop a subscription (chargeback, refund, abuse):
node admin.js revoke --account 12345678 --product drawdownguardian

# See everything:
node admin.js list

# See one customer:
node admin.js list --account 12345678

# Test what a specific tool would see for a specific account (mirrors
# exactly what the server endpoint returns):
node admin.js check --account 12345678 --script EzyMap_BulkClose
```

Products: `bundle`, `bulkclose`, `drawdownguardian`, `autotpsl`,
`currencystrength`, `mtfbias`. Tiers: `1m` (30 days), `6m` (182 days),
`1y` (365 days), `trial` (3 days).

`trial` is intentionally not offered on `/checkout.html` (it has no price
in `lib/pricing.js`) - it's meant to be granted by `admin.js grant` or an
external bot (e.g. ASAP-TeleBot's trial.py) calling `/admin/grant`
directly. Each account/product pair can only ever receive one trial -
`store.js` remembers this in `data/trials.json`, separately from the
subscription record itself, so revoking or upgrading past a trial doesn't
make that account trial-eligible again.

Subscriptions are stored in `data/subscriptions.json` (gitignored - this
is real customer data, back it up separately, e.g. a periodic `scp`/cron
copy off the server). Trial usage is tracked separately in
`data/trials.json` (also gitignored, same backup advice).

### Managing a DEPLOYED server from your own computer

By default `node admin.js ...` edits the local `data/subscriptions.json`
file on whichever computer you run it from. That's only useful for
testing - once the server is deployed elsewhere, that's a different file
on a different machine.

To manage the live server instead, add two lines to your local `.env`:

```
EZYMAP_SERVER_URL=https://your-deployed-url
ADMIN_TOKEN=<same token you set in the deployed server's .env>
```

Every `node admin.js grant/revoke/list/check` command then talks to the
live server over HTTPS instead of touching a local file - same commands,
same output, just pointed at production.

## 4. Wire it into MT5

Every `.mq5` file already `#include`s `EzyMapLicense.mqh` (in the repo
root, next to the tools) and calls the license check on `OnInit` plus a
periodic re-check on `OnTimer`/`OnTick`. Nothing to add per-tool - just:

1. **Deploy this server** somewhere with a stable HTTPS URL.
2. **Whitelist that URL in every customer's MT5**: Tools > Options >
   Expert Advisors tab > check "Allow WebRequest for listed URL" > add
   the server's URL. (If they forget this step, the tool shows exactly
   this instruction on-chart instead of a cryptic error.)
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
VALID|2026-09-13T04:05:28.593Z|bulkclose|1m
INVALID|No active EzyMap subscription found for this account. Contact EzyMap to purchase/renew.
```

If invalid (or the server is unreachable, or the WebRequest URL isn't
whitelisted yet), the tool shows a small on-chart "License Required"
panel with the reason and its own close button instead of its normal
GUI - it does not silently fail or crash.

## 5. Full beginner walkthrough (deploying on Railway)

1. Railway.app -> sign in with GitHub -> New Project -> Deploy from GitHub
   repo -> pick your EzyMap repo.
2. Service Settings -> set **Root Directory** to `EzyMapLicenseServer`.
3. Service Variables -> add `ADMIN_TOKEN`, `XENDIT_SECRET_KEY`,
   `XENDIT_CALLBACK_TOKEN` (see Xendit setup above).
4. Service -> Volumes -> New Volume -> mount path `/app/data` (keeps
   `subscriptions.json` and `trials.json` alive across restarts/redeploys).
5. Settings -> Networking -> Generate Domain -> gives you a free
   `https://....up.railway.app` URL with HTTPS already handled.
6. Visit `https://your-url/health` - should show `ok`. Visit
   `https://your-url/checkout.html` - should show the payment page.
7. Point Xendit's Invoices Callback URL at `https://your-url/webhook/xendit`.
8. In your OWN computer's `EzyMapLicenseServer/.env`, set
   `EZYMAP_SERVER_URL` to that URL and `ADMIN_TOKEN` to the same value
   from step 3 - now `node admin.js grant ...` manages the live server.
9. Set `InpEzyLicenseServerURL` to that URL in every tool before
   compiling the `.ex5` you distribute.
10. Tell customers to whitelist that URL under Tools > Options > Expert
    Advisors > Allow WebRequest for listed URL.

## Adding a new tool or product later

Add its script id to `SCRIPT_REQUIREMENTS` in `lib/products.js` (either
`['bundle']` or `['bundle','<productId>']`) and, if it's a new standalone
product, its price to `lib/pricing.js`. Then in the new `.mq5` file
mirror the pattern used in any existing tool: `#include <EzyMapLicense.mqh>`,
`#define SCRIPT_ID "EzyMap_YourToolName"`, call `EzyMapLicenseGate(...)`
as the first line of `OnInit`, and `EzyMapLicenseRecheck(...)` in
`OnTimer`/`OnTick`.
