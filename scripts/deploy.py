#!/usr/bin/env python3
"""Deploy EAG gateway to GCP Cloud Run across multiple regions.

Reads Terraform outputs to determine target regions and project,
then updates the Cloud Run services with the latest config from
Secret Manager.
"""

import argparse
import json
import subprocess
import sys


def run(cmd: list[str], *, check: bool = True, capture: bool = True) -> str:
    """Run a shell command and return stdout."""
    result = subprocess.run(
        cmd,
        check=check,
        capture_output=capture,
        text=True,
    )
    return result.stdout.strip() if capture else ""


def get_tf_output(env: str) -> dict:
    """Read Terraform outputs for the given environment."""
    tf_dir = f"terraform/environments/{env}"
    raw = run(["terraform", f"-chdir={tf_dir}", "output", "-json"])
    outputs = json.loads(raw)
    return {k: v["value"] for k, v in outputs.items()}


def deploy_region(project_id: str, region: str, image: str) -> None:
    """Deploy/update Cloud Run service in a single region."""
    print(f"  Deploying to {region}...")
    run(
        [
            "gcloud", "run", "services", "update", "eag-gateway",
            f"--project={project_id}",
            f"--region={region}",
            f"--image={image}",
            "--quiet",
        ],
        capture=False,
    )
    print(f"  {region}: done")


def main() -> None:
    parser = argparse.ArgumentParser(description="Deploy EAG to GCP")
    parser.add_argument(
        "--env",
        choices=["prod", "staging"],
        default="prod",
        help="Target environment",
    )
    parser.add_argument(
        "--image",
        default="ghcr.io/agentgateway/agentgateway:0.12.0",
        help="Container image to deploy",
    )
    args = parser.parse_args()

    print(f"Deploying EAG ({args.env})...")
    outputs = get_tf_output(args.env)
    project_id = outputs["project_id"]
    service_urls = outputs.get("service_urls", {})

    if not service_urls:
        print("No Cloud Run services found. Run `make tf-apply` first.")
        sys.exit(1)

    regions = list(service_urls.keys())
    print(f"  Project: {project_id}")
    print(f"  Regions: {', '.join(regions)}")
    print(f"  Image:   {args.image}")
    print()

    # Update the config secret first
    config_path = f"configs/{args.env}/config.yaml"
    print(f"Updating gateway config from {config_path}...")
    run([
        "gcloud", "secrets", "versions", "add", "eag-gateway-config",
        f"--project={project_id}",
        f"--data-file={config_path}",
    ])
    print()

    # Deploy to each region
    for region in regions:
        deploy_region(project_id, region, args.image)

    print()
    print(f"Global endpoint: https://{outputs.get('global_ip', 'N/A')}")
    print("Deployment complete.")


if __name__ == "__main__":
    main()
