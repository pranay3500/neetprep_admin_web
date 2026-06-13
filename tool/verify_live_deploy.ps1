# Compare local build\web\main.dart.js with the live admin site.
# Usage: powershell -File tool\verify_live_deploy.ps1

$ErrorActionPreference = "Stop"
$ProjectRoot = Join-Path $PSScriptRoot ".."
$LocalMain = Join-Path $ProjectRoot "build\web\main.dart.js"
$LiveUrl = "https://neetappadmin.satlas.org/main.dart.js"
$LiveIndex = "https://neetappadmin.satlas.org/index.html"

if (-not (Test-Path $LocalMain)) {
  Write-Host "[FAIL] Local build missing. Run build_admin_daily.bat first." -ForegroundColor Red
  exit 1
}

Write-Host "NEET Prep Admin - live deploy verification" -ForegroundColor Cyan
Write-Host "Local: $LocalMain"
Write-Host "Live:  $LiveUrl"
Write-Host ""

$localHash = (Get-FileHash $LocalMain -Algorithm SHA256).Hash
$localSize = (Get-Item $LocalMain).Length
$tmp = Join-Path $env:TEMP "neetprep_admin_main.dart.js"
Invoke-WebRequest -Uri $LiveUrl -OutFile $tmp -UseBasicParsing
$liveHash = (Get-FileHash $tmp -Algorithm SHA256).Hash
$liveSize = (Get-Item $tmp).Length

Write-Host "Local SHA256: $localHash"
Write-Host "Live  SHA256: $liveHash"
Write-Host "Local size:   $localSize bytes"
Write-Host "Live  size:   $liveSize bytes"
Write-Host ""

$liveText = Get-Content $tmp -Raw
$hasCkEditor = $liveText -match "tpkCkEditor"
$hasVisual = $liveText -match "Visual edit"

try {
  $head = Invoke-WebRequest -Uri $LiveUrl -Method Head -UseBasicParsing
  $lastMod = $head.Headers["Last-Modified"]
  $cache = $head.Headers["Cache-Control"]
  $server = $head.Headers["Server"]
  if ($lastMod) { Write-Host "Live Last-Modified: $lastMod" }
  if ($cache) { Write-Host "Live Cache-Control: $cache" }
  if ($server) { Write-Host "Live Server: $server" }
  Write-Host ""
} catch { }

if ($localHash -eq $liveHash) {
  Write-Host "[OK] main.dart.js on live site MATCHES your local build." -ForegroundColor Green
  exit 0
}

Write-Host "[FAIL] main.dart.js on live site does NOT match local build." -ForegroundColor Red
if ($hasCkEditor) {
  Write-Host "       Live JS still contains OLD CKEditor (tpkCkEditor)." -ForegroundColor Red
}
if ($hasVisual) {
  Write-Host "       Live JS contains new Visual edit strings (partial/mixed deploy?)." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Fix:" -ForegroundColor Yellow
Write-Host "  1. On Satlas, delete main.dart.js (the .js file, ~5 MB) in the site ROOT."
Write-Host "  2. Upload main.dart.js from build\web\ ($localSize bytes)."
Write-Host "  3. Upload flutter_bootstrap.js from the same folder (should be ~9805 bytes, not 3 KB)."
Write-Host "  4. If Server shows cloudflare: purge CDN cache (Caching -> Purge Everything)."
Write-Host "  5. Re-run this script until [OK]."
Write-Host "  6. Hard-refresh https://neetappadmin.satlas.org/ (Ctrl+Shift+R)."

try {
  $index = (Invoke-WebRequest -Uri $LiveIndex -UseBasicParsing).Content
  if ($index -match "serviceWorker") {
    Write-Host ""
    Write-Host "Note: Live index.html includes service-worker cleanup script." -ForegroundColor DarkGray
  }
} catch {
  Write-Host "Could not fetch live index.html: $_" -ForegroundColor DarkGray
}

exit 1
