output "vnet_id" {
  description = "The ID of the Virtual Network"
  value       = azurerm_virtual_network.vnet.id
}

output "vnet_name" {
  description = "The name of the Virtual Network"
  value       = azurerm_virtual_network.vnet.name
}

output "aca_subnet_id" {
  description = "The ID of the Container Apps subnet"
  value       = azurerm_subnet.aca_subnet.id
}

output "database_subnet_id" {
  description = "The ID of the database subnet"
  value       = azurerm_subnet.database_subnet.id
}
