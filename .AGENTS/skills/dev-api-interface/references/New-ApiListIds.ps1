#Requires -Version 5.1
<#
.SYNOPSIS
    为 API 网关「步骤2 API列表」bson 生成 configId（平台流水号）与文档 id（24 位 hex）。

.DESCRIPTION
    configId：GET {ApiBaseUrl}/api/rest/core/serialnumber/new?appId=Thirdparty&type=API
    → serialNumber（如 THIRDPARTY_API_260914001）

    步骤2 bson 的 P_ActionUrlConfig.id、outputParamsDocs[].id 是 24 位 hex，
    不是 serialNumber，由本脚本本地生成。

    鉴权：环境变量 ESB_IDENTITY_TOKEN（API 平台 identitytoken），或 -IdentityToken。
    禁止把 token 写入仓库或 bson。

    默认基地址与用户提供的 API 平台一致：https://szapitest.szmtc.com.cn:8020
    （ESB 编排 FLOW 仍走 8030，见 New-EsbScheduleIds.ps1）

.EXAMPLE
    $env:ESB_IDENTITY_TOKEN = '<从 API 平台 F12 复制 identitytoken>'
    $ids = & '.\New-ApiListIds.ps1'
    $ids.configId   # THIRDPARTY_API_...
    $ids.id         # 填 P_ActionUrlConfig.id

.EXAMPLE
    # 步骤1 内部 REST 的 configId（SYSTEM_MES_API_*）
    $ids = & '.\New-ApiListIds.ps1' -AppId system_mes
#>
[CmdletBinding()]
param(
    [string] $ApiBaseUrl = 'https://szapitest.szmtc.com.cn:8020',
    [string] $IdentityToken = $env:ESB_IDENTITY_TOKEN,
    [ValidateSet('Thirdparty', 'system_mes')]
    [string] $AppId = 'Thirdparty',
    [string] $Type = 'API',
    [int] $ExtraHexCount = 8,
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
    Accept        = 'application/json'
    identitytoken = $IdentityToken
}

$uri = "$ApiBaseUrl/api/rest/core/serialnumber/new?appId=$AppId&type=$Type"
try {
    $apiSerial = Get-EsbPlatformSerialNumber -Uri $uri -Headers $headers
}
catch {
    Write-Error "Serial API failed: $uri ; $($_.Exception.Message)"
    exit 1
}

function NewHexId24 {
    param()
    $bytes = New-Object byte[] 12
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($bytes)
    return (-join ($bytes | ForEach-Object { $_.ToString('x2') }))
}

$extra = New-Object System.Collections.Generic.List[string]
for ($i = 0; $i -lt $ExtraHexCount; $i++) {
    $extra.Add((NewHexId24))
}

$result = [PSCustomObject]@{
    ApiConfigId = $apiSerial
    configId    = $apiSerial
    id          = (NewHexId24)
    extraHexIds = $extra.ToArray()
    appId       = $AppId
    type        = $Type
    fetchedAt   = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    apiBaseUrl  = $ApiBaseUrl
}

$result
