variable "subscription_id" {
  description = "Azure subscription in which to create the Terraform state resources."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", trimspace(var.subscription_id)))
    error_message = "subscription_id must be an Azure subscription UUID."
  }
}

variable "location" {
  description = "Azure region for the Terraform state resources."
  type        = string
  default     = "westus2"
}

variable "resource_group_name" {
  description = "Resource group containing the Terraform state storage account."
  type        = string
  default     = "rg-tfstate-prod-westus2-001"
}

variable "storage_account_name" {
  description = "Globally unique storage account name used for Terraform state."
  type        = string
  default     = "uvoosttfstateprodwus2001"
}

variable "container_name" {
  description = "Private blob container used for Terraform state files."
  type        = string
  default     = "tfstate"
}

variable "github_owner" {
  description = "GitHub user or organization that owns the repository."
  type        = string
  default     = "jeremybusk"
}

variable "github_owner_id" {
  description = "Immutable numeric GitHub ID of the repository owner."
  type        = string
  default     = "19394715"
}

variable "github_repository" {
  description = "GitHub repository trusted by the federated identity."
  type        = string
  default     = "azuresdx1"
}

variable "github_repository_id" {
  description = "Immutable numeric GitHub repository ID."
  type        = string
  default     = "1312417313"
}

variable "github_environment" {
  description = "GitHub environment trusted by the federated identity."
  type        = string
  default     = "azure"
}

variable "github_application_display_name" {
  description = "Display name of the Entra application used by GitHub Actions."
  type        = string
  default     = "gha-azuresdx1-prod"
}

variable "enable_delete_lock" {
  description = "Protect the state storage account from accidental deletion."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to the Terraform state resources."
  type        = map(string)
  default = {
    environment = "prod"
    managed-by  = "terraform"
    purpose     = "terraform-state"
  }
}
