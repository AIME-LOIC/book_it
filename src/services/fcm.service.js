import { createSign } from 'node:crypto';

let cachedAccessToken = null;
let cachedUntil = 0;

const base64url = (value) => Buffer.from(value).toString('base64url');

const serviceAccount = () => {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw);
    if (!parsed.project_id || !parsed.client_email || !parsed.private_key) return null;
    return parsed;
  } catch {
    console.error('[FCM] FIREBASE_SERVICE_ACCOUNT_JSON is not valid JSON.');
    return null;
  }
};

async function getAccessToken(account) {
  if (cachedAccessToken && Date.now() < cachedUntil) return cachedAccessToken;
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64url(JSON.stringify({
    iss: account.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = header + '.' + claims;
  const signer = createSign('RSA-SHA256');
  signer.update(unsigned);
  signer.end();
  const assertion = unsigned + '.' + signer.sign(account.private_key, 'base64url');
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  const result = await response.json();
  if (!response.ok || !result.access_token) {
    throw new Error('Google OAuth token request failed: ' + (result.error_description || result.error || response.status));
  }
  cachedAccessToken = result.access_token;
  cachedUntil = Date.now() + Math.max(60, Number(result.expires_in || 3600) - 60) * 1000;
  return cachedAccessToken;
}

export async function sendPushToTokens(tokens, { title, body, data = {} }) {
  const account = serviceAccount();
  if (!account || !tokens.length) return { sent: 0, skipped: tokens.length };
  const accessToken = await getAccessToken(account);
  let sent = 0;
  for (const device of tokens) {
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
      {
        method: 'POST',
        headers: { Authorization: 'Bearer ' + accessToken, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          message: {
            token: device.token,
            notification: { title, body },
            data: Object.fromEntries(Object.entries(data).map(([key, value]) => [key, typeof value === 'string' ? value : JSON.stringify(value)])),
            android: { priority: 'high', notification: { channel_id: 'bookit_updates' } },
            apns: { payload: { aps: { sound: 'default' } } },
          },
        }),
      },
    );
    if (response.ok) {
      sent += 1;
      continue;
    }
    const error = await response.json().catch(() => ({}));
    const errorCode = error?.error?.details?.find?.((item) => item.errorCode)?.errorCode;
    if (errorCode === 'UNREGISTERED' || response.status === 404) {
      device.destroy().catch(() => {});
    } else {
      console.error('[FCM] Delivery failed:', response.status, error?.error?.message || 'unknown error');
    }
  }
  return { sent, skipped: tokens.length - sent };
}
