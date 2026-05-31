variable "project_prefix" {
  description = "Short project prefix; e.g. circleguard."
  type        = string
  default     = "circleguard"
}

variable "env" {
  description = "Environment name."
  type        = string
}

variable "region" {
  description = "Artifact Registry region."
  type        = string
}
