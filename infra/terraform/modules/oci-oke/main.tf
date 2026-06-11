terraform {
  required_version = ">= 1.5"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0"
    }
  }
}

locals {
  name_prefix = "${var.project_prefix}-${var.env}"

  default_freeform_tags = {
    env        = var.env
    project    = var.project_prefix
    managed-by = "terraform"
  }
}

# Single Always-Free AD in sa-bogota-1 (no need to enumerate; fixed at SWmf:SA-BOGOTA-1-AD-1).
# We still query it dynamically so the module works in any region.
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}

# Latest supported Kubernetes version (filtered to a single string).
data "oci_containerengine_cluster_option" "k8s" {
  cluster_option_id = "all"
}

# ============================================================================
# Trial vs Production
# ----------------------------------------------------------------------------
# This module ships with Always-Free safe defaults:
#   - shape  = VM.Standard.A1.Flex (Ampere ARM, included in the 4 OCPU + 24 GB
#              monthly free quota)
#   - ocpus per node       = 2
#   - memory per node      = 12 GB
#   - node_count           = 1 (stage) / 2 (prod) — both stay inside free tier
#
# To move to paid tier, override these at env level:
#   node_shape       = "VM.Standard.E4.Flex"   # AMD EPYC
#   node_shape_ocpus = 2
#   node_shape_memory_gb = 16
#   node_count       = 3
#   pods_cidr / services_cidr = sized for prod scale
# ============================================================================

# --- OKE control plane (managed, free of charge under "Basic" type) ---
resource "oci_containerengine_cluster" "this" {
  compartment_id     = var.compartment_id
  name               = "${local.name_prefix}-oke"
  vcn_id             = var.vcn_id
  kubernetes_version = var.kubernetes_version
  type               = var.cluster_type # BASIC_CLUSTER is the free option

  endpoint_config {
    is_public_ip_enabled = var.endpoint_is_public
    subnet_id            = var.public_subnet_id
  }

  options {
    service_lb_subnet_ids = [var.public_subnet_id]

    add_ons {
      is_kubernetes_dashboard_enabled = false
      is_tiller_enabled               = false
    }

    kubernetes_network_config {
      pods_cidr     = var.pods_cidr
      services_cidr = var.services_cidr
    }
  }

  freeform_tags = local.default_freeform_tags
}

# --- Worker node pool (Ampere A1 Flex, Always Free) ---
resource "oci_containerengine_node_pool" "workers" {
  cluster_id         = oci_containerengine_cluster.this.id
  compartment_id     = var.compartment_id
  name               = "${local.name_prefix}-oke-pool"
  kubernetes_version = var.kubernetes_version
  node_shape         = var.node_shape

  node_shape_config {
    ocpus         = var.node_shape_ocpus
    memory_in_gbs = var.node_shape_memory_gb
  }

  node_config_details {
    size = var.node_count

    # VCN-native pod networking: nodes live in the private subnet.
    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
      subnet_id           = var.private_subnet_id
    }

    freeform_tags = local.default_freeform_tags
  }

  node_source_details {
    source_type = "IMAGE"
    image_id    = var.node_image_id
  }

  freeform_tags = local.default_freeform_tags
}
