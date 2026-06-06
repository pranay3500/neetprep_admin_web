@echo off
REM Local admin dev — opens Chrome (do not use raw web-server; it won't open a browser).
REM If you see "Terminate batch job (Y/N)?" you pressed Ctrl+C or closed the window.
REM   Press Y to stop, or N to leave the server running and open http://127.0.0.1:8081 manually.
cd /d "%~dp0"
echo Starting NEET Prep Admin Web App...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tool\run_admin_web.ps1"
if errorlevel 1 (
  echo.
  echo Failed to start. Try: powershell -File tool\run_admin_web.ps1
  pause
)
