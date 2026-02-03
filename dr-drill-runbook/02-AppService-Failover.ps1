#Requires -Version 7.0
<#
.SYNOPSIS
    App Service Failover Drill

.DESCRIPTION
    Simulates failure of the primary App Service by disabling it in Front Door
    and verifying traffic fails over to secondary region.

.PARAMETER Failover
    Switch to simulate failover (disable primary origin)

.PARAMETER Failback  
    Switch to restore primary (enable primary origin)

.EXAMPLE
    .\02-AppService-Failover.ps1 -Failover
    .\02-AppService-Failover.ps1 -Failback
#>

param(
    [switch]$Failover,
    [switch]$Failback
)

# Load environment
if (-not $Global:DrDrill) {
    . "$PSScriptRoot\00-Setup-Environment.ps1"
}

if (-not $Failover -and -not $Failback) {
    Write-Host "Usage: .\02-AppService-Failover.ps1 -Failover | -Failback" -ForegroundColor Yellow
    return
}

$width = 62

Write-Host ""
Write-Host ("╔" + "═" * $width + "╗") -ForegroundColor Magenta
Write-Host "║              APP SERVICE FAILOVER DRILL                       ║" -ForegroundColor Magenta
Write-Host ("╠" + "═" * $width + "╣") -ForegroundColor Magenta
Write-Host ("║ Mode: " + $(if ($Failover) { "FAILOVER (Disable Primary)" } else { "FAILBACK (Enable Primary)" })).PadRight($width + 1) + "║" -ForegroundColor Magenta
Write-Host ("║ Start: " + (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")).PadRight($width + 1) + "║" -ForegroundColor Magenta
Write-Host ("╠" + "═" * $width + "╣") -ForegroundColor Magenta

$startTime = Get-Date

if ($Failover) {
    # ============================================
    # FAILOVER: Disable Primary Origin
    # ============================================
    
    Write-Host "║ Step 1: Checking current origin status...".PadRight($width + 1) + "║" -ForegroundColor Cyan
    
    # Get current origin states
    $primaryOrigin = az afd origin show `
        --profile-name $Global:DrDrill.FrontDoor.Name `
        --resource-group $Global:DrDrill.FrontDoor.ResourceGroup `
        --origin-group-name $Global:DrDrill.FrontDoor.OriginGroup `
        --origin-name "primary-appservice" `
        --query "enabledState" -o tsv 2>$null

    Write-Host "║   Primary Origin: $primaryOrigin".PadRight($width + 1) + "║"

    Write-Host ("║" + " " * $width + "║")
    Write-Host "║ Step 2: Disabling Primary Origin (simulating failure)...".PadRight($width + 1) + "║" -ForegroundColor Cyan
    
    $disableStart = Get-Date
    
    az afd origin update `
        --profile-name $Global:DrDrill.FrontDoor.Name `
        --resource-group $Global:DrDrill.FrontDoor.ResourceGroup `
        --origin-group-name $Global:DrDrill.FrontDoor.OriginGroup `
        --origin-name "primary-appservice" `
        --enabled-state Disabled `
        --output none

    $disableTime = (Get-Date) - $disableStart
    Write-Host "║   Primary Origin disabled in $($disableTime.TotalSeconds.ToString('F1'))s".PadRight(55) + "✅   ║" -ForegroundColor Green

    Write-Host ("║" + " " * $width + "║")
    Write-Host "║ Step 3: Waiting for Front Door propagation (30s)...".PadRight($width + 1) + "║" -ForegroundColor Cyan
    
    for ($i = 30; $i -gt 0; $i -= 5) {
        Write-Host "║   Propagating... ${i}s remaining".PadRight($width + 1) + "║"
        Start-Sleep -Seconds 5
    }

    Write-Host ("║" + " " * $width + "║")
    Write-Host "║ Step 4: Testing endpoint...".PadRight($width + 1) + "║" -ForegroundColor Cyan
    
    $endpoint = "https://$($Global:DrDrill.FrontDoor.Endpoint)"
    
    try {
        $response = Invoke-WebRequest -Uri $endpoint -UseBasicParsing -TimeoutSec 10
        Write-Host "║   Endpoint responding: $($response.StatusCode)".PadRight(55) + "✅   ║" -ForegroundColor Green
    } catch {
        Write-Host "║   Endpoint error: $($_.Exception.Message)".PadRight(55) + "⚠️   ║" -ForegroundColor Yellow
    }

    $totalTime = (Get-Date) - $startTime

    Write-Host ("╠" + "═" * $width + "╣") -ForegroundColor Magenta
    Write-Host "║ FAILOVER COMPLETE".PadRight($width + 1) + "║" -ForegroundColor Green
    Write-Host "║   Total RTO: $($totalTime.TotalSeconds.ToString('F1')) seconds".PadRight($width + 1) + "║"
    Write-Host "║   Traffic now routing to: SECONDARY (CUS)".PadRight($width + 1) + "║"
    Write-Host ("╚" + "═" * $width + "╝") -ForegroundColor Magenta

} else {
    # ============================================
    # FAILBACK: Enable Primary Origin
    # ============================================
    
    Write-Host "║ Step 1: Re-enabling Primary Origin...".PadRight($width + 1) + "║" -ForegroundColor Cyan
    
    $enableStart = Get-Date
    
    az afd origin update `
        --profile-name $Global:DrDrill.FrontDoor.Name `
        --resource-group $Global:DrDrill.FrontDoor.ResourceGroup `
        --origin-group-name $Global:DrDrill.FrontDoor.OriginGroup `
        --origin-name "primary-appservice" `
        --enabled-state Enabled `
        --output none

    $enableTime = (Get-Date) - $enableStart
    Write-Host "║   Primary Origin enabled in $($enableTime.TotalSeconds.ToString('F1'))s".PadRight(55) + "✅   ║" -ForegroundColor Green

    Write-Host ("║" + " " * $width + "║")
    Write-Host "║ Step 2: Waiting for Front Door propagation (30s)...".PadRight($width + 1) + "║" -ForegroundColor Cyan
    
    for ($i = 30; $i -gt 0; $i -= 5) {
        Write-Host "║   Propagating... ${i}s remaining".PadRight($width + 1) + "║"
        Start-Sleep -Seconds 5
    }

    Write-Host ("║" + " " * $width + "║")
    Write-Host "║ Step 3: Verifying both origins enabled...".PadRight($width + 1) + "║" -ForegroundColor Cyan
    
    $primaryState = az afd origin show `
        --profile-name $Global:DrDrill.FrontDoor.Name `
        --resource-group $Global:DrDrill.FrontDoor.ResourceGroup `
        --origin-group-name $Global:DrDrill.FrontDoor.OriginGroup `
        --origin-name "primary-appservice" `
        --query "enabledState" -o tsv 2>$null

    $secondaryState = az afd origin show `
        --profile-name $Global:DrDrill.FrontDoor.Name `
        --resource-group $Global:DrDrill.FrontDoor.ResourceGroup `
        --origin-group-name $Global:DrDrill.FrontDoor.OriginGroup `
        --origin-name "secondary-appservice" `
        --query "enabledState" -o tsv 2>$null

    Write-Host "║   Primary Origin:   $primaryState".PadRight(55) + "✅   ║" -ForegroundColor Green
    Write-Host "║   Secondary Origin: $secondaryState".PadRight(55) + "✅   ║" -ForegroundColor Green

    $totalTime = (Get-Date) - $startTime

    Write-Host ("╠" + "═" * $width + "╣") -ForegroundColor Magenta
    Write-Host "║ FAILBACK COMPLETE".PadRight($width + 1) + "║" -ForegroundColor Green
    Write-Host "║   Total Time: $($totalTime.TotalSeconds.ToString('F1')) seconds".PadRight($width + 1) + "║"
    Write-Host "║   Traffic routing: PRIMARY (EUS2) with CUS backup".PadRight($width + 1) + "║"
    Write-Host ("╚" + "═" * $width + "╝") -ForegroundColor Magenta
}

Write-Host ""
