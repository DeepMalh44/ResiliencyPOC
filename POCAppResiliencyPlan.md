# 🏗️ Azure Resilience Plan for Your Architecture

Based on the architecture diagram analysis, this document outlines a comprehensive resilience plan for transforming a single-region deployment into a highly available, multi-zone and multi-region architecture.

---

## 📋 Confirmed Requirements

| Requirement | Confirmed Value |
|-------------|-----------------|
| **RTO (Recovery Time Objective)** | Maximum **1 hour** |
| **RPO (Recovery Point Objective)** | Maximum **4 hours** from disaster point |
| **Budget** | **Not a constraint** - resiliency is the priority |
| **Primary Region** | South Central US |
| **Secondary Region** | **Central US** |
| **APIM Tier** | **Premium** (already in place) |
| **Deployment Model** | **Active-Active** (both regions serve traffic) |
| **Environment** | **Greenfield** - nothing exists |
| **Authentication** | **Managed Identities** wherever possible |
| **Security** | Maximum security with private endpoints |

### Key POC Objectives
- ✅ Demonstrate **Multi-Zone** redundancy within each region
- ✅ Demonstrate **Multi-Region** deployment for disaster recovery
- ✅ Infrastructure-only deployment (no application code)
- ✅ Fully parameterized Terraform (no hardcoded values)

---

## 🗺️ Current Architecture Summary

| Component | Current State |
|-----------|--------------|
| **Azure Front Door** | Single endpoint (services dev.roofhub.pro, sns-broker-prod.azurefd.net) |
| **API Management** | IntHub-PRD-SCUS - Single region |
| **App Services** | EPI/CMS Site, Broker API (North Central, South Central) |
| **Azure Functions** | Data Maintenance & Queue Monitoring (multiple functions) |
| **Storage Accounts** | snsbrokerstorage - likely LRS |
| **SQL** | CMS Content DB, RH SQL DB, FlatterM1 - SQL Managed Instance |
| **External** | Optimizely CMS, Cloudflare |

---

## 🎯 Proposed Resilience Architecture Plan

### **Phase 1: Zone Redundancy (Multi-Zone within Region)**

This provides **99.99% SLA** and protects against datacenter failures within a region.

| Component | Current | Resilient Configuration |
|-----------|---------|------------------------|
| **APIM** | Single instance | Enable **Zone Redundancy** with 2+ units across availability zones |
| **App Services** | Single instance | Deploy on **Zone-Redundant App Service Plan** (Premium v3) |
| **Function Apps** | Single instance | Use **Zone-Redundant Premium/Elastic Premium Plan** |
| **Storage Accounts** | LRS | Upgrade to **ZRS** (Zone-Redundant Storage) |
| **SQL Managed Instance** | Single zone | Enable **Zone Redundancy** (Business Critical tier) |

### **Phase 2: Multi-Region Deployment (Disaster Recovery)**

This provides **99.999% availability** and protects against regional failures.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          AZURE FRONT DOOR (Global)                          │
│                     ┌─────────────────────────────────┐                     │
│                     │  Global Load Balancing & WAF    │                     │
│                     │  Health Probes & Auto-Failover  │                     │
│                     └────────────┬────────────────────┘                     │
└──────────────────────────────────┼──────────────────────────────────────────┘
                                   │
              ┌────────────────────┴────────────────────┐
              │                                         │
              ▼                                         ▼
┌─────────────────────────────┐         ┌─────────────────────────────┐
│   PRIMARY REGION            │         │   SECONDARY REGION          │
│   (e.g., South Central US)  │         │   (e.g., North Central US)  │
├─────────────────────────────┤         ├─────────────────────────────┤
│                             │         │                             │
│  ┌─────────────────────┐    │         │  ┌─────────────────────┐    │
│  │   APIM (Premium)    │    │         │  │   APIM (Premium)    │    │
│  │   Zone Redundant    │    │         │  │   Zone Redundant    │    │
│  │   2+ Units          │    │         │  │   2+ Units          │    │
│  └──────────┬──────────┘    │         │  └──────────┬──────────┘    │
│             │               │         │             │               │
│  ┌──────────▼──────────┐    │         │  ┌──────────▼──────────┐    │
│  │    App Services     │    │         │  │    App Services     │    │
│  │  (Zone Redundant)   │    │         │  │  (Zone Redundant)   │    │
│  │  - Broker API       │    │         │  │  - Broker API       │    │
│  │  - EPI/CMS Site     │    │         │  │  - EPI/CMS Site     │    │
│  └──────────┬──────────┘    │         │  └──────────┬──────────┘    │
│             │               │         │             │               │
│  ┌──────────▼──────────┐    │         │  ┌──────────▼──────────┐    │
│  │   Function Apps     │    │         │  │   Function Apps     │    │
│  │  (Zone Redundant)   │    │         │  │  (Zone Redundant)   │    │
│  │  - Data Updater     │    │         │  │  - Data Updater     │    │
│  │  - Index Updater    │    │         │  │  - Index Updater    │    │
│  │  - Product Catalog  │    │         │  │  - Product Catalog  │    │
│  └──────────┬──────────┘    │         │  └──────────┬──────────┘    │
│             │               │         │             │               │
│  ┌──────────▼──────────┐    │         │  ┌──────────▼──────────┐    │
│  │  Storage Account    │◄───┼─────────┼──►  Storage Account    │    │
│  │  (RA-GZRS)          │    │  Async  │  │  (Read Replica)     │    │
│  └─────────────────────┘    │  Repl.  │  └─────────────────────┘    │
│                             │         │                             │
│  ┌─────────────────────┐    │         │  ┌─────────────────────┐    │
│  │ SQL Managed Instance│◄───┼─────────┼──► SQL Managed Instance│    │
│  │ (Primary - BC Tier) │    │ Failover│  │ (Secondary - DR)    │    │
│  │  Zone Redundant     │    │  Group  │  │  Zone Redundant     │    │
│  └─────────────────────┘    │         │  └─────────────────────┘    │
│                             │         │                             │
└─────────────────────────────┘         └─────────────────────────────┘
```

---

## 📦 Detailed Component Plan

### 1. Azure Front Door

| Aspect | Configuration |
|--------|--------------|
| **Purpose** | Global load balancing, WAF, SSL termination |
| **Backend Pools** | Primary + Secondary region origins |
| **Health Probes** | Configure health probes to each backend |
| **Routing Rules** | Priority-based or weighted routing |
| **Caching** | Enable caching for static content |

### 2. API Management (APIM)

| Aspect | Configuration |
|--------|--------------|
| **Tier** | **Premium** (required for multi-region) |
| **Zone Redundancy** | Enable with minimum 2 units per region |
| **Multi-Region** | Deploy to primary + secondary region |
| **External Cache** | Azure Cache for Redis (Premium with zone redundancy) |

### 3. App Services

| Aspect | Configuration |
|--------|--------------|
| **Plan** | Premium v3 or Isolated v2 |
| **Zone Redundancy** | Enable (requires 3+ instances) |
| **Deployment Slots** | Use for zero-downtime deployments |
| **Auto-Scale** | Configure for both regions |
| **Multi-Region** | Deploy identical apps to secondary region |

### 4. Azure Functions

| Aspect | Configuration |
|--------|--------------|
| **Plan** | Premium (Elastic Premium) or Dedicated |
| **Zone Redundancy** | Enable zone redundancy |
| **Multi-Region** | Deploy to secondary region |
| **Durable Functions** | Use Task Hub per region with geo-replicated storage |

### 5. Storage Accounts

| Aspect | Configuration |
|--------|--------------|
| **Redundancy** | **RA-GZRS** (Read-Access Geo-Zone-Redundant Storage) |
| **Primary Region** | ZRS within region |
| **Secondary Region** | Automatic async replication with read access |
| **Failover** | Customer-managed failover capability |

### 6. SQL Managed Instance

| Aspect | Configuration |
|--------|--------------|
| **Tier** | **Business Critical** (required for zone redundancy) |
| **Zone Redundancy** | Enable in both regions |
| **Failover Groups** | Configure auto-failover group between regions |
| **Read Replicas** | Use secondary for read workloads |
| **RPO** | ~5 seconds with async replication |

---

## 🔧 Terraform Implementation Structure

```
terraform/
├── modules/
│   ├── front-door/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── apim/
│   │   ├── main.tf          # Multi-region APIM
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── app-service/
│   │   ├── main.tf          # Zone-redundant App Service
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── function-app/
│   │   ├── main.tf          # Zone-redundant Functions
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── storage/
│   │   ├── main.tf          # RA-GZRS Storage
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── sql-mi/
│   │   ├── main.tf          # SQL MI with Failover Groups
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── networking/
│       ├── main.tf          # VNets, Subnets, Private Endpoints
│       ├── variables.tf
│       └── outputs.tf
├── environments/
│   ├── prod/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   └── dr/
│       ├── main.tf
│       ├── variables.tf
│       └── terraform.tfvars
├── shared/
│   ├── resource-group.tf
│   ├── key-vault.tf
│   └── monitoring.tf
└── README.md
```

### Key Terraform Considerations

| Aspect | Recommendation |
|--------|---------------|
| **State Management** | Use Azure Storage with GZRS for state files |
| **Provider Aliases** | Use provider aliases for multi-region deployments |
| **Workspaces** | Consider workspaces for environment separation |
| **Modules** | Create reusable modules for each component |
| **Variables** | Parameterize regions, SKUs, and replica counts |

---

## 📊 Cost Implications

| Component | Cost Impact |
|-----------|-------------|
| **APIM Premium** | Significant increase (~$2,800/unit/month) |
| **App Service Premium v3** | ~2x current cost |
| **SQL MI Business Critical** | ~2x General Purpose |
| **Storage RA-GZRS** | ~2x LRS cost |
| **Azure Front Door Premium** | Additional cost for WAF |
| **Multi-Region** | ~2x infrastructure (standby can be scaled down) |

---

## 🚀 Implementation Phases

| Phase | Duration | Components |
|-------|----------|------------|
| **Phase 1** | 2-3 weeks | Zone redundancy for all components in primary region |
| **Phase 2** | 3-4 weeks | Multi-region deployment (secondary region) |
| **Phase 3** | 2 weeks | Failover groups, Front Door configuration |
| **Phase 4** | 1-2 weeks | Testing, DR drills, documentation |

---

## 📚 Azure Documentation References

### High Availability & Zone Redundancy
- [Azure SQL Managed Instance - Business Continuity Overview](https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/business-continuity-high-availability-disaster-recover-hadr-overview)
- [Enable Zone Redundancy for APIM](https://learn.microsoft.com/en-us/azure/api-management/enable-availability-zone-support)
- [APIM Multi-Region Deployment](https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-deploy-multi-region)
- [Azure Storage Redundancy Options](https://learn.microsoft.com/en-us/azure/storage/common/storage-redundancy)
- [Multi-Region App Service Approaches](https://learn.microsoft.com/en-us/azure/architecture/web-apps/guides/multi-region-app-service/multi-region-app-service)

### Disaster Recovery
- [SQL MI Disaster Recovery Guidance](https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/disaster-recovery-guidance)
- [SQL MI Failover Groups](https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/failover-group-sql-mi)
- [SQL MI HA/DR Checklist](https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/high-availability-disaster-recovery-checklist)

### Terraform Best Practices
- [HashiCorp Terraform Style Guide](https://developer.hashicorp.com/terraform/language/style)
- Use `terraform validate` before `terraform plan`
- Use `terraform apply -auto-approve` only after validation

---

## ❓ Next Steps

1. ✅ Requirements confirmed - see above
2. ✅ Comprehensive LLM prompt created - see `POCAppResiliencyTerraformPrompt.md`
3. ⏳ **Next**: Use the prompt to generate Terraform implementation

---

## 📄 Related Documents

- **LLM Prompt for Implementation**: [POCAppResiliencyTerraformPrompt.md](./POCAppResiliencyTerraformPrompt.md)

---

*Document created: January 30, 2026*
*Last updated: January 31, 2026*
