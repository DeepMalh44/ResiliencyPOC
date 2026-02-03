# DR Drill Runbook
## POC Resiliency Project

This runbook contains PowerShell scripts to demonstrate and validate disaster recovery capabilities.

---

## Prerequisites

1. Azure CLI installed and logged in (`az login`)
2. Infrastructure deployed (SQL MI, App Service, Redis, Storage in both regions)
3. PowerShell 7+ recommended

---

## Quick Start

```powershell
# 1. Set up environment variables
.\00-Setup-Environment.ps1

# 2. Check health before drill
.\01-Check-Health.ps1

# 3. Run individual drills
.\02-AppService-Failover.ps1
.\03-SQLMI-Failover.ps1
.\04-Redis-Failover.ps1

# 4. Or run full region failover
.\05-FullRegion-Failover.ps1

# 5. Failback when done
.\06-Failback-All.ps1
```

---

## Drill Scenarios

| Script | Description | Risk | Duration |
|--------|-------------|------|----------|
| `02-AppService-Failover.ps1` | Stop primary App Service, verify Front Door routes to secondary | Low | ~2 min |
| `03-SQLMI-Failover.ps1` | Trigger SQL MI failover group switch | Medium | ~3 min |
| `04-Redis-Failover.ps1` | Force Redis geo-replication failover | Medium | ~2 min |
| `05-FullRegion-Failover.ps1` | Simulate full primary region failure | Medium | ~5 min |
| `06-Failback-All.ps1` | Restore primary region as active | Low | ~5 min |

---

## Expected Outcomes

- **RTO Target**: 1 hour
- **RPO Target**: 4 hours
- **Actual RTO**: Typically < 5 minutes for most scenarios

---

## ⚠️ Important Notes

1. **SQL MI Failover** takes 60-120 seconds - this is normal
2. **Front Door** health probes run every 30 seconds - detection may take up to 90 seconds
3. **Always run `01-Check-Health.ps1`** before any drill to ensure baseline is healthy
4. **Test in non-production first** if possible

---

## File Structure

```
dr-drill-runbook/
├── 00-Setup-Environment.ps1    # Configure variables
├── 01-Check-Health.ps1         # Pre-drill health check
├── 02-AppService-Failover.ps1  # App Service DR drill
├── 03-SQLMI-Failover.ps1       # SQL MI DR drill
├── 04-Redis-Failover.ps1       # Redis DR drill
├── 05-FullRegion-Failover.ps1  # Full region DR drill
├── 06-Failback-All.ps1         # Restore primary
└── README.md                   # This file
```
