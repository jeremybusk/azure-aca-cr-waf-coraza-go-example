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

output "custom_domain_dns_records" {
  description = "Create these records at the registrar before setting enable_custom_domain to true."
  sensitive   = true
  value = {
    domain    = var.custom_domain
    a_name    = "@"
    a_value   = azurerm_container_app_environment.this.static_ip_address
    txt_name  = "asuid"
    txt_value = azurerm_container_app.this.custom_domain_verification_id
  }
}

output "custom_domain_url" {
  description = "Custom HTTPS URL after DNS validation and certificate issuance."
  value       = var.enable_custom_domain ? "https://${var.custom_domain}" : null
}
