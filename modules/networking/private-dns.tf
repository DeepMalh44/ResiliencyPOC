#--------------------------------------------------------------
# Private DNS Zones for Private Endpoints
#--------------------------------------------------------------

resource "azurerm_private_dns_zone" "zones" {
  for_each = var.enable_private_dns_zones ? var.private_dns_zones : {}

  name                = each.value
  resource_group_name = var.resource_group_name

  tags = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "links" {
  for_each = var.enable_private_dns_zones ? var.private_dns_zones : {}

  name                  = "link-${var.vnet_name}-${each.key}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.zones[each.key].name
  virtual_network_id    = azurerm_virtual_network.this.id
  registration_enabled  = false

  tags = var.tags
}

