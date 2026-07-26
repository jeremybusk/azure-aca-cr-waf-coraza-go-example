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

variable "github_identity_object_id" {
  description = "Optional Entra service principal or managed identity object ID used by GitHub Actions."
  type        = string
  default     = null
  nullable    = true
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
