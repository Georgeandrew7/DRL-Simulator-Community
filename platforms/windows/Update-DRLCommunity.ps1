#Requires -Version 5.1
<#
.SYNOPSIS
    DRL Simulator Community - Windows Updater
.DESCRIPTION
    Updates the DRL Community installation to the latest version from GitHub.
    Backs up current installation before updating.
.NOTES
    Run as Administrator for full functionality.
#>

param(
    [string]$GameDir = "",
    [switch]$Force,
    [switch]$NoBackup,
    [switch]$CheckOnly
)

# Configuration
$REPO_URL = "https://github.com/Georgeandrew7/DRL-Simulator-Community"
$REPO_API = "https://api.github.com/repos/Georgeandrew7/DRL-Simulator-Community"
$VERSION_FILE = "VERSION.txt"

# Colors
function Write-Banner {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║         DRL Simulator Community - Windows Updater            ║" -ForegroundColor Cyan
    Write-Host "║                      Version 1.0.0                           ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
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

function Write-Step {
    param([int]$Num, [string]$Message)
    Write-Host ""
    Write-Host "[$Num] " -ForegroundColor Magenta -NoNewline
    Write-Host $Message -ForegroundColor White
    Write-Host ("-" * 50) -ForegroundColor DarkGray
}

function Get-CurrentVersion {
    $InstallDir = Get-InstallDirectory
    $VersionPath = Join-Path $InstallDir $VERSION_FILE
    
    if (Test-Path $VersionPath) {
        $version = Get-Content $VersionPath -Raw
        return $version.Trim()
    }
    return "unknown"
}

function Get-LatestVersion {
    try {
        Write-Info "Checking GitHub for latest version..."
        
        # Try to get the latest release
        $releaseUrl = "$REPO_API/releases/latest"
        try {
            $release = Invoke-RestMethod -Uri $releaseUrl -UseBasicParsing -ErrorAction Stop
            return @{
                Version = $release.tag_name
                Date = $release.published_at
                Notes = $release.body
                Type = "release"
            }
        } catch {
            # No releases, check latest commit
            $commitsUrl = "$REPO_API/commits/main"
            $commit = Invoke-RestMethod -Uri $commitsUrl -UseBasicParsing
            return @{
                Version = $commit.sha.Substring(0, 7)
                Date = $commit.commit.committer.date
                Notes = $commit.commit.message
                Type = "commit"
            }
        }
    } catch {
        Write-Error "Failed to check for updates: $_"
        return $null
    }
}

function Get-InstallDirectory {
    # Check common locations for DRL Community installation
    $possiblePaths = @(
        "$env:LOCALAPPDATA\DRL-Community",
        "$env:PROGRAMFILES\DRL-Community",
        "${env:PROGRAMFILES(x86)}\DRL-Community",
        "$PSScriptRoot\..",
        "$PSScriptRoot"
    )
    
    foreach ($path in $possiblePaths) {
        $versionFile = Join-Path $path $VERSION_FILE
        if (Test-Path $versionFile) {
            return (Resolve-Path $path).Path
        }
    }
    
    # Default to script directory
    return $PSScriptRoot
}

function Find-GameDirectory {
    if ($GameDir -and (Test-Path "$GameDir\DRL Simulator.exe")) {
        return $GameDir
    }
    
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
            return $path
        }
    }
    
    return $null
}

function Backup-Installation {
    param([string]$InstallDir)
    
    Write-Info "Creating backup of current installation..."
    
    $backupDir = Join-Path $InstallDir "backups"
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupPath = Join-Path $backupDir "backup_$timestamp"
    
    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }
    
    # Items to backup
    $itemsToBackup = @(
        "common",
        "platforms\windows",
        $VERSION_FILE
    )
    
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
    
    foreach ($item in $itemsToBackup) {
        $sourcePath = Join-Path $InstallDir $item
        if (Test-Path $sourcePath) {
            $destPath = Join-Path $backupPath $item
            $destDir = Split-Path $destPath -Parent
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Copy-Item -Path $sourcePath -Destination $destPath -Recurse -Force
        }
    }
    
    Write-Success "Backup created at: $backupPath"
    
    # Clean old backups (keep last 5)
    $backups = Get-ChildItem $backupDir -Directory | Sort-Object CreationTime -Descending | Select-Object -Skip 5
    foreach ($oldBackup in $backups) {
        Remove-Item $oldBackup.FullName -Recurse -Force
        Write-Info "Removed old backup: $($oldBackup.Name)"
    }
    
    return $backupPath
}

function Update-FromGitHub {
    param([string]$InstallDir)
    
    Write-Info "Downloading latest version from GitHub..."
    
    $tempDir = Join-Path $env:TEMP "DRL-Community-Update"
    $zipPath = Join-Path $env:TEMP "DRL-Community-latest.zip"
    
    # Clean up any previous temp files
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force
    }
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }
    
    try {
        # Download the latest code
        $downloadUrl = "$REPO_URL/archive/refs/heads/main.zip"
        Write-Info "Downloading from: $downloadUrl"
        
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing
        Write-Success "Download complete"
        
        # Extract
        Write-Info "Extracting files..."
        Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force
        
        # Find the extracted folder (usually repo-name-branch)
        $extractedFolder = Get-ChildItem $tempDir -Directory | Select-Object -First 1
        
        if (-not $extractedFolder) {
            throw "Failed to find extracted files"
        }
        
        # Update files
        Write-Info "Updating installation..."
        
        # Copy common files
        $commonSource = Join-Path $extractedFolder.FullName "common"
        $commonDest = Join-Path $InstallDir "common"
        if (Test-Path $commonSource) {
            if (Test-Path $commonDest) {
                Remove-Item $commonDest -Recurse -Force
            }
            Copy-Item -Path $commonSource -Destination $commonDest -Recurse -Force
            Write-Success "Updated common files"
        }
        
        # Copy Windows platform files
        $windowsSource = Join-Path $extractedFolder.FullName "platforms\windows"
        $windowsDest = Join-Path $InstallDir "platforms\windows"
        if (Test-Path $windowsSource) {
            # Don't overwrite user config files
            $filesToPreserve = @("config.json", "settings.json")
            foreach ($file in $filesToPreserve) {
                $filePath = Join-Path $windowsDest $file
                if (Test-Path $filePath) {
                    $tempPath = Join-Path $env:TEMP $file
                    Copy-Item $filePath $tempPath -Force
                }
            }
            
            if (Test-Path $windowsDest) {
                Remove-Item $windowsDest -Recurse -Force
            }
            Copy-Item -Path $windowsSource -Destination $windowsDest -Recurse -Force
            
            # Restore preserved files
            foreach ($file in $filesToPreserve) {
                $tempPath = Join-Path $env:TEMP $file
                if (Test-Path $tempPath) {
                    $destPath = Join-Path $windowsDest $file
                    Copy-Item $tempPath $destPath -Force
                    Remove-Item $tempPath -Force
                }
            }
            Write-Success "Updated Windows platform files"
        }
        
        # Copy docs
        $docsSource = Join-Path $extractedFolder.FullName "docs"
        $docsDest = Join-Path $InstallDir "docs"
        if (Test-Path $docsSource) {
            if (Test-Path $docsDest) {
                Remove-Item $docsDest -Recurse -Force
            }
            Copy-Item -Path $docsSource -Destination $docsDest -Recurse -Force
            Write-Success "Updated documentation"
        }
        
        # Update version file
        $newVersionPath = Join-Path $extractedFolder.FullName $VERSION_FILE
        if (Test-Path $newVersionPath) {
            Copy-Item $newVersionPath (Join-Path $InstallDir $VERSION_FILE) -Force
        } else {
            # Create version file with current date
            $version = Get-Date -Format "yyyy.MM.dd"
            Set-Content -Path (Join-Path $InstallDir $VERSION_FILE) -Value $version
        }
        
        Write-Success "Update complete!"
        
    } finally {
        # Cleanup
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path $zipPath) {
            Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Update-BepInExPlugins {
    param([string]$GameDir)
    
    if (-not $GameDir) {
        Write-Warning "Game directory not found, skipping plugin update"
        return
    }
    
    Write-Info "Updating BepInEx plugins in game directory..."
    
    $pluginsDir = Join-Path $GameDir "BepInEx\plugins"
    if (-not (Test-Path $pluginsDir)) {
        Write-Warning "BepInEx plugins directory not found"
        return
    }
    
    $InstallDir = Get-InstallDirectory
    $sourcePlugins = Join-Path $InstallDir "common\plugins"
    
    if (Test-Path $sourcePlugins) {
        # Compile and copy plugins
        $pluginFiles = Get-ChildItem $sourcePlugins -Filter "*.cs"
        foreach ($plugin in $pluginFiles) {
            $dllName = $plugin.BaseName + ".dll"
            $dllDest = Join-Path $pluginsDir $dllName
            
            # Check if we need to recompile
            if ((Test-Path $dllDest) -and (-not $Force)) {
                $sourceTime = (Get-Item $plugin.FullName).LastWriteTime
                $dllTime = (Get-Item $dllDest).LastWriteTime
                if ($dllTime -gt $sourceTime) {
                    Write-Info "Plugin $dllName is up to date"
                    continue
                }
            }
            
            Write-Info "Plugin $($plugin.Name) needs recompilation"
            Write-Warning "Run the installer to recompile plugins"
        }
    }
}

function Show-UpdateSummary {
    param(
        [string]$CurrentVersion,
        [hashtable]$LatestInfo
    )
    
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                     Update Available                         ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "  Current Version: " -NoNewline
    Write-Host $CurrentVersion -ForegroundColor Yellow
    
    Write-Host "  Latest Version:  " -NoNewline
    Write-Host $LatestInfo.Version -ForegroundColor Green
    
    Write-Host "  Released:        " -NoNewline
    Write-Host $LatestInfo.Date -ForegroundColor Cyan
    
    if ($LatestInfo.Notes) {
        Write-Host ""
        Write-Host "  Changes:" -ForegroundColor White
        $notes = $LatestInfo.Notes -split "`n" | Select-Object -First 5
        foreach ($line in $notes) {
            Write-Host "    $line" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
}

# Main
Write-Banner

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Not running as Administrator. Some features may not work."
    Write-Info "For full functionality, right-click and 'Run as Administrator'"
    Write-Host ""
}

Write-Step 1 "Checking Current Installation"

$InstallDir = Get-InstallDirectory
Write-Info "Installation directory: $InstallDir"

$currentVersion = Get-CurrentVersion
Write-Info "Current version: $currentVersion"

$gameDir = Find-GameDirectory
if ($gameDir) {
    Write-Info "Game directory: $gameDir"
} else {
    Write-Warning "Game directory not found"
}

Write-Step 2 "Checking for Updates"

$latestInfo = Get-LatestVersion
if (-not $latestInfo) {
    Write-Error "Failed to check for updates"
    exit 1
}

Write-Info "Latest version: $($latestInfo.Version) ($($latestInfo.Type))"

# Compare versions
$needsUpdate = $false
if ($currentVersion -eq "unknown") {
    $needsUpdate = $true
} elseif ($latestInfo.Type -eq "release") {
    $needsUpdate = $currentVersion -ne $latestInfo.Version
} else {
    # For commits, always offer update unless versions match
    $needsUpdate = $currentVersion -ne $latestInfo.Version
}

if (-not $needsUpdate -and -not $Force) {
    Write-Success "You are running the latest version!"
    Write-Host ""
    Write-Host "Use -Force to update anyway" -ForegroundColor Gray
    exit 0
}

if ($needsUpdate) {
    Show-UpdateSummary -CurrentVersion $currentVersion -LatestInfo $latestInfo
}

if ($CheckOnly) {
    Write-Info "Check-only mode, exiting without updating"
    exit 0
}

# Confirm update
if (-not $Force) {
    Write-Host ""
    $confirm = Read-Host "Do you want to update now? (y/n)"
    if ($confirm -notmatch '^[Yy]') {
        Write-Info "Update cancelled"
        exit 0
    }
}

Write-Step 3 "Creating Backup"

if (-not $NoBackup) {
    $backupPath = Backup-Installation -InstallDir $InstallDir
} else {
    Write-Warning "Skipping backup (--NoBackup specified)"
}

Write-Step 4 "Downloading and Installing Update"

try {
    Update-FromGitHub -InstallDir $InstallDir
} catch {
    Write-Error "Update failed: $_"
    Write-Info "You can restore from backup at: $backupPath"
    exit 1
}

Write-Step 5 "Updating Game Files"

Update-BepInExPlugins -GameDir $gameDir

# Done
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                    Update Complete!                          ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

$newVersion = Get-CurrentVersion
Write-Success "Updated from $currentVersion to $newVersion"
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
