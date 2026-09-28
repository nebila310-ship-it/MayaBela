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

REM Same live Supabase project as https://mayabela.pages.dev
set "SUPABASE_URL=https://hwkiihonthueadbhcvfi.supabase.co"
set "SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3a2lpaG9udGh1ZWFkYmhjdmZpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUxNjI4MzcsImV4cCI6MjEwMDczODgzN30.eD6RjusSvYm-3vm4QDiiRtEAihmFvznf5ZkeumJDGdY"
if exist ".env.local" (
  for /f "usebackq tokens=1,* delims==" %%A in (".env.local") do (
    if /i "%%A"=="SUPABASE_URL" set "SUPABASE_URL=%%B"
    if /i "%%A"=="SUPABASE_ANON_KEY" set "SUPABASE_ANON_KEY=%%B"
  )
)

echo Using SUPABASE_URL from APK build (same cloud as the web app)
set "DART_DEFINES=--dart-define=SUPABASE_CONFIGURED=true --dart-define=SUPABASE_URL=%SUPABASE_URL% --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY% --dart-define=MAYABELA_VERSION=1.0.6+7"

echo.
echo === flutter build apk --release ===
echo Android is pinned to AGP 8.12 / Gradle 8.14.3 (see android\settings.gradle.kts).
echo Do not pass empty SUPABASE dart-defines — that wipes compiled login defaults.
echo If assembleRelease fails, use web: https://mayabela.pages.dev
echo See docs\SELL_PACKAGE.md section 4.
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
