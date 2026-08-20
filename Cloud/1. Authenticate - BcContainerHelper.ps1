#### This powershell script can be used for the most common admin center tasks    ####
#### for both single environments and multi environments within the same tenant   ####
####                                                                              ####
#### To be able to use the admin center API check the learning portal             ####
#### Using BcContainerHelper, you dont't need to have an app registration         ####
#### Having a role as Dynamics 365 (Business Central) Administrator is sufficient ####

#Install-Module BcContainerHelper -Force
Import-Module BcContainerHelper -Verbose

#Shared Parameters
$apiVersion = "V2.29"
$applicationFamily = "4PSConstruct"
#$tenantId = Read-Host "Enter the MS TenantId"

$question = "Select the customer to use the admin center of"
$choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&1 - Customer 1'))
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&2 - Customer 2'))
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&3 - Customer 3'))
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&4 - Customer 4'))
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&5 - Customer 5'))

$decision = $Host.UI.PromptForChoice($title, $question, $choices, 0)
Clear-Host
if ($decision -eq 0) { 
    $tenantId = 'TenantId Customer 1'
    } elseif ($decision -eq 1) {
        $tenantId = 'TenantId Customer 2'
        } elseif ($decision -eq 2) {
            $tenantId = 'TenantId Customer 3'
            } elseif ($decision -eq 3) {
                $tenantId = 'TenantId Customer 4'
            } elseif ($decision -eq 4) {
                $tenantId = 'TenantId Customer 5'
            }

######### Login #############
if ($tenantId -eq "") {
    $authContext = New-BcAuthContext -includeDeviceLogin
} else {
    $authContext = New-BcAuthContext -includeDeviceLogin -tenantID $tenantId
}
$accessToken = $authContext.AccessToken
Write-Host -ForegroundColor Cyan 'Authentication complete - we have an access token for Business Central, and it is stored in the $accessToken variable.'

