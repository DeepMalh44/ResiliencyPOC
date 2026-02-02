#--------------------------------------------------------------
# Redis Cache Module - Main
# Premium tier with zone redundancy and geo-replication
#--------------------------------------------------------------

resource "azurerm_redis_cache" "this" {
  name                          = var.name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  capacity                      = var.capacity
  family                        = var.family
  sku_name                      = var.sku_name  # Premium required for zones
  
  # CRITICAL: Zone redundancy (Premium tier only)
  zones = var.zones
  
  # Network settings
  public_network_access_enabled = var.public_network_access_enabled
  
  # Redis settings
  non_ssl_port_enabled           = false
  minimum_tls_version           = var.minimum_tls_version
  
  # Redis configuration
  redis_configuration {
    maxmemory_reserved              = var.maxmemory_reserved
    maxmemory_delta                 = var.maxmemory_delta
    maxmemory_policy                = var.maxmemory_policy
    maxfragmentationmemory_reserved = var.maxfragmentationmemory_reserved
    rdb_backup_enabled              = var.rdb_backup_enabled
    rdb_backup_frequency            = var.rdb_backup_frequency
    rdb_backup_max_snapshot_count   = var.rdb_backup_max_snapshot_count
    rdb_storage_connection_string   = var.rdb_storage_connection_string
    aof_backup_enabled              = var.aof_backup_enabled
    aof_storage_connection_string_0 = var.aof_storage_connection_string_0
    aof_storage_connection_string_1 = var.aof_storage_connection_string_1
  }

  # Patch schedule for maintenance
  dynamic "patch_schedule" {
    for_each = var.patch_schedules
    content {
      day_of_week        = patch_schedule.value.day_of_week
      start_hour_utc     = patch_schedule.value.start_hour_utc
      maintenance_window = patch_schedule.value.maintenance_window
    }
  }

  # Identity for RBAC
  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

#--------------------------------------------------------------
# Diagnostic Settings
#--------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "this" {
  count = var.enable_diagnostics ? 1 : 0

  name                       = "diag-${var.name}"
  target_resource_id         = azurerm_redis_cache.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "ConnectedClientList"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}


