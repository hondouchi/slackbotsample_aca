locals {
  project_name = "slackbot-aca"
  environment  = "production"
  location     = "japaneast"

  tags = {
    Project     = "SlackBot"
    Environment = local.environment
    ManagedBy   = "Terraform"
  }
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "rg-${local.project_name}"
  location = local.location
  tags     = local.tags
}

# Network Module
module "network" {
  source = "../../modules/network"

  vnet_name           = "${local.project_name}-vnet"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = ["10.0.0.0/16"]

  aca_subnet_name             = "aca-subnet"
  aca_subnet_address_prefixes = ["10.0.0.0/23"]

  database_subnet_name             = "database-subnet"
  database_subnet_address_prefixes = ["10.0.2.0/24"]

  tags = local.tags
}

# Log Analytics Module
module "log_analytics" {
  source = "../../modules/log-analytics"

  name                = "ws-slackapp-aca"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = local.tags
}

# Container Registry Module
module "container_registry" {
  source = "../../modules/container-registry"

  name                       = var.acr_name
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  sku                        = "Standard"
  admin_enabled              = false
  log_analytics_workspace_id = module.log_analytics.id

  tags = local.tags
}

# Key Vault Module
module "key_vault" {
  source = "../../modules/key-vault"

  name                       = var.key_vault_name
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  tags = local.tags
}

# Managed Identity Module (Phase 4a: Create identity first)
module "managed_identity" {
  source = "../../modules/managed-identity"

  identity_name       = "${local.project_name}-identity"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  tags = local.tags
}

# Role Assignment: Managed Identity to ACR (Phase 4a: Assign roles before Container App)
resource "azurerm_role_assignment" "aca_acr_pull" {
  scope                = module.container_registry.id
  role_definition_name = "AcrPull"
  principal_id         = module.managed_identity.principal_id
}

# Role Assignment: Managed Identity to Key Vault (Phase 4a: Assign roles before Container App)
resource "azurerm_role_assignment" "aca_keyvault_secrets_user" {
  scope                = module.key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.managed_identity.principal_id
}

# Container Apps Module (Phase 4b: Create Container App with pre-configured identity)
module "container_apps" {
  source = "../../modules/container-apps"

  environment_name           = "${local.project_name}-env"
  app_name                   = var.container_image_name
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  log_analytics_workspace_id = module.log_analytics.id
  infrastructure_subnet_id   = module.network.aca_subnet_id

  user_assigned_identity_id = module.managed_identity.id  # Use pre-created identity

  registry_server = module.container_registry.login_server
  container_image = "${module.container_registry.login_server}/${var.container_image_name}:${var.container_image_tag}"
  container_name  = var.container_image_name

  cpu    = 0.5
  memory = "1Gi"

  min_replicas = 1  # Socket Mode requires always-on connection
  max_replicas = 10

  env_vars = [
    {
      name        = "SLACK_BOT_TOKEN"
      secret_name = "slack-bot-token"
    },
    {
      name        = "SLACK_APP_TOKEN"
      secret_name = "slack-app-token"
    },
    {
      name        = "BOT_USER_ID"
      secret_name = "bot-user-id"
    }
  ]

  secrets = [
    {
      name                = "slack-bot-token"
      key_vault_secret_id = "${module.key_vault.vault_uri}secrets/SLACK-BOT-TOKEN"
    },
    {
      name                = "slack-app-token"
      key_vault_secret_id = "${module.key_vault.vault_uri}secrets/SLACK-APP-TOKEN"
    },
    {
      name                = "bot-user-id"
      key_vault_secret_id = "${module.key_vault.vault_uri}secrets/BOT-USER-ID"
    },
  ]

  tags = local.tags

  # Ensure identity and roles are ready before creating Container App
  depends_on = [
    azurerm_role_assignment.aca_acr_pull,
    azurerm_role_assignment.aca_keyvault_secrets_user
  ]
}
