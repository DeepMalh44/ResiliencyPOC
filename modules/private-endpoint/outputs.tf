#--------------------------------------------------------------
# Private Endpoint Module - Outputs
#--------------------------------------------------------------

output "private_endpoint_id" {
  description = "ID of the private endpoint"
  value       = azurerm_private_endpoint.this.id
}

output "private_endpoint_name" {
  description = "Name of the private endpoint"
  value       = azurerm_private_endpoint.this.name
}

output "private_ip_address" {
  description = "Private IP address of the private endpoint"
  value       = azurerm_private_endpoint.this.private_service_connection[0].private_ip_address
}

output "private_dns_zone_group_id" {
  description = "ID of the private DNS zone group"
  value       = try(azurerm_private_endpoint.this.private_dns_zone_group[0].id, null)
}
