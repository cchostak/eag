resource "google_cloud_run_v2_service" "eag" {
  for_each = toset(var.regions)

  name     = "${var.service_name}${var.name_suffix}"
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
        cpu_idle = false # Keep CPU allocated for WebSocket/SSE
      }

      volume_mounts {
        name       = "config"
        mount_path = "/etc/agentgateway"
      }

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
        secret = var.config_secret_id
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
