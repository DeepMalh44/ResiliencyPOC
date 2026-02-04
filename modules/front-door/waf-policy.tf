#--------------------------------------------------------------
# Front Door WAF Policy
#--------------------------------------------------------------

resource "azurerm_cdn_frontdoor_firewall_policy" "this" {
  count = var.enable_waf ? 1 : 0

  name                = var.waf_policy_name
  resource_group_name = var.resource_group_name
  sku_name            = var.sku_name
  enabled             = true
  mode                = var.waf_mode # Prevention or Detection

  # Managed Rules (OWASP)
  dynamic "managed_rule" {
    for_each = var.waf_managed_rules
    content {
      type    = managed_rule.value.type
      version = managed_rule.value.version
      action  = managed_rule.value.action

      dynamic "override" {
        for_each = managed_rule.value.overrides != null ? managed_rule.value.overrides : []
        content {
          rule_group_name = override.value.rule_group_name

          dynamic "rule" {
            for_each = override.value.rules != null ? override.value.rules : []
            content {
              rule_id = rule.value.rule_id
              action  = rule.value.action
              enabled = rule.value.enabled
            }
          }
        }
      }
    }
  }

  # Custom Rules
  dynamic "custom_rule" {
    for_each = var.waf_custom_rules
    content {
      name                           = custom_rule.value.name
      enabled                        = custom_rule.value.enabled
      priority                       = custom_rule.value.priority
      rate_limit_duration_in_minutes = custom_rule.value.rate_limit_duration_in_minutes
      rate_limit_threshold           = custom_rule.value.rate_limit_threshold
      type                           = custom_rule.value.type
      action                         = custom_rule.value.action

      dynamic "match_condition" {
        for_each = custom_rule.value.match_conditions
        content {
          match_variable     = match_condition.value.match_variable
          operator           = match_condition.value.operator
          negation_condition = match_condition.value.negation_condition
          match_values       = match_condition.value.match_values
          transforms         = match_condition.value.transforms
        }
      }
    }
  }

  tags = var.tags
}

#--------------------------------------------------------------
# WAF Security Policy (Links WAF to Endpoints/Domains)
#--------------------------------------------------------------
resource "azurerm_cdn_frontdoor_security_policy" "this" {
  count = 0 # Disabled for initial deployment - enable after endpoints exist

  name                     = "security-policy-${var.profile_name}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.this[0].id

      association {
        patterns_to_match = var.waf_patterns_to_match

        dynamic "domain" {
          for_each = var.waf_domain_ids
          content {
            cdn_frontdoor_domain_id = domain.value
          }
        }
      }
    }
  }
}



