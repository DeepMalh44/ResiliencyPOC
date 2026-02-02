# Azure Resilient Infrastructure - Terraform Implementation

## 🎯 Overview

This Terraform implementation deploys a highly resilient, multi-zone, multi-region Azure infrastructure as a Proof of Concept (POC) for enterprise resiliency.

### Resiliency Targets

| Metric | Target | Description |
|--------|--------|-------------|
| **RTO** | 1 hour | Recovery Time Objective - Maximum acceptable downtime |
| **RPO** | 4 hours | Recovery Point Objective - Maximum acceptable data loss |
| **Availability** | 99.99% | Target SLA with multi-region deployment |

## 📋 Key Features

- **Multi-Zone Deployment**: All services deployed across 3 availability zones
- **Multi-Region Deployment**: Active-Active configuration across East US 2 and Central US (Azure Paired Regions)
- **Security First**: Private endpoints, managed identities, no public access
- **Infrastructure as Code**: Fully parameterized, no hardcoded values
- **Data Replication**: SQL MI Failover Groups, Redis Geo-Replication, RA-GZRS Storage

## 🏗️ Architecture

> **📊 Detailed Architecture Diagram**: See [Diagrams/pocapp_architecture.drawio](Diagrams/pocapp_architecture.drawio) for the full visual architecture with Azure icons. Open with [Draw.io](https://app.diagrams.net) or VS Code Draw.io extension.

```
                              ┌─────────────────┐
                              │     Users       │
                              └────────┬────────┘
                                       │
                              ┌────────▼────────┐
                              │  Azure Front    │
                              │  Door Premium   │
                              │  (Global + WAF) │
                              └────────┬────────┘
                                       │
              ┌────────────────────────┴─────────────────────────┐
              │ 50%                                         50%  │
              ▼                                                  ▼
┌─────────────────────────────────┐       ┌─────────────────────────────────┐
│   PRIMARY REGION                │       │   SECONDARY REGION              │
│   East US 2                     │       │   Central US                    │
│   VNet: 10.1.0.0/16             │       │   VNet: 10.2.0.0/16             │
├─────────────────────────────────┤       ├─────────────────────────────────┤
│  App Service (P1v3 x 3, ZR)     │       │  App Service (P1v3 x 3, ZR)     │
│  Function App (EP2, ZR)         │       │  Function App (EP2, ZR)         │
│  API Management (Premium x 2)   │◄─────►│  API Management (Secondary)     │
│  SQL MI (Business Critical)     │◄═════►│  SQL MI (Failover Replica)      │
│  Redis (Premium P1, ZR)         │◄─────►│  Redis (Geo-Replica)            │
│  Storage (RA-GZRS)              │◄─────►│  Storage (RA-GZRS)              │
│  Key Vault (Premium, RBAC)      │       │  Key Vault (Premium, RBAC)      │
│  Private Endpoints              │       │  Private Endpoints              │
└─────────────────────────────────┘       └─────────────────────────────────┘
              │                                         │
              └────────────────┬────────────────────────┘
                               │ VNet Peering
                      ┌────────▼────────┐
                      │  Private DNS    │
                      │  Zones          │
                      └─────────────────┘

Legend: ═══ Failover Group │ ─── Geo-Replication │ ZR = Zone Redundant
```

## 📁 Project Structure

```
terraform/
├── Diagrams/
│   └── pocapp_architecture.drawio   # Visual architecture diagram (Draw.io)
├── modules/
│   ├── apim/                # API Management Premium (multi-region)
│   ├── app-service/         # App Service + Deployment Slots
│   ├── front-door/          # Azure Front Door Premium + WAF
│   ├── function-app/        # Function Apps Elastic Premium
│   ├── key-vault/           # Azure Key Vault with RBAC
│   ├── monitoring/          # Log Analytics + App Insights + Alerts
│   ├── networking/          # VNets, Subnets, NSGs, VNet Peering
│   ├── private-endpoint/    # Reusable private endpoint module
│   ├── redis/               # Redis Cache Premium + Geo-Replication
│   ├── resource-group/      # Resource group management
│   ├── sql-mi/              # SQL Managed Instance + Failover Groups
│   └── storage/             # Storage Accounts (RA-GZRS)
├── environments/
│   └── prod/
│       ├── main.tf          # Root module - orchestrates all modules
│       ├── providers.tf     # Provider configuration (AzureRM ~> 3.80)
│       ├── variables.tf     # Variable declarations
│       ├── terraform.tfvars # Environment-specific values
│       ├── outputs.tf       # Output values
│       └── locals.tf        # Local values and computed expressions
└── README.md                # This file
```

## 🚀 Quick Start

### Prerequisites

1. [Terraform](https://www.terraform.io/downloads.html) >= 1.5.0
2. [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) >= 2.50.0
3. Azure subscription with required permissions
4. Sufficient quota for Premium tier resources

### Deployment Steps

```bash
# 1. Login to Azure
az login

# 2. Set subscription
az account set --subscription "<subscription-id>"

# 3. Navigate to environment
cd terraform/environments/prod

# 4. Set sensitive variables via environment variables
export TF_VAR_sql_mi_administrator_login="sqladmin"
export TF_VAR_sql_mi_administrator_password="YourSecurePassword123!"

# 5. Initialize Terraform
terraform init

# 6. Validate configuration
terraform validate

# 7. Plan deployment (review carefully!)
terraform plan -out=tfplan

# 8. Apply deployment
terraform apply tfplan
```

### Remote State Setup (Recommended for Production)

```bash
# Create storage account for state
az group create -n rg-terraform-state -l eastus2
az storage account create -n stterraformstate -g rg-terraform-state -l eastus2 --sku Standard_LRS
az storage container create -n tfstate --account-name stterraformstate

# Uncomment backend configuration in providers.tf
```

### Deployment Time Estimates

| Resource | Approximate Time |
|----------|------------------|
| SQL Managed Instance | 4-6 hours (per instance) |
| API Management Premium | 30-45 minutes |
| VNet Peering | 2-5 minutes |
| Other resources | 5-15 minutes each |

**Total estimated time: 8-12 hours** (mainly due to SQL MI)

## ⚙️ Configuration

### Required Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `project_name` | Project name for resource naming | `pocapp` |
| `environment` | Environment name | `prod` |
| `primary_location` | Primary Azure region | `eastus2` |
| `secondary_location` | Secondary Azure region | `centralus` |

### Network Configuration

| Region | VNet CIDR | Subnets |
|--------|-----------|---------|
| East US 2 (Primary) | 10.1.0.0/16 | appservice, functionapp, apim, privateendpoints, sqlmi, redis |
| Central US (Secondary) | 10.2.0.0/16 | appservice, functionapp, apim, privateendpoints, sqlmi, redis |

### Customization

Override defaults in `terraform.tfvars`:

```hcl
project_name       = "myproject"
environment        = "prod"
primary_location   = "eastus2"
secondary_location = "centralus"
```

## 🔒 Security Features

| Feature | Implementation |
|---------|----------------|
| **Identity** | Managed Identities for all compute services |
| **Network** | Private Endpoints for all PaaS services, no public access |
| **Authentication** | Azure AD/Entra ID integration |
| **Encryption** | TLS 1.2 minimum, Key Vault for secrets |
| **WAF** | Azure Front Door WAF in Prevention mode |
| **Authorization** | Key Vault RBAC, SQL MI AD auth |

## 📊 Resiliency Features

| Component | Primary Region | Secondary Region | Replication |
|-----------|----------------|------------------|-------------|
| **Web App** | P1v3 x 3 (Zone Redundant) | P1v3 x 3 (Zone Redundant) | Active-Active via Front Door |
| **Function App** | Elastic Premium EP2 | Elastic Premium EP2 | Active-Active via Front Door |
| **API Management** | Premium 2 units (ZR) | Premium Secondary | Multi-region deployment |
| **SQL MI** | Business Critical (ZR) | Business Critical | Failover Group (60 min grace) |
| **Redis Cache** | Premium P1 (ZR) | Premium P1 | Geo-Replication |
| **Storage** | RA-GZRS | RA-GZRS | Built-in Geo-Redundancy |
| **Key Vault** | Premium + RBAC | Premium + RBAC | Independent (config sync) |

## 🔍 Monitoring & Alerting

- **Log Analytics Workspace**: Centralized logging for all resources
- **Application Insights**: APM for App Services and Function Apps
- **Metric Alerts**: CPU, Memory, Response Time thresholds
- **Action Groups**: Email notifications for critical alerts

## 📝 Files Reference

| File | Description |
|------|-------------|
| `Diagrams/pocapp_architecture.drawio` | Visual architecture diagram with Azure icons |
| `environments/prod/main.tf` | Main orchestration file with all module calls |
| `environments/prod/terraform.tfvars` | Environment-specific variable values |
| `modules/*/` | Reusable Terraform modules for each Azure service |

## 🛠️ Maintenance

### Validate Changes

```bash
cd terraform/environments/prod
terraform validate
terraform plan
```

### Update Modules

After modifying any module, re-initialize:

```bash
terraform init -upgrade
```

## 📜 License

This project is provided as-is for POC purposes.
