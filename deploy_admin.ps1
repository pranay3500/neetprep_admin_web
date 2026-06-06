# Build NEET Prep Admin for production web hosting.
# After this script finishes, upload EVERYTHING under build\web\ to the server
# that serves https://neetappadmin.satlas.org/ (replace the old files there).
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File .\deploy_admin.ps1
#
# Optional: set $UploadCommand below to your rsync/scp/FTP CLI (run manually once).

param(
  [string]$FlutterBat = "E:\New_TPK_2026\Apps\NEET_Flutter_App\SDK\flutter\bin\flutter.bat"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
$OutDir = Join-Path $ProjectRoot "build\web"

if (-not (Test-Path $FlutterBat)) {
  Write-Host "Flutter not found at: $FlutterBat" -ForegroundColor Red
  Write-Host "Edit deploy_admin.ps1 -FlutterBat or install Flutter and use 'flutter' on PATH."
  exit 1
}

Set-Location $ProjectRoot
Write-Host "=== NEET Prep Admin — production web build ===" -ForegroundColor Cyan
Write-Host "Project: $ProjectRoot"
Write-Host ""

& $FlutterBat pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $FlutterBat build web --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "Build complete." -ForegroundColor Green
Write-Host "Output folder (upload ALL of this to your server):" -ForegroundColor Yellow
Write-Host "  $OutDir"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Back up the current live site on the server (optional but recommended)."
Write-Host "  2. Upload/replace files in the site's document root with build\web\ contents."
Write-Host "     - index.html, flutter_bootstrap.js, main.dart.js, assets/, canvaskit/, etc."
Write-Host "     - Do NOT upload only main.dart.js — upload the full folder."
Write-Host "  3. Open https://neetappadmin.satlas.org/ and hard-refresh (Ctrl+Shift+R)."
Write-Host "  4. Sign in and smoke-test one page (e.g. Settings or CL Editor)."
Write-Host ""
Write-Host "If the site lives in a subfolder (not domain root), rebuild with:" -ForegroundColor DarkGray
Write-Host "  flutter build web --release --base-href /your-subfolder/" -ForegroundColor DarkGray

# Example upload (uncomment and edit for your server):
# scp -r "$OutDir\*" user@your-server:/var/www/neetappadmin/
