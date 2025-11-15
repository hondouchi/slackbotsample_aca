variable "vnet_name" {
  description = "The name of the Virtual Network"
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

variable "address_space" {
  description = "The address space for the Virtual Network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "aca_subnet_name" {
  description = "The name of the Container Apps subnet"
  type        = string
  default     = "aca-subnet"
}

variable "aca_subnet_address_prefixes" {
  description = "The address prefixes for the Container Apps subnet"
  type        = list(string)
  default     = ["10.0.0.0/23"]
}

variable "database_subnet_name" {
  description = "The name of the database subnet"
  type        = string
  default     = "database-subnet"
}

variable "database_subnet_address_prefixes" {
  description = "The address prefixes for the database subnet"
  type        = list(string)
  default     = ["10.0.2.0/24"]
}

variable "tags" {
  description = "A mapping of tags to assign to the resource"
  type        = map(string)
  default     = {}
}
