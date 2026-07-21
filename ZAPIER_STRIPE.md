# Zapier Forms + Stripe → Village Calendar Premium

## How it fits the app (the seam)
The app unlocks premium purely from **`profiles.subscription_tier = 'premium'`**.
So the entire integration is:

```
Zapier Form (collects email + plan, takes Stripe payment)
   → Zap logs the sale in a Zapier Table
   → Zap POSTs to the deployed `grant-premium` endpoint
       → sets that user's subscription_tier = premium
   → app refreshes → premium features unlock
```

You do **not** need RevenueCat if you go this route (they're two paths to the same
column — pick one for web to avoid double-charging).

### The secure endpoint (already deployed)
```
POST https://fmeizeyqwjieapfqgicl.functions.supabase.co/grant-premium
Header:  x-zapier-secret: <YOUR_SECRET>
Body:    { "user_id": "<supabase-user-uuid>", "tier": "premium" }
         (or use "email" instead of user_id)
```
Set the secret once:
```
supabase secrets set ZAPIER_GRANT_SECRET='<a long random string>'
```
To downgrade on cancellation, POST the same with `"tier": "free"`.

### Passing the user into the form
Open the Zapier form from the app's Upgrade button with the signed-in user
prefilled, so the Zap knows who to upgrade:
```
https://<your-interface>.zapier.app/subscribe?user_id=<UID>&email=<EMAIL>&plan=<PLAN>
```
Zapier Interfaces can map those query params into hidden form fields.

---

## Zapier Table — "Village Subscriptions"
Create a Table with these fields:

| Field                | Type       | Notes                                        |
|----------------------|------------|----------------------------------------------|
| user_id              | Text       | Supabase auth user id (from the form param)  |
| email                | Email      | Customer email                               |
| plan                 | Dropdown   | monthly, yearly, lifetime                    |
| amount               | Number     | Amount charged                               |
| currency             | Text       | e.g. USD                                     |
| stripe_customer_id   | Text       | From Stripe                                  |
| stripe_payment_id    | Text       | Payment/Checkout Session id                  |
| status               | Dropdown   | paid, refunded, canceled                     |
| tier                 | Dropdown   | premium, free                                |
| granted              | Checkbox   | True once grant-premium succeeded            |
| created_at           | Created time | auto                                       |
| expires_at           | Date       | for monthly/yearly (optional)               |

This Table is your audit log / source of truth in Zapier; the Zap writes a row
per sale and flips `granted` after the endpoint call succeeds.

---

## Zapier Copilot prompt (paste into Zapier)
> Build me a subscription checkout for my app "Village Calendar".
>
> 1. Create a **Zapier Interface** with a **Form** page at path `/subscribe`
>    titled "Village Calendar Premium". Fields:
>    - Full name (text, required)
>    - Email (email, required)
>    - Plan (dropdown: Monthly, Yearly, Lifetime, required)
>    - A **hidden** field `user_id` that is pre-filled from the URL query
>      parameter `user_id`, and a hidden `email` pre-filled from `email`.
>    - Add a **Stripe payment** component so the form collects payment for the
>      selected plan (Monthly and Yearly as recurring subscriptions, Lifetime as
>      a one-time payment). Connect my Stripe account.
>
> 2. Create a **Zapier Table** named "Village Subscriptions" with fields:
>    user_id (text), email (email), plan (dropdown: monthly/yearly/lifetime),
>    amount (number), currency (text), stripe_customer_id (text),
>    stripe_payment_id (text), status (dropdown: paid/refunded/canceled),
>    tier (dropdown: premium/free), granted (checkbox), expires_at (date).
>
> 3. Create a **Zap**:
>    - **Trigger:** New successful submission of the "Village Calendar Premium"
>      form (payment completed).
>    - **Action 1 — Create Record** in the "Village Subscriptions" table with the
>      submitted fields; set status = "paid", tier = "premium".
>    - **Action 2 — Webhooks by Zapier → POST** to
>      `https://fmeizeyqwjieapfqgicl.functions.supabase.co/grant-premium`
>      with header `x-zapier-secret: <MY_SECRET>` and JSON body
>      `{ "user_id": "{{form.user_id}}", "email": "{{form.email}}", "tier": "premium" }`.
>    - **Action 3 — Update Record** in the table: set `granted` = true.
>
> 4. Create a **second Zap** for cancellations/refunds:
>    - **Trigger:** Stripe — "Customer Subscription Deleted" (and "Charge
>      Refunded").
>    - **Action — Webhooks by Zapier → POST** to the same URL with header
>      `x-zapier-secret: <MY_SECRET>` and body
>      `{ "email": "{{stripe.customer_email}}", "tier": "free" }`.
>    - Also update the matching table row: status = "canceled"/"refunded",
>      tier = "free".
>
> Use my Stripe account for payments and keep the secret in the webhook header.

Replace `<MY_SECRET>` with the value you set for `ZAPIER_GRANT_SECRET`.

---

## Security notes
- The endpoint only accepts the request if the `x-zapier-secret` header matches
  your Supabase secret — so only your Zap can grant premium.
- Prefer matching by **`user_id`** (exact) over email. The app can pass the
  user_id into the form URL; email match is a fallback.
- For recurring plans, the cancellation Zap keeps `subscription_tier` honest.
- Because gating is server-side (`subscription_tier`), the client can't fake
  premium — it only reflects what your Zap wrote.
