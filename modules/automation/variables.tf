#------------------------------------------------------------------------------
# Azure Automation Module Variables
#------------------------------------------------------------------------------

variable "automation_account_name" {
  description = "Name of the Azure Automation Account"
  type        = string
}

variable "location" {
  description = "Azure region for the Automation Account"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "resource_group_id" {
  description = "Resource ID of the primary resource group"
  type        = string
}

variable "secondary_resource_group_id" {
  description = "Resource ID of the secondary resource group (for cross-region failover)"
  type        = string
  default     = ""
}

variable "sql_mi_id" {
  description = "Resource ID of the SQL Managed Instance for role assignment"
  type        = string
  default     = ""
}

variable "redis_cache_id" {
  description = "Resource ID of the Redis Cache for role assignment"
  type        = string
  default     = ""
}

variable "runbook_name" {
  description = "Name of the DR failover runbook"
  type        = string
  default     = "Invoke-DRFailover"
}

variable "runbook_content" {
  description = "PowerShell content for the DR failover runbook"
  type        = string
}

variable "log_verbose" {
  description = "Enable verbose logging for runbook"
  type        = bool
  default     = true
}

variable "log_progress" {
  description = "Enable progress logging for runbook"
  type        = bool
  default     = true
}

variable "webhook_expiry_time" {
  description = "Expiry time for the webhook (RFC3339 format)"
  type        = string
  default     = "2026-12-31T00:00:00Z"
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for diagnostics"
  type        = string
  default     = ""
}

variable "public_network_access_enabled" {
  description = "Enable public network access to Automation Account"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
