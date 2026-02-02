#--------------------------------------------------------------
# Production Environment - Main Orchestration
#--------------------------------------------------------------
# This file orchestrates all modules for multi-region deployment
# Primary: East US 2 | Secondary: Central US
# Architecture: Active-Active for compute, Active-Passive for SQL MI
#--------------------------------------------------------------

#--------------------------------------------------------------
# Random String for Unique Naming
#--------------------------------------------------------------

resource "random_string" "unique" {
  length  = 4
  special = false
  upper   = false
}

#--------------------------------------------------------------
# Resource Groups - Both Regions
#--------------------------------------------------------------

module "resource_group_primary" {
  source = "../../modules/resource-group"

  name     = local.rg_names.primary
  location = local.regions.primary.name
  tags     = local.common_tags
}

module "resource_group_secondary" {
  source = "../../modules/resource-group"

  name     = local.rg_names.secondary
  location = local.regions.secondary.name
  tags     = local.common_tags
}

#--------------------------------------------------------------
# Networking - Both Regions
#--------------------------------------------------------------

module "networking_primary" {
  source = "../../modules/networking"

  resource_group_name = module.resource_group_primary.name
  location            = local.regions.primary.name
  vnet_name           = local.vnet_names.primary
  address_space       = var.vnet_address_space_primary

  subnets = {
    "snet-appservice" = {
      address_prefixes = [local.subnet_config.primary.app_service]
      delegation = {
        name = "Microsoft.Web/serverFarms"
        actions = [
          "Microsoft.Network/virtualNetworks/subnets/action"
        ]
      }
    }
    "snet-functionapp" = {
      address_prefixes = [local.subnet_config.primary.function_app]
      delegation = {
        name = "Microsoft.Web/serverFarms"
        actions = [
          "Microsoft.Network/virtualNetworks/subnets/action"
        ]
      }
    }
    "snet-apim" = {
      address_prefixes = [local.subnet_config.primary.apim]
      delegation = {
        name = "Microsoft.ApiManagement/service"
        actions = [
          "Microsoft.Network/virtualNetworks/subnets/action"
        ]
      }
    }
    "snet-privateendpoints" = {
      address_prefixes = [local.subnet_config.primary.private_endpoints]
    }
    "snet-sqlmi" = {
      address_prefixes  = [local.subnet_config.primary.sql_mi]
      is_sqlmi_subnet   = true  # Required for Route Table creation
      delegation = {
        name = "Microsoft.Sql/managedInstances"
        actions = [
          "Microsoft.Network/virtualNetworks/subnets/action"
        ]
      }
    }
    "snet-redis" = {
      address_prefixes = [local.subnet_config.primary.redis]
    }
  }

  private_dns_zones        = local.private_dns_zones
  enable_private_dns_zones = var.enable_private_endpoints

  tags = local.common_tags
}

module "networking_secondary" {
  source = "../../modules/networking"

  resource_group_name = module.resource_group_secondary.name
  location            = local.regions.secondary.name
  vnet_name           = local.vnet_names.secondary
  address_space       = var.vnet_address_space_secondary

  subnets = {
    "snet-appservice" = {
      address_prefixes = [local.subnet_config.secondary.app_service]
      delegation = {
        name = "Microsoft.Web/serverFarms"
        actions = [
          "Microsoft.Network/virtualNetworks/subnets/action"
        ]
      }
    }
    "snet-functionapp" = {
      address_prefixes = [local.subnet_config.secondary.function_app]
      delegation = {
        name = "Microsoft.Web/serverFarms"
        actions = [
          "Microsoft.Network/virtualNetworks/subnets/action"
        ]
      }
    }
    "snet-apim" = {
      address_prefixes = [local.subnet_config.secondary.apim]
      delegation = {
        name = "Microsoft.ApiManagement/service"
        actions = [
          "Microsoft.Network/virtualNetworks/subnets/action"
        ]
      }
    }
    "snet-privateendpoints" = {
      address_prefixes = [local.subnet_config.secondary.private_endpoints]
    }
    "snet-sqlmi" = {
      address_prefixes  = [local.subnet_config.secondary.sql_mi]
      is_sqlmi_subnet   = true  # Required for Route Table creation
      delegation = {
        name = "Microsoft.Sql/managedInstances"
        actions = [
          "Microsoft.Network/virtualNetworks/subnets/action"
        ]
      }
    }
    "snet-redis" = {
      address_prefixes = [local.subnet_config.secondary.redis]
    }
  }

  private_dns_zones        = local.private_dns_zones
  enable_private_dns_zones = var.enable_private_endpoints

  tags = local.common_tags
}

#--------------------------------------------------------------
# VNet Peering - Bidirectional
#--------------------------------------------------------------

resource "azurerm_virtual_network_peering" "primary_to_secondary" {
  count = var.enable_vnet_peering ? 1 : 0

  name                         = "peer-${local.regions.primary.short}-to-${local.regions.secondary.short}"
  resource_group_name          = module.resource_group_primary.name
  virtual_network_name         = module.networking_primary.vnet_name
  remote_virtual_network_id    = module.networking_secondary.vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
}

resource "azurerm_virtual_network_peering" "secondary_to_primary" {
  count = var.enable_vnet_peering ? 1 : 0

  name                         = "peer-${local.regions.secondary.short}-to-${local.regions.primary.short}"
  resource_group_name          = module.resource_group_secondary.name
  virtual_network_name         = module.networking_secondary.vnet_name
  remote_virtual_network_id    = module.networking_primary.vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
}

#--------------------------------------------------------------
# Monitoring - Primary Region (Centralized)
#--------------------------------------------------------------

module "monitoring" {
  source = "../../modules/monitoring"

  log_analytics_name  = local.law_names.primary
  resource_group_name = module.resource_group_primary.name
  location            = local.regions.primary.name
  retention_in_days   = var.log_analytics_retention_days

  application_insights = {
    primary = {
      application_type    = "web"
      retention_in_days   = var.log_analytics_retention_days
      sampling_percentage = 100
    }
    secondary = {
      application_type    = "web"
      retention_in_days   = var.log_analytics_retention_days
      sampling_percentage = 100
    }
  }

  action_groups = {
    critical = {
      short_name = "critical"
      email_receivers = [
        for email in var.alert_email_addresses : {
          name                    = replace(email, "@", "-at-")
          email_address           = email
          use_common_alert_schema = true
        }
      ]
    }
    warning = {
      short_name = "warning"
      email_receivers = [
        for email in var.alert_email_addresses : {
          name                    = replace(email, "@", "-at-")
          email_address           = email
          use_common_alert_schema = true
        }
      ]
    }
  }

  tags = local.common_tags
}

#--------------------------------------------------------------
# Key Vault - Both Regions
#--------------------------------------------------------------

module "key_vault_primary" {
  source = "../../modules/key-vault"

  name                = local.kv_names.primary
  resource_group_name = module.resource_group_primary.name
  location            = local.regions.primary.name
  sku_name            = var.key_vault_sku_name

  soft_delete_retention_days = var.key_vault_soft_delete_retention_days
  purge_protection_enabled   = true
  enable_rbac_authorization  = true

  network_acls = {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    ip_rules                   = var.allowed_ip_ranges
    virtual_network_subnet_ids = []
  }

  # Private Endpoint
  enable_private_endpoint    = var.enable_private_endpoints
  private_endpoint_subnet_id = module.networking_primary.subnet_ids["snet-privateendpoints"]
  private_dns_zone_ids       = var.enable_private_endpoints ? [module.networking_primary.private_dns_zone_ids["privatelink.vaultcore.azure.net"]] : null

  tags = local.common_tags

  # Diagnostics - Send to Log Analytics
  enable_diagnostics         = true
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
}

module "key_vault_secondary" {
  source = "../../modules/key-vault"

  name                = local.kv_names.secondary
  resource_group_name = module.resource_group_secondary.name
  location            = local.regions.secondary.name
  sku_name            = var.key_vault_sku_name

  soft_delete_retention_days = var.key_vault_soft_delete_retention_days
  purge_protection_enabled   = true
  enable_rbac_authorization  = true

  network_acls = {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    ip_rules                   = var.allowed_ip_ranges
    virtual_network_subnet_ids = []
  }

  # Private Endpoint
  enable_private_endpoint    = var.enable_private_endpoints
  private_endpoint_subnet_id = module.networking_secondary.subnet_ids["snet-privateendpoints"]
  private_dns_zone_ids       = var.enable_private_endpoints ? [module.networking_secondary.private_dns_zone_ids["privatelink.vaultcore.azure.net"]] : null

  tags = local.common_tags

  # Diagnostics - Send to Log Analytics
  enable_diagnostics         = true
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
}

#--------------------------------------------------------------
# Storage Accounts - Both Regions (RA-GZRS)
#--------------------------------------------------------------

module "storage_primary" {
  count  = var.enable_storage ? 1 : 0
  source = "../../modules/storage"

  name                     = local.storage_names.primary
  resource_group_name      = module.resource_group_primary.name
  location                 = local.regions.primary.name
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_account_replication_type

  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false  # RBAC-only authentication (key-based auth disabled)
  default_to_oauth_authentication = true

  network_rules = {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    ip_rules                   = var.allowed_ip_ranges
    virtual_network_subnet_ids = []
  }

  containers = {
    "data" = {
      container_access_type = "private"
    }
    "logs" = {
      container_access_type = "private"
    }
    "backups" = {
      container_access_type = "private"
    }
  }

  # Private Endpoints
  enable_private_endpoints   = var.enable_private_endpoints
  private_endpoint_subnet_id = module.networking_primary.subnet_ids["snet-privateendpoints"]
  blob_private_dns_zone_id   = module.networking_primary.private_dns_zone_ids["privatelink.blob.core.windows.net"]
  file_private_dns_zone_id   = module.networking_primary.private_dns_zone_ids["privatelink.file.core.windows.net"]
  queue_private_dns_zone_id  = module.networking_primary.private_dns_zone_ids["privatelink.queue.core.windows.net"]
  table_private_dns_zone_id  = module.networking_primary.private_dns_zone_ids["privatelink.table.core.windows.net"]

  tags = local.common_tags

  # Diagnostics - Send to Log Analytics
  enable_diagnostics         = true
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
}

module "storage_secondary" {
  count  = var.enable_storage ? 1 : 0
  source = "../../modules/storage"

  name                     = local.storage_names.secondary
  resource_group_name      = module.resource_group_secondary.name
  location                 = local.regions.secondary.name
  account_tier             = var.storage_account_tier
  account_replication_type = var.secondary_storage_replication_type  # GRS for West US (no ZRS support)

  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false  # RBAC-only authentication (key-based auth disabled)
  default_to_oauth_authentication = true

  network_rules = {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    ip_rules                   = var.allowed_ip_ranges
    virtual_network_subnet_ids = []
  }

  containers = {
    "data" = {
      container_access_type = "private"
    }
    "logs" = {
      container_access_type = "private"
    }
    "backups" = {
      container_access_type = "private"
    }
  }

  # Private Endpoints
  enable_private_endpoints   = var.enable_private_endpoints
  private_endpoint_subnet_id = module.networking_secondary.subnet_ids["snet-privateendpoints"]
  blob_private_dns_zone_id   = module.networking_secondary.private_dns_zone_ids["privatelink.blob.core.windows.net"]
  file_private_dns_zone_id   = module.networking_secondary.private_dns_zone_ids["privatelink.file.core.windows.net"]
  queue_private_dns_zone_id  = module.networking_secondary.private_dns_zone_ids["privatelink.queue.core.windows.net"]
  table_private_dns_zone_id  = module.networking_secondary.private_dns_zone_ids["privatelink.table.core.windows.net"]

  tags = local.common_tags

  # Diagnostics - Send to Log Analytics
  enable_diagnostics         = true
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
}

#--------------------------------------------------------------
# SQL Managed Instance - Both Regions with Failover Group
#--------------------------------------------------------------

module "sql_mi_primary" {
  count  = var.enable_sql_mi ? 1 : 0
  source = "../../modules/sql-mi"

  name                   = local.sqlmi_names.primary
  resource_group_name    = module.resource_group_primary.name
  location               = local.regions.primary.name
  subnet_id              = module.networking_primary.subnet_ids["snet-sqlmi"]
  sku_name               = var.sql_mi_sku_name
  license_type           = var.sql_mi_license_type
  vcores                 = var.sql_mi_vcores
  storage_size_in_gb     = var.sql_mi_storage_size_gb
  administrator_login    = var.sql_mi_administrator_login
  administrator_password = var.sql_mi_administrator_password
  zone_redundant         = false  # Simplified for POC

  # Azure AD Authentication
  azure_ad_admin_login        = var.sql_mi_azure_ad_admin_login
  azure_ad_admin_object_id    = var.sql_mi_azure_ad_admin_object_id
  azure_ad_admin_tenant_id    = var.sql_mi_azure_ad_admin_tenant_id
  azuread_authentication_only = var.sql_mi_azuread_authentication_only
  minimum_tls_version    = var.minimum_tls_version

  # Failover Group - Primary is the partner
  create_failover_group        = false  # Set to true after both SQL MIs are created
  failover_group_name          = "fog-${local.project_name}-${local.environment}"
  partner_managed_instance_id  = var.enable_sql_mi ? module.sql_mi_secondary[0].id : null
  grace_period_minutes         = var.sql_mi_failover_grace_period_minutes

  tags = local.common_tags

  depends_on = [module.sql_mi_secondary]
}

module "sql_mi_secondary" {
  count  = var.enable_sql_mi ? 1 : 0
  source = "../../modules/sql-mi"

  name                   = local.sqlmi_names.secondary
  resource_group_name    = module.resource_group_secondary.name
  location               = local.regions.secondary.name
  subnet_id              = module.networking_secondary.subnet_ids["snet-sqlmi"]
  sku_name               = var.sql_mi_sku_name
  license_type           = var.sql_mi_license_type
  vcores                 = var.sql_mi_vcores
  storage_size_in_gb     = var.sql_mi_storage_size_gb
  administrator_login    = var.sql_mi_administrator_login
  administrator_password = var.sql_mi_administrator_password
  # Use dedicated SQL MI zone redundancy variable if set, otherwise fall back to secondary_zone_redundant
  zone_redundant         = coalesce(var.sql_mi_secondary_zone_redundant, var.secondary_zone_redundant)

  # Azure AD Authentication
  azure_ad_admin_login        = var.sql_mi_azure_ad_admin_login
  azure_ad_admin_object_id    = var.sql_mi_azure_ad_admin_object_id
  azure_ad_admin_tenant_id    = var.sql_mi_azure_ad_admin_tenant_id
  azuread_authentication_only = var.sql_mi_azuread_authentication_only
  minimum_tls_version    = var.minimum_tls_version

  # Secondary does not create failover group
  create_failover_group = false

  tags = local.common_tags
}

#--------------------------------------------------------------
# Redis Cache - Both Regions with Geo-Replication
#--------------------------------------------------------------

module "redis_primary" {
  source = "../../modules/redis"

  name                = local.redis_names.primary
  resource_group_name = module.resource_group_primary.name
  location            = local.regions.primary.name
  sku_name            = var.redis_sku_name
  family              = var.redis_family
  capacity            = var.redis_capacity
  zones               = local.primary_availability_zones
  minimum_tls_version = var.minimum_tls_version

  non_ssl_port_enabled          = false
  public_network_access_enabled = false

  # Private Endpoint configuration
  enable_private_endpoint    = var.enable_private_endpoints
  private_endpoint_subnet_id = module.networking_primary.subnet_ids["snet-privateendpoints"]
  private_dns_zone_ids       = [module.networking_primary.private_dns_zone_ids["privatelink.redis.cache.windows.net"]]

  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id

  tags = local.common_tags
}

module "redis_secondary" {
  source = "../../modules/redis"

  name                = local.redis_names.secondary
  resource_group_name = module.resource_group_secondary.name
  location            = local.regions.secondary.name
  sku_name            = var.redis_sku_name
  family              = var.redis_family
  capacity            = var.redis_capacity
  zones               = local.secondary_availability_zones
  minimum_tls_version = var.minimum_tls_version

  non_ssl_port_enabled          = false
  public_network_access_enabled = false

  # Geo-replication - link to primary
  enable_geo_replication      = var.redis_enable_geo_replication
  linked_redis_cache_id       = module.redis_primary.redis_cache_id
  linked_redis_cache_location = local.regions.primary.name
  server_role                 = "Secondary"

  # Private Endpoint configuration
  enable_private_endpoint    = var.enable_private_endpoints
  private_endpoint_subnet_id = module.networking_secondary.subnet_ids["snet-privateendpoints"]
  private_dns_zone_ids       = [module.networking_primary.private_dns_zone_ids["privatelink.redis.cache.windows.net"]]

  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id

  tags = local.common_tags

  depends_on = [module.redis_primary]
}


#--------------------------------------------------------------
# App Service - Both Regions
#--------------------------------------------------------------

module "app_service_primary" {
  source = "../../modules/app-service"

  app_service_plan_name = local.asp_names.primary
  app_service_name      = local.app_names.primary
  resource_group_name   = module.resource_group_primary.name
  location              = local.regions.primary.name

  os_type  = "Windows"
  sku_name = var.app_service_sku

  zone_balancing_enabled = true
  worker_count           = var.app_service_instance_count
  
  # Autoscale
  enable_autoscale   = true
  min_capacity       = var.app_service_instance_count
  max_capacity       = var.app_service_max_instances
  default_capacity   = var.app_service_instance_count

  # Site config
  dotnet_version      = var.app_service_dotnet_version
  minimum_tls_version = var.minimum_tls_version
  ftps_state          = "Disabled"
  http2_enabled       = true
  always_on           = true

  # Identity
  identity_type = "SystemAssigned"

  # VNet Integration
  subnet_id = module.networking_primary.subnet_ids["snet-appservice"]

  # App Settings
  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = module.monitoring.application_insights["primary"].instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = module.monitoring.application_insights["primary"].connection_string
    "KeyVaultUri"                           = module.key_vault_primary.vault_uri
    "WEBSITE_DNS_SERVER"                    = "168.63.129.16"
  }

  # Deployment Slots
  deployment_slots = ["staging"]

  # Private Endpoint
  enable_private_endpoint    = var.enable_private_endpoints
  private_endpoint_subnet_id = module.networking_primary.subnet_ids["snet-privateendpoints"]
  private_dns_zone_ids       = var.enable_private_endpoints ? [module.networking_primary.private_dns_zone_ids["privatelink.azurewebsites.net"]] : null

  tags = local.common_tags
}

module "app_service_secondary" {
  source = "../../modules/app-service"

  app_service_plan_name = local.asp_names.secondary
  app_service_name      = local.app_names.secondary
  resource_group_name   = module.resource_group_secondary.name
  location              = local.regions.secondary.name

  os_type  = "Windows"
  sku_name = var.app_service_sku

  zone_balancing_enabled = var.secondary_zone_redundant  # Conditional based on secondary region support
  worker_count           = var.app_service_instance_count
  
  # Autoscale
  enable_autoscale   = true
  min_capacity       = var.app_service_instance_count
  max_capacity       = var.app_service_max_instances
  default_capacity   = var.app_service_instance_count

  # Site config
  dotnet_version      = var.app_service_dotnet_version
  minimum_tls_version = var.minimum_tls_version
  ftps_state          = "Disabled"
  http2_enabled       = true
  always_on           = true

  # Identity
  identity_type = "SystemAssigned"

  # VNet Integration
  subnet_id = module.networking_secondary.subnet_ids["snet-appservice"]

  # App Settings
  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = module.monitoring.application_insights["secondary"].instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = module.monitoring.application_insights["secondary"].connection_string
    "KeyVaultUri"                           = module.key_vault_secondary.vault_uri
    "WEBSITE_DNS_SERVER"                    = "168.63.129.16"
  }

  # Deployment Slots
  deployment_slots = ["staging"]

  # Private Endpoint
  enable_private_endpoint    = var.enable_private_endpoints
  private_endpoint_subnet_id = module.networking_secondary.subnet_ids["snet-privateendpoints"]
  private_dns_zone_ids       = var.enable_private_endpoints ? [module.networking_secondary.private_dns_zone_ids["privatelink.azurewebsites.net"]] : null

  tags = local.common_tags
}

#--------------------------------------------------------------
# Function Apps - Both Regions
#--------------------------------------------------------------

module "function_app_primary" {
  count  = var.enable_function_apps && var.enable_storage ? 1 : 0
  source = "../../modules/function-app"

  function_app_name     = local.func_names.primary
  app_service_plan_name = "${local.asp_names.primary}-func"
  storage_account_name  = module.storage_primary[0].name
  resource_group_name   = module.resource_group_primary.name
  location              = local.regions.primary.name

  os_type  = "Windows"
  sku_name = var.function_app_sku

  zone_balancing_enabled       = true
  maximum_elastic_worker_count = var.function_app_max_instances

  # Runtime
  runtime_name         = var.function_runtime
  runtime_version      = var.function_runtime_version
  functions_extension_version = "~4"

  # Site config
  minimum_tls_version = var.minimum_tls_version
  ftps_state          = "Disabled"
  http2_enabled       = true

  # Identity
  identity_type = "SystemAssigned"

  # VNet Integration
  subnet_id = module.networking_primary.subnet_ids["snet-functionapp"]

  # App Settings
  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = module.monitoring.application_insights["primary"].instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = module.monitoring.application_insights["primary"].connection_string
    "KeyVaultUri"                           = module.key_vault_primary.vault_uri
    "WEBSITE_DNS_SERVER"                    = "168.63.129.16"
  }

  # Private Endpoint
  enable_private_endpoint    = var.enable_private_endpoints
  private_endpoint_subnet_id = module.networking_primary.subnet_ids["snet-privateendpoints"]
  private_dns_zone_ids       = var.enable_private_endpoints ? [module.networking_primary.private_dns_zone_ids["privatelink.azurewebsites.net"]] : null

  tags = local.common_tags
}

module "function_app_secondary" {
  count  = var.enable_function_apps && var.enable_storage ? 1 : 0
  source = "../../modules/function-app"

  function_app_name     = local.func_names.secondary
  app_service_plan_name = "${local.asp_names.secondary}-func"
  storage_account_name  = module.storage_secondary[0].name
  resource_group_name   = module.resource_group_secondary.name
  location              = local.regions.secondary.name

  os_type  = "Windows"
  sku_name = var.function_app_sku

  zone_balancing_enabled       = var.secondary_zone_redundant  # Zone redundancy based on region support
  maximum_elastic_worker_count = var.function_app_max_instances

  # Runtime
  runtime_name         = var.function_runtime
  runtime_version      = var.function_runtime_version
  functions_extension_version = "~4"

  # Site config
  minimum_tls_version = var.minimum_tls_version
  ftps_state          = "Disabled"
  http2_enabled       = true

  # Identity
  identity_type = "SystemAssigned"

  # VNet Integration
  subnet_id = module.networking_secondary.subnet_ids["snet-functionapp"]

  # App Settings
  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = module.monitoring.application_insights["secondary"].instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = module.monitoring.application_insights["secondary"].connection_string
    "KeyVaultUri"                           = module.key_vault_secondary.vault_uri
    "WEBSITE_DNS_SERVER"                    = "168.63.129.16"
  }

  # Private Endpoint
  enable_private_endpoint    = var.enable_private_endpoints
  private_endpoint_subnet_id = module.networking_secondary.subnet_ids["snet-privateendpoints"]
  private_dns_zone_ids       = var.enable_private_endpoints ? [module.networking_secondary.private_dns_zone_ids["privatelink.azurewebsites.net"]] : null

  tags = local.common_tags
}

#--------------------------------------------------------------
# Azure Front Door - Global Load Balancer with WAF
#--------------------------------------------------------------

module "front_door" {
  source = "../../modules/front-door"

  profile_name        = local.frontdoor_name
  resource_group_name = module.resource_group_primary.name
  sku_name            = var.frontdoor_sku_name

  # Origin Groups with health probes
  origin_groups = {
    "og-webapp" = {
      health_probe = {
        interval_in_seconds = 30
        path                = "/health"
        protocol            = "Https"
        request_type        = "HEAD"
      }
      load_balancing = {
        sample_size                        = 4
        successful_samples_required        = 3
        additional_latency_in_milliseconds = 50
      }
    }
    "og-api" = {
      health_probe = {
        interval_in_seconds = 30
        path                = "/health"
        protocol            = "Https"
        request_type        = "HEAD"
      }
      load_balancing = {
        sample_size                        = 4
        successful_samples_required        = 3
        additional_latency_in_milliseconds = 50
      }
    }
    "og-functions" = {
      health_probe = {
        interval_in_seconds = 30
        path                = "/api/health"
        protocol            = "Https"
        request_type        = "GET"
      }
      load_balancing = {
        sample_size                        = 4
        successful_samples_required        = 3
        additional_latency_in_milliseconds = 50
      }
    }
  }

  # Origins (backends) - Active-Active across regions
  origins = {
    "origin-webapp-primary" = {
      origin_group_key          = "og-webapp"
      host_name                 = module.app_service_primary.default_hostname
      http_port                 = 80
      https_port                = 443
      origin_host_header        = module.app_service_primary.default_hostname
      priority                  = 1
      weight                    = 50
      enabled                   = true
      certificate_name_check_enabled = true
      private_link = var.enable_private_endpoints ? {
        location               = local.regions.primary.name
        private_link_target_id = module.app_service_primary.id
        target_type            = "sites"
        request_message        = "Front Door Private Link"
      } : null
    }
    "origin-webapp-secondary" = {
      origin_group_key          = "og-webapp"
      host_name                 = module.app_service_secondary.default_hostname
      http_port                 = 80
      https_port                = 443
      origin_host_header        = module.app_service_secondary.default_hostname
      priority                  = 1
      weight                    = 50
      enabled                   = true
      certificate_name_check_enabled = true
      private_link = var.enable_private_endpoints ? {
        location               = local.regions.secondary.name
        private_link_target_id = module.app_service_secondary.id
        target_type            = "sites"
        request_message        = "Front Door Private Link"
      } : null
    }
    # APIM origin removed - add APIM module first
    "origin-func-primary" = {
      origin_group_key          = "og-functions"
      host_name                 = var.enable_function_apps && var.enable_storage ? module.function_app_primary[0].default_hostname : "placeholder.azurewebsites.net"
      http_port                 = 80
      https_port                = 443
      origin_host_header        = var.enable_function_apps && var.enable_storage ? module.function_app_primary[0].default_hostname : "placeholder.azurewebsites.net"
      priority                  = 1
      weight                    = 50
      enabled                   = true
      certificate_name_check_enabled = true
      private_link = var.enable_private_endpoints && var.enable_function_apps && var.enable_storage ? {
        location               = local.regions.primary.name
        private_link_target_id = var.enable_function_apps && var.enable_storage ? module.function_app_primary[0].id : null
        target_type            = "sites"
        request_message        = "Front Door Private Link"
      } : null
    }
    "origin-func-secondary" = {
      origin_group_key          = "og-functions"
      host_name                 = var.enable_function_apps && var.enable_storage ? module.function_app_secondary[0].default_hostname : "placeholder.azurewebsites.net"
      http_port                 = 80
      https_port                = 443
      origin_host_header        = var.enable_function_apps && var.enable_storage ? module.function_app_secondary[0].default_hostname : "placeholder.azurewebsites.net"
      priority                  = 1
      weight                    = 50
      enabled                   = true
      certificate_name_check_enabled = true
      private_link = var.enable_private_endpoints && var.enable_function_apps && var.enable_storage ? {
        location               = local.regions.secondary.name
        private_link_target_id = var.enable_function_apps && var.enable_storage ? module.function_app_secondary[0].id : null
        target_type            = "sites"
        request_message        = "Front Door Private Link"
      } : null
    }
  }

  # Endpoints
  endpoints = {
    "ep-webapp" = {
      enabled = true
    }
    "ep-api" = {
      enabled = true
    }
  }

  # Routes
  routes = {
    "route-webapp" = {
      endpoint_key         = "ep-webapp"
      origin_group_key     = "og-webapp"
      origin_keys          = ["origin-webapp-primary", "origin-webapp-secondary"]
      patterns_to_match    = ["/*"]
      supported_protocols  = ["Http", "Https"]
      forwarding_protocol  = "HttpsOnly"
      https_redirect_enabled = true
      link_to_default_domain = true
    }
    # route-api requires APIM module - commented out
    # "route-api" = {
    #   endpoint_key         = "ep-api"
    #   origin_group_key     = "og-api"
    #   origin_keys          = ["origin-api-primary"]
    #   patterns_to_match    = ["/api/*"]
    #   supported_protocols  = ["Http", "Https"]
    #   forwarding_protocol  = "HttpsOnly"
    #   https_redirect_enabled = true
    #   link_to_default_domain = true
    # }
  }

  # WAF Configuration
  waf_policy_name = "wafpocappprodglobal"
  waf_mode        = var.waf_mode

  waf_managed_rules = [
    {
      type    = "Microsoft_DefaultRuleSet"
      version = "2.1"
      action  = "Block"
    },
    {
      type    = "Microsoft_BotManagerRuleSet"
      version = "1.0"
      action  = "Block"
    }
  ]

  tags = local.common_tags
}

#--------------------------------------------------------------
# Role Assignments - Key Vault Access for Apps
#--------------------------------------------------------------

# App Service Primary -> Key Vault Primary
resource "azurerm_role_assignment" "app_primary_kv_primary" {
  scope                = module.key_vault_primary.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.app_service_primary.identity_principal_id
}

# App Service Secondary -> Key Vault Secondary
resource "azurerm_role_assignment" "app_secondary_kv_secondary" {
  scope                = module.key_vault_secondary.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.app_service_secondary.identity_principal_id
}

# Function App Primary -> Key Vault Primary
resource "azurerm_role_assignment" "func_primary_kv_primary" {
  count                = var.enable_function_apps && var.enable_storage ? 1 : 0
  scope                = module.key_vault_primary.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.function_app_primary[0].identity_principal_id
}

# Function App Secondary -> Key Vault Secondary
resource "azurerm_role_assignment" "func_secondary_kv_secondary" {
  count                = var.enable_function_apps && var.enable_storage ? 1 : 0
  scope                = module.key_vault_secondary.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.function_app_secondary[0].identity_principal_id
}

# Function App Primary -> Storage Primary (for Function App runtime)
resource "azurerm_role_assignment" "func_primary_storage" {
  count                = var.enable_function_apps && var.enable_storage ? 1 : 0
  scope                = module.storage_primary[0].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.function_app_primary[0].identity_principal_id
}

# Function App Secondary -> Storage Secondary (for Function App runtime)
resource "azurerm_role_assignment" "func_secondary_storage" {
  count                = var.enable_function_apps && var.enable_storage ? 1 : 0
  scope                = module.storage_secondary[0].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.function_app_secondary[0].identity_principal_id
}
























# Function App Primary -> Storage Primary (Queue access for triggers)
resource "azurerm_role_assignment" "func_primary_storage_queue" {
  count                = var.enable_function_apps && var.enable_storage ? 1 : 0
  scope                = module.storage_primary[0].id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = module.function_app_primary[0].identity_principal_id
}

# Function App Secondary -> Storage Secondary (Queue access for triggers)
resource "azurerm_role_assignment" "func_secondary_storage_queue" {
  count                = var.enable_function_apps && var.enable_storage ? 1 : 0
  scope                = module.storage_secondary[0].id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = module.function_app_secondary[0].identity_principal_id
}

# Function App Primary -> Storage Primary (Table access for durable functions)
resource "azurerm_role_assignment" "func_primary_storage_table" {
  count                = var.enable_function_apps && var.enable_storage ? 1 : 0
  scope                = module.storage_primary[0].id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = module.function_app_primary[0].identity_principal_id
}

# Function App Secondary -> Storage Secondary (Table access for durable functions)
resource "azurerm_role_assignment" "func_secondary_storage_table" {
  count                = var.enable_function_apps && var.enable_storage ? 1 : 0
  scope                = module.storage_secondary[0].id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = module.function_app_secondary[0].identity_principal_id
}

# App Service Primary -> Storage Primary
resource "azurerm_role_assignment" "app_primary_storage" {
  count                = var.enable_storage ? 1 : 0
  scope                = module.storage_primary[0].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.app_service_primary.identity_principal_id
}

# App Service Secondary -> Storage Secondary
resource "azurerm_role_assignment" "app_secondary_storage" {
  count                = var.enable_storage ? 1 : 0
  scope                = module.storage_secondary[0].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.app_service_secondary.identity_principal_id
}

