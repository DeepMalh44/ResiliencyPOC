<#
.SYNOPSIS
    Automated DR Failover Runbook for Azure POC Application
    
.DESCRIPTION
    This runbook is triggered by Azure Monitor alerts via webhook to perform
    automated failover of critical infrastructure components:
    - SQL Managed Instance Failover Group
    - Azure Cache for Redis Geo-Replication
    
    The runbook authenticates using the Automation Account's managed identity.
    Front Door handles its own failover via health probes - no action needed.
    
.PARAMETER WebhookData
    JSON payload from Azure Monitor alert webhook containing alert context
    
.PARAMETER FailoverType
    Type of failover: 'Auto' (alert-triggered), 'Manual', 'Planned', or 'Forced'
    
.PARAMETER ConfigJson
    JSON string containing deployment-specific configuration.
    If not provided, uses Automation Account variables.
    
.NOTES
    Version: 1.1.0
    Author: Azure POC Team
    Last Modified: 2026-02
    
    Prerequisites:
    - Automation Account with System Assigned Managed Identity
    - Az.Accounts, Az.Sql, Az.RedisCache modules imported
    - Contributor role on resource groups
    - SQL MI Contributor role on SQL resources
    - Redis Cache Contributor role on Redis resources
    
    Terraform Integration:
    - Configuration values are injected via Terraform template
    - Resource names follow: {resource}-{project}-{env}-{region}
#>

param(
    [Parameter(Mandatory = $false)]
    [object]$WebhookData,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('Auto', 'Manual', 'Planned', 'Forced')]
    [string]$FailoverType = 'Auto',
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigJson = ''
)

#------------------------------------------------------------------------------
# Configuration
# These values should match your Terraform deployment naming convention:
#   Resource Group: rg-{project}-{env}-{region}
#   SQL MI: sqlmi-{project}-{env}-{region}
#   Redis: redis-{project}-{env}-{region}
#   Failover Group: fog-{project}-sqlmi-{env}
#------------------------------------------------------------------------------

# Default configuration - UPDATE THESE TO MATCH YOUR TERRAFORM VARIABLES
# Format: {resource_type}-{project_name}-{environment}-{region_short}
$defaultConfig = @{
    # Project identification (should match var.project_name and var.environment)
    ProjectName = "pocapp5"      # UPDATE: Match your var.project_name
    Environment = "prod"          # UPDATE: Match your var.environment
    
    # Primary Region Configuration
    PrimaryRegion      = "eastus2"
    PrimaryRegionShort = "eus2"
    
    # Secondary Region Configuration  
    SecondaryRegion      = "centralus"
    SecondaryRegionShort = "cus"
}

# Build resource names from configuration (matches Terraform locals)
function Get-ResourceConfig {
    param([hashtable]$BaseConfig)
    
    $project = $BaseConfig.ProjectName
    $env = $BaseConfig.Environment
    $priShort = $BaseConfig.PrimaryRegionShort
    $secShort = $BaseConfig.SecondaryRegionShort
    
    return @{
        # Regions
        PrimaryRegion   = $BaseConfig.PrimaryRegion
        SecondaryRegion = $BaseConfig.SecondaryRegion
        
        # Resource Groups (format: rg-{project}-{env}-{region})
        PrimaryResourceGroup   = "rg-$project-$env-$priShort"
        SecondaryResourceGroup = "rg-$project-$env-$secShort"
        
        # SQL Managed Instance (format: sqlmi-{project}-{env}-{region})
        SqlMiPrimaryName   = "sqlmi-$project-$env-$priShort"
        SqlMiSecondaryName = "sqlmi-$project-$env-$secShort"
        
        # SQL MI Failover Group (format: fog-{project}-sqlmi-{env})
        SqlMiFailoverGroupName = "fog-$project-sqlmi-$env"
        
        # Redis Cache (format: redis-{project}-{env}-{region})
        RedisPrimaryName   = "redis-$project-$env-$priShort"
        RedisSecondaryName = "redis-$project-$env-$secShort"
        
        # App Service (format: app-{project}-{env}-{region})
        AppServicePrimaryName   = "app-$project-$env-$priShort"
        AppServiceSecondaryName = "app-$project-$env-$secShort"
        
        # Front Door (format: fd-{project}-{env})
        FrontDoorName          = "fd-$project-$env"
        FrontDoorResourceGroup = "rg-$project-$env-$priShort"
    }
}

# Initialize configuration
if ($ConfigJson -and $ConfigJson -ne '') {
    try {
        $providedConfig = $ConfigJson | ConvertFrom-Json -AsHashtable
        $config = Get-ResourceConfig -BaseConfig $providedConfig
        Write-Output "[INFO] Using provided configuration"
    }
    catch {
        Write-Warning "Failed to parse ConfigJson, using defaults: $($_.Exception.Message)"
        $config = Get-ResourceConfig -BaseConfig $defaultConfig
    }
}
else {
    $config = Get-ResourceConfig -BaseConfig $defaultConfig
}

#------------------------------------------------------------------------------
# Functions
#------------------------------------------------------------------------------

function Write-LogMessage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $prefix = switch ($Level) {
        'Info'    { "[INFO]" }
        'Warning' { "[WARN]" }
        'Error'   { "[ERROR]" }
        'Success' { "[SUCCESS]" }
    }
    
    Write-Output "$timestamp $prefix $Message"
    
    if ($Level -eq 'Error') {
        Write-Error $Message -ErrorAction Continue
    }
}

function Connect-AzureWithManagedIdentity {
    <#
    .SYNOPSIS
        Connects to Azure using the Automation Account's managed identity
    #>
    try {
        Write-LogMessage "Connecting to Azure using Managed Identity..." -Level Info
        
        # Disable auto-context save to prevent conflicts in runbook
        Disable-AzContextAutosave -Scope Process | Out-Null
        
        # Connect using system-assigned managed identity
        $connection = Connect-AzAccount -Identity -ErrorAction Stop
        
        Write-LogMessage "Successfully connected to Azure" -Level Success
        Write-LogMessage "  Account: $($connection.Context.Account.Id)" -Level Info
        Write-LogMessage "  Subscription: $($connection.Context.Subscription.Name)" -Level Info
        Write-LogMessage "  Subscription ID: $($connection.Context.Subscription.Id)" -Level Info
        
        return $true
    }
    catch {
        Write-LogMessage "Failed to connect to Azure: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Get-AlertContext {
    <#
    .SYNOPSIS
        Parses the webhook data from Azure Monitor alert (Common Alert Schema)
    .LINK
        https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-common-schema
    #>
    param([object]$WebhookData)
    
    if (-not $WebhookData) {
        Write-LogMessage "No webhook data provided - running in manual/scheduled mode" -Level Warning
        return $null
    }
    
    try {
        # Handle both string and object webhook data
        $webhookBody = if ($WebhookData -is [string]) {
            $WebhookData | ConvertFrom-Json
        }
        elseif ($WebhookData.RequestBody) {
            $WebhookData.RequestBody | ConvertFrom-Json
        }
        else {
            $WebhookData
        }
        
        # Parse Common Alert Schema
        $alertContext = @{
            SchemaId        = $webhookBody.schemaId
            AlertName       = $webhookBody.data.essentials.alertRule
            AlertId         = $webhookBody.data.essentials.alertId
            Severity        = $webhookBody.data.essentials.severity
            SignalType      = $webhookBody.data.essentials.signalType
            MonitorCondition = $webhookBody.data.essentials.monitorCondition
            FiredDateTime   = $webhookBody.data.essentials.firedDateTime
            ResolvedDateTime = $webhookBody.data.essentials.resolvedDateTime
            Description     = $webhookBody.data.essentials.description
            TargetResourceIds = $webhookBody.data.essentials.alertTargetIDs
            TargetResourceType = $webhookBody.data.essentials.targetResourceType
            OriginAlertId   = $webhookBody.data.essentials.originAlertId
        }
        
        Write-LogMessage "========================================" -Level Info
        Write-LogMessage "Alert Context (Common Alert Schema)" -Level Info
        Write-LogMessage "========================================" -Level Info
        Write-LogMessage "  Alert Rule: $($alertContext.AlertName)" -Level Info
        Write-LogMessage "  Severity: Sev$($alertContext.Severity)" -Level Info
        Write-LogMessage "  Condition: $($alertContext.MonitorCondition)" -Level Info
        Write-LogMessage "  Signal Type: $($alertContext.SignalType)" -Level Info
        Write-LogMessage "  Fired At: $($alertContext.FiredDateTime)" -Level Info
        Write-LogMessage "  Target Resources: $($alertContext.TargetResourceIds -join ', ')" -Level Info
        
        return $alertContext
    }
    catch {
        Write-LogMessage "Failed to parse webhook data: $($_.Exception.Message)" -Level Warning
        Write-LogMessage "Webhook data type: $($WebhookData.GetType().Name)" -Level Warning
        return $null
    }
}

function Invoke-SqlMiFailover {
    <#
    .SYNOPSIS
        Triggers failover of SQL Managed Instance Failover Group
    .DESCRIPTION
        Uses Switch-AzSqlDatabaseInstanceFailoverGroup to failover to the secondary region.
        The failover must be initiated from the secondary (target) region.
    #>
    param(
        [hashtable]$Config,
        [string]$FailoverType
    )
    
    Write-LogMessage "========================================" -Level Info
    Write-LogMessage "SQL MI Failover Group Operation" -Level Info
    Write-LogMessage "========================================" -Level Info
    Write-LogMessage "Failover Group: $($Config.SqlMiFailoverGroupName)" -Level Info
    
    try {
        # Try to get failover group from primary region first
        Write-LogMessage "Checking failover group status from primary region..." -Level Info
        
        $failoverGroup = Get-AzSqlDatabaseInstanceFailoverGroup `
            -ResourceGroupName $Config.PrimaryResourceGroup `
            -Location $Config.PrimaryRegion `
            -Name $Config.SqlMiFailoverGroupName `
            -ErrorAction SilentlyContinue
        
        $sourceRegion = $Config.PrimaryRegion
        $sourceRG = $Config.PrimaryResourceGroup
        
        if (-not $failoverGroup) {
            Write-LogMessage "Primary region not responding, checking secondary..." -Level Warning
            
            $failoverGroup = Get-AzSqlDatabaseInstanceFailoverGroup `
                -ResourceGroupName $Config.SecondaryResourceGroup `
                -Location $Config.SecondaryRegion `
                -Name $Config.SqlMiFailoverGroupName `
                -ErrorAction Stop
            
            $sourceRegion = $Config.SecondaryRegion
            $sourceRG = $Config.SecondaryResourceGroup
        }
        
        Write-LogMessage "Failover Group Status:" -Level Info
        Write-LogMessage "  Primary MI: $($failoverGroup.PrimaryManagedInstanceName)" -Level Info
        Write-LogMessage "  Secondary MI: $($failoverGroup.PartnerManagedInstanceName)" -Level Info
        Write-LogMessage "  Replication Role: $($failoverGroup.ReplicationRole)" -Level Info
        Write-LogMessage "  Replication State: $($failoverGroup.ReplicationState)" -Level Info
        
        # Determine if failover is needed and target location
        # Failover must be initiated FROM the secondary (which becomes the new primary)
        if ($failoverGroup.ReplicationRole -eq "Primary") {
            # Current instance is primary, failover to secondary
            $targetLocation = $Config.SecondaryRegion
            $targetRG = $Config.SecondaryResourceGroup
            Write-LogMessage "Current instance is PRIMARY - will failover to secondary" -Level Info
        }
        else {
            # Current instance is secondary, this region becomes primary
            $targetLocation = $sourceRegion
            $targetRG = $sourceRG
            Write-LogMessage "Current instance is SECONDARY - initiating failover to this region" -Level Info
        }
        
        Write-LogMessage "Target Location: $targetLocation" -Level Info
        Write-LogMessage "Target Resource Group: $targetRG" -Level Info
        Write-LogMessage "Failover Type: $FailoverType" -Level Info
        
        # Execute failover
        if ($FailoverType -eq 'Forced') {
            Write-LogMessage "Executing FORCED failover (AllowDataLoss)..." -Level Warning
            Write-LogMessage "WARNING: This may result in data loss!" -Level Warning
            
            $result = Switch-AzSqlDatabaseInstanceFailoverGroup `
                -ResourceGroupName $targetRG `
                -Location $targetLocation `
                -Name $Config.SqlMiFailoverGroupName `
                -AllowDataLoss `
                -ErrorAction Stop
        }
        else {
            Write-LogMessage "Executing planned failover (no data loss)..." -Level Info
            
            $result = Switch-AzSqlDatabaseInstanceFailoverGroup `
                -ResourceGroupName $targetRG `
                -Location $targetLocation `
                -Name $Config.SqlMiFailoverGroupName `
                -ErrorAction Stop
        }
        
        # Wait for failover to complete
        Write-LogMessage "Waiting for failover to complete..." -Level Info
        Start-Sleep -Seconds 30
        
        # Verify new state
        $updatedFG = Get-AzSqlDatabaseInstanceFailoverGroup `
            -ResourceGroupName $targetRG `
            -Location $targetLocation `
            -Name $Config.SqlMiFailoverGroupName `
            -ErrorAction Stop
        
        Write-LogMessage "Failover completed!" -Level Success
        Write-LogMessage "  New Primary: $($updatedFG.PrimaryManagedInstanceName)" -Level Success
        Write-LogMessage "  Replication State: $($updatedFG.ReplicationState)" -Level Info
        
        return @{
            Success = $true
            NewPrimary = $updatedFG.PrimaryManagedInstanceName
            NewSecondary = $updatedFG.PartnerManagedInstanceName
            ReplicationState = $updatedFG.ReplicationState
            Message = "SQL MI failover completed successfully"
        }
    }
    catch {
        Write-LogMessage "SQL MI Failover FAILED: $($_.Exception.Message)" -Level Error
        return @{
            Success = $false
            Error = $_.Exception.Message
            Message = "SQL MI failover failed"
        }
    }
}

function Invoke-RedisFailover {
    <#
    .SYNOPSIS
        Handles Azure Cache for Redis geo-replication failover
    .DESCRIPTION
        For Premium tier Redis with geo-replication, failover is achieved by
        unlinking the caches. The secondary becomes a standalone primary.
        NOTE: After unlinking, you must re-establish geo-replication manually.
    #>
    param(
        [hashtable]$Config
    )
    
    Write-LogMessage "========================================" -Level Info
    Write-LogMessage "Redis Geo-Replication Failover" -Level Info
    Write-LogMessage "========================================" -Level Info
    Write-LogMessage "Primary Redis: $($Config.RedisPrimaryName)" -Level Info
    Write-LogMessage "Secondary Redis: $($Config.RedisSecondaryName)" -Level Info
    
    try {
        # Check if primary Redis is accessible
        $primaryRedis = Get-AzRedisCache `
            -ResourceGroupName $Config.PrimaryResourceGroup `
            -Name $Config.RedisPrimaryName `
            -ErrorAction SilentlyContinue
        
        if ($primaryRedis) {
            Write-LogMessage "Primary Redis Status: $($primaryRedis.ProvisioningState)" -Level Info
            
            # Check for geo-replication links
            $linkedServers = Get-AzRedisCacheLink `
                -Name $Config.RedisPrimaryName `
                -ErrorAction SilentlyContinue
            
            if ($linkedServers -and $linkedServers.Count -gt 0) {
                Write-LogMessage "Found $($linkedServers.Count) geo-replication link(s)" -Level Info
                
                foreach ($link in $linkedServers) {
                    Write-LogMessage "  Linked Cache: $($link.LinkedRedisCacheName)" -Level Info
                    Write-LogMessage "  Server Role: $($link.ServerRole)" -Level Info
                }
                
                # Remove geo-replication link to promote secondary
                Write-LogMessage "Removing geo-replication link..." -Level Warning
                Write-LogMessage "NOTE: Secondary will become standalone. Re-link manually after DR." -Level Warning
                
                Remove-AzRedisCacheLink `
                    -PrimaryServerName $Config.RedisPrimaryName `
                    -SecondaryServerName $Config.RedisSecondaryName `
                    -ErrorAction Stop
                
                Write-LogMessage "Geo-replication link removed successfully" -Level Success
                Write-LogMessage "Secondary Redis is now standalone primary" -Level Success
                
                return @{
                    Success = $true
                    NewPrimary = $Config.RedisSecondaryName
                    Message = "Redis geo-replication link removed - secondary promoted"
                }
            }
            else {
                Write-LogMessage "No geo-replication links found" -Level Warning
                Write-LogMessage "Redis caches may already be standalone" -Level Warning
                
                return @{
                    Success = $true
                    Message = "No geo-replication links to remove"
                }
            }
        }
        else {
            # Primary not accessible - check secondary
            Write-LogMessage "Primary Redis not accessible, checking secondary..." -Level Warning
            
            $secondaryRedis = Get-AzRedisCache `
                -ResourceGroupName $Config.SecondaryResourceGroup `
                -Name $Config.RedisSecondaryName `
                -ErrorAction Stop
            
            Write-LogMessage "Secondary Redis is accessible" -Level Info
            Write-LogMessage "Status: $($secondaryRedis.ProvisioningState)" -Level Info
            Write-LogMessage "Applications should use secondary Redis endpoint" -Level Warning
            
            return @{
                Success = $true
                NewPrimary = $Config.RedisSecondaryName
                Message = "Primary unavailable - secondary Redis should be used"
            }
        }
    }
    catch {
        Write-LogMessage "Redis Failover FAILED: $($_.Exception.Message)" -Level Error
        return @{
            Success = $false
            Error = $_.Exception.Message
            Message = "Redis failover failed"
        }
    }
}

function Send-FailoverSummary {
    <#
    .SYNOPSIS
        Outputs a summary of the failover operation
    #>
    param(
        [hashtable]$Results,
        [string]$FailoverType,
        [hashtable]$Config
    )
    
    $summary = @"

================================================================================
                    DR FAILOVER EXECUTION SUMMARY
================================================================================
Execution Time : $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Failover Type  : $FailoverType
Primary Region : $($Config.PrimaryRegion)
Target Region  : $($Config.SecondaryRegion)

--------------------------------------------------------------------------------
COMPONENT STATUS
--------------------------------------------------------------------------------
SQL MI Failover Group : $(if ($Results.SqlMi.Success) { "SUCCESS - New Primary: $($Results.SqlMi.NewPrimary)" } else { "FAILED - $($Results.SqlMi.Error)" })
Redis Geo-Replication : $(if ($Results.Redis.Success) { "SUCCESS - $($Results.Redis.Message)" } else { "FAILED - $($Results.Redis.Error)" })
Front Door            : $(if ($Results.FrontDoor.Success) { "OK - $($Results.FrontDoor.Message)" } else { "FAILED - $($Results.FrontDoor.Error)" })

--------------------------------------------------------------------------------
POST-FAILOVER CHECKLIST
--------------------------------------------------------------------------------
[ ] 1. Verify application connectivity to new primary region
[ ] 2. Check SQL MI replication status in Azure Portal
[ ] 3. Update application connection strings if needed
[ ] 4. Re-establish Redis geo-replication (if applicable)
[ ] 5. Monitor application performance metrics
[ ] 6. Notify stakeholders of DR activation
[ ] 7. Document incident timeline

--------------------------------------------------------------------------------
FAILBACK INSTRUCTIONS
--------------------------------------------------------------------------------
To fail back to the original primary region, run this runbook with:
  FailoverType = 'Planned'

After failback, re-establish geo-replication for Redis manually.
================================================================================
"@
    
    Write-Output $summary
}

#------------------------------------------------------------------------------
# MAIN EXECUTION
#------------------------------------------------------------------------------

Write-LogMessage "================================================================" -Level Info
Write-LogMessage "  AZURE POC APPLICATION - DR FAILOVER RUNBOOK" -Level Info
Write-LogMessage "================================================================" -Level Info
Write-LogMessage "Execution Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level Info
Write-LogMessage "Failover Type: $FailoverType" -Level Info
Write-LogMessage "" -Level Info

# Display configuration
Write-LogMessage "Configuration:" -Level Info
Write-LogMessage "  Primary RG: $($config.PrimaryResourceGroup)" -Level Info
Write-LogMessage "  Secondary RG: $($config.SecondaryResourceGroup)" -Level Info
Write-LogMessage "  SQL MI Failover Group: $($config.SqlMiFailoverGroupName)" -Level Info

# Parse alert context if webhook-triggered
$alertContext = Get-AlertContext -WebhookData $WebhookData

if ($alertContext) {
    Write-LogMessage "" -Level Info
    Write-LogMessage "*** ALERT-TRIGGERED FAILOVER ***" -Level Warning
    Write-LogMessage "Alert: $($alertContext.AlertName)" -Level Warning
    Write-LogMessage "Severity: Sev$($alertContext.Severity)" -Level Warning
}
else {
    Write-LogMessage "" -Level Info
    Write-LogMessage "Manual/Scheduled failover execution" -Level Info
}

# Connect to Azure using Managed Identity
Write-LogMessage "" -Level Info
$connected = Connect-AzureWithManagedIdentity
if (-not $connected) {
    Write-LogMessage "Cannot proceed without Azure connection" -Level Error
    throw "Azure authentication failed - check Managed Identity configuration"
}

# Initialize results
$results = @{
    SqlMi = @{ Success = $false; Message = "Not executed" }
    Redis = @{ Success = $false; Message = "Not executed" }
    FrontDoor = @{ Success = $true; Message = "Uses health probes - automatic failover" }
}

# Execute failover operations
Write-LogMessage "" -Level Info
try {
    # 1. SQL Managed Instance Failover Group
    $results.SqlMi = Invoke-SqlMiFailover -Config $config -FailoverType $FailoverType
    
    # 2. Redis Geo-Replication Failover
    $results.Redis = Invoke-RedisFailover -Config $config
    
    # 3. Front Door - No action needed (health probes handle failover)
    Write-LogMessage "" -Level Info
    Write-LogMessage "Front Door: No action required" -Level Info
    Write-LogMessage "  Front Door uses health probes for automatic origin failover" -Level Info
}
catch {
    Write-LogMessage "Critical error during failover: $($_.Exception.Message)" -Level Error
}

# Output summary
Send-FailoverSummary -Results $results -FailoverType $FailoverType -Config $config

# Determine overall success
$overallSuccess = $results.SqlMi.Success -and $results.Redis.Success

Write-LogMessage "" -Level Info
if ($overallSuccess) {
    Write-LogMessage "================================================================" -Level Success
    Write-LogMessage "  DR FAILOVER COMPLETED SUCCESSFULLY" -Level Success
    Write-LogMessage "================================================================" -Level Success
}
else {
    Write-LogMessage "================================================================" -Level Error
    Write-LogMessage "  DR FAILOVER COMPLETED WITH ERRORS" -Level Error
    Write-LogMessage "  Review the logs above for details" -Level Error
    Write-LogMessage "================================================================" -Level Error
}

Write-LogMessage "Execution Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level Info
