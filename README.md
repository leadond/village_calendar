# My Village Pro

Flutter app for coordinating childcare requests, villages, subscriptions, and location-aware reminders.

## Local Setup

1. Copy the template:
   `Copy-Item .env.example .env`
2. Fill in the values you have available in `.env`.
3. Install dependencies:
   `flutter pub get`

## Run

The npm scripts now load Flutter `--dart-define` values from `.env` automatically.

- `npm run start:web-server`
- `npm run start:web`
- `npm run start:windows`
- `npm run build`

If `.env` is missing or only partially filled in, the app still launches and shows setup warnings for the missing services.

## Environment Keys

Supported keys for automatic Flutter injection:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `NVIDIA_MODEL`
- `GOOGLE_MAPS_API_KEY`
- `REVENUECAT_API_KEY`
- `REVENUECAT_WEB_API_KEY`
- `REVENUECAT_ENTITLEMENT_ID`
- `FIREBASE_API_KEY`
- `FIREBASE_APP_ID`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_AUTH_DOMAIN`
- `FIREBASE_STORAGE_BUCKET`
- `FIREBASE_MESSAGING_ENABLED`

## NVIDIA AI

The app now includes secure AI hooks for:

- drafting help requests from plain English
- polishing village-wide announcements

The Flutter client does not send your NVIDIA API key directly. Instead, it calls the Supabase Edge Function:

- `supabase/functions/ai-assistant`

Before using AI:

1. Set the Supabase secret:
   `supabase secrets set NVIDIA_API_KEY=... NVIDIA_MODEL=nvidia/llama-3.1-nemotron-nano-8b-v1`
2. Deploy the function:
   `supabase functions deploy ai-assistant`
3. Start the app normally:
   `npm run start:web-server`
