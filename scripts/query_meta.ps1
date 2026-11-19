#requires -Version 5.1
<#
架构表快速查询（只读）。

用法：
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/query_meta.ps1 -Env jiban-mes-prod -Action plugin -Key AGUA
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/query_meta.ps1 -Env jiban-mes-prod -Action txn -Key AGUA
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/query_meta.ps1 -Env jiban-mes-prod -Action mobile -Key CKDYN
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/query_meta.ps1 -Env jiban-mes-prod -Action query -Key ACSN
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/query_meta.ps1 -Env jiban-mes-prod -Action search -Key 锡膏
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/query_meta.ps1 -Env jiban-mes-prod -Action proc -Key AlreadyCancelSNQueryDoMethod

Action：
  plugin   按插件命令查 SysPlugIn + OrDroidPlugin
  txn      按插件命令查静态事务对象、字段、按钮
  mobile   按插件命令查移动事务对象、字段、按钮
  query    按插件命令或元对象名查查询元对象：元字段组 + 条件 + 按钮
  groups   按 MetadataId 查元字段组
  fields   按 MetadataId 查 SysMetadataQuery 条件
  methods  按 MetadataId 或 MetadataFieldGroupId 查 SysMetadataMethod
  params   按事务对象名/ID 查 MESTxnObject 或 MobileObject 的字段和按钮
  search   按名称模糊搜索插件、元对象、事务对象、移动对象、SysObject
  menu     按插件命令查应用/菜单组
  proc     按过程名查定义
  sql      执行一条只读 SELECT（禁止写操作）

输出 UTF-8 JSON。
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Env,

    [Parameter(Mandatory = $true)]
    [ValidateSet('plugin', 'txn', 'mobile', 'query', 'groups', 'fields', 'methods', 'params', 'search', 'menu', 'proc', 'sql')]
    [string]$Action,

    [string]$Key = '',

    [string]$Sql = '',

    [int]$Limit = 200
)

$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent
$catalogPath = Join-Path $root "db/catalog/$Env"
$secretPath = Join-Path $root "secrets/$Env.env"

function Read-EnvFile([string]$path) {
    $values = @{}
    if (-not (Test-Path $path)) { return $values }
    foreach ($line in Get-Content $path -Encoding UTF8) {
        if ($line -notmatch '=' -or $line.StartsWith('#')) { continue }
        $key, $raw = $line -split '=', 2
        $values[$key.Trim()] = $raw.Trim().Trim("'").Trim('"')
    }
    return $values
}

function Write-Result($payload) {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
    Write-Output ($payload | ConvertTo-Json -Depth 10)
}

function Convert-Cell($value) {
    if ($value -is [System.DBNull]) { return $null }
    if ($value -is [datetime]) { return $value.ToString('yyyy-MM-dd HH:mm:ss') }
    if ($value -is [byte[]]) { return '0x' + [BitConverter]::ToString($value).Replace('-', '') }
    return $value
}

function Read-Rows($reader) {
    $rows = New-Object System.Collections.ArrayList
    while ($reader.Read()) {
        $row = [ordered]@{}
        for ($i = 0; $i -lt $reader.FieldCount; $i++) {
            $row[$reader.GetName($i)] = Convert-Cell ($reader.GetValue($i))
        }
        [void]$rows.Add($row)
    }
    $reader.Close()
    return ,$rows.ToArray()
}

function Get-Cell($row, [string]$name) {
    if ($null -eq $row) { return $null }
    if ($row -is [System.Collections.IDictionary]) { return $row[$name] }
    return $row.$name
}

function Get-TagName([string]$text, [string]$tag) {
    $match = [regex]::Match($text, '\[' + [regex]::Escape($tag) + ':([^\]\[]+)')
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return ''
}

if (-not (Test-Path $catalogPath) -or -not (Test-Path $secretPath)) {
    Write-Result ([ordered]@{ action = $Action; env = $Env; error = "没有 $Env 的库配置" })
    exit 1
}
if ($Action -ne 'sql' -and -not $Key.Trim()) {
    Write-Result ([ordered]@{ action = $Action; env = $Env; error = '缺少 -Key' })
    exit 1
}

$catalog = Read-EnvFile $catalogPath
$secrets = Read-EnvFile $secretPath
$dbHost = if ($secrets['DB_HOST']) { $secrets['DB_HOST'] } else { $catalog['HOST'] }
$dbPort = if ($secrets['DB_PORT']) { $secrets['DB_PORT'] } else { '1433' }
$connectionString = "Server=$dbHost,$dbPort;Database=$($catalog['DB']);User ID=$($secrets['DB_USER']);Password=$($secrets['DB_PASSWORD']);Connect Timeout=20"

$conn = New-Object System.Data.SqlClient.SqlConnection $connectionString

function Run-Query([string]$sql, [hashtable]$parameters = @{}) {
    $command = $conn.CreateCommand()
    $command.CommandText = $sql
    $command.CommandTimeout = 120
    foreach ($name in $parameters.Keys) {
        $parameter = $command.Parameters.Add("@$name", [System.Data.SqlDbType]::NVarChar, -1)
        $parameter.Value = [string]$parameters[$name]
    }
    $reader = $command.ExecuteReader()
    return Read-Rows $reader
}

function Get-StaticObject([string]$objectName) {
    $objects = Run-Query @"
SELECT RTRIM(MESTxnObjectId) AS ObjectId, MESTxnObjectName, MESTxnObjectDesc,
       IsActivity, MESTxnObjectType, ColumnCount, FieldWidth, FieldSpace,
       IsThirdDllUsage, ThirdDllFileName, DTxnSubmitTxn, DTxnSubmitParameter,
       IsDefaultMESTxn, IsStaticRun, IsUserUI, IsRunObjectScript,
       LEN(ISNULL(ObjectScript, '')) AS ScriptLength,
       AccessCode, SOPGroupId
FROM dbo.MESTxnObject WITH (NOLOCK)
WHERE RTRIM(MESTxnObjectName) = @name
"@ @{ name = $objectName }

    if ($objects.Count -eq 0) {
        return [ordered]@{ name = $objectName; error = '没有这个静态事务对象' }
    }
    if ($objects.Count -gt 1) {
        return [ordered]@{ name = $objectName; error = '名称对应多个静态事务对象'; matches = $objects }
    }

    $object = $objects[0]
    $objectId = [string](Get-Cell $object 'ObjectId')
    $parameters = Run-Query @"
SELECT RTRIM(MESTxnObjectParameterId) AS ParameterId, TxnParameterName, DataType,
       ParameterSequence, IsValueListUsage, ValueList, LinkToValueListParameter,
       IsReadOnly, IsHidden, IsMustInput, ControlLine,
       IsGrid, IsPicture, IsSplitLine, IsShowTime, IsOpenFile, IsSaveValueToLocal,
       DefaultValue, HiddenCondition, RegularExpression,
       IsMustBeUpper, IsValidation, MustValueMoreThan, MustValueLessThan,
       MustLengthMoreThan, MustLengthLessThan, MustIncludedChar,
       AccessCode, UIStyleLabel, UIStyleControl, DefaultChart
FROM dbo.MESTxnObjectParameter WITH (NOLOCK)
WHERE RTRIM(MESTxnObjectId) = @id
ORDER BY ParameterSequence, MESTxnObjectParameterId
"@ @{ id = $objectId }

    $methods = Run-Query @"
SELECT RTRIM(MESTxnObjectMethodId) AS MethodId, MESTxnObjectMethodName, MethodSequence,
       SQLDoTxn, TxnParameter, IsHidden, RefreshGridParameter,
       IsBeforeRunningConfirm, IsResetWhenDone, IsAutoRunWhenTabActive,
       IsPlaySound, PromptMessage, AccessCode,
       LabelCopies, LabelLeftMargin, LabelTopMargin, LabelFileSP, LabelFileName,
       IsWriteToPort, PortNumber, UIStyle, IsPreview, IsShowDataSetWindow,
       ButtonPicture, UDialogParameter
FROM dbo.MESTxnObjectMethod WITH (NOLOCK)
WHERE RTRIM(MESTxnObjectId) = @id
ORDER BY MethodSequence, MESTxnObjectMethodId
"@ @{ id = $objectId }

    return [ordered]@{ object = $object; parameters = $parameters; methods = $methods }
}

function Get-MobileObject([string]$objectName) {
    $objects = Run-Query @"
SELECT RTRIM(MobileObjectId) AS ObjectId, MobileObjectName, MobileObjectDesc,
       IsActivity, ColumnCount, FieldWidth, FieldSpace, MsgCount, AccessCode
FROM dbo.MobileObject WITH (NOLOCK)
WHERE RTRIM(MobileObjectName) = @name OR RTRIM(MobileObjectDesc) = @name
"@ @{ name = $objectName }

    if ($objects.Count -eq 0) {
        return [ordered]@{ name = $objectName; error = '没有这个移动事务对象' }
    }

    $exact = @($objects | Where-Object {
        ([string](Get-Cell $_ 'MobileObjectName')).Trim().ToLowerInvariant() -eq $objectName.Trim().ToLowerInvariant()
    })
    $matches = @()
    if ($exact.Count -gt 0) { $matches = @($exact) } else { $matches = @($objects) }
    if ($matches.Count -gt 1) {
        return [ordered]@{ name = $objectName; error = '名称对应多个移动事务对象'; matches = $matches }
    }

    $object = $matches[0]
    $objectId = [string](Get-Cell $object 'ObjectId')
    $parameters = Run-Query @"
SELECT RTRIM(MobileObjectParameterId) AS ParameterId, MobileObjectParameterName, DataType,
       ParameterSequence, IsValueListUsage, ValueList, LinkToValueListParameter,
       IsReadOnly, IsHidden, IsMustInput, ControlLine,
       IsGrid, IsPicture, IsSplitLine, IsShowTime, IsSaveValueToLocal,
       AccessCode, DecimalPlace
FROM dbo.MobileObjectParameter WITH (NOLOCK)
WHERE RTRIM(MobileObjectId) = @id
ORDER BY ParameterSequence, MobileObjectParameterId
"@ @{ id = $objectId }

    $methods = Run-Query @"
SELECT RTRIM(MobileObjectMethodId) AS MethodId, MobileObjectMethodName, MethodSequence,
       SQLDoTxn, TxnParameter, RefreshGridParameter,
       IsHidden, IsBeforeRunningConfirm, PromptMessage,
       IsAutoRunWhenTabActive, IsPlaySound, IsGetGPS, AccessCode
FROM dbo.MobileObjectMethod WITH (NOLOCK)
WHERE RTRIM(MobileObjectId) = @id
ORDER BY MethodSequence, MobileObjectMethodId
"@ @{ id = $objectId }

    return [ordered]@{ object = $object; parameters = $parameters; methods = $methods }
}

function Get-MetadataDetail([string]$metadataId) {
    $metadataRows = Run-Query @"
SELECT RTRIM(MetadataId) AS MetadataId, MetadataName, MetadataDescription,
       RTRIM(ParentMetadataId) AS ParentMetadataId, RTRIM(ObjectId) AS ObjectId,
       TreeView, SubTreeView, MainView, MainSave, MainDelete,
       FilterField, IsTreeViewStyle, IsEnterKeySupport, IsMultiPageSupport,
       IsActivity, LEN(ISNULL(ObjectScript, '')) AS ScriptLength
FROM dbo.SysMetadata WITH (NOLOCK)
WHERE RTRIM(MetadataId) = @id
"@ @{ id = $metadataId }
    if ($metadataRows.Count -eq 0) { return $null }

    $groups = Run-Query @"
SELECT RTRIM(MetadataFieldGroupId) AS FieldGroupId, FieldGroupName, FieldGroupSequence,
       ColumnCount, FieldGroupHeight, IsCollapsed, IsHidden
FROM dbo.SysMetadataFieldGroup WITH (NOLOCK)
WHERE RTRIM(MetadataId) = @id
ORDER BY FieldGroupSequence, MetadataFieldGroupId
"@ @{ id = $metadataId }

    $bundles = @()
    foreach ($group in @($groups)) {
        $groupId = [string](Get-Cell $group 'FieldGroupId')
        $fields = Run-Query @"
SELECT RTRIM(MetadataQueryId) AS QueryFieldId, FieldName, DataType, FieldSequence,
       IsValueListUsage, ValueList, LinkToValueListField,
       IsReadOnly, IsHidden, IsShowTime, ControlLine, IsOpenFile
FROM dbo.SysMetadataQuery WITH (NOLOCK)
WHERE RTRIM(MetadataFieldGroupId) = @id
ORDER BY FieldSequence, MetadataQueryId
"@ @{ id = $groupId }

        $methods = Run-Query @"
SELECT RTRIM(MetadataMethodId) AS MethodId, MethodSequence, MethodName, SQLDoMethod,
       MainViewParameter, DialogParameter, UDialogParameter,
       IsBeforeRunningConfirm, PromptMessage,
       IsAutoRunQuery, IsRefreshTreeView, IsAcceptMainViewAsParameter,
       IsRunSubQuery, SubQuerySQLMethod, SubQueryParameter,
       QuerySummaryField, QueryMargedField, IsShowRowIndex,
       IsPrintMethod, IsPreview, LabelFileSP, LabelFileName,
       IsShowDataSetWindow, AccessCode
FROM dbo.SysMetadataMethod WITH (NOLOCK)
WHERE RTRIM(MetadataFieldGroupId) = @id
ORDER BY MethodSequence, MetadataMethodId
"@ @{ id = $groupId }

        $bundles += [ordered]@{ group = $group; fields = $fields; methods = $methods }
    }

    $children = Run-Query @"
SELECT RTRIM(MetadataId) AS MetadataId, MetadataName, MetadataDescription,
       TreeView, MainView, MainSave, MainDelete
FROM dbo.SysMetadata WITH (NOLOCK)
WHERE RTRIM(ParentMetadataId) = @id
ORDER BY Sequence, MetadataId
"@ @{ id = $metadataId }

    $plugins = Run-Query @"
SELECT RTRIM(PluginCommand) AS PluginCommand, PluginName, RTRIM(PluginFileName) AS PluginFileName
FROM dbo.SysPlugIn WITH (NOLOCK)
WHERE RTRIM(MetadataId) = @id
ORDER BY PluginCommand
"@ @{ id = $metadataId }

    return [ordered]@{
        metadata = $metadataRows[0]
        groups   = $bundles
        children = $children
        plugins  = $plugins
    }
}

try {
    $conn.Open()
    switch ($Action) {
        'plugin' {
            $rows = Run-Query @"
SELECT 'PC' AS Channel, RTRIM(PluginCommand) AS PluginCommand, PluginName,
       RTRIM(PluginFileName) AS PluginFileName, RTRIM(PluginParameter) AS PluginParameter,
       RTRIM(a.MetadataId) AS MetadataId, b.MetadataName
FROM dbo.SysPlugIn AS a WITH (NOLOCK)
LEFT JOIN dbo.SysMetadata AS b WITH (NOLOCK) ON b.MetadataId = a.MetadataId
WHERE RTRIM(a.PluginCommand) = @key
UNION ALL
SELECT 'OrDroid', RTRIM(OrDroidPluginCommand), OrDroidPluginName,
       RTRIM(OrDroidPluginFileName), '', '', ''
FROM dbo.OrDroidPlugin WITH (NOLOCK)
WHERE RTRIM(OrDroidPluginCommand) = @key
ORDER BY Channel
"@ @{ key = $Key }
            Write-Result ([ordered]@{ action = $Action; env = $Env; key = $Key; rows = $rows })
        }

        'txn' {
            $plugins = Run-Query @"
SELECT RTRIM(PluginCommand) AS PluginCommand, PluginName, RTRIM(PluginFileName) AS PluginFileName,
       RTRIM(PluginParameter) AS PluginParameter
FROM dbo.SysPlugIn WITH (NOLOCK)
WHERE RTRIM(PluginCommand) = @key AND RTRIM(PluginFileName) = 'PluginMESStaticTxn.dll'
"@ @{ key = $Key }

            if ($plugins.Count -eq 0) {
                Write-Result ([ordered]@{ action = $Action; env = $Env; key = $Key; error = '不是静态事务插件命令' })
                break
            }

            $plugin = $plugins[0]
            $mapped = Run-Query @"
SELECT RTRIM(ParameterValue) AS ObjectName
FROM dbo.SysParameter WITH (NOLOCK)
WHERE ParameterName = @parameter
ORDER BY ParameterValueEx, CreateDate, ParameterId
"@ @{ parameter = [string](Get-Cell $plugin 'PluginParameter') }

            $names = @()
            foreach ($row in @($mapped)) {
                $name = [string](Get-Cell $row 'ObjectName')
                if ($name -and $names -notcontains $name) { $names += $name }
            }
            if ($names.Count -eq 0) {
                $tag = Get-TagName ([string](Get-Cell $plugin 'PluginParameter')) 'MESTXN'
                if ($tag) { $names = @($tag) }
            }

            $objects = @()
            $seen = @{}
            foreach ($name in $names) {
                $bundle = Get-StaticObject $name
                $objectId = [string](Get-Cell (Get-Cell $bundle 'object') 'ObjectId')
                if ($objectId -and $seen.ContainsKey($objectId)) { continue }
                if ($objectId) { $seen[$objectId] = $true }
                $objects += $bundle
            }
            Write-Result ([ordered]@{ action = $Action; env = $Env; key = $Key; plugin = $plugin; objects = $objects })
        }

        'mobile' {
            $pcPlugins = Run-Query @"
SELECT RTRIM(PluginCommand) AS PluginCommand, PluginName, RTRIM(PluginFileName) AS PluginFileName,
       RTRIM(PluginParameter) AS PluginParameter
FROM dbo.SysPlugIn WITH (NOLOCK)
WHERE RTRIM(PluginCommand) = @key
"@ @{ key = $Key }

            $ordroidPlugins = Run-Query @"
SELECT RTRIM(OrDroidPluginId) AS PluginId, RTRIM(OrDroidPluginCommand) AS PluginCommand,
       OrDroidPluginName AS PluginName, OrDroidPluginDescription AS PluginDescription,
       RTRIM(OrDroidPluginFileName) AS PluginFileName, IsHorizontal
FROM dbo.OrDroidPlugin WITH (NOLOCK)
WHERE RTRIM(OrDroidPluginCommand) = @key
"@ @{ key = $Key }

            $names = @()
            if ($pcPlugins.Count -gt 0) {
                $pluginParameter = [string](Get-Cell $pcPlugins[0] 'PluginParameter')
                $mapped = Run-Query @"
SELECT RTRIM(ParameterValue) AS ObjectName
FROM dbo.SysParameter WITH (NOLOCK)
WHERE ParameterName = @parameter
ORDER BY ParameterValueEx, CreateDate, ParameterId
"@ @{ parameter = $pluginParameter }
                foreach ($row in @($mapped)) {
                    $name = [string](Get-Cell $row 'ObjectName')
                    if ($name -and $names -notcontains $name) { $names += $name }
                }
                if ($names.Count -eq 0) {
                    $tag = Get-TagName $pluginParameter 'MOBILETXN'
                    if ($tag) { $names = @($tag) }
                }
            }

            if ($ordroidPlugins.Count -gt 0) {
                $pluginId = [string](Get-Cell $ordroidPlugins[0] 'PluginId')
                $mapped = Run-Query @"
SELECT c.MobileObjectSequence, RTRIM(m.MobileObjectName) AS ObjectName
FROM dbo.OrDroid_MobileObject AS c WITH (NOLOCK)
INNER JOIN dbo.MobileObject AS m WITH (NOLOCK)
        ON RTRIM(m.MobileObjectId) = RTRIM(c.MobileObjectId)
WHERE RTRIM(c.OrDroidPluginId) = @id
ORDER BY c.MobileObjectSequence, m.MobileObjectName
"@ @{ id = $pluginId }
                foreach ($row in @($mapped)) {
                    $name = [string](Get-Cell $row 'ObjectName')
                    if ($name -and $names -notcontains $name) { $names += $name }
                }
            }

            if ($pcPlugins.Count -eq 0 -and $ordroidPlugins.Count -eq 0) {
                Write-Result ([ordered]@{ action = $Action; env = $Env; key = $Key; error = '没有这个移动事务插件命令' })
                break
            }

            $objects = @()
            $seen = @{}
            foreach ($name in $names) {
                $bundle = Get-MobileObject $name
                $objectId = [string](Get-Cell (Get-Cell $bundle 'object') 'ObjectId')
                if ($objectId -and $seen.ContainsKey($objectId)) { continue }
                if ($objectId) { $seen[$objectId] = $true }
                $objects += $bundle
            }
            Write-Result ([ordered]@{
                action         = $Action
                env            = $Env
                key            = $Key
                pcPlugins      = $pcPlugins
                ordroidPlugins = $ordroidPlugins
                objects        = $objects
            })
        }

        'query' {
            $rows = Run-Query @"
SELECT RTRIM(a.PluginCommand) AS PluginCommand, a.PluginName, RTRIM(a.PluginFileName) AS PluginFileName,
       RTRIM(b.MetadataId) AS MetadataId, b.MetadataName
FROM dbo.SysPlugIn AS a WITH (NOLOCK)
INNER JOIN dbo.SysMetadata AS b WITH (NOLOCK) ON b.MetadataId = a.MetadataId
WHERE RTRIM(a.PluginCommand) = @key
"@ @{ key = $Key }

            if ($rows.Count -eq 0) {
                $rows = Run-Query @"
SELECT RTRIM(a.PluginCommand) AS PluginCommand, a.PluginName, RTRIM(a.PluginFileName) AS PluginFileName,
       RTRIM(b.MetadataId) AS MetadataId, b.MetadataName
FROM dbo.SysMetadata AS b WITH (NOLOCK)
LEFT JOIN dbo.SysPlugIn AS a WITH (NOLOCK) ON RTRIM(a.MetadataId) = RTRIM(b.MetadataId)
WHERE b.MetadataName = @key
"@ @{ key = $Key }
            }

            $metadataIds = @()
            foreach ($row in @($rows)) {
                $id = [string](Get-Cell $row 'MetadataId')
                if ($id -and $metadataIds -notcontains $id) { $metadataIds += $id }
            }

            if ($metadataIds.Count -eq 0) {
                Write-Result ([ordered]@{ action = $Action; env = $Env; key = $Key; error = '没有这个查询元对象' })
                break
            }
            if ($metadataIds.Count -gt 1) {
                Write-Result ([ordered]@{ action = $Action; env = $Env; key = $Key; error = '对应多个元对象，请指定插件命令或元对象名'; candidates = $rows })
                break
            }

            $detail = Get-MetadataDetail $metadataIds[0]
            Write-Result ([ordered]@{
                action   = $Action
                env      = $Env
                key      = $Key
                plugin   = $rows[0]
                metadata = $detail.metadata
                groups   = $detail.groups
                children = $detail.children
                plugins  = $detail.plugins
            })
        }

        'groups' {
            $rows = Run-Query @"
SELECT RTRIM(MetadataFieldGroupId) AS FieldGroupId, MetadataId, FieldGroupName,
       FieldGroupSequence, ColumnCount, FieldGroupHeight, IsCollapsed, IsHidden
FROM dbo.SysMetadataFieldGroup WITH (NOLOCK)
WHERE RTRIM(MetadataId) = @key
ORDER BY FieldGroupSequence, MetadataFieldGroupId
"@ @{ key = $Key }
            Write-Result ([ordered]@{ action = $Action; env = $Env; key = $Key; rows = $rows })
        }

        'fields' {
            $rows = Run-Query @"
SELECT RTRIM(g.MetadataFieldGroupId) AS FieldGroupId, g.FieldGroupName, g.FieldGroupSequence,
       RTRIM(q.MetadataQueryId) AS QueryFieldId, q.FieldName, q.DataType, q.FieldSequence,
       q.IsValueListUsage, q.ValueList, q.LinkToValueListField,
       q.IsReadOnly, q.IsHidden, q.IsShowTime, q.ControlLine, q.IsOpenFile
FROM dbo.SysMetadataFieldGroup AS g WITH (NOLOCK)
INNER JOIN dbo.SysMetadataQuery AS q WITH (NOLOCK)
        ON q.MetadataFieldGroupId = g.MetadataFieldGroupId
WHERE RTRIM(g.MetadataId) = @key
ORDER BY g.FieldGroupSequence, q.FieldSequence, q.MetadataQueryId
"@ @{ key = $Key }
            Write-Result ([ordered]@{ action = $Action; env = $Env; key = $Key; rows = $rows })
        }

        'methods' {
            $rows = Run-Query @"
SELECT RTRIM(m.MetadataMethodId) AS MethodId, RTRIM(m.MetadataFieldGroupId) AS FieldGroupId,
       g.FieldGroupName, m.MethodSequence, m.MethodName, m.SQLDoMethod,
       m.MainViewParameter, m.DialogParameter, m.UDialogParameter,
       m.IsBeforeRunningConfirm, m.PromptMessage,
       m.IsAutoRunQuery, m.IsRefreshTreeView, m.IsAcceptMainViewAsParameter,
       m.IsRunSubQuery, m.SubQuerySQLMethod, m.SubQueryParameter,
       m.QuerySummaryField, m.QueryMargedField, m.IsShowRowIndex,
       m.IsPrintMethod, m.IsPreview, m.LabelFileSP, m.LabelFileName,
       m.IsShowDataSetWindow, m.AccessCode
FROM dbo.SysMetadataMethod AS m WITH (NOLOCK)
INNER JOIN dbo.SysMetadataFieldGroup AS g WITH (NOLOCK)
        ON g.MetadataFieldGroupId = m.MetadataFieldGroupId
WHERE RTRIM(m.MetadataFieldGroupId) = @key
   OR RTRIM(g.MetadataId) = @key
ORDER BY g.FieldGroupSequence, m.MethodSequence, m.MetadataMethodId
"@ @{ key = $Key }
            Write-Result ([ordered]@{ action = $Action; env = $Env; key = $Key; rows = $rows })
        }

        'params' {
            $staticObjects = Run-Query @"
SELECT RTRIM(MESTxnObjectId) AS ObjectId, MESTxnObjectName AS ObjectName, MESTxnObjectDesc AS ObjectDesc
FROM dbo.MESTxnObject WITH (NOLOCK)
WHERE RTRIM(MESTxnObjectId) = @key OR RTRIM(MESTxnObjectName) = @key
"@ @{ key = $Key }

            $mobileObjects = Run-Query @"
SELECT RTRIM(MobileObjectId) AS ObjectId, MobileObjectName AS ObjectName, MobileObjectDesc AS ObjectDesc
FROM dbo.MobileObject WITH (NOLOCK)
WHERE RTRIM(MobileObjectId) = @key OR RTRIM(MobileObjectName) = @key OR RTRIM(MobileObjectDesc) = @key
"@ @{ key = $Key }

            $staticBundles = @()
            foreach ($item in @($staticObjects)) { $staticBundles += Get-StaticObject ([string](Get-Cell $item 'ObjectName')) }

            $mobileBundles = @()
            foreach ($item in @($mobileObjects)) { $mobileBundles += Get-MobileObject ([string](Get-Cell $item 'ObjectName')) }

            Write-Result ([ordered]@{
                action = $Action
                env    = $Env
                key    = $Key
                static = $staticBundles
                mobile = $mobileBundles
            })
        }

        'search' {
            $like = '%' + $Key.Trim() + '%'
            $rows = Run-Query @"
SELECT TOP ($Limit) * FROM (
    SELECT 'PluginPC' AS Kind, RTRIM(PluginCommand) AS Code, PluginName AS Name,
           RTRIM(PluginFileName) AS Detail
    FROM dbo.SysPlugIn WITH (NOLOCK)
    WHERE RTRIM(PluginCommand) LIKE @like OR PluginName LIKE @like
    UNION ALL
    SELECT 'PluginOrDroid', RTRIM(OrDroidPluginCommand), OrDroidPluginName,
           RTRIM(OrDroidPluginFileName)
    FROM dbo.OrDroidPlugin WITH (NOLOCK)
    WHERE RTRIM(OrDroidPluginCommand) LIKE @like OR OrDroidPluginName LIKE @like
    UNION ALL
    SELECT 'Metadata', RTRIM(MetadataId), MetadataName, ISNULL(MetadataDescription, '')
    FROM dbo.SysMetadata WITH (NOLOCK)
    WHERE MetadataName LIKE @like OR MetadataDescription LIKE @like
    UNION ALL
    SELECT 'StaticTxn', RTRIM(MESTxnObjectId), MESTxnObjectName, ISNULL(MESTxnObjectDesc, '')
    FROM dbo.MESTxnObject WITH (NOLOCK)
    WHERE MESTxnObjectName LIKE @like OR MESTxnObjectDesc LIKE @like
    UNION ALL
    SELECT 'MobileTxn', RTRIM(MobileObjectId), MobileObjectName, ISNULL(MobileObjectDesc, '')
    FROM dbo.MobileObject WITH (NOLOCK)
    WHERE MobileObjectName LIKE @like OR MobileObjectDesc LIKE @like
    UNION ALL
    SELECT 'SysObject', RTRIM(ObjectId), ObjectName, ISNULL(ObjectDescription, '')
    FROM dbo.SysObject WITH (NOLOCK)
    WHERE ObjectName LIKE @like OR ObjectDescription LIKE @like
) AS found
ORDER BY Kind, Code
"@ @{ like = $like }
            Write-Result ([ordered]@{ action = $Action; env = $Env; key = $Key; rows = $rows })
        }

        'menu' {
            $rows = Run-Query @"
SELECT DISTINCT a.ApplicationName, u.UserGroupName, g.MenuGroupName
FROM dbo.SysPlugIn AS p WITH (NOLOCK)
INNER JOIN dbo.SysMenu AS m WITH (NOLOCK) ON RTRIM(m.PlugInId) = RTRIM(p.PluginId)
INNER JOIN dbo.SysMenuGroup AS g WITH (NOLOCK) ON RTRIM(g.MenuGroupId) = RTRIM(m.MenuGroupId)
INNER JOIN dbo.SysUserGroup AS u WITH (NOLOCK) ON RTRIM(u.UserGroupId) = RTRIM(g.UserGroupId)
INNER JOIN dbo.SysApplication AS a WITH (NOLOCK) ON RTRIM(a.ApplicationId) = RTRIM(u.ApplicationId)
WHERE RTRIM(p.PluginCommand) = @key
ORDER BY a.ApplicationName, u.UserGroupName, g.MenuGroupName
"@ @{ key = $Key }
            Write-Result ([ordered]@{ action = $Action; env = $Env; key = $Key; rows = $rows })
        }

        'proc' {
            $procedureName = $Key.Trim()
            if ($procedureName -notmatch '^[A-Za-z0-9_\.]+$') { throw '过程名不合法' }
            if ($procedureName -notmatch '\.') { $procedureName = 'dbo.' + $procedureName }
            $rows = Run-Query @"
SELECT OBJECT_NAME(m.object_id) AS ProcedureName, m.definition
FROM sys.sql_modules AS m
WHERE m.object_id = OBJECT_ID(@name)
"@ @{ name = $procedureName }
            Write-Result ([ordered]@{ action = $Action; env = $Env; key = $procedureName; rows = $rows })
        }

        'sql' {
            $text = $Sql.Trim()
            if (-not $text) { throw '缺少 -Sql' }
            if ($text -notmatch '^(?is)(select|with)\b') { throw '只允许 SELECT 或 WITH 查询' }
            if ($text -match '(?is)\b(insert|update|delete|merge|drop|alter|create|truncate|exec|execute|grant|revoke|deny|backup|restore)\b') {
                throw '只允许只读查询'
            }
            if ($text -match ';\s*\S') { throw '只允许一条语句' }
            $rows = Run-Query ("SET ROWCOUNT $Limit;`n" + $text)
            Write-Result ([ordered]@{ action = $Action; env = $Env; rows = $rows })
        }
    }
}
catch {
    Write-Result ([ordered]@{ action = $Action; env = $Env; key = $Key; error = $_.Exception.Message })
    exit 1
}
finally {
    if ($conn) { $conn.Close() }
}
