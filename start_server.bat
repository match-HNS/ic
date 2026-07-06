@echo off
chcp 65001 >nul
title HNS Server
color 0A

echo ============================================
echo   HNS Server - Starting...
echo ============================================
echo.

:: Check if hlds.exe exists
if not exist "hlds.exe" (
    echo [ERROR] hlds.exe not found in current directory!
    echo [ERROR] Put this .bat file in the same folder as hlds.exe
    echo.
    echo Current dir: %~dp0
    pause
    exit /b 1
)

echo [OK] hlds.exe found
echo.

:: Config
set PORT=27015
set MAXPLAYERS=32
set MAP=de_dust2
set TICKRATE=100

echo Launching: port=%PORT% players=%MAXPLAYERS% map=%MAP% tick=%TICKRATE%
echo.

start /wait hlds.exe -console -game cstrike +map %MAP% +maxplayers %MAXPLAYERS% -port %PORT% -tickrate %TICKRATE% +sys_tickrate %TICKRATE% +exec server.cfg +sv_lan 0

echo.
echo ============================================
echo   Server stopped (exit code: %ERRORLEVEL%)
echo ============================================
echo.
echo If server crashed or didn't start, check:
echo   1. Is cstrike\ folder present?
echo   2. Is cstrike\addons\metamod\ installed?
echo   3. Is cstrike\addons\amxmodx\ installed?
echo   4. Run hlds.exe directly and see the error
echo.
pause