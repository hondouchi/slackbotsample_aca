variable "environment_name" {
  description = "The name of the Container App Environment"
  type        = string
}

variable "app_name" {
  description = "The name of the Container App"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "location" {
  description = "The Azure region where resources will be created"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics Workspace"
  type        = string
}

variable "infrastructure_subnet_id" {
  description = "The ID of the infrastructure subnet"
  type        = string
}

variable "registry_server" {
  description = "The container registry server"
  type        = string
}

variable "container_name" {
  description = "The name of the container"
  type        = string
  default     = "app"
}

variable "container_image" {
  description = "The container image to deploy"
  type        = string
}

variable "cpu" {
  description = "The amount of vCPU to allocate to the container"
  type        = number
  default     = 0.5
}

variable "memory" {
  description = "The amount of memory to allocate to the container"
  type        = string
  default     = "1Gi"
}

variable "min_replicas" {
  description = "The minimum number of replicas"
  type        = number
  default     = 0
}

variable "max_replicas" {
  description = "The maximum number of replicas"
  type        = number
  default     = 10
}

variable "env_vars" {
  description = "Environment variables for the container"
  type = list(object({
    name        = string
    value       = optional(string)
    secret_name = optional(string)
  }))
  default = []
}

variable "secrets" {
  description = "Secrets for the container app"
  type = list(object({
    name                = string
    key_vault_secret_id = string
  }))
  default = []
}

variable "ingress_external_enabled" {
  description = "Is the ingress external?"
  type        = bool
  default     = true
}

variable "ingress_target_port" {
  description = "The target port for ingress traffic"
  type        = number
  default     = 3000
}

variable "tags" {
  description = "A mapping of tags to assign to the resource"
  type        = map(string)
  default     = {}
}
