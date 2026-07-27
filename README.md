# Azure NGINX Hello World

A minimal NGINX site deployed to **Azure Container Apps** with Terraform.
It uses the Consumption workload profile, scales to zero while idle, and is
capped at one small replica to keep test costs low.

## What gets created

- One Azure resource group
- One Azure Container Apps environment
- One public Container App running the official `nginx:alpine` image

The NGINX startup command writes the Hello World page into the container, so
there is no image build and no Azure Container Registry to pay for. Log
Analytics, Application Insights, a virtual network, and a dedicated workload
profile are deliberately omitted.

## Prerequisites

- An Azure subscription
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [Terraform](https://developer.hashicorp.com/terraform/install) 1.6 or newer

## Deploy

Sign in and select the subscription to use:

```bash
az login
az account set --subscription "<subscription-name-or-id>"
export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv | tr -d '\r\n')"
```

The `tr` is intentional: when Windows Azure CLI is invoked from WSL, its
output can contain a Windows carriage return that AzureRM treats as part of
the subscription ID.

If Terraform still reports a subscription ID ending in `\r`, clear all
environment overrides and pass the clean value directly:

```bash
unset ARM_SUBSCRIPTION_ID TF_VAR_subscription_id
terraform plan \
  -var='subscription_id=00000000-0000-0000-0000-000000000000'
```

Replace the example UUID with the subscription ID printed by:

```bash
az account show --query id -o tsv | tr -d '\r\n'
```

This repository uses Azure Blob Storage for remote state so local and GitHub
deployments share the same infrastructure record. Complete the
[Remote state](#remote-state) setup below, copy `backend.hcl.example` to
`backend.hcl`, and fill in the three Azure resource names.

Initialize and review the deployment:

```bash
terraform init -backend-config=backend.hcl
terraform plan
```

The first plan may pause while Azure registers the `Microsoft.App` resource
provider. Its status can be checked independently:

```bash
az provider show \
  --namespace Microsoft.App \
  --query registrationState \
  --output tsv
```

Deploy it:

```bash
terraform apply
```

Terraform prints `app_url` when deployment finishes. Open it in a browser, or:

```bash
curl "$(terraform output -raw app_url)"
```

The first request after the app scales to zero can take several seconds while
Azure starts a replica.

### Customize

Defaults deploy to `westus2` with names prefixed by `hello-nginx`. Override
them on the command line:

```bash
terraform apply \
  -var='location=eastus' \
  -var='name_prefix=my-nginx-test'
```

Names must use lowercase letters, numbers, and hyphens. If the generated
Container App hostname conflicts, choose a more distinctive `name_prefix`.

## Custom domain

The apex domain defaults to `uvoo.xyz` and is deliberately enabled in two
phases so the deployment does not fail before public DNS is ready.

First leave `enable_custom_domain = false`, apply, and read:

```bash
terraform output -json custom_domain_dns_records
```

Create the reported `A` record for `@` and `TXT` record for `asuid` in the
registrar's DNS control panel. Do not point the domain at a revision-specific
hostname. Terraform treats the verification token as sensitive, so the normal
apply summary redacts this output; requesting it explicitly with `-json`
reveals the values needed for DNS.

After public DNS resolves, set the variable default to `true` or deploy with:

```bash
terraform apply -var='enable_custom_domain=true'
```

Azure Container Apps then validates `uvoo.xyz`, binds it to the app, and
issues a free managed TLS certificate. GitHub Actions uses variable defaults,
so a permanent CI deployment should change the default in `variables.tf` to
`true` in a second pull request after the DNS records exist.

## Cost controls

- Consumption profile: no dedicated always-on compute
- `min_replicas = 0`: the app can scale to zero
- `max_replicas = 1`: traffic cannot create multiple replicas
- 0.25 vCPU and 0.5 GiB: smallest supported general-purpose allocation
- No Log Analytics workspace, registry, public IP resource, or virtual network

Azure's monthly Container Apps free grant is shared by the subscription, not
reserved for this deployment. Usage beyond the grant, outbound data transfer,
and any unrelated Azure resources can still incur charges. Terraform itself
does not create a budget or spending cap.

## Remove everything

Destroy the test as soon as you are finished:

```bash
terraform destroy
```

Confirm in the Azure portal that the resource group shown by
`terraform output resource_group_name` is gone.

## GitHub Actions

The workflow in `.github/workflows/terraform.yml` validates pull requests and
runs a saved plan followed by apply on pushes to `main` or manual dispatches.
The deploy job uses the GitHub environment named `azure`; add required
reviewers to that environment if deployments should require approval.

Authentication uses GitHub OIDC, so **no Azure client secret is needed**.
Create an Entra application or user-assigned managed identity, grant it
`Contributor` on the target subscription, and add a federated credential for:

```text
repo:<github-owner>/<github-repository>:environment:azure
```

Add these GitHub **Actions repository variables** under **Settings → Secrets
and variables → Actions → Variables**:

| Variable | Value |
| --- | --- |
| `AZURE_CLIENT_ID` | Application/client ID of the federated Azure identity |
| `AZURE_TENANT_ID` | Microsoft Entra tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |
| `TF_STATE_RESOURCE_GROUP` | Resource group containing the state account |
| `TF_STATE_STORAGE_ACCOUNT` | Globally unique Azure Storage account name |
| `TF_STATE_CONTAINER` | Blob container name, for example `tfstate` |

The three Azure IDs are identifiers, not credentials. They may be stored as
variables rather than secrets. The federated identity must exactly match the
repository and `azure` environment configured above.

### Remote state

GitHub runners are temporary, so the workflow stores Terraform state in Azure
Blob Storage. The [`bootstrap/`](bootstrap/) Terraform stack creates the
resource group, storage account, private container, data-protection settings,
delete lock, and state-access roles. Follow
[`bootstrap/README.md`](bootstrap/README.md) once before the first root
deployment. The federated identity also needs `Contributor` on the application
subscription so it can deploy the Container Apps resources.

When switching an existing local deployment to this backend, initialize it
with the same values and allow Terraform to migrate the local state:

```bash
terraform init -migrate-state \
  -backend-config="resource_group_name=<state-resource-group>" \
  -backend-config="storage_account_name=<state-storage-account>" \
  -backend-config="container_name=<state-container>" \
  -backend-config="key=hello-nginx.tfstate" \
  -backend-config="use_azuread_auth=true"
```

State storage generally costs very little, but unlike the scale-to-zero
container app it is not a free, ephemeral resource. Never commit a state or
saved-plan file because either can contain sensitive values.

### Main branch ruleset

Import `.github/rulesets/main.json` under **Settings → Rules → Rulesets → New
ruleset → Import a ruleset**. It protects `main` with:

- one approving pull-request review;
- approval of the most recent push by someone other than its author;
- dismissal of stale approvals and resolution of review conversations;
- the up-to-date `Validate` GitHub Actions check;
- squash or rebase merges only; and
- deletion and force-push protection.

Repository administrators can explicitly bypass the ruleset. GitHub omits
bypass actors when exporting rulesets, so confirm after import that
**Repository role: Admin — Always allow** appears in the bypass list.
