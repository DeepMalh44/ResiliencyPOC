#--------------------------------------------------------------
# Networking Module - Main
# Creates VNet, Subnets, NSGs with zone redundancy support
#--------------------------------------------------------------

#--------------------------------------------------------------
# Virtual Network
#--------------------------------------------------------------
resource "azurerm_virtual_network" "this" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.address_space
  dns_servers         = var.dns_servers

  tags = var.tags
}

#--------------------------------------------------------------
# Subnets
#--------------------------------------------------------------
resource "azurerm_subnet" "subnets" {
  for_each = var.subnets

  name                                          = each.key
  resource_group_name                           = var.resource_group_name
  virtual_network_name                          = azurerm_virtual_network.this.name
  address_prefixes                              = each.value.address_prefixes
  private_endpoint_network_policies             = each.value.private_endpoint_network_policies
  private_link_service_network_policies_enabled = each.value.private_link_service_network_policies_enabled

  service_endpoints = each.value.service_endpoints

  dynamic "delegation" {
    for_each = each.value.delegation != null ? [each.value.delegation] : []
    content {
      name = delegation.value.name
      service_delegation {
        name    = delegation.value.name
        actions = delegation.value.actions
      }
    }
  }
}

#--------------------------------------------------------------
# Network Security Groups
#--------------------------------------------------------------
resource "azurerm_network_security_group" "subnets" {
  for_each = { for k, v in var.subnets : k => v if v.create_nsg }

  name                = "nsg-${each.key}"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

#--------------------------------------------------------------
# Default NSG Rules - Deny All Inbound (except required)
#--------------------------------------------------------------
resource "azurerm_network_security_rule" "deny_all_inbound" {
  for_each = { for k, v in var.subnets : k => v if v.create_nsg }

  name                        = "DenyAllInbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.subnets[each.key].name
}

#--------------------------------------------------------------
# NSG Association
#--------------------------------------------------------------
resource "azurerm_subnet_network_security_group_association" "subnets" {
  for_each = { for k, v in var.subnets : k => v if v.create_nsg }

  subnet_id                 = azurerm_subnet.subnets[each.key].id
  network_security_group_id = azurerm_network_security_group.subnets[each.key].id
}

#--------------------------------------------------------------
# SQL MI NSG Rules - REMOVED
# SQL MI automatically creates and manages its own NSG rules 
# when deployed. Manual rules conflict with Azure-managed rules.
# The following rules are now managed by Azure automatically:
# - Management inbound (SqlManagement service tag)
# - Health probe inbound (AzureLoadBalancer)
# - Geo-replication (VirtualNetwork)
# - Management outbound (AzureCloud)
#--------------------------------------------------------------

#--------------------------------------------------------------
# Route Table for SQL MI (if needed)
#--------------------------------------------------------------
resource "azurerm_route_table" "sqlmi" {
  for_each = { for k, v in var.subnets : k => v if v.is_sqlmi_subnet }

  name                          = "rt-${each.key}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  bgp_route_propagation_enabled = true

  tags = var.tags
}

resource "azurerm_subnet_route_table_association" "sqlmi" {
  for_each = { for k, v in var.subnets : k => v if v.is_sqlmi_subnet }

  subnet_id      = azurerm_subnet.subnets[each.key].id
  route_table_id = azurerm_route_table.sqlmi[each.key].id
}



