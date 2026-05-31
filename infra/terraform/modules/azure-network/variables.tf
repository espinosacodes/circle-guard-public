variable "project_prefix" {
  description = "Short project prefix; e.g. circleguard."
  type        = string
  default     = "circleguard"
}

variable "env" {
  description = "Environment name."
  type        = string
}

variable "location" {
  description = "Azure region (e.g. eastus, westeurope)."
  type        = string
}

variable "vnet_cidr" {
  description = "Address space for the VNet."
  type        = string
}

variable "aks_subnet_cidr" {
  description = "CIDR for the AKS node subnet."
  type        = string
}

variable "appgw_subnet_cidr" {
  description = "CIDR for the (optional) Application Gateway subnet."
  type        = string
}
