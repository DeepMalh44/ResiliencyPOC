#--------------------------------------------------------------
# Storage Private Endpoints
#--------------------------------------------------------------

module "blob_private_endpoint" {
  source = "../private-endpoint"
  count  = var.enable_private_endpoint ? 1 : 0

  private_endpoint_name = "pe-${var.name}-blob"
  location              = var.location
  resource_group_name   = var.resource_group_name
  subnet_id             = var.private_endpoint_subnet_id
  target_resource_id    = azurerm_storage_account.this.id
  subresource_names     = ["blob"]
  private_dns_zone_ids  = var.blob_private_dns_zone_ids

  tags = var.tags
}

module "file_private_endpoint" {
  source = "../private-endpoint"
  count  = var.enable_private_endpoint && var.create_file_private_endpoint ? 1 : 0

  private_endpoint_name = "pe-${var.name}-file"
  location              = var.location
  resource_group_name   = var.resource_group_name
  subnet_id             = var.private_endpoint_subnet_id
  target_resource_id    = azurerm_storage_account.this.id
  subresource_names     = ["file"]
  private_dns_zone_ids  = var.file_private_dns_zone_ids

  tags = var.tags
}

module "queue_private_endpoint" {
  source = "../private-endpoint"
  count  = var.enable_private_endpoint && var.create_queue_private_endpoint ? 1 : 0

  private_endpoint_name = "pe-${var.name}-queue"
  location              = var.location
  resource_group_name   = var.resource_group_name
  subnet_id             = var.private_endpoint_subnet_id
  target_resource_id    = azurerm_storage_account.this.id
  subresource_names     = ["queue"]
  private_dns_zone_ids  = var.queue_private_dns_zone_ids

  tags = var.tags
}

module "table_private_endpoint" {
  source = "../private-endpoint"
  count  = var.enable_private_endpoint && var.create_table_private_endpoint ? 1 : 0

  private_endpoint_name = "pe-${var.name}-table"
  location              = var.location
  resource_group_name   = var.resource_group_name
  subnet_id             = var.private_endpoint_subnet_id
  target_resource_id    = azurerm_storage_account.this.id
  subresource_names     = ["table"]
  private_dns_zone_ids  = var.table_private_dns_zone_ids

  tags = var.tags
}

