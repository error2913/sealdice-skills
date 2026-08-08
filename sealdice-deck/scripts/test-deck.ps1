# 牌堆端到端测试（复用 sealdice-plugin-dev 的测试脚本）
# 用法: .\scripts\test-deck.ps1 -BaseUrl http://127.0.0.1:3211
param([string]$BaseUrl = "http://127.0.0.1:3211")
& (Join-Path $PSScriptRoot "..\..\sealdice-plugin-dev\scripts\test-sealdice.ps1") -BaseUrl $BaseUrl -Only deck
