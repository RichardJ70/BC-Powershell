# ===== Variables =====

Param(
    [Parameter(Mandatory=$true)]
    [string]$TenantId,
    [Parameter(Mandatory=$true)]
    [string]$CommonName,
    [Parameter(Mandatory=$true)]
    [string]$PfxPath,
    [Parameter(Mandatory=$true)]
    [SecureString]$PfxSecret
)

Install-Module Microsoft.Graph -Scope CurrentUser -ErrorAction SilentlyContinue

$Script:MaximumFunctionCount  = 18000
$Script:MaximumVariableCount  = 18000

Import-Module Microsoft.Graph.Authentication -Force
Import-Module Microsoft.Graph.Applications -Force

Set-MgGraphOption -DisableLoginByWAM $true
Disconnect-MgGraph -ErrorAction SilentlyContinue

Connect-MgGraph -UseDeviceCode -TenantId $TenantId -Scopes "Application.Read.All"
$cn = $CommonName -replace "'", "''"
$app  = Get-MgApplication -Filter "displayName eq '$cn'" -ConsistencyLevel eventual -Top 5

if (-not $app) {
    throw "No application found with displayName '$CommonName'."
} elseif ($app.Count -gt 1) {
    Write-Warning "Multiple applictions found with displayName '$CommonName'. Taking the first. Consider refining the query."
    $app = $app | Select-Object -First 1
}

$ClientId = $app.AppId


# Load MSAL (comes with Az.Accounts in many environments; otherwise load the assembly manually)
# If needed, install: Install-Package Microsoft.Identity.Client -Provider NuGet -Scope CurrentUser

Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.Web

# Helper to acquire a token for a given scope
function Get-AppOnlyToken {
    param(
        [Parameter(Mandatory)][string]$Scope # e.g., "https://api.businesscentral.dynamics.com/.default"
    )

    $pfxBytes = [System.IO.File]::ReadAllBytes($PfxPath)
    $cert     = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($pfxBytes, $PfxSecret,
                    [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)

    $Authority = "https://login.microsoftonline.com/$TenantId"
    $builder = [Microsoft.Identity.Client.ConfidentialClientApplicationBuilder]::Create($ClientId).
        WithAuthority($Authority).
        WithCertificate($cert).
        Build()

    $result = $builder.AcquireTokenForClient(@($Scope)).ExecuteAsync().GetAwaiter().GetResult()
    return $result.AccessToken
}

# ===== Tokens =====
$bcToken  = Get-AppOnlyToken -Scope "https://api.businesscentral.dynamics.com/.default"
$spoToken = Get-AppOnlyToken -Scope "https://<yourtenant>.sharepoint.com/.default"
$apiToken = Get-AppOnlyToken -Scope "api://<your-custom-api-appid-or-uri>/.default"

$bcToken.Substring(0,25) + "..."
$spoToken.Substring(0,25) + "..."
$apiToken.Substring(0,25) + "..."