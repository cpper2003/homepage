@echo off
chcp 65001 >nul
title Claude Code 远程控制

echo.
echo ╔══════════════════════════════════════╗
echo ║   🤖 Claude Code 远程控制         ║
echo ╚══════════════════════════════════════╝
echo.

echo [提示] 需要先注册免费 ngrok 账号获取 token:
echo   https://dashboard.ngrok.com/signup
echo   登录后在 https://dashboard.ngrok.com/get-started/your-authtoken 复制 token
echo   首次运行 start-tunnel.ps1 会提示输入 token，只需输入一次
echo.
echo [1/2] 启动 Python 服务...
start "ClaudeServer" pythonw "C:\Users\weid\my-page\server.py"
timeout /t 3 /nobreak >nul
echo        服务已启动 (端口 9876)

echo [2/2] 启动 ngrok 隧道...
powershell -ExecutionPolicy Bypass -File "C:\Users\weid\my-page\start-tunnel.ps1"
