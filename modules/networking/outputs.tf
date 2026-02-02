#--------------------------------------------------------------
# Networking Module - Outputs
#--------------------------------------------------------------

output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.this.name
}

output "vnet_address_space" {
  description = "Address space of the virtual network"
  value       = azurerm_virtual_network.this.address_space
}

output "subnet_ids" {
  description = "Map of subnet names to IDs"
  value       = { for k, v in azurerm_subnet.subnets : k => v.id }
}

output "subnet_address_prefixes" {
  description = "Map of subnet names to address prefixes"
  value       = { for k, v in azurerm_subnet.subnets : k => v.address_prefixes }
}

output "nsg_ids" {
  description = "Map of NSG names to IDs"
  value       = { for k, v in azurerm_network_security_group.subnets : k => v.id }
}

output "private_dns_zone_ids" {
  description = "Map of private DNS zone FQDNs to IDs"
  value       = { for k, v in azurerm_private_dns_zone.zones : v.name => v.id }
}

output "private_dns_zone_names" {
  description = "Map of private DNS zone keys to names"
  value       = { for k, v in azurerm_private_dns_zone.zones : k => v.name }
}
