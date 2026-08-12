# AIEnvKit Windows 配置恢复脚本
$BackupDir = Join-Path $env:USERPROFILE ".aienvkit\backups"

if (-not (Test-Path $BackupDir)) {
    Write-Host "❌ 没有找到备份目录" -ForegroundColor Red
    exit 1
}

$LatestSettings = Get-ChildItem -Path $BackupDir -Filter "settings_*.json" -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$LatestProfile = Get-ChildItem -Path $BackupDir -Filter "powershell_profile_*.bak" -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1

$Restored = $false

if ($LatestSettings) {
    $ClaudeSettingsDir = Join-Path $env:USERPROFILE ".claude"
    New-Item -ItemType Directory -Force -Path $ClaudeSettingsDir | Out-Null
    Copy-Item $LatestSettings.FullName (Join-Path $ClaudeSettingsDir "settings.json") -Force
    Write-Host "✔ 已恢复 Claude Code 配置: $($LatestSettings.FullName)" -ForegroundColor Green
    $Restored = $true
}

if ($LatestProfile) {
    $ProfilePath = $PROFILE
    if ($ProfilePath) {
        Copy-Item $LatestProfile.FullName $ProfilePath -Force
        Write-Host "✔ 已恢复 PowerShell profile: $($LatestProfile.FullName)" -ForegroundColor Green
        $Restored = $true
    }
}

if (-not $Restored) {
    Write-Host "❌ 没有找到可恢复的备份" -ForegroundColor Red
    exit 1
}

Write-Host "✅ 配置已恢复到最近一次的备份状态" -ForegroundColor Green
Write-Host "💡 请重新打开 PowerShell/终端使环境变量生效" -ForegroundColor Yellow
