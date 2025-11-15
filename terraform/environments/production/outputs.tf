output "resource_group_name" {
  description = "The name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "container_registry_login_server" {
  description = "The login server of the Container Registry"
  value       = module.container_registry.login_server
}

output "container_registry_name" {
  description = "The name of the Container Registry"
  value       = module.container_registry.name
}

output "key_vault_name" {
  description = "The name of the Key Vault"
  value       = module.key_vault.name
}

output "key_vault_uri" {
  description = "The URI of the Key Vault"
  value       = module.key_vault.vault_uri
}

output "container_app_fqdn" {
  description = "The FQDN of the Container App"
  value       = module.container_apps.app_fqdn
}

output "container_app_url" {
  description = "The URL of the Container App"
  value       = "https://${module.container_apps.app_fqdn}"
}

output "vnet_id" {
  description = "The ID of the Virtual Network"
  value       = module.network.vnet_id
}
