output "app_url" {
  description = "Stable public HTTPS URL of the NGINX site."
  value       = "https://${azurerm_container_app.this.ingress[0].fqdn}"
}

output "latest_revision_url" {
  description = "Revision-specific URL for diagnostics; it stops working after the revision is deactivated."
  value       = "https://${azurerm_container_app.this.latest_revision_fqdn}"
}

output "resource_group_name" {
  description = "Resource group containing all resources created here."
  value       = azurerm_resource_group.this.name
}
