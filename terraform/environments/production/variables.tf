variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
  default     = "rg-slackbot-aca"
}

variable "location" {
  description = "The Azure region where resources will be created"
  type        = string
  default     = "japaneast"
}

variable "vnet_name" {
  description = "The name of the virtual network"
  type        = string
  default     = "slackbot-aca-vnet"
}

variable "aca_subnet_name" {
  description = "The name of the Container Apps subnet"
  type        = string
  default     = "aca-subnet"
}

variable "database_subnet_name" {
  description = "The name of the database subnet"
  type        = string
  default     = "database-subnet"
}

variable "log_analytics_workspace_name" {
  description = "The name of the Log Analytics Workspace"
  type        = string
  default     = "ws-slackapp-aca"
}

variable "acr_name" {
  description = "The name of the Azure Container Registry (must be globally unique)"
  type        = string
}

variable "key_vault_name" {
  description = "The name of the Azure Key Vault (must be globally unique, 3-24 characters)"
  type        = string
}

variable "managed_identity_name" {
  description = "The name of the User Assigned Managed Identity"
  type        = string
  default     = "slackbot-aca-identity"
}

variable "container_apps_environment_name" {
  description = "The name of the Container Apps Environment"
  type        = string
  default     = "slackbot-aca-env"
}

variable "container_app_name" {
  description = "The name of the Container App"
  type        = string
  default     = "slackbot-aca"
}

variable "container_image_name" {
  description = "The name of the container image (repository name in ACR)"
  type        = string
  default     = "slackbot-aca"
}

variable "container_image_tag" {
  description = "The tag of the container image"
  type        = string
  default     = "1"
}

variable "container_name" {
  description = "The name of the container within the Container App"
  type        = string
  default     = "slackbot-aca"
}
