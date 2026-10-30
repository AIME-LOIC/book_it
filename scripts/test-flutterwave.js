import dotenv from 'dotenv';
import crypto from 'crypto';

dotenv.config({ path: process.env.DOTENV_CONFIG_PATH || '.env.local' });

const API = 'https://developersandbox-api.flutterwave.com';
const id = process.env.CLIENT_ID;
const secret = process.env.Client_Secret || process.env.CLIENT_SECRET;

const body = new URLSearchParams({ client_id: id, client_secret: secret, grant_type: 'client_credentials' });
const tokRes = await fetch('https://idp.flutterwave.com/realms/flutterwave/protocol/openid-connect/token', {
  method: 'POST',
  headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  body,
});
const { access_token } = await tokRes.json();

const hdr = () => ({
  Authorization: `Bearer ${access_token}`,
  'Content-Type': 'application/json',
  'X-Trace-Id': crypto.randomUUID(),
  'X-Idempotency-Key': crypto.randomUUID(),
});

const req = async (method, path, data, scenarioKey) => {
  const headers = hdr();
  if (scenarioKey) headers['X-Scenario-Key'] = scenarioKey;
  const r = await fetch(`${API}${path}`, { method, headers, body: data ? JSON.stringify(data) : null });
  const t = await r.text();
  console.log(method, path, r.status, t.slice(0, 1200));
  return JSON.parse(t);
};

await req('GET', '/mobile-networks?country=RW');

const cust = await req('POST', '/customers', {
  email: `testuser-${Date.now()}@bookit.rw`,
  name: { first: 'Test', last: 'User' },
  phone: { country_code: '250', number: '788888888' },
});
const customerId = cust.data?.id;

const pm = await req('POST', '/payment-methods', {
  type: 'mobile_money',
  mobile_money: { country_code: '250', network: 'MTN', phone_number: '788888888' },
});
const pmId = pm.data?.id;

const ch = await req('POST', '/charges', {
  reference: `bookit-test-${Date.now()}`,
  currency: 'RWF',
  customer_id: customerId,
  payment_method_id: pmId,
  amount: 1500,
  meta: { ticket: 'test' },
}, 'scenario:auth_redirect');
const chargeId = ch.data?.id;
console.log('next_action', JSON.stringify(ch.data?.next_action, null, 2));

if (chargeId) {
  await new Promise((r) => setTimeout(r, 8000));
  await req('GET', `/charges/${chargeId}`);
}
