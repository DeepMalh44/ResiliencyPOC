#--------------------------------------------------------------
# Function App Module - Main
# Supports Consumption (Y1), Premium (EP), and Standard tiers
#--------------------------------------------------------------

#--------------------------------------------------------------
# App Service Plan
#--------------------------------------------------------------
resource "azurerm_service_plan" "this" {
  name                   = var.app_service_plan_name
  location               = var.location
  resource_group_name    = var.resource_group_name
  os_type                = var.os_type
  sku_name               = var.sku_name
  zone_balancing_enabled = startswith(var.sku_name, "EP") || startswith(var.sku_name, "P") ? var.zone_balancing_enabled : false

  # maximum_elastic_worker_count is only for Elastic Premium (EP) SKUs
  maximum_elastic_worker_count = startswith(var.sku_name, "EP") ? var.maximum_elastic_worker_count : null

  tags = var.tags
}

#--------------------------------------------------------------
# Windows Function App
#--------------------------------------------------------------
resource "azurerm_windows_function_app" "this" {
  count = var.os_type == "Windows" ? 1 : 0

  name                          = var.function_app_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  service_plan_id               = azurerm_service_plan.this.id
  storage_account_name          = var.storage_account_name
  storage_uses_managed_identity = true
  https_only                    = true
  public_network_access_enabled = var.enable_private_endpoint ? false : var.public_network_access_enabled
  virtual_network_subnet_id     = startswith(var.sku_name, "Y") ? null : var.subnet_id
  functions_extension_version   = var.functions_extension_version

  site_config {
    ftps_state              = var.ftps_state
    http2_enabled           = var.http2_enabled
    minimum_tls_version     = var.minimum_tls_version
    vnet_route_all_enabled  = startswith(var.sku_name, "Y") ? false : (var.subnet_id != null ? true : false)
    use_32_bit_worker       = false

    # Elastic Premium features only
    # When zone_balancing_enabled = true, elastic_instance_minimum must be > 2 (Azure requirement)
    elastic_instance_minimum          = startswith(var.sku_name, "EP") ? (var.zone_balancing_enabled ? 3 : 1) : null
    runtime_scale_monitoring_enabled  = startswith(var.sku_name, "EP") ? true : false

    application_stack {
      dotnet_version              = var.runtime_name == "dotnet-isolated" || var.runtime_name == "dotnet" ? "v${var.runtime_version}" : null
      use_dotnet_isolated_runtime = var.runtime_name == "dotnet-isolated" ? true : false
      node_version                = var.runtime_name == "node" ? var.runtime_version : null
      java_version                = var.runtime_name == "java" ? var.runtime_version : null
      powershell_core_version     = var.runtime_name == "powershell" ? var.runtime_version : null
    }
  }

  identity {
    type = var.identity_type
  }

  app_settings = merge({
    "FUNCTIONS_WORKER_RUNTIME" = var.runtime_name == "dotnet-isolated" ? "dotnet-isolated" : var.runtime_name
    "WEBSITE_CONTENTOVERVNET"  = startswith(var.sku_name, "Y") ? "0" : (var.subnet_id != null ? "1" : "0")
  }, var.app_settings)

  tags = var.tags

  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
      app_settings["WEBSITE_CONTENTSHARE"],
    ]
  }
}

#--------------------------------------------------------------
# Linux Function App
#--------------------------------------------------------------
resource "azurerm_linux_function_app" "this" {
  count = var.os_type == "Linux" ? 1 : 0

  name                          = var.function_app_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  service_plan_id               = azurerm_service_plan.this.id
  storage_account_name          = var.storage_account_name
  storage_uses_managed_identity = true
  https_only                    = true
  public_network_access_enabled = var.enable_private_endpoint ? false : var.public_network_access_enabled
  virtual_network_subnet_id     = startswith(var.sku_name, "Y") ? null : var.subnet_id
  functions_extension_version   = var.functions_extension_version

  site_config {
    ftps_state              = var.ftps_state
    http2_enabled           = var.http2_enabled
    minimum_tls_version     = var.minimum_tls_version
    vnet_route_all_enabled  = startswith(var.sku_name, "Y") ? false : (var.subnet_id != null ? true : false)
    use_32_bit_worker       = false

    # Elastic Premium features only
    # When zone_balancing_enabled = true, elastic_instance_minimum must be > 2 (Azure requirement)
    elastic_instance_minimum          = startswith(var.sku_name, "EP") ? (var.zone_balancing_enabled ? 3 : 1) : null
    runtime_scale_monitoring_enabled  = startswith(var.sku_name, "EP") ? true : false

    application_stack {
      dotnet_version              = var.runtime_name == "dotnet-isolated" || var.runtime_name == "dotnet" ? var.runtime_version : null
      use_dotnet_isolated_runtime = var.runtime_name == "dotnet-isolated" ? true : false
      node_version                = var.runtime_name == "node" ? var.runtime_version : null
      python_version              = var.runtime_name == "python" ? var.runtime_version : null
      java_version                = var.runtime_name == "java" ? var.runtime_version : null
      powershell_core_version     = var.runtime_name == "powershell" ? var.runtime_version : null
    }
  }

  identity {
    type = var.identity_type
  }

  app_settings = merge({
    "FUNCTIONS_WORKER_RUNTIME" = var.runtime_name == "dotnet-isolated" ? "dotnet-isolated" : var.runtime_name
    "WEBSITE_CONTENTOVERVNET"  = startswith(var.sku_name, "Y") ? "0" : (var.subnet_id != null ? "1" : "0")
  }, var.app_settings)

  tags = var.tags

  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
      app_settings["WEBSITE_CONTENTSHARE"],
    ]
  }
}

#--------------------------------------------------------------
# Private Endpoint
#--------------------------------------------------------------
resource "azurerm_private_endpoint" "this" {
  count = var.enable_private_endpoint ? 1 : 0

  name                = "pe-${var.function_app_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "psc-${var.function_app_name}"
    private_connection_resource_id = var.os_type == "Windows" ? azurerm_windows_function_app.this[0].id : azurerm_linux_function_app.this[0].id
    is_manual_connection           = false
    subresource_names              = ["sites"]
  }

  dynamic "private_dns_zone_group" {
    for_each = var.private_dns_zone_ids != null ? [1] : []
    content {
      name                 = "dns-zone-group"
      private_dns_zone_ids = var.private_dns_zone_ids
    }
  }

  tags = var.tags
}

