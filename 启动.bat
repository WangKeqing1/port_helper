@echo off
chcp 65001 >nul
cd /d "%~dp0build\windows\x64\runner\Release"
if not exist "port_helper.exe" (
    echo [端口助手] 还没构建，先执行：flutter build windows --release
    pause
    exit /b 1
)
start "" "port_helper.exe"
