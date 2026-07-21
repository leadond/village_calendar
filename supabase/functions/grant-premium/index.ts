// Supabase Edge Function: grant-premium
// A minimal, secure endpoint for Zapier (or any external payment flow) to flip a
// user's subscription tier after a successful Stripe payment. Zapier calls this
// with a shared secret instead of holding your service-role key.
//
// SETUP:
//   supabase secrets set ZAPIER_GRANT_SECRET='<a long random string>'
//   (already deployed by the assistant)
//
// Zapier "Webhooks by Zapier → POST" to:
//   https://fmeizeyqwjieapfqgicl.functions.supabase.co/grant-premium
//   Header:  x-zapier-secret: <the same secret>
//   Body (JSON): { "user_id": "<supabase uuid>", "tier": "premium" }
//   (or match by "email" if you don't have the user_id)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method not allowed", { status: 405 });

  const secret = Deno.env.get("ZAPIER_GRANT_SECRET");
  let body: any;
  try { body = await req.json(); } catch { return new Response("bad request", { status: 400 }); }

  const provided = req.headers.get("x-zapier-secret") ?? body?.secret;
  if (!secret || provided !== secret) return new Response("unauthorized", { status: 401 });

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
