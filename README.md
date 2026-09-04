# EzyMap

A Pine Script v6 TradingView indicator for XAUUSD/BTCUSD (and other symbols) that maps
higher-timeframe support/resistance zones and generates live BUY/SELL trade signals with
Telegram-ready alerts, a trade card, and a dashboard.

## Current version

**`EzyMap_Pro_V3_0.pine`** is the newest build, on branch `claude/pine-script-live-signals-a3w95t`.

> **Not yet compiled.** V3.0 combines a large batch of changes (expectancy math, entry
> selectivity filters, and a plan-builder consolidation) in one pass with no TradingView
> compiler access during development. Test it in the Pine Editor before using it for live
> alerts. `EzyMap_Pro_V2_0.pine` is the last version that's been through a real user
> compile pass and is a safer fallback if V3.0 needs fixes.

## Active lineage

The current line of development restarted from V1.4 (its live-signal quality outperformed
the later V2/V3 experiments below) and moved forward from there:

| File | What changed |
|---|---|
| `EzyMap_Pro_V1_4.pine` | Baseline: refined S1/S2/R1/R2 zone construction |
| `EzyMap_Pro_V1_5.pine` | Reliability fixes ported from the V2 line + close-to-high/low-to-close zone sizing |
| `EzyMap_Pro_V1_6.pine` | Raised minimum confluence threshold (win-rate experiment) |
| `EzyMap_Pro_V1_7.pine` | Reverted confluence to 0; live signal triggers from LOW RISK zones only |
| `EzyMap_Pro_V1_8.pine` | HIGH and LOW risk zones both independently trigger live signals |
| `EzyMap_Pro_V1_9.pine` | Added fair value gap (FVG) fill as a confirmation type |
| `EzyMap_Pro_V2_0.pine` | **Rebuild Stage 1 — tally fixes** (see below) |
| `EzyMap_Pro_V3_0.pine` | **Rebuild Stages 2–4 combined** — expectancy, selectivity, plan-builder consolidation |

Every version is kept as its own file rather than overwritten, so any two versions can be
diffed or compared directly on chart.

## The V2 Rebuild Plan

Starting at V2.0, development follows a staged audit-and-rebuild plan (tally →
expectancy → win rate → architecture, in that order — see the plan doc for the full
reasoning):

1. **Stage 1 (V2.0, done):** tally fixes — the chart and Telegram alerts now describe the
   same trade every time. Expect the apparent historical win rate to look lower than
   earlier versions; that's measurement error being removed, not a regression.
2. **Stages 2–4 (V3.0, combined per request):** expectancy (R:R floor, structural stops,
   two-target exit, spread modeling), selectivity (tiered confirmation, zone-anchored
   CHOCH, session/volatility/cooldown gates), and a partial architecture cleanup (a single
   shared plan-building function). The plan's own recommendation was to roll these out
   separately and A/B test the selectivity filters one at a time; V3.0 bundles them, so if
   results look off there's no way to isolate which change is responsible.

## Other files in this repo

- `EzyMap_Lite_V1_0.pine`, `EzyMap_Lite_V3.pine` — map-only builds (zone drawing, no live
  signal engine), lighter weight for chart-reference use.
- `EzyMap_Gold_BTC_v4_5_2.pine` through `v4_7_0.pine` — earlier legacy lineage that the
  V1.x/Pro series builds on.
- `EzyMap_Pro_V2.pine` through `V2_4.pine`, `EzyMap_Pro_V3.pine`, `V3_1.pine` — an earlier
  V2/V3 experimental branch, superseded when development restarted from V1.4 (see "Active
  lineage" above). Kept for reference, not part of the current path.

## Usage

Open the current version's `.pine` file, copy its contents into TradingView's Pine
Editor, and add it to a chart. Inputs are grouped under Engine, Confirmation, Risk,
Display, Alerts, and Trade Management in the indicator's settings panel.
