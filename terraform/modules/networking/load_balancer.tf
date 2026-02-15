resource "google_compute_global_address" "eag" {
  name    = "eag-global-ip${var.name_suffix}"
  project = var.project_id
}

resource "google_compute_managed_ssl_certificate" "eag" {
  count   = var.ssl_certificate == "" ? 1 : 0
  name    = "eag-ssl-cert${var.name_suffix}"
  project = var.project_id

  managed {
    domains = [var.domain]
  }
}

resource "google_compute_backend_service" "eag" {
  name                  = "eag-backend${var.name_suffix}"
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
  name            = "eag-url-map${var.name_suffix}"
  project         = var.project_id
  default_service = google_compute_backend_service.eag.self_link
}

resource "google_compute_target_https_proxy" "eag" {
  name    = "eag-https-proxy${var.name_suffix}"
  project = var.project_id
  url_map = google_compute_url_map.eag.self_link

  ssl_certificates = [
    var.ssl_certificate != "" ? var.ssl_certificate : google_compute_managed_ssl_certificate.eag[0].self_link
  ]
}

resource "google_compute_global_forwarding_rule" "eag_https" {
  name                  = "eag-https-forwarding${var.name_suffix}"
  project               = var.project_id
  target                = google_compute_target_https_proxy.eag.self_link
  port_range            = "443"
  ip_address            = google_compute_global_address.eag.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

resource "google_compute_url_map" "eag_redirect" {
  name    = "eag-http-redirect${var.name_suffix}"
  project = var.project_id

  default_url_redirect {
    https_redirect = true
    strip_query    = false
  }
}

resource "google_compute_target_http_proxy" "eag_redirect" {
  name    = "eag-http-redirect-proxy${var.name_suffix}"
  project = var.project_id
  url_map = google_compute_url_map.eag_redirect.self_link
}

resource "google_compute_global_forwarding_rule" "eag_http" {
  name                  = "eag-http-forwarding${var.name_suffix}"
  project               = var.project_id
  target                = google_compute_target_http_proxy.eag_redirect.self_link
  port_range            = "80"
  ip_address            = google_compute_global_address.eag.address
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
