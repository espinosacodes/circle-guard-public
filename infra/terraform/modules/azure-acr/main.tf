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
  # ACR names: 5-50 chars, alphanumeric only, globally unique.
  name = lower(replace("${var.project_prefix}${var.env}acr${var.name_suffix}", "-", ""))

  default_tags = {
    env        = var.env
    project    = var.project_prefix
    managed-by = "terraform"
  }
}

resource "azurerm_container_registry" "this" {
  name                = local.name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = false
  tags                = local.default_tags

  dynamic "retention_policy" {
    for_each = var.sku == "Premium" ? [1] : []
    content {
      enabled = true
      days    = var.retention_days
    }
  }
}

# Allow AKS kubelet to pull from ACR
resource "azurerm_role_assignment" "aks_pull" {
  count = var.aks_kubelet_identity_object_id == null ? 0 : 1

  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPull"
  principal_id         = var.aks_kubelet_identity_object_id
}
