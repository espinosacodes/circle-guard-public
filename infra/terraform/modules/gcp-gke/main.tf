terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

locals {
  name_prefix = "${var.project_prefix}-${var.env}"

  default_labels = {
    env        = var.env
    project    = var.project_prefix
    managed-by = "terraform"
  }
}

resource "google_container_cluster" "this" {
  name     = "${local.name_prefix}-gke"
  location = var.region

  # Pull the default node pool, manage ours separately.
  remove_default_node_pool = true
  initial_node_count       = 1

  # The temporary default pool exists only while GKE creates the control plane.
  # Use standard disks so regional clusters do not exhaust the default SSD quota.
  node_config {
    machine_type = "e2-medium"
    disk_size_gb = 20
    disk_type    = "pd-standard"
  }

  network    = var.network
  subnetwork = var.subnetwork

  networking_mode = "VPC_NATIVE"

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  release_channel {
    channel = var.release_channel
  }

  workload_identity_config {
    workload_pool = "${var.gcp_project_id}.svc.id.goog"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_ipv4_cidr
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
  }

  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  deletion_protection = var.deletion_protection

  resource_labels = local.default_labels

  lifecycle {
    # After the temporary default pool is removed, GKE reports the managed
    # primary pool's node settings here. They are owned by the node-pool resource.
    ignore_changes = [node_config]
  }
}

resource "google_container_node_pool" "primary" {
  name     = "${local.name_prefix}-primary-pool"
  location = var.region
  cluster  = google_container_cluster.this.name

  autoscaling {
    min_node_count = var.node_count_min
    max_node_count = var.node_count_max
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = "pd-standard"
    image_type   = "COS_CONTAINERD"

    spot        = var.preemptible
    preemptible = false # use 'spot' instead; preemptible is legacy

    service_account = var.node_service_account
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = merge(local.default_labels, {
      pool = "primary"
    })

    tags = ["gke-node", "${local.name_prefix}-gke"]

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}
