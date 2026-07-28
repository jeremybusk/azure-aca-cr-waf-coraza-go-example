# Hello World container

This image combines:

- Caddy;
- Coraza WAF;
- OWASP Core Rule Set;
- a MaxMind-compatible country lookup module;
- a build-generated country policy; and
- the static Hello World page.

## Configure the country policy

Edit `config/geoip-policy.yaml`:

```yaml
version: 1
enabled: true
mode: blocklist
countries:
  - XX
unknown_country: allow
```

Use uppercase ISO 3166-1 alpha-2 codes. An empty blocklist blocks nothing. An
empty enabled allowlist is rejected to prevent an accidental global lockout.

## Build with GeoIP

From the repository root:

```bash
docker build \
  --secret id=geolite_archive,src=tmp/GeoLite2-Country_20260724.tar.gz \
  --tag hello-world:local \
  applications/hello-world
```

The tarball must contain `GeoLite2-Country.mmdb`, `COPYRIGHT.txt`, and
`LICENSE.txt` beneath one top-level directory. BuildKit mounts the archive
only for the extraction step, so the tarball and download credentials do not
become image layers.

## Build without GeoIP

Set `enabled: false`, then build without `--secret`:

```bash
docker build --tag hello-world:local applications/hello-world
```

The no-GeoIP build continues to use Coraza and CRS.

## Run locally

```bash
docker run --rm --publish 8080:8080 hello-world:local
curl -i http://localhost:8080/
```

The Azure deployment uses the rightmost sender address added to
`X-Forwarded-For` by Container Apps. Direct local requests normally resolve
as an unknown country unless a test header is supplied.
