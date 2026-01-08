@echo off
REM DRL Photon Server Setup for Windows
REM Runs the embedded Photon Server for self-hosted multiplayer

echo ===============================================
echo     DRL Simulator Photon Server Setup
echo ===============================================
echo.

set "GAME_DIR=%ProgramFiles(x86)%\Steam\steamapps\common\DRL Simulator"
set "PHOTON_DIR=%GAME_DIR%\DRL Simulator_Data\StreamingAssets\PhotonServer\bin_Win64"

REM Check if Photon Server exists
if not exist "%PHOTON_DIR%\PhotonSocketServer.exe" (
    echo ERROR: Photon Server not found at:
    echo   %PHOTON_DIR%
    echo.
    echo Please verify your DRL Simulator installation.
    pause
    exit /b 1
)

echo [OK] Found Photon Server

echo.
echo Select an option:
echo   1) Start Photon Server (LoadBalancing mode)
echo   2) Start Photon Server (Debug mode)
echo   3) Open PhotonControl GUI
echo   4) Check port availability
echo   5) Exit
echo.
set /p choice="Choice [1-5]: "

if "%choice%"=="1" goto :start_normal
if "%choice%"=="2" goto :start_debug
if "%choice%"=="3" goto :photon_control
if "%choice%"=="4" goto :check_ports
if "%choice%"=="5" exit /b 0

echo Invalid option.
pause
exit /b 1

:start_normal
echo.
echo [*] Starting Photon Server...
cd /d "%PHOTON_DIR%"
start "Photon Server" PhotonSocketServer.exe /run LoadBalancing
echo.
echo Photon Server started!
echo.
echo Ports:
echo   UDP 5055 - Master Server
echo   UDP 5056 - Game Server
echo   TCP 4530, 4531 - TCP connections
echo.
pause
exit /b 0

:start_debug
echo.
echo [*] Starting Photon Server in debug mode...
cd /d "%PHOTON_DIR%"
PhotonSocketServer.exe /debug LoadBalancing
pause
exit /b 0

:photon_control
echo.
echo [*] Opening PhotonControl...
cd /d "%PHOTON_DIR%"
start PhotonControl.exe
exit /b 0

:check_ports
echo.
echo Checking Photon ports...
echo.
for %%p in (5055 5056 4530 4531 9090 9091) do (
    netstat -ano | findstr ":%%p " | findstr "LISTENING" >nul 2>&1
    if errorlevel 1 (
        echo   Port %%p: Available
    ) else (
        echo   Port %%p: IN USE
    )
)
echo.
pause
exit /b 0
