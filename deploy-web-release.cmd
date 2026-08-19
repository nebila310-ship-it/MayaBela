@echo off
REM Build Flutter web release with the real Supabase URL + anon key.
REM Reads from .env.local if present; otherwise uses defaults in lib/supabase_options.dart.

set "NODE_DIR=C:\Program Files\nodejs"
set "NPM_DIR=%APPDATA%\npm"
set "PATH=%NODE_DIR%;%NPM_DIR%;%PATH%"

cd /d "%~dp0"

set "SUPABASE_URL=https://hwkiihonthueadbhcvfi.supabase.co"
set "SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3a2lpaG9udGh1ZWFkYmhjdmZpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUxNjI4MzcsImV4cCI6MjEwMDczODgzN30.eD6RjusSvYm-3vm4QDiiRtEAihmFvznf5ZkeumJDGdY"

if exist ".env.local" (
  for /f "usebackq tokens=1,* delims==" %%A in (".env.local") do (
    if /i "%%A"=="SUPABASE_URL" set "SUPABASE_URL=%%B"
    if /i "%%A"=="SUPABASE_ANON_KEY" set "SUPABASE_ANON_KEY=%%B"
  )
)

echo Building web release for:
echo   SUPABASE_URL=%SUPABASE_URL%
echo.

flutter build web --release ^
  --dart-define=SUPABASE_CONFIGURED=true ^
  --dart-define=SUPABASE_URL=%SUPABASE_URL% ^
  --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%

if errorlevel 1 (
  echo Build failed.
  exit /b 1
)

echo.
echo Build ready in build\web
echo Deploy with: deploy-cloudflare-pages.cmd
echo   (or: firebase deploy --only hosting)
exit /b 0
