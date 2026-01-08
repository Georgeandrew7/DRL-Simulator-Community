@echo off
REM Debug script to run the DRL mock server and show any errors
REM Run this script to see what's happening

echo =============================================
echo DRL Mock Server Debug Runner
echo =============================================
echo.

echo Checking Python...
python --version
if %errorlevel% neq 0 (
    echo ERROR: Python not found! Please install Python from python.org
    pause
    exit /b 1
)

echo.
echo Checking required packages...
python -c "import aiohttp; print('  aiohttp: OK')"
if %errorlevel% neq 0 (
    echo   aiohttp: MISSING - Installing...
    pip install aiohttp
)

python -c "import cryptography; print('  cryptography: OK')"
if %errorlevel% neq 0 (
    echo   cryptography: MISSING - Installing...
    pip install cryptography
)

echo.
echo Checking server file...
if exist "%~dp0mock_drl_backend.py" (
    echo   Server file found at: %~dp0mock_drl_backend.py
) else (
    echo ERROR: mock_drl_backend.py not found in %~dp0
    pause
    exit /b 1
)

echo.
echo =============================================
echo Starting server (errors will show below)
echo =============================================
echo.

cd /d "%~dp0"
python mock_drl_backend.py --dual

echo.
echo =============================================
echo Server exited. Check above for any errors.
echo =============================================
pause
