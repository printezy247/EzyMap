// Defines the commercial products and which of the 17 EzyMap MT5 tools
// each one unlocks.
//
// - "bundle": one subscription, unlocks all 17 tools.
// - 5 "hot selling" tools are ALSO sold individually, each as its own
//   standalone product - a customer can buy just Drawdown Guardian, or
//   just Bulk Close, without the rest. Someone who owns "bundle" already
//   has access to all 5 - the individual products are a lower-priced
//   entry point for customers who only want one specific tool.
//
// A tool's requirement list means "valid if the customer has an active
// subscription to ANY product in this list".

const PRODUCTS = ['bundle', 'bulkclose', 'drawdownguardian', 'autotpsl', 'currencystrength', 'mtfbias'];

const TIERS = {
  'trial': { label: '3-Day Trial', days: 3 },
  '1m': { label: '1 Month', days: 30 },
  '6m': { label: '6 Months', days: 182 },
  '1y': { label: '1 Year', days: 365 },
};

// The 5 hot-selling tools, each sold both inside the Bundle and standalone
// as its own product.
const INDIVIDUAL_PRODUCT_FOR_SCRIPT = {
  EzyMap_BulkClose: 'bulkclose',
  EzyMap_DrawdownGuardian: 'drawdownguardian',
  EzyMap_AutoTPSL: 'autotpsl',
  EzyMap_CurrencyStrengthMeter: 'currencystrength',
  EzyMap_MTFBiasDashboard: 'mtfbias',
};

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
for (const [scriptId, productId] of Object.entries(INDIVIDUAL_PRODUCT_FOR_SCRIPT))
  SCRIPT_REQUIREMENTS[scriptId] = ['bundle', productId];
for (const id of BUNDLE_ONLY_SCRIPTS) SCRIPT_REQUIREMENTS[id] = ['bundle'];

const ALL_SCRIPTS = Object.keys(SCRIPT_REQUIREMENTS);

function requirementsFor(scriptId) {
  return SCRIPT_REQUIREMENTS[scriptId] || null;
}

module.exports = {
  PRODUCTS,
  TIERS,
  INDIVIDUAL_PRODUCT_FOR_SCRIPT,
  BUNDLE_ONLY_SCRIPTS,
  ALL_SCRIPTS,
  SCRIPT_REQUIREMENTS,
  requirementsFor,
};
