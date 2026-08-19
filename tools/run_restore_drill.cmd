@echo off
REM Staging-only restore drill + crash-report ping. Loads .env.staging.
cd /d "%~dp0.."
if exist ".env.staging" (
  for /f "usebackq eol=# tokens=1,* delims==" %%A in (".env.staging") do (
    if not "%%A"=="" set "%%A=%%B"
  )
)
node tools\restore_drill_staging.mjs
if errorlevel 1 exit /b %ERRORLEVEL%
node tools\test_crash_report.mjs
exit /b %ERRORLEVEL%
