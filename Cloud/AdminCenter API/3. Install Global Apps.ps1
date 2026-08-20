<# Migration Apps
$AppIdsToInstall =
"58623bfa-0559-4bc2-ae1c-0979c29fd9e0", #"Intelligent Cloud Base"
"334ef79e-547e-4631-8ba1-7a7f18e14de6", #"Business Central Intelligent Cloud"
"6992416F-3F39-4D3C-8242-3FFF61350BEA", #"Business Central Cloud Migration - Previous Release"
"57623bfa-0559-4bc2-ae1c-0979c29fc8d1", #"Business Central Cloud Migration API"
"1a91ec97-a44b-461c-a10f-fabf9d0c32f9", #"4PS Hour Registration W1"
"5697f1f3-2156-4211-bedd-32f0da5ae24d", #"4PS Base API NL",
"44bb2baa-6686-4534-9d3c-a758a767047f", #"4PS Azure Maps W1"
"516ce6df-b904-4272-b405-5ad3b2e2422d" #"4PS File Explorer W1"
#>

# Apps to install
$AppIdsToInstall =
"1a91ec97-a44b-461c-a10f-fabf9d0c32f9", #"4PS Hour Registration W1"
"1b3790da-e8ba-4a11-92a9-c70e37b4f831", #"Direct Banking"
"5697f1f3-2156-4211-bedd-32f0da5ae24d", #"4PS Base API NL",
"3e745006-8ef7-4c52-94a5-e80ba883061b", #"4PS Scheduler (GRP) W1"
"44bb2baa-6686-4534-9d3c-a758a767047f", #"4PS Azure Maps W1"
"4fa3e3b4-e8d8-42f9-97e5-45c07dfc6f19", #"4PS DSP NL"
"516ce6df-b904-4272-b405-5ad3b2e2422d", #"4PS File Explorer W1"
"d88114df-7395-4ec3-b45f-f4f8d750051c", #"4PS WebShop Basket Connector Base NL"
"9a91ec97-a44b-461c-a10f-fabf9d0c32f0", #"4PS Control W1"
"bec4ca36-c7fb-4110-9db5-29559cc1f84c", #"Jet Reports for Business Central"
"b1e4fe65-38e4-41f2-b077-1731167d3b10", #"Exsion Reporting"
"9d92a7c1-67bb-4f7d-b032-d26e21d98fcb", #"4PS Appointment API W1"
"a3ee508f-11aa-4d36-bc0a-21b2e3eb2ea9", #"4PS Home Control W1"
"f5a24f0f-0e9d-41b6-a407-b3c83e4ca460", #"Jet Analytics for Business Central"
"f11aaf49-158b-4d08-aa8c-342d1b0391f1", #"4PS Bing Maps W1"
"4aadc1a9-c361-4b86-a749-139a492026a0", #"Jet Library for Business Central"
"dbc58319-fb06-4cbf-ac7c-cde775273589", #"4PS Plant Portal W1"
"5c522010-d425-4c57-81dc-0375690de474", #"4PS Control Extended NL"
"6e68aa49-6360-4cf1-b596-29b0d481ee2a", #"Idyn App Management"
"7d5b57c9-71d8-47f0-85b8-7a08066f7d2b", #"Direct Banking NL"
"d1e24796-0bc7-43a5-bb58-8afa9762a1f9", #"4PS CAPO Interface NL"
"a1066138-c3eb-432a-a51c-b923bec39a8a", #"4PS Technishe Unie NL"
"58623bfa-0559-4bc2-ae1c-0979c29fd9e0", #"Intelligent Cloud Base"
"334ef79e-547e-4631-8ba1-7a7f18e14de6", #"Business Central Intelligent Cloud"
"6992416F-3F39-4D3C-8242-3FFF61350BEA", #"Business Central Cloud Migration - Previous Release"
"57623bfa-0559-4bc2-ae1c-0979c29fc8d1", #"Business Central Cloud Migration API"
"b7174aae-753c-4e71-bacb-d973995dce5e", #"_Exclude_ReportLayouts",
"8fc50dfb-d338-4fd9-9499-5e44cc8cbf50", #"Email - SMTP API",
"aceb66c8-472e-437c-81d3-27e6c07d0f14", #"Email - Microsoft 365 Connector",
"08d69832-9231-429e-be2c-8bab2c96905b", #"Email - Current User Connector",
"e6328152-bb29-4664-9dae-3bc7eaae1fd8", #"Email - Outlook REST API",
"68e13fa3-217a-4be0-9141-99e5bf0ca818" #"Email - SMTP Connector",

$EnvironmentsToUpdate | ForEach-Object {
    $environment = $_.name

    $i = 1
    $NoOfApps = $AppIdsToInstall.Count

    foreach ($App in $AppIdsToInstall) {

        Write-Host "Install app $i of $NoOfApps : $App"

        Invoke-WebRequest `
            -Method Post `
            -Uri    "https://api.businesscentral.dynamics.com/admin/$apiVersion/applications/$applicationFamily/environments/$environment/apps/$App/install" `
            -Body   (@{
                        "AcceptIsvEula" = $true #set to $true once you've read the the app provider's terms of use and privacy policy
                        "languageId" = "1043"
                        "installOrUpdateNeededDependencies" = $true
                        "useEnvironmentUpdateWindow" = $false
                    } | ConvertTo-Json) `
            -Headers @{Authorization=("Bearer $accessToken")} `
            -ContentType "application/json"

        $i = $i +1

    }

    # Check install status
    Do {
        $response = Invoke-WebRequest `
        -Method Get `
        -Uri    "https://api.businesscentral.dynamics.com/admin/$apiVersion/applications/$applicationFamily/environments/$environment/operations" `
        -Headers @{Authorization=("Bearer $accessToken")}
        $Operations = $response.Content | ConvertFrom-Json
        $Operations = $Operations.value
        $operationsRunning = $Operations | Where-Object { $_.status -eq "scheduled" -or $_.status -eq "running" }
        $amount = $operationsRunning.count
        if ( $operationsRunning.count -ne '' ) {
            write-host "Installation of $amount extensions remaining..."
            Start-Sleep -Seconds 15
        }
    }
    Until( $operationsRunning.count -eq $NoOfApps )

    # List installed apps
    Write-Host "Installed apps in $Environment"
    $response = Invoke-WebRequest `
        -Method Get `
        -Uri    "https://api.businesscentral.dynamics.com/admin/$apiVersion/applications/$applicationFamily/environments/$environment/apps" `
        -Headers @{Authorization=("Bearer $accessToken")}
    ConvertFrom-Json $response.Content | Select-Object -ExpandProperty Value | Select-Object -Property id, name, publisher, version, state | Format-Table | Out-String | Write-Host
}

