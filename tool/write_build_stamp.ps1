# Writes build/web/version.json with hash + editor generation for deploy verification.
param(
  [string]$ProjectRoot = (Join-Path $PSScriptRoot "..")
)

$ErrorActionPreference = "Stop"
$mainJs = Join-Path $ProjectRoot "build\web\main.dart.js"
if (-not (Test-Path $mainJs)) { return }

$hash = (Get-FileHash $mainJs -Algorithm SHA256).Hash.Substring(0, 16)
$stamp = @{
  builtAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
  editor = "visual-html-v2"
  mainJsBytes = (Get-Item $mainJs).Length
  mainJsSha256Prefix = $hash
} | ConvertTo-Json -Compress

$out = Join-Path $ProjectRoot "build\web\version.json"
Set-Content -Path $out -Value $stamp -Encoding UTF8
Write-Host "Wrote $out ($stamp)" -ForegroundColor DarkGray
