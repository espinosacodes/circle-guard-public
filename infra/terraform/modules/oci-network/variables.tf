variable "project_prefix" {
  description = "Short project prefix; e.g. circleguard."
  type        = string
  default     = "circleguard"
}

variable "env" {
  description = "Environment name."
  type        = string
}

variable "compartment_id" {
  description = "OCI compartment OCID where the network is created. Root compartment OCID (the tenancy) is fine for the trial."
  type        = string
}

variable "vcn_cidr" {
  description = "Address space for the VCN."
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR for the public subnet (LB, bastion)."
  type        = string
}

variable "private_subnet_cidr" {
  description = "CIDR for the private subnet (OKE worker nodes)."
  type        = string
}
