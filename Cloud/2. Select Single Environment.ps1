# Get active 4PS environments
$Environment = "ACC"

$environmentList = Invoke-WebRequest `
    -Method Get `
    -Uri    "https://api.businesscentral.dynamics.com/admin/$adminVersion/applications/$applicationFamily/environments" `
    -Headers @{Authorization=("Bearer $accessToken")}
Write-Host -ForegroundColor Green 'Active 4PS environment' $Environment
ConvertFrom-Json $environmentList.Content | Select-Object -ExpandProperty value | Select-Object -Property name, type, applicationfamily, applicationversion, status, platformversion | where-object {($_.status -eq 'Active') -and ($_.name -eq $Environment)} |Format-Table | Out-String | Write-Host
$EnvironmentsToUpdate = $environmentList.Content | ConvertFrom-Json | Select-Object -ExpandProperty value | where-object {($_.status -eq 'Active') -and ($_.name -eq $Environment)} 