// Supabase Edge Function: push-notify
// Sends an FCM push when a row is inserted into public.notifications.
//
// WIRING (requires YOUR Firebase credentials — not yet active):
//  1. Create a Firebase service account (Project Settings > Service accounts)
//     and set its JSON as a secret:
//       supabase secrets set FCM_SERVICE_ACCOUNT='{"project_id":...}'
//  2. Deploy:  supabase functions deploy push-notify
//  3. Add a Database Webhook (Database > Webhooks) on INSERT of
//     public.notifications that POSTs the row to this function, OR call it from
//     a trigger via pg_net.
//
// The app already stores each user's token in profiles.push_token and writes
// notifications rows via DB triggers; this function just delivers them.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface NotificationRow {
  recipient_id: string;
  title: string;
  body: string;
  data: Record<string, unknown>;
}

Deno.serve(async (req) => {
  try {
    const payload = await req.json();
    const row: NotificationRow = payload.record ?? payload;

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: profile } = await supabase
      .from("profiles")
      .select("push_token")
      .eq("id", row.recipient_id)
      .maybeSingle();

    const token = profile?.push_token;
    if (!token) return new Response("no token", { status: 200 });

    const accessToken = await getFcmAccessToken();
    const serviceAccount = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!);

    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title: row.title, body: row.body },
            data: Object.fromEntries(
              Object.entries(row.data ?? {}).map(([k, v]) => [k, String(v)]),
            ),
          },
        }),
      },
    );

    return new Response(await res.text(), { status: res.status });
  } catch (e) {
    return new Response(`error: ${e}`, { status: 500 });
  }
});

// Exchange the service-account JSON for an OAuth access token (JWT grant).
async function getFcmAccessToken(): Promise<string> {
  const sa = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!);
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claim = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const enc = (o: unknown) =>
    btoa(JSON.stringify(o)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const unsigned = `${enc(header)}.${enc(claim)}`;

  const keyData = sa.private_key
    .replace(/-----[^-]+-----/g, "")
    .replace(/\s/g, "");
  const der = Uint8Array.from(atob(keyData), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${
    btoa(String.fromCharCode(...new Uint8Array(sig)))
      .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_")
  }`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const json = await tokenRes.json();
  return json.access_token;
}
