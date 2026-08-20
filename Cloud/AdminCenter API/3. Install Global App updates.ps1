# Install app updates in all environments
$title = "Install app updates all environments"
$question = "Schedule the update to run in the maintenance window?"
$choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))
$decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
if ($decision -eq 0){
    $useMaintenanceWindows  = $true
} else {
    $useMaintenanceWindows  = $false
}

# Get available updates
$EnvironmentsToUpdate | ForEach-Object {
    $Environment = $_.name
    $applicationFamily = $_.applicationFamily
    Clear-Host
    Write-Host 'Available updates for Environment:' $Environment -ForegroundColor Yellow

    $response = Invoke-WebRequest `
    -Method Get `
    -Uri    "https://api.businesscentral.dynamics.com/admin/$apiVersion/applications/$applicationFamily/environments/$Environment/apps/availableUpdates" `
    -Headers @{Authorization=("Bearer $accessToken")}
    $appsToUpdate = ConvertFrom-Json $response.Content | Select-Object -ExpandProperty value
    $appsToUpdateList = $appsToUpdate | Select-Object -Property appId, name, publisher, version | Sort-Object -Property name | Format-Table | Out-String

    $NoOfApps = $appsToUpdate.Count

    if ($NoOfApps -eq 0) {
        Write-Host ("No available updates, you are up-to-date.") -ForegroundColor Green
    } else {
        Write-Host ("Found $NoOfApps updates:") -ForegroundColor Yellow
        $appsToUpdateList
        pause

        $title = "Install app updates"
        $question = "Do you want to install these updates in the environment?"
        $choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
        $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
        $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))
        $decision = $Host.UI.PromptForChoice($title, $question, $choices, 0)
        $i = 1

        if ($decision -eq 0) {
            if ($useMaintenanceWindows -eq $false) {
                Write-Host ("You are not using the maintenance window. Updates will start shortly and user sessions may be lost. Continue?") -ForegroundColor Magenta
                pause
            }
            foreach ($App in $appsToUpdate) {
                $AppId = $App.appId
                $AppVer = $App.version
                $AppName = $App.name
                Write-Host ("Scheduling update $i of $NoOfApps : app Id: $AppId   Name: $AppName   Version: $AppVer") -ForegroundColor Yellow
                
                # Update apps
                $appIdToUpdate = $AppId
                $appTargetVersion = $AppVer
                $response = Invoke-WebRequest `
                  -Method Post `
                  -Uri    "https://api.businesscentral.dynamics.com/admin/$apiVersion/applications/$applicationFamily/environments/$Environment/apps/$appIdToUpdate/update" `
                  -Body   (@{
                               targetVersion = $appTargetVersion
                               installOrUpdateNeededDependencies = $true
                               useEnvironmentUpdateWindow = $useMaintenanceWindows
                            } | ConvertTo-Json) `
                  -Headers @{Authorization=("Bearer $accessToken")} `
                  -ContentType "application/json"
                $i = $i +1
            }
       
        } else { 
                Write-Host ("Updates skipped") -ForegroundColor Magenta 
        }      
    }
}

$EnvironmentsToUpdate | ForEach-Object {
    $Environment = $_.name
    $applicationFamily = $_.applicationFamily
    Write-Host 'Check update status for Environment:' $Environment -ForegroundColor Green

    if ($useMaintenanceWindows -eq $false) {
        Do {
            Start-Sleep -Seconds 15
            $response = Invoke-WebRequest `
                -Method Get `
                -Uri    "https://api.businesscentral.dynamics.com/admin/$apiVersion/applications/$applicationFamily/environments/$Environment/apps/availableUpdates" `
                -Headers @{Authorization=("Bearer $accessToken")}
            $UpdatesRemaining = ConvertFrom-Json $response.Content | Select-Object -ExpandProperty value
            $NoOfUpdatesRemaining = $UpdatesRemaining.count
            Write-host "Updates remaining $NoOfUpdatesRemaining"
        }
        Until( $NoOfUpdatesRemaining -eq 0 )

        # List installed apps
        Write-Host "Installed apps in $Environment"
        $response = Invoke-WebRequest `
            -Method Get `
            -Uri    "https://api.businesscentral.dynamics.com/admin/$apiVersion/applications/$applicationFamily/environments/$environment/apps" `
            -Headers @{Authorization=("Bearer $accessToken")}
        ConvertFrom-Json $response.Content | Select-Object -ExpandProperty Value | Select-Object -Property id, name, publisher, version, state | Format-Table | Out-String | Write-Host
    }
} 