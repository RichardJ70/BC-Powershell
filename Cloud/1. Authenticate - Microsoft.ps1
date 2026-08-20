# This sample authenticates to Azure Active Directory (AAD) an obtains an access token.
# The access token can be used for authenticating to Business Central APIs.

# Parameters
$aadTenantId = "" # customer's tenant id
$aadAppId    = "" # partner's AAD app id

# Fixed parameters
$ClientSecret =  Read-Host "Enter Client Secret" -AsSecureString
$aadAppRedirectUri = "https://4psconstruct.bc.dynamics.com/OAuthLanding.htm"               # partner's AAD app redirect URI
$aadAppSecret      = $ClientSecret
$applicationFamily = '4psconstruct'
$apiVersion      = 'V2.29'

# Only needs to be done once: Install the MSAL PowerShell module (see https://github.com/AzureAD/MSAL.PS)
#Install-Module MSAL.PS
$msalToken = Get-MsalToken `
    -ClientId $aadAppId `
    -ClientSecret $aadAppSecret `
    -RedirectUri $aadAppRedirectUri `
    -TenantId $aadTenantId `
    -Authority "https://login.microsoftonline.com/$aadTenantId" `
    -Scope "https://api.businesscentral.dynamics.com/.default"

$accessToken = $msalToken.AccessToken
Write-Host -ForegroundColor Cyan 'Authentication complete - we have an access token for Business Central, and it is stored in the $accessToken variable.'

<#
# Peek inside the access token (this is just for education purposes; in actual API calls we'll just pass it as one long string)
$middlePart = $accessToken.Split('.')[1]
$middlePartPadded = "$middlePart$(''.PadLeft((4-$middlePart.Length%4)%4,'='))"
$middlePartDecoded = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($middlePartPadded))
$middlePartDecodedPretty = (ConvertTo-Json (ConvertFrom-Json $middlePartDecoded))
Write-Host "Contents of the access token:"
Write-Host $middlePartDecodedPretty

If someone has access to the client secret, you have usually 180 days to mess things up before the secret expires.
With this information, everyone can execute the scripts. Even end-users, no questions asked.
$ClientSecret =  ""
$aadAppSecret = ConvertTo-SecureString -String $ClientSecret -AsPlainText -Force
#>