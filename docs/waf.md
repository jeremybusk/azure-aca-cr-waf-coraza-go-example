# Coraza and OWASP CRS

The Container App runs the public image:

```text
ghcr.io/coreruleset/coraza-crs:4.25.0-caddy-alpine-202604120304
```

Azure Container Apps terminates public TLS and forwards HTTP to port 8080 in
the replica. Caddy evaluates every request with Coraza and OWASP CRS before it
redirects the apex hostname or serves the static page.

```text
Internet → Azure Container Apps ingress → Caddy → Coraza/CRS → static site
```

The configuration is in
[`../container/Caddyfile.tftpl`](../container/Caddyfile.tftpl). The initial
policy enables blocking, paranoia level 1, inbound anomaly threshold 5, and
outbound anomaly threshold 4.

The official container runs without root privileges. Terraform writes the
rendered Caddy override to its supported writable location,
`/config/caddy/Caddyfile`, and writes the static page under
`/tmp/caddy-site`. The image entrypoint copies and formats the Caddy override,
generates Coraza's environment-driven configuration, and activates CRS before
starting Caddy. The image's `/srv` directory remains read-only.

## Verify normal traffic

After applying Terraform:

```bash
curl -i https://www.uvoo.xyz/
curl -i https://uvoo.xyz/
```

The first request should return the Hello World page. The second should return
a permanent redirect to `https://www.uvoo.xyz/`.

## Verify that CRS blocks an attack-shaped test request

Only run this against an application you own:

```bash
curl -i --get \
  --data-urlencode "search=<script>alert(1)</script>" \
  https://www.uvoo.xyz/
```

CRS should reject the request, normally with HTTP `403`. A normal request
should continue to return HTTP `200`:

```bash
curl -i --get \
  --data-urlencode "search=hello" \
  https://www.uvoo.xyz/
```

Container console logs are available without adding a Log Analytics
workspace:

```bash
az containerapp logs show \
  --resource-group hello-nginx-rg \
  --name hello-nginx-app \
  --type console \
  --follow
```

## Detection-only mode

For initial tuning of a real application, change this directive:

```text
SecRuleEngine On
```

to:

```text
SecRuleEngine DetectionOnly
```

Apply the change, exercise representative requests, and review WAF events
before enabling blocking again. The static Hello World site is intentionally
simple enough to begin in blocking mode.

## Tune false positives

Do not raise the anomaly threshold globally as the first response to a false
positive. Identify the CRS rule ID and add the narrowest exclusion possible
for the affected route, parameter, or cookie. Keep exclusions in the
`directives` block with a unique local rule ID.

Test normal requests and known attack-shaped requests after every tuning
change. Do not log authorization headers, cookies, or request bodies unless
the security need outweighs the data-exposure risk.

## Upgrade CRS

The image uses the immutable dated tag
`4.25.0-caddy-alpine-202604120304`. Changing the tag creates a new Container
Apps revision. Review the CRS release notes and repeat the normal/blocking
verification tests before upgrading. Verify a prospective tag exists before
planning:

```bash
docker buildx imagetools inspect \
  ghcr.io/coreruleset/coraza-crs:4.25.0-caddy-alpine-202604120304
```

This command is read-only and does not need to pull the image layers.

## Cost and scaling

Coraza and CRS share the existing Caddy container allocation of 0.25 vCPU and
0.5 GiB. The app keeps `min_replicas = 0` and `max_replicas = 1`, so it can
scale to zero and cannot create unexpected replica fan-out. If the revision
restarts because it exceeds memory, increase the allocation to 0.5 vCPU and
1 GiB and reassess the cost after observing real traffic.
