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
  description = "OCI compartment OCID. Root compartment (tenancy OCID) is acceptable for the trial."
  type        = string
}

variable "vcn_id" {
  description = "VCN OCID from the oci-network module."
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet OCID (used by the OKE API endpoint and service LBs)."
  type        = string
}

variable "private_subnet_id" {
  description = "Private subnet OCID hosting the worker nodes."
  type        = string
}

variable "kubernetes_version" {
  description = "OKE Kubernetes version. Use 'v1.30.1' or similar; check `oci ce cluster-options get --cluster-option-id all`."
  type        = string
  default     = "v1.30.1"
}

variable "cluster_type" {
  description = "OKE tier: BASIC_CLUSTER (free control plane) or ENHANCED_CLUSTER (paid, ~$0.10/h)."
  type        = string
  default     = "BASIC_CLUSTER"
}

variable "endpoint_is_public" {
  description = "If true, the OKE API server gets a public IP. Set false if you want bastion-only access."
  type        = bool
  default     = true
}

variable "pods_cidr" {
  description = "CIDR for Kubernetes pods. Must NOT overlap the VCN."
  type        = string
  default     = "10.244.0.0/16"
}

variable "services_cidr" {
  description = "CIDR for Kubernetes services. Must NOT overlap the VCN or pods CIDR."
  type        = string
  default     = "10.96.0.0/16"
}

# --- Worker pool shape (Always Free defaults) ---
variable "node_shape" {
  description = "Compute shape for the worker pool. Default is the Ampere ARM Always-Free shape."
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "node_shape_ocpus" {
  description = "OCPUs per node. Always-Free quota is 4 OCPU total across the tenancy."
  type        = number
  default     = 2
}

variable "node_shape_memory_gb" {
  description = "Memory (GB) per node. Always-Free quota is 24 GB total across the tenancy."
  type        = number
  default     = 12
}

variable "node_count" {
  description = "Number of worker nodes. Keep at 1 for stage, 2 for prod, to stay inside 4 OCPU/24 GB free quota."
  type        = number
  default     = 1
}

variable "node_image_id" {
  description = "OCID of the OKE-compatible OS image for the worker pool. Look up with `oci ce node-pool-options get --node-pool-option-id all`."
  type        = string
}

variable "region_for_kubeconfig" {
  description = "OCI region identifier (e.g. sa-bogota-1) injected into the get-kubeconfig command output."
  type        = string
}
