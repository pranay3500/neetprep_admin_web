@echo off
setlocal EnableExtensions
cd /d "%~dp0"

title NEET Prep Admin - Daily Web Build

echo.
echo ============================================================
echo   NEET Prep Admin Web - daily release build
echo   Project: %CD%
echo   Output:  build\web\
echo   Live:    https://neetappadmin.satlas.org/
echo   Started: %DATE% %TIME%
echo ============================================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tool\build_admin_web.ps1"
if errorlevel 1 (
  echo.
  echo [FAILED] Build did not complete. Fix errors above and run again.
  echo.
  pause
  exit /b 1
)

echo.
echo ============================================================
echo   [OK] Build finished
echo.
echo   Next: upload ALL files from:
echo         %CD%\build\web
echo   to your server document root, then hard-refresh the live site.
echo ============================================================
echo.

start "" explorer "%CD%\build\web"

pause
endlocal
