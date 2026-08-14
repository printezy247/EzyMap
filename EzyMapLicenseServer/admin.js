#!/usr/bin/env node
// Admin CLI for granting/revoking/listing EzyMap subscriptions.
//
// Usage:
//   node admin.js grant --account 12345678 --product bundle --tier 6m [--note "paid via bank transfer"]
//   node admin.js revoke --account 12345678 --product elite5
//   node admin.js list [--account 12345678]
//   node admin.js check --account 12345678 --script EzyMap_BulkClose

const store = require('./lib/store');
const { PRODUCTS, TIERS, requirementsFor, ALL_SCRIPTS } = require('./lib/products');

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
  console.log(`EzyMap License Admin CLI

  node admin.js grant  --account <num> --product <bundle|elite5> --tier <1m|6m|1y> [--note "text"]
  node admin.js revoke --account <num> --product <bundle|elite5>
  node admin.js list   [--account <num>]
  node admin.js check  --account <num> --script <EzyMap_ToolName>

Products: ${PRODUCTS.join(', ')}
Tiers: ${Object.entries(TIERS).map(([k, v]) => `${k} (${v.label})`).join(', ')}
`);
  process.exit(1);
}

function fmtRecord(product, rec) {
  const active = store.isActive(rec) ? 'ACTIVE' : 'EXPIRED';
  return `  ${product.padEnd(7)} ${active.padEnd(8)} tier=${rec.tier} expires=${rec.expiresAt}${rec.note ? ` note="${rec.note}"` : ''}`;
}

function cmdGrant(args) {
  if (!args.account || !args.product || !args.tier) usageAndExit();
  const rec = store.grant(args.account, args.product, args.tier, args.note);
  console.log(`Granted ${args.product} to account ${args.account}.`);
  console.log(fmtRecord(args.product, rec));
}

function cmdRevoke(args) {
  if (!args.account || !args.product) usageAndExit();
  const ok = store.revoke(args.account, args.product);
  console.log(ok
    ? `Revoked ${args.product} from account ${args.account}.`
    : `Account ${args.account} had no ${args.product} subscription.`);
}

function cmdList(args) {
  if (args.account) {
    const acct = store.listAccount(args.account);
    if (!acct) { console.log(`No subscriptions for account ${args.account}.`); return; }
    console.log(`Account ${args.account}:`);
    for (const [product, rec] of Object.entries(acct)) console.log(fmtRecord(product, rec));
    return;
  }

  const db = store.listAll();
  const accounts = Object.keys(db);
  if (accounts.length === 0) { console.log('No subscriptions on file.'); return; }
  for (const account of accounts) {
    console.log(`Account ${account}:`);
    for (const [product, rec] of Object.entries(db[account])) console.log(fmtRecord(product, rec));
  }
}

function cmdCheck(args) {
  if (!args.account || !args.script) usageAndExit();
  if (!ALL_SCRIPTS.includes(args.script)) {
    console.log(`Unknown script "${args.script}". Known scripts:\n  ${ALL_SCRIPTS.join('\n  ')}`);
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

const args = parseArgs(process.argv.slice(2));
const cmd = args._[0];

switch (cmd) {
  case 'grant': cmdGrant(args); break;
  case 'revoke': cmdRevoke(args); break;
  case 'list': cmdList(args); break;
  case 'check': cmdCheck(args); break;
  default: usageAndExit();
}
