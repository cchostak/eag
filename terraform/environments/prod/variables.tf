variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "primary_region" {
  type    = string
  default = "us-central1"
}

variable "regions" {
  type        = list(string)
  description = "Regions to deploy Cloud Run instances"
  default     = ["us-central1", "europe-west1", "asia-east1"]
}

variable "domain" {
  type        = string
  description = "Domain for the gateway"
}

variable "tailscale_cidrs" {
  type        = list(string)
  description = "Tailscale IP CIDRs for Cloud Armor allowlist"
}

variable "gateway_image" {
  type    = string
  default = "ghcr.io/agentgateway/agentgateway:0.12.0"
}

variable "min_instances" {
  type    = number
  default = 1
}

variable "max_instances" {
  type    = number
  default = 10
}

variable "api_keys" {
  type      = map(string)
  default   = {}
  sensitive = true
}

variable "notification_email" {
  type        = string
  description = "Email to receive alert notifications"
  default     = ""
}

variable "log_retention_days" {
  type    = number
  default = 365
}

variable "log_archive_bucket" {
  type        = string
  description = "Override for the GCS bucket used to archive logs"
  default     = ""
}

variable "state_bucket_name" {
  type        = string
  description = "Override for the Terraform state bucket name"
  default     = ""
}
