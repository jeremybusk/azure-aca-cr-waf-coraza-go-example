# Redirect `uvoo.xyz` to `www.uvoo.xyz`

This configuration serves the application at:

```text
https://www.uvoo.xyz
```

and returns an HTTP `301` redirect from:

```text
https://uvoo.xyz
```

Both hostnames must be added to Azure Container Apps and both need managed TLS
certificates. The existing configuration already manages and secures
`uvoo.xyz`; this procedure adds `www.uvoo.xyz`. The redirect happens in NGINX
after Container Apps terminates TLS for the apex hostname.

## Phase 1: configure DNS

Leave `enable_www_custom_domain = false`, apply Terraform, and retrieve:

```bash
terraform output -json uvoo_xyz_dns_records
```

Configure the reported records at the registrar:

| Type | Host | Target |
| --- | --- | --- |
| `A` | `@` | Container Apps environment IP |
| `TXT` | `asuid` | Azure verification ID |
| `CNAME` | `www` | Stable `azurecontainerapps.io` application hostname |
| `TXT` | `asuid.www` | Azure verification ID |

Remove the existing `www` A record before creating the CNAME. DNS does not
permit a CNAME to coexist with other records at the same name.

Verify the records through public resolvers:

```bash
dig @8.8.8.8 +short uvoo.xyz A
dig @8.8.8.8 +short asuid.uvoo.xyz TXT
dig @8.8.8.8 +short www.uvoo.xyz CNAME
dig @8.8.8.8 +short asuid.www.uvoo.xyz TXT
```

## Phase 2: create the www hostname

After all four records resolve, set:

```hcl
variable "enable_www_custom_domain" {
  type    = bool
  default = true
}
```

Plan and apply. Terraform creates the additional `www.uvoo.xyz` hostname
record and deploys the NGINX redirect configuration.

## Phase 3: bind the www managed certificate

The apex certificate is already bound. Run this command once for `www`:

```bash
az containerapp hostname bind \
  --resource-group hello-nginx-rg \
  --name hello-nginx-app \
  --environment hello-nginx-env \
  --hostname www.uvoo.xyz \
  --validation-method CNAME
```

Allow up to 20 minutes for the managed certificate. Verify both bindings:

```bash
az containerapp hostname list \
  --resource-group hello-nginx-rg \
  --name hello-nginx-app \
  --output table
```

Both should show `SniEnabled`.

## Test

```bash
curl -I https://uvoo.xyz
curl -I https://www.uvoo.xyz
```

The apex response should include:

```text
HTTP/2 301
location: https://www.uvoo.xyz/
```

The `www` response should return `HTTP/2 200`.

Keep both `asuid` TXT records while the domains are in use.
