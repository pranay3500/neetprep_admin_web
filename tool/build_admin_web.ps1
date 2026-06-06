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
Invoke-Flutter -Command build,web,--release,--no-wasm-dry-run

Write-Host ""
Write-Host "Build complete. Deploy the contents of:" -ForegroundColor Green
Write-Host "  $(Join-Path (Get-Location) 'build\web')" -ForegroundColor White
