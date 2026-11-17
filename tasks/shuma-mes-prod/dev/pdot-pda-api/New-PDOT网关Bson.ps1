<#
.SYNOPSIS
    生成 PDOT 移动盘点两条对外 API 的网关两步 bson（BP_ / WG_）。

.DESCRIPTION
    读取同目录 gateway-apis.json 里的 apis[]，逐条生成：
      步骤1 ESB 编排（BP）：P_ESBProcessModelConfig + P_ESBProcessNodeConfig + P_ActionUrlConfig
      步骤2 API 列表（WG）：P_ActionUrlConfig
    本批两条：
      PDOTInitQuery —— 初始化与清单查询（POST /thirdparty/mes/PDOTInitQuery）
      PDOTOperate   —— 单条/批量盘点、置闲置、取消（POST /thirdparty/mes/PDOTOperate）
    ESB SQL 节点 dbConnId 默认取 gateway-apis.json（当前为总装测试环境 000037），导入前人工确认指定数据源。

    流水号（禁止手写，全部由脚本向平台取）：
      ESB_FLOW_*        ← New-EsbScheduleIds.ps1（8030，appId=esb&type=FLOW）
      SYSTEM_MES_API_*  ← New-ApiListIds.ps1 -AppId system_mes（8020）
      THIRDPARTY_API_*  ← New-ApiListIds.ps1（8020）

    四个 bson 用同一个时间戳（脚本内取一次），便于按批次核对。

    鉴权：优先环境变量 ESB_IDENTITY_TOKEN；未设置则用
          .agents\config\esb-api-auth.local.json（userName/password）登录取 token。
          取号失败即报错退出，不写 REPLACE_* 占位。

.EXAMPLE
    & '.\New-PDOT网关Bson.ps1'
#>
[CmdletBinding()]
param(
    [string] $OutDir = $PSScriptRoot,
    [string] $IdentityToken = $env:ESB_IDENTITY_TOKEN,
    [string] $DbConnId = '',
    [string] $OwnerUserId = '',
    [string] $OwnerUserName = '',
    [string] $AuthConfigPath = '',
    [string] $Timestamp = '',
    [switch] $SkipTlsVerify
)

$ErrorActionPreference = 'Stop'

# ---------- 0. 依赖定位 ----------
$RepoRoot = 'E:\work'
$SkillRef = Join-Path $RepoRoot '.agents\skills\api-interface\references'
if (-not (Test-Path $SkillRef)) {
    $SkillRef = Join-Path $RepoRoot '.workbuddy\skills\api-interface\references'
}
if (-not (Test-Path $SkillRef)) {
    Write-Error "找不到 api-interface 技能 references 目录（试过 .agents / .workbuddy）"
    exit 1
}

. (Join-Path $SkillRef 'Enable-EsbTlsForInternalApi.ps1') -Force
. (Join-Path $SkillRef 'Get-GatewayBsonOutputPaths.ps1')
. (Join-Path $SkillRef 'Set-BsonOwnerAuditFields.ps1')
. (Join-Path $SkillRef 'Test-GatewayBsonTemplateLeak.ps1')

if ($SkipTlsVerify) { $env:ESB_SKIP_TLS_VERIFY = '1' }

# 未显式给 token 时，用本地凭据登录（禁止把 token 写进任何产物文件）
if ([string]::IsNullOrWhiteSpace($IdentityToken)) {
    if ([string]::IsNullOrWhiteSpace($AuthConfigPath)) {
        $AuthConfigPath = Join-Path $RepoRoot '.agents\config\esb-api-auth.local.json'
    }
    if (-not (Test-Path $AuthConfigPath)) {
        Write-Error "Set ESB_IDENTITY_TOKEN or provide credentials file: $AuthConfigPath"
        exit 1
    }
    Write-Host "登录 API 平台取 identitytoken（凭据：$AuthConfigPath）..."
    $IdentityToken = & (Join-Path $SkillRef 'Get-EsbApiIdentityToken.ps1') -ConfigPath $AuthConfigPath -PassThru
    if ([string]::IsNullOrWhiteSpace($IdentityToken)) {
        Write-Error '登录未返回 identitytoken'
        exit 1
    }
}

# ---------- 1. 读本地元数据 ----------
$jsonPath = Join-Path $OutDir 'gateway-apis.json'
if (-not (Test-Path $jsonPath)) { Write-Error "Missing gateway-apis.json: $jsonPath"; exit 1 }
$cfg = Get-Content $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json

if ([string]::IsNullOrWhiteSpace($DbConnId)) { $DbConnId = [string]$cfg.esbDbConnId }
Assert-GatewayEsbDbConnId -DbConnId $DbConnId

if ([string]::IsNullOrWhiteSpace($OwnerUserId)   -and $cfg.owner) { $OwnerUserId   = [string]$cfg.owner.userId }
if ([string]::IsNullOrWhiteSpace($OwnerUserName) -and $cfg.owner) { $OwnerUserName = [string]$cfg.owner.userName }
if ([string]::IsNullOrWhiteSpace($OwnerUserId))   { $OwnerUserId   = '1003153' }
if ([string]::IsNullOrWhiteSpace($OwnerUserName)) { $OwnerUserName = '熊思思' }
$script:OwnerUserId   = $OwnerUserId
$script:OwnerUserName = $OwnerUserName

$apis = @($cfg.apis)
if ($apis.Count -eq 0) { Write-Error 'gateway-apis.json 的 apis[] 为空'; exit 1 }
if ([string]::IsNullOrWhiteSpace($Timestamp)) { $Timestamp = Get-Date -Format 'yyMMddHHmm' }
$now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

# ---------- 2. 公共构造 ----------
function New-HexId24 {
    # 子节点 id = 24 位小写 hex（形如 Mongo ObjectId）；顶层 id 则是 "0"/"1"/"2"... 序号串
    $bytes = New-Object 'System.Byte[]' 12
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    return (-join ($bytes | ForEach-Object { $_.ToString('x2') }))
}

# paramsDocs：每个节点（含任意深度 children）都是同一套 16 键信封，children 追加在 sortNum 之后
function New-ParamChildNodes($nodes) {
    $arr = @()
    foreach ($n in $nodes) {
        $ftype = 'String'
        if ($n.fieldType) { $ftype = [string]$n.fieldType }
        $c = [ordered]@{
            id          = (New-HexId24)
            fieldName   = [string]$n.fieldName
            fieldId     = [string]$n.fieldId
            fieldType   = $ftype
            hidden      = $false
            breakFlag   = $false
            required    = [bool]$n.required
            sampleValue = if ($null -ne $n.sampleValue) { [string]$n.sampleValue } else { '' }
            enCode      = 0
            order       = 0
            "in"        = 'body'
            errorCode   = ''
            maxLength   = if ($n.maxLength) { [int]$n.maxLength } else { 0 }
            minLength   = 0
            deprecated  = $false
            sortNum     = if ($n.sortNum) { [int]$n.sortNum } else { 1 }
        }
        if ($n.children) { $c['children'] = @(New-ParamChildNodes $n.children) }
        $arr += $c
    }
    return $arr
}

function New-ParamsDocs($prms) {
    $arr = @()
    $seq = 0
    foreach ($p in $prms) {
        $ft = 'String'
        if ($p.fieldType) { $ft = [string]$p.fieldType }
        $item = [ordered]@{
            id          = [string]$seq
            fieldName   = $p.fieldName
            fieldId     = $p.fieldId
            fieldType   = $ft
            hidden      = $false
            breakFlag   = $false
            required    = [bool]$p.required
            sampleValue = [string]$p.sample
            enCode      = 0
            order       = 0
            "in"        = 'body'
            errorCode   = ''
            maxLength   = if ($p.maxLength) { [int]$p.maxLength } else { 0 }
            minLength   = 0
            deprecated  = $false
            sortNum     = [int]$p.sortNum
        }
        if ($ft -eq 'Object' -or $ft -eq 'Array') {
            if ($p.children) { $item['children'] = @(New-ParamChildNodes $p.children) }
            else             { $item['children'] = @() }
        }
        $arr += $item
        $seq++
    }
    return $arr
}

# sqlCode：过程名 / 参数名取自 gateway-apis.json 的 procedure + params[].procParam，
#          业务值一律 ${$.http.字段}（禁止写死）
function New-SqlCode([string]$procName, $prms) {
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("DECLARE @ReturnMessage NVARCHAR(MAX) = N'';")
    $lines.Add('DECLARE @ReturnValue INT;')
    $lines.Add('')
    $lines.Add("EXEC @ReturnValue = $procName")
    $argLines = New-Object System.Collections.Generic.List[string]
    $argLines.Add('    @ReturnMessage = @ReturnMessage OUTPUT')
    foreach ($p in $prms) {
        $argLines.Add(("    {0} = N'{1}'" -f [string]$p.procParam, ('${$.http.' + [string]$p.fieldId + '}')))
    }
    $lines.Add((($argLines -join ",`n") + ';'))
    $lines.Add('')
    $lines.Add('-- PDOT 两个入口过程在成功、业务失败和异常时均返回同一组固定列，无需补充结果集。')
    return ($lines -join "`n")
}

# ---------- 3. P_ActionUrlConfig 底本（必须 109 字段完整形态，deep-copy 后覆盖）----------
$ActionUrlTemplatePath = Join-Path $SkillRef 'example_gateway_step2_API列表.bson'
if (-not (Test-Path $ActionUrlTemplatePath)) { Write-Error "Missing template: $ActionUrlTemplatePath"; exit 1 }

function Get-ActionUrlTemplate {
    param([string]$Path)
    $tpl = Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    $auc = $tpl[0].P_ActionUrlConfig
    if ($auc -is [System.Array]) { $auc = $auc[0] }
    $ordered = [ordered]@{}
    foreach ($p in $auc.PSObject.Properties) { $ordered[$p.Name] = $p.Value }
    return $ordered
}

$script:TemplateFieldCount = (Get-ActionUrlTemplate $ActionUrlTemplatePath).Keys.Count
if ($script:TemplateFieldCount -ne 109) {
    Write-Error ("底本 P_ActionUrlConfig 字段数 = {0}，期望 109" -f $script:TemplateFieldCount)
    exit 1
}

function New-ActionUrlConfig($overrides) {
    $cfgAuc = Get-ActionUrlTemplate $ActionUrlTemplatePath
    foreach ($k in $overrides.Keys) {
        if (-not $cfgAuc.Contains($k)) {
            throw "覆盖键 '$k' 不在平台底本字段中 —— 疑似字段名拼错，禁止新增未知字段"
        }
        $cfgAuc[$k] = $overrides[$k]
    }
    return $cfgAuc
}

function New-OutputParamsDocs($ops, $hexPool, [ref]$idx) {
    $arr = @()
    foreach ($o in $ops) {
        $hexId = $hexPool[$idx.Value]
        $idx.Value++
        $arr += [ordered]@{
            id          = $hexId
            fieldName   = $o.fieldName
            fieldId     = $o.fieldId
            fieldType   = $o.fieldType
            must        = $true
            'in'        = 'body'
            fieldValue  = [string]$o.sample
            sampleValue = [string]$o.sample
        }
    }
    return $arr
}

# ---------- 4. 写盘 + 泄漏自检 ----------
function Write-BsonFile([string]$path, $obj, [string]$label) {
    # 顶层恒为数组（步骤1 两元素 / 步骤2 一元素）
    $json = (ConvertTo-Json -InputObject @($obj) -Depth 30 -Compress)
    if (-not $json.StartsWith('[')) { $json = "[$json]" }
    $json = Set-BsonOwnerAuditFields -Json $json -UserId $script:OwnerUserId -UserName $script:OwnerUserName
    Test-GatewayBsonTemplateLeak -Json $json -Label $label
    if ($json -match 'REPLACE_') { throw "$label 含 REPLACE_ 占位符" }
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [IO.File]::WriteAllText($path, $json, $utf8)
    Write-Host "OK => $path"
}

# ---------- 5. 已落盘件的结构自检 ----------
$script:ParamEnvelope = @('id','fieldName','fieldId','fieldType','hidden','breakFlag',
                          'required','sampleValue','enCode','order','in','errorCode',
                          'maxLength','minLength','deprecated','sortNum')

function Get-BsonActionUrlConfig([string]$path, [int]$topIndex) {
    $j = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
    $a = $j[$topIndex].P_ActionUrlConfig
    if ($a -is [System.Array]) { $a = $a[0] }
    return $a
}

function Assert-AucFieldCount([string]$path, [int]$topIndex, [string]$label) {
    $a = Get-BsonActionUrlConfig $path $topIndex
    $n = ($a.PSObject.Properties | Measure-Object).Count
    if ($n -ne $script:TemplateFieldCount) {
        throw ("{0} P_ActionUrlConfig 字段数 = {1}，不等于底本 {2} —— 平台会打不开编排！" -f $label, $n, $script:TemplateFieldCount)
    }
    Write-Host ("{0} P_ActionUrlConfig 字段数 = {1} PASS" -f $label, $n)
}

function Assert-ParamsDocsShape([string]$path, [int]$topIndex, [string]$label) {
    $a = Get-BsonActionUrlConfig $path $topIndex
    # paramsDocs 必须是数组：单入参时若塌成对象，平台按数组渲染会读不出入参（python 断言查不出这一条）
    if ($a.paramsDocs -isnot [System.Array]) {
        throw ("{0} paramsDocs 不是数组（类型 {1}）—— 单元素被塌成对象，平台读不出入参树" -f $label, $a.paramsDocs.GetType().Name)
    }
    $bad = New-Object System.Collections.ArrayList
    $ids = New-Object System.Collections.ArrayList
    $script:nodeCount = 0
    function WalkNodes($nodes, $depth) {
        foreach ($n in $nodes) {
            $script:nodeCount++
            $keys = @($n.PSObject.Properties | ForEach-Object { $_.Name })
            $exp = @($script:ParamEnvelope)
            if ($keys -contains 'children') { $exp += 'children' }
            if (($keys -join ',') -ne ($exp -join ',')) {
                [void]$bad.Add("$label depth=$depth fieldId=$($n.fieldId) keys=$($keys -join ',')")
            }
            [void]$ids.Add([string]$n.id)
            if ($n.children) { WalkNodes $n.children ($depth + 1) }
        }
    }
    WalkNodes $a.paramsDocs 1
    $dup = @($ids | Group-Object | Where-Object { $_.Count -gt 1 })
    if ($bad.Count -gt 0) {
        $bad | ForEach-Object { Write-Host "  x $_" }
        throw "$label paramsDocs 结构不符节点 = $($bad.Count) / $($script:nodeCount)（平台会读不出嵌套）"
    }
    if ($dup.Count -gt 0) { throw "$label paramsDocs 存在重复 id：$($dup.Name -join ',')" }
    Write-Host ("{0} paramsDocs 结构自检 PASS（节点 {1}，id 全唯一）" -f $label, $script:nodeCount)
}

# 出参契约自检（泄漏脚本查不出的那一类）：WG 顶层 fieldId 序列 + data.children 列名
function Assert-WgEnvelope([string]$path, $outputParams) {
    $a = Get-BsonActionUrlConfig $path 0
    $seq = @($a.outputParamsDocs | ForEach-Object { [string]$_.fieldId })
    $exp = @('state','errcode','msg','data','transactionId')
    if (($seq -join ',') -ne ($exp -join ',')) {
        throw ("WG outputParamsDocs 顶层 fieldId 序列 = [{0}]，期望 [{1}]" -f ($seq -join ','), ($exp -join ','))
    }
    $data = $a.outputParamsDocs | Where-Object { $_.fieldId -eq 'data' }
    if ($data.children -isnot [System.Array]) {
        throw ("WG data.children 不是数组（类型 {0}）" -f $data.children.GetType().Name)
    }
    $childIds = @($data.children | ForEach-Object { [string]$_.fieldId })
    $expChild = @($outputParams | ForEach-Object { [string]$_.fieldId })
    if (($childIds -join ',') -ne ($expChild -join ',')) {
        throw ("WG data.children 列 = [{0}]，期望 [{1}]" -f ($childIds -join ','), ($expChild -join ','))
    }
    Write-Host ("WG 出参契约 PASS（data.children = {0}）" -f ($childIds -join '/'))
}

# ---------- 6. python 解释器定位（结构断言用）----------
function Test-PythonExe([string]$exe, [string[]]$pre) {
    if ([string]::IsNullOrWhiteSpace($exe)) { return $false }
    $isPath = ($exe -match '[\\/]')
    if ($isPath -and -not (Test-Path $exe)) { return $false }
    if (-not $isPath -and -not (Get-Command $exe -ErrorAction SilentlyContinue)) { return $false }
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $a = @() + $pre + @('--version')
        & $exe @a 2>&1 | Out-Null
        return ($LASTEXITCODE -eq 0)
    }
    catch { return $false }
    finally { $ErrorActionPreference = $old }
}

function Resolve-PythonExe {
    $cands = New-Object System.Collections.ArrayList

    $pyCmd = Get-Command 'python' -ErrorAction SilentlyContinue
    if ($pyCmd) { [void]$cands.Add(@{ Exe = $pyCmd.Source; Pre = @() }) }
    $py3Cmd = Get-Command 'python3' -ErrorAction SilentlyContinue
    if ($py3Cmd) { [void]$cands.Add(@{ Exe = $py3Cmd.Source; Pre = @() }) }

    $verRoot = Join-Path $env:USERPROFILE '.workbuddy\binaries\python\versions'
    if (Test-Path $verRoot) {
        Get-ChildItem $verRoot -Directory -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending |
            ForEach-Object {
                $p = Join-Path $_.FullName 'python.exe'
                if (Test-Path $p) { [void]$cands.Add(@{ Exe = $p; Pre = @() }) }
            }
    }

    $pyLauncher = Get-Command 'py' -ErrorAction SilentlyContinue
    if ($pyLauncher) { [void]$cands.Add(@{ Exe = $pyLauncher.Source; Pre = @('-3') }) }

    foreach ($c in $cands) {
        if (Test-PythonExe $c.Exe $c.Pre) { return $c }
    }
    return $null
}

$checker = Join-Path $SkillRef 'Test-GatewayBsonStructure.py'
if (-not (Test-Path $checker)) { throw "Missing structure checker: $checker" }
$py = Resolve-PythonExe
if (-not $py) { throw 'python 不可用：结构断言 Test-GatewayBsonStructure.py 必须跑通才能交付' }

# ---------- 7. 逐接口生成 ----------
$summary = New-Object System.Collections.ArrayList

foreach ($api in $apis) {
    $method     = [string]$api.method
    $procName   = [string]$api.procedure
    $configName = [string]$api.configName
    if ([string]::IsNullOrWhiteSpace($method) -or [string]::IsNullOrWhiteSpace($procName)) {
        throw "gateway-apis.json 的 apis[] 缺 method / procedure：$configName"
    }
    Write-Host ''
    Write-Host ("================ {0}（{1}）================" -f $method, $configName)

    # 7.1 取流水号（禁止手写）
    Write-Host '取 ESB 编排流水号 (8030)...'
    $flow = & (Join-Path $SkillRef 'New-EsbScheduleIds.ps1') -NodeCount 5 -IdentityToken $IdentityToken
    if (-not $flow.configId) { throw "$method FLOW configId 取号失败" }

    Write-Host '取内部 REST 流水号 (8020 / system_mes)...'
    $mes = & (Join-Path $SkillRef 'New-ApiListIds.ps1') -AppId system_mes -IdentityToken $IdentityToken `
            -ExtraHexCount ([int][Math]::Max(12, (Get-GatewayOutputParamCount $api.outputParams) + 2))

    Write-Host '取对外 API 流水号 (8020 / Thirdparty)...'
    $list = & (Join-Path $SkillRef 'New-ApiListIds.ps1') -IdentityToken $IdentityToken `
            -ExtraHexCount ([int][Math]::Max(12, (Get-GatewayOutputParamCount $api.outputParams) + 8))

    if (-not $mes.configId -or -not $list.configId) { throw "$method API 流水号取号失败" }

    $paths     = Get-GatewayBsonOutputPaths -OutDir $OutDir -MethodName $method -Timestamp $Timestamp
    $nodeIds   = $flow.nodeIds          # 开始/结束/SQL/路由/路由
    $processId = $flow.processId

    # 7.2 sqlCode（业务入参全部 ${$.http.字段}）
    $sqlCode = New-SqlCode $procName $api.params
    $bodySample = [string]$api.bodySample

    # 7.3 步骤1 BP
    $i1 = 0
    $respSampleObj = $api.responseSample | ConvertTo-Json -Depth 6 | ConvertFrom-Json
    $respSampleObj | Add-Member -NotePropertyName transactionId -NotePropertyValue $list.extraHexIds[0] -Force
    $respSampleStr = ($respSampleObj | ConvertTo-Json -Depth 6)

    $step1 = @(
        [ordered]@{
            P_ESBProcessModelConfig = [ordered]@{
                categoryId            = 'ESB_CATEGORY_240927002'
                configId              = $flow.configId
                configName            = $configName
                state                 = '2'
                remark                = $configName
                transaction           = $true
                processTransaction    = 1
                logBeanId             = ''
                debug                 = 1
                processModel          = '{"nodeDataArray":[{"text":"开始","key":"E00001","nodeType":"start","locTop":86,"locLeft":386,"nodeHeight":"51px","nodeWidth":"51px","bgColor":"#2175c4","name":"E00001","nodeName":"开始节点","icon":"start-esb","titleType":"text","showNodeType":"Old","err":false,"flowType":"NewStartNode"},{"text":"结束","key":"E00002","nodeType":"end","locTop":455,"locLeft":386,"nodeHeight":"51px","nodeWidth":"50px","bgColor":"#ff6161","name":"E00002","nodeName":"结束节点","icon":"end-esb","titleType":"text","showNodeType":"Old","err":false,"flowType":"NewStartNode"},{"key":"T00001","nodeType":"sqlExecuterNode","nodeName":"执行SQL脚本","nodeText":"执行SQL脚本","tip":"执行SQL语句对数据进行处理","text":"执行SQL脚本","name":"T00001","icon":"sqlExecuterNode-esb","showNodeType":"Old","err":false,"skipChecking":"0","locLeft":386,"locTop":281,"flowType":"BoxNode","titleType":"text"}],"linkDataArray":[{"routerId":"R00001","from":"E00001","to":"T00001","label":"NO_SHOW","lineType":"Curved","pointsList":[{"x":386,"y":106.5},{"x":386,"y":238}],"edgeType":"always_execute1","edgeTipMsg":"始终执行"},{"routerId":"R00002","from":"T00001","to":"E00002","label":"NO_SHOW","lineType":"Curved","pointsList":[{"x":386,"y":324},{"x":386,"y":434.5}],"edgeType":"always_execute1","edgeTipMsg":"始终执行"}],"transform":1,"translate":{"x":0,"y":0},"detailFlag":false}'
                version               = '1.0'
                pNodeType             = 'process'
                maxRunProcess         = 1
                maxRunProcessOption   = '0'
                maxLogDay             = 30
                loadBalanceId         = ''
                pNodeId               = 'Process'
                processId             = $processId
                compensateRule        = '5,15,30,60,120'
                executeServer         = 'SingleServer'
                eventType             = 0
                eventUrl              = 'https://szapitest.szmtc.com.cn:8030/api'
                eventBody             = "{`n`"msgtype`":`"text`",`n`"text`":{`n`"content`":`"API流程名称:`${processName}`n开始时间:`${startTime}`n结束时间:`${endTime}`n`${message}`"}}"
                lockedUserId          = ''
                applicationId         = 'system_mes'
                taskLevel             = 1
                testParams            = ''
                repeatGenerationTask  = 1
                designer              = ''
                serviceCount          = 0
                runingFlag            = $false
                id                    = $processId
                appId                 = 'esb'
                createTime            = $now
                creator               = $script:OwnerUserId
                creatorName           = $script:OwnerUserName
                editTime              = $now
                editor                = $script:OwnerUserId
                editorName            = $script:OwnerUserName
            }
        },
        [ordered]@{
            P_ESBProcessNodeConfig = @(
                [ordered]@{ _id=''; appId='esb'; processId=$processId; pNodeId='E00001'; pNodeName='开始'; pNodeType='start'; applicationId='system_mes'; gatewayType=''; createTime=$now; creator=$script:OwnerUserId; creatorName=$script:OwnerUserName; expireAfterIndexTime=''; editTime=$now; editor=$script:OwnerUserId; editorName=$script:OwnerUserName; id=$nodeIds[0] },
                [ordered]@{ _id=''; appId='esb'; processId=$processId; pNodeId='E00002'; pNodeName='结束'; pNodeType='end'; applicationId='system_mes'; processEndType=''; createTime=$now; creator=$script:OwnerUserId; creatorName=$script:OwnerUserName; expireAfterIndexTime=''; editTime=$now; editor=$script:OwnerUserId; editorName=$script:OwnerUserName; id=$nodeIds[1] },
                [ordered]@{ _id=''; tableColumns=''; sqlCode=$sqlCode; pNodeName='执行SQL脚本'; pNodeId='T00001'; dbConnId=$DbConnId; responseData='1'; executerType='1'; dataJsonPath=''; methodType='select'; appendFlag=$false; appendToFieldId=''; exceptionAssert=''; compensateFlag=$false; appId='esb'; pNodeType='sqlExecuterNode'; processId=$processId; pNodeRole=''; exportParams=''; applicationId='system_mes'; createTime=$now; creator=$script:OwnerUserId; creatorName=$script:OwnerUserName; expireAfterIndexTime=''; editTime=$now; editor=$script:OwnerUserId; editorName=$script:OwnerUserName; id=$nodeIds[2] },
                [ordered]@{ _id=''; appId='esb'; processId=$processId; pNodeId='R00001'; pNodeName='路由'; pNodeType='router'; sourceId='E00001'; targetId='T00001'; routerCondition=''; async=$false; order=1; asyncFlag=$false; clearProcessMainData=$false; assertCondition=''; applicationId='system_mes'; createTime=$now; creator=$script:OwnerUserId; creatorName=$script:OwnerUserName; expireAfterIndexTime=''; editTime=$now; editor=$script:OwnerUserId; editorName=$script:OwnerUserName; id=$nodeIds[3] },
                [ordered]@{ _id=''; appId='esb'; processId=$processId; pNodeId='R00002'; pNodeName='路由'; pNodeType='router'; sourceId='T00001'; targetId='E00002'; routerCondition=''; async=$false; order=2; asyncFlag=$false; clearProcessMainData=$false; assertCondition=''; applicationId='system_mes'; createTime=$now; creator=$script:OwnerUserId; creatorName=$script:OwnerUserName; expireAfterIndexTime=''; editTime=$now; editor=$script:OwnerUserId; editorName=$script:OwnerUserName; id=$nodeIds[4] }
            )
            P_ActionUrlConfig = @(
                (New-ActionUrlConfig ([ordered]@{
                    configName               = $configName
                    configId                 = $mes.configId
                    mapUrl                   = "/system_mes/$method"
                    beanId                   = 'ESBExecuteProcessRest'
                    beanMethodName           = 'startProcess'
                    methodType               = 'POST'
                    produces                 = 'application/json;charset=utf-8'
                    consumes                 = '*/*'
                    extAttribute             = '$.T00001.data'
                    state                    = '1'
                    transaction              = $true
                    configType               = 'REST'
                    registerFlag             = 0
                    logType                  = 1
                    requestBodyFlag          = $true
                    bodyEscapeFlag           = $false
                    syncFlag                 = $true
                    scsPlugConfig            = '[]'
                    responseSample           = $respSampleStr
                    failResponseSample       = '{"state":false,"msg":"服务运行失败","errcode":500}'
                    syncAnnotation           = $true
                    remark                   = $api.remark
                    tags                     = ''
                    version                  = '1.0'
                    deprecated               = $false
                    requestBodyRequired      = $true
                    requestBodyDataType      = 'JSON'
                    requestBodySampleStr     = $bodySample
                    retryNum                 = 0
                    retrySleep               = 0
                    loadBalanceId            = ''
                    authType                 = 1
                    serializeNull            = $false
                    visibleUserIds           = ''
                    ownerUserId              = ''
                    connecterId              = ''
                    requestCompatibleFlag    = 1
                    # 单入参时 PowerShell 会把单元素数组塌成对象 ⇒ 必须 @() 兜住，否则平台读不出入参树
                    paramsDocs               = @(New-ParamsDocs $api.params)
                    responseDocs             = @()
                    outputParamsDocs         = @(New-OutputParamsDocs $api.outputParams $mes.extraHexIds ([ref]$i1))
                    publishStatus            = '0'
                    backendMethod            = '*'
                    backendUrl               = ''
                    backendConnectTimeout    = 30000
                    backendParamType         = 1
                    processId                = $processId
                    procedureId              = ''
                    bindServicesConfigId     = ''
                    isSystem                 = 0
                    source                   = 'ESB'
                    allowRetry               = 0
                    id                       = $mes.id
                    appId                    = 'system_mes'
                    createTime               = $now
                    creator                  = $script:OwnerUserId
                    creatorName              = $script:OwnerUserName
                    editTime                 = $now
                    editor                   = $script:OwnerUserId
                    editorName               = $script:OwnerUserName
                }))
            )
        }
    )

    # 7.4 步骤2 WG
    $wgResp = $api.responseSample | ConvertTo-Json -Depth 6 | ConvertFrom-Json
    $wgResp | Add-Member -NotePropertyName transactionId -NotePropertyValue $list.extraHexIds[0] -Force
    $wgRespStr = ($wgResp | ConvertTo-Json -Depth 6)

    # data.children：本过程成功结果列（与 gateway-apis.json outputParams 一致）
    $dataChildren = @()
    $ci = 5
    foreach ($o in $api.outputParams) {
        $dataChildren += [ordered]@{
            fieldId     = [string]$o.fieldId
            fieldName   = [string]$o.fieldName
            id          = $list.extraHexIds[$ci]
            fieldType   = [string]$o.fieldType
            must        = $true
            sampleValue = [string]$o.sample
        }
        $ci++
    }

    $step2OutDocs = @(
        [ordered]@{ fieldId='state'; fieldName='API平台接口调用是否成功，true成功，false失败'; id=$list.extraHexIds[1]; must=$true; "in"='query'; fieldType='Boolean'; fieldValue='true'; sampleValue='true'; children=@() },
        [ordered]@{ fieldId='errcode'; fieldName='API平台平台返回状态'; id=$list.extraHexIds[2]; must=$true; "in"='query'; fieldType='Number'; fieldValue='200'; sampleValue='200'; children=@() },
        [ordered]@{ fieldId='msg'; fieldName='API平台平台返回信息'; id=$list.extraHexIds[3]; must=$true; "in"='query'; fieldType='String'; fieldValue=''; sampleValue=''; children=@() },
        [ordered]@{ fieldId='data'; fieldName='返回数据'; id=$list.extraHexIds[4]; must=$true; "in"='query'; fieldType='Object'; fieldValue=''; sampleValue=''; children=$dataChildren },
        [ordered]@{ fieldId='transactionId'; fieldName='API平台请求id'; id=$list.extraHexIds[$ci]; must=$true; "in"='query'; fieldType='String'; fieldValue=$list.extraHexIds[0]; sampleValue=$list.extraHexIds[0]; children=@() }
    )
    if (-not $list.extraHexIds[$ci]) { throw "extraHexIds 不够用：输出字段 $($api.outputParams.Count) 个，需要下标 $ci" }

    $step2 = @(
        [ordered]@{
            P_ActionUrlConfig = (New-ActionUrlConfig ([ordered]@{
                configName               = $configName
                configId                 = $list.configId
                mapUrl                   = "/thirdparty/mes/$method"
                beanId                   = 'ServiceRegisterRest'
                beanMethodName           = 'redirectUrl'
                methodType               = 'POST'
                produces                 = 'application/json;charset=utf-8'
                consumes                 = '*'
                extAttribute             = ''
                state                    = '1'
                transaction              = $false
                configType               = 'REG'
                registerFlag             = 1
                logType                  = 2
                requestBodyFlag          = $true
                bodyEscapeFlag           = $false
                syncFlag                 = $true
                scsPlugConfig            = '[]'
                responseSample           = $wgRespStr
                failResponseSample       = '{"errcode":500,"ResponseBody":"","msg":"","state":false,"traceId":""}'
                syncAnnotation           = $true
                remark                   = $api.remark
                tags                     = ''
                categoryId               = 'THIRDPARTY_CATEGORY_220824005'
                businessClassIds         = 'BU_AREA_220825002'
                version                  = '1.0'
                parentId                 = '6a7692e609c8c94f166d6b5e'
                deprecated               = $false
                requestBodyRequired      = $true
                requestBodyDataType      = 'JSON'
                requestBodySampleStr     = $bodySample
                sqlConfigId              = ''
                filters                  = ''
                retryNum                 = 0
                retrySleep               = 0
                loadBalanceId            = 'WeightRandomServer'
                authType                 = 1
                serializeNull            = $false
                visibleUserIds           = 'sdx01'
                ownerUserId              = ''
                connecterId              = ''
                requestCompatibleFlag    = 1
                paramsDocs               = @(New-ParamsDocs $api.params)
                responseDocs             = @()
                outputParamsDocs         = $step2OutDocs
                publishStatus            = '0'
                backendMethod            = '*'
                backendUrl               = "/system_mes/$method"
                backendConnectTimeout    = 30000
                backendParamType         = 1
                processId                = ''
                procedureId              = ''
                bindServicesConfigId     = '63155a2911eb216cae787611'
                businessDataTagConfigs   = '[]'
                isSystem                 = 0
                source                   = 'GATEWAY'
                allowRetry               = 0
                id                       = $list.id
                appId                    = 'Thirdparty'
                createTime               = $now
                creator                  = $script:OwnerUserId
                creatorName              = $script:OwnerUserName
                editTime                 = $now
                editor                   = $script:OwnerUserId
                editorName               = $script:OwnerUserName
            }))
        }
    )

    # 7.5 ESB 流程侧节点字段归一（对齐平台真实导出件）
    # 流程侧与 WG 侧口径相反：布尔/序号一律字符串，空集必须 "[]"（写 "" 会让设计器弹窗打不开）
    $model = $step1[0].P_ESBProcessModelConfig
    $model['eventType'] = '0'
    $model['repeatGenerationTask'] = '1'
    $model['eventBody'] = ([string]$model['eventBody']).Replace("`r`n", '\n').Replace("`n", '\n')

    $nodes = $step1[1].P_ESBProcessNodeConfig
    $ts = [int]([datetimeoffset]::UtcNow.ToUnixTimeSeconds())
    for ($k = 0; $k -lt $nodes.Count; $k++) {
        $n = $nodes[$k]
        $n['_id'] = [ordered]@{ timestamp = $ts; counter = 9000001 + $k * 2; randomValue1 = 2100001; randomValue2 = 733 }
        switch ([string]$n['pNodeType']) {
            'sqlExecuterNode' {
                $n['exceptionAssert'] = '0'
                $n['exportParams']    = '[]'
                $n['tableColumns']    = '[]'
                $n['appendFlag']      = '1'
                $n['compensateFlag']  = '0'
            }
            'router' {
                $n['assertCondition']      = '0'
                $n['async']                = 'false'
                $n['asyncFlag']            = '0'
                $n['clearProcessMainData'] = '0'
                $n['order']                = [string]$n['order']
                $n['pNodeName']            = 'NO_SHOW'
            }
            'start' { $n['gatewayType'] = '1' }
            'end'   { $n['processEndType'] = '3' }
        }
    }

    # 7.6 写盘
    Write-BsonFile $paths.Step1 $step1 'BP'
    Write-BsonFile $paths.Step2 $step2 'WG'

    # 7.7 落盘后自检
    Assert-AucFieldCount $paths.Step1 1 'BP'
    Assert-AucFieldCount $paths.Step2 0 'WG'
    Assert-ParamsDocsShape $paths.Step1 1 'BP'
    Assert-ParamsDocsShape $paths.Step2 0 'WG'
    Assert-WgEnvelope $paths.Step2 $api.outputParams

    Write-Host ("结构断言（Test-GatewayBsonStructure.py）：{0}" -f $method)
    $chkArgs = @() + $py.Pre + @($checker, $paths.Step1, $paths.Step2)
    & $py.Exe @chkArgs
    if ($LASTEXITCODE -ne 0) { throw ("{0} 结构断言失败（返回码 {1}）" -f $method, $LASTEXITCODE) }
    Write-Host ("{0} 结构断言 PASS（返回码 0）" -f $method)

    [void]$summary.Add([pscustomobject]@{
        method       = $method
        configName   = $configName
        procedure    = $procName
        esbFlow      = $flow.configId
        processId    = $processId
        systemMesApi = $mes.configId
        apiList      = $list.configId
        bp           = $paths.Step1
        wg           = $paths.Step2
    })
}

# ---------- 8. 汇总 ----------
Write-Host ''
Write-Host '================ 流水号汇总（请核对）================'
foreach ($s in $summary) {
    Write-Host ''
    Write-Host ("[{0}] {1}" -f $s.method, $s.configName)
    Write-Host ("  ESB_FLOW       = " + $s.esbFlow)
    Write-Host ("  processId      = " + $s.processId)
    Write-Host ("  SYSTEM_MES_API = " + $s.systemMesApi)
    Write-Host ("  THIRDPARTY_API = " + $s.apiList)
    Write-Host ("  procedure      = " + $s.procedure)
    Write-Host ("  BP             = " + $s.bp)
    Write-Host ("  WG             = " + $s.wg)
}
Write-Host ''
Write-Host ("dbConnId = {0}" -f $DbConnId)
Write-Host ("负责人   = {0}/{1}" -f $script:OwnerUserId, $script:OwnerUserName)
Write-Host ("时间戳   = {0}" -f $Timestamp)
Write-Host '全部接口结构断言 PASS（返回码 0）'
