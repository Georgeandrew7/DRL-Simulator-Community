@echo off
REM Install BepInEx for DRL Simulator on Windows
REM Downloads and extracts BepInEx to the game directory

echo ===============================================
echo      BepInEx Installer for DRL Simulator
echo ===============================================
echo.

set "GAME_DIR=%ProgramFiles(x86)%\Steam\steamapps\common\DRL Simulator"
set "BEPINEX_VERSION=5.4.23.2"
set "BEPINEX_URL=https://github.com/BepInEx/BepInEx/releases/download/v%BEPINEX_VERSION%/BepInEx_win_x64_%BEPINEX_VERSION%.zip"
set "TEMP_ZIP=%TEMP%\bepinex.zip"

REM Check if game exists
if not exist "%GAME_DIR%\DRL Simulator.exe" (
    echo ERROR: DRL Simulator not found at default location.
    echo Please edit GAME_DIR in this script.
    pause
    exit /b 1
)

echo [OK] Found game at: %GAME_DIR%

REM Check if BepInEx already installed
if exist "%GAME_DIR%\BepInEx" (
    echo [OK] BepInEx is already installed!
    echo.
    goto :plugins
)

REM Check for curl or PowerShell for download
echo [*] Downloading BepInEx %BEPINEX_VERSION%...
powershell -Command "Invoke-WebRequest -Uri '%BEPINEX_URL%' -OutFile '%TEMP_ZIP%'"

if not exist "%TEMP_ZIP%" (
    echo ERROR: Failed to download BepInEx.
    echo Please download manually from: %BEPINEX_URL%
    pause
    exit /b 1
)

echo [*] Extracting BepInEx...
powershell -Command "Expand-Archive -Path '%TEMP_ZIP%' -DestinationPath '%GAME_DIR%' -Force"

del "%TEMP_ZIP%"

echo [OK] BepInEx installed successfully!
echo.

:plugins
REM Create plugins directory
if not exist "%GAME_DIR%\BepInEx\plugins" mkdir "%GAME_DIR%\BepInEx\plugins"

REM Copy plugins if available
set "PLUGIN_SRC=%~dp0..\common\plugins"
if exist "%PLUGIN_SRC%\*.dll" (
    echo [*] Copying plugins...
    copy "%PLUGIN_SRC%\*.dll" "%GAME_DIR%\BepInEx\plugins\" >nul
    echo [OK] Plugins copied!
)

echo.
echo ===============================================
echo              Installation Complete!
echo ===============================================
echo.
echo BepInEx has been installed to:
echo   %GAME_DIR%
echo.
echo To compile the C# plugins, you need:
echo   - Visual Studio or .NET SDK
echo   - Open plugins/*.cs and build
echo.
echo After compiling, copy the DLL files to:
echo   %GAME_DIR%\BepInEx\plugins\
echo.
pause
