#--------------------------------------------------------------
# Production Environment - Variable Definitions
#--------------------------------------------------------------

#--------------------------------------------------------------
# General Configuration
#--------------------------------------------------------------

variable "project_name" {
  description = "Name of the project, used in resource naming"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.project_name))
    error_message = "Project name must be 3-20 characters, lowercase alphanumeric with hyphens."
  }
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

#--------------------------------------------------------------
# Regional Configuration
#--------------------------------------------------------------

variable "primary_location" {
  description = "Primary Azure region for deployment"
  type        = string
  default     = "eastus2"

  validation {
    condition     = contains(["eastus", "eastus2", "westus", "westus2", "centralus", "northeurope", "westeurope", "centralindia", "southindia", "westindia", "southeastasia", "eastasia"], var.primary_location)
    error_message = "Primary location must be a supported Azure region."
  }
}

variable "secondary_location" {
  description = "Secondary Azure region for disaster recovery"
  type        = string
  default     = "centralus"

  validation {
    condition     = contains(["eastus", "eastus2", "westus", "westus2", "centralus", "northeurope", "westeurope", "centralindia", "southindia", "westindia", "southeastasia", "eastasia"], var.secondary_location)
    error_message = "Secondary location must be a supported Azure region."
  }
}

#--------------------------------------------------------------
# Networking Configuration
#--------------------------------------------------------------

variable "vnet_address_space_primary" {
  description = "Address space for primary region VNet"
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

variable "vnet_address_space_secondary" {
  description = "Address space for secondary region VNet"
  type        = list(string)
  default     = ["10.2.0.0/16"]
}

variable "enable_vnet_peering" {
  description = "Enable VNet peering between primary and secondary regions"
  type        = bool
  default     = true
}

#--------------------------------------------------------------
# SQL Managed Instance Configuration
#--------------------------------------------------------------

variable "sql_mi_sku_name" {
  description = "SKU name for SQL Managed Instance"
  type        = string
  default     = "BC_Gen5" # Business Critical for production with zone redundancy

  validation {
    condition     = can(regex("^(GP_Gen5|BC_Gen5|GP_G8IM|GP_G8IH|BC_G8IM|BC_G8IH)$", var.sql_mi_sku_name))
    error_message = "SQL MI SKU must be a valid SKU name."
  }
}

variable "sql_mi_license_type" {
  description = "License type for SQL Managed Instance"
  type        = string
  default     = "BasePrice"

  validation {
    condition     = contains(["LicenseIncluded", "BasePrice"], var.sql_mi_license_type)
    error_message = "License type must be LicenseIncluded or BasePrice."
  }
}

variable "sql_mi_vcores" {
  description = "Number of vCores for SQL Managed Instance"
  type        = number
  default     = 4

  validation {
    condition     = contains([4, 8, 16, 24, 32, 40, 64, 80], var.sql_mi_vcores)
    error_message = "vCores must be one of: 4, 8, 16, 24, 32, 40, 64, 80."
  }
}

variable "sql_mi_storage_size_gb" {
  description = "Storage size in GB for SQL Managed Instance"
  type        = number
  default     = 256

  validation {
    condition     = var.sql_mi_storage_size_gb >= 32 && var.sql_mi_storage_size_gb <= 16384
    error_message = "Storage size must be between 32 and 16384 GB."
  }
}

variable "sql_mi_administrator_login" {
  description = "Administrator login for SQL Managed Instance"
  type        = string
  sensitive   = true
}

variable "sql_mi_administrator_password" {
  description = "Administrator password for SQL Managed Instance"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.sql_mi_administrator_password) >= 16
    error_message = "Administrator password must be at least 16 characters."
  }
}

variable "sql_mi_failover_grace_period_minutes" {
  description = "Grace period in minutes before failover for SQL MI failover group"
  type        = number
  default     = 60

  validation {
    condition     = var.sql_mi_failover_grace_period_minutes >= 60
    error_message = "Failover grace period must be at least 60 minutes."
  }
}

#--------------------------------------------------------------
# App Service Configuration
#--------------------------------------------------------------

variable "app_service_sku" {
  description = "SKU for App Service Plan"
  type        = string
  default     = "P1v3"

  validation {
    condition     = can(regex("^(P[1-3]v[2-4]|S[1-3]|B[1-3]|F1)$", var.app_service_sku))
    error_message = "App Service SKU must be Premium v2/v3 or Standard for zone redundancy."
  }
}

variable "app_service_instance_count" {
  description = "Number of instances for App Service (minimum 3 for zone redundancy)"
  type        = number
  default     = 3

  validation {
    condition     = var.app_service_instance_count >= 1
    error_message = "Instance count should be at least 3 for zone redundancy, but can be lower for POC."
  }
}

variable "app_service_max_instances" {
  description = "Maximum number of instances for App Service autoscaling"
  type        = number
  default     = 10
}

variable "app_service_dotnet_version" {
  description = ".NET version for App Service"
  type        = string
  default     = "v8.0"
}

#--------------------------------------------------------------
# Function App Configuration
#--------------------------------------------------------------

variable "function_app_sku" {
  description = "SKU for Function App (Elastic Premium)"
  type        = string
  default     = "EP2"

  validation {
    condition     = can(regex("^(EP[1-3]|Y1|S[1-3]|P[1-3]v[2-4])$", var.function_app_sku))
    error_message = "Function App SKU should be EP1, EP2, or EP3 for zone redundancy. Y1 (Consumption) available for POC."
  }
}

variable "function_app_max_instances" {
  description = "Maximum elastic worker count for Function App"
  type        = number
  default     = 20
}

variable "function_runtime" {
  description = "Runtime for Function App"
  type        = string
  default     = "dotnet-isolated"

  validation {
    condition     = contains(["dotnet", "dotnet-isolated", "node", "python", "java", "powershell"], var.function_runtime)
    error_message = "Function runtime must be a supported runtime."
  }
}

variable "function_runtime_version" {
  description = "Runtime version for Function App"
  type        = string
  default     = "8.0"
}

#--------------------------------------------------------------
# API Management Configuration
#--------------------------------------------------------------

variable "apim_sku_name" {
  description = "SKU name for API Management"
  type        = string
  default     = "Premium"

  validation {
    condition     = contains(["Premium", "Developer", "Standard", "Basic"], var.apim_sku_name)
    error_message = "APIM SKU should be Premium for zone redundancy. Developer tier available for POC."
  }
}

variable "apim_sku_capacity" {
  description = "Number of units for API Management (minimum 2 for zone redundancy)"
  type        = number
  default     = 2

  validation {
    condition     = var.apim_sku_capacity >= 1
    error_message = "APIM capacity should be at least 2 for zone redundancy. 1 unit available for POC."
  }
}

variable "apim_publisher_name" {
  description = "Publisher name for API Management"
  type        = string
}

variable "apim_publisher_email" {
  description = "Publisher email for API Management"
  type        = string
}

#--------------------------------------------------------------
# Redis Cache Configuration
#--------------------------------------------------------------

variable "redis_sku_name" {
  description = "SKU name for Redis Cache"
  type        = string
  default     = "Premium"

  validation {
    condition     = var.redis_sku_name == "Premium"
    error_message = "Redis SKU must be Premium for zone redundancy."
  }
}

variable "redis_family" {
  description = "Family for Redis Cache"
  type        = string
  default     = "P"
}

variable "redis_capacity" {
  description = "Capacity for Redis Cache"
  type        = number
  default     = 1

  validation {
    condition     = var.redis_capacity >= 1 && var.redis_capacity <= 6
    error_message = "Redis capacity must be between 1 and 6 for Premium."
  }
}

variable "redis_enable_geo_replication" {
  description = "Enable geo-replication for Redis Cache"
  type        = bool
  default     = true
}

#--------------------------------------------------------------
# Storage Account Configuration
#--------------------------------------------------------------

variable "storage_account_tier" {
  description = "Account tier for Storage Account"
  type        = string
  default     = "Standard"
}

variable "storage_account_replication_type" {
  description = "Replication type for Storage Account"
  type        = string
  default     = "RAGZRS"

  validation {
    condition     = contains(["RAGZRS", "GZRS", "ZRS", "GRS", "LRS"], var.storage_account_replication_type)
    error_message = "Storage replication should be RAGZRS for full resilience. GRS available for POC."
  }
}

#--------------------------------------------------------------
# Key Vault Configuration
#--------------------------------------------------------------

variable "key_vault_sku_name" {
  description = "SKU name for Key Vault"
  type        = string
  default     = "premium"

  validation {
    condition     = contains(["standard", "premium"], var.key_vault_sku_name)
    error_message = "Key Vault SKU must be standard or premium."
  }
}

variable "key_vault_soft_delete_retention_days" {
  description = "Soft delete retention days for Key Vault"
  type        = number
  default     = 90

  validation {
    condition     = var.key_vault_soft_delete_retention_days >= 7 && var.key_vault_soft_delete_retention_days <= 90
    error_message = "Soft delete retention must be between 7 and 90 days."
  }
}

#--------------------------------------------------------------
# Front Door Configuration
#--------------------------------------------------------------

variable "frontdoor_sku_name" {
  description = "SKU name for Front Door"
  type        = string
  default     = "Premium_AzureFrontDoor"

  validation {
    condition     = contains(["Standard_AzureFrontDoor", "Premium_AzureFrontDoor"], var.frontdoor_sku_name)
    error_message = "Front Door SKU must be Standard or Premium."
  }
}

variable "waf_mode" {
  description = "WAF mode for Front Door"
  type        = string
  default     = "Prevention"

  validation {
    condition     = contains(["Detection", "Prevention"], var.waf_mode)
    error_message = "WAF mode must be Detection or Prevention."
  }
}

#--------------------------------------------------------------
# Monitoring Configuration
#--------------------------------------------------------------

variable "log_analytics_retention_days" {
  description = "Data retention in days for Log Analytics"
  type        = number
  default     = 90

  validation {
    condition     = var.log_analytics_retention_days >= 30 && var.log_analytics_retention_days <= 730
    error_message = "Log Analytics retention must be between 30 and 730 days."
  }
}

variable "alert_email_addresses" {
  description = "Email addresses for alert notifications"
  type        = list(string)
  default     = []
}

#--------------------------------------------------------------
# Security Configuration
#--------------------------------------------------------------

variable "enable_private_endpoints" {
  description = "Enable private endpoints for all PaaS services"
  type        = bool
  default     = true
}

variable "allowed_ip_ranges" {
  description = "IP ranges allowed through WAF (for management access)"
  type        = list(string)
  default     = []
}

variable "minimum_tls_version" {
  description = "Minimum TLS version for services"
  type        = string
  default     = "1.2"

  validation {
    condition     = contains(["1.2", "1.3"], var.minimum_tls_version)
    error_message = "Minimum TLS version must be 1.2 or 1.3."
  }
}

variable "enable_sql_mi" {
  description = "Enable SQL Managed Instance deployment (disable if policy restrictions)"
  type        = bool
  default     = true
}

variable "enable_sql_mi_secondary" {
  description = "Enable secondary SQL MI deployment (disable to save vCore quota)"
  type        = bool
  default     = true
}

variable "create_sql_mi_failover_group" {
  description = "Create SQL MI failover group (set to true only after both SQL MIs are deployed)"
  type        = bool
  default     = false
}

variable "enable_storage" {
  description = "Enable Storage Account deployment (disable if policy blocks key-based auth)"
  type        = bool
  default     = true
}
#--------------------------------------------------------------
# SQL MI Azure AD Authentication
#--------------------------------------------------------------
variable "sql_mi_azure_ad_admin_login" {
  description = "Azure AD administrator login name for SQL MI"
  type        = string
  default     = "admin@MngEnvMCAP245137.onmicrosoft.com"
}

variable "sql_mi_azure_ad_admin_object_id" {
  description = "Azure AD administrator object ID for SQL MI"
  type        = string
  default     = "941f59fd-aeb5-4ba2-9fb9-2f5132d15500"
}

variable "sql_mi_azure_ad_admin_tenant_id" {
  description = "Azure AD tenant ID for SQL MI"
  type        = string
  default     = "6021aa37-5a44-450a-8854-f08245985be2"
}

variable "sql_mi_azuread_authentication_only" {
  description = "Enable Azure AD authentication only (disable SQL auth)"
  type        = bool
  default     = true
}

variable "enable_function_apps" {
  description = "Enable Function App deployment (disable if Storage is disabled)"
  type        = bool
  default     = true
}

#--------------------------------------------------------------
# Automated DR Failover Configuration
#--------------------------------------------------------------

variable "enable_automated_failover" {
  description = "Enable Azure Automation for automated DR failover triggered by alerts"
  type        = bool
  default     = false
}

variable "enable_redis" {
  description = "Enable Redis Cache deployment"
  type        = bool
  default     = true
}

variable "enable_front_door" {
  description = "Enable Azure Front Door deployment"
  type        = bool
  default     = true
}

variable "subscription_id" {
  description = "Azure subscription ID (used for activity log alert scopes)"
  type        = string
  default     = ""
}

#--------------------------------------------------------------
# Secondary Region Zone Configuration
#--------------------------------------------------------------

variable "secondary_zone_redundant" {
  description = "Enable zone redundancy in secondary region. Set to false for regions without AZ support (e.g., West US)"
  type        = bool
  default     = false
}

variable "sql_mi_secondary_zone_redundant" {
  description = "Enable zone redundancy for SQL MI in secondary region. May need to be disabled separately if SQL MI zone redundancy is not available."
  type        = bool
  default     = null # When null, falls back to secondary_zone_redundant
}

variable "secondary_storage_replication_type" {
  description = "Storage replication type for secondary region. Use GRS/LRS for regions without AZ support (e.g., West US)"
  type        = string
  default     = "GRS" # Geo-redundant storage (no zone redundancy required)

  validation {
    condition     = contains(["RAGZRS", "GZRS", "ZRS", "GRS", "RAGRS", "LRS"], var.secondary_storage_replication_type)
    error_message = "Secondary storage replication should be GRS or LRS for regions without AZ support."
  }
}


