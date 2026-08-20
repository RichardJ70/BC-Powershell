# Copy production environment to a sandbox environment
$sourceEnvironment = Read-Host -Prompt "What is the source environment?"
$targetEnvironment = Read-Host -Prompt "What is the target environment?"

$title = "New Production or Sandbox environment"
$question = "Do you want to create a new Sandbox or a new Production environment?"
$choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&1 - Sandbox'))
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&2 - Production'))
$decision = $Host.UI.PromptForChoice($title, $question, $choices, 0)
if ($decision -eq 0) {
    $targetType = 'Sandbox'
} else {
    $targetType = 'Production'
}

$response = Invoke-WebRequest `
    -Method Post `
    -Uri    "https://api.businesscentral.dynamics.com/admin/$apiVersion/applications/$applicationFamily/environments/$sourceEnvironment/copy" `
    -Body   (@{
                 EnvironmentName = $targetEnvironment
                 Type            = $targetType
              } | ConvertTo-Json) `
    -Headers @{Authorization=("Bearer $accessToken")} `
    -ContentType "application/json"
Write-Host -ForegroundColor Green 'Environment '$targetEnvironment' will be created as a '$targetType' environment from source environment '$sourceEnvironment

Do {
    Start-Sleep 15
    $environmentList = Invoke-WebRequest `
        -Method Get `
        -Uri    "https://api.businesscentral.dynamics.com/admin/$apiVersion/applications/$applicationFamily/environments" `
        -Headers @{Authorization=("Bearer $accessToken")}
    Write-Host -ForegroundColor Green 'Prepraring 4PS environment' $Environment
    $CopyEnvironment = ConvertFrom-Json $environmentList.Content | Select-Object -ExpandProperty value | where-object {($_.status -eq 'Preparing') -and ($_.name -eq $TargetEnvironment)}
    $CopyBusy = $CopyEnvironment.Count
}
Until( $CopyBusy -eq 0 )

$response = Invoke-WebRequest `
    -Method Get `
    -Uri    "https://api.businesscentral.dynamics.com/admin/$apiVersion/applications/$applicationFamily/environments" `
    -Headers @{Authorization=("Bearer $accessToken")}
Write-Host -ForegroundColor Green 'Active 4PS environment' $Environment
ConvertFrom-Json $response.Content | Select-Object -ExpandProperty value | Select-Object -Property name, type, applicationfamily, applicationversion, status, platformversion | where-object {($_.status -eq 'Active') -and ($_.name -eq $TargetEnvironment)} |Format-Table | Out-String | Write-Host
