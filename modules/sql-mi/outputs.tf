#--------------------------------------------------------------
# SQL Managed Instance Module - Outputs
#--------------------------------------------------------------

output "id" {
  description = "ID of the SQL Managed Instance"
  value       = azapi_resource.managed_instance.id
}

output "name" {
  description = "Name of the SQL Managed Instance"
  value       = azapi_resource.managed_instance.name
}

output "fqdn" {
  description = "Fully qualified domain name of the SQL Managed Instance"
  value       = try(azapi_resource.managed_instance.output.properties.fullyQualifiedDomainName, null)
}

output "identity_principal_id" {
  description = "Principal ID of the system-assigned identity"
  value       = try(azapi_resource.managed_instance.identity[0].principal_id, null)
}

output "dns_zone" {
  description = "DNS zone of the SQL Managed Instance"
  value       = try(azapi_resource.managed_instance.output.properties.dnsZone, null)
}

output "failover_group_id" {
  description = "ID of the failover group"
  value       = var.create_failover_group && var.partner_managed_instance_id != null ? azurerm_mssql_managed_instance_failover_group.this[0].id : null
}
