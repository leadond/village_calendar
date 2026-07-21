# Village Calendar — Production Setup

Everything below is **code-complete and (where possible) already deployed**. Each
section is the one remaining step that needs *your* account/key. Do them in any
order; the app runs fine without them (features degrade gracefully).

Project ref: `fmeizeyqwjieapfqgicl`

---

## Already done for you
- Security hardening (RLS, function execute, private kid photos, search_path).
- Edge functions **deployed live**: `push-notify`, `revenuecat-webhook`.
- `pg_cron` job `purge-breadcrumbs` (daily 03:00) — GPS trail auto-deletes after 7 days.
- Firebase Hosting + Vercel deploys, GitHub repo.

---

## 1. Email (Resend) — `scripts/configure-email-auth.ps1`
Get a key at https://resend.com/api-keys and a Supabase token at
https://supabase.com/dashboard/account/tokens, then:
```powershell
./scripts/configure-email-auth.ps1 -ResendApiKey "re_xxx" -SupabaseAccessToken "sbp_xxx" `
    -SenderEmail "no-reply@yourdomain.com" -SenderName "Village Calendar"
```
Verify your domain at https://resend.com/domains. Add `-RequireEmailConfirmation`
for production, and then drop the dev auto-confirm trigger (the script prints the line).

## 2. Google Maps (live trip map)
Get a **Maps Static API** key (console.cloud.google.com → enable "Maps Static API"
→ create key → restrict to your domains). Then build with it:
```powershell
./scripts/build-web.ps1 -GoogleMapsApiKey "AIza..."
```
The parent's live-tracking view then renders a map with the helper's marker + route.
Without the key it falls back to live coordinates.

## 3. Push notifications (FCM) — function already deployed
In-app notifications work now (realtime). For device/browser push delivery:
1. Firebase Console → Project settings → Service accounts → **Generate new private key**.
2. Set it as a secret (Supabase CLI, linked to the project):
   ```
   supabase secrets set FCM_SERVICE_ACCOUNT='<paste the JSON>'
   ```
3. Database → Webhooks → new webhook on **INSERT of `public.notifications`** →
   POST to the `push-notify` function.
4. For **web** push also add a Web Push VAPID key (Firebase → Cloud Messaging →
   Web config) and build with the Firebase web config dart-defines +
   `FIREBASE_MESSAGING_ENABLED=true` (see `scripts/build-web.ps1`).

## 4. RevenueCat (real purchases) — webhook already deployed
Paywall + gating already read `profiles.subscription_tier`. To enable purchases:
1. RevenueCat dashboard → configure products/entitlements.
2. Build with `-RevenueCatApiKey "<platform key>"` (see build script).
3. Add a RevenueCat webhook → `https://fmeizeyqwjieapfqgicl.functions.supabase.co/revenuecat-webhook`
   with an `Authorization` header value of your choice, then set the matching secret:
   ```
   supabase secrets set REVENUECAT_WEBHOOK_SECRET='<same value>'
   ```
   The webhook flips `subscription_tier` to `premium`/`free` server-side.

## 5. Before launch (must-do)
- Re-enable email confirmation (section 1) and remove the demo accounts
  (`demo@villagecalendar.app`) + dev passwords.
- Enable leaked-password protection (the email script does this).
- Replace the placeholder **Terms/Privacy** with real, lawyer-reviewed policies.
  Because you store children's data, US **COPPA** (and likely GDPR-K) apply —
  you need verifiable parental consent. This is a legal task, not a code one.
- QA pass, especially multi-user village isolation.
- Mobile: iOS `GoogleService-Info.plist`, app signing, and store listings
  (Android already has `google-services.json`).

---

## Build commands
- Dev (web, hot): `flutter run -d web-server --web-port 5317 --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
- Production web bundle with all keys: `scripts/build-web.ps1` (see its params).
