// Pure calculation functions ported directly from the EzyMap MQL5 tools'
// validated math (same pip-size conventions, same risk-tier percentages).
// No live broker connection here - Margin Calculator needs the current
// price passed in manually since there's no MT5 feed to pull it from.

const SUPPORTED_PAIRS = [
  'EURUSD', 'GBPUSD', 'AUDUSD', 'USDJPY', 'USDCAD', 'USDCHF',
  'XAUUSD', 'XAGUSD', 'BTCUSD', 'LTCUSD', 'ETHUSD',
];

const CRYPTO = ['BTC', 'ETH', 'LTC', 'XRP', 'XBT'];

function normalizePair(raw) {
  return String(raw || '').trim().toUpperCase().replace(/[^A-Z]/g, '');
}

// Same convention as the MQL5 tools: gold is always 1 pip = 10 points
// (0.1 price move) regardless of broker digit count; crypto is always
// 1 pip = $1; JPY pairs use 0.01; everything else uses 0.0001.
function pipSize(pairUpper) {
  if (pairUpper.includes('XAU') || pairUpper.includes('GOLD')) return 0.10;
  if (pairUpper.includes('XAG') || pairUpper.includes('SILVER')) return 0.01;
  if (CRYPTO.some((c) => pairUpper.includes(c))) return 1.0;
  if (pairUpper.includes('JPY')) return 0.01;
  return 0.0001;
}

// Standard retail contract sizes. Indices/oil are intentionally excluded -
// their per-point value varies too much by broker to standardize safely.
function contractSize(pairUpper) {
  if (pairUpper.includes('XAU') || pairUpper.includes('GOLD')) return 100;    // 100 oz/lot
  if (pairUpper.includes('XAG') || pairUpper.includes('SILVER')) return 5000; // 5000 oz/lot
  if (CRYPTO.some((c) => pairUpper.includes(c))) return 1;                    // 1 coin/lot
  return 100000; // standard forex lot
}

function volumeDecimals(step) {
  if (step >= 1) return 0;
  if (step >= 0.1) return 1;
  return 2;
}

/**
 * Lot Size Calculator - same risk-tier logic as EzyMap_LotSizeCalculator.mq5
 * (0.5% / 10% / 25% of capital), floored to a 0.01 lot step with broker
 * min/max clamping (assumed standard 0.01-100 range, since we have no live
 * SymbolInfo here).
 *
 * IMPORTANT: SL distance here is in PIPS, not points, unlike the MT5
 * desktop tool. Points are broker-specific (a 4-digit vs 5-digit quote
 * changes the scale 10x) and this bot has no live broker connection to
 * know which one applies - pips are a standardized unit that don't
 * depend on that, so they're the safer choice for a standalone app.
 */
function lotSize({ pair, capital, slPips, tiers = [0.5, 10, 25] }) {
  const pairUpper = normalizePair(pair);
  if (!SUPPORTED_PAIRS.includes(pairUpper)) {
    return { error: `Unsupported pair "${pair}". Supported: ${SUPPORTED_PAIRS.join(', ')}` };
  }
  if (!(capital > 0) || !(slPips > 0)) {
    return { error: 'Capital and SL distance must both be greater than 0.' };
  }

  const pip = pipSize(pairUpper);
  const cs = contractSize(pairUpper);
  const moneyPerLotAtSL = slPips * pip * cs;
  if (!(moneyPerLotAtSL > 0)) {
    return { error: 'Could not compute risk per lot for this pair.' };
  }

  const volStep = 0.01;
  const volMin = 0.01;
  const volMax = 100;
  const decimals = volumeDecimals(volStep);

  const results = tiers.map((pct) => {
    const riskMoney = (capital * pct) / 100;
    let lots = Math.floor(riskMoney / moneyPerLotAtSL / volStep) * volStep;
    let flag = '';
    if (lots < volMin) { lots = volMin; flag = ' (min lot)'; }
    if (lots > volMax) { lots = volMax; flag = ' (max lot)'; }
    const actualRisk = lots * moneyPerLotAtSL;
    return { pct, lots: Number(lots.toFixed(decimals)), flag, actualRisk };
  });

  return { pairUpper, moneyPerLotAtSL, results };
}

/**
 * Margin Calculator - standard contractSize/leverage formula. Needs the
 * current price passed in manually (no live feed here). Correctly
 * branches for USDxxx pairs (contract already denominated in USD) vs
 * xxxUSD/gold/crypto pairs (quote currency is USD, price conversion
 * applies directly).
 */
function marginRequired({ pair, lots, leverage, price }) {
  const pairUpper = normalizePair(pair);
  if (!SUPPORTED_PAIRS.includes(pairUpper)) {
    return { error: `Unsupported pair "${pair}". Supported: ${SUPPORTED_PAIRS.join(', ')}` };
  }
  if (!(lots > 0) || !(leverage > 0) || !(price > 0)) {
    return { error: 'Lots, leverage, and price must all be greater than 0.' };
  }

  const cs = contractSize(pairUpper);
  const margin = pairUpper.startsWith('USD')
    ? (lots * cs) / leverage
    : (lots * cs * price) / leverage;

  return { pairUpper, margin };
}

module.exports = {
  SUPPORTED_PAIRS,
  normalizePair,
  pipSize,
  contractSize,
  lotSize,
  marginRequired,
};
