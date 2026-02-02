# Azure Resilient Infrastructure - Terraform Implementation Prompt

## 🎯 Objective

Create a production-ready, highly resilient Azure infrastructure using Terraform for a **greenfield deployment** (nothing exists). The infrastructure must demonstrate **multi-zone** and **multi-region** capabilities as a Proof of Concept (POC) for enterprise resiliency.

### 🔴 CRITICAL POC REQUIREMENTS - MUST IMPLEMENT

> **This POC exists to prove RESILIENCY. The following are NON-NEGOTIABLE:**

1. **MULTI-ZONE (Availability Zones)**: Every supported Azure service MUST be deployed across **multiple availability zones (minimum 2, preferably 3)** within each region. This protects against datacenter failures.

2. **MULTI-REGION**: The ENTIRE infrastructure MUST be deployed to **TWO regions** (Primary + Secondary) with proper failover mechanisms. This protects against regional disasters.

3. **ACTIVE-ACTIVE**: Both regions MUST actively serve traffic simultaneously through Azure Front Door, not just standby.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    RESILIENCY ARCHITECTURE OVERVIEW                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│                        ┌─────────────────────┐                          │
│                        │  AZURE FRONT DOOR   │                          │
│                        │  (Global - Active)  │                          │
│                        └──────────┬──────────┘                          │
│                                   │                                     │
│              ┌────────────────────┼────────────────────┐                │
│              │                    │                    │                │
│              ▼                    │                    ▼                │
│  ┌───────────────────────┐        │        ┌───────────────────────┐    │
│  │   PRIMARY REGION      │        │        │   SECONDARY REGION    │    │
│  │   (East US 2)         │        │        │   (Central US)        │    │
│  │                       │        │        │                       │    │
│  │  ┌─────┬─────┬─────┐  │        │        │  ┌─────┬─────┬─────┐  │    │
│  │  │ AZ1 │ AZ2 │ AZ3 │  │◄───────┼───────►│  │ AZ1 │ AZ2 │ AZ3 │  │    │
│  │  └─────┴─────┴─────┘  │   Geo-Repl/     │  └─────┴─────┴─────┘  │    │
│  │   ZONE REDUNDANT      │   Failover      │   ZONE REDUNDANT      │    │
│  └───────────────────────┘                 └───────────────────────┘    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 📋 Business Requirements

| Requirement | Value |
|-------------|-------|
| **RTO (Recovery Time Objective)** | Maximum 1 hour |
| **RPO (Recovery Point Objective)** | Maximum 4 hours from disaster point |
| **Budget** | Not a constraint - resiliency is priority |
| **Deployment Model** | Active-Active (both regions serve traffic) |
| **Primary Region** | **East US 2** (configurable via variable) |
| **Secondary Region** | **Central US** (configurable via variable) |
| **Environment Type** | Greenfield - no existing resources |
| **Zone Redundancy** | **REQUIRED** - All services must use 2-3 availability zones |
| **Multi-Region** | **REQUIRED** - Deploy to BOTH regions with failover |

### ✅ Regional Pairing - OPTIMAL CONFIGURATION

| Azure Paired Regions | Your Selection |
|---------------------|----------------|
| **East US 2 ↔ Central US** | ✅ **East US 2 → Central US** |

**Your choice (East US 2 → Central US) is an official Azure paired region:**
- ✅ SQL MI failover groups will have **optimal geo-replication speed**
- ✅ Coordinated maintenance windows (Azure won't update both simultaneously)
- ✅ Regional recovery prioritization during disasters
- ✅ Lowest possible replication latency (~1-5 seconds)
- ✅ Easily meets your 4-hour RPO requirement

---

## 🏗️ Architecture Components to Deploy

### Global Layer
1. **Azure Front Door Premium** (CRITICAL for Multi-Region)
   - **🔴 MULTI-REGION LOAD BALANCING**: Route traffic to BOTH regions (Active-Active)
   - Configure origin groups with origins from BOTH regions
   - WAF policy with OWASP rule sets
   - Health probes for automatic failover (probe interval: 10 seconds)
   - Custom domains support
   - Private Link origins (secure backend connectivity)
   ```hcl
   # Required multi-region origin configuration
   origin_group {
     health_probe {
       interval_in_seconds = 10
       protocol            = "Https"
     }
     load_balancing {
       sample_size                 = 4
       successful_samples_required = 2
     }
   }
   
   # Origins from BOTH regions
   origin {
     name      = "primary-region-origin"
     host_name = "<primary-region-endpoint>"
     priority  = 1
     weight    = 50
   }
   origin {
     name      = "secondary-region-origin"
     host_name = "<secondary-region-endpoint>"
     priority  = 1  # Same priority = Active-Active
     weight    = 50
   }
   ```

### Per-Region Components (Deploy in BOTH regions)

2. **API Management (APIM) - Premium Tier**
   - **🔴 ZONE REDUNDANCY**: Enable with minimum 2 units distributed across zones [1, 2, 3]
   - **🔴 MULTI-REGION**: Deploy APIM instance in BOTH primary and secondary regions
   - Virtual network integration (internal mode preferred)
   - Managed identity (system-assigned)
   - Custom domains with managed certificates
   - Shared configuration via Git or external config store
   ```hcl
   # Required zone configuration
   zones = ["1", "2", "3"]
   sku_name = "Premium_2"  # Minimum 2 units for zone distribution
   ```

3. **App Service Environment v3 OR App Service Premium v3**
   - **🔴 ZONE REDUNDANCY**: Set `zone_balancing_enabled = true` with minimum 3 instances
   - **🔴 MULTI-REGION**: Deploy identical App Service Plan + Apps in BOTH regions
   - Virtual network integration
   - Managed identity for all apps
   - Deployment slots for zero-downtime deployments
   - Auto-scaling rules configured (min 3 instances for zone spread)
   - Private endpoints enabled
   ```hcl
   # Required zone configuration
   zone_balancing_enabled = true
   worker_count           = 3  # Minimum for zone redundancy
   ```

4. **Azure Functions - Premium Plan (Elastic Premium EP2/EP3)**
   - **🔴 ZONE REDUNDANCY**: Enable zone redundancy on the hosting plan
   - **🔴 MULTI-REGION**: Deploy Function Apps in BOTH regions
   - Virtual network integration
   - Managed identity
   - Private endpoints
   - Application Insights integration
   ```hcl
   # Required zone configuration
   zone_balancing_enabled = true
   ```

5. **Azure Storage Accounts**
   - **🔴 ZONE REDUNDANCY**: Use ZRS or GZRS (data replicated across 3 zones)
   - **🔴 MULTI-REGION**: Use **RA-GZRS** (Read-Access Geo-Zone-Redundant) for automatic geo-replication
   - Private endpoints only (no public access)
   - Managed identity access (disable shared key)
   - Soft delete and versioning enabled
   - Immutable storage policies where applicable
   ```hcl
   # Required redundancy configuration
   account_replication_type = "RAGZRS"  # Zone + Geo redundancy with read access
   ```

6. **Azure SQL Managed Instance - Business Critical Tier**
   - **🔴 ZONE REDUNDANCY**: Enable `zone_redundant = true` (requires Business Critical tier)
   - **🔴 MULTI-REGION**: Configure **Failover Group** between primary and secondary regions
   - Failover group with auto-failover policy (grace period aligned with RTO)
   - Private endpoints only
   - Azure AD authentication only (disable SQL auth)
   - TDE with customer-managed keys (Azure Key Vault)
   - Long-term backup retention configured
   
   ### ⚠️ IMPORTANT: SQL MI Regional Pairing Consideration
   
   **Azure Region Pairs for SQL MI Failover Groups:**
   - SQL MI failover groups work best with **Azure paired regions** for optimal geo-replication speed
   - **South Central US** is paired with **North Central US** (NOT Central US)
   - **Central US** is paired with **East US 2**
   
   **Options for your scenario:**
   
   | Option | Primary Region | Secondary Region | Notes |
   |--------|---------------|------------------|-------|
   | **Option A (Recommended)** | South Central US | **North Central US** | Official Azure pair - fastest replication |
   | **Option B** | South Central US | Central US | Works but non-paired - may have higher latency |
   | **Option C** | **East US 2** | Central US | Official Azure pair if you can change primary |
   
   **SQL MI Failover Group supports ANY region combination**, but paired regions provide:
   - Significantly higher geo-replication speed
   - Coordinated maintenance windows
   - Regional recovery prioritization
   
   **If sticking with South Central US → Central US:**
   - This is a valid non-paired configuration
   - Expect slightly higher replication latency (~5-15 seconds vs ~1-5 seconds)
   - Configure different maintenance windows for each region
   - Still meets your 4-hour RPO requirement easily
   
   ```hcl
   # SQL MI Failover Group Configuration
   # Primary: East US 2, Secondary: Central US (OFFICIAL AZURE PAIRED REGIONS)
   
   resource "azurerm_mssql_managed_instance_failover_group" "main" {
     name                        = "sqlmi-fog-${var.project_name}"
     location                    = var.primary_location
     managed_instance_id         = azurerm_mssql_managed_instance.primary.id
     partner_managed_instance_id = azurerm_mssql_managed_instance.secondary.id
     
     read_write_endpoint_failover_policy {
       mode          = "Automatic"
       grace_minutes = 60  # 1 hour = aligns with RTO
     }
     
     # Customer-managed failover is RECOMMENDED over Microsoft-managed
     # This gives you control over when failover occurs
   }
   
   # Both instances MUST have:
   # - Same service tier (Business Critical)
   # - Same compute size
   # - Zone redundancy enabled
   # - Same DNS zone ID (specified during secondary creation)
   ```
   
   ### SQL MI Active-Active vs Active-Passive
   
   > **⚠️ SQL MI Failover Groups are ACTIVE-PASSIVE by design:**
   > - **Primary**: Read-Write operations
   > - **Secondary**: Read-Only operations (readable geo-secondary)
   > - You CANNOT write to both simultaneously
   
   **However, you can achieve "Read Active-Active":**
   ```
   ┌─────────────────────────────────────────────────────────────────┐
   │                     SQL MI ARCHITECTURE                        │
   ├─────────────────────────────────────────────────────────────────┤
   │                                                                 │
   │   PRIMARY (East US 2)           SECONDARY (Central US)        │
   │   ┌─────────────────────┐        ┌─────────────────────┐       │
   │   │   SQL MI (BC Tier)  │        │   SQL MI (BC Tier)  │       │
   │   │   Zone Redundant    │───────▶│   Zone Redundant    │       │
   │   │                     │  Async │                     │       │
   │   │   READ + WRITE      │  Repl  │   READ ONLY         │       │
   │   └─────────────────────┘        └─────────────────────┘       │
   │                                                                 │
   │   Listener Endpoints:                                          │
   │   • Read-Write: <fog-name>.<zone_id>.database.windows.net      │
   │   • Read-Only:  <fog-name>.secondary.<zone_id>.database.windows.net │
   │                                                                 │
   │   Application Strategy:                                        │
   │   • Write operations → Read-Write endpoint (Primary)           │
   │   • Read operations  → Can use EITHER endpoint                 │
   │   • Reporting/Analytics → Read-Only endpoint (Secondary)       │
   │                                                                 │
   └─────────────────────────────────────────────────────────────────┘
   ```
   
   **Failover Behavior:**
   - Automatic failover triggers after grace period (60 min for your RTO)
   - After failover, secondary becomes new primary (roles swap)
   - Connection strings using listener endpoints automatically redirect
   - No application connection string changes required

7. **Azure Key Vault - Premium Tier**
   - Soft delete and purge protection enabled
   - Private endpoints only
   - RBAC authorization model
   - Managed HSM for high-security scenarios (optional)
   - Geo-replication for DR

8. **Azure Cache for Redis - Premium Tier**
   - **🔴 ZONE REDUNDANCY**: Enable zone redundancy with `zones = ["1", "2", "3"]`
   - **🔴 MULTI-REGION**: Configure **geo-replication** link between primary and secondary regions
   - Private endpoints only
   - Managed identity access
   ```hcl
   # Required zone configuration
   zones    = ["1", "2", "3"]
   sku_name = "Premium"
   family   = "P"
   
   # Geo-replication for multi-region
   # Link secondary cache to primary for replication
   ```

9. **Virtual Network Infrastructure**
   - Hub-spoke topology per region
   - VNet peering between regions (global peering)
   - Network Security Groups (NSGs) with strict rules
   - Azure Firewall or NVA in hub (optional but recommended)
   - Private DNS zones for all PaaS services
   - DDoS Protection Standard

10. **Monitoring & Observability**
    - Log Analytics Workspace (per region + central)
    - Application Insights (per app)
    - Azure Monitor alerts and action groups
    - Diagnostic settings for all resources
    - Azure Dashboard for operations

---

## 🔒 Security Requirements

| Security Control | Implementation |
|------------------|----------------|
| **Identity** | Managed Identities everywhere - NO service principals with secrets |
| **Network** | Private endpoints for ALL PaaS services |
| **Public Access** | Disabled on all services except Front Door |
| **Key Management** | Azure Key Vault with RBAC, customer-managed keys for encryption |
| **Authentication** | Azure AD/Entra ID only - disable local authentication |
| **TLS** | Minimum TLS 1.2, TLS 1.3 preferred |
| **WAF** | Azure Front Door Premium WAF with prevention mode |
| **NSG** | Deny-all default, explicit allow rules only |
| **Secrets** | No hardcoded secrets - use Key Vault references |
| **RBAC** | Least privilege principle, custom roles where needed |

---

## 📁 Terraform Project Structure

```
terraform/
├── modules/
│   ├── resource-group/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── networking/
│   │   ├── main.tf              # VNet, Subnets, NSGs
│   │   ├── private-dns.tf       # Private DNS Zones
│   │   ├── peering.tf           # VNet Peering
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── key-vault/
│   │   ├── main.tf
│   │   ├── private-endpoint.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── front-door/
│   │   ├── main.tf              # Front Door Premium
│   │   ├── waf-policy.tf        # WAF configuration
│   │   ├── origins.tf           # Backend origins
│   │   ├── routes.tf            # Routing rules
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── apim/
│   │   ├── main.tf              # APIM Premium with zones
│   │   ├── identity.tf          # Managed identity config
│   │   ├── networking.tf        # VNet integration
│   │   ├── private-endpoint.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── app-service/
│   │   ├── main.tf              # App Service Plan + Web Apps
│   │   ├── identity.tf
│   │   ├── slots.tf             # Deployment slots
│   │   ├── autoscale.tf
│   │   ├── private-endpoint.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── function-app/
│   │   ├── main.tf              # Function App Premium
│   │   ├── identity.tf
│   │   ├── private-endpoint.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── storage/
│   │   ├── main.tf              # Storage Account RA-GZRS
│   │   ├── containers.tf
│   │   ├── private-endpoint.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── sql-mi/
│   │   ├── main.tf              # SQL MI Business Critical
│   │   ├── failover-group.tf    # Cross-region failover
│   │   ├── identity.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── redis/
│   │   ├── main.tf              # Redis Premium with zones
│   │   ├── geo-replication.tf
│   │   ├── private-endpoint.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── monitoring/
│   │   ├── main.tf              # Log Analytics, App Insights
│   │   ├── alerts.tf
│   │   ├── diagnostics.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── private-endpoint/        # Reusable PE module
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── environments/
│   └── prod/
│       ├── main.tf              # Root module - orchestrates all
│       ├── providers.tf         # Provider configuration
│       ├── backend.tf           # Remote state configuration
│       ├── variables.tf         # All variable declarations
│       ├── terraform.tfvars     # Default values (sample)
│       ├── outputs.tf           # Root outputs
│       └── locals.tf            # Local values and naming
└── README.md                    # Documentation
```

---

## 📝 Variable Design Requirements

### All variables must be overridable. Create these categories:

#### 1. Global Configuration Variables
```hcl
variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "pocapp"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "primary_location" {
  description = "Primary Azure region for deployment"
  type        = string
  default     = "eastus2"
}

variable "secondary_location" {
  description = "Secondary Azure region for DR/HA"
  type        = string
  default     = "centralus"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Environment = "Production"
    Project     = "POC-Resiliency"
    ManagedBy   = "Terraform"
  }
}
```

#### 2. Networking Variables
```hcl
variable "vnet_address_space_primary" {
  description = "Address space for primary region VNet"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "vnet_address_space_secondary" {
  description = "Address space for secondary region VNet"
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

variable "subnet_configurations" {
  description = "Subnet configurations for each region"
  type = map(object({
    address_prefix                            = string
    service_endpoints                         = list(string)
    private_endpoint_network_policies_enabled = bool
    delegation                                = optional(object({
      name    = string
      actions = list(string)
    }))
  }))
}
```

#### 3. Compute Variables (APIM, App Service, Functions)
```hcl
variable "apim_sku_name" {
  description = "APIM SKU (must be Premium for multi-region)"
  type        = string
  default     = "Premium"
}

variable "apim_sku_capacity" {
  description = "Number of APIM units per region"
  type        = number
  default     = 2
}

variable "apim_zones" {
  description = "Availability zones for APIM"
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "app_service_sku" {
  description = "App Service Plan SKU"
  type = object({
    tier = string
    size = string
  })
  default = {
    tier = "PremiumV3"
    size = "P1v3"
  }
}

variable "app_service_zone_redundant" {
  description = "Enable zone redundancy for App Service"
  type        = bool
  default     = true
}

variable "function_app_sku" {
  description = "Function App Premium Plan SKU"
  type        = string
  default     = "EP2"
}
```

#### 4. Data Services Variables
```hcl
variable "sql_mi_sku" {
  description = "SQL Managed Instance SKU"
  type = object({
    name     = string
    tier     = string
    family   = string
    capacity = number
  })
  default = {
    name     = "GP_Gen5"
    tier     = "BusinessCritical"
    family   = "Gen5"
    capacity = 4
  }
}

variable "sql_mi_zone_redundant" {
  description = "Enable zone redundancy for SQL MI"
  type        = bool
  default     = true
}

variable "storage_account_tier" {
  description = "Storage account tier"
  type        = string
  default     = "Standard"
}

variable "storage_account_replication" {
  description = "Storage account replication type"
  type        = string
  default     = "RAGZRS"
}

variable "redis_sku" {
  description = "Redis Cache SKU"
  type = object({
    name     = string
    family   = string
    capacity = number
  })
  default = {
    name     = "Premium"
    family   = "P"
    capacity = 1
  }
}
```

#### 5. Security Variables
```hcl
variable "enable_private_endpoints" {
  description = "Enable private endpoints for all PaaS services"
  type        = bool
  default     = true
}

variable "enable_public_access" {
  description = "Enable public access (should be false for production)"
  type        = bool
  default     = false
}

variable "min_tls_version" {
  description = "Minimum TLS version"
  type        = string
  default     = "1.2"
}

variable "enable_waf" {
  description = "Enable WAF on Front Door"
  type        = bool
  default     = true
}

variable "waf_mode" {
  description = "WAF mode (Detection or Prevention)"
  type        = string
  default     = "Prevention"
}
```

---

## 🔄 Module Design Patterns

### 1. Each module must support multi-region deployment
```hcl
# Example: Module should accept region as parameter
module "app_service_primary" {
  source   = "../../modules/app-service"
  location = var.primary_location
  # ... other params
}

module "app_service_secondary" {
  source   = "../../modules/app-service"
  location = var.secondary_location
  # ... other params
}
```

### 2. Use for_each for multi-region where appropriate
```hcl
locals {
  regions = {
    primary   = var.primary_location
    secondary = var.secondary_location
  }
}

module "networking" {
  for_each = local.regions
  source   = "../../modules/networking"
  location = each.value
  # ...
}
```

### 3. Outputs must expose necessary values for cross-module references
```hcl
# Every module must output IDs and connection info
output "resource_id" { }
output "resource_name" { }
output "private_ip_address" { }  # If applicable
output "principal_id" { }         # For managed identity
```

---

## ⚙️ Terraform Configuration Requirements

### Provider Configuration
```hcl
terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.45"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}
```

### Backend Configuration (Remote State)
```hcl
# Backend should use geo-redundant storage
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate"
    container_name       = "tfstate"
    key                  = "pocapp.prod.tfstate"
  }
}
```

---

## 🏷️ Naming Convention

Use consistent naming across all resources:

```hcl
locals {
  # Format: {resource_type}-{project}-{environment}-{region_short}-{instance}
  naming = {
    resource_group    = "rg-${var.project_name}-${var.environment}"
    vnet              = "vnet-${var.project_name}-${var.environment}"
    subnet            = "snet-${var.project_name}-${var.environment}"
    apim              = "apim-${var.project_name}-${var.environment}"
    app_service_plan  = "asp-${var.project_name}-${var.environment}"
    app_service       = "app-${var.project_name}-${var.environment}"
    function_app      = "func-${var.project_name}-${var.environment}"
    storage_account   = "st${var.project_name}${var.environment}"  # No hyphens
    key_vault         = "kv-${var.project_name}-${var.environment}"
    sql_mi            = "sqlmi-${var.project_name}-${var.environment}"
    redis             = "redis-${var.project_name}-${var.environment}"
    front_door        = "fd-${var.project_name}-${var.environment}"
    log_analytics     = "log-${var.project_name}-${var.environment}"
  }
  
  # Region short codes
  region_short = {
    eastus2        = "eus2"   # PRIMARY
    centralus      = "cus"    # SECONDARY
    eastus         = "eus"
    southcentralus = "scus"
    westus         = "wus"
    westus2        = "wus2"
  }
}
```

---

## ✅ Validation & Testing Requirements

1. **terraform validate** - Must pass with no errors
2. **terraform fmt** - Code must be properly formatted
3. **terraform plan** - Must show expected resources
4. **tflint** - Should pass linting rules
5. **checkov/tfsec** - Security scanning should pass

---

## 📤 Expected Outputs

The root module must output:
```hcl
output "front_door_endpoint" {
  description = "Azure Front Door endpoint URL"
}

output "apim_gateway_urls" {
  description = "APIM gateway URLs for both regions"
}

output "sql_mi_failover_group_endpoint" {
  description = "SQL MI failover group listener endpoint"
}

output "key_vault_uris" {
  description = "Key Vault URIs for both regions"
}

output "resource_group_ids" {
  description = "Resource group IDs"
}

output "managed_identity_ids" {
  description = "Managed identity principal IDs for RBAC"
}
```

---

## 🚨 Critical Implementation Notes

### 🔴 MULTI-ZONE & MULTI-REGION (TOP PRIORITY)
1. **EVERY** supported service MUST have zone redundancy enabled
2. **EVERY** service MUST be deployed to BOTH regions (primary + secondary)
3. **Front Door** MUST have origins from BOTH regions with equal weights (Active-Active)
4. **SQL MI** MUST have a failover group configured between regions
5. **Redis** MUST have geo-replication configured between regions
6. **Storage** MUST use RA-GZRS for zone + geo redundancy

### Security & Best Practices
7. **DO NOT** hardcode any values - use variables
8. **DO NOT** use service principals with secrets - use managed identities
9. **DO NOT** enable public access on any PaaS service
10. **DO NOT** use shared access keys - use RBAC
11. **DO** use private endpoints for ALL PaaS services
12. **DO** configure diagnostic settings for ALL resources
13. **DO** use customer-managed keys where supported
14. **DO** implement proper dependency management between modules
15. **DO** include proper resource tagging

---

## 📊 Success Criteria

The implementation is successful when:

### 🔴 Multi-Zone Verification (CRITICAL)
- [ ] **APIM**: Deployed with 2+ units across zones [1, 2, 3] in EACH region
- [ ] **App Service Plan**: `zone_balancing_enabled = true` with 3+ instances in EACH region
- [ ] **Function App Plan**: Zone redundancy enabled in EACH region
- [ ] **SQL MI**: `zone_redundant = true` (Business Critical tier) in EACH region
- [ ] **Redis Cache**: Deployed across zones [1, 2, 3] in EACH region
- [ ] **Storage Accounts**: Using RAGZRS (zone-redundant + geo-redundant)

### 🔴 Multi-Region Verification (CRITICAL)
- [ ] **Primary Region (East US 2)**: All components deployed and functional
- [ ] **Secondary Region (Central US)**: All components deployed and functional
- [ ] **Front Door**: Routes traffic to BOTH regions simultaneously (Active-Active)
- [ ] **SQL MI Failover Group**: Configured with auto-failover (grace period = 60 min)
  - [ ] Primary instance (East US 2) accepts READ + WRITE
  - [ ] Secondary instance (Central US) accepts READ ONLY
  - [ ] Listener endpoints resolve correctly
  - [ ] Test manual failover completes within RTO (1 hour)
- [ ] **Redis Geo-Replication**: Primary linked to secondary for replication
- [ ] **VNet Peering**: Global peering established between regions

### 🔴 SQL MI Specific Verification
- [ ] Both SQL MI instances are **Business Critical** tier
- [ ] Both SQL MI instances have `zone_redundant = true`
- [ ] Same DNS zone ID is used for both instances
- [ ] Failover group is created with customer-managed policy
- [ ] Read-write listener endpoint: `<fog-name>.<zone>.database.windows.net`
- [ ] Read-only listener endpoint: `<fog-name>.secondary.<zone>.database.windows.net`
- [ ] NSG rules allow ports 5022 and 11000-11999 between regions
- [ ] VNet address spaces do NOT overlap between regions

### General Requirements
- [ ] All resources deploy without errors in a greenfield subscription
- [ ] All services use managed identities (no secrets)
- [ ] All services use private endpoints (no public access)
- [ ] WAF is enabled and in prevention mode
- [ ] Monitoring and alerting is configured
- [ ] **RTO < 1 hour** can be demonstrated (test failover)
- [ ] **RPO < 4 hours** can be demonstrated (verify backup/replication lag)

---

## 🔗 Reference Documentation

- [Azure Well-Architected Framework - Reliability Pillar](https://learn.microsoft.com/azure/well-architected/reliability/)
- [Azure Availability Zones](https://learn.microsoft.com/azure/reliability/availability-zones-overview)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Naming Conventions](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming)
- [Azure Private Endpoints](https://learn.microsoft.com/azure/private-link/private-endpoint-overview)

---

*This prompt is designed to be used with any LLM/AI Agent to generate a complete Terraform implementation for Azure resilient infrastructure.*
