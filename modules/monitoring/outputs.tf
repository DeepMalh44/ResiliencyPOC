#--------------------------------------------------------------
# Monitoring Module - Outputs
#--------------------------------------------------------------

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.this.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.this.name
}

output "log_analytics_workspace_customer_id" {
  description = "Customer ID (Workspace ID) of Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.this.workspace_id
}

output "log_analytics_primary_shared_key" {
  description = "Primary shared key of Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.this.primary_shared_key
  sensitive   = true
}

output "application_insights" {
  description = "Map of Application Insights outputs"
  value = {
    for k, v in azurerm_application_insights.this : k => {
      id                  = v.id
      name                = v.name
      app_id              = v.app_id
      instrumentation_key = v.instrumentation_key
      connection_string   = v.connection_string
    }
  }
  sensitive = true
}

output "action_groups" {
  description = "Map of Action Group outputs"
  value = {
    for k, v in azurerm_monitor_action_group.this : k => {
      id   = v.id
      name = v.name
    }
  }
}

output "metric_alerts" {
  description = "Map of Metric Alert outputs"
  value = {
    for k, v in azurerm_monitor_metric_alert.alerts : k => {
      id   = v.id
      name = v.name
    }
  }
}

output "activity_log_alerts" {
  description = "Map of Activity Log Alert outputs"
  value = {
    for k, v in azurerm_monitor_activity_log_alert.alerts : k => {
      id   = v.id
      name = v.name
    }
  }
}

