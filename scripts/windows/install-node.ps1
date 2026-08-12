# AIEnvKit Windows 一键安装 Node.js
param(
    [string]$Mirror = "official",
    [string]$Proxy = ""
)

$NodeVersion = "20.16.0"
$Arch = "win-x64"
$ZipFile = "node-v${NodeVersion}-${Arch}.zip"

if ($Mirror -eq "npmmirror") {
    $DownloadUrl = "https://cdn.npmmirror.com/binaries/node/v${NodeVersion}/${ZipFile}"
} else {
    $DownloadUrl = "https://nodejs.org/dist/v${NodeVersion}/${ZipFile}"
}

$InstallDir = Join-Path $env:USERPROFILE ".aienvkit\node"
$TempZip = Join-Path $env:TEMP $ZipFile

Write-Host "📦 正在下载 Node.js v${NodeVersion} (${Arch})..." -ForegroundColor Cyan
Write-Host "   来源: ${Mirror} (${DownloadUrl})" -ForegroundColor Gray

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

$WebClient = New-Object System.Net.WebClient
if (-not [string]::IsNullOrWhiteSpace($Proxy)) {
    $ProxyParts = $Proxy -split "://"
    $Scheme = if ($ProxyParts.Count -gt 1) { $ProxyParts[0] } else { "http" }
    $HostPort = if ($ProxyParts.Count -gt 1) { $ProxyParts[1] } else { $ProxyParts[0] }
    $WebProxy = New-Object System.Net.WebProxy("${Scheme}://${HostPort}")
    $WebClient.Proxy = $WebProxy
}

try {
    $WebClient.DownloadFile($DownloadUrl, $TempZip)
} catch {
    Write-Host "❌ 下载失败，请检查网络连接或代理设置" -ForegroundColor Red
    Write-Host "   错误: $_" -ForegroundColor Red
    exit 1
}

Write-Host "📂 正在解压到 ${InstallDir}..." -ForegroundColor Cyan
Remove-Item -Path "$InstallDir\*" -Recurse -Force -ErrorAction SilentlyContinue
Expand-Archive -Path $TempZip -DestinationPath $InstallDir -Force

$ExtractedDir = Join-Path $InstallDir "node-v${NodeVersion}-${Arch}"
if (Test-Path $ExtractedDir) {
    Get-ChildItem -Path $ExtractedDir | Move-Item -Destination $InstallDir -Force
    Remove-Item -Path $ExtractedDir -Recurse -Force
}

Remove-Item -Path $TempZip -Force -ErrorAction SilentlyContinue

$NodeBin = Join-Path $InstallDir "node.exe"
if (-not (Test-Path $NodeBin)) {
    Write-Host "❌ Node.js 安装失败，可执行文件不存在" -ForegroundColor Red
    exit 1
}

$NodeVer = & "$NodeBin" --version
$NpmBin = Join-Path $InstallDir "npm.cmd"
$NpmVer = & "$NpmBin" --version

Write-Host "✔ Node.js 已安装: ${NodeVer}" -ForegroundColor Green
Write-Host "✔ npm 已安装: ${NpmVer}" -ForegroundColor Green
Write-Host "✅ 安装完成，路径: ${InstallDir}" -ForegroundColor Green
