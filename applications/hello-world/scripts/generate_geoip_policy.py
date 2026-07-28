#!/usr/bin/env python3
"""Validate a small GeoIP YAML policy and emit a Caddy expression matcher."""

from __future__ import annotations

import argparse
import ipaddress
import pathlib
import re
import sys

import yaml


COUNTRY_CODE = re.compile(r"^[A-Z]{2}$")
VALID_MODES = {"allowlist", "blocklist"}
VALID_UNKNOWN_POLICIES = {"allow", "block"}
EXPECTED_KEYS = {
    "version",
    "enabled",
    "mode",
    "countries",
    "allow_ips",
    "unknown_country",
}


def fail(message: str) -> None:
    raise ValueError(message)


def load_policy(path: pathlib.Path) -> dict:
    value = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        fail("policy must be a YAML mapping")

    unknown_keys = sorted(set(value) - EXPECTED_KEYS)
    if unknown_keys:
        fail(f"unsupported policy keys: {', '.join(unknown_keys)}")
    if value.get("version") != 1:
        fail("version must be 1")
    if not isinstance(value.get("enabled"), bool):
        fail("enabled must be true or false")

    mode = value.get("mode")
    if mode not in VALID_MODES:
        fail("mode must be allowlist or blocklist")

    unknown_country = value.get("unknown_country")
    if unknown_country not in VALID_UNKNOWN_POLICIES:
        fail("unknown_country must be allow or block")

    countries = value.get("countries")
    if not isinstance(countries, list):
        fail("countries must be a YAML list")
    if not all(isinstance(code, str) and COUNTRY_CODE.fullmatch(code) for code in countries):
        fail("every country must be an uppercase ISO 3166-1 alpha-2 code")
    if len(countries) != len(set(countries)):
        fail("countries must not contain duplicates")
    if value["enabled"] and mode == "allowlist" and not countries:
        fail("an enabled allowlist must contain at least one country")

    allow_ips = value.get("allow_ips", [])
    if not isinstance(allow_ips, list):
        fail("allow_ips must be a YAML list")
    if not all(
        isinstance(network, str) and "/" in network for network in allow_ips
    ):
        fail("every allow_ips entry must be an IPv4 or IPv6 CIDR string")
    try:
        parsed_allow_ips = [
            str(ipaddress.ip_network(network, strict=True)) for network in allow_ips
        ]
    except ValueError as exc:
        fail(f"every allow_ips entry must be a canonical IPv4 or IPv6 CIDR: {exc}")
    if len(parsed_allow_ips) != len(set(parsed_allow_ips)):
        fail("allow_ips must not contain duplicates")

    value["countries"] = sorted(countries)
    value["allow_ips"] = sorted(parsed_allow_ips)
    return value


def render(policy: dict) -> str:
    if not policy["enabled"]:
        return "# GeoIP policy is disabled.\n"

    countries = list(policy["countries"])
    directive = ""
    if policy["mode"] == "blocklist":
        if policy["unknown_country"] == "block":
            countries.append("UNK")
        if countries:
            directive = f"\t\t\tdeny_countries {' '.join(countries)}\n"
    else:
        if policy["unknown_country"] == "allow":
            countries.append("UNK")
        directive = f"\t\t\tallow_countries {' '.join(countries)}\n"

    ip_exception = ""
    if policy["allow_ips"]:
        ip_exception = f"\tnot client_ip {' '.join(policy['allow_ips'])}\n"

    return (
        "# Generated from config/geoip-policy.yaml; do not edit.\n"
        "@geo_denied {\n"
        f"{ip_exception}"
        "\tnot {\n"
        "\t\tmaxmind_geolocation {\n"
        "\t\t\tdb_path /opt/geoip/GeoLite2-Country.mmdb\n"
        f"{directive}"
        "\t\t}\n"
        "\t}\n"
        "}\n"
        'respond @geo_denied "Access from this location is not permitted." 403\n'
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=pathlib.Path)
    parser.add_argument("--output", required=True, type=pathlib.Path)
    parser.add_argument("--enabled-marker", required=True, type=pathlib.Path)
    args = parser.parse_args()

    try:
        policy = load_policy(args.input)
        args.output.write_text(render(policy), encoding="utf-8")
        args.enabled_marker.write_text(
            "true\n" if policy["enabled"] else "false\n",
            encoding="utf-8",
        )
    except (OSError, ValueError, yaml.YAMLError) as exc:
        print(f"invalid GeoIP policy: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
