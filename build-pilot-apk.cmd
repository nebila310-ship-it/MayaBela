@echo off
REM Build a release Android APK for school pilots (sideload / WhatsApp).
REM Agent / CI: set MAYABELA_NOPAUSE=1 to skip "Press any key".

cd /d "%~dp0"

echo.
echo === MayaBela pilot APK ===
echo Package: com.mayabela.app
echo.

where flutter >nul 2>&1
if errorlevel 1 (
  echo ERROR: flutter not on PATH.
  if not defined MAYABELA_NOPAUSE pause
  exit /b 1
)

REM Prefer .env.local Supabase defines when present (same pattern as web deploy).
set "DART_DEFINES="
if exist ".env.local" (
  for /f "usebackq tokens=1,* delims==" %%A in (".env.local") do (
    if /i "%%A"=="SUPABASE_URL" set "SUPABASE_URL=%%B"
    if /i "%%A"=="SUPABASE_ANON_KEY" set "SUPABASE_ANON_KEY=%%B"
  )
)

if defined SUPABASE_URL if defined SUPABASE_ANON_KEY (
  echo Using SUPABASE_URL from environment / .env.local
  set "DART_DEFINES=--dart-define=SUPABASE_URL=%SUPABASE_URL% --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY% --dart-define=SUPABASE_CONFIGURED=true"
) else (
  echo Using compiled-in supabase_options.dart fallbacks
)

echo.
echo === flutter build apk --release ===
echo NOTE: If this fails on Flutter 3.44 + AGP 9 (afterEvaluate),
echo       pilot the school on https://mayabela.pages.dev instead.
echo       See docs\SELL_PACKAGE.md section 4.
echo.
REM Prefer real user Gradle cache (Cursor may inject a sandbox GRADLE_USER_HOME).
if not defined GRADLE_USER_HOME set "GRADLE_USER_HOME=%USERPROFILE%\.gradle"
REM Arm64-only keeps pilot APK smaller/faster; nearly all modern phones are arm64.
call flutter build apk --release --target-platform android-arm64 %DART_DEFINES%
if errorlevel 1 (
  echo ERROR: APK build failed.
  echo Use web pilot: https://mayabela.pages.dev
  if not defined MAYABELA_NOPAUSE pause
  exit /b 1
)

set "APK=build\app\outputs\flutter-apk\app-release.apk"
if not exist "%APK%" (
  echo ERROR: Expected APK missing: %APK%
  if not defined MAYABELA_NOPAUSE pause
  exit /b 1
)

echo.
echo ============================================================
echo  Pilot APK ready:
echo    %CD%\%APK%
echo  Share with the school for sideload install.
echo  Web ERP remains: https://mayabela.pages.dev
echo ============================================================
echo.

if not defined MAYABELA_NOPAUSE pause
exit /b 0
