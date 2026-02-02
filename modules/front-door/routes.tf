#--------------------------------------------------------------
# Front Door Routes
#--------------------------------------------------------------

resource "azurerm_cdn_frontdoor_route" "routes" {
  for_each = var.routes

  name                          = each.key
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.endpoints[each.value.endpoint_key].id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.groups[each.value.origin_group_key].id
  cdn_frontdoor_origin_ids      = [for o in each.value.origin_keys : azurerm_cdn_frontdoor_origin.origins[o].id]
  
  enabled                = each.value.enabled
  forwarding_protocol    = each.value.forwarding_protocol
  https_redirect_enabled = each.value.https_redirect_enabled
  patterns_to_match      = each.value.patterns_to_match
  supported_protocols    = each.value.supported_protocols

  link_to_default_domain = each.value.link_to_default_domain

  cdn_frontdoor_custom_domain_ids = each.value.custom_domain_names != null ? [for d in each.value.custom_domain_names : azurerm_cdn_frontdoor_custom_domain.domains[d].id] : null

  dynamic "cache" {
    for_each = each.value.cache != null ? [each.value.cache] : []
    content {
      compression_enabled           = cache.value.compression_enabled
      content_types_to_compress     = cache.value.content_types_to_compress
      query_string_caching_behavior = cache.value.query_string_caching_behavior
      query_strings                 = cache.value.query_strings
    }
  }
}
