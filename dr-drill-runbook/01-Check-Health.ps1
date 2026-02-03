#Requires -Version 7.0
<#
.SYNOPSIS
    Pre-drill health check for all resources

.DESCRIPTION
    Verifies all resources are healthy before running DR drills.
    Run this BEFORE any failover drill.
#>

# Load environment if not already loaded
if (-not $Global:DrDrill) {
    . "$PSScriptRoot\00-Setup-Environment.ps1"
}

$width = 62

Write-Host ""
Write-Host ("╔" + "═" * $width + "╗") -ForegroundColor Cyan
Write-Host "║              PRE-DRILL HEALTH CHECK                          ║" -ForegroundColor Cyan
Write-Host ("╠" + "═" * $width + "╣") -ForegroundColor Cyan
Write-Host ("║ Timestamp: " + (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")).PadRight($width + 1) + "║" -ForegroundColor Cyan
Write-Host ("╠" + "═" * $width + "╣") -ForegroundColor Cyan

$allHealthy = $true

# ============================================
# Check App Services
# ============================================

Write-Host "║ APP SERVICES".PadRight($width + 1) + "║" -ForegroundColor Yellow

# Primary App Service
try {
    $primaryApp = az webapp show --name $Global:DrDrill.Primary.AppService `
        --resource-group $Global:DrDrill.Primary.ResourceGroup `
        --query "state" -o tsv 2>$null
    
    if ($primaryApp -eq "Running") {
        Write-Host "║   Primary (EUS2):   Running".PadRight(55) + "✅   ║" -ForegroundColor Green
    } else {
        Write-Host "║   Primary (EUS2):   $primaryApp".PadRight(55) + "❌   ║" -ForegroundColor Red
        $allHealthy = $false
    }
} catch {
    Write-Host "║   Primary (EUS2):   Not Found".PadRight(55) + "❌   ║" -ForegroundColor Red
    $allHealthy = $false
}

# Secondary App Service
try {
    $secondaryApp = az webapp show --name $Global:DrDrill.Secondary.AppService `
        --resource-group $Global:DrDrill.Secondary.ResourceGroup `
        --query "state" -o tsv 2>$null
    
    if ($secondaryApp -eq "Running") {
        Write-Host "║   Secondary (CUS):  Running".PadRight(55) + "✅   ║" -ForegroundColor Green
    } else {
        Write-Host "║   Secondary (CUS):  $secondaryApp".PadRight(55) + "❌   ║" -ForegroundColor Red
        $allHealthy = $false
    }
} catch {
    Write-Host "║   Secondary (CUS):  Not Found".PadRight(55) + "❌   ║" -ForegroundColor Red
    $allHealthy = $false
}

Write-Host ("║" + " " * $width + "║")

# ============================================
# Check SQL Managed Instances
# ============================================

Write-Host "║ SQL MANAGED INSTANCES".PadRight($width + 1) + "║" -ForegroundColor Yellow

# Primary SQL MI
try {
    $primarySql = az sql mi show --name $Global:DrDrill.Primary.SqlMi `
        --resource-group $Global:DrDrill.Primary.ResourceGroup `
        --query "state" -o tsv 2>$null
    
    if ($primarySql -eq "Ready") {
        Write-Host "║   Primary (EUS2):   Ready".PadRight(55) + "✅   ║" -ForegroundColor Green
    } else {
        Write-Host "║   Primary (EUS2):   $primarySql".PadRight(55) + "⚠️   ║" -ForegroundColor Yellow
        $allHealthy = $false
    }
} catch {
    Write-Host "║   Primary (EUS2):   Not Found/Creating".PadRight(55) + "⚠️   ║" -ForegroundColor Yellow
    $allHealthy = $false
}

# Secondary SQL MI
try {
    $secondarySql = az sql mi show --name $Global:DrDrill.Secondary.SqlMi `
        --resource-group $Global:DrDrill.Secondary.ResourceGroup `
        --query "state" -o tsv 2>$null
    
    if ($secondarySql -eq "Ready") {
        Write-Host "║   Secondary (CUS):  Ready".PadRight(55) + "✅   ║" -ForegroundColor Green
    } else {
        Write-Host "║   Secondary (CUS):  $secondarySql".PadRight(55) + "⚠️   ║" -ForegroundColor Yellow
        $allHealthy = $false
    }
} catch {
    Write-Host "║   Secondary (CUS):  Not Found/Creating".PadRight(55) + "⚠️   ║" -ForegroundColor Yellow
    $allHealthy = $false
}

# Failover Group
try {
    $fogRole = az sql instance-failover-group show `
        --name $Global:DrDrill.FailoverGroup.Name `
        --resource-group $Global:DrDrill.Primary.ResourceGroup `
        --location $Global:DrDrill.Primary.Region `
        --query "replicationRole" -o tsv 2>$null
    
    Write-Host "║   Failover Group:   Primary is $fogRole".PadRight(55) + "✅   ║" -ForegroundColor Green
} catch {
    Write-Host "║   Failover Group:   Not Configured".PadRight(55) + "⚠️   ║" -ForegroundColor Yellow
}

Write-Host ("║" + " " * $width + "║")

# ============================================
# Check Redis Cache
# ============================================

Write-Host "║ REDIS CACHE".PadRight($width + 1) + "║" -ForegroundColor Yellow

# Primary Redis
try {
    $primaryRedis = az redis show --name $Global:DrDrill.Primary.Redis `
        --resource-group $Global:DrDrill.Primary.ResourceGroup `
        --query "provisioningState" -o tsv 2>$null
    
    if ($primaryRedis -eq "Succeeded") {
        Write-Host "║   Primary (EUS2):   Succeeded".PadRight(55) + "✅   ║" -ForegroundColor Green
    } else {
        Write-Host "║   Primary (EUS2):   $primaryRedis".PadRight(55) + "⚠️   ║" -ForegroundColor Yellow
    }
} catch {
    Write-Host "║   Primary (EUS2):   Not Found".PadRight(55) + "⚠️   ║" -ForegroundColor Yellow
}

# Secondary Redis
try {
    $secondaryRedis = az redis show --name $Global:DrDrill.Secondary.Redis `
        --resource-group $Global:DrDrill.Secondary.ResourceGroup `
        --query "provisioningState" -o tsv 2>$null
    
    if ($secondaryRedis -eq "Succeeded") {
        Write-Host "║   Secondary (CUS):  Succeeded".PadRight(55) + "✅   ║" -ForegroundColor Green
    } else {
        Write-Host "║   Secondary (CUS):  $secondaryRedis".PadRight(55) + "⚠️   ║" -ForegroundColor Yellow
    }
} catch {
    Write-Host "║   Secondary (CUS):  Not Found".PadRight(55) + "⚠️   ║" -ForegroundColor Yellow
}

Write-Host ("║" + " " * $width + "║")

# ============================================
# Check Front Door
# ============================================

Write-Host "║ FRONT DOOR".PadRight($width + 1) + "║" -ForegroundColor Yellow

try {
    $fdState = az afd profile show --profile-name $Global:DrDrill.FrontDoor.Name `
        --resource-group $Global:DrDrill.FrontDoor.ResourceGroup `
        --query "provisioningState" -o tsv 2>$null
    
    if ($fdState -eq "Succeeded") {
        Write-Host "║   Profile:          Succeeded".PadRight(55) + "✅   ║" -ForegroundColor Green
    } else {
        Write-Host "║   Profile:          $fdState".PadRight(55) + "⚠️   ║" -ForegroundColor Yellow
    }
} catch {
    Write-Host "║   Profile:          Not Found".PadRight(55) + "⚠️   ║" -ForegroundColor Yellow
}

# ============================================
# Summary
# ============================================

Write-Host ("╠" + "═" * $width + "╣") -ForegroundColor Cyan

if ($allHealthy) {
    Write-Host "║ OVERALL STATUS: ALL HEALTHY - Ready for DR Drill".PadRight(55) + "✅   ║" -ForegroundColor Green
} else {
    Write-Host "║ OVERALL STATUS: SOME ISSUES - Review before drill".PadRight(55) + "⚠️   ║" -ForegroundColor Yellow
}

Write-Host ("╚" + "═" * $width + "╝") -ForegroundColor Cyan
Write-Host ""

return $allHealthy
