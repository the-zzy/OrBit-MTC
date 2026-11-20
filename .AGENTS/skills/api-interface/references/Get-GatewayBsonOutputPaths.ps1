#Requires -Version 5.1
<#
.SYNOPSIS
  API 网关两步 bson 输出文件名（项目统一规则）。

.DESCRIPTION
  步骤1 ESB 编排：BP_{接口名称}_yyMMddHHmm.bson
  步骤2 API 列表：WG_{接口名称}_yyMMddHHmm.bson
  「接口名称」= gateway-apis.json apis[].method（与 mapUrl 方法英文名一致）。
#>
function Get-GatewayBsonOutputPaths {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $OutDir,
        [Parameter(Mandatory = $true)]
        [string] $MethodName,
        [string] $Timestamp = ''
    )
    if ([string]::IsNullOrWhiteSpace($MethodName)) {
        throw 'Get-GatewayBsonOutputPaths: MethodName is required (apis[].method).'
    }
    if ([string]::IsNullOrWhiteSpace($Timestamp)) {
        $Timestamp = Get-Date -Format 'yyMMddHHmm'
    }
    $safe = $MethodName.Trim()
    @{
        Step1 = Join-Path $OutDir ('BP_' + $safe + '_' + $Timestamp + '.bson')
        Step2 = Join-Path $OutDir ('WG_' + $safe + '_' + $Timestamp + '.bson')
        Timestamp = $Timestamp
    }
}

function Assert-GatewayEsbDbConnId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $DbConnId
    )
    if ([string]::IsNullOrWhiteSpace($DbConnId)) {
        throw 'Missing esbDbConnId in gateway-apis.json or -DbConnId'
    }
    if ($DbConnId -match 'REPLACE_') {
        throw @"
esbDbConnId 仍是占位符「$DbConnId」。请在 gateway-apis.json 填写 000037（默认测试数据源），导入 ESB 前由人工在平台确认「指定数据源」。
规范见：.AGENTS/skills/api-interface/references/gateway-bson.md
"@
    }
}

function Get-GatewayOutputParamCount {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        $OutputParams
    )
    if ($null -eq $OutputParams) { return 0 }
    if ($OutputParams -is [System.Collections.ICollection]) { return $OutputParams.Count }
    return @($OutputParams).Count
}
