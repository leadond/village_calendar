# External setup (keys you need to provide)

Everything in the app works in-app today. Three features need third-party
credentials to go fully live. Here's exactly what to get and where.

## 1. Google Maps key (for the live trip map — M6)

Right now the parent's live view shows the helper's coordinates + last-seen.
To render an actual map with the route, you need a **Google Maps JavaScript API
key**.

Where to get it:
1. Go to https://console.cloud.google.com/ and create (or pick) a project.
2. **APIs & Services → Library** → enable **"Maps JavaScript API"**.
   (For mobile later, also enable "Maps SDK for Android" / "Maps SDK for iOS".)
3. **APIs & Services → Credentials → Create credentials → API key**.
4. Click the key → **Application restrictions: Websites** → add
   `http://localhost:*` and your deployed domain. **API restrictions:** limit to
   Maps JavaScript API.
5. Send me the key. I'll add it to `web/index.html` and swap the coordinate
   fallback for a real map (`google_maps_flutter_web`) with marker + polyline.

Billing: Google requires a billing account, but there's a large monthly free
tier that covers normal usage.

## 2. Firebase Cloud Messaging (for push delivery — M7)

In-app notifications (the bell) already work via realtime. To also deliver OS/
browser push:
1. Firebase Console → your project → **Project settings → Service accounts →
   Generate new private key** (downloads a JSON).
2. Set it as a Supabase secret:
   `supabase secrets set FCM_SERVICE_ACCOUNT='<paste JSON>'`
3. Deploy the function: `supabase functions deploy push-notify`
   (code is in `supabase/functions/push-notify/`).
4. Database → Webhooks → new webhook on **INSERT of `public.notifications`** →
   POST to the `push-notify` function.
5. For **web** push specifically, also add a Web Push **VAPID key** (Firebase
   Console → Cloud Messaging → Web configuration) and enable
   `FIREBASE_MESSAGING_ENABLED=true` with the web config dart-defines.

## 3. RevenueCat (for real purchases — M9)

The paywall + feature gating (multiple villages, live GPS) already work against
`profiles.subscription_tier`. To enable real purchases:
1. Create a RevenueCat account, add your app, and configure products/entitlements
   in the dashboard.
2. Pass the platform SDK key at runtime:
   `--dart-define=REVENUECAT_API_KEY=<key>`.
3. Add a RevenueCat **webhook → Supabase** (Edge Function) that updates
   `profiles.subscription_tier` so entitlements are server-verified.

Until then, you can flip a user to premium for testing with SQL:
`update public.profiles set subscription_tier = 'premium' where email = 'you@example.com';`
