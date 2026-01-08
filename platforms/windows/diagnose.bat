@echo off
:: DRL Simulator Community - Windows Diagnostic Tool Launcher
:: Runs the PowerShell diagnostic script

title DRL Community Diagnostics
color 0B

echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║       DRL Simulator Community - Diagnostic Tool              ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.

:: Check for admin rights
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [WARN] Not running as Administrator
    echo [INFO] Some diagnostics may be incomplete
    echo.
    echo For full diagnostics, right-click and select "Run as administrator"
    echo.
)

:: Parse arguments
set ARGS=
if "%1"=="--verbose" set ARGS=-Verbose
if "%1"=="-v" set ARGS=-Verbose
if "%1"=="--export" set ARGS=-ExportReport
if "%1"=="-e" set ARGS=-ExportReport
if "%1"=="--fix" set ARGS=-Fix

:: Run the PowerShell diagnostic
powershell.exe -ExecutionPolicy Bypass -File "%~dp0Diagnose-DRLCommunity.ps1" %ARGS%

if %errorLevel% neq 0 (
    echo.
    echo [ERROR] Diagnostics failed with error code %errorLevel%
    pause
)
