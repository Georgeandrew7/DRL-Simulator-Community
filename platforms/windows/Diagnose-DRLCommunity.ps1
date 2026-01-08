#Requires -Version 5.1
<#
.SYNOPSIS
    DRL Simulator Community - Windows Diagnostic Tool
.DESCRIPTION
    Checks the health of the DRL Community installation and reports issues.
    Tests all components: Python, BepInEx, plugins, network, hosts file, etc.
.NOTES
    Run as Administrator for complete diagnostics.
#>

param(
    [string]$GameDir = "",
    [switch]$Fix,
    [switch]$Verbose,
    [switch]$ExportReport
)

# Results tracking
$script:Results = @{
    Passed = @()
    Warnings = @()
    Failed = @()
}

$script:StartTime = Get-Date

# Colors and formatting
function Write-Banner {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║       DRL Simulator Community - Diagnostic Tool              ║" -ForegroundColor Cyan
    Write-Host "║                      Version 1.0.0                           ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host " $Title" -ForegroundColor White
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
}

function Write-Check {
    param(
        [string]$Name,
        [string]$Status,  # "pass", "warn", "fail"
        [string]$Message,
        [string]$Detail = ""
    )
    
    $icon = switch ($Status) {
        "pass" { "[✓]"; $color = "Green" }
        "warn" { "[!]"; $color = "Yellow" }
        "fail" { "[✗]"; $color = "Red" }
        default { "[?]"; $color = "Gray" }
    }
    
    Write-Host "  $icon " -ForegroundColor $color -NoNewline
    Write-Host "$Name`: " -NoNewline
    Write-Host $Message -ForegroundColor $color
    
    if ($Detail -and $Verbose) {
        Write-Host "      └─ $Detail" -ForegroundColor DarkGray
    }
    
    # Track results
    $result = @{
        Name = $Name
        Message = $Message
        Detail = $Detail
    }
    
    switch ($Status) {
        "pass" { $script:Results.Passed += $result }
        "warn" { $script:Results.Warnings += $result }
        "fail" { $script:Results.Failed += $result }
    }
}

function Test-AdminPrivileges {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    return $isAdmin
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
        "E:\SteamLibrary\steamapps\common\DRL Simulator",
        "F:\Steam\steamapps\common\DRL Simulator",
        "F:\SteamLibrary\steamapps\common\DRL Simulator"
    )
    
    foreach ($path in $PossiblePaths) {
        if (Test-Path "$path\DRL Simulator.exe") {
            return $path
        }
    }
    
    return $null
}

function Get-InstallDirectory {
    $possiblePaths = @(
        "$env:LOCALAPPDATA\DRL-Community",
        "$env:PROGRAMFILES\DRL-Community",
        "${env:PROGRAMFILES(x86)}\DRL-Community",
        "$PSScriptRoot\..",
        "$PSScriptRoot"
    )
    
    foreach ($path in $possiblePaths) {
        if (Test-Path (Join-Path $path "common")) {
            return (Resolve-Path $path).Path
        }
    }
    
    return $PSScriptRoot
}

# ============================================================================
# DIAGNOSTIC CHECKS
# ============================================================================

function Test-SystemRequirements {
    Write-Section "System Requirements"
    
    # Windows Version
    $os = Get-CimInstance Win32_OperatingSystem
    $osVersion = [version]$os.Version
    if ($osVersion.Major -ge 10) {
        Write-Check "Windows Version" "pass" "Windows $($os.Caption)" "Version $($os.Version)"
    } else {
        Write-Check "Windows Version" "warn" "Windows $($os.Caption)" "Windows 10+ recommended"
    }
    
    # Admin check
    if (Test-AdminPrivileges) {
        Write-Check "Admin Privileges" "pass" "Running as Administrator"
    } else {
        Write-Check "Admin Privileges" "warn" "Not running as Administrator" "Some checks may be incomplete"
    }
    
    # RAM
    $ram = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    if ($ram -ge 8) {
        Write-Check "System Memory" "pass" "$ram GB RAM"
    } elseif ($ram -ge 4) {
        Write-Check "System Memory" "warn" "$ram GB RAM" "8GB+ recommended"
    } else {
        Write-Check "System Memory" "fail" "$ram GB RAM" "Minimum 4GB required"
    }
    
    # Disk space
    $installDir = Get-InstallDirectory
    $drive = (Get-Item $installDir).PSDrive.Name
    $disk = Get-PSDrive $drive
    $freeGB = [math]::Round($disk.Free / 1GB, 1)
    if ($freeGB -ge 5) {
        Write-Check "Disk Space" "pass" "$freeGB GB free on $drive`:"
    } elseif ($freeGB -ge 1) {
        Write-Check "Disk Space" "warn" "$freeGB GB free on $drive`:" "5GB+ recommended"
    } else {
        Write-Check "Disk Space" "fail" "$freeGB GB free on $drive`:" "Low disk space"
    }
}

function Test-PythonInstallation {
    Write-Section "Python Environment"
    
    # Check if Python is installed
    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    $python3Cmd = Get-Command python3 -ErrorAction SilentlyContinue
    
    $python = if ($python3Cmd) { $python3Cmd } else { $pythonCmd }
    
    if ($python) {
        $pythonVersion = & $python.Source --version 2>&1
        if ($pythonVersion -match "Python (\d+)\.(\d+)") {
            $major = [int]$Matches[1]
            $minor = [int]$Matches[2]
            
            if ($major -ge 3 -and $minor -ge 8) {
                Write-Check "Python Version" "pass" $pythonVersion $python.Source
            } elseif ($major -ge 3) {
                Write-Check "Python Version" "warn" $pythonVersion "Python 3.8+ recommended"
            } else {
                Write-Check "Python Version" "fail" $pythonVersion "Python 3.8+ required"
            }
        }
        
        # Check pip
        try {
            $pipVersion = & $python.Source -m pip --version 2>&1
            if ($pipVersion -match "pip (\d+\.\d+)") {
                Write-Check "Pip" "pass" "pip $($Matches[1])"
            }
        } catch {
            Write-Check "Pip" "fail" "Not installed" "Run: python -m ensurepip"
        }
        
        # Check required packages
        $requiredPackages = @("aiohttp", "requests")
        foreach ($pkg in $requiredPackages) {
            try {
                $result = & $python.Source -c "import $pkg; print($pkg.__version__)" 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Check "Package: $pkg" "pass" "Version $result"
                } else {
                    Write-Check "Package: $pkg" "fail" "Not installed" "Run: pip install $pkg"
                }
            } catch {
                Write-Check "Package: $pkg" "fail" "Not installed" "Run: pip install $pkg"
            }
        }
    } else {
        Write-Check "Python" "fail" "Not found in PATH" "Install Python 3.8+ from python.org"
    }
}

function Test-GameInstallation {
    param([string]$GamePath)
    
    Write-Section "Game Installation"
    
    if (-not $GamePath) {
        Write-Check "Game Directory" "fail" "DRL Simulator not found" "Install from Steam or specify -GameDir"
        return
    }
    
    Write-Check "Game Directory" "pass" "Found" $GamePath
    
    # Check executable
    $exePath = Join-Path $GamePath "DRL Simulator.exe"
    if (Test-Path $exePath) {
        $exeInfo = Get-Item $exePath
        $sizeMB = [math]::Round($exeInfo.Length / 1MB, 1)
        Write-Check "Game Executable" "pass" "$sizeMB MB" $exePath
    } else {
        Write-Check "Game Executable" "fail" "Not found"
    }
    
    # Check Data folder
    $dataPath = Join-Path $GamePath "DRL Simulator_Data"
    if (Test-Path $dataPath) {
        Write-Check "Game Data" "pass" "Found" $dataPath
        
        # Check Managed folder (for plugin references)
        $managedPath = Join-Path $dataPath "Managed"
        if (Test-Path $managedPath) {
            $assemblyCSharp = Join-Path $managedPath "Assembly-CSharp.dll"
            if (Test-Path $assemblyCSharp) {
                Write-Check "Assembly-CSharp.dll" "pass" "Found"
            } else {
                Write-Check "Assembly-CSharp.dll" "warn" "Not found" "May affect plugin compilation"
            }
        }
    } else {
        Write-Check "Game Data" "fail" "Not found"
    }
    
    # Check Unity version
    $globalgamemanagers = Join-Path $dataPath "globalgamemanagers"
    if (Test-Path $globalgamemanagers) {
        Write-Check "Unity Data Files" "pass" "Found"
    }
}

function Test-BepInExInstallation {
    param([string]$GamePath)
    
    Write-Section "BepInEx Installation"
    
    if (-not $GamePath) {
        Write-Check "BepInEx" "fail" "Game not found" "Cannot check BepInEx installation"
        return
    }
    
    $bepinexPath = Join-Path $GamePath "BepInEx"
    
    if (-not (Test-Path $bepinexPath)) {
        Write-Check "BepInEx Directory" "fail" "Not installed" "Run install.bat to install BepInEx"
        return
    }
    
    Write-Check "BepInEx Directory" "pass" "Found" $bepinexPath
    
    # Check core files
    $coreFiles = @(
        "core\BepInEx.dll",
        "core\0Harmony.dll",
        "core\MonoMod.RuntimeDetour.dll"
    )
    
    foreach ($file in $coreFiles) {
        $filePath = Join-Path $bepinexPath $file
        if (Test-Path $filePath) {
            $info = Get-Item $filePath
            Write-Check (Split-Path $file -Leaf) "pass" "Found" "$([math]::Round($info.Length/1KB))KB"
        } else {
            Write-Check (Split-Path $file -Leaf) "fail" "Missing" "BepInEx may be corrupted"
        }
    }
    
    # Check winhttp.dll (required for BepInEx to load)
    $winhttpPath = Join-Path $GamePath "winhttp.dll"
    if (Test-Path $winhttpPath) {
        Write-Check "winhttp.dll" "pass" "Found (BepInEx loader)"
    } else {
        Write-Check "winhttp.dll" "fail" "Missing" "BepInEx won't load without this"
    }
    
    # Check plugins directory
    $pluginsPath = Join-Path $bepinexPath "plugins"
    if (Test-Path $pluginsPath) {
        $plugins = Get-ChildItem $pluginsPath -Filter "*.dll" -ErrorAction SilentlyContinue
        if ($plugins.Count -gt 0) {
            Write-Check "Plugins Directory" "pass" "$($plugins.Count) plugin(s) installed"
            foreach ($plugin in $plugins) {
                Write-Check "  └─ $($plugin.Name)" "pass" "$([math]::Round($plugin.Length/1KB))KB"
            }
        } else {
            Write-Check "Plugins Directory" "warn" "No plugins installed" "Run install.bat to compile plugins"
        }
    } else {
        Write-Check "Plugins Directory" "warn" "Not found" "Will be created when plugins are installed"
    }
    
    # Check config
    $configPath = Join-Path $bepinexPath "config"
    if (Test-Path $configPath) {
        Write-Check "Config Directory" "pass" "Found"
    }
    
    # Check logs
    $logFile = Join-Path $bepinexPath "LogOutput.log"
    if (Test-Path $logFile) {
        $logInfo = Get-Item $logFile
        $logAge = (Get-Date) - $logInfo.LastWriteTime
        if ($logAge.TotalDays -lt 7) {
            Write-Check "BepInEx Log" "pass" "Recent activity" "Last modified: $($logInfo.LastWriteTime)"
        } else {
            Write-Check "BepInEx Log" "warn" "Old log file" "Game may not have been run recently"
        }
        
        # Check for errors in log
        $logContent = Get-Content $logFile -Tail 50 -ErrorAction SilentlyContinue
        $errors = $logContent | Where-Object { $_ -match "error|exception|fail" }
        if ($errors.Count -gt 0) {
            Write-Check "Log Errors" "warn" "$($errors.Count) error(s) in recent log"
        }
    }
}

function Test-NetworkConfiguration {
    Write-Section "Network Configuration"
    
    # Check hosts file
    $hostsPath = "C:\Windows\System32\drivers\etc\hosts"
    if (Test-Path $hostsPath) {
        $hostsContent = Get-Content $hostsPath -Raw
        
        if ($hostsContent -match "api\.drlgame\.com") {
            if ($hostsContent -match "127\.0\.0\.1\s+api\.drlgame\.com") {
                Write-Check "Hosts Entry" "pass" "api.drlgame.com → 127.0.0.1"
            } else {
                Write-Check "Hosts Entry" "warn" "api.drlgame.com exists but may be misconfigured"
            }
        } else {
            Write-Check "Hosts Entry" "fail" "api.drlgame.com not in hosts file" "Run install.bat as Administrator"
        }
    } else {
        Write-Check "Hosts File" "fail" "Cannot read hosts file" "Run as Administrator"
    }
    
    # Check if ports are available
    $portsToCheck = @(
        @{Port = 80; Name = "HTTP"},
        @{Port = 443; Name = "HTTPS"},
        @{Port = 8080; Name = "Master Server"}
    )
    
    foreach ($portInfo in $portsToCheck) {
        $port = $portInfo.Port
        $name = $portInfo.Name
        
        try {
            $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $port)
            $listener.Start()
            $listener.Stop()
            Write-Check "Port $port ($name)" "pass" "Available"
        } catch {
            # Port might be in use - check if it's our server
            try {
                $connection = New-Object System.Net.Sockets.TcpClient
                $connection.Connect("127.0.0.1", $port)
                $connection.Close()
                Write-Check "Port $port ($name)" "pass" "In use (server running?)"
            } catch {
                Write-Check "Port $port ($name)" "warn" "In use by another application"
            }
        }
    }
    
    # Test localhost connectivity
    try {
        $response = Invoke-WebRequest -Uri "http://127.0.0.1:80" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
        Write-Check "Mock Server (HTTP)" "pass" "Responding on port 80"
    } catch {
        Write-Check "Mock Server (HTTP)" "warn" "Not running" "Start with start-offline-mode.bat"
    }
    
    # Test internet connectivity
    try {
        $null = Invoke-WebRequest -Uri "https://github.com" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        Write-Check "Internet Connection" "pass" "Connected"
    } catch {
        Write-Check "Internet Connection" "warn" "Limited or no connection" "Updates may not work"
    }
}

function Test-SSLCertificates {
    Write-Section "SSL Certificates"
    
    $installDir = Get-InstallDirectory
    $certPath = Join-Path $installDir "certs"
    
    if (-not (Test-Path $certPath)) {
        $certPath = Join-Path $installDir "platforms\windows\certs"
    }
    
    if (Test-Path $certPath) {
        Write-Check "Certificates Directory" "pass" "Found" $certPath
        
        $certFiles = @("server.crt", "server.key")
        foreach ($file in $certFiles) {
            $filePath = Join-Path $certPath $file
            if (Test-Path $filePath) {
                $info = Get-Item $filePath
                $age = (Get-Date) - $info.CreationTime
                if ($age.TotalDays -lt 365) {
                    Write-Check $file "pass" "Valid" "Created $($info.CreationTime.ToString('yyyy-MM-dd'))"
                } else {
                    Write-Check $file "warn" "May be expired" "Created $($info.CreationTime.ToString('yyyy-MM-dd'))"
                }
            } else {
                Write-Check $file "warn" "Not found" "HTTPS may not work"
            }
        }
    } else {
        Write-Check "Certificates" "warn" "No certificates directory" "HTTPS mock server may not work"
    }
}

function Test-CommunityFiles {
    Write-Section "Community Files"
    
    $installDir = Get-InstallDirectory
    Write-Check "Install Directory" "pass" $installDir
    
    # Check common files
    $commonPath = Join-Path $installDir "common"
    if (Test-Path $commonPath) {
        Write-Check "Common Files" "pass" "Found"
        
        # Check server files
        $serverFiles = @(
            "server\mock_drl_backend.py",
            "server\master_server.py"
        )
        
        foreach ($file in $serverFiles) {
            $filePath = Join-Path $commonPath $file
            if (Test-Path $filePath) {
                Write-Check (Split-Path $file -Leaf) "pass" "Found"
            } else {
                Write-Check (Split-Path $file -Leaf) "fail" "Missing"
            }
        }
        
        # Check plugins source
        $pluginsPath = Join-Path $commonPath "plugins"
        if (Test-Path $pluginsPath) {
            $csFiles = Get-ChildItem $pluginsPath -Filter "*.cs"
            Write-Check "Plugin Sources" "pass" "$($csFiles.Count) source file(s)"
        }
    } else {
        Write-Check "Common Files" "fail" "Not found" "Installation may be corrupted"
    }
    
    # Check version file
    $versionFile = Join-Path $installDir "VERSION.txt"
    if (Test-Path $versionFile) {
        $version = Get-Content $versionFile -Raw
        Write-Check "Version" "pass" $version.Trim()
    } else {
        Write-Check "Version" "warn" "No version file"
    }
}

function Test-SteamIntegration {
    Write-Section "Steam Integration"
    
    # Check if Steam is running
    $steamProcess = Get-Process -Name "steam" -ErrorAction SilentlyContinue
    if ($steamProcess) {
        Write-Check "Steam Process" "pass" "Running"
    } else {
        Write-Check "Steam Process" "warn" "Not running" "Start Steam before playing"
    }
    
    # Check Steam installation
    $steamPaths = @(
        "C:\Program Files (x86)\Steam",
        "C:\Program Files\Steam"
    )
    
    $steamPath = $null
    foreach ($path in $steamPaths) {
        if (Test-Path "$path\steam.exe") {
            $steamPath = $path
            break
        }
    }
    
    if ($steamPath) {
        Write-Check "Steam Installation" "pass" "Found" $steamPath
    } else {
        Write-Check "Steam Installation" "warn" "Not found in default locations"
    }
}

function Show-Summary {
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host " DIAGNOSTIC SUMMARY" -ForegroundColor White
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host ""
    
    $elapsed = (Get-Date) - $script:StartTime
    
    $passCount = $script:Results.Passed.Count
    $warnCount = $script:Results.Warnings.Count
    $failCount = $script:Results.Failed.Count
    $totalCount = $passCount + $warnCount + $failCount
    
    Write-Host "  Checks completed in $([math]::Round($elapsed.TotalSeconds, 1)) seconds" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "  [✓] Passed:   " -ForegroundColor Green -NoNewline
    Write-Host "$passCount / $totalCount"
    
    Write-Host "  [!] Warnings: " -ForegroundColor Yellow -NoNewline
    Write-Host "$warnCount / $totalCount"
    
    Write-Host "  [✗] Failed:   " -ForegroundColor Red -NoNewline
    Write-Host "$failCount / $totalCount"
    
    Write-Host ""
    
    # Health score
    $healthScore = [math]::Round(($passCount / $totalCount) * 100)
    $healthColor = if ($healthScore -ge 80) { "Green" } elseif ($healthScore -ge 60) { "Yellow" } else { "Red" }
    
    Write-Host "  Health Score: " -NoNewline
    Write-Host "$healthScore%" -ForegroundColor $healthColor
    
    if ($failCount -gt 0) {
        Write-Host ""
        Write-Host "  Issues requiring attention:" -ForegroundColor Red
        foreach ($fail in $script:Results.Failed) {
            Write-Host "    • $($fail.Name): $($fail.Message)" -ForegroundColor Red
            if ($fail.Detail) {
                Write-Host "      Fix: $($fail.Detail)" -ForegroundColor Gray
            }
        }
    }
    
    if ($warnCount -gt 0 -and $Verbose) {
        Write-Host ""
        Write-Host "  Warnings:" -ForegroundColor Yellow
        foreach ($warn in $script:Results.Warnings) {
            Write-Host "    • $($warn.Name): $($warn.Message)" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
}

function Export-DiagnosticReport {
    $reportPath = Join-Path $env:USERPROFILE "Desktop\DRL-Diagnostic-Report.txt"
    
    $report = @"
DRL Simulator Community - Diagnostic Report
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
============================================

PASSED CHECKS ($($script:Results.Passed.Count)):
$(($script:Results.Passed | ForEach-Object { "  [✓] $($_.Name): $($_.Message)" }) -join "`n")

WARNINGS ($($script:Results.Warnings.Count)):
$(($script:Results.Warnings | ForEach-Object { "  [!] $($_.Name): $($_.Message)" }) -join "`n")

FAILED CHECKS ($($script:Results.Failed.Count)):
$(($script:Results.Failed | ForEach-Object { "  [✗] $($_.Name): $($_.Message) - $($_.Detail)" }) -join "`n")

============================================
Health Score: $([math]::Round(($script:Results.Passed.Count / ($script:Results.Passed.Count + $script:Results.Warnings.Count + $script:Results.Failed.Count)) * 100))%
"@
    
    Set-Content -Path $reportPath -Value $report
    Write-Host "  Report exported to: $reportPath" -ForegroundColor Cyan
}

# ============================================================================
# MAIN
# ============================================================================

Write-Banner

# Find game directory
$GamePath = Find-GameDirectory
if ($GamePath) {
    Write-Host "  Game found: $GamePath" -ForegroundColor Green
} else {
    Write-Host "  Game not found - some checks will be skipped" -ForegroundColor Yellow
}
Write-Host ""

# Run all diagnostics
Test-SystemRequirements
Test-PythonInstallation
Test-GameInstallation -GamePath $GamePath
Test-BepInExInstallation -GamePath $GamePath
Test-NetworkConfiguration
Test-SSLCertificates
Test-CommunityFiles
Test-SteamIntegration

# Show summary
Show-Summary

# Export report if requested
if ($ExportReport) {
    Export-DiagnosticReport
}

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
