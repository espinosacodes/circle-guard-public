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
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group hosting the registry."
  type        = string
}

variable "sku" {
  description = "ACR SKU: Basic, Standard, or Premium."
  type        = string
  default     = "Basic"
}

variable "name_suffix" {
  description = "Optional unique suffix; ACR names are globally unique."
  type        = string
  default     = ""
}

variable "retention_days" {
  description = "Untagged manifest retention (Premium SKU only)."
  type        = number
  default     = 14
}

variable "aks_kubelet_identity_object_id" {
  description = "Kubelet identity object ID for granting AcrPull. Set null to skip."
  type        = string
  default     = null
}
