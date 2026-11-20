#Requires -Version 5.1
<#
.SYNOPSIS
    调用 API 平台 auth/login，返回 identitytoken（供 ESB / 网关流水号接口使用）。

.DESCRIPTION
    凭据优先级：
    1. 仅取 token：已设置环境变量 ESB_IDENTITY_TOKEN
    2. 登录：参数 -ConfigPath / ESB_API_AUTH_FILE / 仓库 secrets/esb-api-auth.local.json
    3. 登录：ESB_API_USER_NAME + ESB_API_PASSWORD（或 API_USERNAME / API_PASSWORD）+ 可选 ESB_API_LOGIN_URL

    禁止把 token 或密码写入 Git 跟踪文件。

.EXAMPLE
    & .\Get-EsbApiIdentityToken.ps1 -SetSessionEnv
    & .\New-点屏升级网关Bson.ps1
#>
[CmdletBinding()]
param(
    [string] $ConfigPath = $env:ESB_API_AUTH_FILE,
    [string] $LoginUrl = $env:ESB_API_LOGIN_URL,
    [string] $UserName = $env:ESB_API_USER_NAME,
    [string] $Password = $env:ESB_API_PASSWORD,
    [switch] $SetSessionEnv,
    [switch] $PassThru,
    [switch] $UseFileTokenFirst
)

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding $false
. (Join-Path $PSScriptRoot 'Enable-EsbTlsForInternalApi.ps1') -Force

function Get-RepoRoot {
    $dir = $PSScriptRoot
    while ($dir) {
        if (Test-Path (Join-Path $dir '.AGENTS\skills\mes-db\SKILL.md')) { return $dir }
        $parent = Split-Path $dir -Parent
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
    Split-Path (Split-Path $PSScriptRoot -Parent) -Parent | Split-Path -Parent
}

if ([string]::IsNullOrWhiteSpace($UserName)) { $UserName = $env:API_USERNAME }
if ([string]::IsNullOrWhiteSpace($Password)) { $Password = $env:API_PASSWORD }

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $defaultLocal = Join-Path (Get-RepoRoot) 'secrets\esb-api-auth.local.json'
    if (Test-Path -LiteralPath $defaultLocal) { $ConfigPath = $defaultLocal }
}

$cfg = $null
if (-not [string]::IsNullOrWhiteSpace($ConfigPath) -and (Test-Path -LiteralPath $ConfigPath)) {
    Add-Type -AssemblyName System.Web.Extensions
    $ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $cfg = $ser.DeserializeObject([IO.File]::ReadAllText($ConfigPath, $utf8))
    if ([string]::IsNullOrWhiteSpace($LoginUrl) -and $cfg['loginUrl']) { $LoginUrl = $cfg['loginUrl'].ToString() }
    if ([string]::IsNullOrWhiteSpace($UserName) -and $cfg['userName']) { $UserName = $cfg['userName'].ToString() }
    if ([string]::IsNullOrWhiteSpace($Password) -and $cfg['password']) { $Password = $cfg['password'].ToString() }
    if ($cfg['skipTlsVerify'] -eq $true) { $env:ESB_SKIP_TLS_VERIFY = '1' }
}

if ([string]::IsNullOrWhiteSpace($LoginUrl)) {
    $LoginUrl = 'https://172.16.8.126:8020/api/rest/core/auth/login'
}

$fileToken = $null
if ($cfg -and $cfg['identityToken'] -and -not [string]::IsNullOrWhiteSpace($cfg['identityToken'].ToString())) {
    $fileToken = $cfg['identityToken'].ToString().Trim()
    if ($fileToken.StartsWith('<')) { $fileToken = $null }
}

if ($UseFileTokenFirst -and $fileToken) {
    if ($SetSessionEnv) { $env:ESB_IDENTITY_TOKEN = $fileToken }
    if ($PassThru -or $MyInvocation.InvocationName -ne '.') { return $fileToken }
    return $fileToken
}

if ([string]::IsNullOrWhiteSpace($UserName) -or [string]::IsNullOrWhiteSpace($Password)) {
    if (-not [string]::IsNullOrWhiteSpace($env:ESB_IDENTITY_TOKEN)) {
        $t = $env:ESB_IDENTITY_TOKEN.Trim()
        if ($SetSessionEnv) { $env:ESB_IDENTITY_TOKEN = $t }
        if ($PassThru -or $MyInvocation.InvocationName -ne '.') { return $t }
        return $t
    }
    if ($fileToken) {
        if ($SetSessionEnv) { $env:ESB_IDENTITY_TOKEN = $fileToken }
        if ($PassThru -or $MyInvocation.InvocationName -ne '.') { return $fileToken }
        return $fileToken
    }
    Write-Error 'Missing credentials: set ESB_IDENTITY_TOKEN, or userName/password in esb-api-auth.local.json (see esb-api-auth.md).'
    exit 1
}

$body = (@{ userName = $UserName; password = $Password } | ConvertTo-Json -Compress)
try {
    $resp = Invoke-RestMethod -Uri $LoginUrl -Method Post -Body $body -ContentType 'application/json; charset=utf-8' -Headers @{ Accept = 'application/json' }
}
catch {
    Write-Error "Login failed: $LoginUrl ; $($_.Exception.Message)"
    exit 1
}

$token = $null
if ($resp -is [hashtable] -or $resp.PSObject.Properties['identitytoken']) {
    $token = $resp.identitytoken
}
if ([string]::IsNullOrWhiteSpace($token)) {
    Write-Error 'Login response has no identitytoken.'
    exit 1
}
if ($resp.state -eq $false) {
    Write-Error ('登录 state=false: ' + ($resp.msg | Out-String))
    exit 1
}

$token = $token.ToString().Trim()
if ($SetSessionEnv) { $env:ESB_IDENTITY_TOKEN = $token }
if ($PassThru -or $MyInvocation.InvocationName -ne '.') { return $token }
return $token
