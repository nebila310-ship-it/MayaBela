@echo off
REM Deploy the INSA Stage 1 edge functions to the STAGING Supabase project.
REM Reads STAGING_SUPABASE_URL from .env.staging. Refuses production.
REM Extra arguments are passed to every deploy (e.g. --use-api without Docker).
setlocal EnableExtensions
cd /d "%~dp0.."

if not exist ".env.staging" (
  echo Missing .env.staging
  exit /b 2
)

for /f "usebackq eol=# tokens=1,* delims==" %%A in (".env.staging") do (
  if /I "%%A"=="STAGING_SUPABASE_URL" set "STAGING_URL=%%B"
)

set "REF=bfpcpgxekzdqxuxvajuy"
echo %STAGING_URL% | findstr /I "%REF%" >nul
if errorlevel 1 (
  echo STAGING_SUPABASE_URL in .env.staging is not the staging project %REF%. Stopping.
  exit /b 2
)
echo %STAGING_URL% | findstr /I "hwkiihonthueadbhcvfi" >nul
if not errorlevel 1 (
  echo Refusing: production project.
  exit /b 2
)

for %%F in (
  platform-owner-pin
  platform-create-school
  platform-update-school
  platform-delete-school
  platform-list-schools
  platform-mail-config
  platform-upload-logo
  platform-upload-mark
  school-login
  school-invite-parent
  school-verify-student
) do (
  echo.
  echo === Deploying %%F to staging %REF% ===
  call npx --yes supabase functions deploy %%F --project-ref %REF% --no-verify-jwt %*
  if errorlevel 1 (
    echo Deploy of %%F failed. Stopping.
    exit /b 1
  )
)

echo.
echo All Stage 1 functions deployed to staging %REF%.
exit /b 0
