terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}

  # Azure CLI for Windows can append CRLF when called from WSL.
  subscription_id = var.subscription_id == null ? null : trimspace(var.subscription_id)

  # Avoid AzureRM 4.x checking its broad legacy provider set on every run.
  resource_provider_registrations = "none"
  resource_providers_to_register  = ["Microsoft.App"]
}
