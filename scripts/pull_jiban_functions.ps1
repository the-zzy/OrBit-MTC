# Pull all jiban PC plugins from SysPlugIn and PDA plugins from OrDroidPlugin.
# The same command published to both tables is counted twice: one PC plugin and one PDA plugin.
# Output: scripts/jiban_functions.json and web/src/function-data/jiban.js.
param([string]$EnvName = "jiban-mes-prod")

$root = Split-Path $PSScriptRoot -Parent
$out = Join-Path $PSScriptRoot "jiban_functions.json"

function Read-EnvFile($path) {
    $values = @{}
    if (-not (Test-Path $path)) { return $values }
    foreach ($line in Get-Content $path -Encoding UTF8) {
        if ($line -notmatch '=' -or $line.StartsWith('#')) { continue }
        $key, $raw = $line -split '=', 2
        $raw = $raw.Trim().Trim("'").Trim('"')
        $values[$key.Trim()] = $raw
    }
    return $values
}

$catalog = Read-EnvFile (Join-Path $root "db/catalog/$EnvName")
$secrets = Read-EnvFile (Join-Path $root "secrets/$EnvName.env")
$dbHost = if ($secrets['DB_HOST']) { $secrets['DB_HOST'] } else { $catalog['HOST'] }
$dbPort = if ($secrets['DB_PORT']) { $secrets['DB_PORT'] } else { '1433' }
$connStr = "Server=$dbHost,$dbPort;Database=$($catalog['DB']);User ID=$($secrets['DB_USER']);Password=$($secrets['DB_PASSWORD']);Connect Timeout=20"
$conn = New-Object System.Data.SqlClient.SqlConnection $connStr
$conn.Open()

function Run-Query($sql) {
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = $sql
    $cmd.CommandTimeout = 120
    $reader = $cmd.ExecuteReader()
    $rows = @()
    while ($reader.Read()) {
        $row = [ordered]@{}
        for ($i = 0; $i -lt $reader.FieldCount; $i++) { $row[$reader.GetName($i)] = $reader.GetValue($i) }
        $rows += $row
    }
    $reader.Close()
    return $rows
}

# 1. PC plugins: all SysPlugIn rows except the OPLUG management plugin itself.
# Do not exclude commands that are also published as OrDroid plugins.
$plugins = Run-Query @"
SELECT RTRIM(p.PluginId) AS pid, RTRIM(p.PluginCommand) AS cmd, p.PluginName AS name,
       RTRIM(p.PluginFileName) AS dll, RTRIM(p.PluginParameter) AS param, RTRIM(p.MetadataId) AS mid
FROM dbo.SysPlugIn p WITH (NOLOCK)
WHERE RTRIM(p.PluginCommand) <> 'OPLUG'
ORDER BY RTRIM(p.PluginCommand)
"@

# 2. PDA plugins: separate publications, never deduplicated against SysPlugIn.
$ordroidPlugins = Run-Query @"
SELECT RTRIM(o.OrDroidPluginCommand) AS cmd, o.OrDroidPluginName AS name,
       RTRIM(o.OrDroidPluginFileName) AS dll
FROM dbo.OrDroidPlugin o WITH (NOLOCK)
ORDER BY RTRIM(o.OrDroidPluginCommand)
"@

# 2. metadata root names
$metaName = @{}
Run-Query "SELECT RTRIM(MetadataId) AS mid, MetadataName FROM dbo.SysMetadata WITH (NOLOCK)" |
    ForEach-Object { $metaName[$_.mid] = [string]$_.MetadataName }

# 3. txn / mobile object lookups (by name and by unambiguous description)
function Build-Lookup($rows, $nameCol, $descCol) {
    $byName = @{}; $byDesc = @{}; $ambiguous = @{}
    foreach ($r in $rows) {
        $n = ([string]$r[$nameCol]).Trim()
        $d = ([string]$r[$descCol]).Trim()
        if ($n) { $byName[$n.ToLowerInvariant()] = $n }
        if ($n -and $d) {
            $k = $d.ToLowerInvariant()
            if ($byDesc.ContainsKey($k) -and $byDesc[$k] -ne $n) { $ambiguous[$k] = $true }
            else { $byDesc[$k] = $n }
        }
    }
    foreach ($k in $ambiguous.Keys) { $byDesc.Remove($k) }
    return @($byName, $byDesc)
}
$txnRows = Run-Query "SELECT MESTxnObjectName, MESTxnObjectDesc FROM dbo.MESTxnObject WITH (NOLOCK)"
$txn = Build-Lookup $txnRows 'MESTxnObjectName' 'MESTxnObjectDesc'
$mobRows = Run-Query "SELECT MobileObjectName, MobileObjectDesc FROM dbo.MobileObject WITH (NOLOCK)"
$mob = Build-Lookup $mobRows 'MobileObjectName' 'MobileObjectDesc'

# 4. application per plugin via menu path: SysMenu -> SysMenuGroup -> SysUserGroup -> SysApplication
$apps = @{}
Run-Query @"
SELECT DISTINCT RTRIM(m.PlugInId) AS pid, a.ApplicationName AS app
FROM dbo.SysMenu m WITH (NOLOCK)
JOIN dbo.SysMenuGroup g WITH (NOLOCK) ON RTRIM(g.MenuGroupId) = RTRIM(m.MenuGroupId)
JOIN dbo.SysUserGroup u WITH (NOLOCK) ON RTRIM(u.UserGroupId) = RTRIM(g.UserGroupId)
JOIN dbo.SysApplication a WITH (NOLOCK) ON RTRIM(a.ApplicationId) = RTRIM(u.ApplicationId)
"@ | ForEach-Object {
        if (-not $apps.ContainsKey($_.pid)) { $apps[$_.pid] = @() }
        $apps[$_.pid] += [string]$_.app
    }

# 5. assemble rows: one row per (application, command); no menu -> single row with empty a
$tagByDll = @{ 'PluginMESStaticTxn.dll' = 'MESTXN'; 'PluginMESMobile.dll' = 'MOBILETXN' }
$rows = @()
foreach ($p in $plugins) {
    $objName = ''
    if ($p.mid -and $metaName.ContainsKey($p.mid)) { $objName = [string]$metaName[$p.mid] }
    if (-not $objName -and $tagByDll.ContainsKey($p.dll)) {
        $tag = $tagByDll[$p.dll]
        $match = [regex]::Match([string]$p.param, ('\[' + $tag + ':([^\]\[]+)'), 'IgnoreCase')
        if ($match.Success) {
            $key = $match.Groups[1].Value.Trim()
            $lk = if ($tag -eq 'MESTXN') { $txn } else { $mob }
            $objName = [string]($lk[0][$key.ToLowerInvariant()])
            if (-not $objName) { $objName = [string]($lk[1][$key.ToLowerInvariant()]) }
            if (-not $objName) { $objName = $key }
        }
    }
    $appList = $apps[$p.pid]
    if (-not $appList) { $appList = @('') }
    foreach ($app in ($appList | Sort-Object -Unique)) {
        $rows += [ordered]@{ a = $app; c = $p.cmd; f = $p.dll; n = [string]$p.name; o = $objName; s = '' }
    }
}

# 6. Append every OrDroid publication, including commands also present in SysPlugIn.
foreach ($p in $ordroidPlugins) {
    $rows += [ordered]@{ a = 'OrDroid'; c = $p.cmd; f = $p.dll; n = [string]$p.name; o = ''; s = 'OrDroid' }
}

$rows = @($rows | Sort-Object @{e={$_.a}}, @{e={$_.c}})
$json = ConvertTo-Json $rows -Compress
[System.IO.File]::WriteAllText($out, $json, (New-Object System.Text.UTF8Encoding($false)))

# Replace only the jiban data module; the other plants remain untouched.
$indexPath = Join-Path $root 'web/src/function-data/jiban.js'
$allJson = ConvertTo-Json -InputObject @($rows) -Compress -Depth 20
$updatedIndex = 'export default ' + $allJson + "`n"
[System.IO.File]::WriteAllText($indexPath, $updatedIndex, (New-Object System.Text.UTF8Encoding($false)))

$conn.Close()
Write-Host ("PC plugins: {0}  PDA plugins: {1}  exported rows: {2}" -f $plugins.Count, $ordroidPlugins.Count, $rows.Count)
Write-Host ("updated: {0} and {1}" -f $out, $indexPath)
