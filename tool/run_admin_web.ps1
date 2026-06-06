# Run NEET Prep admin web locally (opens Chrome).
# Usage: powershell -File tool/run_admin_web.ps1
# Optional: powershell -File tool/run_admin_web.ps1 -WebPort 8082

param(
  [int]$WebPort = 8081
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..

. "$PSScriptRoot\flutter_env.ps1"

function Test-TcpPortInUse {
  param([int]$Port)
  $matches = netstat -ano | Select-String ":$Port\s" | Select-String "LISTENING"
  return $null -ne $matches
}

function Stop-StaleDartOnPort {
  param([int]$Port)
  $line = netstat -ano | Select-String ":$Port\s" | Select-String "LISTENING" | Select-Object -First 1
  if (-not $line) { return $false }
  $pidText = ($line -replace '\s+', ' ').ToString().Trim().Split(' ')[-1]
  if ($pidText -notmatch '^\d+$') { return $false }
  $proc = Get-Process -Id ([int]$pidText) -ErrorAction SilentlyContinue
  if ($proc -and $proc.Name -like 'dart*') {
    Write-Host "Stopping stale Flutter web process on port $Port (PID $pidText)..." -ForegroundColor Yellow
    Stop-Process -Id ([int]$pidText) -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    return $true
  }
  return $false
}

if (Test-TcpPortInUse -Port $WebPort) {
  Stop-StaleDartOnPort -Port $WebPort | Out-Null
}

if (Test-TcpPortInUse -Port $WebPort) {
  for ($p = 8082; $p -le 8090; $p++) {
    if (-not (Test-TcpPortInUse -Port $p)) {
      Write-Host "Port $WebPort is busy; using $p instead." -ForegroundColor Yellow
      $WebPort = $p
      break
    }
  }
}

Write-Host "NEET Prep Admin Web - local dev" -ForegroundColor Cyan
Write-Host "Folder: $(Get-Location)" -ForegroundColor DarkGray
Write-Host "Flutter: $script:FlutterSdkRoot" -ForegroundColor DarkGray
Write-Host "Web port: $WebPort" -ForegroundColor DarkGray

Invoke-Flutter -Command pub,get
Write-Host ""
Write-Host "Starting on Chrome. First compile may take 1-2 minutes." -ForegroundColor Green
Write-Host "For local sign-in add localhost and 127.0.0.1 in Firebase Auth authorized domains." -ForegroundColor DarkGray
Write-Host ""

Invoke-Flutter -Command run,-d,chrome,--web-port,$WebPort
