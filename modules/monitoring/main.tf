#--------------------------------------------------------------
# Monitoring Module - Main
# Log Analytics, Application Insights, Alerts
#--------------------------------------------------------------

#--------------------------------------------------------------
# Log Analytics Workspace
#--------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "this" {
  name                = var.log_analytics_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.log_analytics_sku
  retention_in_days   = var.retention_in_days
  daily_quota_gb      = var.daily_quota_gb

  tags = var.tags
}

#--------------------------------------------------------------
# Application Insights
#--------------------------------------------------------------
resource "azurerm_application_insights" "this" {
  for_each = var.application_insights

  name                = each.key
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.this.id
  application_type    = each.value.application_type
  retention_in_days   = each.value.retention_in_days
  sampling_percentage = each.value.sampling_percentage

  disable_ip_masking = each.value.disable_ip_masking

  tags = var.tags
}

#--------------------------------------------------------------
# Action Group for Alerts
#--------------------------------------------------------------
resource "azurerm_monitor_action_group" "this" {
  for_each = var.action_groups

  name                = each.key
  resource_group_name = var.resource_group_name
  short_name          = each.value.short_name

  dynamic "email_receiver" {
    for_each = each.value.email_receivers != null ? each.value.email_receivers : []
    content {
      name                    = email_receiver.value.name
      email_address           = email_receiver.value.email_address
      use_common_alert_schema = email_receiver.value.use_common_alert_schema
    }
  }

  dynamic "sms_receiver" {
    for_each = each.value.sms_receivers != null ? each.value.sms_receivers : []
    content {
      name         = sms_receiver.value.name
      country_code = sms_receiver.value.country_code
      phone_number = sms_receiver.value.phone_number
    }
  }

  dynamic "webhook_receiver" {
    for_each = each.value.webhook_receivers != null ? each.value.webhook_receivers : []
    content {
      name                    = webhook_receiver.value.name
      service_uri             = webhook_receiver.value.service_uri
      use_common_alert_schema = webhook_receiver.value.use_common_alert_schema
    }
  }

  dynamic "azure_app_push_receiver" {
    for_each = each.value.azure_app_push_receivers != null ? each.value.azure_app_push_receivers : []
    content {
      name          = azure_app_push_receiver.value.name
      email_address = azure_app_push_receiver.value.email_address
    }
  }

  tags = var.tags
}

#--------------------------------------------------------------
# Metric Alerts
#--------------------------------------------------------------
resource "azurerm_monitor_metric_alert" "alerts" {
  for_each = var.metric_alerts

  name                = each.key
  resource_group_name = var.resource_group_name
  scopes              = each.value.scopes
  description         = each.value.description
  severity            = each.value.severity
  enabled             = each.value.enabled
  frequency           = each.value.frequency
  window_size         = each.value.window_size
  auto_mitigate       = each.value.auto_mitigate

  dynamic "criteria" {
    for_each = each.value.criteria != null ? each.value.criteria : []
    content {
      metric_namespace = criteria.value.metric_namespace
      metric_name      = criteria.value.metric_name
      aggregation      = criteria.value.aggregation
      operator         = criteria.value.operator
      threshold        = criteria.value.threshold

      dynamic "dimension" {
        for_each = criteria.value.dimensions != null ? criteria.value.dimensions : []
        content {
          name     = dimension.value.name
          operator = dimension.value.operator
          values   = dimension.value.values
        }
      }
    }
  }

  dynamic "action" {
    for_each = each.value.action_group_names != null ? each.value.action_group_names : []
    content {
      action_group_id = azurerm_monitor_action_group.this[action.value].id
    }
  }

  tags = var.tags
}

#--------------------------------------------------------------
# Activity Log Alerts
#--------------------------------------------------------------
resource "azurerm_monitor_activity_log_alert" "alerts" {
  for_each = var.activity_log_alerts

  name                = each.key
  resource_group_name = var.resource_group_name
  scopes              = each.value.scopes
  description         = each.value.description
  enabled             = each.value.enabled

  criteria {
    category       = each.value.criteria.category
    operation_name = each.value.criteria.operation_name
    level          = each.value.criteria.level
    status         = each.value.criteria.status

    dynamic "resource_health" {
      for_each = each.value.criteria.resource_health != null ? [each.value.criteria.resource_health] : []
      content {
        current  = resource_health.value.current
        previous = resource_health.value.previous
        reason   = resource_health.value.reason
      }
    }
  }

  dynamic "action" {
    for_each = each.value.action_group_names != null ? each.value.action_group_names : []
    content {
      action_group_id = azurerm_monitor_action_group.this[action.value].id
    }
  }

  tags = var.tags
}
