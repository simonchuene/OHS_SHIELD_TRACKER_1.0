// path: supabase/functions/_shared/fcm.ts
// FCM HTTP v1 transport, shared by `notify-fanout` (event-driven) and
// `notify-sweep` (scheduled).
//
// The legacy endpoint this replaced (`fcm.googleapis.com/fcm/send`, authorised
// by a static `FCM_SERVER_KEY`) was retired by Google in 2024. v1 authorises
// with a short-lived OAuth2 bearer minted from a service account, so the JWT
// signing + token exchange live here and `index.ts` stays about fan-out.
//
// Config: `FIREBASE_SERVICE_ACCOUNT` = the service-account JSON, verbatim.
//   supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat service-account.json)"
// Absent or malformed => `fcmConfigured` is false and push is skipped, which
// preserves the "degrades gracefully with no Firebase wiring" property.

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

const OAUTH_TOKEN_URL = 'https://oauth2.googleapis.com/token';
const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

const account: ServiceAccount | null = (() => {
  const raw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw);
    if (parsed?.project_id && parsed?.client_email && parsed?.private_key) return parsed;
    console.error('FIREBASE_SERVICE_ACCOUNT lacks project_id/client_email/private_key — push disabled');
  } catch (e) {
    console.error('FIREBASE_SERVICE_ACCOUNT is not valid JSON — push disabled', e);
  }
  return null;
})();

/// True when a usable service account is configured. Callers skip push otherwise.
export const fcmConfigured = account !== null;

const b64url = (bytes: Uint8Array) =>
  btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
const b64urlText = (s: string) => b64url(new TextEncoder().encode(s));

// Importing the key is pure CPU; do it once per instance, not once per send.
let signingKey: CryptoKey | null = null;
async function getSigningKey(pem: string): Promise<CryptoKey> {
  if (signingKey) return signingKey;
  const der = pem
    .replace(/\\n/g, '\n') // tolerate a secret stored with escaped newlines
    .replace(/-----(BEGIN|END) PRIVATE KEY-----/g, '')
    .replace(/\s/g, '');
  signingKey = await crypto.subtle.importKey(
    'pkcs8',
    Uint8Array.from(atob(der), (c) => c.charCodeAt(0)),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  return signingKey;
}

// Access tokens live an hour and Edge Function instances are reused across
// invocations, so cache — refreshing a minute early rather than racing expiry.
let cachedToken: { value: string; expiresAt: number } | null = null;

async function accessToken(acct: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt > now + 60) return cachedToken.value;

  const header = b64urlText(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = b64urlText(JSON.stringify({
    iss: acct.client_email,
    scope: SCOPE,
    aud: OAUTH_TOKEN_URL,
    iat: now,
    exp: now + 3600,
  }));
  const signature = new Uint8Array(await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    await getSigningKey(acct.private_key),
    new TextEncoder().encode(`${header}.${claims}`),
  ));

  const res = await fetch(OAUTH_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${header}.${claims}.${b64url(signature)}`,
    }),
  });
  if (!res.ok) throw new Error(`FCM OAuth exchange failed (${res.status}): ${await res.text()}`);

  const tok = await res.json();
  cachedToken = { value: tok.access_token, expiresAt: now + (tok.expires_in ?? 3600) };
  return cachedToken.value;
}

/// `stale` = FCM rejected the token itself (app uninstalled, token rotated);
/// the caller should deactivate it rather than retry.
export type PushOutcome = 'sent' | 'stale' | 'failed';

export async function sendPush(opts: {
  token: string;
  title: string;
  body: string;
  data: Record<string, string>;
  highPriority: boolean;
}): Promise<PushOutcome> {
  const acct = account!;
  const bearer = await accessToken(acct);

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${acct.project_id}/messages:send`,
    {
      method: 'POST',
      headers: { Authorization: `Bearer ${bearer}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: {
          token: opts.token,
          notification: { title: opts.title, body: opts.body },
          // v1 requires every data value to be a string; FcmService reads
          // entityType/entityId back out to build the deep link.
          data: opts.data,
          // No `channel_id`: the app declares no notification channel, and
          // naming one that does not exist suppresses the notification on
          // Android 8+. This lets FCM fall back to its default channel.
          android: { priority: opts.highPriority ? 'HIGH' : 'NORMAL' },
          apns: {
            headers: { 'apns-priority': opts.highPriority ? '10' : '5' },
            payload: { aps: { sound: 'default' } },
          },
        },
      }),
    },
  );

  if (res.ok) return 'sent';

  const detail = await res.text();
  // 404 UNREGISTERED / 400 INVALID_ARGUMENT both mean "stop sending here".
  if (res.status === 404 || (res.status === 400 && detail.includes('INVALID_ARGUMENT'))) {
    return 'stale';
  }
  console.error(`FCM send failed (${res.status}): ${detail}`);
  return 'failed';
}
