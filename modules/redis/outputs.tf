#--------------------------------------------------------------
# Redis Cache Module - Outputs
#--------------------------------------------------------------

output "redis_cache_id" {
  description = "ID of the Redis cache"
  value       = azurerm_redis_cache.this.id
}

output "redis_cache_name" {
  description = "Name of the Redis cache"
  value       = azurerm_redis_cache.this.name
}

output "redis_cache_hostname" {
  description = "Hostname of the Redis cache"
  value       = azurerm_redis_cache.this.hostname
}

output "redis_cache_port" {
  description = "Port of the Redis cache (SSL)"
  value       = azurerm_redis_cache.this.ssl_port
}

output "redis_cache_primary_access_key" {
  description = "Primary access key (use managed identity instead)"
  value       = azurerm_redis_cache.this.primary_access_key
  sensitive   = true
}

output "redis_cache_primary_connection_string" {
  description = "Primary connection string (use managed identity instead)"
  value       = azurerm_redis_cache.this.primary_connection_string
  sensitive   = true
}

output "redis_cache_identity_principal_id" {
  description = "Principal ID of the system-assigned identity"
  value       = azurerm_redis_cache.this.identity[0].principal_id
}

output "private_endpoint_id" {
  description = "ID of the private endpoint"
  value       = var.enable_private_endpoint ? module.private_endpoint[0].private_endpoint_id : null
}

output "private_endpoint_ip" {
  description = "Private IP of the private endpoint"
  value       = var.enable_private_endpoint ? module.private_endpoint[0].private_ip_address : null
}

# Disabled for initial deployment - geo-replication requires primary cache to exist first
output "linked_server_name" {
  description = "Name of the geo-replication linked server"
  value       = null  # Enable after initial deployment: var.linked_redis_cache_id != null ? azurerm_redis_linked_server.this[0].name : null
}

output "id" {
  description = "ID of the Redis cache"
  value       = azurerm_redis_cache.this.id
}

output "name" {
  description = "Name of the Redis cache"
  value       = azurerm_redis_cache.this.name
}

output "hostname" {
  description = "Hostname of the Redis cache"
  value       = azurerm_redis_cache.this.hostname
}

output "primary_connection_string" {
  description = "Primary connection string"
  value       = azurerm_redis_cache.this.primary_connection_string
  sensitive   = true
}