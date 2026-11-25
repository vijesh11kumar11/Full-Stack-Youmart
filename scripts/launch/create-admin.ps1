# Creates the production SUPER_ADMIN in the launch copy of the database (youmart_launch).
# You type the email and password here; the password is never shown, saved or printed.
#   & '.\scripts\launch\create-admin.ps1'
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$node = 'C:\Users\vijes\tools\node-v20.20.2-win-x64'
$env:Path = "$node;$env:Path"

# Same connection as the local admin service, but pointed at the launch copy.
$line = Get-Content (Join-Path $repo '.env') | Where-Object { $_ -match '^ADMIN_DATABASE_URL=' } | Select-Object -First 1
if (-not $line) { throw 'ADMIN_DATABASE_URL not found in .env' }
$url = ($line -replace '^ADMIN_DATABASE_URL=', '') -replace '/youmart_dev\?', '/youmart_launch?'
if ($url -notmatch '/youmart_launch\?') { throw 'Could not point ADMIN_DATABASE_URL at youmart_launch' }

$email = Read-Host 'Production admin email (a real mailbox you own)'
$secure = Read-Host 'Password (min 12 characters, use a password manager)' -AsSecureString
$confirm = Read-Host 'Repeat password' -AsSecureString
$plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
$plain2 = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($confirm))
if ($plain -ne $plain2) { throw 'Passwords do not match' }
if ($plain.Length -lt 12) { throw 'Use at least 12 characters' }

try {
  $env:ADMIN_DATABASE_URL = $url
  $env:INITIAL_ADMIN_EMAIL = $email
  $env:INITIAL_ADMIN_PASSWORD = $plain
  Push-Location (Join-Path $repo 'apps\admin-service')
  pnpm run seed | Where-Object { $_ -match 'SUPER_ADMIN|already exists \(id|Error' -and $_ -notmatch 'Permission|Role' }
} finally {
  Pop-Location
  Remove-Item Env:INITIAL_ADMIN_PASSWORD, Env:INITIAL_ADMIN_EMAIL, Env:ADMIN_DATABASE_URL -ErrorAction SilentlyContinue
  $plain = $null; $plain2 = $null
}
Write-Host 'Done. Ignore the "dev placeholder" note above - you chose this password yourself.'
