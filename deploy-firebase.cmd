@echo off
REM Deploy Firestore rules + indexes (+ functions if Blaze plan).
REM Run login-firebase.cmd first if not logged in.

set "NODE_DIR=C:\Program Files\nodejs"
set "NPM_DIR=%APPDATA%\npm"
set "PATH=%NODE_DIR%;%NPM_DIR%;%PATH%"

if not exist "%NODE_DIR%\node.exe" (
  echo ERROR: Node.js not found at %NODE_DIR%
  pause
  exit /b 1
)

set "FIREBASE_CMD=%NPM_DIR%\firebase.cmd"
cd /d "%~dp0"

echo Node: & node --version
echo Firebase: & "%FIREBASE_CMD%" --version
echo.

"%FIREBASE_CMD%" login:list 2>nul | findstr /i "@" >nul
if errorlevel 1 (
  echo NOT LOGGED IN.
  echo Double-click login-firebase.cmd first, then run this again.
  pause
  exit /b 1
)

echo Using project majo-e-school-bridge ...
"%FIREBASE_CMD%" use majo-e-school-bridge
if errorlevel 1 (
  echo Could not select project. Check login account has access.
  pause
  exit /b 1
)

echo.
echo Deploying Firestore rules and indexes ...
"%FIREBASE_CMD%" deploy --only firestore:rules,firestore:indexes
if errorlevel 1 (
  echo Deploy failed.
  pause
  exit /b 1
)

echo.
set /p DEPLOY_FN=Deploy Cloud Functions too? Requires Blaze plan (y/N):
if /i "%DEPLOY_FN%"=="y" (
  if exist functions\package.json (
    echo Installing function dependencies ...
    pushd functions
    call "%NODE_DIR%\npm.cmd" install
    popd
  )
  "%FIREBASE_CMD%" deploy --only functions
)

echo.
echo ============================================================
echo  DONE. Rules are live. Test messaging on two phones.
echo ============================================================
pause
