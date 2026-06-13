@echo off
setlocal EnableExtensions
cd /d "%~dp0"

title NEET Prep Admin - Verify live deploy

echo.
echo Comparing local build\web\main.dart.js with https://neetappadmin.satlas.org/
echo Project: %CD%
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tool\verify_live_deploy.ps1"
set EXITCODE=%ERRORLEVEL%

echo.
if %EXITCODE%==0 (
  echo [OK] Live site matches your local build. Hard-refresh the admin site if needed.
) else (
  echo [FAIL] Live site does NOT match. Upload main.dart.js from build\web\ then run this again.
)
echo.
pause
endlocal
exit /b %EXITCODE%
