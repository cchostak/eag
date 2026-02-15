resource "google_compute_security_policy" "tailscale_allowlist" {
  name    = "eag-tailscale-allowlist${var.name_suffix}"
  project = var.project_id

  rule {
    action   = "deny(403)"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default deny all"
  }

  rule {
    action   = "allow"
    priority = 1000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = var.tailscale_cidrs
      }
    }
    description = "Allow Tailscale network"
  }

  rule {
    action   = "allow"
    priority = 900
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = [
          "35.191.0.0/16",
          "130.211.0.0/22",
        ]
      }
    }
    description = "Allow GCP health check ranges"
  }
}
