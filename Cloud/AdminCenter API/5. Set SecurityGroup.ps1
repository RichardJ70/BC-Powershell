## Security Group
<# Get security group
$environmentName = "Fill the environment name"
$response = Invoke-WebRequest `
    -Method Get `
    -Uri    "https://api.businesscentral.dynamics.com/admin/$apiVersion/applications/$applicationFamily/environments/$environmentName/settings/securitygroupaccess" `
    -Headers @{Authorization=("Bearer $accessToken")} `
    -ContentType "application/json"
$securitygroup = ConvertFrom-Json $response.Content
#>

# Set Security group

$securitygroup = "Fill the security group"
$response = Invoke-WebRequest `
    -Method Post `
    -Uri    "https://api.businesscentral.dynamics.com/admin/$apiVersion/applications/$applicationFamily/environments/$EnvironmentName/settings/securitygroupaccess" `
    -Body   (@{
                 Value = $securitygroup.id
              } | ConvertTo-Json) `
    -Headers @{Authorization=("Bearer $accessToken")} `
    -ContentType "application/json"
Write-Host -ForegroundColor Green 'Security Group' $securitygroup.id 'is set to sandbox environment' $EnvironmentName
