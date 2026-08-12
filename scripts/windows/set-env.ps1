# AIEnvKit Windows 环境配置脚本
param(
    [Parameter(Mandatory = $true)]
    [string]$ApiKey,

    [Parameter(Mandatory = $true)]
    [string]$BaseUrl,

    [Parameter(Mandatory = $true)]
    [string]$ModelName
)

if ([string]::IsNullOrWhiteSpace($ApiKey) -or [string]::IsNullOrWhiteSpace($BaseUrl) -or [string]::IsNullOrWhiteSpace($ModelName)) {
    Write-Host "❌ API Key、API 地址和模型名称不能为空" -ForegroundColor Red
    exit 1
}

Write-Host "🚀 AIEnvKit 开始配置 Claude 环境..." -ForegroundColor Cyan

$DefaultSonnetModel = $ModelName
$DefaultHaikuModel = $ModelName
$SubagentModel = $ModelName

# 1. 检测 Node.js / npm 并安装/升级 Claude Code CLI
$NodeCmd = Get-Command "node" -ErrorAction SilentlyContinue
$NpmCmd = Get-Command "npm" -ErrorAction SilentlyContinue

if (-not $NodeCmd -or -not $NpmCmd) {
    Write-Host "❌ 未检测到 Node.js 或 npm，请先安装 Node.js" -ForegroundColor Red
    exit 1
}

Write-Host "✔ Node.js 已安装: $(node --version)" -ForegroundColor Green
Write-Host "✔ npm 已安装: $(npm --version)" -ForegroundColor Green

Write-Host "📦 正在安装/升级 Claude Code CLI..." -ForegroundColor Yellow
try {
    npm install -g @anthropic-ai/claude-code
    Write-Host "✔ Claude Code CLI 已就绪" -ForegroundColor Green
} catch {
    Write-Host "⚠️ 安装 Claude Code CLI 失败：$_" -ForegroundColor Yellow
}

# 2. 设置用户级环境变量
Write-Host "🔧 正在设置用户环境变量..." -ForegroundColor Cyan

function Set-UserEnvVar {
    param([string]$Name, [string]$Value)
    [Environment]::SetEnvironmentVariable($Name, $Value, "User")
    Write-Host "  ✔ $Name = $Value" -ForegroundColor Green
}

Set-UserEnvVar -Name "ANTHROPIC_AUTH_TOKEN" -Value $ApiKey
Set-UserEnvVar -Name "ANTHROPIC_BASE_URL" -Value $BaseUrl
Set-UserEnvVar -Name "ANTHROPIC_MODEL" -Value $ModelName
Set-UserEnvVar -Name "ANTHROPIC_DEFAULT_SONNET_MODEL" -Value $DefaultSonnetModel
Set-UserEnvVar -Name "ANTHROPIC_DEFAULT_HAIKU_MODEL" -Value $DefaultHaikuModel
Set-UserEnvVar -Name "CLAUDE_CODE_SUBAGENT_MODEL" -Value $SubagentModel

# 3. 创建备份目录并备份 PowerShell profile
$BackupDir = Join-Path $env:USERPROFILE ".aienvkit\backups"
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null

$ProfilePath = $PROFILE
if (Test-Path $ProfilePath) {
    $BackupFile = Join-Path $BackupDir "powershell_profile_$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"
    Copy-Item $ProfilePath $BackupFile -Force
    Write-Host "✔ 已备份 PowerShell profile: $BackupFile" -ForegroundColor Green
}

# 4. 在 PowerShell profile 中写入环境变量
$Marker = "# AIEnvKit auto-generated config"
$EndMarker = "# AIEnvKit config end"

if (-not (Test-Path $ProfilePath)) {
    New-Item -ItemType File -Path $ProfilePath -Force | Out-Null
}

$ProfileContent = Get-Content $ProfilePath -Raw -ErrorAction SilentlyContinue
if ([string]::IsNullOrEmpty($ProfileContent)) { $ProfileContent = "" }

# 移除旧的 AIEnvKit 配置块
$Pattern = "(?s)$Marker.*?$EndMarker\r?\n?"
$ProfileContent = [regex]::Replace($ProfileContent, $Pattern, "").Trim()

$NewBlock = @"

$Marker
`$env:ANTHROPIC_AUTH_TOKEN = "$ApiKey"
`$env:ANTHROPIC_BASE_URL = "$BaseUrl"
`$env:ANTHROPIC_MODEL = "$ModelName"
`$env:ANTHROPIC_DEFAULT_SONNET_MODEL = "$DefaultSonnetModel"
`$env:ANTHROPIC_DEFAULT_HAIKU_MODEL = "$DefaultHaikuModel"
`$env:CLAUDE_CODE_SUBAGENT_MODEL = "$SubagentModel"
$EndMarker
"@

Set-Content -Path $ProfilePath -Value "$ProfileContent$NewBlock" -Force -Encoding UTF8
Write-Host "✔ PowerShell profile 已更新: $ProfilePath" -ForegroundColor Green

# 5. 写入 Claude Code settings.json
$ClaudeSettingsDir = Join-Path $env:USERPROFILE ".claude"
$ClaudeSettings = Join-Path $ClaudeSettingsDir "settings.json"
New-Item -ItemType Directory -Force -Path $ClaudeSettingsDir | Out-Null

if (Test-Path $ClaudeSettings) {
    $BackupSettings = Join-Path $BackupDir "settings_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    Copy-Item $ClaudeSettings $BackupSettings -Force
}

$SettingsJson = @{
    env = @{
        ANTHROPIC_AUTH_TOKEN = $ApiKey
        ANTHROPIC_BASE_URL = $BaseUrl
        ANTHROPIC_MODEL = $ModelName
        ANTHROPIC_DEFAULT_SONNET_MODEL = $DefaultSonnetModel
        ANTHROPIC_DEFAULT_HAIKU_MODEL = $DefaultHaikuModel
        CLAUDE_CODE_SUBAGENT_MODEL = $SubagentModel
    }
} | ConvertTo-Json -Depth 3

Set-Content -Path $ClaudeSettings -Value $SettingsJson -Force -Encoding UTF8
Write-Host "✔ Claude Code 配置已写入 $ClaudeSettings" -ForegroundColor Green

# 6. 同步设置当前进程环境变量
$env:ANTHROPIC_AUTH_TOKEN = $ApiKey
$env:ANTHROPIC_BASE_URL = $BaseUrl
$env:ANTHROPIC_MODEL = $ModelName
$env:ANTHROPIC_DEFAULT_SONNET_MODEL = $DefaultSonnetModel
$env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $DefaultHaikuModel
$env:CLAUDE_CODE_SUBAGENT_MODEL = $SubagentModel

Write-Host "✅ Windows 环境配置完成！" -ForegroundColor Green
Write-Host "💡 提示：请重新打开 PowerShell/终端，或运行 `$PROFILE 使环境变量生效。" -ForegroundColor Yellow
