output "registry" {
  description = "Private registry values used for builds and deployments."
  value = {
    id           = azurerm_container_registry.this.id
    name         = azurerm_container_registry.this.name
    login_server = azurerm_container_registry.this.login_server
  }
}

output "pull_identity" {
  description = "User-assigned identity granted AcrPull on the registry."
  value = {
    id           = azurerm_user_assigned_identity.container_pull.id
    client_id    = azurerm_user_assigned_identity.container_pull.client_id
    principal_id = azurerm_user_assigned_identity.container_pull.principal_id
  }
}

output "github_actions_variables" {
  description = "Additional non-secret GitHub Actions variables."
  value = {
    ACR_NAME                   = azurerm_container_registry.this.name
    ACR_LOGIN_SERVER           = azurerm_container_registry.this.login_server
    ACR_PULL_IDENTITY_ID       = azurerm_user_assigned_identity.container_pull.id
    CONTAINER_IMAGE_REPOSITORY = "hello-world"
  }
}
