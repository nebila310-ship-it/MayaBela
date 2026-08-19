@echo off
REM Build Flutter web against the staging Supabase project and deploy to a
REM separate Cloudflare Pages project. Does NOT overwrite mayabela.pages.dev.
setlocal EnableExtensions
cd /d "%~dp0.."

if not exist ".env.staging" (
  echo Missing .env.staging
  exit /b 2
)

for /f "usebackq eol=# tokens=1,* delims==" %%A in (".env.staging") do (
  if /I "%%A"=="STAGING_SUPABASE_URL" set "SUPABASE_URL=%%B"
  if /I "%%A"=="STAGING_ANON_KEY" set "SUPABASE_ANON_KEY=%%B"
)

echo %SUPABASE_URL% | findstr /I "hwkiihonthueadbhcvfi" >nul
if not errorlevel 1 (
  echo Refusing to deploy staging web with a production Supabase URL.
  exit /b 2
)

echo Building staging web for %SUPABASE_URL%
call flutter build web --release --dart-define=SUPABASE_CONFIGURED=true --dart-define=SUPABASE_URL=%SUPABASE_URL% --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%
if errorlevel 1 exit /b 1

if exist "web\_redirects" copy /Y "web\_redirects" "build\web\_redirects" >nul
if exist "web\_headers" copy /Y "web\_headers" "build\web\_headers" >nul

echo Deploying to Cloudflare Pages project mayabela-staging
call npx --yes wrangler@4 pages project create mayabela-staging --production-branch=main
call npx --yes wrangler@4 pages deploy build/web --project-name=mayabela-staging --commit-dirty=true
exit /b %ERRORLEVEL%
