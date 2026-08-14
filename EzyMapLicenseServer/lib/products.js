// Defines the two commercial products and which of the 17 EzyMap MT5 tools
// each one unlocks.
//
// - "bundle": one subscription, unlocks all 17 tools.
// - "elite5": a cheaper, standalone subscription that unlocks ONLY the 5
//   named hot-selling tools. Someone who owns "bundle" already has access
//   to these 5 too - elite5 exists purely as a lower-priced entry point for
//   customers who only want these 5.
//
// A tool's `requires` list means "valid if the customer has an active
// subscription to ANY product in this list".

const PRODUCTS = ['bundle', 'elite5'];

const TIERS = {
  '1m': { label: '1 Month', days: 30 },
  '6m': { label: '6 Months', days: 182 },
  '1y': { label: '1 Year', days: 365 },
};

// The 5 tools sold both inside the Bundle and standalone as Elite5.
const ELITE5_SCRIPTS = [
  'EzyMap_AutoTPSL',
  'EzyMap_BulkClose',
  'EzyMap_CurrencyStrengthMeter',
  'EzyMap_MTFBiasDashboard',
  'EzyMap_DrawdownGuardian',
];

// The remaining 12 tools - Bundle only.
const BUNDLE_ONLY_SCRIPTS = [
  'EzyMap_Scalper',
  'EzyMap_LotSizeCalculator',
  'EzyMap_RiskRewardCalculator',
  'EzyMap_MarginCalculator',
  'EzyMap_CorrelationSizer',
  'EzyMap_SessionClock',
  'EzyMap_HTFSnapshot',
  'EzyMap_SpreadSlippageLogger',
  'EzyMap_TradeCopier',
  'EzyMap_TradeJournalExporter',
  'EzyMap_EquityCurveLogger',
  'EzyMap_NewsTimeline',
];

const SCRIPT_REQUIREMENTS = {};
for (const id of ELITE5_SCRIPTS) SCRIPT_REQUIREMENTS[id] = ['bundle', 'elite5'];
for (const id of BUNDLE_ONLY_SCRIPTS) SCRIPT_REQUIREMENTS[id] = ['bundle'];

const ALL_SCRIPTS = Object.keys(SCRIPT_REQUIREMENTS);

function requirementsFor(scriptId) {
  return SCRIPT_REQUIREMENTS[scriptId] || null;
}

module.exports = {
  PRODUCTS,
  TIERS,
  ELITE5_SCRIPTS,
  BUNDLE_ONLY_SCRIPTS,
  ALL_SCRIPTS,
  SCRIPT_REQUIREMENTS,
  requirementsFor,
};
