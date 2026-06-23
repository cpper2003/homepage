<#
.SYNOPSIS
  启动内网穿透隧道 (ngrok)，把本地 9876 端口暴露到公网
  首次使用需要 ngrok 免费账号: https://dashboard.ngrok.com/signup
#>

$PORT = 9876

Write-Host "🔗 启动 ngrok 隧道..." -ForegroundColor Cyan

# 检查 ngrok token
$tokenFile = "$PSScriptRoot\.ngrok-token"
$ngrokToken = $null

if (Test-Path $tokenFile) {
    $ngrokToken = (Get-Content $tokenFile -Raw).Trim()
}

if (-not $ngrokToken) {
    Write-Host ""
    Write-Host "  ⚠ 首次使用需要 ngrok 免费账号" -ForegroundColor Yellow
    Write-Host "  1. 打开 https://dashboard.ngrok.com/signup 注册" -ForegroundColor White
    Write-Host "  2. 登录后访问 https://dashboard.ngrok.com/get-started/your-authtoken" -ForegroundColor White
    Write-Host "  3. 复制你的 Authtoken (格式: 数字_字母...)" -ForegroundColor White
    Write-Host ""

    $ngrokToken = Read-Host "  请粘贴你的 ngrok authtoken"

    if (-not $ngrokToken.Trim()) {
        Write-Host "  ✗ 未提供 token，退出" -ForegroundColor Red
        exit 1
    }
    $ngrokToken = $ngrokToken.Trim()
    $ngrokToken | Out-File $tokenFile -Encoding utf8 -NoNewline
    Write-Host "  ✅ Token 已保存" -ForegroundColor Green
}

Write-Host "  启动隧道..." -ForegroundColor Yellow

try {
    $result = python -c @"
from pyngrok import ngrok
ngrok.set_auth_token('$ngrokToken')
tunnel = ngrok.connect($PORT, 'http')
print('TUNNEL_URL=' + tunnel.public_url)
"@ 2>&1

    if ($result -match 'TUNNEL_URL=(https?://[^\s]+)') {
        $tunnelUrl = $Matches[1]
        Write-Host ""
        Write-Host "  ╔══════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "  ║  ✅ 隧道已建立！                    ║" -ForegroundColor Green
        Write-Host "  ║  🔗 $tunnelUrl" -ForegroundColor Cyan
        Write-Host "  ╚══════════════════════════════════════╝" -ForegroundColor Green
        Write-Host ""
        Write-Host "  将此 URL 填入网页聊天设置中" -ForegroundColor Yellow
        Write-Host "  (打开网页 → Claude 卡片 → 开始对话 → 点击顶栏设置地址)" -ForegroundColor DarkGray

        # 保存 URL
        $tunnelUrl | Out-File "$PSScriptRoot\.tunnel-url" -Encoding utf8
        Write-Host ""
        Write-Host "  按 Ctrl+C 停止隧道" -ForegroundColor DarkGray

        # 阻塞保持连接
        while ($true) { Start-Sleep -Seconds 10 }
    } else {
        Write-Host "  ✗ 启动失败:" -ForegroundColor Red
        Write-Host $result
    }
} catch {
    Write-Host "  ✗ 错误: $_" -ForegroundColor Red
}

Write-Host "`n按任意键退出..." -ForegroundColor DarkGray
$null = Read-Host
