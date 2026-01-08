#Requires -RunAsAdministrator
<#
.SYNOPSIS
    DRL Simulator Community Server - Windows Installer

.DESCRIPTION
    One-click installer for DRL Simulator offline/community play.
    Installs the mock backend server, BepInEx, and bypass plugins.

.NOTES
    Version: 1.0.0
    Run this script as Administrator
#>

param(
    [string]$GamePath = "",
    [switch]$SkipBepInEx,
    [switch]$SkipPlugins,
    [switch]$Uninstall
)

# Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$Version = "1.0.0"
$InstallDir = "$env:LOCALAPPDATA\DRL-Community"
$ConfigFile = "$InstallDir\config.json"
$BepInExUrl = "https://github.com/BepInEx/BepInEx/releases/download/v5.4.23.2/BepInEx_x64_5.4.23.2.0.zip"

# Colors and formatting
function Write-Banner {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║      DRL Simulator Community Server - Windows Installer       ║" -ForegroundColor Cyan
    Write-Host "║                         v$Version                                ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] " -ForegroundColor Blue -NoNewline
    Write-Host $Message
}

function Write-Success {
    param([string]$Message)
    Write-Host "[✓] " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

function Find-GameDirectory {
    Write-Info "Looking for DRL Simulator installation..."
    
    $PossiblePaths = @(
        "C:\Program Files (x86)\Steam\steamapps\common\DRL Simulator",
        "C:\Program Files\Steam\steamapps\common\DRL Simulator",
        "D:\Steam\steamapps\common\DRL Simulator",
        "D:\SteamLibrary\steamapps\common\DRL Simulator",
        "E:\Steam\steamapps\common\DRL Simulator",
        "E:\SteamLibrary\steamapps\common\DRL Simulator"
    )
    
    foreach ($path in $PossiblePaths) {
        if (Test-Path "$path\DRL Simulator.exe") {
            Write-Success "Found DRL Simulator at: $path"
            return $path
        }
    }
    
    # Check Steam registry for library folders
    try {
        $SteamPath = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamPath
        if ($SteamPath) {
            $LibraryPath = "$SteamPath\steamapps\common\DRL Simulator"
            if (Test-Path "$LibraryPath\DRL Simulator.exe") {
                Write-Success "Found DRL Simulator at: $LibraryPath"
                return $LibraryPath
            }
        }
    } catch { }
    
    # Ask user
    Write-Warning "Could not auto-detect DRL Simulator installation."
    Write-Host ""
    $UserPath = Read-Host "Please enter the full path to your DRL Simulator folder"
    
    if (-not (Test-Path $UserPath)) {
        throw "Directory does not exist: $UserPath"
    }
    
    return $UserPath
}

function Install-Dependencies {
    Write-Info "Checking dependencies..."
    
    # Check for Python
    $PythonInstalled = $false
    try {
        $PythonVersion = python --version 2>&1
        if ($PythonVersion -match "Python 3") {
            Write-Success "Python found: $PythonVersion"
            $PythonInstalled = $true
        }
    } catch { }
    
    if (-not $PythonInstalled) {
        Write-Warning "Python 3 not found!"
        Write-Host ""
        Write-Host "Please install Python 3.8+ from: https://www.python.org/downloads/" -ForegroundColor Yellow
        Write-Host "Make sure to check 'Add Python to PATH' during installation!" -ForegroundColor Yellow
        Write-Host ""
        
        $OpenBrowser = Read-Host "Open Python download page? (y/n)"
        if ($OpenBrowser -eq 'y') {
            Start-Process "https://www.python.org/downloads/"
        }
        
        throw "Python 3 is required. Please install it and run this installer again."
    }
    
    # Install Python packages
    Write-Info "Installing Python packages..."
    try {
        pip install aiohttp requests --quiet 2>&1 | Out-Null
        Write-Success "Python packages installed"
    } catch {
        Write-Warning "Failed to install Python packages. You may need to install manually:"
        Write-Host "  pip install aiohttp requests" -ForegroundColor Yellow
    }
}

function New-InstallDirectory {
    Write-Info "Creating installation directory..."
    
    $Directories = @(
        $InstallDir,
        "$InstallDir\server",
        "$InstallDir\plugins",
        "$InstallDir\tools",
        "$InstallDir\logs",
        "$InstallDir\certs"
    )
    
    foreach ($dir in $Directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
    
    Write-Success "Created: $InstallDir"
}

function Copy-Files {
    Write-Info "Copying server files..."
    
    $ScriptDir = Split-Path -Parent $MyInvocation.ScriptName
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
    $CommonDir = "$RepoRoot\common"
    
    # Copy server files
    if (Test-Path "$CommonDir\server") {
        Copy-Item "$CommonDir\server\*.py" "$InstallDir\server\" -Force -ErrorAction SilentlyContinue
    }
    
    # Copy plugins
    if (Test-Path "$CommonDir\plugins") {
        Copy-Item "$CommonDir\plugins\*.cs" "$InstallDir\plugins\" -Force -ErrorAction SilentlyContinue
    }
    
    # Copy tools
    if (Test-Path "$CommonDir\tools") {
        Copy-Item "$CommonDir\tools\*.py" "$InstallDir\tools\" -Force -ErrorAction SilentlyContinue
    }
    
    Write-Success "Files copied"
}

function New-SSLCertificates {
    Write-Info "Generating SSL certificates..."
    
    $CertDir = "$InstallDir\certs"
    $CertFile = "$CertDir\server.crt"
    $KeyFile = "$CertDir\server.key"
    
    if ((Test-Path $CertFile) -and (Test-Path $KeyFile)) {
        Write-Warning "SSL certificates already exist. Skipping."
        return
    }
    
    # Check for OpenSSL
    $OpenSSLPath = $null
    $PossibleOpenSSL = @(
        "C:\Program Files\OpenSSL-Win64\bin\openssl.exe",
        "C:\Program Files (x86)\OpenSSL-Win32\bin\openssl.exe",
        "C:\OpenSSL-Win64\bin\openssl.exe"
    )
    
    foreach ($path in $PossibleOpenSSL) {
        if (Test-Path $path) {
            $OpenSSLPath = $path
            break
        }
    }
    
    # Also check if openssl is in PATH
    try {
        $null = Get-Command openssl -ErrorAction Stop
        $OpenSSLPath = "openssl"
    } catch { }
    
    if ($OpenSSLPath) {
        & $OpenSSLPath req -x509 -newkey rsa:4096 -keyout $KeyFile -out $CertFile `
            -days 365 -nodes -subj "/CN=api.drlgame.com/O=DRL Community/C=US" 2>&1 | Out-Null
        Write-Success "SSL certificates generated"
    } else {
        Write-Warning "OpenSSL not found. Using built-in certificate generation..."
        
        # Use PowerShell to create self-signed certificate
        $Cert = New-SelfSignedCertificate -DnsName "api.drlgame.com" `
            -CertStoreLocation "Cert:\CurrentUser\My" `
            -NotAfter (Get-Date).AddYears(1) `
            -KeyAlgorithm RSA -KeyLength 4096
        
        # Export certificate
        Export-Certificate -Cert $Cert -FilePath $CertFile -Type CERT | Out-Null
        
        # Export private key (PFX format for Windows)
        $PfxFile = "$CertDir\server.pfx"
        $SecurePassword = ConvertTo-SecureString -String "drlcommunity" -Force -AsPlainText
        Export-PfxCertificate -Cert $Cert -FilePath $PfxFile -Password $SecurePassword | Out-Null
        
        Write-Success "SSL certificates generated (PFX format)"
    }
}

function Install-BepInEx {
    param([string]$GameDir)
    
    Write-Info "Installing BepInEx..."
    
    $BepInExDir = "$GameDir\BepInEx"
    
    if (Test-Path $BepInExDir) {
        Write-Warning "BepInEx already installed. Skipping."
        return
    }
    
    Write-Info "Downloading BepInEx..."
    $TempZip = "$env:TEMP\bepinex.zip"
    
    try {
        Invoke-WebRequest -Uri $BepInExUrl -OutFile $TempZip -UseBasicParsing
        
        Write-Info "Extracting BepInEx..."
        Expand-Archive -Path $TempZip -DestinationPath $GameDir -Force
        
        Remove-Item $TempZip -Force -ErrorAction SilentlyContinue
        
        # Create plugins directory
        New-Item -ItemType Directory -Path "$BepInExDir\plugins" -Force | Out-Null
        
        Write-Success "BepInEx installed"
    } catch {
        Write-Warning "Failed to download BepInEx: $_"
        Write-Host "You can manually download from: $BepInExUrl" -ForegroundColor Yellow
    }
}

function Install-Plugins {
    param([string]$GameDir)
    
    Write-Info "Installing plugins..."
    
    $BepInExPlugins = "$GameDir\BepInEx\plugins"
    $SourcePlugins = "$InstallDir\plugins"
    
    if (-not (Test-Path $BepInExPlugins)) {
        Write-Warning "BepInEx plugins folder not found. Skipping."
        return
    }
    
    # Check for .NET SDK for compilation
    $HasDotNet = $false
    try {
        $DotNetVersion = dotnet --version 2>&1
        $HasDotNet = $true
    } catch { }
    
    if (-not $HasDotNet) {
        Write-Warning ".NET SDK not found. Cannot compile plugins."
        Write-Host "Install .NET SDK from: https://dotnet.microsoft.com/download" -ForegroundColor Yellow
        Write-Host "Or copy pre-compiled .dll files to: $BepInExPlugins" -ForegroundColor Yellow
        return
    }
    
    # For now, just copy the source files
    # Users will need Visual Studio or .NET SDK to compile
    Copy-Item "$SourcePlugins\*.cs" "$BepInExPlugins\" -Force -ErrorAction SilentlyContinue
    
    Write-Success "Plugin source files copied to BepInEx\plugins"
    Write-Host "  Note: Compile with Visual Studio or 'dotnet build'" -ForegroundColor Yellow
}

function Set-HostsFile {
    Write-Info "Configuring hosts file..."
    
    $HostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
    $HostsEntry = "127.0.0.1 api.drlgame.com"
    
    $HostsContent = Get-Content $HostsPath -Raw -ErrorAction SilentlyContinue
    
    if ($HostsContent -match "api\.drlgame\.com") {
        Write-Warning "hosts entry already exists"
        return
    }
    
    Write-Host ""
    Write-Host "Adding entry to hosts file to redirect api.drlgame.com..." -ForegroundColor Yellow
    
    try {
        Add-Content -Path $HostsPath -Value "`n$HostsEntry" -Force
        Write-Success "hosts entry added"
    } catch {
        Write-Warning "Failed to modify hosts file: $_"
        Write-Host "Please manually add this line to $HostsPath`:" -ForegroundColor Yellow
        Write-Host "  $HostsEntry" -ForegroundColor Green
    }
}

function Save-Config {
    param([string]$GameDir)
    
    Write-Info "Saving configuration..."
    
    $Config = @{
        Version = $Version
        GameDirectory = $GameDir
        InstallDirectory = $InstallDir
        InstalledDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $Config | ConvertTo-Json | Set-Content $ConfigFile
    
    Write-Success "Configuration saved"
}

function New-LauncherScripts {
    param([string]$GameDir)
    
    Write-Info "Creating launcher scripts..."
    
    # Start Server batch file
    $StartServerBat = @"
@echo off
title DRL Community Server
echo Starting DRL Community Server...
echo.
cd /d "$InstallDir\server"
python mock_drl_backend.py --dual --game-dir "$GameDir"
pause
"@
    Set-Content -Path "$InstallDir\Start-Server.bat" -Value $StartServerBat
    
    # Start Server PowerShell
    $StartServerPs1 = @"
# DRL Community Server Launcher
Write-Host "Starting DRL Community Server..." -ForegroundColor Cyan
Write-Host "Game Directory: $GameDir" -ForegroundColor Gray
Write-Host ""

Set-Location "$InstallDir\server"
python mock_drl_backend.py --dual --game-dir "$GameDir"
"@
    Set-Content -Path "$InstallDir\Start-Server.ps1" -Value $StartServerPs1
    
    # Desktop shortcut
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\DRL Community Server.lnk")
    $Shortcut.TargetPath = "$InstallDir\Start-Server.bat"
    $Shortcut.WorkingDirectory = $InstallDir
    $Shortcut.Description = "Start the DRL Simulator Community Server"
    $Shortcut.Save()
    
    Write-Success "Created desktop shortcut"
}

function Show-Summary {
    param([string]$GameDir)
    
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║              Installation Complete! 🎮                        ║" -ForegroundColor Green
    Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "Installation Summary:" -ForegroundColor Cyan
    Write-Host "  • Install Directory: $InstallDir"
    Write-Host "  • Game Directory: $GameDir"
    Write-Host "  • Desktop Shortcut: Created"
    Write-Host ""
    Write-Host "To start playing:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1. Double-click 'DRL Community Server' on your desktop"
    Write-Host "     OR run: " -NoNewline
    Write-Host "$InstallDir\Start-Server.bat" -ForegroundColor Green
    Write-Host ""
    Write-Host "  2. Launch DRL Simulator from Steam"
    Write-Host ""
    Write-Host "Note: Run the server as Administrator for ports 80/443" -ForegroundColor Yellow
    Write-Host ""
}

function Uninstall-DRLCommunity {
    Write-Banner
    Write-Info "Uninstalling DRL Community Server..."
    
    # Remove installation directory
    if (Test-Path $InstallDir) {
        Remove-Item -Path $InstallDir -Recurse -Force
        Write-Success "Removed: $InstallDir"
    }
    
    # Remove desktop shortcut
    $DesktopShortcut = "$env:USERPROFILE\Desktop\DRL Community Server.lnk"
    if (Test-Path $DesktopShortcut) {
        Remove-Item $DesktopShortcut -Force
        Write-Success "Removed desktop shortcut"
    }
    
    # Note about hosts file
    Write-Host ""
    Write-Warning "The hosts file entry was not removed."
    Write-Host "To fully uninstall, remove this line from C:\Windows\System32\drivers\etc\hosts:" -ForegroundColor Yellow
    Write-Host "  127.0.0.1 api.drlgame.com" -ForegroundColor Gray
    Write-Host ""
    
    Write-Success "Uninstallation complete"
}

# Main Installation
function Main {
    Write-Banner
    
    if ($Uninstall) {
        Uninstall-DRLCommunity
        return
    }
    
    Write-Host "This installer will:" -ForegroundColor Cyan
    Write-Host "  1. Install required dependencies (Python packages)"
    Write-Host "  2. Set up the mock backend server"
    Write-Host "  3. Install BepInEx mod framework"
    Write-Host "  4. Configure hosts file"
    Write-Host "  5. Create desktop shortcut"
    Write-Host ""
    
    $Continue = Read-Host "Continue with installation? (y/n)"
    if ($Continue -ne 'y') {
        Write-Info "Installation cancelled."
        return
    }
    
    # Find or use provided game path
    if ($GamePath -and (Test-Path $GamePath)) {
        $GameDir = $GamePath
    } else {
        $GameDir = Find-GameDirectory
    }
    
    Install-Dependencies
    New-InstallDirectory
    Copy-Files
    New-SSLCertificates
    
    if (-not $SkipBepInEx) {
        Install-BepInEx -GameDir $GameDir
    }
    
    if (-not $SkipPlugins) {
        Install-Plugins -GameDir $GameDir
    }
    
    Set-HostsFile
    Save-Config -GameDir $GameDir
    New-LauncherScripts -GameDir $GameDir
    Show-Summary -GameDir $GameDir
    
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Run installer
Main
