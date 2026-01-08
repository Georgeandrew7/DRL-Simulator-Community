@echo off
REM Find DRL Simulator installation directory
REM Checks multiple common Steam library locations

REM First check if GAME_DIR is already set
if defined GAME_DIR if exist "%GAME_DIR%\DRL Simulator.exe" goto :found

REM Default Steam locations to check
set "STEAM_PATHS="
set "STEAM_PATHS=%STEAM_PATHS% %ProgramFiles(x86)%\Steam"
set "STEAM_PATHS=%STEAM_PATHS% %ProgramFiles%\Steam"
set "STEAM_PATHS=%STEAM_PATHS% C:\Steam"
set "STEAM_PATHS=%STEAM_PATHS% D:\Steam"
set "STEAM_PATHS=%STEAM_PATHS% E:\Steam"
set "STEAM_PATHS=%STEAM_PATHS% F:\Steam"
set "STEAM_PATHS=%STEAM_PATHS% D:\SteamLibrary"
set "STEAM_PATHS=%STEAM_PATHS% E:\SteamLibrary"
set "STEAM_PATHS=%STEAM_PATHS% F:\SteamLibrary"
set "STEAM_PATHS=%STEAM_PATHS% D:\Games\Steam"
set "STEAM_PATHS=%STEAM_PATHS% E:\Games\Steam"
set "STEAM_PATHS=%STEAM_PATHS% D:\Games\SteamLibrary"
set "STEAM_PATHS=%STEAM_PATHS% E:\Games\SteamLibrary"

REM Check each path
for %%P in (%STEAM_PATHS%) do (
    if exist "%%P\steamapps\common\DRL Simulator\DRL Simulator.exe" (
        set "GAME_DIR=%%P\steamapps\common\DRL Simulator"
        goto :found
    )
)

REM Try to find via registry
for /f "tokens=2*" %%a in ('reg query "HKCU\Software\Valve\Steam" /v SteamPath 2^>nul') do (
    set "STEAM_PATH=%%b"
)
if defined STEAM_PATH (
    set "STEAM_PATH=%STEAM_PATH:/=\%"
    if exist "%STEAM_PATH%\steamapps\common\DRL Simulator\DRL Simulator.exe" (
        set "GAME_DIR=%STEAM_PATH%\steamapps\common\DRL Simulator"
        goto :found
    )
    
    REM Check libraryfolders.vdf for additional Steam libraries
    if exist "%STEAM_PATH%\steamapps\libraryfolders.vdf" (
        for /f "tokens=2 delims=	 " %%L in ('findstr /R /C:"path" "%STEAM_PATH%\steamapps\libraryfolders.vdf"') do (
            set "LIB_PATH=%%~L"
            set "LIB_PATH=!LIB_PATH:\\=\!"
            if exist "!LIB_PATH!\steamapps\common\DRL Simulator\DRL Simulator.exe" (
                set "GAME_DIR=!LIB_PATH!\steamapps\common\DRL Simulator"
                goto :found
            )
        )
    )
)

REM Not found - prompt user
echo.
echo DRL Simulator was not found automatically.
echo.
echo Please enter the full path to DRL Simulator folder:
echo Example: D:\SteamLibrary\steamapps\common\DRL Simulator
echo.
set /p "GAME_DIR=Path: "

if not exist "%GAME_DIR%\DRL Simulator.exe" (
    echo.
    echo ERROR: DRL Simulator.exe not found at that location.
    set "GAME_DIR="
    exit /b 1
)

:found
REM Export for other scripts
echo %GAME_DIR%
exit /b 0
