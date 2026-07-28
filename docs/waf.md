# Coraza, OWASP CRS, and GeoIP

The Container App runs an immutable private image:

```text
uvooacrprodwus2001.azurecr.io/hello-world:<git-sha>
```

Azure Container Apps terminates public TLS and forwards HTTP to port 8080 in
the replica. Caddy resolves the sender's country, evaluates the generated
country policy, then evaluates allowed requests with Coraza and OWASP CRS.

```text
Internet → Container Apps ingress → GeoIP policy → Coraza/CRS → static site
```

Application files are under
[`../applications/hello-world/`](../applications/hello-world/). The image runs
without root privileges. Its wrapper copies the baked Caddyfile into the
base image's supported writable configuration directory, then invokes the
upstream entrypoint to generate Coraza configuration and activate CRS.

## GeoIP policy

Edit
[`geoip-policy.yaml`](../applications/hello-world/config/geoip-policy.yaml):

```yaml
version: 1
enabled: true
mode: blocklist
countries:
  - XX
  - YY
unknown_country: allow
```

`blocklist` rejects listed ISO 3166-1 alpha-2 country codes. `allowlist`
rejects every known country not listed. `unknown_country` controls addresses
that cannot be resolved. An enabled allowlist must not be empty.

`allow_ips` contains explicit IPv4 or IPv6 CIDRs that bypass the country
decision while remaining protected by Coraza and CRS. For a single address,
use `/32` for IPv4 or `/128` for IPv6. Residential addresses may change, so
do not treat this as a permanent identity mechanism.

The build validates the schema, rejects duplicate or malformed country codes,
and generates a Caddy expression snippet. The default policy is an empty
blocklist, so GeoIP is active but does not block a real country until the list
is deliberately populated.

Set `enabled: false` to build without GeoIP. In that mode no MaxMind archive
is required and the image uses `Caddyfile.no-geo`.

Azure appends the trustworthy sender address at the right side of
`X-Forwarded-For`. Caddy trusts only connections from private ingress proxy
ranges and enables `trusted_proxies_strict`, so it evaluates the header
right-to-left rather than accepting a spoofable leftmost value.

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

For initial tuning of a real application, set this image environment value:

```text
CORAZA_RULE_ENGINE=DetectionOnly
```

Restore blocking with:

```text
CORAZA_RULE_ENGINE=On
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

## Database and image updates

GitHub Actions caches the GeoLite2 Country archive using
`GEOIP_DATABASE_VERSION`. Normal policy builds reuse that version. Changing
the variable creates a cache miss and downloads the current release, which is
then cached for later builds. GitHub may evict an old cache, causing one new
download. The workflow temporarily stages the archive under the ignored
application `.build/` directory. Local builds can copy a dated archive there
from the ignored `tmp/` directory. Never commit the archive or extracted
database.

## Revision rollback

The Container App uses single-revision mode. Azure directs traffic to one
revision and retains older revisions inactive, avoiding duplicate steady-state
replica cost. List retained revisions:

```bash
az containerapp revision list \
  --resource-group hello-nginx-rg \
  --name hello-nginx-app \
  --output table
```

To roll back, copy the image value from a known healthy revision and set
`container_image` to that immutable ACR tag, then run the normal saved
Terraform plan and apply workflow. This keeps Terraform state aligned with the
revision receiving traffic.

The Dockerfile pins Caddy, Coraza-Caddy, the GeoIP module, and its base CRS
image. Review upstream releases and verification tests before changing those
pins. Every GitHub deployment pushes a commit-SHA tag, so Terraform never
deploys `latest`.

## Cost and scaling

Caddy, GeoIP, Coraza, and CRS share 0.25 vCPU and 0.5 GiB. The app keeps
`min_replicas = 0` and `max_replicas = 1`, so compute can scale to zero and
cannot create unexpected replica fan-out. ACR Basic has a separate fixed
charge. If the revision exceeds memory, increase the allocation to 0.5 vCPU
and 1 GiB and reassess after observing real traffic.
