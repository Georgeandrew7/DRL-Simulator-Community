@echo off
:: DRL Simulator Community - Windows Updater Launcher
:: Runs the PowerShell update script with proper execution policy

title DRL Community Updater
color 0B

echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║         DRL Simulator Community - Windows Updater            ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.

:: Check for admin rights
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [WARN] Not running as Administrator
    echo [INFO] Some features may require admin rights
    echo.
    echo Right-click this file and select "Run as administrator"
    echo for full functionality.
    echo.
    pause
)

:: Run the PowerShell updater
powershell.exe -ExecutionPolicy Bypass -File "%~dp0Update-DRLCommunity.ps1" %*

if %errorLevel% neq 0 (
    echo.
    echo [ERROR] Update failed with error code %errorLevel%
    pause
)
