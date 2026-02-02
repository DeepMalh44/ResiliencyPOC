#--------------------------------------------------------------
# Function App Module - Outputs
#--------------------------------------------------------------

output "app_service_plan_id" {
  description = "ID of the App Service Plan"
  value       = azurerm_service_plan.this.id
}

output "app_service_plan_name" {
  description = "Name of the App Service Plan"
  value       = azurerm_service_plan.this.name
}

output "id" {
  description = "ID of the Function App"
  value       = var.os_type == "Windows" ? azurerm_windows_function_app.this[0].id : azurerm_linux_function_app.this[0].id
}

output "name" {
  description = "Name of the Function App"
  value       = var.os_type == "Windows" ? azurerm_windows_function_app.this[0].name : azurerm_linux_function_app.this[0].name
}

output "default_hostname" {
  description = "Default hostname of the Function App"
  value       = var.os_type == "Windows" ? azurerm_windows_function_app.this[0].default_hostname : azurerm_linux_function_app.this[0].default_hostname
}

output "identity_principal_id" {
  description = "Principal ID of the system-assigned identity"
  value       = var.os_type == "Windows" ? azurerm_windows_function_app.this[0].identity[0].principal_id : azurerm_linux_function_app.this[0].identity[0].principal_id
}

output "identity_tenant_id" {
  description = "Tenant ID of the system-assigned identity"
  value       = var.os_type == "Windows" ? azurerm_windows_function_app.this[0].identity[0].tenant_id : azurerm_linux_function_app.this[0].identity[0].tenant_id
}

output "private_endpoint_id" {
  description = "ID of the private endpoint"
  value       = length(azurerm_private_endpoint.this) > 0 ? azurerm_private_endpoint.this[0].id : null
}