#--------------------------------------------------------------
# Storage Account Module - Outputs
#--------------------------------------------------------------

output "storage_account_id" {
  description = "ID of the storage account"
  value       = azurerm_storage_account.this.id
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.this.name
}

output "primary_blob_endpoint" {
  description = "Primary blob endpoint"
  value       = azurerm_storage_account.this.primary_blob_endpoint
}

output "primary_queue_endpoint" {
  description = "Primary queue endpoint"
  value       = azurerm_storage_account.this.primary_queue_endpoint
}

output "primary_table_endpoint" {
  description = "Primary table endpoint"
  value       = azurerm_storage_account.this.primary_table_endpoint
}

output "primary_file_endpoint" {
  description = "Primary file endpoint"
  value       = azurerm_storage_account.this.primary_file_endpoint
}

output "secondary_blob_endpoint" {
  description = "Secondary blob endpoint (for RA-GZRS)"
  value       = azurerm_storage_account.this.secondary_blob_endpoint
}

output "primary_access_key" {
  description = "Primary access key (use managed identity instead)"
  value       = azurerm_storage_account.this.primary_access_key
  sensitive   = true
}

output "primary_connection_string" {
  description = "Primary connection string (use managed identity instead)"
  value       = azurerm_storage_account.this.primary_connection_string
  sensitive   = true
}

output "identity_principal_id" {
  description = "Principal ID of the system-assigned identity"
  value       = azurerm_storage_account.this.identity[0].principal_id
}

output "identity_tenant_id" {
  description = "Tenant ID of the system-assigned identity"
  value       = azurerm_storage_account.this.identity[0].tenant_id
}

output "blob_private_endpoint_id" {
  description = "ID of the blob private endpoint"
  value       = var.enable_private_endpoint ? module.blob_private_endpoint[0].private_endpoint_id : null
}

output "container_ids" {
  description = "Map of container names (created via Azure CLI)"
  value       = { for k, v in var.containers : k => join("/", [azurerm_storage_account.this.id, "blobServices/default/containers", k]) }
}

output "id" {
  description = "ID of the storage account"
  value       = azurerm_storage_account.this.id
}

output "name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.this.name
}
