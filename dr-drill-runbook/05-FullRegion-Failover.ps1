#Requires -Version 7.0
<#
.SYNOPSIS
    Full Region Failover Drill

.DESCRIPTION
    Simulates complete primary region (EUS2) failure by:
    1. Disabling primary App Service origin in Front Door
    2. Failing over SQL MI to secondary
    3. Promoting secondary Redis (optional, if geo-replicated)
    
    This is the most comprehensive DR drill and demonstrates
    full regional resiliency.

.PARAMETER Failover
    Execute full region failover to CUS

.PARAMETER Force
    Skip all confirmation prompts (use with caution!)

.EXAMPLE
    .\05-FullRegion-Failover.ps1 -Failover
    .\05-FullRegion-Failover.ps1 -Failover -Force
#>

param(
    [switch]$Failover,
    [switch]$Force
)

# Load environment
if (-not $Global:DrDrill) {
    . "$PSScriptRoot\00-Setup-Environment.ps1"
}

if (-not $Failover) {
    Write-Host "Usage: .\05-FullRegion-Failover.ps1 -Failover [-Force]" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This script simulates complete EUS2 region failure." -ForegroundColor Yellow
    Write-Host "Use 06-Failback-All.ps1 to restore primary region." -ForegroundColor Yellow
    return
}

$width = 66

Write-Host ""
Write-Host ("╔" + "═" * $width + "╗") -ForegroundColor DarkRed
Write-Host "║               FULL REGION FAILOVER DRILL                          ║" -ForegroundColor DarkRed
Write-Host "║                    ⚠️  MAJOR DR EVENT ⚠️                            ║" -ForegroundColor DarkRed
Write-Host ("╠" + "═" * $width + "╣") -ForegroundColor DarkRed
Write-Host ("║ Scenario: Primary Region (EUS2) Complete Failure").PadRight($width + 1) + "║" -ForegroundColor DarkRed
Write-Host ("║ Start: " + (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")).PadRight($width + 1) + "║" -ForegroundColor DarkRed
Write-Host ("╠" + "═" * $width + "╣") -ForegroundColor DarkRed

# ============================================
# Confirmation
# ============================================

if (-not $Force) {
    Write-Host "║ This will execute the following actions:".PadRight($width + 1) + "║" -ForegroundColor Yellow
    Write-Host "║   1. Disable EUS2 App Service in Front Door".PadRight($width + 1) + "║"
    Write-Host "║   2. Failover SQL MI Failover Group to CUS".PadRight($width + 1) + "║"
    Write-Host "║   3. Break Redis geo-replication (if configured)".PadRight($width + 1) + "║"
    Write-Host ("║" + " " * $width + "║")
    Write-Host "║ ⚠️  THIS SIMULATES A MAJOR DISASTER!".PadRight($width + 1) + "║" -ForegroundColor Red
    Write-Host ("║" + " " * $width + "║")
    $confirm = Read-Host "║ Type 'DISASTER' to confirm"
    if ($confirm -ne "DISASTER") {
        Write-Host "║ Cancelled by user".PadRight($width + 1) + "║"
        Write-Host ("╚" + "═" * $width + "╝") -ForegroundColor DarkRed
        return
    }
}

$drillStart = Get-Date
$results = @{
    AppService = @{ Success = $false; RTO = 0 }
    SqlMi = @{ Success = $false; RTO = 0 }
    Redis = @{ Success = $false; RTO = 0; Skipped = $false }
}

# ============================================
# Phase 1: Front Door - Disable Primary Origin
# ============================================

Write-Host ("║" + " " * $width + "║")
Write-Host "║ ═══════════════════════════════════════════════════════════════   ║" -ForegroundColor Yellow
Write-Host "║ PHASE 1: FRONT DOOR - Disable Primary App Service Origin          ║" -ForegroundColor Yellow
Write-Host "║ ═══════════════════════════════════════════════════════════════   ║" -ForegroundColor Yellow

$phase1Start = Get-Date

try {
    Write-Host "║   Disabling primary origin...".PadRight($width + 1) + "║"
    
    az afd origin update `
        --profile-name $Global:DrDrill.FrontDoor.Name `
        --resource-group $Global:DrDrill.FrontDoor.ResourceGroup `
        --origin-group-name $Global:DrDrill.FrontDoor.OriginGroup `
        --origin-name "primary-appservice" `
        --enabled-state Disabled `
        --output none
    
    $results.AppService.RTO = ((Get-Date) - $phase1Start).TotalSeconds
    $results.AppService.Success = $true
    Write-Host "║   Primary origin disabled in $($results.AppService.RTO.ToString('F1'))s".PadRight(59) + "✅   ║" -ForegroundColor Green
} catch {
    Write-Host "║   ERROR: $($_.Exception.Message)".PadRight(59) + "❌   ║" -ForegroundColor Red
}

# ============================================
# Phase 2: SQL MI Failover Group
# ============================================

Write-Host ("║" + " " * $width + "║")
Write-Host "║ ═══════════════════════════════════════════════════════════════   ║" -ForegroundColor Yellow
Write-Host "║ PHASE 2: SQL MI - Failover to Secondary Region (CUS)              ║" -ForegroundColor Yellow
Write-Host "║ ═══════════════════════════════════════════════════════════════   ║" -ForegroundColor Yellow

$phase2Start = Get-Date

try {
    # Check if FOG exists
    $fogExists = az sql instance-failover-group show `
        --name $Global:DrDrill.FailoverGroup.Name `
        --resource-group $Global:DrDrill.Primary.ResourceGroup `
        --location $Global:DrDrill.Primary.Region `
        --query "name" -o tsv 2>$null
    
    if ($fogExists) {
        Write-Host "║   Initiating SQL MI failover (2-5 minutes)...".PadRight($width + 1) + "║"
        
        az sql instance-failover-group set-primary `
            --name $Global:DrDrill.FailoverGroup.Name `
            --resource-group $Global:DrDrill.Secondary.ResourceGroup `
            --location $Global:DrDrill.Secondary.Region `
            --output none
        
        $results.SqlMi.RTO = ((Get-Date) - $phase2Start).TotalSeconds
        $results.SqlMi.Success = $true
        Write-Host "║   SQL MI failover complete in $($results.SqlMi.RTO.ToString('F0'))s".PadRight(59) + "✅   ║" -ForegroundColor Green
        
        # Verify
        $newRole = az sql instance-failover-group show `
            --name $Global:DrDrill.FailoverGroup.Name `
            --resource-group $Global:DrDrill.Secondary.ResourceGroup `
            --location $Global:DrDrill.Secondary.Region `
            --query "replicationRole" -o tsv 2>$null
        
        Write-Host "║   CUS SQL MI is now: $newRole".PadRight($width + 1) + "║"
    } else {
        Write-Host "║   Failover Group not found - SKIPPED".PadRight(59) + "⚠️   ║" -ForegroundColor Yellow
        $results.SqlMi.Skipped = $true
    }
} catch {
    Write-Host "║   ERROR: $($_.Exception.Message)".PadRight(59) + "❌   ║" -ForegroundColor Red
}

# ============================================
# Phase 3: Redis Geo-Replication (if exists)
# ============================================

Write-Host ("║" + " " * $width + "║")
Write-Host "║ ═══════════════════════════════════════════════════════════════   ║" -ForegroundColor Yellow
Write-Host "║ PHASE 3: REDIS - Break Geo-Replication (if configured)            ║" -ForegroundColor Yellow
Write-Host "║ ═══════════════════════════════════════════════════════════════   ║" -ForegroundColor Yellow

$phase3Start = Get-Date

try {
    # Check for geo-replication links
    $geoLinks = az redis server-link list `
        --name $Global:DrDrill.Primary.Redis `
        --resource-group $Global:DrDrill.Primary.ResourceGroup 2>$null | ConvertFrom-Json
    
    if ($geoLinks -and $geoLinks.Count -gt 0) {
        Write-Host "║   Breaking geo-replication link...".PadRight($width + 1) + "║"
        
        az redis server-link delete `
            --name $Global:DrDrill.Primary.Redis `
            --resource-group $Global:DrDrill.Primary.ResourceGroup `
            --linked-server-name $Global:DrDrill.Secondary.Redis `
            --output none 2>$null
        
        $results.Redis.RTO = ((Get-Date) - $phase3Start).TotalSeconds
        $results.Redis.Success = $true
        Write-Host "║   Geo-replication broken in $($results.Redis.RTO.ToString('F1'))s".PadRight(59) + "✅   ║" -ForegroundColor Green
        Write-Host "║   CUS Redis is now independent".PadRight($width + 1) + "║"
    } else {
        Write-Host "║   No geo-replication configured - Using standalone caches".PadRight(59) + "⚠️   ║" -ForegroundColor Yellow
        $results.Redis.Skipped = $true
    }
} catch {
    Write-Host "║   Redis check/failover skipped".PadRight(59) + "⚠️   ║" -ForegroundColor Yellow
    $results.Redis.Skipped = $true
}

# ============================================
# Wait for Front Door Propagation
# ============================================

Write-Host ("║" + " " * $width + "║")
Write-Host "║ ═══════════════════════════════════════════════════════════════   ║" -ForegroundColor Yellow
Write-Host "║ PHASE 4: Waiting for Front Door Propagation (30s)                 ║" -ForegroundColor Yellow
Write-Host "║ ═══════════════════════════════════════════════════════════════   ║" -ForegroundColor Yellow

for ($i = 30; $i -gt 0; $i -= 5) {
    Write-Host "║   Propagating changes... ${i}s remaining".PadRight($width + 1) + "║"
    Start-Sleep -Seconds 5
}

# ============================================
# Final Verification
# ============================================

Write-Host ("║" + " " * $width + "║")
Write-Host "║ ═══════════════════════════════════════════════════════════════   ║" -ForegroundColor Cyan
Write-Host "║ VERIFICATION                                                      ║" -ForegroundColor Cyan
Write-Host "║ ═══════════════════════════════════════════════════════════════   ║" -ForegroundColor Cyan

# Test Front Door endpoint
$endpoint = "https://$($Global:DrDrill.FrontDoor.Endpoint)"
Write-Host "║   Testing endpoint: $endpoint".PadRight($width + 1) + "║"

try {
    $response = Invoke-WebRequest -Uri $endpoint -UseBasicParsing -TimeoutSec 15
    Write-Host "║   Endpoint responding: HTTP $($response.StatusCode)".PadRight(59) + "✅   ║" -ForegroundColor Green
} catch {
    Write-Host "║   Endpoint error (may need more time)".PadRight(59) + "⚠️   ║" -ForegroundColor Yellow
}

$totalDrillTime = (Get-Date) - $drillStart

# ============================================
# Summary
# ============================================

Write-Host ("╠" + "═" * $width + "╣") -ForegroundColor DarkRed
Write-Host "║                    FULL REGION FAILOVER COMPLETE                  ║" -ForegroundColor Green
Write-Host ("╠" + "═" * $width + "╣") -ForegroundColor DarkRed
Write-Host "║ TIMING SUMMARY:".PadRight($width + 1) + "║" -ForegroundColor Cyan
Write-Host "║   Front Door Origin Disable: $($results.AppService.RTO.ToString('F1'))s".PadRight($width + 1) + "║"
if (-not $results.SqlMi.Skipped) {
    Write-Host "║   SQL MI Failover:           $($results.SqlMi.RTO.ToString('F0'))s".PadRight($width + 1) + "║"
} else {
    Write-Host "║   SQL MI Failover:           Skipped (FOG not configured)".PadRight($width + 1) + "║"
}
if (-not $results.Redis.Skipped) {
    Write-Host "║   Redis Geo-Rep Break:       $($results.Redis.RTO.ToString('F1'))s".PadRight($width + 1) + "║"
} else {
    Write-Host "║   Redis:                     Skipped (no geo-rep)".PadRight($width + 1) + "║"
}
Write-Host "║   Front Door Propagation:    ~30s".PadRight($width + 1) + "║"
Write-Host ("║" + "-" * $width + "║")
Write-Host "║   TOTAL RTO:                 $($totalDrillTime.TotalSeconds.ToString('F0'))s ($($totalDrillTime.TotalMinutes.ToString('F1')) minutes)".PadRight($width + 1) + "║" -ForegroundColor Green
Write-Host ("║" + " " * $width + "║")
Write-Host "║ CURRENT STATE:".PadRight($width + 1) + "║" -ForegroundColor Cyan
Write-Host "║   • Traffic routing to: CUS (Secondary Region)".PadRight($width + 1) + "║"
Write-Host "║   • SQL MI Primary: CUS".PadRight($width + 1) + "║"
Write-Host "║   • Application: Using CUS resources".PadRight($width + 1) + "║"
Write-Host ("╚" + "═" * $width + "╝") -ForegroundColor DarkRed

Write-Host ""
Write-Host "══════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host " Next Steps:" -ForegroundColor Yellow
Write-Host "══════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host " 1. Verify application functionality via Front Door endpoint"
Write-Host " 2. Test database connectivity via Failover Group listener"
Write-Host " 3. Monitor application logs for any errors"
Write-Host " 4. When ready, run: .\06-Failback-All.ps1 -Failback"
Write-Host "══════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host ""

# Return results object for scripting
return @{
    TotalRTO = $totalDrillTime.TotalSeconds
    Components = $results
    Timestamp = Get-Date
}
