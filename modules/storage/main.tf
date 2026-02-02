#--------------------------------------------------------------
# Storage Account Module - Main
# RA-GZRS for multi-zone and multi-region redundancy
#--------------------------------------------------------------

terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = ">= 1.12.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.80.0"
    }
  }
}

resource "azurerm_storage_account" "this" {
  name                     = var.name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type  # RAGZRS for geo-zone redundancy
  account_kind             = var.account_kind

  # Security settings
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = var.public_network_access_enabled
  shared_access_key_enabled       = var.shared_access_key_enabled  # Disable for RBAC-only access
  default_to_oauth_authentication = true

  # Enable infrastructure encryption
  infrastructure_encryption_enabled = var.infrastructure_encryption_enabled

  # Enable hierarchical namespace for Data Lake (optional)
  is_hns_enabled = var.is_hns_enabled

  # Blob properties
  blob_properties {
    versioning_enabled = var.versioning_enabled

    delete_retention_policy {
      days = var.blob_soft_delete_retention_days
    }

    container_delete_retention_policy {
      days = var.container_soft_delete_retention_days
    }

    dynamic "cors_rule" {
      for_each = var.cors_rules
      content {
        allowed_headers    = cors_rule.value.allowed_headers
        allowed_methods    = cors_rule.value.allowed_methods
        allowed_origins    = cors_rule.value.allowed_origins
        exposed_headers    = cors_rule.value.exposed_headers
        max_age_in_seconds = cors_rule.value.max_age_in_seconds
      }
    }
  }

  # Network rules
  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    ip_rules                   = var.allowed_ip_ranges
    virtual_network_subnet_ids = var.allowed_subnet_ids
  }

  # Identity for CMK and RBAC
  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

#--------------------------------------------------------------
# Role Assignment for Deployer (RBAC-only storage)
# Required when shared_access_key_enabled = false
#--------------------------------------------------------------
data "azurerm_client_config" "current" {}

resource "azurerm_role_assignment" "deployer_blob_contributor" {
  count = var.shared_access_key_enabled == false ? 1 : 0

  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

#--------------------------------------------------------------
# Diagnostic Settings
#--------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "blob" {
  count = var.enable_diagnostics ? 1 : 0

  name                       = "diag-${var.name}-blob"
  target_resource_id         = "${azurerm_storage_account.this.id}/blobServices/default"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  metric {
    category = "Transaction"
    enabled  = true
  }
}
