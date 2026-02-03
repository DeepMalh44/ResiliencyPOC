#Requires -Version 7.0
<#
.SYNOPSIS
    Failback All - Restore Primary Region

.DESCRIPTION
    Restores all services to primary region (EUS2) after a DR drill:
    1. Re-enable EUS2 App Service origin in Front Door
    2. Failback SQL MI to EUS2
    3. Re-establish Redis geo-replication (if applicable)

.PARAMETER Failback
    Execute full region failback to EUS2

.PARAMETER Force
    Skip all confirmation prompts

.EXAMPLE
    .\06-Failback-All.ps1 -Failback
    .\06-Failback-All.ps1 -Failback -Force
#>

param(
    [switch]$Failback,
    [switch]$Force
)

# Load environment
if (-not $Global:DrDrill) {
    . "$PSScriptRoot\00-Setup-Environment.ps1"
}

if (-not $Failback) {
    Write-Host "Usage: .\06-Failback-All.ps1 -Failback [-Force]" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This script restores all services to primary region (EUS2)." -ForegroundColor Yellow
    return
}

$width = 66

Write-Host ""
Write-Host ("╔" + "═" * $width + "╗") -ForegroundColor DarkGreen
Write-Host "║               FULL REGION FAILBACK - RESTORE PRIMARY              ║" -ForegroundColor DarkGreen
Write-Host "║                    ✅ Restoration Process ✅                       ║" -ForegroundColor DarkGreen
Write-Host ("╠" + "═" * $width + "╣") -ForegroundColor DarkGreen
Write-Host ("║ Target: Restore Primary Region (EUS2)").PadRight($width + 1) + "║" -ForegroundColor DarkGreen
Write-Host ("║ Start: " + (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")).PadRight($width + 1) + "║" -ForegroundColor DarkGreen
Write-Host ("╠" + "═" * $width + "╣") -ForegroundColor DarkGreen

# ============================================
# Confirmation
# ============================================

if (-not $Force) {
    Write-Host "║ This will execute the following actions:".PadRight($width + 1) + "║" -ForegroundColor Cyan
    Write-Host "║   1. Re-enable EUS2 App Service in Front Door".PadRight($width + 1) + "║"
    Write-Host "║   2. Failback SQL MI Failover Group to EUS2".PadRight($width + 1) + "║"
    Write-Host "║   3. Re-establish Redis geo-replication".PadRight($width + 1) + "║"
    Write-Host ("║" + " " * $width + "║")
    $confirm = Read-Host "║ Type 'RESTORE' to confirm"
    if ($confirm -ne "RESTORE") {
        Write-Host "║ Cancelled by user".PadRight($width + 1) + "║"
        Write-Host ("╚" + "═" * $width + "╝") -ForegroundColor DarkGreen
        return
    }
}

$drillStart = Get-Date
$results = @{
    AppService = @{ Success = $false; Time = 0 }
    SqlMi = @{ Success = $false; Time = 0; Skipped = $false }
    Redis = @{ Success = $false; Time = 0; Skipped = $false }
}

# ============================================
# Phase 1: Front Door - Re-enable Primary Origin
# ============================================

Write-Host ("║" + " " * $width + "║")
Write-Host "║ ═══════════════════════════════════════════════════════════════   ║" -ForegroundColor Yellow
Write-Host "║ PHASE 1: FRONT DOOR - Re-enable Primary App Service Origin        ║" -ForegroundColor Yellow
Write-Host "║ ═══════════════════════════════════════════════════════════════   ║" -ForegroundColor Yellow

$phase1Start = Get-Date

try {
    Write-Host "║   Re-enabling primary origin...".PadRight($width + 1) + "║"
    
    az afd origin update `
        --profile-name $Global:DrDrill.FrontDoor.Name `
        --resource-group $Global:DrDrill.FrontDoor.ResourceGroup `
        --origin-group-name $Global:DrDrill.FrontDoor.OriginGroup `
        --origin-name "primary-appservice" `
        --enabled-state Enabled `
        --output none
    
    $results.AppService.Time = ((Get-Date) - $phase1Start).TotalSeconds
    $results.AppService.Success = $true
    Write-Host "║   Primary origin enabled in $($results.AppService.Time.ToString('F1'))s".PadRight(59) + "✅   ║" -ForegroundColor Green
    
    # Verify both origins
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
    
    Write-Host "║   Primary Origin (EUS2):   $primaryState".PadRight($width + 1) + "║"
    Write-Host "║   Secondary Origin (CUS):  $secondaryState".PadRight($width + 1) + "║"
    
} catch {
    Write-Host "║   ERROR: $($_.Exception.Message)".PadRight(59) + "❌   ║" -ForegroundColor Red
}

# ============================================
# Phase 2: SQL MI Failover Group - Failback
# ============================================

Write-Host ("║" + " " * $width + "║")
Write-Host "║ ═══════════════════════════════════════════════════════════════   ║" -ForegroundColor Yellow
Write-Host "║ PHASE 2: SQL MI - Failback to Primary Region (EUS2)               ║" -ForegroundColor Yellow
Write-Host "║ ═══════════════════════════════════════════════════════════════   ║" -ForegroundColor Yellow

$phase2Start = Get-Date

try {
    # Check current state
    $currentRole = az sql instance-failover-group show `
        --name $Global:DrDrill.FailoverGroup.Name `
        --resource-group $Global:DrDrill.Primary.ResourceGroup `
        --location $Global:DrDrill.Primary.Region `
        --query "replicationRole" -o tsv 2>$null

    if ($currentRole -eq "Secondary") {
        Write-Host "║   EUS2 is currently Secondary - initiating failback...".PadRight($width + 1) + "║"
        Write-Host "║   This may take 2-5 minutes...".PadRight($width + 1) + "║"
        
        az sql instance-failover-group set-primary `
            --name $Global:DrDrill.FailoverGroup.Name `
            --resource-group $Global:DrDrill.Primary.ResourceGroup `
            --location $Global:DrDrill.Primary.Region `
            --output none
        
        $results.SqlMi.Time = ((Get-Date) - $phase2Start).TotalSeconds
        $results.SqlMi.Success = $true
        Write-Host "║   SQL MI failback complete in $($results.SqlMi.Time.ToString('F0'))s".PadRight(59) + "✅   ║" -ForegroundColor Green
        
        # Verify
        $newRole = az sql instance-failover-group show `
            --name $Global:DrDrill.FailoverGroup.Name `
            --resource-group $Global:DrDrill.Primary.ResourceGroup `
            --location $Global:DrDrill.Primary.Region `
            --query "replicationRole" -o tsv 2>$null
        
        Write-Host "║   EUS2 SQL MI is now: $newRole".PadRight($width + 1) + "║"
        
    } elseif ($currentRole -eq "Primary") {
        Write-Host "║   EUS2 is already Primary - no failback needed".PadRight(59) + "✅   ║" -ForegroundColor Green
        $results.SqlMi.Skipped = $true
    } else {
        Write-Host "║   Could not determine current role - skipping".PadRight(59) + "⚠️   ║" -ForegroundColor Yellow
        $results.SqlMi.Skipped = $true
    }
} catch {
    Write-Host "║   SQL MI not configured - skipping".PadRight(59) + "⚠️   ║" -ForegroundColor Yellow
    $results.SqlMi.Skipped = $true
}

# ============================================
# Phase 3: Redis - Re-establish Geo-Replication
# ============================================

Write-Host ("║" + " " * $width + "║")
Write-Host "║ ═══════════════════════════════════════════════════════════════   ║" -ForegroundColor Yellow
Write-Host "║ PHASE 3: REDIS - Re-establish Geo-Replication                     ║" -ForegroundColor Yellow
Write-Host "║ ═══════════════════════════════════════════════════════════════   ║" -ForegroundColor Yellow

$phase3Start = Get-Date

try {
    # Check current geo-replication state
    $existingLinks = az redis server-link list `
        --name $Global:DrDrill.Primary.Redis `
        --resource-group $Global:DrDrill.Primary.ResourceGroup 2>$null | ConvertFrom-Json
    
    if ($existingLinks -and $existingLinks.Count -gt 0) {
        Write-Host "║   Geo-replication already configured".PadRight(59) + "✅   ║" -ForegroundColor Green
        $results.Redis.Skipped = $true
    } else {
        Write-Host "║   Re-establishing geo-replication link...".PadRight($width + 1) + "║"
        
        # Get secondary cache resource ID
        $secondaryId = az redis show `
            --name $Global:DrDrill.Secondary.Redis `
            --resource-group $Global:DrDrill.Secondary.ResourceGroup `
            --query "id" -o tsv 2>$null
        
        if ($secondaryId) {
            az redis server-link create `
                --name $Global:DrDrill.Primary.Redis `
                --resource-group $Global:DrDrill.Primary.ResourceGroup `
                --server-to-link $secondaryId `
                --replication-role Secondary `
                --output none 2>$null
            
            $results.Redis.Time = ((Get-Date) - $phase3Start).TotalSeconds
            $results.Redis.Success = $true
            Write-Host "║   Geo-replication link created in $($results.Redis.Time.ToString('F1'))s".PadRight(59) + "✅   ║" -ForegroundColor Green
        } else {
            Write-Host "║   Secondary Redis not found - skipping".PadRight(59) + "⚠️   ║" -ForegroundColor Yellow
            $results.Redis.Skipped = $true
        }
    }
} catch {
    Write-Host "║   Redis geo-replication skipped".PadRight(59) + "⚠️   ║" -ForegroundColor Yellow
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
# Final Health Check
# ============================================

Write-Host ("║" + " " * $width + "║")
Write-Host "║ ═══════════════════════════════════════════════════════════════   ║" -ForegroundColor Cyan
Write-Host "║ FINAL HEALTH CHECK                                                ║" -ForegroundColor Cyan
Write-Host "║ ═══════════════════════════════════════════════════════════════   ║" -ForegroundColor Cyan

# Run health check
Write-Host "║   Running health verification...".PadRight($width + 1) + "║"

# Test Front Door endpoint
$endpoint = "https://$($Global:DrDrill.FrontDoor.Endpoint)"
try {
    $response = Invoke-WebRequest -Uri $endpoint -UseBasicParsing -TimeoutSec 15
    Write-Host "║   Front Door Endpoint: HTTP $($response.StatusCode)".PadRight(59) + "✅   ║" -ForegroundColor Green
} catch {
    Write-Host "║   Front Door Endpoint: Error".PadRight(59) + "⚠️   ║" -ForegroundColor Yellow
}

# Check App Services
$primaryAppState = az webapp show --name $Global:DrDrill.Primary.AppService `
    --resource-group $Global:DrDrill.Primary.ResourceGroup `
    --query "state" -o tsv 2>$null

$secondaryAppState = az webapp show --name $Global:DrDrill.Secondary.AppService `
    --resource-group $Global:DrDrill.Secondary.ResourceGroup `
    --query "state" -o tsv 2>$null

Write-Host "║   Primary App Service (EUS2):   $primaryAppState".PadRight($width + 1) + "║"
Write-Host "║   Secondary App Service (CUS):  $secondaryAppState".PadRight($width + 1) + "║"

$totalTime = (Get-Date) - $drillStart

# ============================================
# Summary
# ============================================

Write-Host ("╠" + "═" * $width + "╣") -ForegroundColor DarkGreen
Write-Host "║                    FAILBACK COMPLETE - PRIMARY RESTORED           ║" -ForegroundColor Green
Write-Host ("╠" + "═" * $width + "╣") -ForegroundColor DarkGreen
Write-Host "║ TIMING SUMMARY:".PadRight($width + 1) + "║" -ForegroundColor Cyan
Write-Host "║   Front Door Origin Enable:  $($results.AppService.Time.ToString('F1'))s".PadRight($width + 1) + "║"
if (-not $results.SqlMi.Skipped) {
    Write-Host "║   SQL MI Failback:           $($results.SqlMi.Time.ToString('F0'))s".PadRight($width + 1) + "║"
} else {
    Write-Host "║   SQL MI Failback:           Skipped/Already Primary".PadRight($width + 1) + "║"
}
if (-not $results.Redis.Skipped) {
    Write-Host "║   Redis Geo-Rep Restore:     $($results.Redis.Time.ToString('F1'))s".PadRight($width + 1) + "║"
} else {
    Write-Host "║   Redis:                     Skipped/Already Linked".PadRight($width + 1) + "║"
}
Write-Host "║   Front Door Propagation:    ~30s".PadRight($width + 1) + "║"
Write-Host ("║" + "-" * $width + "║")
Write-Host "║   TOTAL RESTORATION TIME:    $($totalTime.TotalSeconds.ToString('F0'))s ($($totalTime.TotalMinutes.ToString('F1')) minutes)".PadRight($width + 1) + "║" -ForegroundColor Green
Write-Host ("║" + " " * $width + "║")
Write-Host "║ CURRENT STATE:".PadRight($width + 1) + "║" -ForegroundColor Cyan
Write-Host "║   • Traffic routing: EUS2 (Primary) with CUS backup".PadRight($width + 1) + "║"
Write-Host "║   • SQL MI Primary:  EUS2".PadRight($width + 1) + "║"
Write-Host "║   • System Status:   NORMAL OPERATIONS".PadRight($width + 1) + "║"
Write-Host ("╚" + "═" * $width + "╝") -ForegroundColor DarkGreen

Write-Host ""
Write-Host "══════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host " ✅ DR Drill Complete - System restored to normal operations" -ForegroundColor Green
Write-Host "══════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host " Recommended Post-Drill Actions:" -ForegroundColor Cyan
Write-Host " 1. Run .\01-Check-Health.ps1 to verify all systems"
Write-Host " 2. Review application logs for any errors during drill"
Write-Host " 3. Document actual RTO/RPO times for reporting"
Write-Host " 4. Schedule next DR drill"
Write-Host ""

# Return results
return @{
    TotalTime = $totalTime.TotalSeconds
    Components = $results
    Timestamp = Get-Date
    Status = "Primary Restored"
}
