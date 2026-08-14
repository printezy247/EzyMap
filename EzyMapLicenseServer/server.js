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

// ---------------------------------------------------------------------
// Admin API - lets admin.js manage subscriptions on a DEPLOYED server
// (not just the copy of data/subscriptions.json on your own computer).
// Protected by ADMIN_TOKEN (set in .env) - without it these routes are
// disabled entirely, so a server deployed without an ADMIN_TOKEN simply
// can't be managed remotely (admin.js falls back to local-file mode).
// ---------------------------------------------------------------------
app.use(express.json());

function requireAdmin(req, res, next) {
  const token = process.env.ADMIN_TOKEN;
  if (!token) return res.status(503).json({ ok: false, error: 'Admin API disabled - set ADMIN_TOKEN in .env on the server.' });
  if (req.get('Authorization') !== `Bearer ${token}`) return res.status(401).json({ ok: false, error: 'Unauthorized.' });
  next();
}

app.post('/admin/grant', requireAdmin, (req, res) => {
  try {
    const { account, product, tier, note } = req.body || {};
    const record = store.grant(account, product, tier, note);
    res.json({ ok: true, record });
  } catch (err) {
    res.status(400).json({ ok: false, error: err.message });
  }
});

app.post('/admin/revoke', requireAdmin, (req, res) => {
  const { account, product } = req.body || {};
  const revoked = store.revoke(account, product);
  res.json({ ok: true, revoked });
});

app.get('/admin/list', requireAdmin, (req, res) => {
  const { account } = req.query;
  res.json({ ok: true, data: account ? (store.listAccount(account) || {}) : store.listAll() });
});

app.listen(PORT, () => {
  console.log(`EzyMap License Server listening on port ${PORT}`);
  console.log(`Known scripts: ${ALL_SCRIPTS.length}`);
});
