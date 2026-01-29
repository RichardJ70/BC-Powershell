
# Script Publish-PerTenantExtensionApps.ps1 is modified to use only for PTE extensions and testing with 4PS Construct
# Publish-PerTenantExtensionApps `
#    -bcAuthContext $authContext `
#    -environment $environment `
#    -appFiles $apps 
#
# It works for Business Central Standard, but not for 4PS Construct. Probably because of the different API calls and the different way of handling the apps in
# version 23.51 of 4PS Construct and version 24.4 of Business Central Standard.

Install-Module BcContainerHelper -Force
Import-Module BcContainerHelper -Verbose

#Shared Parameters
$environment = "SandBox4PSNL" #4PS
$environment = "Production"
$environment = "Sandbox" #Standard BC
$tenant = "your tenant id"
$appfiles = "D:\Apps-Git\RISA\4PS\RISA_Application\RISA Support BV_RISA Application_24.4.0.0.app",
            "D:\Apps-Git\RISA\4PS\RISA_Financial\RISA Support BV_RISA Financial_24.4.0.0.app",
            "D:\Apps-Git\RISA\4PS\RISA_IT\RISA Support BV_RISA_IT_24.0.0.0.app",
            "D:\Apps-Git\RISA\4PS\RISA_Projects\RISA Support BV_RISA Projects_24.0.0.0.app",
            "D:\Apps-Git\RISA\4PS\RISA_Sales\RISA Support BV_RISA Sales_24.0.0.0.app"

#4PS Construct
$bcContainerHelperConfig.apiBaseUrl = "https://4psconstruct.api.bc.dynamics.com"
$bcContainerHelperConfig.baseUrl = "https://4psconstruct.bc.dynamics.com"

#Standard BC
#Not required to set these values but after changing the values, the script will work for 4PS Construct but not anymore for Standard BC
$bcContainerHelperConfig.apiBaseUrl = "https://api.businesscentral.dynamics.com"
$bcContainerHelperConfig.baseUrl = "https://businesscentral.dynamics.com"

######### Login #############
$authContext = New-BcAuthContext -includeDeviceLogin
$accessToken = $authContext.AccessToken

Write-Host -ForegroundColor Cyan 'Authentication complete - we have an access token for Business Central, and it is stored in the $accessToken variable.'

<#
companies
Write-Host "$automationApiUrl/companies"
$companies = Invoke-RestMethod -Headers (@{ "Authorization" = "Bearer $($accessToken)" }) -Method Get -Uri "$automationApiUrl/companies" -UseBasicParsing
$companies = $companies.value
$companies | ForEach-Object {
    $companyId = $_.id
    $companyName = $_.name  
    Write-Host "Company $companyName with id $companyId" -ForegroundColor Green
}
#>

# Standard BC
# https://api.businesscentral.dynamics.com/v2.0/$tenant/$environment/api/microsoft/automation/v2.0/companies($companyid)/extensions
$automationApiUrl = "$($bcContainerHelperConfig.apiBaseUrl.TrimEnd('/'))/v2.0/$tenant/$environment/api/microsoft/automation/v2.0"
$Contents = Invoke-WebRequest -Headers (@{ "Authorization" = "Bearer $($accessToken)" }) -Method Get -Uri "$automationApiUrl"
$Contents = Invoke-WebRequest -Headers (@{ "Authorization" = "Bearer $($accessToken)" }) -Method Get -Uri "$automationApiUrl/entityDefinitions"
$Contents = Invoke-WebRequest -Headers (@{ "Authorization" = "Bearer $($accessToken)" }) -Method Get -Uri "$automationApiUrl/extensions"
(ConvertFrom-Json $Contents.Content).value | Sort-Object -Property DisplayName



# 4PS Construct
# Geen api calls beschikbaar waar extension in beschikbaar zijn. Mogelijk dat dit komt door het verschil in versie van 4PS Construct en Business Central Standard
# Onderstaande zijn getest, maar hebben geen resultaat opgeleverd
$automationApiUrl = "$($bcContainerHelperConfig.apiBaseUrl.TrimEnd('/'))/v2.0/$environment/api/microsoft/admin/beta" #Get installed api calls microsoft/admin/beta
$automationApiUrl = "$($bcContainerHelperConfig.apiBaseUrl.TrimEnd('/'))/v2.0/$environment/api/microsoft/automation/beta" #Get installed api calls microsoft/automation/beta
$automationApiUrl = "$($bcContainerHelperConfig.apiBaseUrl.TrimEnd('/'))/v2.0/$environment/api/microsoft/automate/v1.0" #Get installed api calls microsoft/automate/beta
$automationApiUrl = "$($bcContainerHelperConfig.apiBaseUrl.TrimEnd('/'))/v2.0/$environment/api/microsoft/runtime/beta" #Get installed api calls microsoft/automation/beta

$Contents = Invoke-WebRequest -Headers (@{ "Authorization" = "Bearer $($accessToken)" }) -Method Get -Uri "$automationApiUrl"
(ConvertFrom-Json $Contents.Content).value | Sort-Object -Property DisplayName


#Get PTE Extensions per company
$companies = Invoke-RestMethod -Headers (@{ "Authorization" = "Bearer $($accessToken)" }) -Method Get -Uri "$automationApiUrl/companies" -UseBasicParsing
$companies = $companies.value
$companies | ForEach-Object {
    $companyId = $_.id
    $companyName = $_.name  
   
    Write-Host "Extensions from company $companyName with id $companyId" -ForegroundColor Green
    $getExtensions = Invoke-WebRequest -Headers (@{ "Authorization" = "Bearer $($accessToken)" }) -Method Get -Uri "$automationApiUrl/companies($companyId)/extensions"
    $extensions = (ConvertFrom-Json $getExtensions.Content).value | Sort-Object -Property DisplayName | Where-Object {($_.PublishedAs -EQ ' PTE')}
    (ConvertFrom-Json $getExtensions.Content).value | Sort-Object -Property DisplayName | Select-Object -Property id,DisplayName,versionMajor,versionMinor,versionBuild,versionRevision,publisher, isInstalled, PublishedAs | Where-Object {($_.PublishedAs -EQ ' PTE')} | Format-Table -AutoSize

    Write-Host "Publishing and installing apps" -ForegroundColor Green
    $body = @{"schedule" = "Current Version"}
    $body."SchemaSyncMode" = "Force Sync"
    $ifMatchHeader = @{ "If-Match" = '*'}
    $jsonHeader = @{ "Content-Type" = 'application/json'}
    $streamHeader = @{ "Content-Type" = 'application/octet-stream'}
    try {
        Sort-AppFilesByDependencies -appFiles $appFiles -excludeRuntimePackages | ForEach-Object {
            Write-Host -NoNewline "$([System.IO.Path]::GetFileName($_)) - "
            $appJson = Get-AppJsonFromAppFile -appFile $_
            
            $existingApp = $extensions | Where-Object { $_.id -eq $appJson.id -and $_.isInstalled }
        
            if ($existingApp) {
                if ($existingApp.isInstalled) {
                    $existingVersion = [System.Version]"$($existingApp.versionMajor).$($existingApp.versionMinor).$($existingApp.versionBuild).$($existingApp.versionRevision)"
                    if ($existingVersion -ge $appJson.version) {
                        Write-Host "already installed"
                    }
                    else {
                        Write-Host @newLine "upgrading"
                        $existingApp = $null
                    }
                }
                else {
                    Write-Host @newLine "installing"
                    $existingApp = $null
                }
            }
            else {
                Write-Host @newLine "publishing and installing"
            }
        
            if (!$existingApp) {
                $extensionUpload = (Invoke-RestMethod -Method Get -Uri "$automationApiUrl/companies($companyId)/extensionUpload" -Headers (@{ "Authorization" = "Bearer $($accessToken)" })).value
                Write-Host @newLine "."
                if ($extensionUpload -and $extensionUpload.systemId) {
                    $extensionUpload = Invoke-RestMethod `
                        -Method Patch `
                        -Uri "$automationApiUrl/companies($companyId)/extensionUpload($($extensionUpload.systemId))" `
                        -Headers ((@{ "Authorization" = "Bearer $($accessToken)" }) + $ifMatchHeader + $jsonHeader) `
                        -Body ($body | ConvertTo-Json -Compress)
                }
                else {
                    $ExtensionUpload = Invoke-RestMethod `
                        -Method Post `
                        -Uri "$automationApiUrl/companies($companyId)/extensionUpload" `
                        -Headers ((@{ "Authorization" = "Bearer $($accessToken)" }) + $jsonHeader) `
                        -Body ($body | ConvertTo-Json -Compress)
                }
                Write-Host @newLine "."
                if ($null -eq $extensionUpload.systemId) {
                    throw "Unable to upload extension"
                }
                $fileBody = [System.IO.File]::ReadAllBytes($_)
                Invoke-RestMethod `
                    -Method Patch `
                    -Uri $extensionUpload.'extensionContent@odata.mediaEditLink' `
                    -Headers ((@{ "Authorization" = "Bearer $($accessToken)" }) + $ifMatchHeader + $streamHeader) `
                    -Body $fileBody | Out-Null
                Write-Host @newLine "."    
                Invoke-RestMethod `
                    -Method Post `
                    -Uri "$automationApiUrl/companies($companyId)/extensionUpload($($extensionUpload.systemId))/Microsoft.NAV.upload" `
                    -Headers ((@{ "Authorization" = "Bearer $($accessToken)" }) + $ifMatchHeader) | Out-Null
                Write-Host @newLine "."    
                $completed = $false
                $errCount = 0
                $sleepSeconds = 30
                while (!$completed)
                {
                    Start-Sleep -Seconds $sleepSeconds
                    try {
                        $extensionDeploymentStatusResponse = Invoke-WebRequest -Headers (@{ "Authorization" = "Bearer $($accessToken)" }) -Method Get -Uri "$automationApiUrl/companies($companyId)/extensionDeploymentStatus" -UseBasicParsing
                        $extensionDeploymentStatuses = (ConvertFrom-Json $extensionDeploymentStatusResponse.Content).value
                    
                        $completed = $true
                        $extensionDeploymentStatuses | Where-Object { $_.publisher -eq $appJson.publisher -and $_.name -eq $appJson.name -and $_.appVersion -eq $appJson.version } | % {
                            if ($_.status -eq "InProgress") {
                                Write-Host @newLine "."
                                $completed = $false
                            }
                            elseif ($_.Status -eq "Unknown") {
                                throw "Unknown Error"
                            }
                            elseif ($_.Status -ne "Completed") {
                                $errCount = 5
                                throw $_.status
                            }
                        }
                        $errCount = 0
                        $sleepSeconds = 5
                    }
                    catch {
                        if ($errCount++ -gt 4) {
                            Write-Host $_.Exception.Message
                            throw "Unable to publish app. Please open the Extension Deployment Status Details page in Business Central to see the detailed error message."
                        }
                        $sleepSeconds += $sleepSeconds
                        $completed = $false
                    }
                }
                if ($completed) {
                    Write-Host "completed"
                }
            }
        }
    }
    catch [System.Net.WebException],[System.Net.Http.HttpRequestException] {
        Write-Host "ERROR $($_.Exception.Message)"
        Write-Host $_.ScriptStackTrace
        throw (GetExtendedErrorMessage $_)
    }
    catch {
        Write-Host "ERROR: $($_.Exception.Message) [$($_.Exception.GetType().FullName)]"
        TrackException -telemetryScope $telemetryScope -errorRecord $_
        throw
    }
    finally {
        $getExtensions = Invoke-WebRequest -Headers (@{ "Authorization" = "Bearer $($accessToken)" }) -Method Get -Uri "$automationApiUrl/companies($companyId)/extensions" -UseBasicParsing
        $extensions = (ConvertFrom-Json $getExtensions.Content).value | Sort-Object -Property DisplayName | Where-Object {($_.PublishedAs -EQ ' PTE')}
        (ConvertFrom-Json $getExtensions.Content).value | Sort-Object -Property DisplayName | Select-Object -Property id,DisplayName,versionMajor,versionMinor,versionBuild,versionRevision,publisher, isInstalled, PublishedAs | Where-Object {($_.PublishedAs -EQ ' PTE')} | Format-Table -AutoSize
        TrackTrace -telemetryScope $telemetryScope

        #Unpublish uninstalled extensions does not seem possible         

        Write-Host "Finished publishing and installing apps" -ForegroundColor Green
    }
}


