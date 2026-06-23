@echo off
chcp 65001 >nul
title Claude Code 远程控制

echo.
echo ╔══════════════════════════════════════╗
echo ║   🤖 Claude Code 远程控制         ║
echo ╚══════════════════════════════════════╝
echo.

echo [1/2] 启动 Python 服务...
start "ClaudeServer" pythonw "C:\Users\weid\my-page\server.py"
timeout /t 2 /nobreak >nul
echo        服务已启动 (端口 9876)

echo [2/2] 启动隧道...
powershell -ExecutionPolicy Bypass -File "C:\Users\weid\my-page\start-tunnel.ps1"
