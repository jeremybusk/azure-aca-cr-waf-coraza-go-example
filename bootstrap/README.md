# Terraform state bootstrap

This stack creates the Azure Blob backend used by the root Terraform
configuration. It starts with local state because the remote backend does not
exist yet, then migrates its own state into that backend.

## 1. Configure

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars
```

Set `subscription_id`. To grant GitHub Actions access during the same apply,
also set `github_identity_object_id` to the Entra **object ID** of its service
principal or managed identity.

## 2. Create the backend

Do not create `backend.tf` yet.

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

This creates:

- resource group `rg-tfstate-prod-westus2-001`;
- storage account `uvoosttfstateprodwus2001` using Standard LRS;
- private container `tfstate`;
- blob versioning and seven-day soft deletion;
- Blob Data Contributor access for the current identity and optional GitHub
  identity; and
- a deletion lock on the storage account.

## 3. Migrate the bootstrap state

```bash
cp backend.tf.example backend.tf
terraform init -migrate-state
```

Approve the state-copy prompt. `backend.tf` is intentionally git-ignored
because backend settings are deployment-specific. The bootstrap stack uses:

```text
bootstrap/prod/terraform.tfstate
```

The root application uses a separate state blob:

```text
azuresdx1/prod/hello-nginx.tfstate
```

## Destruction warning

The delete lock intentionally prevents accidental removal. To intentionally
destroy this state infrastructure, first set:

```hcl
enable_delete_lock = false
```

Apply that change before running `terraform destroy`. Deleting this stack also
deletes the state history for every application using its container.
