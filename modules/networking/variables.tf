#--------------------------------------------------------------
# Networking Module - Variables
#--------------------------------------------------------------

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
}

variable "location" {
  description = "Azure region for the virtual network"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
}

variable "dns_servers" {
  description = "Custom DNS servers for the virtual network"
  type        = list(string)
  default     = []
}

variable "subnets" {
  description = "Map of subnet configurations"
  type = map(object({
    address_prefixes = list(string)
    service_endpoints                           = optional(list(string), [])
    private_endpoint_network_policies           = optional(string, "Enabled")
    private_link_service_network_policies_enabled = optional(bool, true)
    create_nsg                                  = optional(bool, true)
    is_sqlmi_subnet                             = optional(bool, false)
    delegation = optional(object({
      name    = string
      actions = list(string)
    }), null)
  }))
}

variable "enable_private_dns_zones" {
  description = "Whether to create private DNS zones"
  type        = bool
  default     = true
}

variable "private_dns_zones" {
  description = "Map of private DNS zones to create"
  type        = map(string)
  default = {
    keyvault      = "privatelink.vaultcore.azure.net"
    blob          = "privatelink.blob.core.windows.net"
    file          = "privatelink.file.core.windows.net"
    queue         = "privatelink.queue.core.windows.net"
    table         = "privatelink.table.core.windows.net"
    sqlmi         = "privatelink.database.windows.net"
    redis         = "privatelink.redis.cache.windows.net"
    apim          = "privatelink.azure-api.net"
    webapp        = "privatelink.azurewebsites.net"
    monitor       = "privatelink.monitor.azure.com"
  }
}

variable "peer_vnet_id" {
  description = "ID of the VNet to peer with"
  type        = string
  default     = null
}

variable "peer_vnet_name" {
  description = "Name of the VNet to peer with (for naming)"
  type        = string
  default     = null
}

variable "allow_gateway_transit" {
  description = "Allow gateway transit for peering"
  type        = bool
  default     = false
}

variable "use_remote_gateways" {
  description = "Use remote gateways for peering"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
