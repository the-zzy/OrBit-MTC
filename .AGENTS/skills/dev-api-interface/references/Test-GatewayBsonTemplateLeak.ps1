#Requires -Version 5.1
<#
.SYNOPSIS
    网关 bson 禁止残留样例接口的成功/失败文案。
    responseSample 必须是「本接口调用成功」的返回，不是模板默认值。
#>
function Test-GatewayBsonTemplateLeak {
    param(
        [Parameter(Mandatory = $true)][string] $Json,
        [Parameter(Mandatory = $true)][string] $Label
    )
    $bad = @(
        '亚马逊AUTOTEST',
        'YMXUploadFileSetObaTested',
        '总装_AUTOTEST',
        'TEST_YMX_OBA_001',
        'obaTested 已是 TRUE',
        'TESTLOT00002'
    )
    foreach ($b in $bad) {
        if ($Json.Contains($b)) {
            throw ("Template leak ($Label): '$b'. responseSample / outputParamsDocs must be THIS API successful response, not the example.")
        }
    }
}
