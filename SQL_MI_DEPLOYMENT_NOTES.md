# SQL MI Deployment Session Notes
## POC Resiliency Project - February 2026

> ✅ **RESOLVED** - All SQL MI issues have been fixed. This file is kept for historical reference.

---

## ✅ FINAL RESOLUTION (February 4, 2026)

All SQL MI deployment issues have been resolved:

1. **SKU Changed**: From `BC_Gen5` (blocked by quota) → `GP_G8IM` (General Purpose Premium Series)
2. **NSG Rules Added**: Geo-replication ports 5022, 11000-11999, 1433 for VirtualNetwork
3. **Failover Group**: Successfully created using separate resource to avoid circular dependency
4. **Deployment Verified**: `pocapp6` successfully deployed with:
   - SQL MI Primary: `sqlmi-pocapp6-prod-eus2` (~40 min)
   - SQL MI Secondary: `sqlmi-pocapp6-prod-cus` (~18 min)
   - Failover Group: `fog-pocapp6-prod` (~1 min)

---

## Historical Notes (Original Issues)

**Infrastructure Created:**
- ✅ Resource Groups: `rg-pocapp6-prod-eus2` (primary), `rg-pocapp6-prod-cus` (secondary)
- ✅ VNets, Subnets, NSGs in both regions with geo-replication rules
- ✅ Route Tables for SQL MI subnets
- ✅ SQL MI subnet delegations configured correctly

**SQL MI Status:**
- ✅ **EUS2 (Primary)**: Successfully deployed with GP_G8IM SKU
- ✅ **CUS (Secondary)**: Successfully deployed with GP_G8IM SKU
- ✅ **Failover Group**: Successfully configured (`fog-pocapp6-prod`)

---

## Key Errors Encountered & Solutions

| Error | Root Cause | Solution Applied |
|-------|------------|------------------|
| `BC_Gen5` SKU failed | Gen5 vCore quota = 0 in EUS2 | Changed to `BC_G8IM` (Premium Series) |
| NSG rule conflicts (`SecurityRuleConflict`) | SQL MI auto-creates NSG rules at priority 100 | Removed custom SQL MI NSG rules from Terraform |
| `ConflictingServerOperation` | Terraform tried to modify SQL MI while it was creating | Removed secondary from state, updated `proxy_override` default |
| `ProvisioningDisabled` - max vCores: 0 | EUS2 has 0 Gen5 vCore quota | **Awaiting quota increase** |

---

## Quota Situation

**East US 2 (EUS2):**
- `VCoreQuota` (Gen5): **0 / 0** ← This is the blocker
- `PremiumSeriesVCoreQuota`: 0 / 960 (available but unused due to Gen5 check)

**Central US (CUS):**
- `VCoreQuota` (Gen5): 16 / 960 ✅
- `PremiumSeriesVCoreQuota`: 16 / 960 ✅

---

## Terraform State Status

| Resource | In State? | Notes |
|----------|-----------|-------|
| `module.sql_mi_primary[0]` | ❌ No | Never created |
| `module.sql_mi_secondary[0]` | ❌ No | Removed from state (was creating in Azure) |

---

## Code Changes Made

1. **modules/sql-mi/variables.tf**: Changed `proxy_override` default from `"Default"` to `"Redirect"` (matches Azure's default)

2. **modules/networking/main.tf**: Removed custom SQL MI NSG rules (Azure manages these automatically)

3. **environments/prod/terraform.tfvars**: `sql_mi_sku_name = "BC_G8IM"` (Premium Series)

---

## When You Return With Quota

### Step 1: Check/Clean Azure Resources
```powershell
# Check if any SQL MIs exist
az sql mi list -o table

# Check SQL MI operations if any exist
az sql mi op list --managed-instance sqlmi-pocapp2-prod-cus --resource-group rg-pocapp2-prod-cus -o table
```

### Step 2: Import any existing SQL MIs (if they exist in Azure)
```powershell
cd C:\Users\ketaanhshah\Documents\ResilencyPOC\environments\prod

# If CUS SQL MI exists and is Ready:
terraform import 'module.sql_mi_secondary[0].azapi_resource.managed_instance' '/subscriptions/b8383a80-7a39-472f-89b8-4f0b6a53b266/resourceGroups/rg-pocapp2-prod-cus/providers/Microsoft.Sql/managedInstances/sqlmi-pocapp2-prod-cus'

# If EUS2 SQL MI exists and is Ready:
terraform import 'module.sql_mi_primary[0].azapi_resource.managed_instance' '/subscriptions/b8383a80-7a39-472f-89b8-4f0b6a53b266/resourceGroups/rg-pocapp2-prod-eus2/providers/Microsoft.Sql/managedInstances/sqlmi-pocapp2-prod-eus2'
```

### Step 3: Run Terraform Apply
```powershell
cd C:\Users\ketaanhshah\Documents\ResilencyPOC\environments\prod
terraform plan
terraform apply -auto-approve
```

---

## Key Configuration Values

| Setting | Value |
|---------|-------|
| Subscription | `b8383a80-7a39-472f-89b8-4f0b6a53b266` |
| Tenant | `6021aa37-5a44-450a-8854-f08245985be2` |
| SQL MI SKU | `BC_G8IM` (Business Critical Premium Series) |
| vCores | 4 |
| Primary Region | East US 2 |
| Secondary Region | Central US |
| Azure AD Admin | `admin@MngEnvMCAP245137.onmicrosoft.com` |
| Azure AD Admin Object ID | `941f59fd-aeb5-4ba2-9fb9-2f5132d15500` |

---

## Quota Request Details

Request **Gen5 vCore quota** for **East US 2** region:
- Resource: SQL Managed Instance
- Quota Type: VCoreQuota (Gen5)
- Requested: At least 16 vCores (960 recommended to match CUS)
- Azure Portal: aka.ms/sql-mi-obtain-larger-quota

---

## Useful Commands

```powershell
# Check quotas
az sql list-usages --location eastus2 -o table
az sql list-usages --location centralus -o table

# Check SQL MI status
az sql mi list -o table
az sql mi show --name sqlmi-pocapp2-prod-eus2 --resource-group rg-pocapp2-prod-eus2 -o json

# Check SQL MI operations
az sql mi op list --managed-instance <name> --resource-group <rg> -o table
```
