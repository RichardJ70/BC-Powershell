<#
.SYNOPSIS
    Configure certificate-based auth on an existing App Registration ("Graph API") for
    Business Central, SharePoint Online, and a Custom API.

.NOTES
    Requires Microsoft.Graph PowerShell SDK.
    Run as:  Connect-MgGraph -Scopes "Application.ReadWrite.All","AppRoleAssignment.ReadWrite.All","Directory.ReadWrite.All"
#>

# =========================
# ======= Variables =======
# =========================
$TenantId            = "<YOUR-TENANT-ID-GUID>"
$AppDisplayName      = "Graph API"  # existing App Registration display name
$CertSubjectCN       = "CN=GraphAPI-ClientCert"   # subject for self-signed cert
$CertValidityYears   = 2
$CertOutDir          = "C:\Temp\GraphApiCert"
$PfxPasswordPlain    = "<STRONG-PASSWORD-HERE>"   # used only to export the PFX for your app/agent
$CreateNewCert       = $true  # set to $false to reuse an existing .cer/.pfx in $CertOutDir

# ---- Custom API (adjust!) ----
# If your custom API is another Entra app in the same tenant:
#   Option A) Identify it by its "Application (client) ID"
$CustomApi_ResourceAppId = "<CUSTOM-API-APPID-GUID>"
#   Option B) Or by its "Application ID URI" (e.g., "api://your-api-id")
$CustomApi_AppIdUri      = ""  # leave empty if using the GUID above
#   Required app role value on your custom API (e.g., "access_as_application" or your own)
$CustomApi_AppRoleValue  = "access_as_application"

# ===============================
# ======= Helper Functions ======
# ===============================
function Ensure-Module {
    param([Parameter(Mandatory)][string]$Name)
    if (-not (Get-Module -ListAvailable -Name $Name)) {
        Install-Module $Name -Scope AllUsers -Force -ErrorAction Stop
    }
}

function Ensure-ConnectedGraph {
    $ctx = Get-MgContext -ErrorAction SilentlyContinue
    if (-not $ctx) {
        Connect-MgGraph -Scopes "Application.ReadWrite.All","AppRoleAssignment.ReadWrite.All","Directory.ReadWrite.All" -ErrorAction Stop
    }
    Select-MgProfile -Name "beta"  # beta has fuller appRole surfaces; switch back if you prefer 'v1.0'
}

function New-Or-Load-Certificate {
    param(
        [Parameter(Mandatory)][string]$SubjectCN,
        [Parameter(Mandatory)][string]$OutDir,
        [Parameter(Mandatory)][int]$Years,
        [Parameter(Mandatory)][string]$PfxPassword,
        [Parameter(Mandatory)][bool]$CreateNew
    )
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
    $pfxPath = Join-Path $OutDir "client.pfx"
    $cerPath = Join-Path $OutDir "client.cer"

    if ($CreateNew) {
        Write-Host "Creating a new self-signed certificate..." -ForegroundColor Cyan
        $cert = New-SelfSignedCertificate -CertStoreLocation Cert:\CurrentUser\My `
            -Subject $SubjectCN -KeySpec Signature -KeyExportPolicy Exportable `
            -NotAfter (Get-Date).AddYears($Years)

        $secPwd  = ConvertTo-SecureString $PfxPassword -AsPlainText -Force
        Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $secPwd | Out-Null
        Export-Certificate   -Cert $cert -FilePath $cerPath | Out-Null
    }
    elseif (-not (Test-Path $pfxPath -PathType Leaf -ErrorAction SilentlyContinue) -or `
            -not (Test-Path $cerPath -PathType Leaf -ErrorAction SilentlyContinue)) {
        throw "CreateNew is false but $pfxPath and/or $cerPath not found in $OutDir."
    }

    return [PSCustomObject]@{
        PfxPath = $pfxPath
        CerPath = $cerPath
    }
}

function Get-AppByDisplayName {
    param([Parameter(Mandatory)][string]$DisplayName)
    $apps = Get-MgApplication -Filter "displayName eq '$DisplayName'"
    if ($apps.Count -gt 1) {
        throw "Multiple app registrations found with displayName '$DisplayName'. Please disambiguate."
    }
    if (-not $apps) { throw "App registration '$DisplayName' not found." }
    return $apps
}

function Add-CertificateToApp {
    param(
        [Parameter(Mandatory)]$App,
        [Parameter(Mandatory)][string]$CerPath,
        [string]$DisplayName = "ClientCert"
    )
    $certBytes  = Get-Content -Path $CerPath -Encoding Byte
    $base64Cert = [System.Convert]::ToBase64String($certBytes)

    # Build KeyCredential object
    $keyCred = @{
        type        = "AsymmetricX509Cert"
        usage       = "Verify"
        key         = $base64Cert
        displayName = $DisplayName
    }

    # Append to existing KeyCredentials
    $existing   = @($App.KeyCredentials)
    $updated    = $existing + (New-Object -TypeName psobject -Property $keyCred)

    Write-Host "Uploading certificate to application '$($App.DisplayName)'..." -ForegroundColor Cyan
    Update-MgApplication -ApplicationId $App.Id -KeyCredentials $updated | Out-Null
}

function Ensure-ServicePrincipalForApp {
    param([Parameter(Mandatory)]$App)
    $sp = Get-MgServicePrincipal -Filter "appId eq '$($App.AppId)'" -ConsistencyLevel eventual
    if (-not $sp) {
        Write-Host "Creating service principal for app '$($App.DisplayName)'..." -ForegroundColor Cyan
        $sp = New-MgServicePrincipal -AppId $App.AppId
    }
    return $sp
}

function Get-ResourceServicePrincipal {
    param(
        [string]$DisplayName,             # e.g., "SharePoint Online", "Dynamics 365 Business Central"
        [string]$AppIdGuid,               # optional direct AppId
        [string]$AppIdUri                 # optional direct App ID URI
    )
    if ($AppIdGuid) {
        return Get-MgServicePrincipal -Filter "appId eq '$AppIdGuid'" -ConsistencyLevel eventual
    }
    if ($AppIdUri) {
        return Get-MgServicePrincipal -Filter "identifierUris/any(u:u eq '$AppIdUri')" -ConsistencyLevel eventual
    }
    if ($DisplayName) {
        $sp = Get-MgServicePrincipal -Filter "displayName eq '$DisplayName'" -ConsistencyLevel eventual
        if ($sp.Count -gt 1) { throw "Multiple service principals match displayName '$DisplayName'." }
        return $sp
    }
    throw "Provide DisplayName or AppIdGuid or AppIdUri to locate the resource service principal."
}

function Ensure-AppRoleAssignment {
    param(
        [Parameter(Mandatory)]$ClientSp,  # your application's service principal
        [Parameter(Mandatory)]$ResourceSp,# resource service principal (e.g., SharePoint, BC, custom API)
        [Parameter(Mandatory)][string]$AppRoleValue # value field (e.g., 'Sites.FullControl.All')
    )
    $role = $ResourceSp.AppRoles | Where-Object { $_.Value -eq $AppRoleValue -and $_.AllowedMemberTypes -contains "Application" }
    if (-not $role) {
        throw "App role '$AppRoleValue' not found on resource '$($ResourceSp.DisplayName)'."
    }

    # Check if already assigned
    $existing = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $ClientSp.Id `
                 | Where-Object { $_.ResourceId -eq $ResourceSp.Id -and $_.AppRoleId -eq $role.Id }

    if ($existing) {
        Write-Host "App role '$($role.Value)' already assigned on '$($ResourceSp.DisplayName)'." -ForegroundColor DarkGray
        return $existing
    }

    Write-Host "Granting '$($role.Value)' on '$($ResourceSp.DisplayName)'..." -ForegroundColor Cyan
    New-MgServicePrincipalAppRoleAssignment `
        -ServicePrincipalId $ClientSp.Id `
        -PrincipalId $ClientSp.Id `
        -ResourceId $ResourceSp.Id `
        -AppRoleId $role.Id | Out-Null
}

# ==================================
# ======= Connect & Validate =======
# ==================================
Ensure-Module -Name Microsoft.Graph
Ensure-ConnectedGraph

Write-Host "`n=== Loading/creating certificate ===" -ForegroundColor Yellow
$certOut   = New-Or-Load-Certificate -SubjectCN $CertSubjectCN -OutDir $CertOutDir -Years $CertValidityYears -PfxPassword $PfxPasswordPlain -CreateNew $CreateNewCert

Write-Host "`n=== Resolving App Registration ===" -ForegroundColor Yellow
$app = Get-AppByDisplayName -DisplayName $AppDisplayName

Write-Host "`n=== Uploading certificate to App Registration ===" -ForegroundColor Yellow
Add-CertificateToApp -App $app -CerPath $certOut.CerPath -DisplayName "Cert-$((Get-Date).ToString('yyyyMMdd'))"

Write-Host "`n=== Ensuring Service Principal exists ===" -ForegroundColor Yellow
$clientSp = Ensure-ServicePrincipalForApp -App $app

# ==================================
# ======= Resource Permissions ======
# ==================================

# ---- Business Central (Application permissions) ----
# Common display name in tenants: "Dynamics 365 Business Central"
# App roles often used: "API.ReadWrite.All" and "Automation.ReadWrite.All"
Write-Host "`n=== Granting permissions for Business Central ===" -ForegroundColor Yellow
$bcSp = Get-ResourceServicePrincipal -DisplayName "Dynamics 365 Business Central"
if (-not $bcSp) { throw "Could not find Service Principal for 'Dynamics 365 Business Central' in this tenant." }

Ensure-AppRoleAssignment -ClientSp $clientSp -ResourceSp $bcSp -AppRoleValue "API.ReadWrite.All"
Ensure-AppRoleAssignment -ClientSp $clientSp -ResourceSp $bcSp -AppRoleValue "Automation.ReadWrite.All"

# ---- SharePoint (Application permissions) ----
# SharePoint Online’s SP display name is typically "SharePoint Online"
# App role commonly used for app-only is "Sites.FullControl.All"
Write-Host "`n=== Granting permissions for SharePoint Online ===" -ForegroundColor Yellow
$spoSp = Get-ResourceServicePrincipal -DisplayName "SharePoint Online"
if (-not $spoSp) { throw "Could not find Service Principal for 'SharePoint Online' in this tenant." }

Ensure-AppRoleAssignment -ClientSp $clientSp -ResourceSp $spoSp -AppRoleValue "Sites.FullControl.All"

# ---- Custom API (Application permissions) ----
Write-Host "`n=== Granting permissions for your Custom API ===" -ForegroundColor Yellow
$customSp = $null
if ($CustomApi_ResourceAppId -and $CustomApi_ResourceAppId -ne "<CUSTOM-API-APPID-GUID>") {
    $customSp = Get-ResourceServicePrincipal -AppIdGuid $CustomApi_ResourceAppId
} elseif ($CustomApi_AppIdUri) {
    $customSp = Get-ResourceServicePrincipal -AppIdUri $CustomApi_AppIdUri
}

if (-not $customSp) {
    Write-Warning "Custom API not found. Set either CustomApi_ResourceAppId or CustomApi_AppIdUri and re-run."
} else {
    Ensure-AppRoleAssignment -ClientSp $clientSp -ResourceSp $customSp -AppRoleValue $CustomApi_AppRoleValue
}

Write-Host "`n=== DONE: Certificate uploaded and app roles assigned ===" -ForegroundColor Green
Write-Host "Certificate files:"
Write-Host "  CER: $($certOut.CerPath)"
Write-Host "  PFX: $($certOut.PfxPath)"
``