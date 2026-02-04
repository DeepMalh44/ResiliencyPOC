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
# SQL MI NSG Rules for Geo-Replication
# These rules allow failover group traffic between SQL MIs
# across peered VNets. Priority < 4096 (before DenyAllInbound)
#--------------------------------------------------------------

# Allow SQL MI geo-replication port 5022 between VNets
resource "azurerm_network_security_rule" "sqlmi_geo_replication_5022" {
  for_each = { for k, v in var.subnets : k => v if v.is_sqlmi_subnet }

  name                        = "Allow_SQLMi_GeoReplication_5022"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5022"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.subnets[each.key].name
}

# Allow SQL MI port range 11000-11999 for replication
resource "azurerm_network_security_rule" "sqlmi_geo_replication_11000" {
  for_each = { for k, v in var.subnets : k => v if v.is_sqlmi_subnet }

  name                        = "Allow_SQLMi_GeoReplication_11000_11999"
  priority                    = 201
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "11000-11999"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.subnets[each.key].name
}

# Allow SQL MI port 1433 for failover group listener
resource "azurerm_network_security_rule" "sqlmi_listener_1433" {
  for_each = { for k, v in var.subnets : k => v if v.is_sqlmi_subnet }

  name                        = "Allow_SQLMi_Listener_1433"
  priority                    = 202
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "1433"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.subnets[each.key].name
}

# Allow outbound geo-replication traffic from SQL MI
resource "azurerm_network_security_rule" "sqlmi_geo_replication_outbound" {
  for_each = { for k, v in var.subnets : k => v if v.is_sqlmi_subnet }

  name                        = "Allow_SQLMi_GeoReplication_Outbound"
  priority                    = 200
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["5022", "11000-11999", "1433"]
  source_address_prefix       = "*"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.subnets[each.key].name
}

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



