#--------------------------------------------------------------
# APIM Module - Outputs
#--------------------------------------------------------------

output "apim_id" {
  description = "ID of the API Management instance"
  value       = azurerm_api_management.this.id
}

output "apim_name" {
  description = "Name of the API Management instance"
  value       = azurerm_api_management.this.name
}

output "apim_gateway_url" {
  description = "Gateway URL of the API Management instance"
  value       = azurerm_api_management.this.gateway_url
}

output "apim_gateway_regional_url" {
  description = "Regional gateway URL"
  value       = azurerm_api_management.this.gateway_regional_url
}

output "apim_management_api_url" {
  description = "Management API URL"
  value       = azurerm_api_management.this.management_api_url
}

output "apim_portal_url" {
  description = "Developer portal URL"
  value       = azurerm_api_management.this.portal_url
}

output "apim_developer_portal_url" {
  description = "Developer portal URL (new)"
  value       = azurerm_api_management.this.developer_portal_url
}

output "apim_public_ip_addresses" {
  description = "Public IP addresses"
  value       = azurerm_api_management.this.public_ip_addresses
}

output "apim_private_ip_addresses" {
  description = "Private IP addresses"
  value       = azurerm_api_management.this.private_ip_addresses
}

output "apim_identity_principal_id" {
  description = "Principal ID of the system-assigned identity"
  value       = azurerm_api_management.this.identity[0].principal_id
}

output "apim_identity_tenant_id" {
  description = "Tenant ID of the system-assigned identity"
  value       = azurerm_api_management.this.identity[0].tenant_id
}

output "id" {
  description = "ID of the API Management instance"
  value       = azurerm_api_management.this.id
}

output "name" {
  description = "Name of the API Management instance"
  value       = azurerm_api_management.this.name
}

output "gateway_url" {
  description = "Gateway URL of the API Management instance"
  value       = azurerm_api_management.this.gateway_url
}
