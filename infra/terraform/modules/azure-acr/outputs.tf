output "registry_name" {
  description = "ACR name."
  value       = azurerm_container_registry.this.name
}

output "registry_id" {
  description = "ACR resource ID."
  value       = azurerm_container_registry.this.id
}

output "login_server" {
  description = "Login server, e.g. circleguarddevacr.azurecr.io"
  value       = azurerm_container_registry.this.login_server
}
