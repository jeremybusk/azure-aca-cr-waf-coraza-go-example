output "backend_config" {
  description = "Values used by the root Terraform AzureRM backend."
  value = {
    resource_group_name  = azurerm_resource_group.state.name
    storage_account_name = azurerm_storage_account.state.name
    container_name       = azurerm_storage_container.state.name
    key                  = "azuresdx1/prod/hello-nginx.tfstate"
    use_azuread_auth     = true
  }
}

output "storage_account_id" {
  description = "Resource ID used when assigning additional state access."
  value       = azurerm_storage_account.state.id
}
