# Delete Sandbox environment
# BE cAREFULL: NO QUESTIONS ASKED !!!! #
$environmentNameToDelete = "TestRISA"
$response = Invoke-WebRequest `
    -Method Delete `
    -Uri    "https://api.businesscentral.dynamics.com/admin/$apiVersion/applications/$applicationFamily/environments/$environmentNameToDelete" `
    -Headers @{Authorization=("Bearer $accessToken")} 
write-host -ForegroundColor Green 'Environment' $environmentNameToDelete 'is deleted'
ConvertFrom-Json $response.Content
