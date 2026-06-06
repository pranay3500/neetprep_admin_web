# Canonical Flutter SDK for this machine (edit tool/flutter_sdk.path if it moves).
# Dot-source from other scripts: . "$PSScriptRoot\flutter_env.ps1"
#
# Usage: Invoke-Flutter -Command pub,get
#        Invoke-Flutter -Command run,-d,chrome
# (Comma-separated list avoids PowerShell swallowing flags like -d.)

$ErrorActionPreference = "Stop"

$FlutterSdkPathFile = Join-Path $PSScriptRoot "flutter_sdk.path"
if (-not (Test-Path $FlutterSdkPathFile)) {
  throw "Missing $FlutterSdkPathFile"
}

$script:FlutterSdkRoot = (Get-Content $FlutterSdkPathFile -Raw).Trim()
$script:FlutterBat = Join-Path $script:FlutterSdkRoot "bin\flutter.bat"
$script:DartBat = Join-Path $script:FlutterSdkRoot "bin\dart.bat"

if (-not (Test-Path $script:FlutterBat)) {
  throw "Flutter not found at $script:FlutterBat (check tool/flutter_sdk.path)"
}

$binDir = Join-Path $script:FlutterSdkRoot "bin"
if ($env:PATH -notlike "*$binDir*") {
  $env:PATH = "$binDir;$env:PATH"
}

function Invoke-Flutter {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Command
  )
  & $script:FlutterBat @Command
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

function Invoke-Dart {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Command
  )
  & $script:DartBat @Command
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
