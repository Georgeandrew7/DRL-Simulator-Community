@echo off
:: DRL Community - Windows Installer Build Script
:: Requires Inno Setup 6.x to be installed

title Building DRL Community Installer
color 0B

echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║        DRL Community - Windows Installer Builder             ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.

:: Check for Inno Setup
set ISCC=
if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" (
    set "ISCC=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
) else if exist "C:\Program Files\Inno Setup 6\ISCC.exe" (
    set "ISCC=C:\Program Files\Inno Setup 6\ISCC.exe"
) else (
    echo [ERROR] Inno Setup 6 not found!
    echo.
    echo Please install Inno Setup 6 from:
    echo https://jrsoftware.org/isinfo.php
    echo.
    pause
    exit /b 1
)

echo [INFO] Found Inno Setup: %ISCC%
echo.

:: Check for icon file
if not exist "installer\icon.ico" (
    echo [WARN] Icon file not found at installer\icon.ico
    echo [INFO] Creating placeholder icon...
    
    :: Create a simple placeholder (in production, use a real icon)
    echo. > installer\icon.ico
    echo [WARN] Please replace installer\icon.ico with a real icon file!
    echo.
)

:: Create output directory
if not exist "installer\output" mkdir installer\output

:: Build the installer
echo [INFO] Compiling installer...
echo.

"%ISCC%" DRL-Community.iss

if %errorLevel% neq 0 (
    echo.
    echo [ERROR] Build failed with error code %errorLevel%
    pause
    exit /b %errorLevel%
)

echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║                    Build Successful!                         ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.
echo  Installer created at:
echo  installer\output\DRL-Community-Setup-1.0.0.exe
echo.

:: Ask to open output folder
set /p OPEN="Open output folder? (y/n) "
if /i "%OPEN%"=="y" explorer installer\output

pause
