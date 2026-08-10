// Supabase Edge Function: grant-premium
// A minimal, secure endpoint for Zapier (or any external payment flow) to flip a
// user's subscription tier after a successful Stripe payment.
//
// Auth: Zapier sends header  x-zapier-secret: <SECRET>.
// The SECRET is read from ZAPIER_GRANT_SECRET if set (to rotate), otherwise a
// baked-in value is used so no Supabase secret needs configuring to start.
//
// Zapier "Webhooks by Zapier → POST" to:
//   https://fmeizeyqwjieapfqgicl.functions.supabase.co/grant-premium
//   Header:  x-zapier-secret: <SECRET>
//   Body (JSON): { "email": "<login email>", "tier": "premium" }   // or "user_id"

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SECRET = Deno.env.get("ZAPIER_GRANT_SECRET") ??
  "vc_zap_YM-_a6dgGKmWQ-K7UQ7H_O7Zj7GaMUzxDbuqP4VXf8M";

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method not allowed", { status: 405 });

  let body: any;
  try { body = await req.json(); } catch { return new Response("bad request", { status: 400 }); }

  const provided = req.headers.get("x-zapier-secret") ?? body?.secret;
  if (provided !== SECRET) return new Response("unauthorized", { status: 401 });

  const userId: string | undefined = body?.user_id;
  const email: string | undefined = body?.email;
  const tier: string = body?.tier ?? "premium";
  if (!userId && !email) return new Response("provide user_id or email", { status: 400 });

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  let query = supabase.from("profiles").update({ subscription_tier: tier });
  query = userId ? query.eq("id", userId) : query.eq("email", email!);
  const { data, error } = await query.select("id, email");

  if (error) return new Response(`db error: ${error.message}`, { status: 500 });
  return new Response(JSON.stringify({ updated: data?.length ?? 0, tier, data }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
