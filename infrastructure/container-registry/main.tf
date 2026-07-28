data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "registry" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_container_registry" "this" {
  name                = var.registry_name
  resource_group_name = azurerm_resource_group.registry.name
  location            = azurerm_resource_group.registry.location
  sku                 = "Basic"
  admin_enabled       = false

  public_network_access_enabled = true
  anonymous_pull_enabled        = false

  tags = var.tags
}

resource "azurerm_user_assigned_identity" "container_pull" {
  name                = var.pull_identity_name
  resource_group_name = azurerm_resource_group.registry.name
  location            = azurerm_resource_group.registry.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "container_app_pull" {
  scope                            = azurerm_container_registry.this.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_user_assigned_identity.container_pull.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "github_push" {
  scope                            = azurerm_container_registry.this.id
  role_definition_name             = "AcrPush"
  principal_id                     = trimspace(var.github_principal_object_id)
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "current_principal_push" {
  count = var.grant_current_principal_push ? 1 : 0

  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPush"
  principal_id         = data.azurerm_client_config.current.object_id
}
