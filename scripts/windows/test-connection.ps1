# AIEnvKit Windows 连接测试脚本
param(
    [Parameter(Mandatory = $true)]
    [string]$ApiKey,

    [Parameter(Mandatory = $true)]
    [string]$BaseUrl,

    [Parameter(Mandatory = $true)]
    [string]$ModelName
)

if ([string]::IsNullOrWhiteSpace($BaseUrl) -or [string]::IsNullOrWhiteSpace($ApiKey)) {
    Write-Host "❌ API 地址和 API Key 不能为空" -ForegroundColor Red
    exit 1
}

$BaseUrl = $BaseUrl.TrimEnd('/')
Write-Host "🔌 正在测试连接: $BaseUrl" -ForegroundColor Cyan

$Headers = @{
    "Authorization" = "Bearer $ApiKey"
    "Content-Type"  = "application/json"
}

try {
    # 优先尝试 /models 接口
    $Response = Invoke-RestMethod -Uri "$BaseUrl/models" -Headers $Headers -Method GET -TimeoutSec 15
    $Count = ($Response.data | Measure-Object).Count
    Write-Host "✅ 连接成功 (HTTP 200)，可用模型数量约: $Count" -ForegroundColor Green
    Write-Host "💡 当前配置模型: $ModelName" -ForegroundColor Cyan
    exit 0
} catch {
    # /models 失败则回退到 /chat/completions
    Write-Host "⚠️ /models 接口不可用，尝试 /chat/completions..." -ForegroundColor Yellow
}

$Body = @{
    model    = $ModelName
    messages = @(
        @{ role = "user"; content = "hi" }
    )
    max_tokens = 5
} | ConvertTo-Json -Depth 3

try {
    $ChatResponse = Invoke-RestMethod -Uri "$BaseUrl/chat/completions" -Headers $Headers -Method POST -Body $Body -TimeoutSec 15
    Write-Host "✅ 连接成功 (HTTP 200)，/chat/completions 可正常访问" -ForegroundColor Green
    exit 0
} catch {
    $StatusCode = $_.Exception.Response.StatusCode.value__
    if ($null -eq $StatusCode) {
        Write-Host "❌ 无法连接到 $BaseUrl，请检查网络或代理地址" -ForegroundColor Red
    } else {
        Write-Host "❌ 连接测试失败 (HTTP $StatusCode)" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
    exit 1
}
