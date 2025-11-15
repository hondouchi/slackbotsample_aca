resource "azurerm_container_app_environment" "env" {
  name                       = var.environment_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  log_analytics_workspace_id = var.log_analytics_workspace_id
  infrastructure_subnet_id   = var.infrastructure_subnet_id

  tags = var.tags
}

resource "azurerm_container_app" "app" {
  name                         = var.app_name
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  identity {
    type = "SystemAssigned"
  }

  registry {
    server   = var.registry_server
    identity = "system"
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = var.container_name
      image  = var.container_image
      cpu    = var.cpu
      memory = var.memory

      dynamic "env" {
        for_each = var.env_vars
        content {
          name        = env.value.name
          secret_name = lookup(env.value, "secret_name", null)
          value       = lookup(env.value, "value", null)
        }
      }
    }
  }

  dynamic "secret" {
    for_each = var.secrets
    content {
      name                = secret.value.name
      key_vault_secret_id = secret.value.key_vault_secret_id
      identity            = "system"
    }
  }

  # Socket Mode では HTTP エンドポイントが不要なため Ingress は設定しない
  # Ingress を有効にするとヘルスチェックが失敗して Unhealthy 状態になる

  tags = var.tags
}
