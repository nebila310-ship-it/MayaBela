@echo off
REM Staging-only RLS isolation. Loads .env.staging. Refuses production.
cd /d "%~dp0.."
if exist ".env.staging" (
  for /f "usebackq eol=# tokens=1,* delims==" %%A in (".env.staging") do (
    if not "%%A"=="" set "%%A=%%B"
  )
)
node tools\test_rls_isolation.mjs
exit /b %ERRORLEVEL%
