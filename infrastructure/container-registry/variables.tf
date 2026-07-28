variable "subscription_id" {
  description = "Azure subscription in which to create the registry."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", trimspace(var.subscription_id)))
    error_message = "subscription_id must be an Azure subscription UUID."
  }
}

variable "location" {
  description = "Azure region for the registry and pull identity."
  type        = string
  default     = "westus2"
}

variable "resource_group_name" {
  description = "Resource group containing the private container registry."
  type        = string
  default     = "rg-acr-prod-westus2-001"
}

variable "registry_name" {
  description = "Globally unique alphanumeric Azure Container Registry name."
  type        = string
  default     = "uvooacrprodwus2001"

  validation {
    condition     = can(regex("^[a-zA-Z0-9]{5,50}$", var.registry_name))
    error_message = "registry_name must contain 5-50 alphanumeric characters."
  }
}

variable "pull_identity_name" {
  description = "User-assigned identity used by Azure Container Apps for ACR pulls."
  type        = string
  default     = "id-acr-pull-prod-westus2-001"
}

variable "github_principal_object_id" {
  description = "Object ID of the GitHub Actions service principal created by bootstrap."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", trimspace(var.github_principal_object_id)))
    error_message = "github_principal_object_id must be an Entra object UUID, not the application client ID."
  }
}

variable "grant_current_principal_push" {
  description = "Grant the principal applying this stack AcrPush for local builds."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to registry resources."
  type        = map(string)
  default = {
    application = "azuresdx1"
    environment = "prod"
    managed-by  = "terraform"
    purpose     = "container-images"
  }
}
