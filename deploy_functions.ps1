# deploy_functions.ps1
# Deploys the Cloud Functions. Kashier keys are read from the gitignored
# functions/.env; Firebase deploys that .env as the function's runtime
# environment (Firebase Functions v2 params). No keys are committed to git.
#
# Keys NEVER live in tracked source files — only in functions/.env (gitignored,
# local only), which Firebase uploads as the deployed function's environment.
#
# Usage (from repo root):
#   .\deploy_functions.ps1

$ErrorActionPreference = 'Stop'

$envFile = 'functions/.env'
if (-not (Test-Path $envFile)) {
  Write-Host "Missing $envFile. Copy functions/.env.example -> functions/.env and fill in your LIVE keys." -ForegroundColor Red
  exit 1
}

# Parse KEY=VALUE lines (ignore comments / blank lines)
$config = @{}
Get-Content $envFile | ForEach-Object {
  $line = $_.Trim()
  if ($line -and -not $line.StartsWith('#')) {
    $parts = $line -split '=', 2
    if ($parts.Count -eq 2) { $config[$parts[0].Trim()] = $parts[1].Trim() }
  }
}

$k = $config['KASHIER_API_KEY']
$s = $config['KASHIER_SECRET_KEY']
$m = $config['KASHIER_MERCHANT_ID']
$b = $config['KASHIER_BASE_URL']

# Guard against placeholders
if (-not $k -or $k -eq 'REPLACE_WITH_YOUR_API_KEY') {
  Write-Host 'Please set a real KASHIER_API_KEY in functions/.env' -ForegroundColor Red
  exit 1
}
if (-not $s -or $s -eq 'REPLACE_WITH_YOUR_SECRET_KEY') {
  Write-Host 'Please set a real KASHIER_SECRET_KEY in functions/.env' -ForegroundColor Red
  exit 1
}
if (-not $m -or $m -eq 'REPLACE_WITH_YOUR_MERCHANT_ID') {
  Write-Host 'Please set a real KASHIER_MERCHANT_ID in functions/.env' -ForegroundColor Red
  exit 1
}

Write-Host 'Deploying functions (keys come from the gitignored functions/.env, deployed as the function environment)...' -ForegroundColor Cyan
firebase deploy --only functions

Write-Host 'Done. If the payment still fails, inspect logs with: firebase functions:log' -ForegroundColor Green
