# 海豹测试环境端到端脚本（v1.6.0 API 验证）
# 用法:
#   .\scripts\test-sealdice.ps1 -BaseUrl http://127.0.0.1:3211 [-Only js|reply|deck|text|package|all] [-WorkDir <临时目录>]
# 前置: 本地已运行海豹核心（v1.6.0+），WebUI 默认端口 3211；新装实例免密码可直接签入。
param(
    [string]$BaseUrl = "",
    [string]$Password = "",
    [ValidateSet("js", "reply", "deck", "text", "package", "all")] [string]$Only = "all",
    [string]$WorkDir = ""
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

# 从技能目录 .env 读取凭据（已有配置直接使用，未配置才用默认/询问）
$envMap = Read-DotEnv (Join-Path $PSScriptRoot "..\.env")
if (-not $BaseUrl) {
    $BaseUrl = if ($env:SEALDICE_PANEL_URL) { $env:SEALDICE_PANEL_URL } elseif ($envMap["SEALDICE_PANEL_URL"]) { $envMap["SEALDICE_PANEL_URL"] } else { "http://127.0.0.1:3211" }
}
if (-not $Password) {
    $Password = if ($env:SEALDICE_PANEL_PASSWORD) { $env:SEALDICE_PANEL_PASSWORD } elseif ($envMap["SEALDICE_PANEL_PASSWORD"]) { $envMap["SEALDICE_PANEL_PASSWORD"] } else { "" }
}
$script:PanelToken = if ($env:SEALDICE_PANEL_TOKEN) { $env:SEALDICE_PANEL_TOKEN } elseif ($envMap["SEALDICE_PANEL_TOKEN"]) { $envMap["SEALDICE_PANEL_TOKEN"] } else { "" }

if (-not $WorkDir) { $WorkDir = Join-Path $env:TEMP "sealdice-test-$PID" }
New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
$script:Token = ""
$script:Recent = @()

function Invoke-SealApi {
    # 使用 curl.exe：Invoke-RestMethod 对含 @ / : 的 token 会报格式错误
    param([string]$Method, [string]$Path, $Body = $null, [string]$ContentType = "application/json", [string]$FormFile = "")
    $Method = $Method.ToUpperInvariant()  # echo 路由区分大小写，-X 必须用大写 POST
    $curlArgs = @("-sf", "-X", $Method, "-H", "authorization: $script:Token", "-H", "token: $script:Token")
    if ($FormFile) {
        $curlArgs += @("-F", "file=@$FormFile")
    } elseif ($null -ne $Body) {
        $curlArgs += @("-H", "Content-Type: $ContentType", "--data-binary", $Body)
    }
    $curlArgs += "$BaseUrl/sd-api$Path"
    $out = & curl.exe $curlArgs 2>$null
    if ($LASTEXITCODE -ne 0) { throw "curl 调用失败: $Path (exit=$LASTEXITCODE)" }
    if (-not $out) { return $null }
    $text = $out -join "`n"
    try { return ($text | ConvertFrom-Json) } catch { return $text }
}

function Get-SealPasswordHash {
    # 新版（1.6+）signin：PBKDF2-SHA512(password, salt, 1000, 32)，
    # 提交 base64("v01" + salt(utf8) + [00 03 E8] + derived)，与新版面板实际行为一致
    param([string]$Password, [string]$Salt)
    $saltBytes = [System.Text.Encoding]::UTF8.GetBytes($Salt)
    $pbkdf2 = [System.Security.Cryptography.Rfc2898DeriveBytes]::new($Password, $saltBytes, 1000, [System.Security.Cryptography.HashAlgorithmName]::SHA512)
    $derived = $pbkdf2.GetBytes(32)
    $ms = [System.IO.MemoryStream]::new()
    $bw = [System.IO.BinaryWriter]::new($ms)
    $bw.Write([System.Text.Encoding]::Latin1.GetBytes("v01"))
    $bw.Write($saltBytes)
    $bw.Write([byte[]](0x00, 0x03, 0xE8))
    $bw.Write($derived)
    $bw.Flush()
    return [Convert]::ToBase64String($ms.ToArray())
}

function Connect-Seal {
    Write-Host "[env] BaseUrl=$BaseUrl"
    if ($script:PanelToken) {
        # .env 已提供解锁 token 时直接使用，跳过 signin
        $script:Token = $script:PanelToken
        Write-Host "[ok] 使用 SEALDICE_PANEL_TOKEN"
    } elseif (-not $Password) {
        # 新装未设密码实例：空密码直接签入
        $r = curl.exe -sf -X POST -H "Content-Type: application/json" --data-binary '{"password":""}' "$BaseUrl/sd-api/signin" | ConvertFrom-Json
        $script:Token = $r.token
    } else {
        # 新版（1.6+）不认明文密码：先取盐再提交 PBKDF2 哈希
        $salt = (curl.exe -sf "$BaseUrl/sd-api/signin/salt" | ConvertFrom-Json).salt
        $hash = Get-SealPasswordHash -Password $Password -Salt $salt
        $r = curl.exe -sf -X POST -H "Content-Type: application/json" --data-binary (@{ password = $hash } | ConvertTo-Json -Compress) "$BaseUrl/sd-api/signin" | ConvertFrom-Json
        $script:Token = $r.token
    }
    if (-not $script:Token) { throw "signin 失败" }
    # 新装海豹自定义回复总开关默认关闭，需要打开（幂等）
    curl.exe -sf -X POST -H "authorization: $script:Token" -H "token: $script:Token" -H "Content-Type: application/json" --data-binary '{"customReplyConfigEnable":true}' "$BaseUrl/sd-api/dice/config/set" | Out-Null
    Write-Host "[ok] 签入成功"
}

function Send-CommandTest {
    param([string]$Message, [string]$Type = "private")
    $body = @{ message = $Message; messageType = $Type } | ConvertTo-Json
    Invoke-SealApi -Method Post -Path "/dice/exec" -Body $body | Out-Null
    Start-Sleep -Milliseconds 800
    $script:Recent = Invoke-SealApi -Method Get -Path "/dice/recentMessage"
    return ($script:Recent | ForEach-Object { $_.message }) -join "`n"
}

function Get-LogText {
    $logs = Invoke-SealApi -Method Get -Path "/log/fetchAndClear"
    return ($logs | ForEach-Object { "[$($_.level)] $($_.msg)" }) -join "`n"
}

# ---------- JS 插件测试 ----------
function Test-JsPlugin {
    $plugin = @'
// ==UserScript==
// @name 测试插件
// @author 测试
// @version 1.0.0
// ==/UserScript==
let ext = seal.ext.find('test_plugin');
if (!ext) {
  ext = seal.ext.new('test_plugin', '测试', '1.0.0');
  seal.ext.register(ext);
  seal.ext.registerStringConfig(ext, 'tip', '默认提示', '提示语');
}
const cmd = seal.ext.newCmdItemInfo();
cmd.name = 'hello';
cmd.help = '.hello 测试指令';
cmd.solve = (ctx, msg, cmdArgs) => {
  seal.replyToSender(ctx, msg, '你好，世界！' + seal.ext.getStringConfig(ext, 'tip'));
  return seal.ext.newCmdExecuteResult(true);
};
ext.cmdMap['hello'] = cmd;
'@
    $jsFile = Join-Path $WorkDir "test-plugin.js"
    Set-Content -LiteralPath $jsFile -Value $plugin -Encoding UTF8

    Write-Host "--- JS: 安装 ---"
    Invoke-SealApi -Method Post -Path "/js/upload" -FormFile $jsFile | Out-Null
    Write-Host "[ok] 上传 test-plugin.js"
    Invoke-SealApi -Method Post -Path "/js/reload" | Out-Null
    Write-Host "[ok] 重载 JS"
    Start-Sleep -Seconds 3

    Write-Host "--- JS: 查看配置 ---"
    $cfgs = Invoke-SealApi -Method Get -Path "/js/get_configs"
    $cfgJson = $cfgs | ConvertTo-Json -Depth 6
    if ($cfgJson -match "test_plugin") { Write-Host "[ok] 插件配置已注册" } else { Write-Host "[warn] 未在配置中看到 test_plugin" }

    Write-Host "--- JS: 修改配置 ---"
    $item = $cfgs.test_plugin.configs[0]
    $item.value = "【已修改】"
    $setBody = @{ test_plugin = @{ pluginName = "test_plugin"; configs = @($item) } } | ConvertTo-Json -Depth 6
    Invoke-SealApi -Method Post -Path "/js/set_configs" -Body $setBody | Out-Null
    Write-Host "[ok] 修改 tip = 【已修改】"

    Write-Host "--- JS: 指令测试 ---"
    $reply = Send-CommandTest -Message ".hello"
    Write-Host "[reply] $reply"
    if ($reply -match "你好，世界！【已修改】") { Write-Host "[ok] 指令测试命中修改后的配置" } else { Write-Host "[fail] 指令测试未命中预期回复" }

    Write-Host "--- JS: 抓日志 ---"
    $logText = Get-LogText
    if ($logText.Length -gt 0) { Write-Host "[ok] 抓取日志 $($logText.Split("`n").Count) 条" } else { Write-Host "[warn] 日志为空" }

    Write-Host "--- JS: 删除插件 ---"
    Invoke-SealApi -Method Post -Path "/js/delete" -Body (@{ filename = "test-plugin.js" } | ConvertTo-Json) | Out-Null
    Invoke-SealApi -Method Post -Path "/js/reload" | Out-Null
    Start-Sleep -Seconds 2
    Write-Host "[ok] 已删除并重载"
}

# ---------- 自定义回复测试 ----------
function Test-CustomReply {
    try { Invoke-SealApi -Method Post -Path "/configs/custom_reply/file_delete" -Body (@{ filename = "测试回复.yaml" } | ConvertTo-Json) | Out-Null } catch { }
    $yaml = @'
enable: true
items:
  - enable: true
    conditions:
      - condType: textMatch
        matchType: matchExact
        value: 测试回复
    results:
      - resultType: replyToSender
        message:
          - - 收到测试回复！
            - 1
name: 测试回复.yaml
author:
  - 测试
version: ""
desc: ""
'@
    $yamlFile = Join-Path $WorkDir "测试回复.yaml"
    Set-Content -LiteralPath $yamlFile -Value $yaml -Encoding UTF8

    Write-Host "--- 回复: 上传 ---"
    Invoke-SealApi -Method Post -Path "/configs/custom_reply/file_upload" -FormFile $yamlFile | Out-Null
    Write-Host "[ok] 上传 测试回复.yaml"
    Start-Sleep -Seconds 1
    $rc = Invoke-SealApi -Method Get -Path "/configs/custom_reply?filename=测试回复.yaml"
    if ($rc.items.Count -gt 0) { Write-Host "[ok] 读取到 $($rc.items.Count) 个回复项" } else { Write-Host "[fail] 未读取到回复项" }

    Write-Host "--- 回复: 指令测试触发 ---"
    $reply = Send-CommandTest -Message "测试回复"
    Write-Host "[reply] $reply"
    if ($reply -match "收到测试回复") { Write-Host "[ok] 关键词回复命中" } else { Write-Host "[fail] 关键词回复未命中" }

    Write-Host "--- 回复: 删除 ---"
    Invoke-SealApi -Method Post -Path "/configs/custom_reply/file_delete" -Body (@{ filename = "测试回复.yaml" } | ConvertTo-Json) | Out-Null
    Write-Host "[ok] 已删除"
}

# ---------- 牌堆测试 ----------
function Test-Deck {
    try { Invoke-SealApi -Method Post -Path "/deck/delete" -Body (@{ filename = "测试牌堆.json" } | ConvertTo-Json) | Out-Null } catch { }
    $deck = @'
{
  "_title": ["测试牌堆"],
  "_author": ["测试"],
  "测试牌组": ["牌堆结果A", "牌堆结果B"]
}
'@
    $deckFile = Join-Path $WorkDir "测试牌堆.json"
    Set-Content -LiteralPath $deckFile -Value $deck -Encoding UTF8

    Write-Host "--- 牌堆: 上传 ---"
    Invoke-SealApi -Method Post -Path "/deck/upload" -FormFile $deckFile | Out-Null
    Invoke-SealApi -Method Post -Path "/deck/reload" | Out-Null
    Start-Sleep -Seconds 1
    $decks = Invoke-SealApi -Method Get -Path "/deck/list"
    if (($decks | ConvertTo-Json -Depth 4) -match "测试牌堆") { Write-Host "[ok] 牌堆已载入" } else { Write-Host "[fail] 牌堆未载入" }

    Write-Host "--- 牌堆: 抽牌测试 ---"
    $reply = Send-CommandTest -Message ".draw 测试牌组"
    Write-Host "[reply] $reply"
    if ($reply -match "牌堆结果") { Write-Host "[ok] 抽牌成功" } else { Write-Host "[fail] 抽牌未命中" }

    Write-Host "--- 牌堆: 删除 ---"
    Invoke-SealApi -Method Post -Path "/deck/delete" -Body (@{ filename = "测试牌堆.json" } | ConvertTo-Json) | Out-Null
    Invoke-SealApi -Method Post -Path "/deck/reload" | Out-Null
    Write-Host "[ok] 已删除"
}

# ---------- 自定义文案测试 ----------
function Test-CustomText {
    Write-Host "--- 文案: 读取 ---"
    $raw = curl.exe -s -H "authorization: $script:Token" -H "token: $script:Token" "$BaseUrl/sd-api/configs/customText"
    # texts 结构：分类 -> 条目 -> origin 数组 [["文本",权重], ...]（对象详情在 previewInfo 里）
    $obj = $raw | ConvertFrom-Json -AsHashtable
    $texts = $obj.texts
    $category = ($texts.Keys | Where-Object { $_ } | Select-Object -First 1)
    $catData = $texts[$category]
    $firstKey = ($catData.Keys | Where-Object { $_ -and $catData[$_] -and $catData[$_].Count -gt 0 } | Select-Object -First 1)
    if (-not $firstKey) { throw "没有可修改的文案条目" }
    $origText = $catData[$firstKey][0][0]
    Write-Host "[ok] 分类=$category 条目=$firstKey 原文=$origText"

    # 保存时需整类回传，否则会整类覆盖
    Write-Host "--- 文案: 修改 ---"
    $modified = @{}
    foreach ($k in $catData.Keys) {
        $entry = @($catData[$k] | ForEach-Object { ,@($_[0], [int]$_[1]) })
        if ($k -eq $firstKey) { $entry[0][0] = "$($entry[0][0])【已修改】" }
        $modified[$k] = $entry
    }
    $saveBody = @{ category = $category; data = $modified } | ConvertTo-Json -Depth 10
    Invoke-SealApi -Method Post -Path "/configs/customText/save" -Body $saveBody | Out-Null
    $checkRaw = curl.exe -s -H "authorization: $script:Token" -H "token: $script:Token" "$BaseUrl/sd-api/configs/customText"
    $check = $checkRaw | ConvertFrom-Json -AsHashtable
    if ($check.texts[$category][$firstKey][0][0] -match "【已修改】") {
        Write-Host "[ok] 文案修改成功并已生效"
    } else { Write-Host "[fail] 文案修改未生效" }

    Write-Host "--- 文案: 恢复 ---"
    $restore = @{}
    foreach ($k in $catData.Keys) {
        $restore[$k] = @($catData[$k] | ForEach-Object { ,@($_[0], [int]$_[1]) })
    }
    Invoke-SealApi -Method Post -Path "/configs/customText/save" -Body (@{ category = $category; data = $restore } | ConvertTo-Json -Depth 10) | Out-Null
    Write-Host "[ok] 已恢复原文"
}

# ---------- 扩展包（sealpack）测试 ----------
function Test-Package {
    Write-Host "--- 豹包: 构建 ---"
    $pkgDir = Join-Path $WorkDir "pkg"
    New-Item -ItemType Directory -Path (Join-Path $pkgDir "scripts") -Force | Out-Null
    $info = @'
format_version = "1.0.0"
[package]
id = "test/sealdice-test"
name = "测试扩展包"
version = "1.0.0"
authors = ["测试"]
[package.seal]
min_version = "1.6.0"
[permissions]
network = false
[contents]
scripts = ["scripts/*.js"]
[store]
readme = "README.md"
'@
    Set-Content -LiteralPath (Join-Path $pkgDir "info.toml") -Value $info -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $pkgDir "README.md") -Value "# 测试扩展包" -Encoding UTF8
    $mainJs = @'
let ext = seal.ext.find('test_pkg_plugin');
if (!ext) {
  ext = seal.ext.new('test_pkg_plugin', '测试', '1.0.0');
  seal.ext.register(ext);
}
const cmd = seal.ext.newCmdItemInfo();
cmd.name = 'pkghello';
cmd.help = '.pkghello 豹包内指令';
cmd.solve = (ctx, msg, cmdArgs) => {
  seal.replyToSender(ctx, msg, '豹包指令生效');
  return seal.ext.newCmdExecuteResult(true);
};
ext.cmdMap['pkghello'] = cmd;
'@
    Set-Content -LiteralPath (Join-Path $pkgDir "scripts\main.js") -Value $mainJs -Encoding UTF8
    $pkgFile = Join-Path $WorkDir "sealdice-test-1.0.0.sealpack"
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($pkgDir, $pkgFile)
    Write-Host "[ok] $pkgFile ($((Get-Item $pkgFile).Length) bytes)"

    Write-Host "--- 豹包: 安装 ---"
    $inst = curl.exe -sf -X POST -H "authorization: $script:Token" -H "token: $script:Token" -H "Content-Type: application/octet-stream" --data-binary "@$pkgFile" "$BaseUrl/sd-api/package/install-upload" | ConvertFrom-Json
    Write-Host "[ok] 安装返回: $($inst | ConvertTo-Json -Compress)"

    Write-Host "--- 豹包: 启用与重载 ---"
    Invoke-SealApi -Method Post -Path "/package/enable" -Body (@{ id = "test/sealdice-test" } | ConvertTo-Json) | Out-Null
    Invoke-SealApi -Method Post -Path "/package/reload" -Body (@{ id = "test/sealdice-test" } | ConvertTo-Json) | Out-Null
    Start-Sleep -Seconds 3
    $pkgs = Invoke-SealApi -Method Get -Path "/package/list"
    if (($pkgs | ConvertTo-Json -Depth 6) -match "sealdice-test") { Write-Host "[ok] 扩展包已列出" } else { Write-Host "[fail] 扩展包未列出" }

    Write-Host "--- 豹包: 指令测试 ---"
    $reply = Send-CommandTest -Message ".pkghello"
    Write-Host "[reply] $reply"
    if ($reply -match "豹包指令生效") { Write-Host "[ok] 豹包内指令生效" } else { Write-Host "[fail] 豹包指令未生效" }

    Write-Host "--- 豹包: 卸载 ---"
    try {
        Invoke-SealApi -Method Post -Path "/package/uninstall" -Body (@{ id = "test/sealdice-test"; mode = "full" } | ConvertTo-Json) | Out-Null
        Write-Host "[ok] 已卸载"
    } catch {
        Invoke-SealApi -Method Post -Path "/package/uninstall" -Body (@{ id = "test/sealdice-test" } | ConvertTo-Json) | Out-Null
        Write-Host "[ok] 已卸载（默认模式）"
    }
}

Connect-Seal
if ($Only -in @("js", "all")) { Test-JsPlugin }
if ($Only -in @("reply", "all")) { Test-CustomReply }
if ($Only -in @("deck", "all")) { Test-Deck }
if ($Only -in @("text", "all")) { Test-CustomText }
if ($Only -in @("package", "all")) { Test-Package }
Write-Host "`n全部完成。临时文件目录: $WorkDir"
