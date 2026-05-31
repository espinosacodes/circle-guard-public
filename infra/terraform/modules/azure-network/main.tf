terraform {
  required_version = ">= 1.6"
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

resource "azurerm_resource_group" "this" {
  name     = "${local.name_prefix}-rg"
  location = var.location
  tags     = local.default_tags
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${local.name_prefix}-vnet"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.vnet_cidr]
  tags                = local.default_tags
}

resource "azurerm_subnet" "aks" {
  name                 = "${local.name_prefix}-aks-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.aks_subnet_cidr]
}

resource "azurerm_subnet" "appgw" {
  name                 = "${local.name_prefix}-appgw-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.appgw_subnet_cidr]
}

resource "azurerm_network_security_group" "aks" {
  name                = "${local.name_prefix}-aks-nsg"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.default_tags

  security_rule {
    name                       = "allow-https-inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}
