#--------------------------------------------------------------
# Storage Account Module - Variables
#--------------------------------------------------------------

variable "name" {
  description = "Name of the storage account (must be globally unique)"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for the storage account"
  type        = string
}

variable "account_tier" {
  description = "Storage account tier"
  type        = string
  default     = "Standard"
}

variable "account_replication_type" {
  description = "Storage account replication type (LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS)"
  type        = string
  default     = "RAGZRS" # Zone + Geo redundancy with read access
}

variable "account_kind" {
  description = "Storage account kind"
  type        = string
  default     = "StorageV2"
}

variable "public_network_access_enabled" {
  description = "Enable public network access"
  type        = bool
  default     = false
}

variable "shared_access_key_enabled" {
  description = "Enable shared access key (disable for RBAC-only)"
  type        = bool
  default     = false
}

variable "infrastructure_encryption_enabled" {
  description = "Enable infrastructure encryption"
  type        = bool
  default     = true
}

variable "is_hns_enabled" {
  description = "Enable hierarchical namespace (Data Lake Gen2)"
  type        = bool
  default     = false
}

variable "versioning_enabled" {
  description = "Enable blob versioning"
  type        = bool
  default     = true
}

variable "blob_soft_delete_retention_days" {
  description = "Blob soft delete retention days"
  type        = number
  default     = 30
}

variable "container_soft_delete_retention_days" {
  description = "Container soft delete retention days"
  type        = number
  default     = 30
}

variable "cors_rules" {
  description = "CORS rules for blob storage"
  type = list(object({
    allowed_headers    = list(string)
    allowed_methods    = list(string)
    allowed_origins    = list(string)
    exposed_headers    = list(string)
    max_age_in_seconds = number
  }))
  default = []
}

variable "allowed_ip_ranges" {
  description = "Allowed IP ranges for network rules"
  type        = list(string)
  default     = []
}

variable "allowed_subnet_ids" {
  description = "Allowed subnet IDs for network rules"
  type        = list(string)
  default     = []
}

variable "enable_advanced_threat_protection" {
  description = "Enable advanced threat protection"
  type        = bool
  default     = true
}

variable "containers" {
  description = "Map of storage containers to create"
  type = map(object({
    access_type = optional(string, "private")
  }))
  default = {}
}

variable "queues" {
  description = "Map of storage queues to create"
  type        = map(object({}))
  default     = {}
}

variable "file_shares" {
  description = "Map of file shares to create"
  type = map(object({
    quota       = number
    access_tier = optional(string, "Hot")
  }))
  default = {}
}

variable "tables" {
  description = "Map of storage tables to create"
  type        = map(object({}))
  default     = {}
}

variable "enable_private_endpoint" {
  description = "Enable private endpoints"
  type        = bool
  default     = true
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID for private endpoints"
  type        = string
  default     = null
}

variable "blob_private_dns_zone_ids" {
  description = "Private DNS zone IDs for blob endpoint"
  type        = list(string)
  default     = null
}

variable "file_private_dns_zone_ids" {
  description = "Private DNS zone IDs for file endpoint"
  type        = list(string)
  default     = null
}

variable "queue_private_dns_zone_ids" {
  description = "Private DNS zone IDs for queue endpoint"
  type        = list(string)
  default     = null
}

variable "table_private_dns_zone_ids" {
  description = "Private DNS zone IDs for table endpoint"
  type        = list(string)
  default     = null
}

variable "create_file_private_endpoint" {
  description = "Create file private endpoint"
  type        = bool
  default     = true
}

variable "create_queue_private_endpoint" {
  description = "Create queue private endpoint"
  type        = bool
  default     = true
}

variable "create_table_private_endpoint" {
  description = "Create table private endpoint"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for diagnostics"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}


variable "min_tls_version" {
  description = "Minimum TLS version"
  type        = string
  default     = "TLS1_2"
}

variable "allow_nested_items_to_be_public" {
  description = "Allow nested items to be public"
  type        = bool
  default     = false
}

variable "default_to_oauth_authentication" {
  description = "Default to OAuth authentication"
  type        = bool
  default     = true
}

variable "network_rules" {
  description = "Network rules for storage account"
  type = object({
    default_action             = string
    bypass                     = list(string)
    ip_rules                   = list(string)
    virtual_network_subnet_ids = list(string)
  })
  default = {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    ip_rules                   = []
    virtual_network_subnet_ids = []
  }
}

variable "enable_private_endpoints" {
  description = "Enable private endpoints"
  type        = bool
  default     = true
}

variable "blob_private_dns_zone_id" {
  description = "Private DNS zone ID for blob"
  type        = string
  default     = null
}

variable "file_private_dns_zone_id" {
  description = "Private DNS zone ID for file"
  type        = string
  default     = null
}

variable "queue_private_dns_zone_id" {
  description = "Private DNS zone ID for queue"
  type        = string
  default     = null
}

variable "table_private_dns_zone_id" {
  description = "Private DNS zone ID for table"
  type        = string
  default     = null
}

variable "enable_diagnostics" {
  description = "Enable diagnostic settings"
  type        = bool
  default     = true
}

