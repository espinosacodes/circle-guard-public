output "resource_group_name" {
  description = "Resource group containing the network."
  value       = azurerm_resource_group.this.name
}

output "resource_group_location" {
  description = "Region of the resource group."
  value       = azurerm_resource_group.this.location
}

output "vnet_id" {
  description = "ID of the VNet."
  value       = azurerm_virtual_network.vnet.id
}

output "vnet_name" {
  description = "Name of the VNet."
  value       = azurerm_virtual_network.vnet.name
}

output "aks_subnet_id" {
  description = "Subnet ID to pass into the AKS module."
  value       = azurerm_subnet.aks.id
}

output "appgw_subnet_id" {
  description = "Subnet ID reserved for Application Gateway."
  value       = azurerm_subnet.appgw.id
}
