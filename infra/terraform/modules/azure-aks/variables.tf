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
  description = "Resource group from azure-network module."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID from azure-network module."
  type        = string
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version."
  type        = string
  default     = "1.30"
}

variable "sku_tier" {
  description = "AKS SKU tier: Free or Standard. Standard adds an uptime SLA."
  type        = string
  default     = "Free"
}

variable "system_vm_size" {
  description = "VM size for the system node pool."
  type        = string
  default     = "Standard_B2s"
}

variable "system_node_count" {
  description = "Fixed node count for the system pool."
  type        = number
  default     = 1
}

variable "user_vm_size" {
  description = "VM size for the user node pool."
  type        = string
  default     = "Standard_B2s"
}

variable "user_node_min" {
  description = "Min nodes in the user pool."
  type        = number
  default     = 1
}

variable "user_node_max" {
  description = "Max nodes in the user pool."
  type        = number
  default     = 3
}

variable "service_cidr" {
  description = "CIDR for Kubernetes services. Must NOT overlap the VNet."
  type        = string
  default     = "10.200.0.0/16"
}

variable "dns_service_ip" {
  description = "IP of the cluster DNS, inside service_cidr."
  type        = string
  default     = "10.200.0.10"
}

variable "spot_enabled" {
  description = "If true, create an additional spot node pool."
  type        = bool
  default     = false
}

variable "spot_vm_size" {
  description = "VM size for the spot node pool."
  type        = string
  default     = "Standard_B2s"
}

variable "spot_node_max" {
  description = "Max nodes in the spot pool (min is always 0 so it can scale to zero)."
  type        = number
  default     = 3
}
