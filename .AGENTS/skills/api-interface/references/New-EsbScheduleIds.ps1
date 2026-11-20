#Requires -Version 5.1
<#
.SYNOPSIS
    为 ESB 定时任务 bson 生成 configId（平台流水号）与 processId/节点 id（24 位 hex）。

.DESCRIPTION
    - configId：GET .../serialnumber/new?appId=esb&type=FLOW → serialNumber（如 ESB_FLOW_260914007）
    - processId / ModelConfig.id / 各节点 processId：本地 12 字节随机 hex（与平台导出 bson 形态一致）
    - 各 P_ESBProcessNodeConfig.id：在 processId 基础上末字节 +1..N（与仓库样例递增规律一致）

    鉴权：环境变量 ESB_IDENTITY_TOKEN（浏览器 identitytoken），或参数 -IdentityToken。
    默认基地址与编排设计器一致，可用 -BaseUrl 覆盖。

.EXAMPLE
    $env:ESB_IDENTITY_TOKEN = '<从浏览器复制>'
    .\.AGENTS\skills\api-interface\references\New-EsbScheduleIds.ps1 -NodeCount 5

.EXAMPLE
    $ids = & '.\New-EsbScheduleIds.ps1' -NodeCount 5
    $ids.configId
    $ids.processId
    $ids.nodeIds
#>
[CmdletBinding()]
param(
    [string] $BaseUrl = 'https://szapitest.szmtc.com.cn:8030',
    [string] $IdentityToken = $env:ESB_IDENTITY_TOKEN,
    [int] $NodeCount = 5,
    [switch] $SkipTlsVerify
)

$ErrorActionPreference = 'Stop'
if ($SkipTlsVerify -or $env:ESB_SKIP_TLS_VERIFY -eq '1') { $env:ESB_SKIP_TLS_VERIFY = '1' }
. (Join-Path $PSScriptRoot 'Enable-EsbTlsForInternalApi.ps1') -Force
. (Join-Path $PSScriptRoot 'Invoke-EsbPlatformSerial.ps1')

if ([string]::IsNullOrWhiteSpace($IdentityToken)) {
    Write-Error 'Set ESB_IDENTITY_TOKEN or pass -IdentityToken.'
    exit 1
}

$headers = @{
    Accept         = 'application/json'
    identitytoken  = $IdentityToken
}

$uri = "$BaseUrl/api/rest/core/serialnumber/new?appId=esb&type=FLOW"
try {
    $flowSerial = Get-EsbPlatformSerialNumber -Uri $uri -Headers $headers
}
catch {
    Write-Error "Serial API failed: $uri ; $($_.Exception.Message)"
    exit 1
}

$bytes = New-Object byte[] 12
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($bytes)
$processId = -join ($bytes | ForEach-Object { $_.ToString('x2') })

$nodeIds = New-Object System.Collections.Generic.List[string]
for ($i = 1; $i -le $NodeCount; $i++) {
    $nb = $bytes.Clone()
    $nb[11] = [byte](($nb[11] + $i) % 256)
    $nodeIds.Add((-join ($nb | ForEach-Object { $_.ToString('x2') })))
}

[PSCustomObject]@{
    FlowConfigId = $flowSerial
    configId     = $flowSerial
    processId    = $processId
    nodeIds      = $nodeIds.ToArray()
    fetchedAt    = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    apiBaseUrl   = $BaseUrl
}
