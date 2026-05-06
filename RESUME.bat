@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul
title OpenClaude - Resume letzte Session

set "ENGINE_DIR=%~dp0engine\"
set "USB_ROOT=%ENGINE_DIR%..\"
set "DATA_DIR=%USB_ROOT%data"
set "ENV_FILE=%DATA_DIR%\ai_settings.env"
set "NODE_DIR=%ENGINE_DIR%node-win-x64"
set "GIT_DIR=%ENGINE_DIR%git-win-x64"
set "GIT_BASH=%GIT_DIR%\bin\bash.exe"
set "OC_BIN=%ENGINE_DIR%node_modules\@gitlawb\openclaude\bin\openclaude"

set "CLAUDE_CONFIG_DIR=%DATA_DIR%\openclaude"
set "XDG_CONFIG_HOME=%DATA_DIR%\config"
set "XDG_DATA_HOME=%DATA_DIR%\app_data"

set "PATH=%NODE_DIR%;%GIT_DIR%\cmd;%GIT_DIR%\bin;%GIT_DIR%\usr\bin;%PATH%"
set "CLAUDE_CODE_GIT_BASH_PATH=%GIT_BASH%"

if not exist "%NODE_DIR%\node.exe" (
    echo [ERROR] Node.js wurde nicht gefunden: %NODE_DIR%\node.exe
    echo Bitte zuerst START.bat ausfuehren.
    pause
    exit /b 1
)

if not exist "%OC_BIN%" (
    echo [ERROR] OpenClaude wurde nicht gefunden: %OC_BIN%
    echo Bitte zuerst START.bat ausfuehren.
    pause
    exit /b 1
)

if exist "%ENV_FILE%" (
    for /f "usebackq tokens=1,* delims==" %%A in ("%ENV_FILE%") do (
        set "%%A=%%~B"
    )
) else (
    echo [WARN] Keine Provider-Konfiguration gefunden: %ENV_FILE%
)

if not "!AI_PROVIDER!"=="anthropic" (
    set "ANTHROPIC_API_KEY="
)

set "PROVIDER_ARGS="
if defined AI_PROVIDER set "PROVIDER_ARGS=--provider !AI_PROVIDER!"

pushd "%ENGINE_DIR%"
call "%NODE_DIR%\node.exe" "%OC_BIN%" !PROVIDER_ARGS! --continue
set "OC_STATUS=!ERRORLEVEL!"
popd

pause
exit /b !OC_STATUS!
