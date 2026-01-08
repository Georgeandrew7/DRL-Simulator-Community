@echo off
REM DRL Simulator Self-Hosted Multiplayer Setup for Windows
REM This script sets up everything needed for offline/LAN play

echo ===============================================
echo        DRL Simulator Self-Hosted Setup
echo ===============================================
echo.

REM Check for admin rights
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: This script requires Administrator privileges.
    echo Please right-click and select "Run as administrator"
    pause
    exit /b 1
)

REM Set paths
set "GAME_DIR=%ProgramFiles(x86)%\Steam\steamapps\common\DRL Simulator"
set "HOSTS_FILE=%SystemRoot%\System32\drivers\etc\hosts"
set "HOSTS_ENTRY=127.0.0.1 api.drlgame.com"

REM Check if game exists
if not exist "%GAME_DIR%\DRL Simulator.exe" (
    echo ERROR: DRL Simulator not found at default location.
    echo Please edit this script to set the correct GAME_DIR path.
    echo.
    echo Looking for: %GAME_DIR%
    pause
    exit /b 1
)

echo [OK] Found DRL Simulator at: %GAME_DIR%

REM Check hosts file
findstr /C:"api.drlgame.com" "%HOSTS_FILE%" >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] /etc/hosts already contains api.drlgame.com entry
) else (
    echo [*] Adding api.drlgame.com to hosts file...
    echo %HOSTS_ENTRY% >> "%HOSTS_FILE%"
    echo [OK] Added: %HOSTS_ENTRY%
)

REM Check if Python is available
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo ERROR: Python is not installed or not in PATH.
    echo Please install Python 3.8+ from https://python.org
    pause
    exit /b 1
)

echo [OK] Python is available

REM Kill any existing process on port 80
echo.
echo [*] Checking port 80...
netstat -ano | findstr ":80 " | findstr "LISTENING" >nul 2>&1
if %errorlevel% equ 0 (
    echo [!] Port 80 is in use. You may need to stop the conflicting service.
)

REM Start the mock backend server
echo.
echo [*] Starting mock DRL backend server...
echo.

cd /d "%~dp0..\common\server"
start "DRL Mock Server" python mock_drl_backend.py --dual

echo.
echo ===============================================
echo.
echo The mock backend server is now running!
echo.
echo Next steps:
echo   1. Launch DRL Simulator through Steam
echo   2. The game should now get past the login screen
echo.
echo Close the "DRL Mock Server" window to stop the server.
echo.
pause
