@echo off
REM Deploy the INSA Stage 1 edge functions to the STAGING Supabase project.
REM Takes the project ref from STAGING_SUPABASE_URL in .env.staging,
REM asks you to retype it, and refuses production.
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

if not defined STAGING_URL (
  echo STAGING_SUPABASE_URL is missing from .env.staging. Stopping.
  exit /b 2
)
set "HOST=%STAGING_URL:https://=%"
for /f "tokens=1 delims=." %%R in ("%HOST%") do set "REF=%%R"
if not defined REF (
  echo Could not read the project ref from STAGING_SUPABASE_URL. Stopping.
  exit /b 2
)
if /I "%REF%"=="hwkiihonthueadbhcvfi" (
  echo Refusing: STAGING_SUPABASE_URL points at the production project.
  exit /b 2
)
echo Target staging project: %REF%
set /p "CONFIRM=Type the project ref again to continue: "
if /I not "%CONFIRM%"=="%REF%" (
  echo Ref did not match. Nothing deployed.
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
  school-register-parent
  school-upsert-account
  school-upsert-registry
  school-change-password
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
echo Also deployed school-register-parent, school-upsert-account and school-upsert-registry.
exit /b 0
