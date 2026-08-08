# 海豹 WebUI 截图脚本（无依赖，使用 Edge/Chrome 无头模式）
# 用法: .\scripts\screenshot.ps1 -Url http://127.0.0.1:3211/#/home -Out <png 路径>
param(
    [string]$Url = "http://127.0.0.1:3211/#/home",
    [string]$Out = ""
)

$ErrorActionPreference = "Stop"
if (-not $Out) { $Out = Join-Path (Get-Location) "sealdice-screenshot.png" }
$candidates = @(
    "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    "C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    "C:\Program Files\Google\Chrome\Application\chrome.exe",
    "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
)
$browser = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $browser) { throw "未找到 Edge/Chrome，请设置 BROWSER_PATH 环境变量" }
if ($env:BROWSER_PATH) { $browser = $env:BROWSER_PATH }

$profile = Join-Path $env:TEMP "sealdice-shot-$PID"
New-Item -ItemType Directory -Path $profile -Force | Out-Null
& $browser --headless=new --disable-gpu --no-first-run --user-data-dir="$profile" --window-size=1440,900 --virtual-time-budget=10000 --screenshot="$Out" "$Url" 2>$null
if (Test-Path -LiteralPath $Out) {
    Write-Host "[ok] 截图已保存: $Out"
} else {
    throw "截图失败"
}
