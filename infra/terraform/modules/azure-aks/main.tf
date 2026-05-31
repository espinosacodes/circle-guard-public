terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.80"
    }
  }
}

locals {
  name_prefix = "${var.project_prefix}-${var.env}"

  default_tags = {
    env        = var.env
    project    = var.project_prefix
    managed-by = "terraform"
  }
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = "${local.name_prefix}-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${local.name_prefix}-aks"
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier

  default_node_pool {
    name                 = "system"
    vm_size              = var.system_vm_size
    vnet_subnet_id       = var.subnet_id
    node_count           = var.system_node_count
    orchestrator_version = var.kubernetes_version
    type                 = "VirtualMachineScaleSets"
    only_critical_addons_enabled = true

    upgrade_settings {
      max_surge = "33%"
    }

    tags = local.default_tags
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "calico"
    load_balancer_sku = "standard"
    service_cidr      = var.service_cidr
    dns_service_ip    = var.dns_service_ip
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  role_based_access_control_enabled = true

  tags = local.default_tags
}

# --- User node pool (workloads) ---
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id

  vm_size              = var.user_vm_size
  vnet_subnet_id       = var.subnet_id
  orchestrator_version = var.kubernetes_version

  auto_scaling_enabled = true
  min_count            = var.user_node_min
  max_count            = var.user_node_max

  mode = "User"

  tags = local.default_tags
}

# --- Optional spot pool (FinOps) ---
resource "azurerm_kubernetes_cluster_node_pool" "spot" {
  count = var.spot_enabled ? 1 : 0

  name                  = "spot"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id

  vm_size              = var.spot_vm_size
  vnet_subnet_id       = var.subnet_id
  orchestrator_version = var.kubernetes_version

  auto_scaling_enabled = true
  min_count            = 0
  max_count            = var.spot_node_max

  priority        = "Spot"
  eviction_policy = "Delete"
  spot_max_price  = -1 # pay up to the on-demand rate

  node_labels = {
    "kubernetes.azure.com/scalesetpriority" = "spot"
  }
  node_taints = [
    "kubernetes.azure.com/scalesetpriority=spot:NoSchedule"
  ]

  mode = "User"
  tags = local.default_tags
}
