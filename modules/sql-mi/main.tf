#--------------------------------------------------------------
# SQL Managed Instance Module - Main
# Uses azapi_resource to set Azure AD-only auth at creation time
# This is required by MCAPS policies that deny non-AAD-only MI
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

# Create SQL MI using azapi_resource with administrators block
# This sets azureADOnlyAuthentication = true at creation time
# When azureADOnlyAuthentication is true, SQL admin credentials are not required
resource "azapi_resource" "managed_instance" {
  type      = "Microsoft.Sql/managedInstances@2023-08-01-preview"
  name      = var.name
  location  = var.location
  parent_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"

  identity {
    type = "SystemAssigned"
  }

  body = {
    sku = {
      name = var.sku_name
      # Business Critical tier: BC_Gen5, BC_G8IM (Premium Series), BC_G8IH (Premium Series Memory Optimized)
      tier = startswith(var.sku_name, "BC_") ? "BusinessCritical" : "GeneralPurpose"
    }
    properties = merge(
      {
        subnetId                   = var.subnet_id
        licenseType                = var.license_type
        vCores                     = var.vcores
        storageSizeInGB            = var.storage_size_in_gb
        collation                  = var.collation
        timezoneId                 = var.timezone_id
        minimalTlsVersion          = var.minimum_tls_version
        publicDataEndpointEnabled  = var.public_data_endpoint_enabled
        proxyOverride              = var.proxy_override
        # When zone_redundant is true, backup storage must also be Zone-redundant
        requestedBackupStorageRedundancy = var.zone_redundant ? "Zone" : var.backup_storage_redundancy
        zoneRedundant              = var.zone_redundant

        # Azure AD Administrator with AAD-only authentication at creation time
        administrators = {
          administratorType         = "ActiveDirectory"
          azureADOnlyAuthentication = var.azuread_authentication_only
          login                     = var.azure_ad_admin_login
          principalType             = "User"
          sid                       = var.azure_ad_admin_object_id
          tenantId                  = var.azure_ad_admin_tenant_id
        }
      },
      # Only include SQL admin credentials if NOT using Azure AD-only auth
      var.azuread_authentication_only ? {} : {
        administratorLogin         = var.administrator_login
        administratorLoginPassword = var.administrator_password
      }
    )
  }

  tags = var.tags

  timeouts {
    create = "2h"
    update = "2h"
    delete = "2h"
  }
}

data "azurerm_client_config" "current" {}

#--------------------------------------------------------------
# Diagnostic Settings
#--------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "this" {
  count = var.enable_diagnostics ? 1 : 0

  name                       = "diag-${var.name}"
  target_resource_id         = azapi_resource.managed_instance.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

#--------------------------------------------------------------
# Failover Group (created on primary only)
#--------------------------------------------------------------
resource "azurerm_mssql_managed_instance_failover_group" "this" {
  count = var.create_failover_group && var.partner_managed_instance_id != null ? 1 : 0

  name                        = var.failover_group_name
  location                    = var.location
  managed_instance_id         = azapi_resource.managed_instance.id
  partner_managed_instance_id = var.partner_managed_instance_id

  read_write_endpoint_failover_policy {
    mode          = "Automatic"
    grace_minutes = var.grace_period_minutes
  }
}
