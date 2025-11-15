output "id" {
  description = "The ID of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.workspace.id
}

output "workspace_id" {
  description = "The Workspace ID of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.workspace.workspace_id
}

output "primary_shared_key" {
  description = "The Primary shared key for the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.workspace.primary_shared_key
  sensitive   = true
}
