#--------------------------------------------------------------
# Key Vault Private Endpoint
#--------------------------------------------------------------

module "private_endpoint" {
  source = "../private-endpoint"
  count  = var.enable_private_endpoint ? 1 : 0

  private_endpoint_name = "pe-${var.name}"
  location              = var.location
  resource_group_name   = var.resource_group_name
  subnet_id             = var.private_endpoint_subnet_id
  target_resource_id    = azurerm_key_vault.this.id
  subresource_names     = ["vault"]
  private_dns_zone_ids  = var.private_dns_zone_ids

  tags = var.tags
}

