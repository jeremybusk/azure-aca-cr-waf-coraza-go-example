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

Initialize and review the deployment:

```bash
terraform init
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
