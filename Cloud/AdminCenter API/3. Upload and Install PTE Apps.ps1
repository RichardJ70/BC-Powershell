# Apps to install
$AppFilesToinstall = 
"D:\Git\RISA\Application_27.5.260629.0.app",
"D:\Git\RISA\CRM_27.5.260629.0.app",
"D:\Git\RISA\Sales_27.5.260701.0.app"

$question = "Select the deployment method"
$choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription '&1 - Immediately'))
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription '&2 - Update Window'))
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription '&3 - Next Minor Update'))
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription '&4 - Next Major Update'))

$decision = $Host.UI.PromptForChoice($title, $question, $choices, 0)

Write-Host "Decision: $decision"

switch ($decision) {
    0 { $deploymentSchedule = 'Immediate' }
    1 { $deploymentSchedule = 'UpdateWindow' }
    2 { $deploymentSchedule = 'NextMinorUpdate' }
    3 { $deploymentSchedule = 'NextMajorUpdate' }
}
        

$EnvironmentsToUpdate | ForEach-Object {

    $environment = $_.name
    $i = 1
    $NoOfApps = $AppFilesToInstall.Count

    foreach ($App in $AppFilesToInstall) {

        Write-Host "Install app $i of $NoOfApps : $App"

        if (-not (Test-Path -LiteralPath $App -PathType Leaf)) {
            Write-Error "App file not found: $App"
            $i++
            continue
        }

        $uri = "https://api.businesscentral.dynamics.com/admin/$apiVersion/applications/$applicationFamily/environments/$environment/apps/pteInstall"

        $httpClient = $null
        $multipartContent = $null
        $fileStream = $null
        $fileContent = $null

        try {
            $httpClient = [System.Net.Http.HttpClient]::new()
            $httpClient.DefaultRequestHeaders.Authorization =
                [System.Net.Http.Headers.AuthenticationHeaderValue]::new(
                    "Bearer",
                    $accessToken
                )

            $multipartContent =
                [System.Net.Http.MultipartFormDataContent]::new()

            # Actual binary .app file
            $fileStream = [System.IO.File]::OpenRead($App)
            $fileContent =
                [System.Net.Http.StreamContent]::new($fileStream)

            $fileContent.Headers.ContentType =
                [System.Net.Http.Headers.MediaTypeHeaderValue]::new(
                    "application/octet-stream"
                )

            $multipartContent.Add(
                $fileContent,
                "extensionFile",
                [System.IO.Path]::GetFileName($App)
            )

            # Other multipart fields
            $multipartContent.Add(
                [System.Net.Http.StringContent]::new($deploymentSchedule),
                "deploymentSchedule"
            )

            $multipartContent.Add(
                [System.Net.Http.StringContent]::new("Add"),
                "syncMode"
            )

            $multipartContent.Add(
                [System.Net.Http.StringContent]::new("nl-NL"),
                "languageId"
            )

            $multipartContent.Add(
                [System.Net.Http.StringContent]::new("true"),
                "acceptIsvEula"
            )

            $multipartContent.Add(
                [System.Net.Http.StringContent]::new("true"),
                "installOrUpdateNeededDependencies"
            )

            Write-Host "Environment       : $environment"
            Write-Host "Deployment schedule: $deploymentSchedule"
            Write-Host "Endpoint          : $uri"

            $response = $httpClient.PostAsync(
                $uri,
                $multipartContent
            ).GetAwaiter().GetResult()

            $responseBody = $response.Content.ReadAsStringAsync().
                GetAwaiter().
                GetResult()

            if (-not $response.IsSuccessStatusCode) {
                throw "HTTP $([int]$response.StatusCode) $($response.ReasonPhrase): $responseBody"
            }

            $operation = $responseBody | ConvertFrom-Json

            Write-Host "Upload accepted" -ForegroundColor Green
            Write-Host "Operation ID : $($operation.id)"
            Write-Host "App ID       : $($operation.appId)"
            Write-Host "Version      : $($operation.targetAppVersion)"
            Write-Host "Status       : $($operation.status)"
            Write-Host "Schedule     : $($operation.scheduleKind)"

        }
        catch {
            Write-Error "Installation failed for '$App': $($_.Exception.Message)"
        }
        finally {
            if ($fileContent) {
                $fileContent.Dispose()
            }

            if ($fileStream) {
                $fileStream.Dispose()
            }

            if ($multipartContent) {
                $multipartContent.Dispose()
            }

            if ($httpClient) {
                $httpClient.Dispose()
            }
        }

        $i++
    }
}


#Controle
Write-Host ""
Write-Host "Waiting for all installations to complete..."
Write-Host ""

$completedStates = @(
    "succeeded",
    "failed",
    "canceled",
    "skipped"
)

do {

    $response = Invoke-WebRequest `
        -Method Get `
        -Uri "https://api.businesscentral.dynamics.com/admin/$apiVersion/applications/$applicationFamily/environments/$environment/operations" `
        -Headers @{
            Authorization = "Bearer $accessToken"
        }

    $allOperations = ($response.Content | ConvertFrom-Json).value

    # Alleen de operations die door dit script zijn gestart
    $myOperations = $allOperations | Where-Object {
        $_.id -in $OperationIds
    }

    $runningOperations = $myOperations | Where-Object {
        $_.status -notin $completedStates
    }

    $completedCount = ($myOperations | Where-Object {
        $_.status -in $completedStates
    }).Count

    Write-Host ("Completed {0}/{1} installations" -f `
        $completedCount,
        $OperationIds.Count)

    foreach ($op in $runningOperations) {
        Write-Host ("  [{0}] {1}" -f `
            $op.status,
            $op.id)
    }

    if ($runningOperations.Count -gt 0) {
        Start-Sleep -Seconds 15
    }

}
until ($runningOperations.Count -eq 0)

Write-Host ""
Write-Host "All operations finished."
Write-Host ""

#Check for errors
$failedOperations = $myOperations | Where-Object {
    $_.status -eq "failed"
}

if ($failedOperations.Count -gt 0) {

    Write-Host ""
    Write-Host "FAILED OPERATIONS" -ForegroundColor Red

    foreach ($operation in $failedOperations) {

        Write-Host ""
        Write-Host "Operation : $($operation.id)"
        Write-Host "Status    : $($operation.status)"
        Write-Host "Error     : $($operation.errorMessage)"
    }

    throw "One or more app installations failed."
}
else {
    Write-Host "All apps installed successfully." -ForegroundColor Green
}