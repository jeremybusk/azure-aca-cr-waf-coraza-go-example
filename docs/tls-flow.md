Your setup uses an Azure Container Apps managed certificate. It does not use Key Vault or Azure Front Door.

The request path is:

```text
Browser
  → DNS: uvoo.xyz resolves to Container Apps environment IP
  → Azure Container Apps ingress terminates TLS
  → Azure routes the request to hello-nginx-app
  → Caddy receives traffic on container port 8080
  → Coraza and OWASP CRS inspect the request
```

Certificate lifecycle:

1. The `A` record routes `uvoo.xyz` to the Container Apps environment.
2. The `asuid` TXT record proves domain ownership.
3. Azure validates the domain.
4. `az containerapp hostname bind` requests a free managed certificate.
5. Azure stores the certificate as a managed certificate within `hello-nginx-env`.
6. The certificate is bound to `uvoo.xyz` using SNI.
7. Azure manages the private key and certificate renewal.

The certificate resource resides conceptually at:

```text
hello-nginx-env
└── managedCertificates
    └── <Azure-generated-managed-certificate>
```

You cannot download its private key. Azure controls it entirely.

Inspect it with:

```bash
az containerapp env certificate list \
  --resource-group hello-nginx-rg \
  --name hello-nginx-env \
  --output table
```

Check the hostname binding:

```bash
az containerapp hostname list \
  --resource-group hello-nginx-rg \
  --name hello-nginx-app \
  --output table
```

You want:

```text
BindingType    Name
-------------  --------
SniEnabled     uvoo.xyz
```

If it still says `Disabled`, request and bind the certificate:

```bash
az containerapp hostname bind \
  --resource-group hello-nginx-rg \
  --name hello-nginx-app \
  --environment hello-nginx-env \
  --hostname uvoo.xyz \
  --validation-method HTTP
```

Keep both the `A` and `asuid` records in place so Azure can continue routing and revalidating the domain.

Front Door would only be needed if you later want features such as WAF, global routing, CDN caching, or multi-region failover. Key Vault would be relevant if you supplied and managed your own certificate. Neither is necessary for this low-cost setup. [Azure managed-certificate documentation](https://learn.microsoft.com/en-us/azure/container-apps/custom-domains-managed-certificates)
