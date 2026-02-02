#--------------------------------------------------------------
# Resource Group Module - Main
#--------------------------------------------------------------

resource "azurerm_resource_group" "this" {
  name     = var.name
  location = var.location
  tags     = var.tags
}

