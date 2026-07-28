# syntax=docker/dockerfile:1.7

ARG CADDY_VERSION=2.11.2
ARG CORAZA_CADDY_VERSION=v2.5.0
ARG GEOIP_CADDY_VERSION=v1.0.3
ARG CORAZA_CRS_IMAGE=ghcr.io/coreruleset/coraza-crs:4.25.0-caddy-alpine-202604120304

FROM caddy:${CADDY_VERSION}-builder-alpine AS caddy-builder
ARG CORAZA_CADDY_VERSION
ARG GEOIP_CADDY_VERSION
RUN xcaddy build \
    --with github.com/corazawaf/coraza-caddy/v2@${CORAZA_CADDY_VERSION} \
    --with github.com/porech/caddy-maxmind-geolocation@${GEOIP_CADDY_VERSION}

FROM python:3.13-alpine AS policy-builder
WORKDIR /src
RUN pip install --no-cache-dir PyYAML==6.0.2
COPY config/geoip-policy.yaml config/geoip-policy.yaml
COPY scripts/generate_geoip_policy.py scripts/generate_geoip_policy.py
COPY .build/ /tmp/build/
RUN mkdir -p /out/geoip \
    && python scripts/generate_geoip_policy.py \
         --input config/geoip-policy.yaml \
         --output /out/geoip-policy.caddy \
         --enabled-marker /out/geoip-enabled
RUN if grep -qx true /out/geoip-enabled; then \
      test -s /tmp/build/GeoLite2-Country.tar.gz \
      || { echo >&2 "GeoIP is enabled, but .build/GeoLite2-Country.tar.gz is missing"; exit 1; }; \
      mkdir -p /tmp/geolite; \
      tar -xzf /tmp/build/GeoLite2-Country.tar.gz -C /tmp/geolite; \
      cp /tmp/geolite/*/GeoLite2-Country.mmdb /out/geoip/; \
      cp /tmp/geolite/*/COPYRIGHT.txt /out/geoip/; \
      cp /tmp/geolite/*/LICENSE.txt /out/geoip/; \
      test -s /out/geoip/GeoLite2-Country.mmdb; \
    fi \
    && rm -rf /tmp/build /tmp/geolite

FROM ${CORAZA_CRS_IMAGE} AS runtime
LABEL org.opencontainers.image.source="https://github.com/jeremybusk/azuresdx1" \
      org.opencontainers.image.description="Caddy with Coraza, OWASP CRS, and optional MaxMind GeoLite2 country policy"

COPY --from=caddy-builder /usr/bin/caddy /usr/bin/caddy
COPY --from=policy-builder --chown=caddy:caddy /out/geoip /opt/geoip
COPY --from=policy-builder --chown=caddy:caddy /out/geoip-policy.caddy /opt/app/geoip-policy.caddy
COPY --from=policy-builder --chown=caddy:caddy /out/geoip-enabled /opt/app/geoip-enabled
COPY --chown=caddy:caddy Caddyfile /opt/app/Caddyfile
COPY --chown=caddy:caddy Caddyfile.no-geo /opt/app/Caddyfile.no-geo
COPY --chown=caddy:caddy public /opt/app/public
COPY --chown=caddy:caddy --chmod=0555 scripts/entrypoint.sh /opt/app/entrypoint.sh

USER caddy:caddy
ENTRYPOINT ["/opt/app/entrypoint.sh"]
CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
