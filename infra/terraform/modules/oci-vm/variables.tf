variable "project_prefix" {
  description = "Short prefix, e.g. circleguard."
  type        = string
  default     = "circleguard"
}

variable "env" {
  description = "Environment name (dev, stage, prod)."
  type        = string
}

variable "compartment_id" {
  description = "OCI compartment OCID (defaults to tenancy root)."
  type        = string
}

variable "subnet_id" {
  description = "Public subnet OCID — must permit ingress TCP/80."
  type        = string
}

variable "image_id" {
  description = "OCID of the OS image. Use a plain Oracle-Linux-8.x x86_64 (NOT GPU, NOT aarch64) for VM.Standard.E2.1.Micro."
  type        = string
}
