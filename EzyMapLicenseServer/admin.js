#!/usr/bin/env node
// Admin CLI for granting/revoking/listing EzyMap subscriptions.
//
// Usage:
//   node admin.js grant --account 12345678 --product bundle --tier 6m [--note "paid via bank transfer"]
//   node admin.js revoke --account 12345678 --product elite5
//   node admin.js list [--account 12345678]
//   node admin.js check --account 12345678 --script EzyMap_BulkClose
//
// LOCAL vs REMOTE mode:
//   By default this edits the copy of data/subscriptions.json on THIS
//   computer - fine for testing, useless once the server is deployed
//   elsewhere (that copy is a different file on a different machine).
//
//   To manage subscriptions on your DEPLOYED server instead, set these
//   in EzyMapLicenseServer/.env (same file the server itself reads):
//     EZYMAP_SERVER_URL=https://your-deployed-url
//     ADMIN_TOKEN=<same token you set on the deployed server>
//   Once both are set, every command below talks to the live server
//   over HTTPS instead of touching a local file - no other change needed.

require('dotenv').config();
const store = require('./lib/store');
const { PRODUCTS, TIERS, requirementsFor, ALL_SCRIPTS } = require('./lib/products');

const REMOTE_URL = process.env.EZYMAP_SERVER_URL;
const REMOTE_TOKEN = process.env.ADMIN_TOKEN;

function parseArgs(argv) {
  const args = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const key = a.slice(2);
      const next = argv[i + 1];
      if (next !== undefined && !next.startsWith('--')) {
        args[key] = next;
        i++;
      } else {
        args[key] = true;
      }
    } else {
      args._.push(a);
    }
  }
  return args;
}

function usageAndExit() {
  console.log(`EzyMap License Admin CLI ${REMOTE_URL ? `(REMOTE: ${REMOTE_URL})` : '(LOCAL file mode)'}

  node admin.js grant  --account <num> --product <bundle|elite5> --tier <1m|6m|1y> [--note "text"]
  node admin.js revoke --account <num> --product <bundle|elite5>
  node admin.js list   [--account <num>]
  node admin.js check  --account <num> --script <EzyMap_ToolName>

Products: ${PRODUCTS.join(', ')}
Tiers: ${Object.entries(TIERS).map(([k, v]) => `${k} (${v.label})`).join(', ')}

Set EZYMAP_SERVER_URL and ADMIN_TOKEN in .env to manage a deployed
server instead of the local data/subscriptions.json file.
`);
  process.exit(1);
}

function fmtRecord(product, rec) {
  const active = store.isActive(rec) ? 'ACTIVE' : 'EXPIRED';
  return `  ${product.padEnd(7)} ${active.padEnd(8)} tier=${rec.tier} expires=${rec.expiresAt}${rec.note ? ` note="${rec.note}"` : ''}`;
}

async function remoteCall(method, path, body) {
  const res = await fetch(`${REMOTE_URL}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${REMOTE_TOKEN}`,
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok || data.ok === false) {
    console.log(`Error: ${data.error || res.statusText}`);
    process.exit(1);
  }
  return data;
}

async function cmdGrant(args) {
  if (!args.account || !args.product || !args.tier) usageAndExit();

  const rec = REMOTE_URL
    ? (await remoteCall('POST', '/admin/grant', { account: args.account, product: args.product, tier: args.tier, note: args.note })).record
    : store.grant(args.account, args.product, args.tier, args.note);

  console.log(`Granted ${args.product} to account ${args.account}.`);
  console.log(fmtRecord(args.product, rec));
}

async function cmdRevoke(args) {
  if (!args.account || !args.product) usageAndExit();

  const revoked = REMOTE_URL
    ? (await remoteCall('POST', '/admin/revoke', { account: args.account, product: args.product })).revoked
    : store.revoke(args.account, args.product);

  console.log(revoked
    ? `Revoked ${args.product} from account ${args.account}.`
    : `Account ${args.account} had no ${args.product} subscription.`);
}

async function cmdList(args) {
  const db = REMOTE_URL
    ? (await remoteCall('GET', `/admin/list${args.account ? `?account=${encodeURIComponent(args.account)}` : ''}`)).data
    : (args.account ? (store.listAccount(args.account) || {}) : store.listAll());

  if (args.account) {
    if (!db || Object.keys(db).length === 0) { console.log(`No subscriptions for account ${args.account}.`); return; }
    console.log(`Account ${args.account}:`);
    for (const [product, rec] of Object.entries(db)) console.log(fmtRecord(product, rec));
    return;
  }

  const accounts = Object.keys(db);
  if (accounts.length === 0) { console.log('No subscriptions on file.'); return; }
  for (const account of accounts) {
    console.log(`Account ${account}:`);
    for (const [product, rec] of Object.entries(db[account])) console.log(fmtRecord(product, rec));
  }
}

async function cmdCheck(args) {
  if (!args.account || !args.script) usageAndExit();
  if (!ALL_SCRIPTS.includes(args.script)) {
    console.log(`Unknown script "${args.script}". Known scripts:\n  ${ALL_SCRIPTS.join('\n  ')}`);
    return;
  }

  if (REMOTE_URL) {
    // Hits the same public endpoint the MT5 tools use - no admin token needed.
    const res = await fetch(`${REMOTE_URL}/license/check?account=${encodeURIComponent(args.account)}&script=${encodeURIComponent(args.script)}`);
    console.log(await res.text());
    return;
  }

  const allowedProducts = requirementsFor(args.script);
  for (const product of allowedProducts) {
    const rec = store.getSubscription(args.account, product);
    if (store.isActive(rec)) {
      console.log(`VALID via "${product}" (tier=${rec.tier}, expires=${rec.expiresAt})`);
      return;
    }
  }
  console.log(`INVALID - account ${args.account} has no active subscription covering ${args.script} (needs one of: ${allowedProducts.join(', ')})`);
}

async function main() {
  if (REMOTE_URL && !REMOTE_TOKEN) {
    console.log('EZYMAP_SERVER_URL is set but ADMIN_TOKEN is missing in .env - add the same token the server uses.');
    process.exit(1);
  }

  const args = parseArgs(process.argv.slice(2));
  const cmd = args._[0];

  switch (cmd) {
    case 'grant': await cmdGrant(args); break;
    case 'revoke': await cmdRevoke(args); break;
    case 'list': await cmdList(args); break;
    case 'check': await cmdCheck(args); break;
    default: usageAndExit();
  }
}

main();
