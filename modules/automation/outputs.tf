#------------------------------------------------------------------------------
# Azure Automation Module Outputs
#------------------------------------------------------------------------------

output "automation_account_id" {
  description = "Resource ID of the Automation Account"
  value       = azurerm_automation_account.this.id
}

output "automation_account_name" {
  description = "Name of the Automation Account"
  value       = azurerm_automation_account.this.name
}

output "automation_account_identity_principal_id" {
  description = "Principal ID of the Automation Account managed identity"
  value       = azurerm_automation_account.this.identity[0].principal_id
}

output "automation_account_identity_tenant_id" {
  description = "Tenant ID of the Automation Account managed identity"
  value       = azurerm_automation_account.this.identity[0].tenant_id
}

output "runbook_id" {
  description = "Resource ID of the DR failover runbook"
  value       = azurerm_automation_runbook.dr_failover.id
}

output "runbook_name" {
  description = "Name of the DR failover runbook"
  value       = azurerm_automation_runbook.dr_failover.name
}

output "webhook_uri" {
  description = "URI of the webhook for alert-triggered execution"
  value       = azurerm_automation_webhook.dr_failover.uri
  sensitive   = true
}
