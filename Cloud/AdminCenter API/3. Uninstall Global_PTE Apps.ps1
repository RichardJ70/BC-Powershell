# Apps to uninstall
$AppIdsToUnInstall =
"1b3790da-e8ba-4a11-92a9-c70e37b4f831", #"Direct Banking"
"E0B65886-53B0-47C6-B680-C72FD8A0D169" #4PS COHUB Interface 4PS Markplaats

$title = "Delete data"
$question = "Do you want to delete the data with the app removal?"
$choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))
$decision = $Host.UI.PromptForChoice($title, $question, $choices, 0)
if ($decision -eq 0) {
    $deleteData = $true
} else {
    $deleteData = $false
}

$title = "Uninstall dependent apps"
$question = "Do you want to uninstall dependent apps?"
$choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))
$decision = $Host.UI.PromptForChoice($title, $question, $choices, 0)
if ($decision -eq 0) {
    $UninstallDependentApps = $true
} else {
    $UninstallDependentApps = $false
}

$EnvironmentsToUpdate | ForEach-Object {
    $Environment = $_.name

    $i = 1
    $NoOfApps = $AppIdsToUnInstall.Count

    foreach ($App in $AppIdsToInstall) {

        Write-Host "Removal app $i of $NoOfApps : $App from $Environment"
 
        Invoke-WebRequest `
        -Method Post `
        -Uri    "https://api.businesscentral.dynamics.com/admin/$apiVersion/applications/$applicationFamily/environments/$Environment/apps/$appIdsToUnInstall/uninstall" `
        -Body   (@{
                    deleteData = $deleteData
                    uninstallDependents = $UninstallDependentApps
                    useEnvironmentUpdateWindow = $false    
                } | ConvertTo-Json) `
        -Headers @{Authorization=("Bearer $accessToken")} `
        -ContentType "application/json"

        $i = $i +1
    }

    # Check install status
    Do {
        $response = Invoke-WebRequest `
        -Method Get `
        -Uri    "https://api.businesscentral.dynamics.com/admin/$apiVersion/applications/$applicationFamily/environments/$Environment/operations" `
        -Headers @{Authorization=("Bearer $accessToken")}
        $Operations = $response.Content | ConvertFrom-Json
        $Operations = $Operations.value
        $operationsRunning = $Operations | Where-Object { $_.status -eq "scheduled" -or $_.status -eq "running" }
        $amount = $operationsRunning.count
        if ( $operationsRunning.count -ne '' ) {
            write-host "De-Installation of $amount extensions remaining..."
            Start-Sleep -Seconds 15
        }
    }
    Until( $operationsRunning.count -eq '' )   

    # List installed apps
    Write-Host "Installed apps in $Environment"
    $response = Invoke-WebRequest `
        -Method Get `
        -Uri    "https://api.businesscentral.dynamics.com/admin/$apiVersion/applications/$applicationFamily/environments/$environment/apps" `
        -Headers @{Authorization=("Bearer $accessToken")}
    Write-Host (ConvertTo-Json (ConvertFrom-Json $response.Content))
}