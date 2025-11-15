output "environment_id" {
  description = "The ID of the Container App Environment"
  value       = azurerm_container_app_environment.env.id
}

output "app_id" {
  description = "The ID of the Container App"
  value       = azurerm_container_app.app.id
}

output "app_name" {
  description = "The name of the Container App"
  value       = azurerm_container_app.app.name
}

output "app_identity_principal_id" {
  description = "The Principal ID of the System Assigned Managed Identity"
  value       = azurerm_container_app.app.identity[0].principal_id
}
