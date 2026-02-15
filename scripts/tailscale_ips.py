#!/usr/bin/env python3
"""Sync Tailscale device IPs to GCP Cloud Armor security policy.

Fetches all device IPs from the Tailscale API and updates the
Cloud Armor allowlist so only Tailscale-connected devices can
reach the gateway.

Requires:
  - TAILSCALE_API_KEY env var (or --api-key flag)
  - TAILSCALE_TAILNET env var (or --tailnet flag)
  - gcloud CLI authenticated with appropriate permissions
"""

import argparse
import json
import os
import subprocess
import sys
import urllib.request


TAILSCALE_API = "https://api.tailscale.com/api/v2"
SECURITY_POLICY_NAME = "eag-tailscale-allowlist"
RULE_PRIORITY = 1000


def get_tailscale_ips(api_key: str, tailnet: str) -> list[str]:
    """Fetch all device IPs from Tailscale API."""
    url = f"{TAILSCALE_API}/tailnet/{tailnet}/devices"
    req = urllib.request.Request(url)
    req.add_header("Authorization", f"Bearer {api_key}")

    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read())

    ips = set()
    for device in data.get("devices", []):
        for addr in device.get("addresses", []):
            # Add as /32 for individual IPs
            if ":" not in addr:  # IPv4 only
                ips.add(f"{addr}/32")
    return sorted(ips)


def get_tf_output(env: str) -> dict:
    tf_dir = f"terraform/environments/{env}"
    raw = subprocess.run(
        ["terraform", f"-chdir={tf_dir}", "output", "-json"],
        check=True, capture_output=True, text=True,
    ).stdout.strip()
    outputs = json.loads(raw)
    return {k: v["value"] for k, v in outputs.items()}


def update_cloud_armor(project_id: str, ips: list[str]) -> None:
    """Update the Cloud Armor security policy with new IP list."""
    if not ips:
        print("No IPs found, skipping update.")
        return

    # Cloud Armor has a limit of ~256 IPs per rule. Split if needed.
    # For most organizations, this should be well within this limit.
    ip_list = ",".join(ips)

    print(f"Updating Cloud Armor rule with {len(ips)} IPs...")
    subprocess.run(
        [
            "gcloud", "compute", "security-policies", "rules", "update",
            str(RULE_PRIORITY),
            f"--project={project_id}",
            f"--security-policy={SECURITY_POLICY_NAME}",
            "--action=allow",
            f"--src-ip-ranges={ip_list}",
            "--description=Allow Tailscale network (auto-synced)",
        ],
        check=True,
    )
    print("Cloud Armor policy updated.")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Sync Tailscale IPs to Cloud Armor"
    )
    parser.add_argument("--env", choices=["prod", "staging"], default="prod")
    parser.add_argument("--api-key", default=os.environ.get("TAILSCALE_API_KEY"))
    parser.add_argument("--tailnet", default=os.environ.get("TAILSCALE_TAILNET"))
    parser.add_argument("--dry-run", action="store_true", help="Print IPs without updating")
    args = parser.parse_args()

    if not args.api_key:
        print("Error: TAILSCALE_API_KEY env var or --api-key required")
        sys.exit(1)
    if not args.tailnet:
        print("Error: TAILSCALE_TAILNET env var or --tailnet required")
        sys.exit(1)

    print(f"Fetching Tailscale device IPs for tailnet: {args.tailnet}")
    ips = get_tailscale_ips(args.api_key, args.tailnet)
    print(f"Found {len(ips)} device IPs")

    if args.dry_run:
        for ip in ips:
            print(f"  {ip}")
        return

    outputs = get_tf_output(args.env)
    project_id = outputs["project_id"]
    update_cloud_armor(project_id, ips)


if __name__ == "__main__":
    main()
