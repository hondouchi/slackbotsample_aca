variable "identity_name" {
  description = "Name of the user assigned managed identity"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "tags" {
  description = "Tags to apply to the identity"
  type        = map(string)
  default     = {}
}
