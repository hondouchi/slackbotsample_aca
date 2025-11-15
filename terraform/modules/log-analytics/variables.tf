variable "name" {
  description = "The name of the Log Analytics Workspace"
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

variable "sku" {
  description = "Specifies the SKU of the Log Analytics Workspace"
  type        = string
  default     = "PerGB2018"
}

variable "retention_in_days" {
  description = "The workspace data retention in days"
  type        = number
  default     = 30
}

variable "tags" {
  description = "A mapping of tags to assign to the resource"
  type        = map(string)
  default     = {}
}
