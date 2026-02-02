#--------------------------------------------------------------
# Front Door Module - Variables
#--------------------------------------------------------------

variable "profile_name" {
  description = "Name of the Front Door profile"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "sku_name" {
  description = "SKU name (Standard_AzureFrontDoor or Premium_AzureFrontDoor)"
  type        = string
  default     = "Premium_AzureFrontDoor"
}

variable "response_timeout_seconds" {
  description = "Response timeout in seconds"
  type        = number
  default     = 120
}

variable "origin_groups" {
  description = "Map of origin groups (backend pools)"
  type = map(object({
    session_affinity_enabled = optional(bool, false)
    health_probe = object({
      interval_in_seconds = optional(number, 10)
      path                = optional(string, "/")
      protocol            = optional(string, "Https")
      request_type        = optional(string, "HEAD")
    })
    load_balancing = object({
      additional_latency_in_milliseconds = optional(number, 50)
      sample_size                        = optional(number, 4)
      successful_samples_required        = optional(number, 2)
    })
  }))
  default = {}
}

variable "origins" {
  description = "Map of origins (backend servers)"
  type = map(object({
    origin_group_key              = string
    enabled                        = optional(bool, true)
    certificate_name_check_enabled = optional(bool, true)
    host_name                      = string
    origin_host_header             = optional(string)
    http_port                      = optional(number, 80)
    https_port                     = optional(number, 443)
    priority                       = optional(number, 1)
    weight                         = optional(number, 50)
    private_link = optional(object({
      location               = string
      private_link_target_id = string
      request_message        = optional(string, "Please approve this Private Link connection")
      target_type            = optional(string)
    }))
  }))
  default = {}
}

variable "endpoints" {
  description = "Map of endpoints"
  type = map(object({
    enabled = optional(bool, true)
  }))
  default = {}
}

variable "custom_domains" {
  description = "Map of custom domains"
  type = map(object({
    host_name           = string
    certificate_type    = optional(string, "ManagedCertificate")
    minimum_tls_version = optional(string, "TLS12")
  }))
  default = {}
}

variable "routes" {
  description = "Map of routes"
  type = map(object({
    endpoint_key          = string
    origin_group_key      = string
    origin_keys           = list(string)
    enabled                = optional(bool, true)
    forwarding_protocol    = optional(string, "HttpsOnly")
    https_redirect_enabled = optional(bool, true)
    patterns_to_match      = optional(list(string), ["/*"])
    supported_protocols    = optional(list(string), ["Http", "Https"])
    link_to_default_domain = optional(bool, true)
    custom_domain_names    = optional(list(string))
    cache = optional(object({
      compression_enabled           = optional(bool, true)
      content_types_to_compress     = optional(list(string))
      query_string_caching_behavior = optional(string, "IgnoreQueryString")
      query_strings                 = optional(list(string))
    }))
  }))
  default = {}
}

#--------------------------------------------------------------
# WAF Variables
#--------------------------------------------------------------
variable "enable_waf" {
  description = "Enable WAF"
  type        = bool
  default     = true
}

variable "waf_policy_name" {
  description = "Name of the WAF policy"
  type        = string
  default     = "wafpolicy"
}

variable "waf_mode" {
  description = "WAF mode (Prevention or Detection)"
  type        = string
  default     = "Prevention"
}

variable "waf_managed_rules" {
  description = "WAF managed rules"
  type = list(object({
    type    = string
    version = string
    action  = optional(string, "Block")
    overrides = optional(list(object({
      rule_group_name = string
      rules = optional(list(object({
        rule_id = string
        action  = string
        enabled = bool
      })))
    })))
  }))
  default = [
    {
      type    = "Microsoft_DefaultRuleSet"
      version = "2.1"
      action  = "Block"
    },
    {
      type    = "Microsoft_BotManagerRuleSet"
      version = "1.0"
      action  = "Block"
    }
  ]
}

variable "waf_custom_rules" {
  description = "WAF custom rules"
  type = list(object({
    name                           = string
    enabled                        = optional(bool, true)
    priority                       = number
    rate_limit_duration_in_minutes = optional(number, 1)
    rate_limit_threshold           = optional(number, 100)
    type                           = string
    action                         = string
    match_conditions = list(object({
      match_variable     = string
      operator           = string
      negation_condition = optional(bool, false)
      match_values       = list(string)
      transforms         = optional(list(string))
    }))
  }))
  default = []
}

variable "waf_patterns_to_match" {
  description = "Patterns to match for WAF"
  type        = list(string)
  default     = ["/*"]
}

variable "waf_domain_ids" {
  description = "Domain IDs to associate with WAF"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}


