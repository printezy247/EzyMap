// EzyMap License Server.
//
// Exposes a single public endpoint the MT5 tools call on startup (and
// periodically afterwards) to confirm the account has an active
// subscription that covers that specific tool:
//
//   GET /license/check?account=<mt5_login>&script=<EzyMap_ToolName>
//
// Response is plain text (not JSON) on purpose - MQL5's StringSplit makes
// parsing "KEY|VALUE|VALUE" trivial, no JSON library needed on the MQL5 side.
//
//   VALID|<expiresAtIso>|<product>|<tier>
//   INVALID|<human-readable reason>

require('dotenv').config();
const express = require('express');
const store = require('./lib/store');
const { requirementsFor, ALL_SCRIPTS } = require('./lib/products');

const app = express();
const PORT = process.env.PORT || 3000;

app.get('/license/check', (req, res) => {
  res.type('text/plain');

  const account = String(req.query.account || '').trim();
  const script = String(req.query.script || '').trim();

  if (!account || !script) {
    return res.status(400).send('INVALID|Missing account or script parameter.');
  }

  const allowedProducts = requirementsFor(script);
  if (!allowedProducts) {
    return res.status(400).send('INVALID|Unknown script id.');
  }

  for (const product of allowedProducts) {
    const rec = store.getSubscription(account, product);
    if (store.isActive(rec)) {
      return res.send(`VALID|${rec.expiresAt}|${product}|${rec.tier}`);
    }
  }

  return res.send('INVALID|No active EzyMap subscription found for this account. Contact EzyMap to purchase/renew.');
});

app.get('/health', (req, res) => res.send('ok'));

app.listen(PORT, () => {
  console.log(`EzyMap License Server listening on port ${PORT}`);
  console.log(`Known scripts: ${ALL_SCRIPTS.length}`);
});
