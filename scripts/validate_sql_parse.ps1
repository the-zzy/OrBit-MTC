# Parse a SQL file on the selected connection without executing its contents.
param(
    [Parameter(Mandatory=$true)][string]$SqlFile,
    [string]$EnvName = "jiban-mes-prod"
)

$root = Split-Path $PSScriptRoot -Parent

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

$resolvedSqlFile = (Resolve-Path $SqlFile).Path
$catalog = Read-EnvFile (Join-Path $root "db/catalog/$EnvName")
$secrets = Read-EnvFile (Join-Path $root "secrets/$EnvName.env")
$dbHost = if ($secrets['DB_HOST']) { $secrets['DB_HOST'] } else { $catalog['HOST'] }
$dbPort = if ($secrets['DB_PORT']) { $secrets['DB_PORT'] } else { '1433' }
$connStr = "Server=$dbHost,$dbPort;Database=$($catalog['DB']);User ID=$($secrets['DB_USER']);Password=$($secrets['DB_PASSWORD']);Connect Timeout=20"
$conn = New-Object System.Data.SqlClient.SqlConnection $connStr
$conn.Open()
try {
    $set = $conn.CreateCommand()
    $set.CommandText = 'SET PARSEONLY ON'
    $set.ExecuteNonQuery() | Out-Null

    $cmd = $conn.CreateCommand()
    $cmd.CommandText = [System.IO.File]::ReadAllText($resolvedSqlFile, [System.Text.Encoding]::UTF8)
    $cmd.CommandTimeout = 60
    $cmd.ExecuteNonQuery() | Out-Null
    Write-Host "Parse passed: $resolvedSqlFile"
}
finally {
    if ($conn.State -eq [System.Data.ConnectionState]::Open) {
        $off = $conn.CreateCommand()
        $off.CommandText = 'SET PARSEONLY OFF'
        $off.ExecuteNonQuery() | Out-Null
        $conn.Close()
    }
}
