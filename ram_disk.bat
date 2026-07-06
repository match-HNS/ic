@echo off
chcp 65001 >nul
title RAM Disk - HNS Server Optimizer
color 0E
echo ============================================
echo   HNS RAM Disk Memory Optimizer
echo ============================================
echo.

:: ============ CONFIG: CHANGE THESE TO YOUR PATHS ============
:: RAM disk drive letter (e.g. R:)
set RAM_DRIVE=R:\
:: Your CS server directory (e.g. C:\HLDS\cstrike)
set SERVER_DIR=C:\HLDS\cstrike
:: =============================================================

:: ============ Check RAM Disk ============
if not exist "%RAM_DRIVE%" (
    echo [ERROR] RAM disk %RAM_DRIVE% not found!
    echo.
    echo Create a RAM disk with ImDisk first:
    echo   1. Download: https://sourceforge.net/projects/imdisk-toolkit/
    echo   2. Install and open ImDisk Toolkit
    echo   3. Create virtual disk, size 1-2GB, format NTFS
    echo   4. Assign drive letter (e.g. R:)
    echo.
    pause
    exit /b 1
)

:: ============ Sync to RAM Disk ============
echo [1/2] Syncing files to RAM disk...
echo       Source: %SERVER_DIR%
echo       Target: %RAM_DRIVE%cstrike

if not exist "%RAM_DRIVE%cstrike" mkdir "%RAM_DRIVE%cstrike"
if not exist "%RAM_DRIVE%cstrike\addons" mkdir "%RAM_DRIVE%cstrike\addons"
if not exist "%RAM_DRIVE%cstrike\addons\amxmodx" mkdir "%RAM_DRIVE%cstrike\addons\amxmodx"
if not exist "%RAM_DRIVE%cstrike\addons\amxmodx\plugins" mkdir "%RAM_DRIVE%cstrike\addons\amxmodx\plugins"
if not exist "%RAM_DRIVE%cstrike\addons\amxmodx\configs" mkdir "%RAM_DRIVE%cstrike\addons\amxmodx\configs"
if not exist "%RAM_DRIVE%cstrike\addons\amxmodx\data" mkdir "%RAM_DRIVE%cstrike\addons\amxmodx\data"
if not exist "%RAM_DRIVE%cstrike\addons\amxmodx\modules" mkdir "%RAM_DRIVE%cstrike\addons\amxmodx\modules"
if not exist "%RAM_DRIVE%cstrike\addons\metamod" mkdir "%RAM_DRIVE%cstrike\addons\metamod"

xcopy /E /Y /Q "%SERVER_DIR%\addons" "%RAM_DRIVE%cstrike\addons\" >nul 2>&1
xcopy /E /Y /Q "%SERVER_DIR%\maps" "%RAM_DRIVE%cstrike\maps\" >nul 2>&1
xcopy /E /Y /Q "%SERVER_DIR%\sound" "%RAM_DRIVE%cstrike\sound\" >nul 2>&1
xcopy /E /Y /Q "%SERVER_DIR%\models" "%RAM_DRIVE%cstrike\models\" >nul 2>&1
xcopy /E /Y /Q "%SERVER_DIR%\gfx" "%RAM_DRIVE%cstrike\gfx\" >nul 2>&1
xcopy /E /Y /Q "%SERVER_DIR%\sprites" "%RAM_DRIVE%cstrike\sprites\" >nul 2>&1
copy /Y "%SERVER_DIR%\server.cfg" "%RAM_DRIVE%cstrike\" >nul 2>&1
copy /Y "%SERVER_DIR%\liblist.gam" "%RAM_DRIVE%cstrike\" >nul 2>&1

echo [OK] Sync complete!
echo.

:: ============ Launch Server from RAM Disk ============
echo [2/2] Launching server from RAM disk...
echo.

cd /d "%RAM_DRIVE%"
hlds.exe -game cstrike +map de_dust2 +maxplayers 32 -port 27015 -tickrate 100 +sys_tickrate 100 -pingboost 3 -heapsize 524288 -noipx +fps_max 1000 +exec server.cfg -norestart +sv_lan 0

:: ============ Sync Data Back to HDD ============
echo.
echo [SYNC] Server stopped. Saving data back to HDD...
xcopy /E /Y /Q /D "%RAM_DRIVE%cstrike\addons\amxmodx\data" "%SERVER_DIR%\addons\amxmodx\data\" >nul 2>&1
xcopy /E /Y /Q /D "%RAM_DRIVE%cstrike\addons\amxmodx\configs" "%SERVER_DIR%\addons\amxmodx\configs\" >nul 2>&1
echo [OK] Data saved.
echo.
pause