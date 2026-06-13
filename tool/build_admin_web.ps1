# Release build for NEET Prep admin web (output: build/web/)
# Usage: powershell -File tool/build_admin_web.ps1

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..

. "$PSScriptRoot\flutter_env.ps1"

Write-Host "NEET Prep Admin Web - release build" -ForegroundColor Cyan
Write-Host "Folder: $(Get-Location)" -ForegroundColor DarkGray
Write-Host "Flutter: $script:FlutterSdkRoot" -ForegroundColor DarkGray
Write-Host ""

Invoke-Flutter -Command pub,get
Invoke-Flutter -Command build,web,--release,--no-wasm-dry-run,--pwa-strategy=none

& (Join-Path $PSScriptRoot "write_build_stamp.ps1") -ProjectRoot (Get-Location)

$visualEditor = Join-Path (Get-Location) 'build\web\content_library_visual_editor.html'
if (-not (Test-Path $visualEditor)) {
  throw "Missing $visualEditor - CL Editor visual tab will fail in production. Check web/ assets."
}
Write-Host "OK: content_library_visual_editor.html in build output" -ForegroundColor DarkGray

Write-Host ""
Write-Host "Build complete. Deploy the contents of:" -ForegroundColor Green
Write-Host "  $(Join-Path (Get-Location) 'build\web')" -ForegroundColor White
$mainJs = Join-Path (Get-Location) 'build\web\main.dart.js'
if (Test-Path $mainJs) {
  $h = (Get-FileHash $mainJs -Algorithm SHA256).Hash
  $sz = (Get-Item $mainJs).Length
  Write-Host ""
  Write-Host "CRITICAL - upload main.dart.js ($sz bytes):" -ForegroundColor Yellow
  Write-Host "  SHA256: $h" -ForegroundColor Yellow
  Write-Host "  After upload run: powershell -File tool\verify_live_deploy.ps1" -ForegroundColor Yellow
}
