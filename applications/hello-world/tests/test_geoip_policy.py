from __future__ import annotations

import pathlib
import sys
import tempfile
import unittest

import yaml

SCRIPTS = pathlib.Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))

import generate_geoip_policy as policy  # noqa: E402


class GeoIPPolicyTests(unittest.TestCase):
    def load(self, value: dict) -> dict:
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "policy.yaml"
            path.write_text(yaml.safe_dump(value), encoding="utf-8")
            return policy.load_policy(path)

    def base(self, **overrides: object) -> dict:
        value = {
            "version": 1,
            "enabled": True,
            "mode": "blocklist",
            "countries": [],
            "allow_ips": [],
            "unknown_country": "allow",
        }
        value.update(overrides)
        return value

    def test_empty_blocklist_blocks_nothing(self) -> None:
        rendered = policy.render(self.load(self.base()))
        self.assertNotIn("deny_countries", rendered)
        self.assertIn("maxmind_geolocation", rendered)

    def test_unknown_can_be_blocked(self) -> None:
        rendered = policy.render(
            self.load(self.base(countries=["CA"], unknown_country="block"))
        )
        self.assertIn("deny_countries CA UNK", rendered)

    def test_allowlist_can_allow_unknown(self) -> None:
        rendered = policy.render(
            self.load(
                self.base(
                    mode="allowlist",
                    countries=["US"],
                    unknown_country="allow",
                )
            )
        )
        self.assertIn("allow_countries US UNK", rendered)

    def test_empty_enabled_allowlist_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "must contain at least one"):
            self.load(self.base(mode="allowlist"))

    def test_malformed_country_code_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "uppercase ISO"):
            self.load(self.base(countries=["usa"]))

    def test_allowed_ip_is_exempt_from_geo_denial(self) -> None:
        rendered = policy.render(
            self.load(
                self.base(
                    countries=["US"],
                    allow_ips=["203.0.113.42/32", "2001:db8:1234::/64"],
                )
            )
        )
        self.assertIn(
            "not client_ip 2001:db8:1234::/64 203.0.113.42/32",
            rendered,
        )
        self.assertIn("deny_countries US", rendered)

    def test_host_address_without_cidr_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "IPv4 or IPv6 CIDR"):
            self.load(self.base(allow_ips=["203.0.113.42"]))

    def test_duplicate_allowed_ip_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "must not contain duplicates"):
            self.load(
                self.base(
                    allow_ips=["203.0.113.42/32", "203.0.113.42/32"],
                )
            )


if __name__ == "__main__":
    unittest.main()
