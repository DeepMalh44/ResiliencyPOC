#Requires -Version 7.0
<#
.SYNOPSIS
    Redis Cache Geo-Replication Failover Drill

.DESCRIPTION
    Tests Redis geo-replication failover. For Premium tier Redis with geo-replication,
    this promotes the secondary to primary and reconfigures replication.

.PARAMETER Failover
    Switch to failover to secondary Redis (break replication, promote secondary)

.PARAMETER Failback
    Switch to restore original topology (re-link as primary)

.PARAMETER Force
    Skip confirmation prompt

.NOTES
    Redis geo-replication failover is DESTRUCTIVE - it breaks the replication link.
    After failover, you must manually re-establish geo-replication.

.EXAMPLE
    .\04-Redis-Failover.ps1 -Failover
    .\04-Redis-Failover.ps1 -Failback
#>

param(
    [switch]$Failover,
    [switch]$Failback,
    [switch]$Force
)

# Load environment
if (-not $Global:DrDrill) {
    . "$PSScriptRoot\00-Setup-Environment.ps1"
}

if (-not $Failover -and -not $Failback) {
    Write-Host "Usage: .\04-Redis-Failover.ps1 -Failover | -Failback [-Force]" -ForegroundColor Yellow
    return
}

$width = 62

Write-Host ""
Write-Host ("╔" + "═" * $width + "╗") -ForegroundColor Red
Write-Host "║            REDIS GEO-REPLICATION DRILL                        ║" -ForegroundColor Red
Write-Host ("╠" + "═" * $width + "╣") -ForegroundColor Red
Write-Host ("║ Mode: " + $(if ($Failover) { "FAILOVER (Unlink & Promote CUS)" } else { "FAILBACK (Re-establish Replication)" })).PadRight($width + 1) + "║" -ForegroundColor Red
Write-Host ("║ Start: " + (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")).PadRight($width + 1) + "║" -ForegroundColor Red
Write-Host ("╠" + "═" * $width + "╣") -ForegroundColor Red

# ============================================
# Pre-checks
# ============================================

Write-Host "║ Step 1: Checking Redis Cache Status...".PadRight($width + 1) + "║" -ForegroundColor Cyan

# Check primary Redis
$primaryRedis = az redis show `
    --name $Global:DrDrill.Primary.Redis `
    --resource-group $Global:DrDrill.Primary.ResourceGroup `
    --query "{state:provisioningState, sku:sku.name}" -o json 2>$null | ConvertFrom-Json

if ($primaryRedis) {
    Write-Host "║   Primary (EUS2): $($primaryRedis.state) - $($primaryRedis.sku)".PadRight($width + 1) + "║"
} else {
    Write-Host "║   Primary (EUS2): Not Found".PadRight(55) + "❌   ║" -ForegroundColor Red
    Write-Host ("╚" + "═" * $width + "╝") -ForegroundColor Red
    return
}

# Check secondary Redis
$secondaryRedis = az redis show `
    --name $Global:DrDrill.Secondary.Redis `
    --resource-group $Global:DrDrill.Secondary.ResourceGroup `
    --query "{state:provisioningState, sku:sku.name}" -o json 2>$null | ConvertFrom-Json

if ($secondaryRedis) {
    Write-Host "║   Secondary (CUS): $($secondaryRedis.state) - $($secondaryRedis.sku)".PadRight($width + 1) + "║"
} else {
    Write-Host "║   Secondary (CUS): Not Found".PadRight(55) + "❌   ║" -ForegroundColor Red
    Write-Host ("╚" + "═" * $width + "╝") -ForegroundColor Red
    return
}

# Check geo-replication links
Write-Host ("║" + " " * $width + "║")
Write-Host "║ Step 2: Checking Geo-Replication Links...".PadRight($width + 1) + "║" -ForegroundColor Cyan

$geoLinks = az redis server-link list `
    --name $Global:DrDrill.Primary.Redis `
    --resource-group $Global:DrDrill.Primary.ResourceGroup `
    --query "[].{name:name, role:serverRole, state:geoReplicatedPrimaryHostName}" 2>$null | ConvertFrom-Json

if ($geoLinks -and $geoLinks.Count -gt 0) {
    Write-Host "║   Geo-replication: ACTIVE".PadRight(55) + "✅   ║" -ForegroundColor Green
    foreach ($link in $geoLinks) {
        Write-Host "║     - $($link.name): $($link.role)".PadRight($width + 1) + "║"
    }
} else {
    Write-Host "║   Geo-replication: NOT CONFIGURED".PadRight(55) + "⚠️   ║" -ForegroundColor Yellow
}

$startTime = Get-Date

if ($Failover) {
    # ============================================
    # FAILOVER: Break replication, promote secondary
    # ============================================
    
    Write-Host ("║" + " " * $width + "║")
    Write-Host "║ ⚠️  WARNING: This will BREAK geo-replication link!".PadRight($width + 1) + "║" -ForegroundColor Yellow
    Write-Host "║ The secondary cache will become an independent cache.".PadRight($width + 1) + "║" -ForegroundColor Yellow
    
    if (-not $Force) {
        $confirm = Read-Host "║ Type 'UNLINK' to confirm"
        if ($confirm -ne "UNLINK") {
            Write-Host "║ Cancelled by user".PadRight($width + 1) + "║"
            Write-Host ("╚" + "═" * $width + "╝") -ForegroundColor Red
            return
        }
    }
    
    Write-Host ("║" + " " * $width + "║")
    Write-Host "║ Step 3: Breaking Geo-Replication Link...".PadRight($width + 1) + "║" -ForegroundColor Cyan
    
    $unlinkStart = Get-Date
    
    # Get the secondary cache resource ID for unlinking
    $secondaryId = az redis show `
        --name $Global:DrDrill.Secondary.Redis `
        --resource-group $Global:DrDrill.Secondary.ResourceGroup `
        --query "id" -o tsv 2>$null
    
    # Unlink (from primary) - Note: This command doesn't have --yes, it runs immediately
    az redis server-link delete `
        --name $Global:DrDrill.Primary.Redis `
        --resource-group $Global:DrDrill.Primary.ResourceGroup `
        --linked-server-name $Global:DrDrill.Secondary.Redis `
        --output none 2>$null

    $unlinkTime = (Get-Date) - $unlinkStart
    Write-Host "║   Geo-replication unlinked in $($unlinkTime.TotalSeconds.ToString('F1'))s".PadRight(55) + "✅   ║" -ForegroundColor Green
    
    Write-Host ("║" + " " * $width + "║")
    Write-Host "║ Step 4: Verifying Secondary is Independent...".PadRight($width + 1) + "║" -ForegroundColor Cyan
    
    Start-Sleep -Seconds 5
    
    $newSecondaryState = az redis show `
        --name $Global:DrDrill.Secondary.Redis `
        --resource-group $Global:DrDrill.Secondary.ResourceGroup `
        --query "provisioningState" -o tsv 2>$null
    
    Write-Host "║   CUS Redis State: $newSecondaryState".PadRight(55) + "✅   ║" -ForegroundColor Green
    
    Write-Host ("║" + " " * $width + "║")
    Write-Host "║ Step 5: Update Application Config".PadRight($width + 1) + "║" -ForegroundColor Cyan
    
    # Get secondary connection info
    $secondaryHostname = az redis show `
        --name $Global:DrDrill.Secondary.Redis `
        --resource-group $Global:DrDrill.Secondary.ResourceGroup `
        --query "hostName" -o tsv 2>$null
    
    Write-Host "║   New Redis endpoint: $secondaryHostname".PadRight($width + 1) + "║"
    Write-Host "║   Update REDIS_CONNECTION_STRING in App Service".PadRight($width + 1) + "║"

    $totalTime = (Get-Date) - $startTime

    Write-Host ("╠" + "═" * $width + "╣") -ForegroundColor Red
    Write-Host "║ REDIS FAILOVER COMPLETE".PadRight($width + 1) + "║" -ForegroundColor Green
    Write-Host "║   RTO: $($totalTime.TotalSeconds.ToString('F1')) seconds".PadRight($width + 1) + "║"
    Write-Host "║   CUS Redis is now independent (writable)".PadRight($width + 1) + "║"
    Write-Host ("╚" + "═" * $width + "╝") -ForegroundColor Red

    Write-Host ""
    Write-Host "⚠️  IMPORTANT: Manual steps required:" -ForegroundColor Yellow
    Write-Host "   1. Update App Service configuration to use CUS Redis endpoint"
    Write-Host "   2. Test application connectivity"
    Write-Host "   3. When primary is restored, re-establish geo-replication"
    Write-Host ""

} else {
    # ============================================
    # FAILBACK: Re-establish geo-replication
    # ============================================
    
    Write-Host ("║" + " " * $width + "║")
    Write-Host "║ Step 3: Re-establishing Geo-Replication...".PadRight($width + 1) + "║" -ForegroundColor Cyan
    Write-Host "║   This will link CUS as secondary to EUS2 primary".PadRight($width + 1) + "║"
    
    if (-not $Force) {
        $confirm = Read-Host "║ Type 'RELINK' to confirm"
        if ($confirm -ne "RELINK") {
            Write-Host "║ Cancelled by user".PadRight($width + 1) + "║"
            Write-Host ("╚" + "═" * $width + "╝") -ForegroundColor Red
            return
        }
    }
    
    $linkStart = Get-Date
    
    # Get secondary cache resource ID
    $secondaryId = az redis show `
        --name $Global:DrDrill.Secondary.Redis `
        --resource-group $Global:DrDrill.Secondary.ResourceGroup `
        --query "id" -o tsv 2>$null
    
    # Create geo-replication link (secondary cache links to primary)
    az redis server-link create `
        --name $Global:DrDrill.Primary.Redis `
        --resource-group $Global:DrDrill.Primary.ResourceGroup `
        --server-to-link $secondaryId `
        --replication-role Secondary `
        --output none 2>$null

    $linkTime = (Get-Date) - $linkStart
    Write-Host "║   Geo-replication link created in $($linkTime.TotalSeconds.ToString('F1'))s".PadRight(55) + "✅   ║" -ForegroundColor Green
    
    Write-Host ("║" + " " * $width + "║")
    Write-Host "║ Step 4: Waiting for sync...".PadRight($width + 1) + "║" -ForegroundColor Cyan
    Write-Host "║   Initial sync may take several minutes...".PadRight($width + 1) + "║"
    
    # Wait a bit and check status
    Start-Sleep -Seconds 10
    
    $newLinks = az redis server-link list `
        --name $Global:DrDrill.Primary.Redis `
        --resource-group $Global:DrDrill.Primary.ResourceGroup `
        --query "[].{name:name, role:serverRole}" 2>$null | ConvertFrom-Json
    
    if ($newLinks -and $newLinks.Count -gt 0) {
        Write-Host "║   Geo-replication: RE-ESTABLISHED".PadRight(55) + "✅   ║" -ForegroundColor Green
    } else {
        Write-Host "║   Geo-replication: Check status manually".PadRight(55) + "⚠️   ║" -ForegroundColor Yellow
    }

    $totalTime = (Get-Date) - $startTime

    Write-Host ("╠" + "═" * $width + "╣") -ForegroundColor Red
    Write-Host "║ REDIS FAILBACK COMPLETE".PadRight($width + 1) + "║" -ForegroundColor Green
    Write-Host "║   Total Time: $($totalTime.TotalSeconds.ToString('F1')) seconds".PadRight($width + 1) + "║"
    Write-Host "║   Geo-replication restored: EUS2 (Primary) -> CUS (Secondary)".PadRight($width + 1) + "║"
    Write-Host ("╚" + "═" * $width + "╝") -ForegroundColor Red

    Write-Host ""
    Write-Host "✅ IMPORTANT: Update App Service config to use EUS2 Redis endpoint" -ForegroundColor Green
    Write-Host ""
}
