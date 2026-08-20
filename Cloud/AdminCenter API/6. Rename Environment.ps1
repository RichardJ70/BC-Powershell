# Rename Environment
$environmentNameToRename = "BVGO_Template2"
$newenvironmentName = "VWBTemplate"
$response = Invoke-WebRequest `
    -Method Post `
    -Uri    "https://api.businesscentral.dynamics.com/admin/$apiVersion/applications/$applicationFamily/environments/$environmentNameToRename/rename" `
    -Body   (@{
                 NewEnvironmentName = $newenvironmentName
              } | ConvertTo-Json) `
    -Headers @{Authorization=("Bearer $accessToken")} `
    -ContentType "application/json"
Write-Host -ForegroundColor Green 'Environment' $environmentNameToRename 'is renamed to' $newenvironmentName
ConvertFrom-Json $response.Content