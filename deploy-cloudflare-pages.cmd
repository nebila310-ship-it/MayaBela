@echo off
REM Build Flutter web release and deploy to Cloudflare Pages.
REM First time: create a free Cloudflare account, then this script will open login.
REM Agent / CI: set MAYABELA_NOPAUSE=1 to skip "Press any key".

set "NODE_DIR=C:\Program Files\nodejs"
set "NPM_DIR=%APPDATA%\npm"
set "PATH=%NODE_DIR%;%NPM_DIR%;%PATH%"

cd /d "%~dp0"

if not exist "%NODE_DIR%\node.exe" (
  echo ERROR: Node.js not found at %NODE_DIR%
  echo Install from https://nodejs.org then run again.
  if not defined MAYABELA_NOPAUSE pause
  exit /b 1
)

set "PROJECT_NAME=mayabela"
if exist ".env.local" (
  for /f "usebackq tokens=1,* delims==" %%A in (".env.local") do (
    if /i "%%A"=="CLOUDFLARE_PAGES_PROJECT" set "PROJECT_NAME=%%B"
  )
)

echo.
echo === 1/3 Build web release ===
call "%~dp0deploy-web-release.cmd"
if errorlevel 1 (
  if not defined MAYABELA_NOPAUSE pause
  exit /b 1
)

if not exist "build\web\index.html" (
  echo ERROR: build\web\index.html missing after build.
  if not defined MAYABELA_NOPAUSE pause
  exit /b 1
)

REM Ensure SPA + security files are present (also copied from web/ by Flutter).
copy /Y "web\_redirects" "build\web\_redirects" >nul
copy /Y "web\_headers" "build\web\_headers" >nul
rmdir /S /Q "build\web\fenote-raey-academy" 2>nul
xcopy /E /I /Y "web\fenote-raey-academy" "build\web\fenote-raey-academy" >nul

echo.
echo === 2/3 Cloudflare auth ===
echo If a browser opens, sign in to Cloudflare and approve Wrangler.
echo.
call npx --yes wrangler@4 whoami
if errorlevel 1 (
  echo.
  echo Not logged in. Opening Cloudflare login...
  call npx --yes wrangler@4 login
  if errorlevel 1 (
    echo Login failed.
    if not defined MAYABELA_NOPAUSE pause
    exit /b 1
  )
)

echo.
echo === 3/3 Deploy to Pages project "%PROJECT_NAME%" ===
call npx --yes wrangler@4 pages deploy build/web --project-name=%PROJECT_NAME% --commit-dirty=true
if errorlevel 1 (
  echo.
  echo Deploy failed.
  echo Tip: create the project once in the Cloudflare dashboard:
  echo   Workers ^& Pages -^> Create -^> Pages -^> Direct Upload
  echo   Project name: %PROJECT_NAME%
  echo Or set CLOUDFLARE_PAGES_PROJECT=your-name in .env.local
  if not defined MAYABELA_NOPAUSE pause
  exit /b 1
)

echo.
echo ============================================================
echo  Live on Cloudflare Pages:
echo    https://mayabela.pages.dev
echo  Data still comes from Supabase (shared with mobile).
echo ============================================================
echo.
if not defined MAYABELA_NOPAUSE pause
exit /b 0
