# DRL Simulator Self-Hosted Multiplayer Setup for Windows (PowerShell)
# Run as Administrator: Right-click PowerShell -> Run as Administrator

param(
    [string]$GameDir = "${env:ProgramFiles(x86)}\Steam\steamapps\common\DRL Simulator",
    [switch]$SkipHostsCheck
)

$ErrorActionPreference = "Stop"

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "       DRL Simulator Self-Hosted Setup        " -ForegroundColor Cyan  
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# Check for admin rights
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This script requires Administrator privileges." -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again."
    exit 1
}

# Paths
$HostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
$HostsEntry = "127.0.0.1 api.drlgame.com"

# Check if game exists
if (-not (Test-Path "$GameDir\DRL Simulator.exe")) {
    Write-Host "ERROR: DRL Simulator not found at: $GameDir" -ForegroundColor Red
    Write-Host ""
    Write-Host "Try specifying the path:"
    Write-Host "  .\start-offline-mode.ps1 -GameDir 'D:\Games\DRL Simulator'"
    exit 1
}

Write-Host "[OK] Found DRL Simulator at: $GameDir" -ForegroundColor Green

# Check/update hosts file
if (-not $SkipHostsCheck) {
    $hostsContent = Get-Content $HostsFile -Raw
    if ($hostsContent -match "api\.drlgame\.com") {
        Write-Host "[OK] hosts file already contains api.drlgame.com entry" -ForegroundColor Green
    } else {
        Write-Host "[*] Adding api.drlgame.com to hosts file..." -ForegroundColor Yellow
        Add-Content -Path $HostsFile -Value "`n$HostsEntry"
        Write-Host "[OK] Added: $HostsEntry" -ForegroundColor Green
    }
}

# Check Python
try {
    $pythonVersion = python --version 2>&1
    Write-Host "[OK] Python is available: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Python is not installed or not in PATH." -ForegroundColor Red
    Write-Host "Please install Python 3.8+ from https://python.org"
    exit 1
}

# Check port 80
$port80 = Get-NetTCPConnection -LocalPort 80 -State Listen -ErrorAction SilentlyContinue
if ($port80) {
    Write-Host "[!] Port 80 is in use by PID: $($port80.OwningProcess)" -ForegroundColor Yellow
    Write-Host "    You may need to stop the conflicting service (often IIS or Skype)"
}

# Start the mock server
Write-Host ""
Write-Host "[*] Starting mock DRL backend server..." -ForegroundColor Yellow
Write-Host ""

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$serverScript = Join-Path $scriptDir "..\common\server\mock_drl_backend.py"

# Set environment variable for game directory
$env:DRL_GAME_DIR = $GameDir

Start-Process -FilePath "python" -ArgumentList "$serverScript --dual" -NoNewWindow

Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "The mock backend server is now running!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Launch DRL Simulator through Steam"
Write-Host "  2. The game should now get past the login screen"
Write-Host ""
Write-Host "Press Ctrl+C to stop the server."
Write-Host ""

# Keep running
try {
    while ($true) { Start-Sleep -Seconds 60 }
} finally {
    Write-Host "Shutting down..."
}
