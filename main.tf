resource "azurerm_resource_group" "this" {
  name     = "${var.name_prefix}-rg"
  location = var.location
  tags     = var.tags
}

resource "azurerm_container_app_environment" "this" {
  name                = "${var.name_prefix}-env"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags

  # A v2 environment with only the serverless Consumption profile.
  # Omitting logs_destination streams logs without provisioning Log Analytics.
  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
}

resource "azurerm_container_app" "this" {
  name                         = "${var.name_prefix}-app"
  container_app_environment_id = azurerm_container_app_environment.this.id
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"
  tags                         = var.tags

  ingress {
    external_enabled = true
    target_port      = 80
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 0
    max_replicas = 1

    container {
      name   = "nginx"
      image  = "nginx:alpine"
      cpu    = 0.25
      memory = "0.5Gi"

      command = ["/bin/sh"]
      args = [
        "-c",
        "printf '%s\n' '<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><title>Hello All from Azure</title></head><body><h1>Hello All, World!</h1><p>NGINX is running on Azure Container Apps.</p></body></html>' > /usr/share/nginx/html/index.html && exec nginx -g 'daemon off;'"
      ]
    }
  }
}

resource "azurerm_container_app_custom_domain" "this" {
  count = var.enable_custom_domain ? 1 : 0

  name             = var.custom_domain
  container_app_id = azurerm_container_app.this.id

  # Azure populates these asynchronously when issuing its free managed
  # certificate. Ignoring them prevents Terraform from undoing the binding.
  lifecycle {
    ignore_changes = [
      certificate_binding_type,
      container_app_environment_certificate_id
    ]
  }
}
