#Requires -Version 5.1
# 内网 HTTPS（自签证书）+ TLS1.2，供 Invoke-RestMethod 调用 172.16.x API 平台
param([switch]$Force)

if ($Force -or $env:ESB_SKIP_TLS_VERIFY -eq '1') {
    if (-not ([System.Management.Automation.PSTypeName]'TrustAllCerts').Type) {
        Add-Type @'
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCerts : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) { return true; }
}
'@
    }
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCerts
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
}

$proto = [Net.SecurityProtocolType]::Tls12
if ([enum]::IsDefined([Net.SecurityProtocolType], 'Tls13')) {
    $proto = $proto -bor [Net.SecurityProtocolType]::Tls13
}
[Net.ServicePointManager]::SecurityProtocol = $proto
[Net.ServicePointManager]::Expect100Continue = $false
[Net.ServicePointManager]::DefaultConnectionLimit = 50
