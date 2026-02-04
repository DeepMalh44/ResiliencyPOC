#------------------------------------------------------------------------------
# DR Alerts for Automated Failover
# These alerts trigger the Azure Automation runbook for automated failover
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Action Group for DR Failover with Webhook
#------------------------------------------------------------------------------
resource "azurerm_monitor_action_group" "dr_failover" {
  count = var.enable_dr_alerts ? 1 : 0

  name                = var.dr_action_group_name
  resource_group_name = var.resource_group_name
  short_name          = "drfailover"

  # Email notifications for DR events
  dynamic "email_receiver" {
    for_each = var.dr_alert_email_receivers
    content {
      name                    = email_receiver.value.name
      email_address           = email_receiver.value.email_address
      use_common_alert_schema = true
    }
  }

  # Webhook to trigger Automation Runbook
  dynamic "webhook_receiver" {
    for_each = var.dr_webhook_uri != "" ? [1] : []
    content {
      name                    = "DRFailoverRunbook"
      service_uri             = var.dr_webhook_uri
      use_common_alert_schema = true
    }
  }

  # Automation Runbook receiver (alternative to webhook)
  dynamic "automation_runbook_receiver" {
    for_each = var.dr_automation_account_id != "" ? [1] : []
    content {
      name                    = "DRFailoverRunbook"
      automation_account_id   = var.dr_automation_account_id
      runbook_name            = var.dr_runbook_name
      webhook_resource_id     = var.dr_webhook_resource_id
      is_global_runbook       = false
      service_uri             = var.dr_webhook_uri
      use_common_alert_schema = true
    }
  }

  tags = var.tags
}

#------------------------------------------------------------------------------
# SQL MI Availability Alert
# Triggers failover when SQL MI becomes unavailable
#------------------------------------------------------------------------------
resource "azurerm_monitor_metric_alert" "sql_mi_availability" {
  count = var.enable_dr_alerts && var.sql_mi_resource_id != "" ? 1 : 0

  name                = "alert-sqlmi-availability-critical"
  resource_group_name = var.resource_group_name
  scopes              = [var.sql_mi_resource_id]
  description         = "SQL Managed Instance availability dropped below threshold - potential DR trigger"
  severity            = 0 # Critical
  enabled             = true
  frequency           = "PT1M"
  window_size         = "PT5M"
  auto_mitigate       = false # Don't auto-resolve - requires manual confirmation after failover

  criteria {
    metric_namespace = "Microsoft.Sql/managedInstances"
    metric_name      = "avg_cpu_percent"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 0 # 0% CPU = instance unavailable
  }

  action {
    action_group_id = azurerm_monitor_action_group.dr_failover[0].id
  }

  tags = merge(var.tags, {
    "AlertType" = "DR-Critical"
    "Component" = "SQL-MI"
  })
}

#------------------------------------------------------------------------------
# SQL MI Connection Failures Alert
#------------------------------------------------------------------------------
resource "azurerm_monitor_activity_log_alert" "sql_mi_health" {
  count = var.enable_dr_alerts && var.sql_mi_resource_id != "" ? 1 : 0

  name                = "alert-sqlmi-health-degraded"
  resource_group_name = var.resource_group_name
  scopes              = [var.subscription_id]
  description         = "SQL Managed Instance health degraded - potential DR trigger"
  enabled             = true

  criteria {
    category = "ResourceHealth"

    resource_health {
      current  = ["Degraded", "Unavailable"]
      previous = ["Available"]
      reason   = ["PlatformInitiated", "Unknown"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.dr_failover[0].id
  }

  tags = merge(var.tags, {
    "AlertType" = "DR-Critical"
    "Component" = "SQL-MI"
  })
}

#------------------------------------------------------------------------------
# App Service Availability Alert
#------------------------------------------------------------------------------
resource "azurerm_monitor_metric_alert" "app_service_availability" {
  count = var.enable_dr_alerts && length(var.app_service_resource_ids) > 0 ? 1 : 0

  name                = "alert-appservice-availability-critical"
  resource_group_name = var.resource_group_name
  scopes              = var.app_service_resource_ids
  description         = "App Service availability dropped below 90% - potential region outage"
  severity            = 0 # Critical
  enabled             = true
  frequency           = "PT1M"
  window_size         = "PT5M"
  auto_mitigate       = false

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "HealthCheckStatus"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 90 # Less than 90% healthy
  }

  action {
    action_group_id = azurerm_monitor_action_group.dr_failover[0].id
  }

  tags = merge(var.tags, {
    "AlertType" = "DR-Critical"
    "Component" = "App-Service"
  })
}

#------------------------------------------------------------------------------
# App Service HTTP 5xx Errors Alert
#------------------------------------------------------------------------------
resource "azurerm_monitor_metric_alert" "app_service_5xx_errors" {
  count = var.enable_dr_alerts && length(var.app_service_resource_ids) > 0 ? 1 : 0

  name                = "alert-appservice-5xx-critical"
  resource_group_name = var.resource_group_name
  scopes              = var.app_service_resource_ids
  description         = "App Service experiencing high 5xx error rate - potential region outage"
  severity            = 0 # Critical
  enabled             = true
  frequency           = "PT1M"
  window_size         = "PT5M"
  auto_mitigate       = false

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 100 # More than 100 5xx errors in 5 minutes
  }

  action {
    action_group_id = azurerm_monitor_action_group.dr_failover[0].id
  }

  tags = merge(var.tags, {
    "AlertType" = "DR-Warning"
    "Component" = "App-Service"
  })
}

#------------------------------------------------------------------------------
# Redis Cache Availability Alert
#------------------------------------------------------------------------------
resource "azurerm_monitor_metric_alert" "redis_availability" {
  count = var.enable_dr_alerts && var.redis_cache_resource_id != "" ? 1 : 0

  name                = "alert-redis-availability-critical"
  resource_group_name = var.resource_group_name
  scopes              = [var.redis_cache_resource_id]
  description         = "Redis Cache server load critical - potential region outage"
  severity            = 0 # Critical
  enabled             = true
  frequency           = "PT1M"
  window_size         = "PT5M"
  auto_mitigate       = false

  criteria {
    metric_namespace = "Microsoft.Cache/redis"
    metric_name      = "serverLoad"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 99 # Server load > 99% = effectively unavailable
  }

  action {
    action_group_id = azurerm_monitor_action_group.dr_failover[0].id
  }

  tags = merge(var.tags, {
    "AlertType" = "DR-Critical"
    "Component" = "Redis"
  })
}

#------------------------------------------------------------------------------
# Redis Cache Connectivity Alert
#------------------------------------------------------------------------------
resource "azurerm_monitor_metric_alert" "redis_connected_clients" {
  count = var.enable_dr_alerts && var.redis_cache_resource_id != "" ? 1 : 0

  name                = "alert-redis-connectivity-critical"
  resource_group_name = var.resource_group_name
  scopes              = [var.redis_cache_resource_id]
  description         = "Redis Cache lost all connections - potential region outage"
  severity            = 0 # Critical
  enabled             = true
  frequency           = "PT1M"
  window_size         = "PT5M"
  auto_mitigate       = false

  criteria {
    metric_namespace = "Microsoft.Cache/redis"
    metric_name      = "connectedclients"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1 # No connected clients = unavailable
  }

  action {
    action_group_id = azurerm_monitor_action_group.dr_failover[0].id
  }

  tags = merge(var.tags, {
    "AlertType" = "DR-Critical"
    "Component" = "Redis"
  })
}

#------------------------------------------------------------------------------
# Front Door Health Probe Alert
#------------------------------------------------------------------------------
resource "azurerm_monitor_metric_alert" "frontdoor_backend_health" {
  count = var.enable_dr_alerts && var.front_door_resource_id != "" ? 1 : 0

  name                = "alert-frontdoor-backend-health-critical"
  resource_group_name = var.resource_group_name
  scopes              = [var.front_door_resource_id]
  description         = "Front Door backend health percentage dropped - multiple backend failures"
  severity            = 1 # Warning (Front Door handles failover automatically)
  enabled             = true
  frequency           = "PT1M"
  window_size         = "PT5M"
  auto_mitigate       = true

  criteria {
    metric_namespace = "Microsoft.Cdn/profiles"
    metric_name      = "OriginHealthPercentage"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 50 # Less than 50% backends healthy
  }

  action {
    action_group_id = azurerm_monitor_action_group.dr_failover[0].id
  }

  tags = merge(var.tags, {
    "AlertType" = "DR-Warning"
    "Component" = "Front-Door"
  })
}

#------------------------------------------------------------------------------
# Regional Outage Alert (Activity Log)
#------------------------------------------------------------------------------
resource "azurerm_monitor_activity_log_alert" "region_outage" {
  count = var.enable_dr_alerts ? 1 : 0

  name                = "alert-region-service-health"
  resource_group_name = var.resource_group_name
  scopes              = [var.subscription_id]
  description         = "Azure service health incident in primary region"
  enabled             = true

  criteria {
    category = "ServiceHealth"

    service_health {
      locations = var.dr_monitored_regions
      events    = ["Incident", "Maintenance"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.dr_failover[0].id
  }

  tags = merge(var.tags, {
    "AlertType" = "DR-Critical"
    "Component" = "Region-Health"
  })
}
