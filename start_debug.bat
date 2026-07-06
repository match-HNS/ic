@echo off
chcp 65001 >nul
title HNS Server - Debug Mode
color 0E

echo ============================================
echo   HNS Server - Debug Mode
echo ============================================
echo.

echo [CHECK] Running diagnostics...
echo.

:: Check 1: hlds.exe
if exist "hlds.exe" (
    echo [OK] hlds.exe found
) else (
    echo [FAIL] hlds.exe not found! Put this .bat in HLDS root folder.
    pause
    exit /b 1
)

:: Check 2: cstrike folder
if exist "cstrike\liblist.gam" (
    echo [OK] cstrike\liblist.gam found
) else (
    echo [FAIL] cstrike\liblist.gam not found! cstrike folder missing?
    pause
    exit /b 1
)

:: Check 3: Metamod
if exist "cstrike\addons\metamod\dlls\metamod.dll" (
    echo [OK] cstrike\addons\metamod\dlls\metamod.dll found
) else (
    echo [FAIL] Metamod not installed! Server will crash without it.
    echo        Download: https://github.com/rehlds/Metamod-R/releases
)

:: Check 4: ReGameDLL
if exist "cstrike\addons\regamedll\regamedll.dll" (
    echo [OK] cstrike\addons\regamedll\regamedll.dll found
) else (
    echo [FAIL] ReGameDLL not installed! HNS plugins REQUIRE ReGameDLL.
    echo        Download: https://github.com/rehlds/ReGameDLL_CS/releases
    echo        Install: extract regamedll.dll to cstrike\addons\regamedll\
)

:: Check 5: ReAPI
if exist "cstrike\addons\amxmodx\modules\reapi_amxx.dll" (
    echo [OK] reapi_amxx.dll found
) else (
    echo [FAIL] ReAPI module missing! HNS plugins REQUIRE ReAPI.
    echo        Download: https://github.com/rehlds/ReAPI/releases
)

:: Check 6: metamod plugins.ini
if exist "cstrike\addons\metamod\plugins.ini" (
    echo [OK] metamod\plugins.ini found
) else (
    echo [WARN] metamod\plugins.ini not found! Creating it...
    echo win32   addons/regamedll/regamedll.dll > "cstrike\addons\metamod\plugins.ini"
    echo [OK] Created metamod\plugins.ini with ReGameDLL
)

:: Check 7: PersistentDataStorage
if exist "cstrike\addons\amxmodx\modules\PersistentDataStorage_amxx.dll" (
    echo [OK] PersistentDataStorage module found
) else (
    echo [WARN] PersistentDataStorage module missing. HnsMatchSystem needs it.
    echo        Download: https://hlds.run/resources/220/
)

echo.
echo ============================================
echo   Starting server with console output...
echo   Watch for red ERROR messages below!
echo ============================================
echo.

hlds.exe -console -game cstrike +map de_dust2 +maxplayers 32 -port 27015 -tickrate 100 +sys_tickrate 100 +exec server.cfg +sv_lan 0

echo.
echo Server stopped.
pause