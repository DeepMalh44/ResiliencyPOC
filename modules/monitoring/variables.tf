#--------------------------------------------------------------
# Monitoring Module - Variables
#--------------------------------------------------------------

variable "log_analytics_name" {
  description = "Name of the Log Analytics workspace"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for monitoring resources"
  type        = string
}

variable "log_analytics_sku" {
  description = "SKU for Log Analytics workspace"
  type        = string
  default     = "PerGB2018"
}

variable "retention_in_days" {
  description = "Data retention in days"
  type        = number
  default     = 90
}

variable "daily_quota_gb" {
  description = "Daily ingestion quota in GB (-1 for unlimited)"
  type        = number
  default     = -1
}

variable "application_insights" {
  description = "Map of Application Insights instances to create"
  type = map(object({
    application_type    = optional(string, "web")
    retention_in_days   = optional(number, 90)
    sampling_percentage = optional(number, 100)
    disable_ip_masking  = optional(bool, false)
  }))
  default = {}
}

variable "action_groups" {
  description = "Map of action groups to create"
  type = map(object({
    short_name = string
    email_receivers = optional(list(object({
      name                    = string
      email_address           = string
      use_common_alert_schema = optional(bool, true)
    })))
    sms_receivers = optional(list(object({
      name         = string
      country_code = string
      phone_number = string
    })))
    webhook_receivers = optional(list(object({
      name                    = string
      service_uri             = string
      use_common_alert_schema = optional(bool, true)
    })))
    azure_app_push_receivers = optional(list(object({
      name          = string
      email_address = string
    })))
  }))
  default = {}
}

variable "metric_alerts" {
  description = "Map of metric alerts to create"
  type = map(object({
    scopes            = list(string)
    description       = optional(string)
    severity          = optional(number, 3)
    enabled           = optional(bool, true)
    frequency         = optional(string, "PT5M")
    window_size       = optional(string, "PT15M")
    auto_mitigate     = optional(bool, true)
    action_group_names = optional(list(string))
    criteria = optional(list(object({
      metric_namespace = string
      metric_name      = string
      aggregation      = string
      operator         = string
      threshold        = number
      dimensions = optional(list(object({
        name     = string
        operator = string
        values   = list(string)
      })))
    })))
  }))
  default = {}
}

variable "activity_log_alerts" {
  description = "Map of activity log alerts to create"
  type = map(object({
    scopes            = list(string)
    description       = optional(string)
    enabled           = optional(bool, true)
    action_group_names = optional(list(string))
    criteria = object({
      category       = string
      operation_name = optional(string)
      level          = optional(string)
      status         = optional(string)
      resource_health = optional(object({
        current  = optional(list(string))
        previous = optional(list(string))
        reason   = optional(list(string))
      }))
    })
  }))
  default = {}
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
