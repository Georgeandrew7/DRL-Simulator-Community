@echo off
:: DRL Simulator Community - Windows Installer
:: This batch file launches the PowerShell installer with admin rights

title DRL Community Server Installer

echo.
echo ============================================================
echo    DRL Simulator Community Server - Windows Installer
echo ============================================================
echo.
echo This will install the DRL Community Server components.
echo.
echo Checking for administrator rights...
echo.

:: Check for admin rights
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Administrator rights are required.
    echo.
    echo Requesting elevation...
    
    :: Create a VBS script to elevate
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "cmd.exe", "/c cd /d ""%~dp0"" && ""%~f0""", "", "runas", 1 >> "%temp%\getadmin.vbs"
    
    "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /b
)

echo Administrator rights confirmed.
echo.

:: Check if PowerShell is available
where powershell >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: PowerShell is not available on this system.
    echo Please install PowerShell or run the installer manually.
    pause
    exit /b 1
)

:: Get the directory of this script
set "SCRIPT_DIR=%~dp0"

:: Run the PowerShell installer
echo Starting PowerShell installer...
echo.

powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT_DIR%Install-DRLCommunity.ps1"

if %errorLevel% neq 0 (
    echo.
    echo Installation encountered an error.
    echo.
    pause
)
