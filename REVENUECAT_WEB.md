# RevenueCat — Web (My Village Pro)

## Important: which SDK
Your app is **Flutter**. RevenueCat has two SDKs:
- `purchases_flutter` → **iOS / Android only** (already wired for mobile).
- `@revenuecat/purchases-js` → **Web** (your live app is Flutter *web*, so this
  is the one that powers purchases on the deployed site).

Because `@revenuecat/purchases-js` is JavaScript, it's bridged into Flutter web
via `dart:js_interop`. This repo already contains that bridge — you only need to
finish the RevenueCat dashboard setup and (for production) connect Stripe.

Files in this repo:
- `web/revenuecat_bridge.js` — loads `@revenuecat/purchases-js` and exposes `window.RCWeb`.
- `web/index.html` — includes the bridge.
- `lib/src/services/revenuecat_web*.dart` — Dart wrapper (web impl + mobile stub).
- `lib/src/features/subscriptions/paywall_screen.dart` — uses the bridge on web.
- `supabase/functions/revenuecat-webhook/` — **deployed**; syncs `subscription_tier`.

---

## 1. Install (for any JS surface)
```bash
npm install --save @revenuecat/purchases-js
```
This Flutter app doesn't bundle npm; the bridge imports the SDK from a pinned ESM
CDN (`esm.sh/@revenuecat/purchases-js@1.13.2`). If you prefer bundling, run the
npm install in a JS build and import it there instead.

## 2. RevenueCat dashboard setup
1. **Connect Stripe** (Web Billing uses Stripe as the gateway):
   RevenueCat → Account/Project settings → connect your Stripe account.
2. **Create a Web Billing app** in the project (choose the connected Stripe account).
3. **Entitlement**: create one with identifier **`pro`** (display name
   "My Village Pro"). The app checks this id (override with
   `--dart-define=REVENUECAT_ENTITLEMENT_ID=...` if you name it differently).
4. **Products** (Web Billing): create `monthly`, `yearly`, `lifetime`, each
   attached to the `pro` entitlement.
5. **Offering**: create an offering (e.g. `default`) and add packages →
   Monthly = `monthly`, Annual = `yearly`, Lifetime = `lifetime`. Mark it the
   **current** offering.

## 3. API key
Your Web Billing **public** key is already set as the default
(`test_...`, sandbox). For production, pass the live key at build time:
```powershell
./scripts/build-web.ps1 -SupabaseAnonKey <key> -RevenueCatApiKey <ignored-on-web>
# web key:
flutter build web --release --dart-define=REVENUECAT_WEB_API_KEY=<web_public_key> ...
```

## 4. Webhook (server-verified entitlements) — already deployed
The app **gates features on `profiles.subscription_tier`** (server truth), not on
the client. The deployed `revenuecat-webhook` edge function updates that column.
Wire it up:
1. RevenueCat → Integrations → Webhooks → URL:
   `https://fmeizeyqwjieapfqgicl.functions.supabase.co/revenuecat-webhook`
   with an `Authorization` header value you choose.
2. `supabase secrets set REVENUECAT_WEBHOOK_SECRET='<same value>'`
3. Ensure the RevenueCat **app user id = the Supabase auth user id** (the app
   configures the SDK with the signed-in user's id, so this is automatic).

---

## 5. The modern Web SDK API (reference)
This is what the bridge uses; here it is as plain JS if you build a separate web
surface.

```js
import { Purchases, PurchasesError, ErrorCode } from "@revenuecat/purchases-js";

// Configure ONCE. appUserId must be your Supabase user id.
const purchases = Purchases.configure({
  apiKey: "test_qeVgqUcpbgLSQIRIiKClErHwoyh",
  appUserId: supabaseUserId,
});

// Entitlement check (customer info)
async function isPro() {
  try {
    const info = await Purchases.getSharedInstance().getCustomerInfo();
    return "pro" in info.entitlements.active;      // "My Village Pro"
  } catch (e) { console.error(e); return false; }
}

// Offerings / packages (monthly, yearly, lifetime)
async function loadPackages() {
  const offerings = await Purchases.getSharedInstance().getOfferings();
  const cur = offerings.current;
  if (!cur || cur.availablePackages.length === 0) return [];
  // cur.monthly / cur.annual / cur.packagesById["lifetime"] also work
  return cur.availablePackages;
}

// Purchase with error handling
async function buy(pkg) {
  try {
    const { customerInfo, redemptionInfo } =
      await Purchases.getSharedInstance().purchase({ rcPackage: pkg });
    if ("pro" in customerInfo.entitlements.active) unlockPro();
  } catch (e) {
    if (e instanceof PurchasesError && e.errorCode === ErrorCode.UserCancelledError) {
      // user closed the sheet — ignore
    } else { console.error(e); showError(); }
  }
}

// RevenueCat-hosted Paywall (recommended)
async function showPaywall() {
  const target = document.getElementById("paywall-container");
  const { customerInfo } =
    await Purchases.getSharedInstance().presentPaywall({ htmlTarget: target });
  if ("pro" in customerInfo.entitlements.active) unlockPro();
}
```

## 6. Best practices
- **Configure once**, early, with `appUserId = your auth user id` so entitlements
  follow the customer across web + mobile.
- **Gate on the server** (`subscription_tier` via the webhook), not on the client
  `customerInfo` — the app already does this. Use `customerInfo`/`isPremium()`
  only for immediate UI feedback right after a purchase.
- **Present the RevenueCat Paywall** (`presentPaywall`) instead of hand-building
  the purchase UI — it handles pricing, localization, and checkout.
- Handle `ErrorCode.UserCancelledError` silently; surface everything else.

## 7. Customer Center
RevenueCat's **Customer Center** (self-serve manage/cancel/refund UI) is currently
a **mobile** feature (iOS/Android/RN/Flutter via `RevenueCatUI`). On **web**, the
equivalent is the billing provider's customer portal — with Web Billing/Stripe,
link customers to **Stripe's customer portal** for managing/cancelling. Add a
"Manage subscription" link in the Profile screen that opens that portal URL.
When RevenueCat ships a web Customer Center, swap it in behind the same button.

## 8. Testing
Use the sandbox `test_` key and Stripe **test mode** cards
(https://www.revenuecat.com/docs/web/web-billing/testing). Buy in the app →
confirm `subscription_tier` flips to `premium` (webhook) → premium features
(multiple villages, live GPS) unlock.
