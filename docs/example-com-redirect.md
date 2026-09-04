# Redirect `example.com` to `www.example.com`

This configuration serves the application at:

```text
https://www.example.com
```

and returns an HTTP `301` redirect from:

```text
https://example.com
```

Both hostnames must be added to Azure Container Apps and both need managed TLS
certificates. The existing configuration already manages and secures
`example.com`; this procedure adds `www.example.com`. The redirect happens in Caddy
after Container Apps terminates TLS for the apex hostname.

## Phase 1: configure DNS

Leave `enable_www_custom_domain = false`, apply Terraform, and retrieve:

```bash
terraform output -json example.com_dns_records
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
dig @8.8.8.8 +short example.com A
dig @8.8.8.8 +short asuid.example.com TXT
dig @8.8.8.8 +short www.example.com CNAME
dig @8.8.8.8 +short asuid.www.example.com TXT
```

## Phase 2: create the www hostname

After all four records resolve, set:

```hcl
variable "enable_www_custom_domain" {
  type    = bool
  default = true
}
```

Plan and apply. Terraform creates the additional `www.example.com` hostname
record and deploys the Caddy redirect configuration.

## Phase 3: bind the www managed certificate

The apex certificate is already bound. Run this command once for `www`:

```bash
az containerapp hostname bind \
  --resource-group hello-nginx-rg \
  --name hello-nginx-app \
  --environment hello-nginx-env \
  --hostname www.example.com \
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
curl -I https://example.com
curl -I https://www.example.com
```

The apex response should include:

```text
HTTP/2 301
location: https://www.example.com/
```

The `www` response should return `HTTP/2 200`.

Keep both `asuid` TXT records while the domains are in use.
