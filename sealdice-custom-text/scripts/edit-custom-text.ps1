# 自定义文案：读取 -> 修改 -> 验证 -> 恢复（实测可用，v1.6.0）
# 用法:
#   .\scripts\edit-custom-text.ps1 -BaseUrl http://127.0.0.1:3211 -Category COC -Key 判定_大失败 -NewText "新文案"
# 说明: 保存会整类覆盖，脚本会自动整类回传；结束后恢复原值。
param(
    [string]$BaseUrl = "",
    [string]$Category = "COC",
    [string]$Key = "",
    [string]$NewText = "",
    [switch]$RestoreOnly
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

$envMap = Read-DotEnv (Join-Path $PSScriptRoot "..\..\sealdice-plugin-dev\.env")
if (-not $BaseUrl) {
    $BaseUrl = if ($env:SEALDICE_PANEL_URL) { $env:SEALDICE_PANEL_URL } elseif ($envMap["SEALDICE_PANEL_URL"]) { $envMap["SEALDICE_PANEL_URL"] } else { "http://127.0.0.1:3211" }
}
$password = if ($env:SEALDICE_PANEL_PASSWORD) { $env:SEALDICE_PANEL_PASSWORD } elseif ($envMap["SEALDICE_PANEL_PASSWORD"]) { $envMap["SEALDICE_PANEL_PASSWORD"] } else { "" }

$token = (curl.exe -sf -X POST -H "Content-Type: application/json" --data-binary (@{ password = $password } | ConvertTo-Json) "$BaseUrl/sd-api/signin" | ConvertFrom-Json).token
if (-not $token) { throw "signin 失败（已设密码实例需先在 WebUI 解锁，见 sealdice-plugin-dev 的 test-notes.md）" }

function Get-Texts {
    $raw = curl.exe -s -H "authorization: $token" -H "token: $token" "$BaseUrl/sd-api/configs/customText"
    return ($raw | ConvertFrom-Json -AsHashtable).texts
}

function Save-Category {
    param($Cat, $Data)
    $body = @{ category = $Cat; data = $Data } | ConvertTo-Json -Depth 10
    curl.exe -sf -X POST -H "authorization: $token" -H "token: $token" -H "Content-Type: application/json" --data-binary $body "$BaseUrl/sd-api/configs/customText/save" | Out-Null
}

$texts = Get-Texts
if (-not $texts.ContainsKey($Category)) { throw "分类不存在: $Category（可选: $($texts.Keys -join ', ')）" }
$catData = $texts[$Category]
if (-not $Key) { $Key = ($catData.Keys | Where-Object { $_ -and $catData[$_] -and $catData[$_].Count -gt 0 } | Select-Object -First 1) }
if (-not $catData.ContainsKey($Key)) { throw "条目不存在: $Key" }

$original = @{}
foreach ($k in $catData.Keys) {
    $original[$k] = @($catData[$k] | ForEach-Object { ,@($_[0], [int]$_[1]) })
}

Write-Host "原文: $($original[$Key][0][0])"
if (-not $RestoreOnly) {
    $modified = @{}
    foreach ($k in $original.Keys) {
        $entry = @($original[$k] | ForEach-Object { ,@($_[0], [int]$_[1]) })
        if ($k -eq $Key) { $entry[0][0] = $NewText }
        $modified[$k] = $entry
    }
    Save-Category -Cat $Category -Data $modified
    $check = Get-Texts
    if ($check[$Category][$Key][0][0] -eq $NewText) {
        Write-Host "[ok] 修改成功并已生效: $($check[$Category][$Key][0][0])"
    } else {
        Write-Host "[fail] 修改未生效: $($check[$Category][$Key][0][0])"
    }
}

Save-Category -Cat $Category -Data $original
Write-Host "[ok] 已恢复原值: $($original[$Key][0][0])"
