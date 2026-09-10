# EzyMap Telegram Bot

Phase 1: standalone calculators (Lot Size, Margin). No MT5 connection needed -
runs anywhere Node.js runs, works from any phone via Telegram.

## 1. Create the bot (one-time, ~2 minutes)

1. Open Telegram, search for **@BotFather**, start a chat.
2. Send `/newbot`, follow the prompts (pick a name and a username ending in `bot`).
3. BotFather replies with a token like `123456789:ABCdefGhIJKlmNoPQRstuVwxyZ`. Copy it.

## 2. Run it locally (for testing)

```bash
cd EzyMapBot
npm install
cp .env.example .env
# paste your token into .env
npm start
```

Open Telegram, find your bot by the username you chose, send `/start`.

## 3. Deploy it (so it stays running without your computer on)

Any small always-on host works - e.g. a $5/mo VPS (Vultr, DigitalOcean,
Hetzner), or a free-tier platform like Railway/Render. Steps are the same
as running locally:

```bash
git clone <this repo>
cd EzyMapBot
npm install
# set TELEGRAM_BOT_TOKEN as an environment variable (or .env file)
npm start
```

Keep it alive with a process manager, e.g. `pm2 start index.js --name ezymap-bot`.

## Usage

- `📏 Lot Size` → send `Pair, Capital, SL distance (PIPS)`
  e.g. `XAUUSD, 500, 30` (30 pips = $3 on gold)
  **Note: pips, not points** - unlike the MT5 desktop tool, which uses raw
  broker points. Points depend on your specific broker's quote digits (a
  10x difference between 4-digit and 5-digit brokers), which this bot has
  no way to know without a live connection. Pips are standardized and
  don't have that problem, so that's what this bot uses - don't type the
  same number you'd use on the MT5 version and expect the same result.
- `💰 Margin` → send `Pair, Lots, Leverage, Current Price`
  e.g. `XAUUSD, 0.10, 500, 2015.30` (type the price you see on your MT5 chart -
  this bot has no live feed)

Supported pairs: EURUSD, GBPUSD, AUDUSD, USDJPY, USDCAD, USDCHF, XAUUSD,
XAGUSD, BTCUSD, LTCUSD, ETHUSD.

## Notes on accuracy

- Lot Size Calculator matches the MQL5 EzyMap_LotSizeCalculator exactly
  (same pip conventions, same 0.5%/10%/25% risk tiers), using standard
  contract sizes since there's no live broker connection to query.
- Margin Calculator uses the standard `lots × contractSize × price / leverage`
  formula. It's a close approximation for standard accounts, not an exact
  match to your broker's real margin (which can vary by account type/tiered
  margin schedules - use the MT5 version for exact numbers before entering
  a trade near your margin limit).
- Indices and oil are intentionally not supported - their per-point value
  varies too much broker-to-broker to standardize safely without live data.

## What's next (Phase 2)

Bulk Close, Auto TP/SL, and Drawdown Guardian control real MT5 positions,
which this standalone bot cannot do - that needs a remote-control bridge
(an MT5-side EA + a small backend server the bot talks to). See the
`EzyMapBridge/` folder once that's built.
