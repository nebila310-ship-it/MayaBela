@echo off
REM Staging-only k6 load test. Refuses production project ref.
REM Usage:
REM   tools\run_k6_staging.cmd
REM   tools\run_k6_staging.cmd smoke
REM   tools\run_k6_staging.cmd full
REM   tools\run_k6_staging.cmd rung 50
REM Requires .env.staging (STAGING_SUPABASE_URL + STAGING_ANON_KEY) or those vars set.

setlocal EnableExtensions
cd /d "%~dp0.."

if exist ".env.staging" (
  for /f "usebackq eol=# tokens=1,* delims==" %%A in (".env.staging") do (
    if not "%%A"=="" set "%%A=%%B"
  )
)

if /I "%~1"=="smoke" set LOAD_PROFILE=smoke
if /I "%~1"=="full" set LOAD_PROFILE=full
if /I "%~1"=="session" set LOAD_PROFILE=session
if /I "%~1"=="rung" set LOAD_PROFILE=rung
if /I "%~1"=="rung" if not "%~2"=="" set LOAD_VUS=%~2
if /I "%LOAD_PROFILE%"=="rung" if "%LOAD_VUS%"=="" set LOAD_VUS=50
if "%LOAD_PROFILE%"=="" set LOAD_PROFILE=session

if "%STAGING_SUPABASE_URL%"=="" (
  echo TEST NOT EXECUTED
  echo Set STAGING_SUPABASE_URL and STAGING_ANON_KEY to a dedicated staging project.
  echo Production https://hwkiihonthueadbhcvfi.supabase.co is blocked in the script.
  exit /b 2
)

echo %STAGING_SUPABASE_URL% | findstr /I "hwkiihonthueadbhcvfi" >nul
if not errorlevel 1 (
  echo TEST NOT EXECUTED — URL looks like production.
  exit /b 2
)

if exist "%~dp0bin\k6.exe" set "PATH=%~dp0bin;%PATH%"
if exist "C:\Program Files\k6\k6.exe" set "PATH=C:\Program Files\k6;%PATH%"

where k6 >nul 2>&1
if errorlevel 1 (
  echo TEST NOT EXECUTED — k6 is not installed.
  echo Install from https://grafana.com/docs/k6/latest/set-up/install-k6/
  echo Or place k6.exe in tools\bin\
  exit /b 2
)

echo Running k6 LOAD_PROFILE=%LOAD_PROFILE% LOAD_VUS=%LOAD_VUS% against staging...
if not exist "load\k6" mkdir load\k6
k6 run --summary-export "load\k6\last_summary.json" load\k6\school_erp.js
exit /b %ERRORLEVEL%
