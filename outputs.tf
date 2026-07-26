output "app_url" {
  description = "Public HTTPS URL of the NGINX site."
  value       = "https://${azurerm_container_app.this.latest_revision_fqdn}"
}

output "resource_group_name" {
  description = "Resource group containing all resources created here."
  value       = azurerm_resource_group.this.name
}
