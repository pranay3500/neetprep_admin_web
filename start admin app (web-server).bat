@echo off
REM Optional: web-server only (no auto browser). After "is being served", open:
REM   http://127.0.0.1:8081
REM Keep this window open while using the app. Do not press Ctrl+C unless you want to stop.
cd /d "%~dp0"
echo Starting NEET Prep Admin Web App on http://127.0.0.1:8081 ...
echo Opening browser in ~50 seconds after compile...
start "" cmd /c "timeout /t 50 /nobreak >nul && start http://127.0.0.1:8081"

for /f "usebackq delims=" %%F in ("%~dp0tool\flutter_sdk.path") do set "FLUTTER_SDK=%%F"
call "%FLUTTER_SDK%\bin\flutter.bat" pub get
call "%FLUTTER_SDK%\bin\flutter.bat" run -d web-server --web-hostname 127.0.0.1 --web-port 8081
