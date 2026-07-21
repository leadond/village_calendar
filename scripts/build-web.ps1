<#
.SYNOPSIS
  Builds the production Flutter web bundle with all runtime keys baked in.

.EXAMPLE
  ./scripts/build-web.ps1 -GoogleMapsApiKey "AIza..." -RevenueCatApiKey "appl_..."
#>
param(
  [string] $SupabaseUrl = "https://fmeizeyqwjieapfqgicl.supabase.co",
  [Parameter(Mandatory = $true)] [string] $SupabaseAnonKey,
  [string] $GoogleMapsApiKey = "",
  [string] $RevenueCatApiKey = "",
  # Firebase web config (only needed for web push):
  [string] $FirebaseApiKey = "",
  [string] $FirebaseAppId = "",
  [string] $FirebaseMessagingSenderId = "",
  [string] $FirebaseProjectId = "",
  [switch] $EnableFirebaseMessaging
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$defs = @(
  "--dart-define=SUPABASE_URL=$SupabaseUrl",
  "--dart-define=SUPABASE_ANON_KEY=$SupabaseAnonKey"
)
if ($GoogleMapsApiKey) { $defs += "--dart-define=GOOGLE_MAPS_API_KEY=$GoogleMapsApiKey" }
if ($RevenueCatApiKey) { $defs += "--dart-define=REVENUECAT_API_KEY=$RevenueCatApiKey" }
if ($FirebaseApiKey)   { $defs += "--dart-define=FIREBASE_API_KEY=$FirebaseApiKey" }
if ($FirebaseAppId)    { $defs += "--dart-define=FIREBASE_APP_ID=$FirebaseAppId" }
if ($FirebaseMessagingSenderId) { $defs += "--dart-define=FIREBASE_MESSAGING_SENDER_ID=$FirebaseMessagingSenderId" }
if ($FirebaseProjectId) { $defs += "--dart-define=FIREBASE_PROJECT_ID=$FirebaseProjectId" }
if ($EnableFirebaseMessaging.IsPresent) { $defs += "--dart-define=FIREBASE_MESSAGING_ENABLED=true" }

Write-Host "Building web with $($defs.Count) dart-defines..." -ForegroundColor Cyan
& flutter build web --release @defs
if ($LASTEXITCODE -ne 0) { throw "flutter build failed" }

# SPA routing for Vercel static deploys
Set-Content -Path "build/web/vercel.json" -Value '{ "rewrites": [ { "source": "/(.*)", "destination": "/index.html" } ] }'
Write-Host "Built build/web. Deploy with:" -ForegroundColor Green
Write-Host "  firebase deploy --only hosting:village-calendar" -ForegroundColor Green
Write-Host "  (cd build/web; vercel deploy --prod --yes)" -ForegroundColor Green
