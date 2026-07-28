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
cp tmp/GeoLite2-Country_20260724.tar.gz \
  applications/hello-world/.build/GeoLite2-Country.tar.gz
docker build \
  --tag hello-world:local \
  applications/hello-world
rm applications/hello-world/.build/GeoLite2-Country.tar.gz
```

The tarball must contain `GeoLite2-Country.mmdb`, `COPYRIGHT.txt`, and
`LICENSE.txt` beneath one top-level directory. The temporary `.build` input is
git-ignored. The archive is consumed in an intermediate stage and is not
copied into the final runtime image. MaxMind download credentials are never
passed to Docker.

## Build without GeoIP

Set `enabled: false`, then build without staging an archive:

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
