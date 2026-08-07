# 将 sealdice-skills 仓库中的技能同步到本机 Codex 技能目录。
# 用法：.\scripts\sync-to-codex.ps1 [-DryRun]
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$skills = @(
    'sealdice-plugin-dev',
    'sealdice-custom-reply',
    'sealdice-deck',
    'sealdice-sealpack'
)

$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
$destRoot = Join-Path $codexHome 'skills'
if (-not (Test-Path -LiteralPath $destRoot)) {
    New-Item -ItemType Directory -Path $destRoot | Out-Null
}

foreach ($skill in $skills) {
    $src = Join-Path $repoRoot $skill
    if (-not (Test-Path -LiteralPath $src)) {
        Write-Warning "跳过不存在的技能目录：$src"
        continue
    }
    $dst = Join-Path $destRoot $skill
    if ($DryRun) {
        Write-Host "[dry-run] $src -> $dst"
    } else {
        Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
        Write-Host "已同步：$skill"
    }
}

if ($DryRun) {
    Write-Host '完成（dry-run，未写入任何文件）。'
} else {
    Write-Host "完成。已同步到：$destRoot"
}
