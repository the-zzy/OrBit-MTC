#requires -Version 5.1
<#
Get or replace a stored procedure on one configured MES source.

Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/proc_sql.ps1 -Env jiban-mes-prod -Action get -Name KDOrderLoadedPull -File out.sql
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/proc_sql.ps1 -Env jiban-mes-prod -Action put -File fix.sql -Name KDOrderLoadedPull -DryRun
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/proc_sql.ps1 -Env jiban-mes-prod -Action put -File fix.sql -Name KDOrderLoadedPull

put runs the whole script inside one transaction; -DryRun rolls it back after checking.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Env,

    [Parameter(Mandatory = $true)]
    [ValidateSet('get', 'put')]
    [string]$Action,

    [string]$Name = '',
    [string]$File = '',
    [switch]$DryRun
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

if (-not (Test-Path $catalogPath) -or -not (Test-Path $secretPath)) {
    throw "No configuration for $Env"
}
if (-not $File) { throw 'Missing -File' }

$catalog = Read-EnvFile $catalogPath
$secrets = Read-EnvFile $secretPath
$dbHost = if ($secrets['DB_HOST']) { $secrets['DB_HOST'] } else { $catalog['HOST'] }
$dbPort = if ($secrets['DB_PORT']) { $secrets['DB_PORT'] } else { '1433' }
$connectionString = "Server=$dbHost,$dbPort;Database=$($catalog['DB']);User ID=$($secrets['DB_USER']);Password=$($secrets['DB_PASSWORD']);Connect Timeout=20"

$conn = New-Object System.Data.SqlClient.SqlConnection $connectionString
$conn.Open()

try {
    if ($Action -eq 'get') {
        if (-not $Name) { throw 'Missing -Name' }
        $fullName = if ($Name.Contains('.')) { $Name } else { "dbo.$Name" }
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = 'SELECT OBJECT_DEFINITION(OBJECT_ID(@n))'
        $param = $cmd.Parameters.Add('@n', [System.Data.SqlDbType]::NVarChar, 200)
        $param.Value = $fullName
        $definition = $cmd.ExecuteScalar()
        if ($null -eq $definition -or $definition -is [System.DBNull]) { throw "NOT FOUND: $fullName" }
        $dir = Split-Path $File -Parent
        if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        [System.IO.File]::WriteAllText($File, [string]$definition, (New-Object System.Text.UTF8Encoding($false)))
        Write-Output "saved $fullName -> $File ($($definition.Length) chars)"
    }
    else {
        $sql = [System.IO.File]::ReadAllText($File, [System.Text.Encoding]::UTF8)
        $batches = [regex]::Split($sql, '(?im)^\s*GO\s*$') | Where-Object { $_.Trim() }
        $tx = $conn.BeginTransaction()
        try {
            foreach ($batch in $batches) {
                $cmd = $conn.CreateCommand()
                $cmd.Transaction = $tx
                $cmd.CommandText = $batch
                $cmd.CommandTimeout = 180
                [void]$cmd.ExecuteNonQuery()
            }
            if ($DryRun) {
                $tx.Rollback()
                Write-Output 'dry-run: rolled back'
            }
            else {
                $tx.Commit()
                Write-Output 'committed'
            }
        }
        catch {
            $tx.Rollback()
            throw
        }
    }
}
finally {
    $conn.Close()
}
