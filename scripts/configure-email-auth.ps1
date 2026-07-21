<#
.SYNOPSIS
  Configures Supabase Auth to send email through Resend (SMTP), turns on leaked-
  password protection, and (optionally) re-enables email confirmation.

.DESCRIPTION
  Uses the Supabase Management API. You supply:
    - Your Resend API key      (https://resend.com/api-keys)
    - A Supabase access token  (https://supabase.com/dashboard/account/tokens)

  Resend SMTP settings are fixed:
    host = smtp.resend.com, port = 465, user = "resend", pass = <ResendApiKey>

  IMPORTANT: the "From" address must be on a domain you've verified in Resend
  (https://resend.com/domains). For a quick test you can use onboarding@resend.dev,
  which can only email your own Resend account address.

.EXAMPLE
  # Basic: wire up Resend + leaked-password protection (keeps current signup flow)
  ./configure-email-auth.ps1 -ResendApiKey "re_xxx" -SupabaseAccessToken "sbp_xxx" `
      -SenderEmail "no-reply@yourdomain.com" -SenderName "Village Calendar"

.EXAMPLE
  # Production: also require email confirmation on new signups
  ./configure-email-auth.ps1 -ResendApiKey "re_xxx" -SupabaseAccessToken "sbp_xxx" `
      -SenderEmail "no-reply@yourdomain.com" -RequireEmailConfirmation
#>

param(
  [string] $ResendApiKey,
  [string] $SupabaseAccessToken,
  [string] $ProjectRef = "fmeizeyqwjieapfqgicl",
  [string] $SenderEmail,
  [string] $SenderName,
  [switch] $RequireEmailConfirmation
)

$ErrorActionPreference = "Stop"

# Fall back to values in ./.env when a parameter isn't passed.
$envVars = & "$PSScriptRoot/load-env.ps1"
if (-not $ResendApiKey)        { $ResendApiKey        = $envVars["RESEND_API_KEY"] }
if (-not $SupabaseAccessToken) { $SupabaseAccessToken = $envVars["SUPABASE_ACCESS_TOKEN"] }
if (-not $SenderEmail)         { $SenderEmail         = $envVars["RESEND_SENDER_EMAIL"] }
if (-not $SenderName)          { $SenderName          = $envVars["RESEND_SENDER_NAME"] }
if (-not $SenderEmail) { $SenderEmail = "onboarding@resend.dev" }
if (-not $SenderName)  { $SenderName  = "Village Calendar" }

if (-not $ResendApiKey -or -not $SupabaseAccessToken) {
  Write-Host "Missing keys. Add RESEND_API_KEY and SUPABASE_ACCESS_TOKEN to .env" -ForegroundColor Red
  Write-Host "(copy .env.example to .env), or pass -ResendApiKey / -SupabaseAccessToken." -ForegroundColor Red
  exit 1
}
$base = "https://api.supabase.com/v1/projects/$ProjectRef/config/auth"
$headers = @{
  Authorization  = "Bearer $SupabaseAccessToken"
  "Content-Type" = "application/json"
}

Write-Host "Configuring Supabase Auth for project $ProjectRef ..." -ForegroundColor Cyan

# --- 1) SMTP (Resend) + optional email-confirmation requirement ---------------
$body = @{
  external_email_enabled = $true
  smtp_admin_email       = $SenderEmail
  smtp_host              = "smtp.resend.com"
  smtp_port              = "465"
  smtp_user              = "resend"
  smtp_pass              = $ResendApiKey
  smtp_sender_name       = $SenderName
  smtp_max_frequency     = 60
  mailer_autoconfirm     = (-not $RequireEmailConfirmation.IsPresent)
}

try {
  $resp = Invoke-RestMethod -Method Patch -Uri $base -Headers $headers -Body ($body | ConvertTo-Json)
  Write-Host "  [ok] Resend SMTP configured (from: $SenderEmail)." -ForegroundColor Green
  if ($RequireEmailConfirmation.IsPresent) {
    Write-Host "  [ok] Email confirmation REQUIRED for new signups." -ForegroundColor Green
    Write-Host "  NOTE: a DB trigger currently auto-confirms users. To fully enforce" -ForegroundColor Yellow
    Write-Host "        confirmation, run this in the Supabase SQL editor:" -ForegroundColor Yellow
    Write-Host "        drop trigger if exists trg_auto_confirm on auth.users;" -ForegroundColor Yellow
  }
} catch {
  Write-Host "  [FAIL] SMTP config: $($_.Exception.Message)" -ForegroundColor Red
  if ($_.ErrorDetails.Message) { Write-Host $_.ErrorDetails.Message -ForegroundColor Red }
  exit 1
}

# --- 2) Leaked-password protection (best effort; field name may vary) ---------
try {
  Invoke-RestMethod -Method Patch -Uri $base -Headers $headers `
    -Body (@{ password_hibp_enabled = $true } | ConvertTo-Json) | Out-Null
  Write-Host "  [ok] Leaked-password protection enabled (HaveIBeenPwned)." -ForegroundColor Green
} catch {
  Write-Host "  [skip] Could not set leaked-password via API; enable it in the" -ForegroundColor Yellow
  Write-Host "         dashboard: Authentication > Providers > Email." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Done. Send a test: create a new account in the app and confirm the" -ForegroundColor Cyan
Write-Host "email arrives from $SenderEmail. If it doesn't, verify your domain at" -ForegroundColor Cyan
Write-Host "https://resend.com/domains and re-run with that domain's address." -ForegroundColor Cyan
