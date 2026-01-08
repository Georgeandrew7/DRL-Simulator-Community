@echo off
REM Build script for DRL Community BepInEx plugins
REM Requires .NET SDK: https://dotnet.microsoft.com/download

echo =============================================
echo DRL Community Plugin Builder
echo =============================================
echo.

REM Check for dotnet
dotnet --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: .NET SDK not found!
    echo.
    echo Please install .NET SDK from:
    echo   https://dotnet.microsoft.com/download
    echo.
    echo Download the ".NET SDK" (not just Runtime)
    pause
    exit /b 1
)

echo [OK] .NET SDK found

REM Find the game directory
set "GAME_DIR="
if exist "C:\Program Files (x86)\Steam\steamapps\common\DRL Simulator" set "GAME_DIR=C:\Program Files (x86)\Steam\steamapps\common\DRL Simulator"
if exist "D:\Steam\steamapps\common\DRL Simulator" set "GAME_DIR=D:\Steam\steamapps\common\DRL Simulator"
if exist "D:\SteamLibrary\steamapps\common\DRL Simulator" set "GAME_DIR=D:\SteamLibrary\steamapps\common\DRL Simulator"

if not defined GAME_DIR (
    echo Game directory not found automatically.
    set /p "GAME_DIR=Enter path to DRL Simulator folder: "
)

echo [OK] Game directory: %GAME_DIR%

REM Check for BepInEx
if not exist "%GAME_DIR%\BepInEx" (
    echo ERROR: BepInEx not found in game directory!
    echo Please install BepInEx first.
    pause
    exit /b 1
)

echo [OK] BepInEx found

REM Create build directory
set "BUILD_DIR=%~dp0build"
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

REM Create a simple .csproj file for building
echo [*] Creating project file...

(
echo ^<Project Sdk="Microsoft.NET.Sdk"^>
echo   ^<PropertyGroup^>
echo     ^<TargetFramework^>net472^</TargetFramework^>
echo     ^<AssemblyName^>DRLCommunityPlugins^</AssemblyName^>
echo     ^<LangVersion^>latest^</LangVersion^>
echo   ^</PropertyGroup^>
echo   ^<ItemGroup^>
echo     ^<Reference Include="BepInEx"^>
echo       ^<HintPath^>%GAME_DIR%\BepInEx\core\BepInEx.dll^</HintPath^>
echo     ^</Reference^>
echo     ^<Reference Include="0Harmony"^>
echo       ^<HintPath^>%GAME_DIR%\BepInEx\core\0Harmony.dll^</HintPath^>
echo     ^</Reference^>
echo     ^<Reference Include="UnityEngine"^>
echo       ^<HintPath^>%GAME_DIR%\DRL Simulator_Data\Managed\UnityEngine.dll^</HintPath^>
echo     ^</Reference^>
echo     ^<Reference Include="UnityEngine.CoreModule"^>
echo       ^<HintPath^>%GAME_DIR%\DRL Simulator_Data\Managed\UnityEngine.CoreModule.dll^</HintPath^>
echo     ^</Reference^>
echo     ^<Reference Include="UnityEngine.UnityWebRequestModule"^>
echo       ^<HintPath^>%GAME_DIR%\DRL Simulator_Data\Managed\UnityEngine.UnityWebRequestModule.dll^</HintPath^>
echo     ^</Reference^>
echo   ^</ItemGroup^>
echo ^</Project^>
) > "%BUILD_DIR%\DRLCommunityPlugins.csproj"

REM Copy source files
echo [*] Copying source files...
copy "%~dp0SSLBypassPlugin.cs" "%BUILD_DIR%\" >nul
copy "%~dp0LicenseBypassPlugin.cs" "%BUILD_DIR%\" >nul

REM Build
echo [*] Building plugins...
cd /d "%BUILD_DIR%"
dotnet build -c Release

if %errorlevel% neq 0 (
    echo.
    echo ERROR: Build failed! Check errors above.
    pause
    exit /b 1
)

REM Copy to BepInEx plugins folder
echo [*] Installing plugins...
set "PLUGINS_DIR=%GAME_DIR%\BepInEx\plugins"
if not exist "%PLUGINS_DIR%" mkdir "%PLUGINS_DIR%"

copy "%BUILD_DIR%\bin\Release\net472\DRLCommunityPlugins.dll" "%PLUGINS_DIR%\" >nul

echo.
echo =============================================
echo SUCCESS! Plugin installed to:
echo   %PLUGINS_DIR%\DRLCommunityPlugins.dll
echo.
echo Now restart the game and try connecting!
echo =============================================
pause
