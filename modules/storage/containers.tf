#--------------------------------------------------------------
# Storage Containers - Using ARM API via azapi_resource
# The ARM control plane bypasses network restrictions and works with:
# - shared_access_key_enabled = false (RBAC-only)
# - public_network_access_enabled = false
# This is the recommended approach for locked-down storage accounts
#--------------------------------------------------------------

resource "azapi_resource" "containers" {
  for_each = var.containers

  type      = "Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01"
  name      = each.key
  parent_id = "${azurerm_storage_account.this.id}/blobServices/default"

  body = {
    properties = {
      publicAccess = "None"
    }
  }

  depends_on = [
    azurerm_storage_account.this
  ]
}

#--------------------------------------------------------------
# Storage Queues
#--------------------------------------------------------------

resource "azurerm_storage_queue" "queues" {
  for_each = var.queues

  name                 = each.key
  storage_account_name = azurerm_storage_account.this.name
}

#--------------------------------------------------------------
# Storage File Shares
#--------------------------------------------------------------

resource "azurerm_storage_share" "shares" {
  for_each = var.file_shares

  name                 = each.key
  storage_account_name = azurerm_storage_account.this.name
  quota                = each.value.quota
  access_tier          = each.value.access_tier
}

#--------------------------------------------------------------
# Storage Tables
#--------------------------------------------------------------

resource "azurerm_storage_table" "tables" {
  for_each = var.tables

  name                 = each.key
  storage_account_name = azurerm_storage_account.this.name
}
