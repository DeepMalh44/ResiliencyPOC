#Requires -Version 7.0
<#
.SYNOPSIS
    Setup environment variables for DR Drill Runbook

.DESCRIPTION
    Configures all resource names and settings for the DR drill scripts.
    Run this first before any other scripts.
#>

# ============================================
# CONFIGURATION - Update these values
# ============================================

$Global:DrDrill = @{
    # Subscription
    SubscriptionId = "b8383a80-7a39-472f-89b8-4f0b6a53b266"
    
    # Primary Region (East US 2)
    Primary = @{
        Region           = "eastus2"
        ResourceGroup    = "rg-pocapp6-prod-eus2"
        AppService       = "app-pocapp6-prod-eus2"
        FunctionApp      = "func-pocapp6-prod-eus2"
        SqlMi            = "sqlmi-pocapp6-prod-eus2"
        Redis            = "redis-pocapp6-prod-eus2"
        Storage          = "stpocapp6prodeus2"
    }
    
    # Secondary Region (Central US)
    Secondary = @{
        Region           = "centralus"
        ResourceGroup    = "rg-pocapp6-prod-cus"
        AppService       = "app-pocapp6-prod-cus"
        FunctionApp      = "func-pocapp6-prod-cus"
        SqlMi            = "sqlmi-pocapp6-prod-cus"
        Redis            = "redis-pocapp6-prod-cus"
        Storage          = "stpocapp6prodcus"
    }
    
    # Failover Group
    FailoverGroup = @{
        Name             = "fog-pocapp6-prod"
    }
    
    # Front Door
    FrontDoor = @{
        Name             = "fd-pocapp6-prod"
        ResourceGroup    = "rg-pocapp6-prod-eus2"
        Endpoint         = "fd-pocapp6-prod.azurefd.net"
        OriginGroup      = "default-origin-group"
    }
    
    # Timing
    HealthProbeInterval = 30  # seconds
    MaxWaitTime         = 300 # seconds (5 min max wait)
}

# ============================================
# HELPER FUNCTIONS
# ============================================

function Write-DrillHeader {
    param([string]$Title)
    
    $width = 62
    Write-Host ""
    Write-Host ("╔" + "═" * $width + "╗") -ForegroundColor Cyan
    Write-Host ("║" + $Title.PadLeft(($width + $Title.Length) / 2).PadRight($width) + "║") -ForegroundColor Cyan
    Write-Host ("╠" + "═" * $width + "╣") -ForegroundColor Cyan
}

function Write-DrillFooter {
    param(
        [datetime]$StartTime,
        [datetime]$EndTime,
        [string]$Status,
        [int]$TargetRtoMinutes = 60
    )
    
    $duration = $EndTime - $StartTime
    $width = 62
    
    Write-Host ("╠" + "═" * $width + "╣") -ForegroundColor Cyan
    Write-Host ("║ End Time: " + $EndTime.ToString("yyyy-MM-dd HH:mm:ss")).PadRight($width + 1) + "║" -ForegroundColor Cyan
    Write-Host ("║ ACTUAL RTO: " + $duration.ToString("mm' minutes 'ss' seconds'")).PadRight($width + 1) + "║" -ForegroundColor Yellow
    Write-Host ("║ TARGET RTO: $TargetRtoMinutes minutes").PadRight($width + 1) + "║" -ForegroundColor Cyan
    
    $statusColor = if ($Status -eq "PASSED") { "Green" } else { "Red" }
    Write-Host ("║ STATUS: $Status").PadRight($width + 1) + "║" -ForegroundColor $statusColor
    Write-Host ("╚" + "═" * $width + "╝") -ForegroundColor Cyan
    Write-Host ""
}

function Write-DrillStep {
    param(
        [int]$Step,
        [int]$TotalSteps,
        [string]$Message,
        [string]$Status = "Running"
    )
    
    $statusIcon = switch ($Status) {
        "Running" { "⏳" }
        "OK"      { "✅" }
        "Done"    { "✅" }
        "Failed"  { "❌" }
        "Warning" { "⚠️" }
        default   { "  " }
    }
    
    $statusColor = switch ($Status) {
        "OK"      { "Green" }
        "Done"    { "Green" }
        "Failed"  { "Red" }
        "Warning" { "Yellow" }
        default   { "White" }
    }
    
    $line = "║ [$Step/$TotalSteps] $Message".PadRight(55) + "$statusIcon".PadLeft(4) + " ║"
    Write-Host $line -ForegroundColor $statusColor
}

function Test-ServiceHealth {
    param(
        [string]$Url,
        [int]$TimeoutSeconds = 10
    )
    
    try {
        $response = Invoke-WebRequest -Uri $Url -TimeoutSec $TimeoutSeconds -UseBasicParsing -ErrorAction Stop
        return $response.StatusCode -eq 200
    }
    catch {
        return $false
    }
}

function Get-CurrentActiveRegion {
    # Determine which region is currently serving traffic
    # This checks the Front Door backend health
    
    try {
        $fdHealth = az afd origin-group show `
            --resource-group $Global:DrDrill.FrontDoor.ResourceGroup `
            --profile-name $Global:DrDrill.FrontDoor.Name `
            --origin-group-name "default-origin-group" `
            --query "origins[?healthState=='Healthy'].name" -o tsv 2>$null
        
        if ($fdHealth -match "eus2") { return "Primary (EUS2)" }
        if ($fdHealth -match "cus") { return "Secondary (CUS)" }
        return "Unknown"
    }
    catch {
        return "Unable to determine"
    }
}

# ============================================
# CONFIRMATION
# ============================================

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║          DR DRILL ENVIRONMENT CONFIGURED                     ║" -ForegroundColor Green
Write-Host "╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Green
Write-Host "║ Primary Region:   $($Global:DrDrill.Primary.Region)".PadRight(63) + "║" -ForegroundColor Green
Write-Host "║ Secondary Region: $($Global:DrDrill.Secondary.Region)".PadRight(63) + "║" -ForegroundColor Green
Write-Host "║ Subscription:     $($Global:DrDrill.SubscriptionId.Substring(0,8))...".PadRight(63) + "║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "Run .\01-Check-Health.ps1 to verify all resources are healthy." -ForegroundColor Yellow
Write-Host ""
