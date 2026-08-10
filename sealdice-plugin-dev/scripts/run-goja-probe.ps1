# 海豹 JS 运行时探测脚本（配合 goja-probe.js 使用）
# 用法:
#   .\run-goja-probe.ps1 [-BaseUrl http://127.0.0.1:3211] [-Password ""] [-ProbeFile goja-probe.js] [-OutFile result.json]
# 通过 WebUI 控制台接口（/sd-api/js/execute）在真实运行环境中执行探测代码。
# 注意：/sd-api/js/execute 的源码包装为函数体，探测代码必须用顶层 return 输出结果。
# 凭据读取顺序：参数 > 环境变量 > 技能目录 .env > Codex 技能副本 .env。
param(
    [string]$BaseUrl = "",
    [string]$Password = "",
    [string]$ProbeFile = "goja-probe.js",
    [string]$OutFile = ""
)
$ErrorActionPreference = "Stop"

function Read-DotEnv {
    param([string]$Path)
    $map = @{}
    if (Test-Path -LiteralPath $Path) {
        foreach ($line in Get-Content -LiteralPath $Path) {
            $t = $line.Trim()
            if ($t -and -not $t.StartsWith("#")) {
                $i = $t.IndexOf("=")
                if ($i -gt 0) { $map[$t.Substring(0, $i).Trim()] = $t.Substring($i + 1).Trim() }
            }
        }
    }
    return $map
}

$envMap = @{}
foreach ($candidate in @(
        (Join-Path $PSScriptRoot "..\.env"),
        (Join-Path $HOME ".codex\skills\sealdice-plugin-dev\.env")
    )) {
    $m = Read-DotEnv $candidate
    foreach ($p in $m.Keys) { $envMap[$p] = $m[$p] }
}
if (-not $BaseUrl) {
    $BaseUrl = if ($env:SEALDICE_PANEL_URL) { $env:SEALDICE_PANEL_URL } elseif ($envMap["SEALDICE_PANEL_URL"]) { $envMap["SEALDICE_PANEL_URL"] } else { "" }
}
if (-not $Password) {
    $Password = if ($env:SEALDICE_PANEL_PASSWORD) { $env:SEALDICE_PANEL_PASSWORD } elseif ($envMap["SEALDICE_PANEL_PASSWORD"]) { $envMap["SEALDICE_PANEL_PASSWORD"] } else { "" }
}
if (-not $BaseUrl) { throw "未提供 WebUI 地址：请传 -BaseUrl，或配置 SEALDICE_PANEL_URL / .env" }
Write-Host "[env] BaseUrl=$BaseUrl"

$script:Token = ""
if ($env:SEALDICE_PANEL_TOKEN) { $script:Token = $env:SEALDICE_PANEL_TOKEN }
elseif ($envMap["SEALDICE_PANEL_TOKEN"]) { $script:Token = $envMap["SEALDICE_PANEL_TOKEN"] }
else {
    # v1.6+ 登录流程：先取盐，PBKDF2-SHA512(password, salt, 1000, 32)，
    # 再提交 base64("v01" + salt + [0x00,0x03,0xE8] + derived) 作为 password。
    $salt = (curl.exe -sf "$BaseUrl/sd-api/signin/salt" | ConvertFrom-Json).salt
    $saltBytes = [System.Text.Encoding]::UTF8.GetBytes($salt)
    $pbkdf2 = [System.Security.Cryptography.Rfc2898DeriveBytes]::new($Password, $saltBytes, 1000, [System.Security.Cryptography.HashAlgorithmName]::SHA512)
    $derived = $pbkdf2.GetBytes(32)
    $ms = [System.IO.MemoryStream]::new()
    $bw = [System.IO.BinaryWriter]::new($ms)
    $bw.Write([System.Text.Encoding]::Latin1.GetBytes("v01"))
    $bw.Write($saltBytes)
    $bw.Write([byte[]](0x00, 0x03, 0xE8))
    $bw.Write($derived)
    $bw.Flush()
    $hash = [Convert]::ToBase64String($ms.ToArray())
    $r = curl.exe -sf -X POST -H "Content-Type: application/json" --data-binary (@{ password = $hash } | ConvertTo-Json -Compress) "$BaseUrl/sd-api/signin" | ConvertFrom-Json
    $script:Token = $r.token
}
Write-Host "[ok] signin/token"

$probe = Get-Content -LiteralPath (Join-Path $PSScriptRoot $ProbeFile) -Raw
$body = @{ value = $probe } | ConvertTo-Json -Depth 4
$raw = curl.exe -sf -X POST -H "authorization: $script:Token" -H "token: $script:Token" -H "Content-Type: application/json" --data-binary $body "$BaseUrl/sd-api/js/execute"
Write-Host ("[raw] " + $raw)
$resp = $raw | ConvertFrom-Json
if ($resp.err) { Write-Output ("PROBE_ERR: " + $resp.err) }
$resp.ret | ConvertTo-Json -Depth 8
if ($OutFile) {
    # 只保存 ret 部分（不含实例信息等敏感字段），作为结果快照
    $resp.ret | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutFile -Encoding UTF8
    Write-Host "[ok] saved: $OutFile"
}
