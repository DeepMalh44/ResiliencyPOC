#--------------------------------------------------------------
# VNet Peering - For cross-region connectivity
#--------------------------------------------------------------

resource "azurerm_virtual_network_peering" "this" {
  count = var.peer_vnet_id != null ? 1 : 0

  name                         = "peer-to-${var.peer_vnet_name}"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = azurerm_virtual_network.this.name
  remote_virtual_network_id    = var.peer_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = var.allow_gateway_transit
  use_remote_gateways          = var.use_remote_gateways
}
