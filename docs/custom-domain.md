# Exposing Azure Container Apps with a custom domain

This runbook documents how `uvoo.xyz` is exposed publicly through Azure
Container Apps with registrar-hosted DNS and an Azure-managed TLS certificate.

## Architecture

```text
uvoo.xyz
  A record -> Container Apps environment public IP
  TXT asuid -> Azure domain verification ID
                    |
                    v
        hello-nginx-app ingress
                    |
                    v
           NGINX container
```

The generated Container Apps hostname remains available as a fallback:

```text
https://hello-nginx-app.purplegrass-98a3fa44.westus2.azurecontainerapps.io
```

Do not publish a hostname containing a revision suffix such as
`hello-nginx-app--0000001`. Revision hostnames stop working when Azure
deactivates the corresponding revision.

## DNS records

For the apex domain `uvoo.xyz`, configure these records at the registrar:

| Type | Host | Value |
| --- | --- | --- |
| `A` | `@` | Container Apps environment static public IP |
| `TXT` | `asuid` | Container App custom-domain verification ID |

Some registrars use an empty host field instead of `@`. The resulting record
names must be:

```text
uvoo.xyz
asuid.uvoo.xyz
```

Terraform intentionally marks the verification value sensitive. Retrieve both
expected values from the root stack:

```bash
terraform output -json custom_domain_dns_records
```

## Verify public DNS

Query more than one public resolver to avoid relying on a local DNS cache:

```bash
dig @8.8.8.8 +short uvoo.xyz A
dig @8.8.8.8 +short asuid.uvoo.xyz TXT

dig @1.1.1.1 +short uvoo.xyz A
dig @1.1.1.1 +short asuid.uvoo.xyz TXT
```

The `A` response must equal Terraform's `a_value`. The TXT response must equal
Terraform's `txt_value`. A registrar normally appends `.uvoo.xyz`
automatically; entering `asuid.uvoo.xyz` where only `asuid` is expected can
accidentally create `asuid.uvoo.xyz.uvoo.xyz`.

## Enable the Terraform binding

Only after both records resolve publicly, enable the root variable:

```hcl
variable "enable_custom_domain" {
  type    = bool
  default = true
}
```

Plan and apply:

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

The custom-domain resource validates ownership and adds `uvoo.xyz` to the
Container App. At this point `az containerapp hostname list` can show the
hostname with `BindingType: Disabled`: the hostname exists, but HTTPS is not
yet bound.

## Create and bind the managed certificate

Run this once after Terraform has created the custom-domain resource:

```bash
az containerapp hostname bind \
  --resource-group hello-nginx-rg \
  --name hello-nginx-app \
  --environment hello-nginx-env \
  --hostname uvoo.xyz \
  --validation-method HTTP
```

This command initiates creation of the free Azure-managed certificate and
binds it to the hostname. It can take up to 20 minutes. Let the command finish
and do not run it repeatedly while issuance is in progress.

## Verify the hostname and certificate

Check the binding:

```bash
az containerapp hostname list \
  --resource-group hello-nginx-rg \
  --name hello-nginx-app \
  --output table
```

The final binding should be:

```text
BindingType    Name
-------------  --------
SniEnabled     uvoo.xyz
```

An apex domain uses `HTTP` validation; a subdomain using a CNAME uses `CNAME`
validation.

Test HTTPS:

```bash
curl -I https://uvoo.xyz
```

## Keep the `asuid` TXT record

Leave `asuid.uvoo.xyz` in DNS while the custom domain is in use.

Removing it generally does not immediately disconnect an already validated
domain or invalidate an already issued certificate. However, Azure can need
the record again when the binding is recreated, moved, recovered, or
revalidated. Keeping it also provides persistent proof tying the domain to
this Azure tenant and reduces custom-domain takeover risk. A TXT record has no
meaningful runtime or Azure cost.

If the Container App is intentionally retired, remove the public `A` record
first so the domain does not point at abandoned infrastructure. Remove the
`asuid` record only as part of the same controlled DNS cleanup or when
replacing it with a new Azure verification ID.

## Troubleshooting

### Azure returns “Container App is stopped or does not exist”

Confirm the URL does not contain a revision suffix. Use:

```bash
terraform output -raw app_url
```

### The hostname is `Disabled`

Verify `uvoo.xyz A` and `asuid.uvoo.xyz TXT` through public resolvers. Wait for
DNS propagation, then run the managed-certificate binding command above. A
disabled binding is expected after Terraform adds the hostname but before this
one-time binding step completes.

### Inspect managed certificates

```bash
az containerapp env certificate list \
  --resource-group hello-nginx-rg \
  --name hello-nginx-env \
  --output table
```

Look for failed or pending provisioning states. Also check whether a CAA
record on `uvoo.xyz` prevents the managed certificate authority from issuing
the certificate.

## References

- [Azure Container Apps custom domains and certificates](https://learn.microsoft.com/azure/container-apps/custom-domains-certificates)
- [Azure Container Apps free managed certificates](https://learn.microsoft.com/azure/container-apps/custom-domains-managed-certificates)
- [Microsoft guidance for preventing dangling DNS and domain takeover](https://learn.microsoft.com/azure/security/fundamentals/subdomain-takeover)
