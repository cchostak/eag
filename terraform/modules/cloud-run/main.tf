# cloud-run module - Multi-region Cloud Run deployment

variable "project_id" {
  type = string
}

variable "regions" {
  type        = list(string)
  description = "GCP regions to deploy to"
}

variable "image" {
  type        = string
  description = "Container image URI"
}

variable "config_secret_id" {
  type        = string
  description = "Secret Manager secret ID containing the gateway config"
}

variable "env_secrets" {
  type        = map(string)
  description = "Map of ENV_VAR_NAME => secret_id for runtime secrets"
  default     = {}
}

variable "service_account_email" {
  type = string
}

variable "min_instances" {
  type    = number
  default = 1
}

variable "max_instances" {
  type    = number
  default = 10
}

variable "cpu" {
  type    = string
  default = "2"
}

variable "memory" {
  type    = string
  default = "1Gi"
}

# --- Cloud Run services per region ---

resource "google_cloud_run_v2_service" "eag" {
  for_each = toset(var.regions)

  name     = "eag-gateway"
  location = each.value
  project  = var.project_id

  template {
    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    service_account = var.service_account_email

    containers {
      image = var.image

      ports {
        container_port = 3000
      }

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
        cpu_idle = false # Keep CPU always allocated for WebSocket/SSE
      }

      # Mount config from Secret Manager
      volume_mounts {
        name       = "config"
        mount_path = "/etc/agentgateway"
      }

      # Inject API keys as env vars from Secret Manager
      dynamic "env" {
        for_each = var.env_secrets
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value
              version = "latest"
            }
          }
        }
      }

      startup_probe {
        http_get {
          path = "/healthz"
          port = 15002
        }
        initial_delay_seconds = 2
        period_seconds        = 5
        failure_threshold     = 5
      }

      liveness_probe {
        http_get {
          path = "/healthz"
          port = 15002
        }
        period_seconds = 10
      }
    }

    volumes {
      name = "config"
      secret {
        secret  = var.config_secret_id
        items {
          version = "latest"
          path    = "config.yaml"
        }
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

# --- Serverless NEGs for the load balancer ---

resource "google_compute_region_network_endpoint_group" "eag" {
  for_each = toset(var.regions)

  name                  = "eag-neg-${each.value}"
  project               = var.project_id
  region                = each.value
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.eag[each.value].name
  }
}

# --- IAM: Allow unauthenticated (LB handles auth via Cloud Armor + JWT) ---

resource "google_cloud_run_v2_service_iam_member" "public" {
  for_each = toset(var.regions)

  project  = var.project_id
  location = each.value
  name     = google_cloud_run_v2_service.eag[each.value].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# --- Outputs ---

output "service_urls" {
  value = {
    for region, svc in google_cloud_run_v2_service.eag :
    region => svc.uri
  }
}

output "neg_ids" {
  value = {
    for region, neg in google_compute_region_network_endpoint_group.eag :
    region => neg.id
  }
}
