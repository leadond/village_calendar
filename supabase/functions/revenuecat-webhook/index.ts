// Supabase Edge Function: revenuecat-webhook
// Server-verifies subscription state: RevenueCat POSTs events here and we set
// public.profiles.subscription_tier accordingly.
//
// SETUP (needs YOUR RevenueCat account):
//  1. In RevenueCat, set the app user id to the Supabase user id (the app already
//     configures Purchases with appUserID = auth user id).
//  2. Add a webhook (RevenueCat > Project > Integrations > Webhooks) pointing to
//     https://<project-ref>.functions.supabase.co/revenuecat-webhook
//     with an Authorization header value of your choice.
//  3. Set that value as a secret:
//       supabase secrets set REVENUECAT_WEBHOOK_SECRET='<the same value>'
//  4. Deploy: supabase functions deploy revenuecat-webhook  (already deployed by
//     the assistant; redeploy after edits).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ACTIVE = new Set([
  "INITIAL_PURCHASE", "RENEWAL", "PRODUCT_CHANGE", "UNCANCELLATION",
  "NON_RENEWING_PURCHASE", "SUBSCRIPTION_EXTENDED",
]);
const INACTIVE = new Set([
  "CANCELLATION", "EXPIRATION", "BILLING_ISSUE", "SUBSCRIPTION_PAUSED",
]);

Deno.serve(async (req) => {
  const secret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");
  if (secret && req.headers.get("Authorization") !== secret) {
    return new Response("unauthorized", { status: 401 });
  }

  let payload: any;
  try {
    payload = await req.json();
  } catch {
    return new Response("bad request", { status: 400 });
  }

  const event = payload?.event ?? payload;
  const type: string = event?.type ?? "";
  const appUserId: string | undefined =
    event?.app_user_id ?? event?.original_app_user_id;
  if (!appUserId) return new Response("no app_user_id", { status: 200 });

  let tier: string | null = null;
  if (ACTIVE.has(type)) tier = "premium";
  else if (INACTIVE.has(type)) tier = "free";
  if (tier === null) return new Response("ignored", { status: 200 });

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { error } = await supabase
    .from("profiles")
    .update({ subscription_tier: tier })
    .eq("id", appUserId);

  if (error) return new Response(`db error: ${error.message}`, { status: 500 });
  return new Response(JSON.stringify({ updated: appUserId, tier }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
