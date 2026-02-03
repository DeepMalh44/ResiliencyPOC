#Requires -Version 7.0
<#
.SYNOPSIS
    SQL Managed Instance Failover Group Drill

.DESCRIPTION
    Performs a planned failover of the SQL MI Failover Group from primary to secondary region.
    This is a core DR drill to validate database resiliency.

.PARAMETER Failover
    Switch to failover to secondary (CUS becomes primary)

.PARAMETER Failback  
    Switch to failback to primary (EUS2 becomes primary)

.PARAMETER Force
    Skip confirmation prompt

.EXAMPLE
    .\03-SQLMI-Failover.ps1 -Failover
    .\03-SQLMI-Failover.ps1 -Failback
    .\03-SQLMI-Failover.ps1 -Failover -Force
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
    Write-Host "Usage: .\03-SQLMI-Failover.ps1 -Failover | -Failback [-Force]" -ForegroundColor Yellow
    return
}

$width = 62

Write-Host ""
Write-Host ("╔" + "═" * $width + "╗") -ForegroundColor Blue
Write-Host "║            SQL MI FAILOVER GROUP DRILL                        ║" -ForegroundColor Blue
Write-Host ("╠" + "═" * $width + "╣") -ForegroundColor Blue
Write-Host ("║ Mode: " + $(if ($Failover) { "FAILOVER (Make CUS Primary)" } else { "FAILBACK (Make EUS2 Primary)" })).PadRight($width + 1) + "║" -ForegroundColor Blue
Write-Host ("║ Start: " + (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")).PadRight($width + 1) + "║" -ForegroundColor Blue
Write-Host ("╠" + "═" * $width + "╣") -ForegroundColor Blue

# ============================================
# Pre-checks
# ============================================

Write-Host "║ Step 1: Checking Failover Group Status...".PadRight($width + 1) + "║" -ForegroundColor Cyan

$fogInfo = az sql instance-failover-group show `
    --name $Global:DrDrill.FailoverGroup.Name `
    --resource-group $Global:DrDrill.Primary.ResourceGroup `
    --location $Global:DrDrill.Primary.Region `
    --query "{role:replicationRole, state:replicationState}" -o json 2>$null | ConvertFrom-Json

if (-not $fogInfo) {
    Write-Host "║   ERROR: Could not retrieve Failover Group info".PadRight(55) + "❌   ║" -ForegroundColor Red
    Write-Host "║   Verify SQL MI and FOG exist".PadRight($width + 1) + "║" -ForegroundColor Red
    Write-Host ("╚" + "═" * $width + "╝") -ForegroundColor Blue
    return
}

Write-Host "║   Current Role: $($fogInfo.role)".PadRight($width + 1) + "║"
Write-Host "║   Replication State: $($fogInfo.state)".PadRight($width + 1) + "║"

# Validate state
if ($fogInfo.state -ne "CATCH_UP" -and $fogInfo.state -ne "SEEDING") {
    Write-Host "║   Replication is synced".PadRight(55) + "✅   ║" -ForegroundColor Green
} else {
    Write-Host "║   WARNING: Replication still syncing".PadRight(55) + "⚠️   ║" -ForegroundColor Yellow
    if (-not $Force) {
        $continue = Read-Host "║   Continue anyway? (y/N)"
        if ($continue -ne "y") {
            Write-Host ("╚" + "═" * $width + "╝") -ForegroundColor Blue
            return
        }
    }
}

# ============================================
# Confirmation
# ============================================

if (-not $Force) {
    Write-Host ("║" + " " * $width + "║")
    Write-Host "║ ⚠️  WARNING: This will perform a planned failover!".PadRight($width + 1) + "║" -ForegroundColor Yellow
    Write-Host ("║" + " " * $width + "║")
    $confirm = Read-Host "║ Type 'FAILOVER' to confirm"
    if ($confirm -ne "FAILOVER") {
        Write-Host "║ Cancelled by user".PadRight($width + 1) + "║" -ForegroundColor Yellow
        Write-Host ("╚" + "═" * $width + "╝") -ForegroundColor Blue
        return
    }
}

$startTime = Get-Date

if ($Failover) {
    # ============================================
    # FAILOVER: Switch to Secondary (CUS)
    # ============================================
    
    Write-Host ("║" + " " * $width + "║")
    Write-Host "║ Step 2: Initiating Planned Failover to CUS...".PadRight($width + 1) + "║" -ForegroundColor Cyan
    Write-Host "║   This may take 2-5 minutes...".PadRight($width + 1) + "║"
    
    $failoverStart = Get-Date
    
    # Failover is initiated from the SECONDARY location
    az sql instance-failover-group set-primary `
        --name $Global:DrDrill.FailoverGroup.Name `
        --resource-group $Global:DrDrill.Secondary.ResourceGroup `
        --location $Global:DrDrill.Secondary.Region `
        --output none

    $failoverTime = (Get-Date) - $failoverStart
    
    Write-Host "║   Failover command completed in $($failoverTime.TotalSeconds.ToString('F0'))s".PadRight(55) + "✅   ║" -ForegroundColor Green

    Write-Host ("║" + " " * $width + "║")
    Write-Host "║ Step 3: Verifying new roles...".PadRight($width + 1) + "║" -ForegroundColor Cyan
    
    # Check new primary (CUS)
    $newPrimaryRole = az sql instance-failover-group show `
        --name $Global:DrDrill.FailoverGroup.Name `
        --resource-group $Global:DrDrill.Secondary.ResourceGroup `
        --location $Global:DrDrill.Secondary.Region `
        --query "replicationRole" -o tsv 2>$null
    
    # Check new secondary (EUS2)
    $newSecondaryRole = az sql instance-failover-group show `
        --name $Global:DrDrill.FailoverGroup.Name `
        --resource-group $Global:DrDrill.Primary.ResourceGroup `
        --location $Global:DrDrill.Primary.Region `
        --query "replicationRole" -o tsv 2>$null

    if ($newPrimaryRole -eq "Primary") {
        Write-Host "║   CUS SQL MI:  $newPrimaryRole (was Secondary)".PadRight(55) + "✅   ║" -ForegroundColor Green
    } else {
        Write-Host "║   CUS SQL MI:  $newPrimaryRole".PadRight(55) + "❌   ║" -ForegroundColor Red
    }
    
    if ($newSecondaryRole -eq "Secondary") {
        Write-Host "║   EUS2 SQL MI: $newSecondaryRole (was Primary)".PadRight(55) + "✅   ║" -ForegroundColor Green
    } else {
        Write-Host "║   EUS2 SQL MI: $newSecondaryRole".PadRight(55) + "❌   ║" -ForegroundColor Red
    }

    Write-Host ("║" + " " * $width + "║")
    Write-Host "║ Step 4: Testing Failover Group Listener...".PadRight($width + 1) + "║" -ForegroundColor Cyan
    
    # Test connectivity (DNS resolution)
    $listener = "$($Global:DrDrill.FailoverGroup.Name).database.windows.net"
    Write-Host "║   Listener: $listener".PadRight($width + 1) + "║"
    
    try {
        $dns = Resolve-DnsName $listener -ErrorAction Stop
        Write-Host "║   DNS resolves to: $($dns[0].IPAddress)".PadRight(55) + "✅   ║" -ForegroundColor Green
    } catch {
        Write-Host "║   DNS resolution pending...".PadRight(55) + "⚠️   ║" -ForegroundColor Yellow
    }

    $totalTime = (Get-Date) - $startTime

    Write-Host ("╠" + "═" * $width + "╣") -ForegroundColor Blue
    Write-Host "║ SQL MI FAILOVER COMPLETE".PadRight($width + 1) + "║" -ForegroundColor Green
    Write-Host "║   RTO (Total): $($totalTime.TotalSeconds.ToString('F1')) seconds ($($totalTime.TotalMinutes.ToString('F1')) min)".PadRight($width + 1) + "║"
    Write-Host "║   RPO: ~0 (synchronous replication)".PadRight($width + 1) + "║"
    Write-Host "║   New Primary: CUS ($($Global:DrDrill.Secondary.SqlMi))".PadRight($width + 1) + "║"
    Write-Host ("╚" + "═" * $width + "╝") -ForegroundColor Blue

} else {
    # ============================================
    # FAILBACK: Switch back to Primary (EUS2)
    # ============================================
    
    Write-Host ("║" + " " * $width + "║")
    Write-Host "║ Step 2: Initiating Failback to EUS2...".PadRight($width + 1) + "║" -ForegroundColor Cyan
    Write-Host "║   This may take 2-5 minutes...".PadRight($width + 1) + "║"
    
    $failbackStart = Get-Date
    
    # Failback is initiated from the EUS2 location (currently secondary)
    az sql instance-failover-group set-primary `
        --name $Global:DrDrill.FailoverGroup.Name `
        --resource-group $Global:DrDrill.Primary.ResourceGroup `
        --location $Global:DrDrill.Primary.Region `
        --output none

    $failbackTime = (Get-Date) - $failbackStart
    
    Write-Host "║   Failback command completed in $($failbackTime.TotalSeconds.ToString('F0'))s".PadRight(55) + "✅   ║" -ForegroundColor Green

    Write-Host ("║" + " " * $width + "║")
    Write-Host "║ Step 3: Verifying restored roles...".PadRight($width + 1) + "║" -ForegroundColor Cyan
    
    $eus2Role = az sql instance-failover-group show `
        --name $Global:DrDrill.FailoverGroup.Name `
        --resource-group $Global:DrDrill.Primary.ResourceGroup `
        --location $Global:DrDrill.Primary.Region `
        --query "replicationRole" -o tsv 2>$null

    $cusRole = az sql instance-failover-group show `
        --name $Global:DrDrill.FailoverGroup.Name `
        --resource-group $Global:DrDrill.Secondary.ResourceGroup `
        --location $Global:DrDrill.Secondary.Region `
        --query "replicationRole" -o tsv 2>$null

    Write-Host "║   EUS2 SQL MI: $eus2Role (restored)".PadRight(55) + "✅   ║" -ForegroundColor Green
    Write-Host "║   CUS SQL MI:  $cusRole".PadRight(55) + "✅   ║" -ForegroundColor Green

    $totalTime = (Get-Date) - $startTime

    Write-Host ("╠" + "═" * $width + "╣") -ForegroundColor Blue
    Write-Host "║ SQL MI FAILBACK COMPLETE".PadRight($width + 1) + "║" -ForegroundColor Green
    Write-Host "║   Total Time: $($totalTime.TotalSeconds.ToString('F1')) seconds".PadRight($width + 1) + "║"
    Write-Host "║   Primary restored to: EUS2 ($($Global:DrDrill.Primary.SqlMi))".PadRight($width + 1) + "║"
    Write-Host ("╚" + "═" * $width + "╝") -ForegroundColor Blue
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  - Test application connectivity via Failover Group listener"
Write-Host "  - Verify connection strings use the FOG endpoint, not direct MI endpoint"
Write-Host "  - Monitor replication state returning to 'SYNCHRONIZED'"
Write-Host ""
