#Requires -Version 5.1
function Get-EsbPlatformSerialNumber {
    param(
        [Parameter(Mandatory = $true)][string] $Uri,
        [Parameter(Mandatory = $true)][hashtable] $Headers
    )
    try {
        $resp = Invoke-RestMethod -Uri $Uri -Headers $Headers -Method Get -TimeoutSec 60
        $sn = [string]$resp.serialNumber
        if (-not [string]::IsNullOrWhiteSpace($sn)) { return $sn }
    }
    catch { }

    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if (-not $curl) {
        throw ('Serial API failed (Invoke-RestMethod and curl.exe unavailable): ' + $Uri)
    }
    $args = @('-sS', '--fail-with-body')
    foreach ($k in $Headers.Keys) {
        $args += '-H'
        $args += ($k + ': ' + $Headers[$k])
    }
    $args += $Uri
    $json = & curl.exe @args 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        throw ('curl serial API failed: ' + $Uri + ' ; ' + $json.Trim())
    }
    $obj = $json.Trim() | ConvertFrom-Json
    $sn = [string]$obj.serialNumber
    if ([string]::IsNullOrWhiteSpace($sn)) {
        throw ('No serialNumber in curl response: ' + $json.Trim())
    }
    return $sn
}
