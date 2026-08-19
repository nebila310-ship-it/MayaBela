@echo off
REM Firebase login — use this FIRST (keep this window open).
set "NODE_DIR=C:\Program Files\nodejs"
set "NPM_DIR=%APPDATA%\npm"
set "PATH=%NODE_DIR%;%NPM_DIR%;%PATH%"

if not exist "%NODE_DIR%\node.exe" (
  echo ERROR: Node.js not found. Install from https://nodejs.org/
  pause
  exit /b 1
)

set "FIREBASE_CMD=%NPM_DIR%\firebase.cmd"

echo.
echo ============================================================
echo  FIREBASE LOGIN
echo ============================================================
echo.
echo  1. A URL will appear below in a moment.
echo  2. COPY that URL and paste it into Chrome/Edge.
echo  3. Sign in with the Google account for Firebase.
echo  4. COPY the code from the browser.
echo  5. PASTE the code back into this window and press Enter.
echo.
echo  (Browser may not open automatically — that is normal.)
echo ============================================================
echo.

"%FIREBASE_CMD%" login --no-localhost

if errorlevel 1 (
  echo.
  echo Login failed. Try again or use Firebase Console to paste rules manually.
  pause
  exit /b 1
)

echo.
echo Login OK. You can now run deploy-firebase.cmd
pause
