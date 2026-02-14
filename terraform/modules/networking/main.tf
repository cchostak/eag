# networking module - Global LB, Cloud Armor, DNS

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

# --- Cloud Armor Security Policy ---

resource "google_compute_security_policy" "tailscale_allowlist" {
  name    = "eag-tailscale-allowlist"
  project = var.project_id

  # Default: deny all
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

  # Allow Tailscale IPs
  rule {
    action   = "allow"
    priority = "1000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = var.tailscale_cidrs
      }
    }
    description = "Allow Tailscale network"
  }

  # Allow GCP health checks
  rule {
    action   = "allow"
    priority = "900"
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

# --- Global HTTPS Load Balancer ---

resource "google_compute_global_address" "eag" {
  name    = "eag-global-ip"
  project = var.project_id
}

resource "google_compute_managed_ssl_certificate" "eag" {
  count   = var.ssl_certificate == "" ? 1 : 0
  name    = "eag-ssl-cert"
  project = var.project_id

  managed {
    domains = [var.domain]
  }
}

resource "google_compute_backend_service" "eag" {
  name                  = "eag-backend"
  project               = var.project_id
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 300
  load_balancing_scheme = "EXTERNAL_MANAGED"
  security_policy       = google_compute_security_policy.tailscale_allowlist.self_link

  dynamic "backend" {
    for_each = var.cloud_run_negs
    content {
      group = backend.value
    }
  }

  log_config {
    enable = true
  }
}

resource "google_compute_url_map" "eag" {
  name            = "eag-url-map"
  project         = var.project_id
  default_service = google_compute_backend_service.eag.self_link
}

resource "google_compute_target_https_proxy" "eag" {
  name    = "eag-https-proxy"
  project = var.project_id
  url_map = google_compute_url_map.eag.self_link

  ssl_certificates = [
    var.ssl_certificate != "" ? var.ssl_certificate : google_compute_managed_ssl_certificate.eag[0].self_link
  ]
}

resource "google_compute_global_forwarding_rule" "eag_https" {
  name                  = "eag-https-forwarding"
  project               = var.project_id
  target                = google_compute_target_https_proxy.eag.self_link
  port_range            = "443"
  ip_address            = google_compute_global_address.eag.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# HTTP -> HTTPS redirect
resource "google_compute_url_map" "eag_redirect" {
  name    = "eag-http-redirect"
  project = var.project_id

  default_url_redirect {
    https_redirect = true
    strip_query    = false
  }
}

resource "google_compute_target_http_proxy" "eag_redirect" {
  name    = "eag-http-redirect-proxy"
  project = var.project_id
  url_map = google_compute_url_map.eag_redirect.self_link
}

resource "google_compute_global_forwarding_rule" "eag_http" {
  name                  = "eag-http-forwarding"
  project               = var.project_id
  target                = google_compute_target_http_proxy.eag_redirect.self_link
  port_range            = "80"
  ip_address            = google_compute_global_address.eag.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# --- Outputs ---

output "global_ip" {
  value = google_compute_global_address.eag.address
}

output "security_policy_id" {
  value = google_compute_security_policy.tailscale_allowlist.id
}
