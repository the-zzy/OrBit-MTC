# Start the workbench if it is not already listening.
# API on 127.0.0.1:8765, page on 127.0.0.1:3000.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$logDir = Join-Path $root 'var'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$log = Join-Path $logDir 'workbench.log'

function Write-Log([string]$message) {
    $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $message
    Add-Content -Path $log -Value $line -Encoding UTF8
}

function Test-Listening([int]$port) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $connect = $client.BeginConnect('127.0.0.1', $port, $null, $null)
        $ok = $connect.AsyncWaitHandle.WaitOne(400)
        if (-not $ok) { return $false }
        $client.EndConnect($connect)
        return $true
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

function Find-Npm {
    $cmd = Get-Command npm.cmd -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $fallback = 'E:\soft\node\npm.cmd'
    if (Test-Path -LiteralPath $fallback) { return $fallback }
    return $null
}

Write-Log 'start requested'

if (-not (Test-Listening 8765)) {
    $python = Join-Path $root '.venv\Scripts\python.exe'
    if (-not (Test-Path -LiteralPath $python)) {
        Write-Log "missing python: $python"
        exit 1
    }
    Start-Process -FilePath $python `
        -ArgumentList @('-m', 'uvicorn', 'app:app', '--app-dir', (Join-Path $root 'server'), '--host', '127.0.0.1', '--port', '8765') `
        -WorkingDirectory $root `
        -WindowStyle Normal
    Write-Log 'api starting on 8765'
} else {
    Write-Log 'api already listening on 8765'
}

if (-not (Test-Listening 3000)) {
    $npm = Find-Npm
    if (-not $npm) {
        Write-Log 'npm.cmd not found'
        exit 1
    }
    Start-Process -FilePath $npm `
        -ArgumentList @('run', 'dev') `
        -WorkingDirectory (Join-Path $root 'web') `
        -WindowStyle Normal
    Write-Log 'page starting on 3000'
} else {
    Write-Log 'page already listening on 3000'
}

exit 0
