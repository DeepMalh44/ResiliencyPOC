# Azure Automated DR Failover

This module provides automated Disaster Recovery (DR) failover capabilities for the Azure POC Application using Azure Automation and Azure Monitor alerts.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Components](#components)
- [How It Works](#how-it-works)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Manual vs Automated Failover](#manual-vs-automated-failover)

## Overview

The automated DR failover system monitors critical Azure resources and automatically triggers failover operations when issues are detected. This complements the manual DR drill scripts by providing real-time automated response to outages.

### Key Features

- **Alert-Triggered Failover**: Azure Monitor alerts automatically trigger the failover runbook via webhook
- **Managed Identity Authentication**: Secure, passwordless authentication using system-assigned managed identity
- **Multi-Component Failover**: Handles SQL MI Failover Groups and Redis geo-replication
- **Detailed Logging**: All operations are logged for audit and troubleshooting
- **Graceful Degradation**: Front Door handles traffic failover automatically via health probes

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         AUTOMATED DR FAILOVER FLOW                          │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  Azure Monitor   │     │   Action Group   │     │    Automation    │
│     Alerts       │────▶│   (Webhook)      │────▶│     Account      │
│                  │     │                  │     │                  │
│ - SQL MI Health  │     │ - Email Notify   │     │ - Invoke-DR      │
│ - App Service    │     │ - Webhook URI    │     │   Failover.ps1   │
│ - Redis Cache    │     │                  │     │                  │
│ - Region Health  │     │                  │     │ - Managed        │
└──────────────────┘     └──────────────────┘     │   Identity       │
                                                  └────────┬─────────┘
                                                           │
                    ┌──────────────────────────────────────┼──────────────────┐
                    │                                      │                  │
                    ▼                                      ▼                  ▼
         ┌──────────────────┐              ┌──────────────────┐    ┌─────────────────┐
         │  SQL MI Failover │              │  Redis Geo-Rep   │    │   Front Door    │
         │      Group       │              │    Failover      │    │  (Automatic)    │
         │                  │              │                  │    │                 │
         │ Switch-AzSql     │              │ Remove-AzRedis   │    │ Health probes   │
         │ DatabaseInstance │              │ CacheLink        │    │ handle failover │
         │ FailoverGroup    │              │                  │    │ automatically   │
         └──────────────────┘              └──────────────────┘    └─────────────────┘
```

## Components

### 1. Azure Automation Account (`modules/automation/`)

| File | Description |
|------|-------------|
| `main.tf` | Automation Account, role assignments, modules, runbook, webhook |
| `variables.tf` | Input variables for the module |
| `outputs.tf` | Output values including webhook URI |
| `scripts/Invoke-DRFailover.ps1` | PowerShell runbook for failover execution |

### 2. DR Alerts (`modules/monitoring/dr-alerts.tf`)

| Alert | Trigger Condition | Severity |
|-------|-------------------|----------|
| SQL MI Availability | CPU = 0% (unavailable) | Critical (Sev0) |
| SQL MI Health | ResourceHealth = Degraded/Unavailable | Critical |
| App Service Availability | HealthCheckStatus < 90% | Critical |
| App Service 5xx Errors | Http5xx > 100 in 5 min | Critical |
| Redis Server Load | serverLoad > 99% | Critical |
| Redis Connectivity | connectedclients < 1 | Critical |
| Front Door Backend | OriginHealthPercentage < 50% | Warning |
| Region Service Health | Azure incident in monitored regions | Critical |

### 3. Action Group

The DR action group includes:
- **Email Receivers**: Notify operations team
- **Webhook Receiver**: Trigger Automation runbook

## How It Works

### Trigger Flow

1. **Alert Fires**: Azure Monitor detects unhealthy resource metrics
2. **Action Group Executes**: Sends email notification AND calls webhook
3. **Webhook Triggers Runbook**: Automation Account receives webhook call with alert context
4. **Runbook Executes Failover**:
   - Parses Common Alert Schema payload
   - Authenticates via Managed Identity
   - Executes SQL MI Failover Group switch
   - Removes Redis geo-replication link (promotes secondary)
   - Logs all operations
5. **Summary Generated**: Runbook outputs detailed summary for audit

### Failover Types

| Type | Description | Data Loss Risk |
|------|-------------|----------------|
| `Auto` | Alert-triggered (default webhook parameter) | No |
| `Manual` | On-demand execution | No |
| `Planned` | Scheduled maintenance/failback | No |
| `Forced` | Emergency with `-AllowDataLoss` | **Possible** |

## Configuration

### 1. Enable Automated Failover

In `environments/prod/terraform.tfvars`:

```hcl
# Enable the automation module
enable_automated_failover = true

# Your subscription ID (required for activity log alerts)
subscription_id = "your-subscription-id"

# Email addresses for alerts
alert_email_addresses = ["ops-team@company.com", "dba@company.com"]
```

### 2. Update Runbook Configuration

The runbook uses a naming convention matching Terraform locals. Update `defaultConfig` in [Invoke-DRFailover.ps1](scripts/Invoke-DRFailover.ps1):

```powershell
$defaultConfig = @{
    ProjectName = "pocapp2"      # Match var.project_name
    Environment = "prod"          # Match var.environment
    
    PrimaryRegion      = "eastus2"
    PrimaryRegionShort = "eus2"
    
    SecondaryRegion      = "centralus"
    SecondaryRegionShort = "cus"
}
```

### 3. Resource Naming Convention

The runbook builds resource names using this pattern:

| Resource | Naming Pattern | Example |
|----------|---------------|---------|
| Resource Group | `rg-{project}-{env}-{region}` | `rg-pocapp2-prod-eus2` |
| SQL MI | `sqlmi-{project}-{env}-{region}` | `sqlmi-pocapp2-prod-eus2` |
| Failover Group | `fog-{project}-sqlmi-{env}` | `fog-pocapp2-sqlmi-prod` |
| Redis | `redis-{project}-{env}-{region}` | `redis-pocapp2-prod-eus2` |

## Deployment

### Prerequisites

1. Terraform >= 1.0
2. Azure CLI authenticated
3. Contributor access to subscription
4. SQL MI deployed in both regions (with failover group)
5. Redis deployed with geo-replication (Premium tier)

### Deploy Steps

```powershell
cd environments/prod

# Initialize Terraform
terraform init

# Plan with automation enabled
terraform plan -var="enable_automated_failover=true"

# Apply
terraform apply
```

### Verify Deployment

```powershell
# Check Automation Account
az automation account show \
  --name "aa-pocapp2-prod-dr" \
  --resource-group "rg-pocapp2-prod-eus2"

# List runbooks
az automation runbook list \
  --automation-account-name "aa-pocapp2-prod-dr" \
  --resource-group "rg-pocapp2-prod-eus2" \
  -o table

# Check role assignments
az role assignment list \
  --assignee $(az automation account show --name "aa-pocapp2-prod-dr" --resource-group "rg-pocapp2-prod-eus2" --query identity.principalId -o tsv) \
  -o table
```

## Testing

### 1. Test Runbook Manually

```powershell
# Start runbook with Manual failover type
az automation runbook start \
  --automation-account-name "aa-pocapp2-prod-dr" \
  --resource-group "rg-pocapp2-prod-eus2" \
  --name "Invoke-DRFailover" \
  --parameters FailoverType=Manual

# Check job status
az automation job list \
  --automation-account-name "aa-pocapp2-prod-dr" \
  --resource-group "rg-pocapp2-prod-eus2" \
  -o table
```

### 2. Test Alert Webhook

Use the Azure Portal:
1. Navigate to **Monitor > Alerts > Action Groups**
2. Select the DR action group
3. Click **Test action group**
4. Select a sample alert type
5. Verify runbook execution in Automation Account Jobs

### 3. Simulate Alert (PowerShell)

```powershell
# Get webhook URI (from Terraform output or Key Vault)
$webhookUri = "https://xxx.webhook.eus2.azure-automation.net/webhooks?token=xxx"

# Create sample alert payload (Common Alert Schema)
$alertPayload = @{
    schemaId = "azureMonitorCommonAlertSchema"
    data = @{
        essentials = @{
            alertId = "/subscriptions/xxx/providers/Microsoft.AlertsManagement/alerts/xxx"
            alertRule = "Test-DR-Alert"
            severity = "Sev0"
            signalType = "Metric"
            monitorCondition = "Fired"
            firedDateTime = (Get-Date).ToString("o")
            alertTargetIDs = @("/subscriptions/xxx/resourceGroups/rg-pocapp2-prod-eus2")
        }
    }
} | ConvertTo-Json -Depth 10

# Invoke webhook
Invoke-RestMethod -Uri $webhookUri -Method Post -Body $alertPayload -ContentType "application/json"
```

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Runbook fails to authenticate | Missing/incorrect role assignments | Verify Managed Identity has Contributor role |
| SQL MI failover fails | Incorrect region/resource group | Check `$defaultConfig` matches Terraform |
| Redis failover fails | No geo-replication link | Verify Redis Premium tier with geo-replication |
| Webhook not triggering | Invalid webhook URI or expired | Regenerate webhook in Terraform |
| Alert not firing | Wrong metric/threshold | Review alert configuration in Azure Portal |

### View Runbook Logs

```powershell
# Get recent jobs
$jobs = az automation job list \
  --automation-account-name "aa-pocapp2-prod-dr" \
  --resource-group "rg-pocapp2-prod-eus2" \
  --query "[?status=='Completed' || status=='Failed'].{Name:runbook.name, Status:status, StartTime:startTime}" \
  -o json | ConvertFrom-Json

# Get job output
az automation job-stream list \
  --automation-account-name "aa-pocapp2-prod-dr" \
  --resource-group "rg-pocapp2-prod-eus2" \
  --job-name $jobs[0].Name \
  -o table
```

### Check Role Assignments

```powershell
# Get Automation Account's managed identity principal ID
$principalId = az automation account show \
  --name "aa-pocapp2-prod-dr" \
  --resource-group "rg-pocapp2-prod-eus2" \
  --query "identity.principalId" -o tsv

# List all role assignments for this identity
az role assignment list --assignee $principalId -o table
```

## Manual vs Automated Failover

This project includes **both** manual and automated failover capabilities:

### Manual DR Drill Scripts (`dr-drill-runbook/`)

Located in the root `dr-drill-runbook/` folder:
- **Purpose**: Scheduled DR testing and controlled failover exercises
- **Execution**: Run locally or from Azure Cloud Shell
- **Scripts**:
  - `01-PreDrillValidation.ps1` - Validate environment before drill
  - `02-InitiateFailover.ps1` - Execute failover operations
  - `03-ValidateFailover.ps1` - Verify failover success
  - `04-InitiateFailback.ps1` - Return to primary region
  - `05-PostDrillReport.ps1` - Generate drill summary

### Automated Failover (`modules/automation/`)

- **Purpose**: Real-time response to actual outages
- **Execution**: Triggered automatically by Azure Monitor alerts
- **Components**:
  - Azure Automation Account with Managed Identity
  - PowerShell runbook deployed via Terraform
  - Webhook for alert integration

### When to Use Each

| Scenario | Use Manual Scripts | Use Automated |
|----------|-------------------|---------------|
| Scheduled DR drill | ✅ | ❌ |
| Testing failover procedures | ✅ | ❌ |
| Actual production outage | ❌ | ✅ |
| Learning/Training | ✅ | ❌ |
| Unattended response | ❌ | ✅ |
| Compliance DR testing | ✅ | ❌ |

## Security Considerations

1. **Webhook URI**: Stored as sensitive output; consider storing in Key Vault
2. **Managed Identity**: Uses system-assigned identity with least-privilege roles
3. **Role Assignments**: Limited to specific resource groups and resources
4. **Alert Thresholds**: Tuned to avoid false positives triggering unnecessary failovers

## Related Documentation

- [Azure Automation Runbook Best Practices](https://learn.microsoft.com/en-us/azure/automation/automation-runbook-execution)
- [Common Alert Schema](https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-common-schema)
- [SQL MI Failover Groups](https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/failover-group-sql-mi)
- [Redis Geo-Replication](https://learn.microsoft.com/en-us/azure/azure-cache-for-redis/cache-how-to-geo-replication)
