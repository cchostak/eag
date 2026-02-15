# Copy to terraform.tfvars and fill in values

project_id     = "networking-486816"
primary_region = "us-central1"
domain         = "eag.yourcompany.com"

# Deploy to these regions for global HA
regions = [
  "us-central1",  # Americas
  "europe-west1", # EMEA
  "asia-east1",   # APAC
]

# Tailscale IP ranges to allowlist in Cloud Armor.
# Get these from: tailscale status --json | jq '.Peer[].TailscaleIPs'
# Or use `make sync-tailscale-ips` to auto-update after initial deploy.
tailscale_cidrs = [
  "100.64.0.0/10", # Default Tailscale CGNAT range - narrow this down
]

# Cloud Run scaling
min_instances = 1
max_instances = 10

gateway_image = "us-docker.pkg.dev/cloudrun/container/hello"

# Disable mirroring for now (hello image is already in Google registry)
use_artifact_registry_mirror = false
source_gateway_image         = "ghcr.io/agentgateway/agentgateway:0.12.0"
artifact_registry_location   = "us"
artifact_registry_repo       = "gateway"

# Suffix applied to resource names to avoid collisions with staging
name_suffix = "-prod2"

# Skip log exports when permissions are missing
enable_exports = false

# Skip auth metric/alert/custom service if already exist
create_auth_metric    = false
create_auth_alert     = false
create_custom_service = false

# API keys (sensitive - use env vars or a .tfvars file NOT in git)
# api_keys = {
#   "openai-api-key"    = "sk-..."
#   "anthropic-api-key" = "sk-ant-..."
# }

# Alerting
# notification_email = "oncall@yourcompany.com"

# Logging retention and archive (optional overrides)
# log_retention_days = 365
# log_archive_bucket = "custom-archive-bucket-name"

# Remote state bucket override (optional)
# state_bucket_name = "custom-tf-state-bucket"
