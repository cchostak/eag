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

# Disable mirroring for now (hello image is already in Google registry)
use_artifact_registry_mirror = false
source_gateway_image         = "ghcr.io/agentgateway/agentgateway:0.12.0"
artifact_registry_location   = "us"
artifact_registry_repo       = "gateway"
existing_repository_id       = "gateway-stg3"

# Suffix applied to resource names to avoid collisions with existing prod/staging resources in same project
name_suffix = "-stg3"

# Skip log exports when permissions are missing
enable_exports = false

# Skip auth metric/alert/custom service if already exist
create_auth_metric    = false
create_auth_alert     = false
create_custom_service = false

# Reuse already-created resources to stay idempotent
existing_global_address        = "eag-global-ip-stg3"
existing_ssl_certificate       = "eag-ssl-cert-stg3"
existing_url_map_redirect      = "eag-http-redirect-stg3"
existing_security_policy       = "eag-tailscale-allowlist-stg3"
existing_service_account_email = "eag-gatewaystg3@networking-486816.iam.gserviceaccount.com"
existing_config_secret_id      = "eag-gateway-config-stg3"
state_bucket_name              = "networking-486816-eag-tf-state-stg3"
