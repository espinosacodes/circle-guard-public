variable "project_prefix" {
  description = "Short project prefix; e.g. circleguard."
  type        = string
  default     = "circleguard"
}

variable "env" {
  description = "Environment name (dev, stage, prod)."
  type        = string
}

variable "region" {
  description = "GCP region for the subnet, router and NAT."
  type        = string
}

variable "subnet_cidr" {
  description = "Primary CIDR for the GKE node subnet."
  type        = string
}

variable "pods_cidr" {
  description = "Secondary CIDR used for GKE pods."
  type        = string
}

variable "services_cidr" {
  description = "Secondary CIDR used for GKE services."
  type        = string
}
