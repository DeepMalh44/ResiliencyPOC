#------------------------------------------------------------------------------
# Azure Automation Account Module
# Provides infrastructure for automated DR failover triggered by alerts
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Automation Account
#------------------------------------------------------------------------------
resource "azurerm_automation_account" "this" {
  name                          = var.automation_account_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku_name                      = "Basic"
  public_network_access_enabled = var.public_network_access_enabled

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

#------------------------------------------------------------------------------
# Role Assignments for Managed Identity
# Grant the Automation Account permissions to manage failover resources
#------------------------------------------------------------------------------

# Contributor role on the resource group for managing resources
resource "azurerm_role_assignment" "automation_contributor" {
  scope                = var.resource_group_id
  role_definition_name = "Contributor"
  principal_id         = azurerm_automation_account.this.identity[0].principal_id
}

# If secondary resource group is different, grant access there too
resource "azurerm_role_assignment" "automation_contributor_secondary" {
  count                = var.secondary_resource_group_id != "" ? 1 : 0
  scope                = var.secondary_resource_group_id
  role_definition_name = "Contributor"
  principal_id         = azurerm_automation_account.this.identity[0].principal_id
}

# SQL MI Contributor for failover group management
resource "azurerm_role_assignment" "sql_mi_contributor" {
  count                = var.sql_mi_id != "" ? 1 : 0
  scope                = var.sql_mi_id
  role_definition_name = "SQL Managed Instance Contributor"
  principal_id         = azurerm_automation_account.this.identity[0].principal_id
}

# Redis Cache Contributor for geo-replication failover
resource "azurerm_role_assignment" "redis_contributor" {
  count                = var.redis_cache_id != "" ? 1 : 0
  scope                = var.redis_cache_id
  role_definition_name = "Redis Cache Contributor"
  principal_id         = azurerm_automation_account.this.identity[0].principal_id
}

#------------------------------------------------------------------------------
# Az Modules for Runbook
#------------------------------------------------------------------------------
resource "azurerm_automation_module" "az_accounts" {
  name                    = "Az.Accounts"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.this.name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Accounts/3.0.0"
  }
}

resource "azurerm_automation_module" "az_sql" {
  name                    = "Az.Sql"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.this.name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Sql/5.2.0"
  }

  depends_on = [azurerm_automation_module.az_accounts]
}

resource "azurerm_automation_module" "az_redis_cache" {
  name                    = "Az.RedisCache"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.this.name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.RedisCache/1.9.0"
  }

  depends_on = [azurerm_automation_module.az_accounts]
}

resource "azurerm_automation_module" "az_websites" {
  name                    = "Az.Websites"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.this.name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Websites/3.2.0"
  }

  depends_on = [azurerm_automation_module.az_accounts]
}

#------------------------------------------------------------------------------
# Runbook for DR Failover
#------------------------------------------------------------------------------
resource "azurerm_automation_runbook" "dr_failover" {
  name                    = var.runbook_name
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.this.name
  log_verbose             = var.log_verbose
  log_progress            = var.log_progress
  description             = "Automated DR failover runbook triggered by Azure Monitor alerts"
  runbook_type            = "PowerShell"

  content = var.runbook_content

  depends_on = [
    azurerm_automation_module.az_accounts,
    azurerm_automation_module.az_sql,
    azurerm_automation_module.az_redis_cache,
    azurerm_automation_module.az_websites
  ]

  tags = var.tags
}

#------------------------------------------------------------------------------
# Webhook for Alert-Triggered Execution
#------------------------------------------------------------------------------
resource "azurerm_automation_webhook" "dr_failover" {
  name                    = "${var.runbook_name}-webhook"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.this.name
  expiry_time             = var.webhook_expiry_time
  enabled                 = true
  runbook_name            = azurerm_automation_runbook.dr_failover.name

  parameters = {
    FailoverType = "Auto"
  }
}

#------------------------------------------------------------------------------
# Diagnostic Settings for Automation Account
#------------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "automation" {
  count                      = var.log_analytics_workspace_id != "" ? 1 : 0
  name                       = "${var.automation_account_name}-diag"
  target_resource_id         = azurerm_automation_account.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "JobLogs"
  }

  enabled_log {
    category = "JobStreams"
  }

  enabled_log {
    category = "DscNodeStatus"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
