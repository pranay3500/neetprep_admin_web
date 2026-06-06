# Run NEET Prep admin web locally (opens Chrome).
# Prefer this over raw `flutter run -d web-server` — web-server does not open a browser.
# Usage: powershell -File run_admin.ps1
#        powershell -File run_admin.ps1 -WebPort 8082

param(
  [int]$WebPort = 8081
)

$ErrorActionPreference = "Stop"
& "$PSScriptRoot\tool\run_admin_web.ps1" -WebPort $WebPort
