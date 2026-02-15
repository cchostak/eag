variable "project_id" {
  type = string
}

variable "tailscale_cidrs" {
  type        = list(string)
  description = "Tailscale IP CIDRs allowed through Cloud Armor"
}

variable "cloud_run_negs" {
  type        = map(string)
  description = "Map of region => serverless NEG ID"
}

variable "domain" {
  type        = string
  description = "Domain name for the gateway (e.g. eag.yourcompany.com)"
}

variable "ssl_certificate" {
  type        = string
  description = "Google-managed SSL certificate name"
  default     = ""
}

variable "name_suffix" {
  type        = string
  default     = ""
  description = "Optional suffix appended to networking resource names (include leading dash if desired)"
}
