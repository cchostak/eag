# Copy to terraform.tfvars and fill in values

project_id     = "networking-486816"
primary_region = "us-central1"
domain         = "eag-staging.yourcompany.com"

# Single region for staging
regions = ["us-central1"]

tailscale_cidrs = [
  "100.64.0.0/10",
]
