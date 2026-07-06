@echo off
chcp 65001 >nul
title HNS Match System - High Performance
color 0B
echo ============================================
echo   HNS Match System - High Performance Mode
echo ============================================
echo.

:: ============ Config ============
set PORT=27015
set MAXPLAYERS=32
set MAP=de_dust2
set TICKRATE=100

:: ============ System Optimizations ============
echo [SYS] Applying system optimizations...
:: High priority for HLDS
wmic process where name="hlds.exe" CALL setpriority "high priority" >nul 2>&1
:: TCP optimizations
netsh int tcp set global autotuninglevel=normal >nul 2>&1
netsh int tcp set global congestionprovider=ctcp >nul 2>&1
echo [SYS] Done
echo.

:: ============ Launch ============
echo [INFO] Port: %PORT% | Players: %MAXPLAYERS% | Map: %MAP% | Tick: %TICKRATE%
echo [INFO] Heap: 512MB | FPS: unlimited
echo.
echo ============================================

hlds.exe -game cstrike +map %MAP% +maxplayers %MAXPLAYERS% -port %PORT% -tickrate %TICKRATE% +sys_tickrate %TICKRATE% -pingboost 3 -heapsize 524288 -noipx +fps_max 1000 -num_edicts 4096 +exec server.cfg -norestart +sv_lan 0

echo.
echo Server stopped.
pause