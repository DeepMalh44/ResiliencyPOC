#--------------------------------------------------------------
# APIM Module - Variables
#--------------------------------------------------------------

variable "name" {
  description = "Name of the API Management instance"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for APIM"
  type        = string
}

variable "publisher_name" {
  description = "Publisher name for APIM"
  type        = string
}

variable "publisher_email" {
  description = "Publisher email for APIM"
  type        = string
}

variable "sku_name" {
  description = "SKU name (Premium required for multi-region and zones)"
  type        = string
  default     = "Premium"
}

variable "sku_capacity" {
  description = "Number of APIM units (minimum 2 for zone redundancy)"
  type        = number
  default     = 2
}

variable "zones" {
  description = "Availability zones for zone redundancy"
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "virtual_network_type" {
  description = "VNet integration type (None, External, Internal)"
  type        = string
  default     = "Internal"
}

variable "subnet_id" {
  description = "Subnet ID for VNet integration"
  type        = string
  default     = null
}

variable "public_network_access_enabled" {
  description = "Enable public network access"
  type        = bool
  default     = false
}

variable "user_assigned_identity_ids" {
  description = "List of user-assigned identity IDs"
  type        = list(string)
  default     = null
}

variable "min_api_version" {
  description = "Minimum API version"
  type        = string
  default     = "2021-08-01"
}

variable "enable_http2" {
  description = "Enable HTTP/2 protocol"
  type        = bool
  default     = true
}

variable "sign_up_enabled" {
  description = "Enable developer portal sign-up"
  type        = bool
  default     = false
}

variable "terms_consent_required" {
  description = "Require terms consent"
  type        = bool
  default     = false
}

variable "terms_enabled" {
  description = "Enable terms of service"
  type        = bool
  default     = false
}

variable "terms_text" {
  description = "Terms of service text"
  type        = string
  default     = ""
}

variable "named_values" {
  description = "Map of named values to create"
  type = map(object({
    display_name        = string
    value               = optional(string)
    secret              = optional(bool, false)
    key_vault_secret_id = optional(string)
  }))
  default = {}
}

#--------------------------------------------------------------
# Private Endpoint Variables
#--------------------------------------------------------------
variable "enable_private_endpoint" {
  description = "Enable private endpoint for APIM"
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


variable "additional_locations" {
  description = "Additional locations for multi-region deployment"
  type = list(object({
    location             = string
    capacity             = number
    zones                = list(string)
    subnet_id            = string
    public_ip_address_id = optional(string)
  }))
  default = []
}

variable "instrumentation_key" {
  description = "Application Insights instrumentation key"
  type        = string
  default     = null
  sensitive   = true
}

variable "public_ip_address_id" {
  description = "Public IP address ID (required for Premium with zones)"
  type        = string
  default     = null
}

variable "enable_diagnostics" {
  description = "Enable diagnostic settings"
  type        = bool
  default     = true
}

variable "enable_diagnostics" {
  description = "Enable diagnostic settings"
  type        = bool
  default     = true
}

