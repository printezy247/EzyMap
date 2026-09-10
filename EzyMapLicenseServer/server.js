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
//
// Also serves a self-service checkout page (/checkout.html) backed by
// Xendit invoices, and a webhook that auto-grants the subscription the
// moment a customer pays - no manual admin.js command needed.

require('dotenv').config();
const path = require('path');
const crypto = require('crypto');
const express = require('express');
const store = require('./lib/store');
const { requirementsFor, ALL_SCRIPTS, TIERS } = require('./lib/products');
const { PRICING, CURRENCY, priceFor } = require('./lib/pricing');
const { createInvoice } = require('./lib/xendit');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

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
// Checkout - self-service payment via Xendit. Customer picks a product
// + tier and types their MT5 account number on /checkout.html, which
// posts here to create a hosted Xendit invoice and redirects them to it.
// ---------------------------------------------------------------------
app.get('/checkout/pricing', (req, res) => {
  res.json({ currency: CURRENCY, products: PRICING });
});

app.post('/checkout/create', async (req, res) => {
  try {
    const account = String((req.body || {}).account || '').trim();
    const product = String((req.body || {}).product || '').trim();
    const tier = String((req.body || {}).tier || '').trim();

    if (!/^[0-9]+$/.test(account)) {
      return res.status(400).json({ ok: false, error: 'Enter a valid MT5 account number (numbers only).' });
    }
    if (!PRICING[product]) {
      return res.status(400).json({ ok: false, error: 'Unknown product.' });
    }
    const amount = priceFor(product, tier);
    if (amount == null) {
      return res.status(400).json({ ok: false, error: 'Unknown tier for this product.' });
    }

    const baseUrl = `${req.protocol}://${req.get('host')}`;
    // "grant_<account>_<product>_<tier>_<random>" - the webhook below parses
    // this back out once Xendit confirms payment. Random suffix keeps
    // external_id unique per checkout attempt (Xendit requires uniqueness).
    const externalId = `grant_${account}_${product}_${tier}_${crypto.randomBytes(3).toString('hex')}`;

    const invoice = await createInvoice({
      externalId,
      amount,
      currency: CURRENCY,
      description: `${PRICING[product].name} - ${TIERS[tier].label} (MT5 account ${account})`,
      successRedirectUrl: `${baseUrl}/thanks.html`,
      failureRedirectUrl: `${baseUrl}/checkout.html`,
    });

    res.json({ ok: true, invoiceUrl: invoice.invoice_url });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
});

// Xendit calls this the moment an invoice's status changes. Verified via
// the "x-callback-token" header, set to match XENDIT_CALLBACK_TOKEN below
// (configure the same value in Xendit Dashboard > Settings > Callbacks).
app.post('/webhook/xendit', (req, res) => {
  const expectedToken = process.env.XENDIT_CALLBACK_TOKEN;
  const receivedToken = req.get('x-callback-token');
  if (!expectedToken || receivedToken !== expectedToken) {
    return res.status(401).send('Unauthorized');
  }

  const { status, external_id: externalId } = req.body || {};
  if (status === 'PAID' || status === 'SETTLED') {
    const parts = String(externalId || '').split('_');
    if (parts[0] === 'grant' && parts.length >= 4) {
      const [, account, product, tier] = parts;
      try {
        store.grant(account, product, tier, `Auto-granted via Xendit invoice ${externalId}`);
        console.log(`Auto-granted ${product}/${tier} to account ${account} (Xendit ${externalId})`);
      } catch (err) {
        console.error(`Auto-grant failed for ${externalId}:`, err.message);
      }
    } else {
      console.error(`Paid invoice with unrecognized external_id: ${externalId}`);
    }
  }

  // Xendit retries on non-2xx, so always acknowledge once verified.
  res.status(200).send('ok');
});

// ---------------------------------------------------------------------
// Admin API - lets admin.js manage subscriptions on a DEPLOYED server
// (not just the copy of data/subscriptions.json on your own computer).
// Protected by ADMIN_TOKEN (set in .env) - without it these routes are
// disabled entirely, so a server deployed without an ADMIN_TOKEN simply
// can't be managed remotely (admin.js falls back to local-file mode).
// ---------------------------------------------------------------------
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
