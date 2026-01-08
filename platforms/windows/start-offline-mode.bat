@echo off
setlocal EnableDelayedExpansion
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

REM Auto-detect game location
call :FindGame
if not defined GAME_DIR (
    echo ERROR: Could not find DRL Simulator installation.
    pause
    exit /b 1
)

set "HOSTS_FILE=%SystemRoot%\System32\drivers\etc\hosts"
set "HOSTS_ENTRY=127.0.0.1 api.drlgame.com"

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

REM Find the server directory (could be in various locations)
set "SERVER_DIR="

REM Check installed location first (installer puts it in common\server)
if exist "%~dp0common\server\mock_drl_backend.py" (
    set "SERVER_DIR=%~dp0common\server"
    goto :StartServer
)

REM Check relative to repo structure (for development)
if exist "%~dp0..\common\server\mock_drl_backend.py" (
    set "SERVER_DIR=%~dp0..\common\server"
    goto :StartServer
)

REM Check if there's a server subfolder directly
if exist "%~dp0server\mock_drl_backend.py" (
    set "SERVER_DIR=%~dp0server"
    goto :StartServer
)

REM Check Program Files install
if exist "%ProgramFiles%\DRL-Community\common\server\mock_drl_backend.py" (
    set "SERVER_DIR=%ProgramFiles%\DRL-Community\common\server"
    goto :StartServer
)

REM Not found
echo ERROR: Could not find mock_drl_backend.py
echo.
echo Please ensure the server files are installed correctly.
echo Looking in:
echo   - %~dp0common\server\
echo   - %~dp0..\common\server\
echo   - %ProgramFiles%\DRL-Community\common\server\
pause
exit /b 1

:StartServer
echo [OK] Server directory: %SERVER_DIR%
cd /d "%SERVER_DIR%"

REM Check if Python dependencies are installed
python -c "import aiohttp" 2>nul
if %errorlevel% neq 0 (
    echo [*] Installing Python dependencies...
    python -m pip install aiohttp requests --quiet
)

start "DRL Mock Server" cmd /k "python mock_drl_backend.py --dual"

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
endlocal
exit /b 0

:FindGame
REM Auto-detect DRL Simulator installation
set "STEAM_PATHS=%ProgramFiles(x86)%\Steam %ProgramFiles%\Steam C:\Steam D:\Steam E:\Steam F:\Steam"
set "STEAM_PATHS=%STEAM_PATHS% D:\SteamLibrary E:\SteamLibrary F:\SteamLibrary"
set "STEAM_PATHS=%STEAM_PATHS% D:\Games\Steam E:\Games\Steam D:\Games\SteamLibrary E:\Games\SteamLibrary"

for %%P in (%STEAM_PATHS%) do (
    if exist "%%P\steamapps\common\DRL Simulator\DRL Simulator.exe" (
        set "GAME_DIR=%%P\steamapps\common\DRL Simulator"
        exit /b 0
    )
)

REM Try registry
for /f "tokens=2*" %%a in ('reg query "HKCU\Software\Valve\Steam" /v SteamPath 2^>nul') do set "STEAM_PATH=%%b"
if defined STEAM_PATH (
    set "STEAM_PATH=!STEAM_PATH:/=\!"
    if exist "!STEAM_PATH!\steamapps\common\DRL Simulator\DRL Simulator.exe" (
        set "GAME_DIR=!STEAM_PATH!\steamapps\common\DRL Simulator"
        exit /b 0
    )
)

REM Prompt user
echo DRL Simulator not found automatically.
echo Please enter the full path to your DRL Simulator folder:
set /p "GAME_DIR=Path: "
if exist "%GAME_DIR%\DRL Simulator.exe" exit /b 0
set "GAME_DIR="
exit /b 1
