#--------------------------------------------------------------
# App Service Module - Variables (Simplified Interface)
#--------------------------------------------------------------

variable "app_service_plan_name" {
  description = "Name of the App Service Plan"
  type        = string
}

variable "app_service_name" {
  description = "Name of the App Service (Web App)"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for the App Service"
  type        = string
}

variable "os_type" {
  description = "OS type (Linux or Windows)"
  type        = string
  default     = "Windows"
}

variable "sku_name" {
  description = "SKU name for the App Service Plan"
  type        = string
  default     = "P1v3"
}

variable "zone_balancing_enabled" {
  description = "Enable zone balancing for high availability"
  type        = bool
  default     = true
}

variable "worker_count" {
  description = "Number of workers (minimum 3 for zone redundancy)"
  type        = number
  default     = 3
}

variable "public_network_access_enabled" {
  description = "Enable public network access"
  type        = bool
  default     = false
}

variable "subnet_id" {
  description = "Subnet ID for VNet integration"
  type        = string
  default     = null
}

variable "always_on" {
  description = "Keep the app always on"
  type        = bool
  default     = true
}

variable "minimum_tls_version" {
  description = "Minimum TLS version"
  type        = string
  default     = "1.2"
}

variable "ftps_state" {
  description = "FTPS state (Disabled, AllAllowed, FtpsOnly)"
  type        = string
  default     = "Disabled"
}

variable "http2_enabled" {
  description = "Enable HTTP/2"
  type        = bool
  default     = true
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/health"
}

variable "dotnet_version" {
  description = ".NET version (e.g., v6.0, v7.0, v8.0)"
  type        = string
  default     = "v8.0"
}

variable "identity_type" {
  description = "Identity type"
  type        = string
  default     = "SystemAssigned"
}

variable "app_settings" {
  description = "App settings for the web app"
  type        = map(string)
  default     = {}
}

variable "deployment_slots" {
  description = "List of deployment slot names to create"
  type        = list(string)
  default     = []
}

#--------------------------------------------------------------
# Autoscale Variables
#--------------------------------------------------------------
variable "enable_autoscale" {
  description = "Enable autoscale"
  type        = bool
  default     = true
}

variable "min_capacity" {
  description = "Minimum capacity for autoscale"
  type        = number
  default     = 3
}

variable "max_capacity" {
  description = "Maximum capacity for autoscale"
  type        = number
  default     = 10
}

variable "default_capacity" {
  description = "Default capacity for autoscale"
  type        = number
  default     = 3
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

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
