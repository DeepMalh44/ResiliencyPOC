#--------------------------------------------------------------
# App Service Module - Main
# Supports Free (F1), Basic (B1), Standard (S1), Premium tiers
#--------------------------------------------------------------

#--------------------------------------------------------------
# App Service Plan
#--------------------------------------------------------------
resource "azurerm_service_plan" "this" {
  name                = var.app_service_plan_name
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = var.os_type
  sku_name            = var.sku_name

  # Zone balancing only for Premium/Standard tiers, not Free/Basic/Consumption
  zone_balancing_enabled = can(regex("^(P|S)[0-9]v[0-9]|^P[0-9]|^S[0-9]$", var.sku_name)) ? var.zone_balancing_enabled : false

  # Worker count only for paid tiers
  worker_count = can(regex("^F[0-9]|^D[0-9]|^B[0-9]$", var.sku_name)) ? null : var.worker_count

  tags = var.tags
}

#--------------------------------------------------------------
# Windows Web App
#--------------------------------------------------------------
resource "azurerm_windows_web_app" "this" {
  count = var.os_type == "Windows" ? 1 : 0

  name                          = var.app_service_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  service_plan_id               = azurerm_service_plan.this.id
  https_only                    = true
  public_network_access_enabled = var.enable_private_endpoint ? false : var.public_network_access_enabled
  # VNet integration not supported for Free/Shared tiers
  virtual_network_subnet_id = can(regex("^F[0-9]|^D[0-9]$", var.sku_name)) ? null : var.subnet_id

  site_config {
    # always_on not supported for Free/Shared tiers
    always_on              = can(regex("^F[0-9]|^D[0-9]$", var.sku_name)) ? false : var.always_on
    ftps_state             = var.ftps_state
    http2_enabled          = var.http2_enabled
    minimum_tls_version    = var.minimum_tls_version
    vnet_route_all_enabled = can(regex("^F[0-9]|^D[0-9]$", var.sku_name)) ? false : (var.subnet_id != null ? true : false)
    health_check_path      = var.health_check_path

    application_stack {
      current_stack  = "dotnet"
      dotnet_version = var.dotnet_version
    }
  }

  identity {
    type = var.identity_type
  }

  app_settings = var.app_settings

  tags = var.tags

  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
    ]
  }
}

#--------------------------------------------------------------
# Linux Web App
#--------------------------------------------------------------
resource "azurerm_linux_web_app" "this" {
  count = var.os_type == "Linux" ? 1 : 0

  name                          = var.app_service_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  service_plan_id               = azurerm_service_plan.this.id
  https_only                    = true
  public_network_access_enabled = var.enable_private_endpoint ? false : var.public_network_access_enabled
  # VNet integration not supported for Free/Shared tiers
  virtual_network_subnet_id = can(regex("^F[0-9]|^D[0-9]$", var.sku_name)) ? null : var.subnet_id

  site_config {
    # always_on not supported for Free/Shared tiers
    always_on              = can(regex("^F[0-9]|^D[0-9]$", var.sku_name)) ? false : var.always_on
    ftps_state             = var.ftps_state
    http2_enabled          = var.http2_enabled
    minimum_tls_version    = var.minimum_tls_version
    vnet_route_all_enabled = can(regex("^F[0-9]|^D[0-9]$", var.sku_name)) ? false : (var.subnet_id != null ? true : false)
    health_check_path      = var.health_check_path

    application_stack {
      dotnet_version = var.dotnet_version
    }
  }

  identity {
    type = var.identity_type
  }

  app_settings = var.app_settings

  tags = var.tags

  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
    ]
  }
}

#--------------------------------------------------------------
# Deployment Slots (only for Standard and higher)
#--------------------------------------------------------------
resource "azurerm_windows_web_app_slot" "slots" {
  for_each = var.os_type == "Windows" && can(regex("^(P|S)[0-9]", var.sku_name)) ? toset(var.deployment_slots) : toset([])

  name           = each.key
  app_service_id = azurerm_windows_web_app.this[0].id

  site_config {
    always_on              = var.always_on
    ftps_state             = var.ftps_state
    http2_enabled          = var.http2_enabled
    minimum_tls_version    = var.minimum_tls_version
    vnet_route_all_enabled = var.subnet_id != null ? true : false

    application_stack {
      current_stack  = "dotnet"
      dotnet_version = var.dotnet_version
    }
  }

  identity {
    type = var.identity_type
  }

  app_settings = var.app_settings

  tags = var.tags
}

resource "azurerm_linux_web_app_slot" "slots" {
  for_each = var.os_type == "Linux" && can(regex("^(P|S)[0-9]", var.sku_name)) ? toset(var.deployment_slots) : toset([])

  name           = each.key
  app_service_id = azurerm_linux_web_app.this[0].id

  site_config {
    always_on              = var.always_on
    ftps_state             = var.ftps_state
    http2_enabled          = var.http2_enabled
    minimum_tls_version    = var.minimum_tls_version
    vnet_route_all_enabled = var.subnet_id != null ? true : false

    application_stack {
      dotnet_version = var.dotnet_version
    }
  }

  identity {
    type = var.identity_type
  }

  app_settings = var.app_settings

  tags = var.tags
}

#--------------------------------------------------------------
# Private Endpoint
#--------------------------------------------------------------
resource "azurerm_private_endpoint" "this" {
  count = var.enable_private_endpoint ? 1 : 0

  name                = "pe-${var.app_service_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "psc-${var.app_service_name}"
    private_connection_resource_id = var.os_type == "Windows" ? azurerm_windows_web_app.this[0].id : azurerm_linux_web_app.this[0].id
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

#--------------------------------------------------------------
# Autoscale (only for Standard and higher)
#--------------------------------------------------------------
resource "azurerm_monitor_autoscale_setting" "this" {
  count = var.enable_autoscale && can(regex("^(P|S)[0-9]", var.sku_name)) ? 1 : 0

  name                = "autoscale-${var.app_service_plan_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  target_resource_id  = azurerm_service_plan.this.id

  profile {
    name = "default"

    capacity {
      default = var.default_capacity
      minimum = var.min_capacity
      maximum = var.max_capacity
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.this.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.this.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30
      }
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }

  tags = var.tags
}

