#--------------------------------------------------------------
# Production Environment - Local Values
#--------------------------------------------------------------

locals {
  # Project naming
  project_name = var.project_name
  environment  = var.environment

  # Regional configuration
  regions = {
    primary = {
      name     = var.primary_location
      short    = local.region_short_names[var.primary_location]
      is_primary = true
    }
    secondary = {
      name     = var.secondary_location
      short    = local.region_short_names[var.secondary_location]
      is_primary = false
    }
  }

  # Region short names for resource naming
  region_short_names = {
    "eastus"         = "eus"
    "eastus2"        = "eus2"
    "westus"         = "wus"
    "westus2"        = "wus2"
    "centralus"      = "cus"
    "northcentralus" = "ncus"
    "southcentralus" = "scus"
    "westeurope"     = "weu"
    "northeurope"    = "neu"
    "centralindia"   = "cin"
    "southindia"     = "sin"
    "westindia"      = "win"
    "southeastasia"  = "sea"
    "eastasia"       = "eas"
  }

  # Common tags applied to all resources
  common_tags = merge(var.tags, {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "Terraform"
    CreatedDate = timestamp()
  })

  # Naming convention function-like locals
  rg_names = {
    for region_key, region in local.regions : region_key => "rg-${local.project_name}-${local.environment}-${region.short}"
  }
  vnet_names = {
    for region_key, region in local.regions : region_key => "vnet-${local.project_name}-${local.environment}-${region.short}"
  }
  kv_names = {
    for region_key, region in local.regions : region_key => "kv-${local.project_name}-${local.environment}-${region.short}"
  }
  storage_names = {
    for region_key, region in local.regions : region_key => "st${replace(local.project_name, "-", "")}${local.environment}${region.short}"
  }
  sqlmi_names = {
    for region_key, region in local.regions : region_key => "sqlmi-${local.project_name}-${local.environment}-${region.short}"
  }
  redis_names = {
    for region_key, region in local.regions : region_key => "redis-${local.project_name}-${local.environment}-${region.short}"
  }
  apim_names = {
    for region_key, region in local.regions : region_key => "apim-${local.project_name}-${local.environment}-${region.short}"
  }
  asp_names = {
    for region_key, region in local.regions : region_key => "asp-${local.project_name}-${local.environment}-${region.short}"
  }
  app_names = {
    for region_key, region in local.regions : region_key => "app-${local.project_name}-${local.environment}-${region.short}"
  }
  func_names = {
    for region_key, region in local.regions : region_key => "func-${local.project_name}-${local.environment}-${region.short}"
  }
  frontdoor_name = "fd-${local.project_name}-${local.environment}"
  law_names = {
    for region_key, region in local.regions : region_key => "law-${local.project_name}-${local.environment}-${region.short}"
  }
  appi_names = {
    for region_key, region in local.regions : region_key => "appi-${local.project_name}-${local.environment}-${region.short}"
  }

  # Availability Zones
  availability_zones           = ["1", "2", "3"]
  primary_availability_zones   = ["1", "2", "3"]
  secondary_availability_zones = var.secondary_zone_redundant ? ["1", "2", "3"] : []

  # Subnet CIDR calculations
  subnet_config = {
    primary = {
      vnet_cidr     = "10.1.0.0/16"
      app_service   = "10.1.1.0/24"
      function_app  = "10.1.2.0/24"
      apim          = "10.1.3.0/24"
      private_endpoints = "10.1.4.0/24"
      sql_mi        = "10.1.5.0/24"
      redis         = "10.1.6.0/24"
      bastion       = "10.1.254.0/24"
    }
    secondary = {
      vnet_cidr     = "10.2.0.0/16"
      app_service   = "10.2.1.0/24"
      function_app  = "10.2.2.0/24"
      apim          = "10.2.3.0/24"
      private_endpoints = "10.2.4.0/24"
      sql_mi        = "10.2.5.0/24"
      redis         = "10.2.6.0/24"
      bastion       = "10.2.254.0/24"
    }
  }

  # Private DNS Zone names
  private_dns_zones = {
    blob      = "privatelink.blob.core.windows.net"
    file      = "privatelink.file.core.windows.net"
    queue     = "privatelink.queue.core.windows.net"
    table     = "privatelink.table.core.windows.net"
    keyvault  = "privatelink.vaultcore.azure.net"
    redis     = "privatelink.redis.cache.windows.net"
    sql       = "privatelink.database.windows.net"
    webapp    = "privatelink.azurewebsites.net"
    apim      = "privatelink.azure-api.net"
  }
}
