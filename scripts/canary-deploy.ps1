param(
    [string]$ApiId = "yuz7ckt2s0",
    [string]$RouteId = "96ks841",
    [string]$BlueIntegrationId = "qs7qa91",
    [string]$GreenIntegrationId = "yryzrfq",
    [string]$ApiEndpoint = "https://yuz7ckt2s0.execute-api.us-east-1.amazonaws.com/prod/api",
    [string]$Region = "us-east-1",
    [int]$ErrorThresholdPct = 20
)

function Test-Endpoint {
    param([string]$Url, [int]$Requests = 10)
    $errors = 0
    for ($i = 0; $i -lt $Requests; $i++) {
        try {
            $r = Invoke-RestMethod -Uri $Url -ErrorAction Stop
            Write-Host "  [$i] OK - environment: $($r.environment)" -ForegroundColor Green
        } catch {
            $errors++
            Write-Host "  [$i] ERROR: $_" -ForegroundColor Red
        }
    }
    return [math]::Round(($errors / $Requests) * 100)
}

function Set-RouteIntegration {
    param([string]$IntegrationId)
    $result = aws apigatewayv2 update-route `
        --region $Region `
        --api-id $ApiId `
        --route-id $RouteId `
        --target "integrations/$IntegrationId" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  FAILED to update route: $result" -ForegroundColor Red
        exit 1
    }
    Write-Host "Route updated to integration: $IntegrationId" -ForegroundColor Cyan
}

function Invoke-Rollback {
    Write-Host "`n!! ERROR THRESHOLD EXCEEDED - ROLLING BACK TO BLUE !!" -ForegroundColor Red
    Set-RouteIntegration -IntegrationId $BlueIntegrationId
    Write-Host "Rollback complete. Blue is live." -ForegroundColor Yellow
    exit 1
}

Write-Host "`n=== CANARY DEPLOYMENT: Blue -> Green ===" -ForegroundColor Cyan
Write-Host "API: $ApiEndpoint`n"

Write-Host ">> Stage 0: Baseline check on BLUE (0% green)" -ForegroundColor White
$errPct = Test-Endpoint -Url $ApiEndpoint -Requests 5
Write-Host "Blue error rate: $errPct%"
if ($errPct -gt $ErrorThresholdPct) { Invoke-Rollback }

Write-Host "`n>> Stage 1: Shifting to GREEN (canary sample)" -ForegroundColor White
Set-RouteIntegration -IntegrationId $GreenIntegrationId
Start-Sleep -Seconds 3
$errPct = Test-Endpoint -Url $ApiEndpoint -Requests 3
Write-Host "Green canary error rate: $errPct%"
if ($errPct -gt $ErrorThresholdPct) { Invoke-Rollback }

Write-Host "`n>> Stage 2: Full traffic on GREEN" -ForegroundColor White
$errPct = Test-Endpoint -Url $ApiEndpoint -Requests 10
Write-Host "Green full-traffic error rate: $errPct%"
if ($errPct -gt $ErrorThresholdPct) { Invoke-Rollback }

Write-Host "`n=== DEPLOYMENT COMPLETE - GREEN is live ===" -ForegroundColor Green
Write-Host "Blue integration ($BlueIntegrationId) retained for instant rollback."
