# Parameters
$aadTenantId = "" # customer's tenant id
#$aadAppId    = "" # customer's client id with api permission API.ReadWrite.All en Automation.ReadWrite.All
$aadAdminApi = "" # customer's client id with api permission AdminCenter.ReadWrite.All                                      
$Environment = "" # customer's environment
$ClientSecretAdminApi = Read-Host "Enter Client Secret admin center API" -AsSecureString
#$ClientSecretApi = Read-Host "Enter Client Secret BC API" -AsSecureString 

# Fixed parameters
$aadAppRedirectUri = "https://4psconstruct.bc.dynamics.com/OAuthLanding.htm"               # partner's AAD app redirect URI
$applicationFamily = '4psconstruct'
$apiVersion      = 'V2.29'

# Only needs to be done once: Install the MSAL PowerShell module (see https://github.com/AzureAD/MSAL.PS)
#Install-Module MSAL.PS

#Get Token App registration Admin Center API
$msalTokenAdmin = Get-MsalToken `
    -ClientId $aadAdminApi `
    -ClientSecret $ClientSecretAdminApi `
    -RedirectUri $aadAppRedirectUri `
    -TenantId $aadTenantId `
    -Authority "https://login.microsoftonline.com/$aadTenantId" `
    -Scope "https://api.businesscentral.dynamics.com/.default"
$accessTokenAdmin = $msalTokenAdmin.AccessToken
Write-Host -ForegroundColor Cyan 'Authentication complete - we have an access token for Business Central Admin Center API, and it is stored in the $accessTokenAdmin variable.'

#Get Token App registration BC API
#Appregistration 
#$msalToken = Get-MsalToken `
#    -ClientId $aadappId `
#    -ClientSecret $ClientSecretApi `
#    -RedirectUri $aadAppRedirectUri `
#    -TenantId $aadTenantId `
#    -Authority "https://login.microsoftonline.com/$aadTenantId" `
#    -Scope "https://api.businesscentral.dynamics.com/.default"
#$accessToken = $msalToken.AccessToken
#Write-Host -ForegroundColor Cyan 'Authentication complete - we have an access token for a Business Central API, and it is stored in the $accessTokenAdmin variable.'

#When no app registration is available, use a device login with an admin user with the Dynamics 365 Administrator or Dynamics 365 Business Central Administrator role
Import-Module BcContainerHelper -Verbose

$bcContainerHelperConfig.apiBaseUrl = "https://4psconstruct.api.bc.dynamics.com"
$bcContainerHelperConfig.baseUrl = "https://4psconstruct.bc.dynamics.com"
$authContext = New-BcAuthContext -includeDeviceLogin
$accessToken = $authContext.AccessToken
Write-Host -ForegroundColor Cyan 'Authentication complete - we have an access token for Business Central as device login , and it is stored in the $accessToken variable.'

# Get Global apps using Admin Center API token
$response = Invoke-WebRequest `
            -Method Get `
            -Uri    "https://api.businesscentral.dynamics.com/admin/$apiVersion/applications/$applicationFamily/environments/$environment/apps" `
            -Headers @{Authorization=("Bearer $accessTokenAdmin")}
$appsEnvironment = ConvertFrom-Json $response.Content | Select-Object -ExpandProperty Value

$appsEnvironment | ForEach-Object {

    $appId = $_.id
    $appName = $_.name
    $apppublisher = $_.publisher
    $appversion = $_.version
 
    #Get the app info as a user or app registration with api permissions API.ReadWrite.All en Automation.ReadWrite.All
    $response = Invoke-WebRequest `
        -Method Get `
        -Uri    "https://4psconstruct.api.bc.dynamics.com/v2.0/$environment/dev/packages?publisher=$apppublisher&appName=$appName&versionText=$appversion&appId=$appId" `
        -Headers @{Authorization=("Bearer $accessToken")}
    
    if ($response.StatusCode -eq 200) {
        $contentDisposition = $response.Headers["Content-Disposition"]
        Write-Output "Content-Disposition header: $contentDisposition"

        if ($contentDisposition) {
            # Try to match the filename* first, then fallback to filename
            $fileNameMatch = [regex]::Match($contentDisposition, 'filename\*?="?([^";]+)"?')
            if ($fileNameMatch.Success) {
                $fileName = $fileNameMatch.Groups[1].Value
                Write-Output "File name from Content-Disposition header: $fileName"
            } 
        }
        
        $filePath = "C:\temp\Apps\$fileName"

        [System.IO.File]::WriteAllBytes($filePath, $response.Content)
        Write-Output "File downloaded successfully to $filePath"
    } else {
        Write-Output "Failed to download the file. Status code: $($response.StatusCode)"
    }
}