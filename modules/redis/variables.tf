#--------------------------------------------------------------
# Redis Cache Module - Variables
#--------------------------------------------------------------

variable "name" {
  description = "Name of the Redis cache"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for the Redis cache"
  type        = string
}

variable "capacity" {
  description = "Redis cache capacity (size)"
  type        = number
  default     = 1
}

variable "family" {
  description = "Redis cache family (C for Basic/Standard, P for Premium)"
  type        = string
  default     = "P"
}

variable "sku_name" {
  description = "Redis cache SKU (Basic, Standard, Premium)"
  type        = string
  default     = "Premium"
}

variable "zones" {
  description = "Availability zones for zone redundancy"
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "public_network_access_enabled" {
  description = "Enable public network access"
  type        = bool
  default     = false
}

variable "minimum_tls_version" {
  description = "Minimum TLS version"
  type        = string
  default     = "1.2"
}

variable "maxmemory_reserved" {
  description = "Memory reserved for non-cache operations (MB)"
  type        = number
  default     = 50
}

variable "maxmemory_delta" {
  description = "Memory reserved for cache fragmentation (MB)"
  type        = number
  default     = 50
}

variable "maxmemory_policy" {
  description = "Policy for handling memory limit"
  type        = string
  default     = "volatile-lru"
}

variable "maxfragmentationmemory_reserved" {
  description = "Memory reserved for fragmentation (MB)"
  type        = number
  default     = 50
}

variable "rdb_backup_enabled" {
  description = "Enable RDB backup"
  type        = bool
  default     = false
}

variable "rdb_backup_frequency" {
  description = "RDB backup frequency in minutes"
  type        = number
  default     = 60
}

variable "rdb_backup_max_snapshot_count" {
  description = "Maximum number of RDB snapshots"
  type        = number
  default     = 1
}

variable "rdb_storage_connection_string" {
  description = "Storage connection string for RDB backups"
  type        = string
  default     = null
  sensitive   = true
}

variable "aof_backup_enabled" {
  description = "Enable AOF backup"
  type        = bool
  default     = false
}

variable "aof_storage_connection_string_0" {
  description = "Storage connection string for AOF backup (primary)"
  type        = string
  default     = null
  sensitive   = true
}

variable "aof_storage_connection_string_1" {
  description = "Storage connection string for AOF backup (secondary)"
  type        = string
  default     = null
  sensitive   = true
}

variable "patch_schedules" {
  description = "Patch schedules for maintenance"
  type = list(object({
    day_of_week        = string
    start_hour_utc     = optional(number)
    maintenance_window = optional(string)
  }))
  default = [
    {
      day_of_week    = "Sunday"
      start_hour_utc = 2
    }
  ]
}

#--------------------------------------------------------------
# Geo-Replication Variables
#--------------------------------------------------------------
variable "linked_redis_cache_id" {
  description = "ID of the Redis cache to link for geo-replication"
  type        = string
  default     = null
}

variable "linked_redis_cache_location" {
  description = "Location of the linked Redis cache"
  type        = string
  default     = null
}

variable "server_role" {
  description = "Server role for geo-replication (Primary or Secondary)"
  type        = string
  default     = "Secondary"
}

#--------------------------------------------------------------
# Private Endpoint Variables
#--------------------------------------------------------------
variable "enable_private_endpoint" {
  description = "Enable private endpoint"
  type        = bool
  default     = true
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID for private endpoint"
  type        = string
  default     = null
}

variable "private_dns_zone_ids" {
  description = "Private DNS zone IDs for private endpoint"
  type        = list(string)
  default     = null
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


variable "non_ssl_port_enabled" {
  description = "Enable non-SSL port"
  type        = bool
  default     = false
}

variable "enable_geo_replication" {
  description = "Enable geo-replication"
  type        = bool
  default     = false
}

variable "enable_diagnostics" {
  description = "Enable diagnostic settings for Redis"
  type        = bool
  default     = true
}

