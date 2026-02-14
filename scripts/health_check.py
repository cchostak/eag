#!/usr/bin/env python3
"""Health check utility for EAG gateway.

Checks health of all deployed Cloud Run instances and the global
load balancer endpoint.
"""

import argparse
import json
import subprocess
import sys
import urllib.request
import urllib.error


def run(cmd: list[str]) -> str:
    result = subprocess.run(cmd, check=True, capture_output=True, text=True)
    return result.stdout.strip()


def get_tf_output(env: str) -> dict:
    tf_dir = f"terraform/environments/{env}"
    raw = run(["terraform", f"-chdir={tf_dir}", "output", "-json"])
    outputs = json.loads(raw)
    return {k: v["value"] for k, v in outputs.items()}


def check_url(url: str, timeout: int = 10) -> tuple[bool, str]:
    """Check if a URL returns 200. Returns (ok, message)."""
    try:
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status == 200, f"HTTP {resp.status}"
    except urllib.error.HTTPError as e:
        return False, f"HTTP {e.code}"
    except Exception as e:
        return False, str(e)


def main() -> None:
    parser = argparse.ArgumentParser(description="EAG health check")
    parser.add_argument("--env", choices=["prod", "staging"], default="prod")
    parser.add_argument("--verbose", "-v", action="store_true")
    args = parser.parse_args()

    print(f"EAG Health Check ({args.env})")
    print("=" * 40)

    outputs = get_tf_output(args.env)
    service_urls = outputs.get("service_urls", {})
    global_ip = outputs.get("global_ip", "")

    all_ok = True

    # Check individual Cloud Run services
    for region, url in service_urls.items():
        health_url = f"{url}:15002/healthz"
        ok, msg = check_url(health_url)
        status = "OK" if ok else "FAIL"
        print(f"  [{status}] {region}: {msg}")
        if not ok:
            all_ok = False

    # Check global LB
    if global_ip:
        print()
        lb_url = f"https://{global_ip}:15002/healthz"
        ok, msg = check_url(lb_url)
        status = "OK" if ok else "FAIL"
        print(f"  [{status}] Global LB ({global_ip}): {msg}")
        if not ok:
            all_ok = False

    print()
    if all_ok:
        print("All checks passed.")
    else:
        print("Some checks failed.")
        sys.exit(1)


if __name__ == "__main__":
    main()
