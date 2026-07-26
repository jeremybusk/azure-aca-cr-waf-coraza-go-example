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
the defaults target `jeremybusk/azuresdx1`, its immutable GitHub owner and
repository IDs, and its `azure` GitHub environment. Override the corresponding
variables only if the repository changes. The immutable IDs must match the
subject claim printed by GitHub's OIDC login step.

Your signed-in account must be permitted to create Entra application
registrations and Azure role assignments. Depending on tenant policy, that
can require the Application Administrator directory role plus Owner or User
Access Administrator on the Azure subscription.

## 2. Create the backend

Do not create `backend.tf` yet.

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

If the storage bootstrap was already initialized before the identity resources
were added, run `terraform init -upgrade` once to install the AzureAD provider,
then run the plan and apply commands above.

This creates:

- resource group `rg-tfstate-prod-westus2-001`;
- storage account `uvoosttfstateprodwus2001` using Standard LRS;
- private container `tfstate`;
- blob versioning and seven-day soft deletion;
- an Entra application, service principal, and GitHub OIDC federated
  credential;
- subscription Contributor access for GitHub deployments;
- Blob Data Contributor access for the current and GitHub identities; and
- a deletion lock on the storage account.

After apply, print the values to add as GitHub Actions repository variables:

```bash
terraform output github_actions_variables
terraform output github_federated_subject
```

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
