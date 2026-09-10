// Thin wrapper around Xendit's Invoices API.
// Docs: https://developers.xendit.co/api-reference/#create-invoice

const XENDIT_INVOICES_URL = 'https://api.xendit.co/v2/invoices';

async function createInvoice({ externalId, amount, currency, description, successRedirectUrl, failureRedirectUrl }) {
  const secretKey = process.env.XENDIT_SECRET_KEY;
  if (!secretKey) throw new Error('XENDIT_SECRET_KEY is not set in .env');

  const auth = Buffer.from(`${secretKey}:`).toString('base64');
  const res = await fetch(XENDIT_INVOICES_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Basic ${auth}`,
    },
    body: JSON.stringify({
      external_id: externalId,
      amount,
      currency,
      description,
      success_redirect_url: successRedirectUrl,
      failure_redirect_url: failureRedirectUrl,
    }),
  });

  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.message || `Xendit invoice creation failed (HTTP ${res.status})`);
  return data; // { id, invoice_url, status, ... }
}

module.exports = { createInvoice };
