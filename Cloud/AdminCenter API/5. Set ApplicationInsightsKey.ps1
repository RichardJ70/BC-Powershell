# Get Application Insights Key production environment
# Not supported

# Set Application Insights Key to new sandbox.
# This will restart the environment
$appInsightsKey = "InstrumentationKey=00000000-0000-0000-0000-000000000000"

$EnvironmentsToUpdate | ForEach-Object {
    $Environment = $_.name
    Invoke-WebRequest `
        -Method Post `
        -Uri    "https://api.businesscentral.dynamics.com/admin/$apiVersion/applications/$applicationFamily/environments/$Environment/settings/appinsightskey" `
        -Body   (@{
                    key = $appInsightsKey
                } | ConvertTo-Json) `
        -Headers @{Authorization=("Bearer $accessToken")} `
        -ContentType "application/json"
    Write-Host -ForegroundColor Green 'Application Insights Key is set to sandbox environment' $Environment
}

