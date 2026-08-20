# Recover Deleted Environment
$environmentNameToRecover = "Fill in the environment name to recover"
$response = Invoke-WebRequest `
    -Method Post `
    -Uri    "https://api.businesscentral.dynamics.com/admin/$apiVersion/applications/$applicationFamily/environments/$environmentNameToRecover/recover" `
    -Headers @{Authorization=("Bearer $accessToken")} 
write-host -ForegroundColor Green 'Environment' $environmentNameToRecover 'is recovered'
ConvertFrom-Json $response.Content