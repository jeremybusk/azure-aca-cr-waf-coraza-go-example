# Private Azure Container Registry

This independent Terraform stack provisions:

- a Basic-tier private Azure Container Registry;
- a user-assigned identity with `AcrPull` for Container Apps;
- `AcrPush` for the GitHub Actions service principal; and
- optional `AcrPush` for the principal applying this stack locally.

Terraform provisions the registry and RBAC. Docker BuildKit builds the
application, and GitHub Actions or a developer pushes it. Keeping builds out
of Terraform makes plans deterministic and prevents local Docker state from
becoming part of infrastructure state.

## Prerequisites

The applying principal needs permission to create role assignments, such as
Owner or User Access Administrator plus Contributor, at the registry resource
group or subscription scope.

Get the GitHub service principal **object ID**:

```bash
CLIENT_ID="$(cd ../../bootstrap && terraform output -raw github_client_id)"
az ad sp show --id "$CLIENT_ID" --query id --output tsv
```

Copy `terraform.tfvars.example` to `terraform.tfvars` and set the subscription
ID and returned object ID. Copy `backend.hcl.example` to `backend.hcl`.

## Apply

```bash
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply tfplan
```

Add the values from this output as GitHub Actions repository variables:

```bash
terraform output -json github_actions_variables
```

The registry name must be globally unique. If the default is unavailable,
change `registry_name` before the first apply.

## Local image build

From the repository root:

```bash
ACR_NAME="$(terraform -chdir=infrastructure/container-registry output -json registry | jq -r .name)"
ACR_SERVER="$(terraform -chdir=infrastructure/container-registry output -json registry | jq -r .login_server)"
IMAGE_TAG="20260724-local"

az acr login --name "$ACR_NAME"

docker build \
  --secret id=geolite_archive,src=tmp/GeoLite2-Country_20260724.tar.gz \
  --tag "$ACR_SERVER/hello-world:$IMAGE_TAG" \
  applications/hello-world

docker push "$ACR_SERVER/hello-world:$IMAGE_TAG"
```

Never commit the MaxMind archive, database, account ID, or license key.
