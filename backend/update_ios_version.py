#!/usr/bin/env python3
"""
Fetches the latest iOS version from Apple's IPSW feed and writes
the result to a JSON file for the Verifium API.

Usage:
    python3 update_ios_version.py [--output /var/www/verifium/api/v1/ios-latest.json]
"""

import argparse
import json
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

APPLE_IPSW_API = "https://api.ipsw.me/v4/device/iPhone17,3?type=ipsw"
DEFAULT_OUTPUT = Path(__file__).parent / "ios-latest.json"


def fetch_latest_ios_version() -> str:
    """Query the IPSW.me API for the latest signed iOS version."""
    req = urllib.request.Request(APPLE_IPSW_API, headers={"Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = json.loads(resp.read())

    firmwares = data.get("firmwares", [])
    # Filter to signed firmwares and pick the highest version
    signed = [fw for fw in firmwares if fw.get("signed", False)]
    if not signed:
        raise RuntimeError("No signed firmware found in IPSW.me response")

    # Sort by version components descending
    def version_key(fw):
        parts = fw["version"].split(".")
        return tuple(int(p) for p in parts if p.isdigit())

    signed.sort(key=version_key, reverse=True)
    return signed[0]["version"]


def main():
    parser = argparse.ArgumentParser(description="Update latest iOS version JSON")
    parser.add_argument(
        "--output", "-o",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"Output JSON file path (default: {DEFAULT_OUTPUT})",
    )
    args = parser.parse_args()

    version = fetch_latest_ios_version()

    payload = {
        "latest": version,
        "updated_at": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, indent=2) + "\n")
    print(f"✓ Updated {args.output}: iOS {version}")


if __name__ == "__main__":
    main()
