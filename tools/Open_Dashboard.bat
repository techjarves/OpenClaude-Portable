@echo off
setlocal enabledelayedexpansion
title Portable AI USB - Dashboard

:: Define ANSI Colors using PowerShell
for /F %%a in ('powershell -NoProfile -Command "[char]27"') do set "ESC=%%a"
set "CYAN=%ESC%[36m"
set "GREEN=%ESC%[32m"
set "YELLOW=%ESC%[33m"
set "RED=%ESC%[31m"
set "DIM=%ESC%[90m"
set "R=%ESC%[0m"
set "BOLD=%ESC%[1m"

set "USB_ROOT=%~dp0..\"
set "ENGINE_DIR=%USB_ROOT%engine"
set "NODE=%ENGINE_DIR%\node-win-x64\node.exe"
set "DASHBOARD=%USB_ROOT%dashboard\server.mjs"
set "DATA_DIR=%USB_ROOT%data"

:: Portable data - keep everything on USB
set "CLAUDE_CONFIG_DIR=%DATA_DIR%\openclaude"
set "XDG_CONFIG_HOME=%DATA_DIR%\config"
set "XDG_DATA_HOME=%DATA_DIR%\app_data"
if not exist "%CLAUDE_CONFIG_DIR%" mkdir "%CLAUDE_CONFIG_DIR%"
if not exist "%XDG_CONFIG_HOME%" mkdir "%XDG_CONFIG_HOME%"
if not exist "%XDG_DATA_HOME%" mkdir "%XDG_DATA_HOME%"

echo.
echo %CYAN%=========================================================%R%
echo   %BOLD%Portable AI USB - Configuration Dashboard%R%
echo %CYAN%=========================================================%R%
echo.

:: Check Node.js
if not exist "%NODE%" goto err_nonode

:: Check dashboard file
if not exist "%DASHBOARD%" goto err_nodash

:: Check if port 3000 is already in use
set "PORT_BUSY=0"
netstat -ano 2>nul | findstr ":3000 " | findstr "LISTENING" >nul 2>&1
if not errorlevel 1 set "PORT_BUSY=1"

if "%PORT_BUSY%"=="1" goto port_conflict

echo   %CYAN%[~] Starting dashboard server...%R%
echo   %DIM%Dashboard will be available at %BOLD%http://localhost:3000%R%
echo.

:: Open browser
start "" "http://localhost:3000"

echo   %GREEN%[OK] Browser opened!%R%
echo   %DIM%Press Ctrl+C to stop the dashboard.%R%
echo.

"%NODE%" "%DASHBOARD%"
pause
goto :eof

:: ---------------------------------------------------------
::   ERROR HANDLERS
:: ---------------------------------------------------------
:err_nonode
echo   %RED%[ERROR] Node.js not found.%R%
echo   %YELLOW%Please run START.bat first.%R%
echo.
pause
goto :eof

:err_nodash
echo   %RED%[ERROR] Dashboard files not found!%R%
echo   %YELLOW%Expected: %DASHBOARD%%R%
echo.
pause
goto :eof

:port_conflict
echo   %YELLOW%[WARNING] Port 3000 is already in use!%R%
echo.
echo   %DIM%Another application is using port 3000.%R%
echo   %DIM%The dashboard may already be running.%R%
echo.
echo   %CYAN%1)%R% Open browser anyway (dashboard may already be running)
echo   %CYAN%2)%R% Cancel
echo.
set "PORT_CHOICE="
set /p "PORT_CHOICE=  Select (1 or 2): "
if "%PORT_CHOICE%"=="1" (
    echo.
    echo   %CYAN%[~] Opening browser...%R%
    start "" "http://localhost:3000"
    echo   %GREEN%[OK] Browser opened!%R%
    echo.
    pause
    goto :eof
)
echo.
echo   %DIM%Cancelled.%R%
pause
goto :eof
