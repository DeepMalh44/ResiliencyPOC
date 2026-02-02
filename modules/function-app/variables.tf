#--------------------------------------------------------------
# Function App Module - Variables (Simplified Interface)
#--------------------------------------------------------------

variable "function_app_name" {
  description = "Name of the Function App"
  type        = string
}

variable "app_service_plan_name" {
  description = "Name of the App Service Plan for Function App"
  type        = string
}

variable "storage_account_name" {
  description = "Storage account name for function app"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for the Function App"
  type        = string
}

variable "os_type" {
  description = "OS type (Linux or Windows)"
  type        = string
  default     = "Windows"
}

variable "sku_name" {
  description = "SKU name for the App Service Plan (EP1, EP2, EP3)"
  type        = string
  default     = "EP2"
}

variable "zone_balancing_enabled" {
  description = "Enable zone balancing for high availability"
  type        = bool
  default     = true
}

variable "maximum_elastic_worker_count" {
  description = "Maximum elastic worker count"
  type        = number
  default     = 20
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

variable "minimum_tls_version" {
  description = "Minimum TLS version"
  type        = string
  default     = "1.2"
}

variable "ftps_state" {
  description = "FTPS state"
  type        = string
  default     = "Disabled"
}

variable "http2_enabled" {
  description = "Enable HTTP/2"
  type        = bool
  default     = true
}

variable "runtime_name" {
  description = "Runtime name (dotnet, dotnet-isolated, node, python, java, powershell)"
  type        = string
  default     = "dotnet-isolated"
}

variable "runtime_version" {
  description = "Runtime version"
  type        = string
  default     = "8.0"
}

variable "functions_extension_version" {
  description = "Functions extension version (~4)"
  type        = string
  default     = "~4"
}

variable "identity_type" {
  description = "Identity type"
  type        = string
  default     = "SystemAssigned"
}

variable "app_settings" {
  description = "App settings for the function app"
  type        = map(string)
  default     = {}
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

variable "storage_account_access_key" {
  description = "Storage account primary access key"
  type        = string
  sensitive   = true
  default     = ""
}


