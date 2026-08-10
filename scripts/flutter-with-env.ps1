param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('run', 'build')]
  [string] $Command,

  [string] $Device,
  [string] $BuildTarget,
  [switch] $Release
)

$projectRoot = Split-Path -Parent $PSScriptRoot
$envValues = & "$PSScriptRoot/load-env.ps1"

$dartDefineKeys = @(
  'SUPABASE_URL',
  'SUPABASE_ANON_KEY',
  'REVENUECAT_API_KEY',
  'REVENUECAT_WEB_API_KEY',
  'REVENUECAT_ENTITLEMENT_ID',
  'FIREBASE_API_KEY',
  'FIREBASE_APP_ID',
  'FIREBASE_MESSAGING_SENDER_ID',
  'FIREBASE_PROJECT_ID',
  'FIREBASE_AUTH_DOMAIN',
  'FIREBASE_STORAGE_BUCKET',
  'FIREBASE_WEB_VAPID_KEY',
  'FIREBASE_MESSAGING_ENABLED',
  'GOOGLE_MAPS_API_KEY',
  'NVIDIA_MODEL'
)

$args = @('flutter', $Command)

if ($Command -eq 'run' -and $Device) {
  $args += @('-d', $Device)
}

if ($Command -eq 'build' -and $BuildTarget) {
  $args += $BuildTarget
}

if ($Release) {
  $args += '--release'
}

foreach ($key in $dartDefineKeys) {
  if ($envValues.ContainsKey($key) -and -not [string]::IsNullOrWhiteSpace($envValues[$key])) {
    $args += "--dart-define=$key=$($envValues[$key])"
  }
}

Write-Host "Using Flutter environment from .env" -ForegroundColor Cyan
if ($envValues.Count -eq 0) {
  Write-Host "No .env file detected. The app will run with setup warnings." -ForegroundColor Yellow
}

Push-Location $projectRoot
try {
  & $args[0] $args[1..($args.Length - 1)]
  exit $LASTEXITCODE
} finally {
  Pop-Location
}
