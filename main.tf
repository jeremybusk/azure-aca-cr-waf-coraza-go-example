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
    target_port      = 8080
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
      name   = "caddy-coraza"
      image  = var.container_image
      cpu    = 0.25
      memory = "0.5Gi"

      command = ["/bin/sh"]
      args = [
        "-c",
        "mkdir -p /config/caddy /tmp/caddy-site && printf '%s' '${base64encode(templatefile("${path.module}/container/Caddyfile.tftpl", {
          redirect_apex_domain = var.redirect_apex_domain
          primary_www_domain   = var.primary_www_domain
        }))}' | base64 -d > /config/caddy/Caddyfile && printf '%s' '${base64encode(file("${path.module}/container/index.html"))}' | base64 -d > /tmp/caddy-site/index.html && exec /entrypoint.sh caddy run --config /etc/caddy/Caddyfile --adapter caddyfile"
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

resource "azurerm_container_app_custom_domain" "www" {
  count = var.enable_www_custom_domain ? 1 : 0

  name             = var.primary_www_domain
  container_app_id = azurerm_container_app.this.id

  lifecycle {
    ignore_changes = [
      certificate_binding_type,
      container_app_environment_certificate_id
    ]
  }
}
