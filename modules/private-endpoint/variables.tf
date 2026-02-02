#--------------------------------------------------------------
# Private Endpoint Module - Variables
#--------------------------------------------------------------

variable "private_endpoint_name" {
  description = "Name of the private endpoint"
  type        = string
}

variable "location" {
  description = "Azure region for the private endpoint"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet for the private endpoint"
  type        = string
}

variable "target_resource_id" {
  description = "ID of the resource to connect to"
  type        = string
}

variable "subresource_names" {
  description = "Subresource names for the private endpoint (e.g., ['blob'], ['sqlServer'])"
  type        = list(string)
}

variable "private_dns_zone_ids" {
  description = "List of private DNS zone IDs to link"
  type        = list(string)
  default     = null
}

variable "tags" {
  description = "Tags to apply to the private endpoint"
  type        = map(string)
  default     = {}
}
