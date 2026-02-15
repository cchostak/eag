project_id     = "networking-486816"
primary_region = "us-central1"
domain         = "eag-staging.yourcompany.com"

regions = [
  "us-central1",
]

tailscale_cidrs = [
  "100.64.0.0/10",
]

gateway_image = "us-docker.pkg.dev/cloudrun/container/hello"

# Mirror upstream GHCR image into Artifact Registry so Cloud Run accepts it
use_artifact_registry_mirror = true
source_gateway_image         = "ghcr.io/agentgateway/agentgateway:0.12.0"
artifact_registry_location   = "us"
artifact_registry_repo       = "gateway"

# Suffix applied to resource names to avoid collisions with existing prod/staging resources in same project
name_suffix = "-stg"
