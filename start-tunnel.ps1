<#
.SYNOPSIS
  启动内网穿透隧道，把本地 9876 端口暴露到公网
  支持多种隧道方式，自动尝试直到成功
#>

$PORT = 9876
$TUNNEL_DIR = "C:\Users\weid\my-page"

Write-Host "🔗 正在建立隧道..." -ForegroundColor Cyan

# ====== 方法 1: cloudflared ======
$cloudflared = "$TUNNEL_DIR\cloudflared.exe"
if (Test-Path $cloudflared) {
    Write-Host "  尝试 cloudflared..." -ForegroundColor Yellow
    try {
        $proc = Start-Process -FilePath $cloudflared -ArgumentList "tunnel", "--url", "http://localhost:$PORT", "--no-autoupdate" -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\cf-output.txt" -RedirectStandardError "$env:TEMP\cf-error.txt"
        Start-Sleep 5

        # 从输出中提取 trycloudflare.com URL
        $output = Get-Content "$env:TEMP\cf-output.txt" -Raw -ErrorAction SilentlyContinue
        $err = Get-Content "$env:TEMP\cf-error.txt" -Raw -ErrorAction SilentlyContinue
        $all = ($output + "`n" + $err)

        if ($all -match 'https://[a-z0-9-]+\.trycloudflare\.com') {
            $tunnelUrl = $Matches[0]
            Write-Host ""
            Write-Host "  ╔══════════════════════════════════════╗" -ForegroundColor Green
            Write-Host "  ║  ✅ 隧道已建立！                    ║" -ForegroundColor Green
            Write-Host "  ║  🔗 $tunnelUrl" -ForegroundColor Cyan
            Write-Host "  ╚══════════════════════════════════════╝" -ForegroundColor Green
            Write-Host ""
            Write-Host "  请将此 URL 填入网页聊天设置中" -ForegroundColor Yellow
            Write-Host "  按 Ctrl+C 停止隧道" -ForegroundColor DarkGray

            # 保存到文件供后续使用
            $tunnelUrl | Out-File "$TUNNEL_DIR\.tunnel-url" -Encoding utf8

            # 阻塞等待
            $proc.WaitForExit()
            return
        }
        Write-Host "  cloudflared 已启动但未检测到 URL，检查 $env:TEMP\cf-output.txt" -ForegroundColor Yellow
        Get-Content "$env:TEMP\cf-output.txt" -ErrorAction SilentlyContinue | Select-Object -Last 10
    } catch {
        Write-Host "  cloudflared 启动失败" -ForegroundColor Red
    }
}

# ====== 方法 2: SSH 隧道 (serveo) ======
Write-Host "  尝试 serveo.net..." -ForegroundColor Yellow
$sshPath = "C:\Users\weid\PortableGit\usr\bin\ssh.exe"
if (Test-Path $sshPath) {
    Write-Host ""
    Write-Host "  运行以下命令 (在新终端中):" -ForegroundColor Cyan
    Write-Host "  $sshPath -R 80:localhost:$PORT serveo.net" -ForegroundColor White
    Write-Host "  访问 URL 会在连接后显示" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  或者用 localhost.run:" -ForegroundColor DarkGray
    Write-Host "  $sshPath -R 80:localhost:$PORT nokey@localhost.run" -ForegroundColor White
} else {
    Write-Host "  未找到 SSH 客户端" -ForegroundColor Red
}

# ====== 方法 3: 本地局域网 (备用) ======
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -like "*WLAN*" -or $_.InterfaceAlias -like "*Wi*" } | Select-Object -First 1).IPAddress
if ($ip) {
    Write-Host ""
    Write-Host "  📱 局域网访问 (手机连同一 WiFi):" -ForegroundColor DarkGray
    Write-Host "  http://${ip}:$PORT" -ForegroundColor White
}

Write-Host ""
Write-Host "按任意键退出..." -ForegroundColor DarkGray
$null = Read-Host
