#--------------------------------------------------------------
# API Management Module - Main
# Supports multiple tiers including Developer for POC
#--------------------------------------------------------------

resource "azurerm_api_management" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = "${var.sku_name}_${var.sku_capacity}"

  # Zone redundancy only for Premium tier
  # For Developer/Standard/Basic - no zones
  zones = var.sku_name == "Premium" ? var.zones : null

  # Virtual Network configuration
  virtual_network_type = var.virtual_network_type

  dynamic "virtual_network_configuration" {
    for_each = var.virtual_network_type != "None" ? [1] : []
    content {
      subnet_id = var.subnet_id
    }
  }

  # Public network access - MUST be enabled during creation (Azure limitation)
  # Can be disabled post-deployment if needed
  public_network_access_enabled = true

  # Managed Identity
  identity {
    type         = var.user_assigned_identity_ids != null ? "SystemAssigned, UserAssigned" : "SystemAssigned"
    identity_ids = var.user_assigned_identity_ids
  }

  # Security settings
  min_api_version = var.min_api_version

  # Protocols
  protocols {
    enable_http2 = var.enable_http2
  }

  # Security
  security {
    enable_backend_ssl30                                = false
    enable_backend_tls10                                = false
    enable_backend_tls11                                = false
    enable_frontend_ssl30                               = false
    enable_frontend_tls10                               = false
    enable_frontend_tls11                               = false
    tls_ecdhe_ecdsa_with_aes128_cbc_sha_ciphers_enabled = false
    tls_ecdhe_ecdsa_with_aes256_cbc_sha_ciphers_enabled = false
    tls_ecdhe_rsa_with_aes128_cbc_sha_ciphers_enabled   = false
    tls_ecdhe_rsa_with_aes256_cbc_sha_ciphers_enabled   = false
    tls_rsa_with_aes128_cbc_sha256_ciphers_enabled      = false
    tls_rsa_with_aes128_cbc_sha_ciphers_enabled         = false
    tls_rsa_with_aes128_gcm_sha256_ciphers_enabled      = true
    tls_rsa_with_aes256_cbc_sha256_ciphers_enabled      = false
    tls_rsa_with_aes256_cbc_sha_ciphers_enabled         = false
    tls_rsa_with_aes256_gcm_sha384_ciphers_enabled      = true
    triple_des_ciphers_enabled                          = false
  }

  # Sign-up settings
  sign_up {
    enabled = var.sign_up_enabled
    terms_of_service {
      consent_required = var.terms_consent_required
      enabled          = var.terms_enabled
      text             = var.terms_text
    }
  }

  tags = var.tags

  # APIM can take a long time to provision
  timeouts {
    create = "3h"
    update = "3h"
    delete = "3h"
  }
}

#--------------------------------------------------------------
# Named Values (for configuration)
#--------------------------------------------------------------
resource "azurerm_api_management_named_value" "named_values" {
  for_each = var.named_values

  name                = each.key
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.this.name
  display_name        = each.value.display_name
  value               = each.value.secret ? null : each.value.value
  secret              = each.value.secret

  dynamic "value_from_key_vault" {
    for_each = each.value.key_vault_secret_id != null ? [1] : []
    content {
      secret_id = each.value.key_vault_secret_id
    }
  }
}

#--------------------------------------------------------------
# Diagnostic Settings
#--------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "this" {
  count = var.enable_diagnostics ? 1 : 0

  name                       = "diag-${var.name}"
  target_resource_id         = azurerm_api_management.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "GatewayLogs"
  }

  enabled_log {
    category = "WebSocketConnectionLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
