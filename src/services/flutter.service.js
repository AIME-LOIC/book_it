import crypto from 'crypto';

// ── CONFIG ─────────────────────────────────────────────
// Supports both the sandbox test naming (CLIENT_ID / Client_Secret) and the
// conventional FLW_* naming so you don't have to touch your .env.local.
const FLW_BASE_URL = process.env.FLW_BASE_URL || 'https://developersandbox-api.flutterwave.com';
const FLW_IDP_URL =
  process.env.FLW_IDP_URL ||
  'https://idp.flutterwave.com/realms/flutterwave/protocol/openid-connect/token';

const CLIENT_ID = process.env.FLW_CLIENT_ID || process.env.CLIENT_ID;
const CLIENT_SECRET =
  process.env.FLW_CLIENT_SECRET || process.env.Client_Secret || process.env.CLIENT_SECRET;

// Set this once you enable webhooks in the Flutterwave dashboard.
const WEBHOOK_SECRET_HASH = process.env.FLW_WEBHOOK_SECRET_HASH;

// The default mobile money flow simulates a push notification to a real
// phone — sandbox has no way to auto-approve that, so a charge just sits
// "pending" forever in dev. `scenario:auth_redirect` swaps in a mock
// approval page you can actually click through. Applied automatically
// outside production; set FLW_SANDBOX_SCENARIO_KEY='' to disable.
const SANDBOX_SCENARIO_KEY =
  process.env.FLW_SANDBOX_SCENARIO_KEY !== undefined
    ? process.env.FLW_SANDBOX_SCENARIO_KEY
    : process.env.NODE_ENV === 'production'
      ? ''
      : 'scenario:auth_redirect';

// Where Flutterwave's mock approval page sends the customer back to after
// they simulate approve/decline. Must be a full absolute URL (http/https)
// or the sandbox rejects the charge outright with "Redirect url is invalid".
function resolveRedirectUrl() {
  const configured = process.env.FLW_REDIRECT_URL;
  if (!configured) return 'https://example.com/payment-callback'; // harmless placeholder — sandbox only cares that it's well-formed
  try {
    const u = new URL(configured);
    if (!['http:', 'https:'].includes(u.protocol)) throw new Error('bad protocol');
    return configured;
  } catch {
    console.warn(
      `[flutterwave] FLW_REDIRECT_URL="${configured}" is not a valid absolute URL (needs http:// or https://) — falling back to a placeholder.`
    );
    return 'https://example.com/payment-callback';
  }
}
const FLW_REDIRECT_URL = resolveRedirectUrl();

const NETWORK_MAP = {
  mtn: 'MTN',
  momo: 'MTN',
  mtn_momo: 'MTN',
  airtel: 'AIRTEL',
  airtel_money: 'AIRTEL',
};

// ── TOKEN CACHING ──────────────────────────────────────
// client_credentials tokens are short-lived; cache and refresh instead of
// hitting the IDP on every request.
let cachedToken = null;
let tokenExpiresAt = 0;

async function getAccessToken() {
  const now = Date.now();
  if (cachedToken && now < tokenExpiresAt - 30_000) return cachedToken;

  if (!CLIENT_ID || !CLIENT_SECRET) {
    throw new Error(
      'Flutterwave credentials missing. Set FLW_CLIENT_ID and FLW_CLIENT_SECRET (or CLIENT_ID / CLIENT_SECRET) in your .env.local'
    );
  }

  const body = new URLSearchParams({
    client_id: CLIENT_ID,
    client_secret: CLIENT_SECRET,
    grant_type: 'client_credentials',
  });

  const res = await fetch(FLW_IDP_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });

  const data = await res.json();
  if (!res.ok || !data.access_token) {
    throw new Error(`Flutterwave auth failed: ${JSON.stringify(data)}`);
  }

  cachedToken = data.access_token;
  // fall back to 5 min if expires_in isn't returned
  tokenExpiresAt = now + Number(data.expires_in || 300) * 1000;
  return cachedToken;
}

// ── LOW-LEVEL REQUEST HELPER ───────────────────────────
async function flwRequest(method, path, data, extraHeaders = {}) {
  const token = await getAccessToken();
  const headers = {
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
    'X-Trace-Id': crypto.randomUUID(),
    'X-Idempotency-Key': crypto.randomUUID(),
    ...extraHeaders,
  };

  const res = await fetch(`${FLW_BASE_URL}${path}`, {
    method,
    headers,
    body: data ? JSON.stringify(data) : undefined,
  });

  const text = await res.text();
  let json;
  try {
    json = text ? JSON.parse(text) : {};
  } catch {
    json = { raw: text };
  }

  if (!res.ok) {
    const detailList = json?.error?.details || json?.errors || json?.data?.errors;
    const detailMsg = Array.isArray(detailList)
      ? detailList.map(d => d.message || d.detail || JSON.stringify(d)).join('; ')
      : (typeof detailList === 'object' && detailList ? JSON.stringify(detailList) : null);
    const msg = json?.error?.message || json?.message || text;
    const fullMsg = detailMsg ? `${msg} — ${detailMsg}` : msg;
    const err = new Error(`Flutterwave ${method} ${path} failed (${res.status}): ${fullMsg}`);
    err.status = res.status;
    err.response = json;
    console.error('[flutterwave] full error response:', JSON.stringify(json, null, 2));
    throw err;
  }

  return json;
}

function normalizePhone(phone) {
  if (!phone) throw new Error('Phone number is required');
  let p = String(phone).replace(/\D/g, '');
  if (p.startsWith('250')) p = p.slice(3);
  if (p.startsWith('0')) p = p.slice(1);
  return p;
}

// ── PUBLIC API ─────────────────────────────────────────
export async function getMobileNetworks(country = 'RW') {
  return flwRequest('GET', `/mobile-networks?country=${country}`);
}

export async function createFlwCustomer(user) {
  const parts = (user.name || 'BookIt Customer').trim().split(/\s+/);
  const first = parts[0];
  const last = parts.slice(1).join(' ') || first;

  try {
    const res = await flwRequest('POST', '/customers', {
      email: user.email,
      name: { first, last },
      phone: { country_code: '250', number: normalizePhone(user.phone) },
    });
    return res.data;
  } catch (err) {
    // Sandbox (and prod) reject a second customer with the same email —
    // very common on retries/repeat test payments. Look up the existing
    // one instead of failing the whole charge.
    const looksLikeDuplicate =
      (err.status === 400 || err.status === 409) &&
      /already exists|duplicate/i.test(JSON.stringify(err.response || {}));

    if (!looksLikeDuplicate) throw err;

    const embeddedId =
      err.response?.data?.id || err.response?.error?.data?.id || err.response?.data?.customer_id;
    if (embeddedId) return { id: embeddedId };

    const existing = await findFlwCustomerByEmail(user.email);
    if (existing) return existing;
    throw err; // couldn't recover — surface the original error
  }
}

async function findFlwCustomerByEmail(email) {
    try {
      const res = await flwRequest('GET', `/customers?email=${encodeURIComponent(email)}`);
      const list = res?.data;
      if (Array.isArray(list) && list.length) return list[0];
      if (list?.id) return list;
      return null;
    } catch (err) {
      console.log('[flutterwave] customer lookup failed:', err.message);
      return null;
    }
  }

export async function createMobileMoneyPaymentMethod({ network, phone_number }) {
  const flwNetwork = NETWORK_MAP[String(network).toLowerCase()];
  if (!flwNetwork) {
    throw new Error(`Unsupported mobile money network: "${network}". Use "mtn" or "airtel".`);
  }

  const res = await flwRequest('POST', '/payment-methods', {
    type: 'mobile_money',
    mobile_money: {
      country_code: '250',
      network: flwNetwork,
      phone_number: normalizePhone(phone_number),
    },
  });

  return res.data;
}

export async function createCharge({
    reference,
    currency = 'RWF',
    customer_id,
    payment_method_id,
    amount,
    meta,
    redirect_url,
    scenarioKey,
  }) {
    const extraHeaders = scenarioKey ? { 'X-Scenario-Key': scenarioKey } : {};
    console.log('[flutterwave] creating charge — scenarioKey:', scenarioKey || '(none)', 'redirect_url:', redirect_url || '(none)');
    const res = await flwRequest('POST', '/charges', {
      reference,
      currency,
      customer_id,
      payment_method_id,
      amount,
      ...(redirect_url ? { redirect_url } : {}),
      ...(meta ? { meta } : {}),
    }, extraHeaders);
    console.log('[flutterwave] FULL charge response:', JSON.stringify(res.data, null, 2));
    return res.data;
  }

  export async function getCharge(chargeId) {
    const res = await flwRequest('GET', `/charges/${chargeId}`);
    console.log('[flutterwave] poll status:', res.data.status, '| full:', JSON.stringify(res.data, null, 2));
    return res.data;
  }

/**
 * Orchestrates a full mobile money charge: create/reuse customer, create
 * the mobile-money payment method for the given network, then create the
 * charge. Returns everything so the caller can persist IDs for later
 * status checks / webhook reconciliation.
 *
 * NOTE: this does NOT mark anything as paid. MTN/Airtel mobile money in
 * production triggers a push/USSD prompt on the customer's phone — the
 * charge stays "pending" until they approve it. Use getCharge() (polling)
 * or the webhook handler below to find out when it actually settles.
 */
export async function initiateMobileMoneyCharge({ user, network, phone_number, amount, reference, meta, existing_customer_id }) {
    const customer = existing_customer_id
      ? { id: existing_customer_id }
      : await createFlwCustomer(user);
  
    const paymentMethod = await createMobileMoneyPaymentMethod({ network, phone_number });
    const charge = await createCharge({
      reference,
      customer_id: customer.id,
      payment_method_id: paymentMethod.id,
      amount,
      meta,
      scenarioKey: SANDBOX_SCENARIO_KEY || undefined,
      redirect_url: SANDBOX_SCENARIO_KEY ? FLW_REDIRECT_URL : undefined,
    });
  
    return { customer, paymentMethod, charge };
  }

/**
 * Verifies the `verif-hash` header Flutterwave sends on webhook requests
 * against the secret hash you configured in the dashboard. Returns false
 * (never throws) so callers can respond 401 cleanly.
 */
export function verifyWebhookSignature(receivedHash) {
  if (!WEBHOOK_SECRET_HASH) {
    console.warn('[flutterwave] FLW_WEBHOOK_SECRET_HASH is not set — webhook signature is NOT being verified.');
    return true;
  }
  if (!receivedHash) return false;
  // constant-time-ish comparison
  return crypto.timingSafeEqual(
    Buffer.from(String(receivedHash)),
    Buffer.from(String(WEBHOOK_SECRET_HASH))
  ) && receivedHash.length === WEBHOOK_SECRET_HASH.length;
}

export const FLW_SUCCESS_STATUSES = ['successful', 'success', 'completed','succeeded'];
export const FLW_FAILED_STATUSES = ['failed', 'cancelled', 'declined', 'expired'];
