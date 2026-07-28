#!/bin/sh
set -eu

if grep -qx true /opt/app/geoip-enabled; then
  if [ ! -s /opt/geoip/GeoLite2-Country.mmdb ]; then
    echo >&2 "GeoLite2-Country.mmdb is missing; rebuild with the geolite_archive BuildKit secret"
    exit 1
  fi
  source_caddyfile=/opt/app/Caddyfile
else
  source_caddyfile=/opt/app/Caddyfile.no-geo
fi

mkdir -p /config/caddy
cp "$source_caddyfile" /config/caddy/Caddyfile

exec /entrypoint.sh "$@"
