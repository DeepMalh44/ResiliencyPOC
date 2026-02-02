#--------------------------------------------------------------
# Production Environment - Outputs
#--------------------------------------------------------------

#--------------------------------------------------------------
# Resource Group Outputs
#--------------------------------------------------------------

output "resource_groups" {
  description = "Resource group information for both regions"
  value = {
    primary = {
      id       = module.resource_group_primary.id
      name     = module.resource_group_primary.name
      location = module.resource_group_primary.location
    }
    secondary = {
      id       = module.resource_group_secondary.id
      name     = module.resource_group_secondary.name
      location = module.resource_group_secondary.location
    }
  }
}

#--------------------------------------------------------------
# Networking Outputs
#--------------------------------------------------------------

output "networking" {
  description = "Virtual network information for both regions"
  value = {
    primary = {
      vnet_id     = module.networking_primary.vnet_id
      vnet_name   = module.networking_primary.vnet_name
      subnet_ids  = module.networking_primary.subnet_ids
    }
    secondary = {
      vnet_id     = module.networking_secondary.vnet_id
      vnet_name   = module.networking_secondary.vnet_name
      subnet_ids  = module.networking_secondary.subnet_ids
    }
  }
}

#--------------------------------------------------------------
# Front Door Outputs
#--------------------------------------------------------------

output "front_door" {
  description = "Azure Front Door information"
  value = {
    profile_id = module.front_door.profile_id
    endpoints  = module.front_door.endpoints
  }
}

#--------------------------------------------------------------
# App Service Outputs
#--------------------------------------------------------------

output "app_services" {
  description = "App Service information for both regions"
  value = {
    primary = {
      id               = module.app_service_primary.id
      name             = module.app_service_primary.name
      default_hostname = module.app_service_primary.default_hostname
    }
    secondary = {
      id               = module.app_service_secondary.id
      name             = module.app_service_secondary.name
      default_hostname = module.app_service_secondary.default_hostname
    }
  }
}

#--------------------------------------------------------------
# Function App Outputs
#--------------------------------------------------------------

output "function_apps" {
  description = "Function App information for both regions"
  value = var.enable_function_apps && var.enable_storage ? {
    primary = {
      id               = module.function_app_primary[0].id
      name             = module.function_app_primary[0].name
      default_hostname = module.function_app_primary[0].default_hostname
    }
    secondary = {
      id               = module.function_app_secondary[0].id
      name             = module.function_app_secondary[0].name
      default_hostname = module.function_app_secondary[0].default_hostname
    }
  } : null
}

#--------------------------------------------------------------
# API Management Outputs
#--------------------------------------------------------------

# APIM output commented out - add APIM module first
# output "apim" {
#   description = "API Management information"
#   value = {
#     id          = module.apim_primary.id
#     name        = module.apim_primary.name
#     gateway_url = module.apim_primary.gateway_url
#   }
# }

#--------------------------------------------------------------
# SQL Managed Instance Outputs
#--------------------------------------------------------------

output "sql_mi" {
  description = "SQL Managed Instance information"
  value = var.enable_sql_mi ? {
    primary = {
      id   = module.sql_mi_primary[0].id
      name = module.sql_mi_primary[0].name
      fqdn = module.sql_mi_primary[0].fqdn
    }
    secondary = {
      id   = module.sql_mi_secondary[0].id
      name = module.sql_mi_secondary[0].name
      fqdn = module.sql_mi_secondary[0].fqdn
    }
    failover_group = null  # Enable after both SQL MIs are created and failover group is configured
  } : null
  sensitive = true
}

#--------------------------------------------------------------
# Redis Cache Outputs
#--------------------------------------------------------------

output "redis" {
  description = "Redis Cache information for both regions"
  value = {
    primary = {
      id       = module.redis_primary.id
      name     = module.redis_primary.name
      hostname = module.redis_primary.hostname
    }
    secondary = {
      id       = module.redis_secondary.id
      name     = module.redis_secondary.name
      hostname = module.redis_secondary.hostname
    }
  }
}

#--------------------------------------------------------------
# Storage Account Outputs
#--------------------------------------------------------------

output "storage_accounts" {
  description = "Storage account information for both regions"
  value = var.enable_storage ? {
    primary = {
      id                        = module.storage_primary[0].id
      name                      = module.storage_primary[0].name
      primary_blob_endpoint     = module.storage_primary[0].primary_blob_endpoint
      secondary_blob_endpoint   = module.storage_primary[0].secondary_blob_endpoint
    }
    secondary = {
      id                        = module.storage_secondary[0].id
      name                      = module.storage_secondary[0].name
      primary_blob_endpoint     = module.storage_secondary[0].primary_blob_endpoint
      secondary_blob_endpoint   = module.storage_secondary[0].secondary_blob_endpoint
    }
  } : null
}

#--------------------------------------------------------------
# Key Vault Outputs
#--------------------------------------------------------------

output "key_vaults" {
  description = "Key Vault information for both regions"
  value = {
    primary = {
      id        = module.key_vault_primary.id
      name      = module.key_vault_primary.name
      vault_uri = module.key_vault_primary.vault_uri
    }
    secondary = {
      id        = module.key_vault_secondary.id
      name      = module.key_vault_secondary.name
      vault_uri = module.key_vault_secondary.vault_uri
    }
  }
}

#--------------------------------------------------------------
# Monitoring Outputs
#--------------------------------------------------------------

output "monitoring" {
  description = "Monitoring resources information"
  sensitive = true
  value = {
    log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
    application_insights = {
      for k, v in module.monitoring.application_insights : k => {
        id   = v.id
        name = v.name
      }
    }
  }
}

#--------------------------------------------------------------
# Connection Strings (Sensitive)
#--------------------------------------------------------------

output "connection_strings" {
  description = "Connection strings for applications (sensitive)"
  sensitive   = true
  value = {
    sql_failover_group = null  # Enable after failover group is created
    redis_primary      = module.redis_primary.primary_connection_string
    redis_secondary    = module.redis_secondary.primary_connection_string
    app_insights = {
      primary   = module.monitoring.application_insights["primary"].connection_string
      secondary = module.monitoring.application_insights["secondary"].connection_string
    }
  }
}

#--------------------------------------------------------------
# Summary Output
#--------------------------------------------------------------

output "deployment_summary" {
  description = "Summary of the deployment"
  value = <<-EOT

    ═══════════════════════════════════════════════════════════════
    POC Application - Multi-Region Resilient Infrastructure
    ═══════════════════════════════════════════════════════════════

    Primary Region:   ${local.regions.primary.name}
    Secondary Region: ${local.regions.secondary.name}

    ┌─────────────────────────────────────────────────────────────┐
    │ Global Resources                                            │
    ├─────────────────────────────────────────────────────────────┤
    │ Front Door:     ${module.front_door.profile_id}
    │ WAF Mode:       ${var.waf_mode}
    └─────────────────────────────────────────────────────────────┘

    ┌─────────────────────────────────────────────────────────────┐
    │ Data Tier (Active-Passive)                                  │
    ├─────────────────────────────────────────────────────────────┤
    │ SQL MI Failover Group:  Not configured yet (requires both SQL MIs first)
    │ Redis Geo-Replication:  Enabled
    │ Storage Replication:    ${var.storage_account_replication_type}
    └─────────────────────────────────────────────────────────────┘

    ┌─────────────────────────────────────────────────────────────┐
    │ Compute Tier (Active-Active)                                │
    ├─────────────────────────────────────────────────────────────┤
    │ App Services:    Zone-redundant in both regions
    │ Function Apps:   ${var.enable_function_apps ? "Enabled" : "Disabled (Storage required)"}
    │ APIM:            Multi-region Premium deployment
    └─────────────────────────────────────────────────────────────┘

    ┌─────────────────────────────────────────────────────────────┐
    │ Security                                                    │
    ├─────────────────────────────────────────────────────────────┤
    │ Private Endpoints:  ${var.enable_private_endpoints ? "Enabled" : "Disabled"}
    │ Managed Identities: Enabled for all compute
    │ TLS Version:        ${var.minimum_tls_version}+
    └─────────────────────────────────────────────────────────────┘

    RTO Target: 1 hour | RPO Target: 4 hours

    ═══════════════════════════════════════════════════════════════
  EOT
}

