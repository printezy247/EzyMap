// Checkout prices, in USD, per product per tier. This is the single
// source of truth for what the checkout page shows AND what invoice
// amount gets created at Xendit - edit freely, nothing else needs to
// change when you update a price.
//
// `wasPrice` (optional) shows a struck-through "was" price next to the
// real price, for a launch-discount look.

const CURRENCY = 'USD';

const PRICING = {
  bundle: {
    name: 'MT5 Indicator Bundle',
    description: 'Complete 17 MT5 EzyMap Indicators',
    tiers: {
      '1m': { price: 99, wasPrice: 999 },
      '6m': { price: 499, wasPrice: 5994 },
      '1y': { price: 999, wasPrice: 11988 },
    },
  },
  bulkclose: {
    name: 'Bulk Close - BONUS Layer Close (Top Selling)',
    description: 'Close partial profit, or a chosen number of layers, with fast execution.',
    tiers: {
      '1m': { price: 19 },
      '6m': { price: 109 },
      '1y': { price: 199 },
    },
  },
  drawdownguardian: {
    name: 'Drawdown Guardian (Prop Firm Favorite)',
    description: 'Stay alert to your current drawdown so you avoid elimination from any prop firm stage.',
    tiers: {
      '1m': { price: 9 },
      '6m': { price: 49 },
      '1y': { price: 99 },
    },
  },
  autotpsl: {
    name: 'Auto TP/SL (Trending This Month)',
    description: "Don't waste time setting TP & SL manually for each layer.",
    tiers: {
      '1m': { price: 9 },
      '6m': { price: 49 },
      '1y': { price: 99 },
    },
  },
  currencystrength: {
    name: 'Currency Strength Meter',
    description: 'Stay updated on the current volatility of the most-traded currencies.',
    tiers: {
      '1m': { price: 9 },
      '6m': { price: 49 },
      '1y': { price: 99 },
    },
  },
  mtfbias: {
    name: 'MTF Bias',
    description: 'Reveals bullish or bearish bias to give confluence for your ever-adapting trading plan.',
    tiers: {
      '1m': { price: 9 },
      '6m': { price: 49 },
      '1y': { price: 99 },
    },
  },
};

function priceFor(product, tier) {
  const entry = PRICING[product] && PRICING[product].tiers[tier];
  return entry ? entry.price : null;
}

module.exports = { CURRENCY, PRICING, priceFor };
