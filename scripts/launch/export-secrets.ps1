# Copies the external-service values (Razorpay, MSG91, Zoho, Anthropic, business details) from the
# local .env into C:\Users\vijes\youmart-launch\secrets-import.env, ready to paste onto the server
# as /opt/youmart/secrets-import.env (deploy/server/fill-secrets.sh applies and then destroys it).
# Prints only key NAMES. Delete the file after launch day.
#   & 'C:\Users\vijes\Videos\Full Stack\scripts\launch\export-secrets.ps1'
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$out = 'C:\Users\vijes\youmart-launch\secrets-import.env'
$keys = @(
  'RAZORPAY_KEY_ID', 'RAZORPAY_KEY_SECRET', 'RAZORPAY_WEBHOOK_SECRET',
  'MSG91_AUTH_KEY', 'MSG91_INTEGRATED_NUMBER', 'MSG91_WHATSAPP_NAMESPACE', 'MSG91_SENDER_ID',
  'ZOHO_CLIENT_ID', 'ZOHO_CLIENT_SECRET', 'ZOHO_REFRESH_TOKEN', 'ZOHO_ACCOUNT_ID', 'ZOHO_FROM_EMAIL',
  'SUPPORT_INBOX_EMAIL', 'ANTHROPIC_API_KEY',
  'BUSINESS_LEGAL_NAME', 'BUSINESS_GSTIN', 'BUSINESS_ADDRESS', 'BUSINESS_STATE', 'BUSINESS_STATE_CODE'
)
$envLines = Get-Content (Join-Path $repo '.env')
$lines = @()
foreach ($k in $keys) {
  $line = $envLines | Where-Object { $_ -match "^$k=" } | Select-Object -First 1
  if ($line) { $lines += $line; Write-Host "exported $k" } else { Write-Host "MISSING  $k" }
}
$lines += 'EMAIL_SENDING_ENABLED=true'
New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
[IO.File]::WriteAllLines($out, $lines)
Write-Host "`nWrote $out - fix the placeholder business values in it, then paste it onto the server."
