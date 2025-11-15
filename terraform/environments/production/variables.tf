variable "acr_name" {
  description = "The name of the Azure Container Registry (must be globally unique)"
  type        = string
}

variable "key_vault_name" {
  description = "The name of the Azure Key Vault (must be globally unique, 3-24 characters)"
  type        = string
}

variable "container_image_name" {
  description = "The name of the container image"
  type        = string
  default     = "slackbot"
}

variable "container_image_tag" {
  description = "The tag of the container image"
  type        = string
  default     = "latest"
}
