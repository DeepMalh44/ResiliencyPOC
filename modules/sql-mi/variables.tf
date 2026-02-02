#--------------------------------------------------------------
# SQL MI Module - Variables
#--------------------------------------------------------------

variable "name" {
  description = "Name of the SQL Managed Instance"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for the SQL MI"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for SQL MI (must be delegated)"
  type        = string
}

variable "administrator_login" {
  description = "Administrator login name"
  type        = string
  default     = "sqladmin"
}

variable "administrator_password" {
  description = "Administrator login password"
  type        = string
  sensitive   = true
}

variable "license_type" {
  description = "License type (LicenseIncluded or BasePrice)"
  type        = string
  default     = "BasePrice"
}

variable "sku_name" {
  description = "SKU name (BC_Gen5 for Business Critical with zone redundancy)"
  type        = string
  default     = "BC_Gen5"
}

variable "storage_size_in_gb" {
  description = "Storage size in GB"
  type        = number
  default     = 256
}

variable "vcores" {
  description = "Number of vCores"
  type        = number
  default     = 4
}

variable "zone_redundant" {
  description = "Enable zone redundancy (requires Business Critical tier)"
  type        = bool
  default     = true
}

variable "dns_zone_partner_id" {
  description = "DNS zone partner ID (for failover group, use primary instance ID)"
  type        = string
  default     = null
}

variable "minimum_tls_version" {
  description = "Minimum TLS version"
  type        = string
  default     = "1.2"
}

variable "public_data_endpoint_enabled" {
  description = "Enable public data endpoint"
  type        = bool
  default     = false
}

variable "proxy_override" {
  description = "Proxy override (Default, Proxy, or Redirect). Azure SQL MI uses 'Redirect' by default for better performance."
  type        = string
  default     = "Redirect"  # Redirect is Azure's default for better performance within VNet
}

variable "timezone_id" {
  description = "Timezone ID"
  type        = string
  default     = "UTC"
}

variable "backup_storage_redundancy" {
  description = "Backup storage redundancy type (Geo, Local, Zone, GeoZone). Using Local for POC."
  type        = string
  default     = "Local"  # Local (LRS) for POC - simplest option, no cross-region complexity
}

variable "maintenance_configuration_name" {
  description = "Maintenance configuration name"
  type        = string
  default     = "SQL_Default"
}

#--------------------------------------------------------------
# Azure AD Admin Variables
#--------------------------------------------------------------
variable "azure_ad_admin_login" {
  description = "Azure AD admin login name"
  type        = string
  default     = null
}

variable "azure_ad_admin_object_id" {
  description = "Azure AD admin object ID"
  type        = string
  default     = null
}

variable "azure_ad_admin_tenant_id" {
  description = "Azure AD admin tenant ID"
  type        = string
  default     = null
}

variable "azuread_authentication_only" {
  description = "Enable Azure AD authentication only (disable SQL auth)"
  type        = bool
  default     = false
}

#--------------------------------------------------------------
# Failover Group Variables
#--------------------------------------------------------------
variable "create_failover_group" {
  description = "Create a failover group"
  type        = bool
  default     = false
}

variable "failover_group_name" {
  description = "Name of the failover group"
  type        = string
  default     = null
}

variable "partner_managed_instance_id" {
  description = "Partner managed instance ID for failover group"
  type        = string
  default     = null
}

variable "failover_mode" {
  description = "Failover mode (Automatic or Manual)"
  type        = string
  default     = "Automatic"
}

variable "grace_period_minutes" {
  description = "Grace period in minutes before failover (aligns with RTO)"
  type        = number
  default     = 60  # 1 hour = your RTO
}

#--------------------------------------------------------------
# Database Variables
#--------------------------------------------------------------
variable "databases" {
  description = "Map of databases to create"
  type = map(object({
    short_term_retention_days = optional(number, 7)
    long_term_retention = optional(object({
      weekly_retention  = optional(string)
      monthly_retention = optional(string)
      yearly_retention  = optional(string)
      week_of_year      = optional(number)
    }))
    restore_point_in_time = optional(string)
    source_database_id    = optional(string)
  }))
  default = {}
}

#--------------------------------------------------------------
# Vulnerability Assessment Variables
#--------------------------------------------------------------
variable "vulnerability_assessment_storage_container_path" {
  description = "Storage container path for vulnerability assessment"
  type        = string
  default     = null
}

variable "vulnerability_assessment_storage_account_access_key" {
  description = "Storage account access key for vulnerability assessment"
  type        = string
  default     = null
  sensitive   = true
}

variable "vulnerability_assessment_emails" {
  description = "Emails for vulnerability assessment notifications"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}



#--------------------------------------------------------------
# Additional Variables for azapi_resource
#--------------------------------------------------------------
variable "collation" {
  description = "SQL collation"
  type        = string
  default     = "SQL_Latin1_General_CP1_CI_AS"
}

variable "enable_diagnostics" {
  description = "Enable diagnostic settings"
  type        = bool
  default     = false
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for diagnostics"
  type        = string
  default     = null
}
