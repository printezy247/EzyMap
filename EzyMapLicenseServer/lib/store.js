// JSON-file subscription store. Deliberately not a database - this is a
// small single-operator business, and a flat file keyed by account number
// is easy to back up, inspect, and hand-edit in an emergency.
//
// Shape of data/subscriptions.json:
// {
//   "12345678": {
//     "bundle": { "tier": "6m", "expiresAt": "2026-02-14T00:00:00.000Z", "note": "" },
//     "bulkclose": { "tier": "1y", "expiresAt": "2027-08-14T00:00:00.000Z", "note": "" }
//   }
// }

const fs = require('fs');
const path = require('path');
const { PRODUCTS, TIERS } = require('./products');

const DATA_FILE = path.join(__dirname, '..', 'data', 'subscriptions.json');
// Separate from subscriptions.json on purpose: a trial's "used" flag must
// outlive the subscription record it granted (which gets overwritten on
// upgrade, or deleted on revoke) - otherwise revoking or upgrading past a
// trial would quietly make that account trial-eligible again.
const TRIALS_FILE = path.join(__dirname, '..', 'data', 'trials.json');

function load() {
  if (!fs.existsSync(DATA_FILE)) return {};
  const raw = fs.readFileSync(DATA_FILE, 'utf8').trim();
  if (!raw) return {};
  return JSON.parse(raw);
}

function save(db) {
  fs.mkdirSync(path.dirname(DATA_FILE), { recursive: true });
  fs.writeFileSync(DATA_FILE, JSON.stringify(db, null, 2) + '\n', 'utf8');
}

function loadTrials() {
  if (!fs.existsSync(TRIALS_FILE)) return {};
  const raw = fs.readFileSync(TRIALS_FILE, 'utf8').trim();
  if (!raw) return {};
  return JSON.parse(raw);
}

function saveTrials(db) {
  fs.mkdirSync(path.dirname(TRIALS_FILE), { recursive: true });
  fs.writeFileSync(TRIALS_FILE, JSON.stringify(db, null, 2) + '\n', 'utf8');
}

// Has this account already had a trial of this product, ever (regardless
// of whether that trial has since expired, been upgraded, or revoked)?
function hasUsedTrial(account, product) {
  const db = loadTrials();
  const acct = db[String(account)];
  return !!(acct && acct[product]);
}

function markTrialUsed(account, product) {
  const db = loadTrials();
  const key = String(account);
  if (!db[key]) db[key] = {};
  db[key][product] = new Date().toISOString();
  saveTrials(db);
}

function isActive(record) {
  if (!record || !record.expiresAt) return false;
  return new Date(record.expiresAt).getTime() > Date.now();
}

// Returns the subscription record for account+product, or null.
function getSubscription(account, product) {
  const db = load();
  const acct = db[String(account)];
  if (!acct || !acct[product]) return null;
  return acct[product];
}

function listAll() {
  return load();
}

function listAccount(account) {
  const db = load();
  return db[String(account)] || null;
}

// Grants/renews a subscription. If the account already has an active
// subscription to this product, the new period is added on top of the
// existing expiry (so renewing early doesn't waste paid-for time).
// Otherwise the period starts from now.
function grant(account, product, tier, note) {
  if (!PRODUCTS.includes(product)) {
    throw new Error(`Unknown product "${product}". Valid: ${PRODUCTS.join(', ')}`);
  }
  if (!TIERS[tier]) {
    throw new Error(`Unknown tier "${tier}". Valid: ${Object.keys(TIERS).join(', ')}`);
  }
  if (tier === 'trial' && hasUsedTrial(account, product)) {
    throw new Error(`Account ${account} already used its trial for "${product}".`);
  }

  const db = load();
  const key = String(account);
  if (!db[key]) db[key] = {};

  const existing = db[key][product];
  const days = TIERS[tier].days;
  const base = isActive(existing) ? new Date(existing.expiresAt).getTime() : Date.now();
  const expiresAt = new Date(base + days * 24 * 60 * 60 * 1000).toISOString();

  db[key][product] = { tier, expiresAt, note: note || '' };
  save(db);
  if (tier === 'trial') markTrialUsed(account, product);
  return db[key][product];
}

function revoke(account, product) {
  const db = load();
  const key = String(account);
  if (!db[key] || !db[key][product]) return false;
  delete db[key][product];
  if (Object.keys(db[key]).length === 0) delete db[key];
  save(db);
  return true;
}

module.exports = { load, save, isActive, getSubscription, listAll, listAccount, grant, revoke, hasUsedTrial };
