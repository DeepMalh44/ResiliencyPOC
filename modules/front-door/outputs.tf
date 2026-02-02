#--------------------------------------------------------------
# Front Door Module - Outputs
#--------------------------------------------------------------

output "front_door_profile_id" {
  description = "ID of the Front Door profile"
  value       = azurerm_cdn_frontdoor_profile.this.id
}

output "front_door_profile_name" {
  description = "Name of the Front Door profile"
  value       = azurerm_cdn_frontdoor_profile.this.name
}

output "front_door_resource_guid" {
  description = "Resource GUID of the Front Door profile"
  value       = azurerm_cdn_frontdoor_profile.this.resource_guid
}

output "endpoint_ids" {
  description = "Map of endpoint names to IDs"
  value       = { for k, v in azurerm_cdn_frontdoor_endpoint.endpoints : k => v.id }
}

output "endpoint_hostnames" {
  description = "Map of endpoint names to hostnames"
  value       = { for k, v in azurerm_cdn_frontdoor_endpoint.endpoints : k => v.host_name }
}

output "origin_group_ids" {
  description = "Map of origin group names to IDs"
  value       = { for k, v in azurerm_cdn_frontdoor_origin_group.groups : k => v.id }
}

output "origin_ids" {
  description = "Map of origin names to IDs"
  value       = { for k, v in azurerm_cdn_frontdoor_origin.origins : k => v.id }
}

output "custom_domain_ids" {
  description = "Map of custom domain names to IDs"
  value       = { for k, v in azurerm_cdn_frontdoor_custom_domain.domains : k => v.id }
}

output "waf_policy_id" {
  description = "ID of the WAF policy"
  value       = var.enable_waf ? azurerm_cdn_frontdoor_firewall_policy.this[0].id : null
}

output "waf_policy_frontend_endpoint_ids" {
  description = "Frontend endpoint IDs associated with WAF"
  value       = var.enable_waf ? azurerm_cdn_frontdoor_firewall_policy.this[0].frontend_endpoint_ids : null
}

output "profile_id" {
  description = "ID of the Front Door profile"
  value       = azurerm_cdn_frontdoor_profile.this.id
}

output "endpoints" {
  description = "Map of endpoint names to hostnames"
  value       = { for k, v in azurerm_cdn_frontdoor_endpoint.endpoints : k => v.host_name }
}
