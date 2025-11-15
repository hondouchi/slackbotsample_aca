resource "azurerm_container_registry" "acr" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = var.admin_enabled

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "acr_diagnostics" {
  count                      = var.log_analytics_workspace_id != null ? 1 : 0
  name                       = "${var.name}-diagnostics"
  target_resource_id         = azurerm_container_registry.acr.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "ContainerRegistryRepositoryEvents"
  }

  enabled_log {
    category = "ContainerRegistryLoginEvents"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
