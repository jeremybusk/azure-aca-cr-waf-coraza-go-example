variable "subscription_id" {
  description = "Azure subscription ID. When null, set ARM_SUBSCRIPTION_ID in the shell."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.subscription_id == null ||
      can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", trimspace(var.subscription_id)))
    )
    error_message = "subscription_id must be an Azure subscription UUID."
  }
}

variable "location" {
  description = "Azure region in which to deploy the resources."
  type        = string
  default     = "westus2"
}

variable "name_prefix" {
  description = "Lowercase prefix used for all resource names."
  type        = string
  default     = "hello-nginx"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,19}[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix must be 3-21 characters, start with a letter, end with a letter or number, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "container_image" {
  description = "Immutable ACR image reference, preferably tagged with the Git commit SHA."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9.-]+\\.azurecr\\.io/[a-z0-9._/-]+:[A-Za-z0-9._-]+$", trimspace(var.container_image)))
    error_message = "container_image must be a tagged Azure Container Registry image."
  }
}

variable "container_registry_server" {
  description = "ACR login server, for example uvooacrprodwus2001.azurecr.io."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]+\\.azurecr\\.io$", trimspace(var.container_registry_server)))
    error_message = "container_registry_server must be an Azure Container Registry login server."
  }
}

variable "container_registry_identity_id" {
  description = "Resource ID of the user-assigned identity granted AcrPull."
  type        = string

  validation {
    condition     = can(regex("(?i)^/subscriptions/[0-9a-f-]+/resourceGroups/[^/]+/providers/Microsoft\\.ManagedIdentity/userAssignedIdentities/[^/]+$", trimspace(var.container_registry_identity_id)))
    error_message = "container_registry_identity_id must be a user-assigned managed identity resource ID."
  }
}

variable "custom_domain" {
  description = "Apex custom domain to bind to the Container App."
  type        = string
  default     = "uvoo.xyz"
}

variable "enable_custom_domain" {
  description = "Enable only after the required A and TXT records exist in public DNS."
  type        = bool
  default     = true
}

variable "redirect_apex_domain" {
  description = "Apex domain that redirects permanently to the canonical www hostname."
  type        = string
  default     = "uvoo.xyz"
}

variable "primary_www_domain" {
  description = "Canonical www hostname that serves the application."
  type        = string
  default     = "www.uvoo.xyz"
}

variable "enable_www_custom_domain" {
  description = "Enable only after the www.uvoo.xyz CNAME and asuid.www TXT records exist in public DNS."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to the Azure resources."
  type        = map(string)
  default = {
    application = "caddy-coraza-hello-world"
    environment = "test"
    managed-by  = "terraform"
  }
}
